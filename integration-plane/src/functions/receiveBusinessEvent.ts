/**
 * The endpoint Business Central delivers external business events to.
 *
 * A router and nothing more: answer the subscription validation handshake, look
 * the event name up in `eventRoutes.ts`, enqueue, answer. An event name the plane
 * does not know is acknowledged, logged, and dropped, deliberately: BC counts a
 * failed delivery against the subscription's health and removes the subscription
 * silently after repeated failures, so rejecting an unknown event would risk the
 * subscription carrying the events the plane does handle.
 */

import { app, type HttpRequest, type HttpResponseInit, type InvocationContext } from "@azure/functions";
import { CORRELATION_HEADER, resolveCorrelationId } from "../shared/correlation.js";
import { buildEnvelope } from "../shared/envelope.js";
import { routeFor } from "../shared/eventRoutes.js";
import { sendEnvelope } from "../shared/serviceBus.js";
import { logStep } from "../shared/telemetry.js";

export async function receiveBusinessEvent(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  // Registration handshake: BC proves the endpoint is ours by asking it to echo
  // a token. Nothing is enqueued, and this is the only path that answers before
  // reading a body.
  const validationToken = request.query.get("validationToken");
  if (validationToken !== null && validationToken !== "") {
    context.log(JSON.stringify({ step: "event.received", reason: "validation handshake" }));
    return { status: 200, body: validationToken, headers: { "Content-Type": "text/plain" } };
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    logStep(context, "receiver.rejected", { status: 400, reason: "body is not json" });
    return { status: 400, jsonBody: { error: "body is not valid JSON" } };
  }

  const eventName = typeof body["eventName"] === "string" ? (body["eventName"] as string) : "";
  logStep(context, "event.received", { eventName });

  const route = routeFor(eventName);
  if (route === undefined) {
    logStep(context, "event.unknown", { eventName, status: 200, reason: "no route for this event" });
    return { status: 200, jsonBody: { accepted: false, reason: "no route for this event" } };
  }

  const payload = (body["payload"] ?? body) as Record<string, unknown>;
  const businessKey = stringAt(payload, route.businessKeyField);
  const correlationFromPayload = stringAt(payload, route.correlationField);

  let envelope;
  try {
    envelope = buildEnvelope({
      flow: route.flow,
      source: "business-central",
      businessKey,
      correlationId: resolveCorrelationId(
        request.headers.get(CORRELATION_HEADER) ?? correlationFromPayload ?? null,
        businessKey,
      ),
      payload,
    });
  } catch (error) {
    const reason = error instanceof Error ? error.message : "missing business key";
    logStep(context, "receiver.rejected", { eventName, status: 400, reason });
    return { status: 400, jsonBody: { error: `missing ${route.businessKeyField}` } };
  }

  await sendEnvelope(context, route.queueName, envelope);

  logStep(context, "event.routed", {
    eventName,
    queue: route.queueName,
    flow: route.flow,
    businessKey: envelope.businessKey,
    correlationId: envelope.correlationId,
    status: 200,
  });

  return { status: 200, jsonBody: { accepted: true, reference: envelope.businessKey } };
}

function stringAt(payload: Record<string, unknown>, field: string): string | undefined {
  const value = payload[field];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : undefined;
}

app.http("receiveBusinessEvent", {
  methods: ["POST"],
  authLevel: "function",
  route: "bc/events",
  handler: receiveBusinessEvent,
});
