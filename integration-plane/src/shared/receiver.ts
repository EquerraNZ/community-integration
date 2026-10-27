/**
 * The one receiver implementation. Both inbound HTTP functions configure it and
 * neither reimplements it, because the second copy is where the two drift.
 *
 * It authenticates, finds the business key, builds the envelope, enqueues, and
 * answers. It does not call BC, it does not call any external system, and it does
 * not validate the payload beyond the business key: BC owns what is valid, and a
 * plane that pre-judges a payload is a second place to maintain the rules.
 */

import type { HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { timingSafeEqual } from "node:crypto";
import { config } from "./config.js";
import { CORRELATION_HEADER, resolveCorrelationId } from "./correlation.js";
import { buildEnvelope, EnvelopeError, type Flow } from "./envelope.js";
import { sendEnvelope } from "./serviceBus.js";
import { logStep } from "./telemetry.js";

export const API_KEY_HEADER = "x-api-key";

export interface ReceiverConfig {
  flow: Flow;
  source: string;
  queueName: string;
  /** The app setting holding the shared key this caller must present. */
  apiKeySettingName: string;
  /** The field in the body that is this system's stable id. */
  businessKeyField: string;
  /** Where to derive a correlation id when the caller sends no header. */
  correlationField?: string;
}

export async function handleReceive(
  cfg: ReceiverConfig,
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  if (!isAuthorised(request.headers.get(API_KEY_HEADER), cfg.apiKeySettingName)) {
    logStep(context, "receiver.rejected", {
      flow: cfg.flow,
      status: 401,
      reason: "api key missing or wrong",
    });
    return { status: 401, jsonBody: { error: "unauthorised" } };
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    logStep(context, "receiver.rejected", { flow: cfg.flow, status: 400, reason: "body is not json" });
    return { status: 400, jsonBody: { error: "body is not valid JSON" } };
  }

  const businessKey = stringAt(body, cfg.businessKeyField);
  const correlationSource =
    cfg.correlationField === undefined ? businessKey : stringAt(body, cfg.correlationField) ?? businessKey;

  let envelope;
  try {
    envelope = buildEnvelope({
      flow: cfg.flow,
      source: cfg.source,
      businessKey,
      correlationId: resolveCorrelationId(request.headers.get(CORRELATION_HEADER), correlationSource),
      payload: body,
    });
  } catch (error) {
    const reason =
      error instanceof EnvelopeError || error instanceof Error
        ? error.message
        : `missing ${cfg.businessKeyField}`;
    logStep(context, "receiver.rejected", { flow: cfg.flow, status: 400, reason });
    return { status: 400, jsonBody: { error: `missing ${cfg.businessKeyField}` } };
  }

  await sendEnvelope(context, cfg.queueName, envelope);

  logStep(context, "receiver.accepted", {
    flow: cfg.flow,
    businessKey: envelope.businessKey,
    correlationId: envelope.correlationId,
    status: 202,
  });

  // 202 means queued, not accepted by BC. The contract says so, and the
  // Integration Message list in BC is where acceptance becomes visible.
  return {
    status: 202,
    jsonBody: { accepted: true, reference: envelope.businessKey, correlationId: envelope.correlationId },
  };
}

function isAuthorised(presented: string | null, settingName: string): boolean {
  if (presented === null || presented === "") return false;
  const expected = config.secret(settingName);
  const a = Buffer.from(presented);
  const b = Buffer.from(expected);
  // Compare in constant time, and compare the lengths separately, because
  // timingSafeEqual throws on a length mismatch rather than returning false.
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

function stringAt(body: Record<string, unknown>, field: string): string | undefined {
  const value = body[field];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : undefined;
}
