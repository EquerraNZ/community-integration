/**
 * Ask the WMS to pick, pack, and ship. Business process 2, second hop.
 *
 * The event that triggered this carries only `reference`, `bcOrderNo`, and
 * `correlationId`, because an `[ExternalBusinessEvent]` argument is capped at 250
 * characters and a multi-line order exceeds it. The fulfilment DTO is on the
 * staged outbound Integration Message, so this reads it back and POSTs it
 * unchanged.
 *
 * Reading it rather than rebuilding it from BC records is deliberate: rebuilding
 * would be a second implementation of feature 005's logic, in another language,
 * that would diverge the first time either changed.
 */

import { app, type InvocationContext } from "@azure/functions";
import { BcClient } from "../shared/bcClient.js";
import { config } from "../shared/config.js";
import { runQueueStep } from "../shared/queueStep.js";
import { callExternal, stringFrom } from "../shared/sender.js";
import { logStep } from "../shared/telemetry.js";

export async function sendWmsFulfilment(
  message: unknown,
  context: InvocationContext,
  bc: BcClient = new BcClient(),
): Promise<void> {
  await runQueueStep(
    context,
    message,
    "wms-fulfilment",
    { started: "dispatch.started", succeeded: "dispatch.succeeded", failed: "dispatch.failed" },
    async (envelope) => {
      const staged = await bc.readOutboundMessage(envelope.businessKey, envelope.correlationId);

      logStep(context, "dispatch.read", {
        flow: envelope.flow,
        businessKey: envelope.businessKey,
        correlationId: envelope.correlationId,
        bcMessageId: staged.bcMessageId,
      });

      const response = await callExternal({
        target: "WMS",
        url: `${config.wmsBaseUrl()}/api/v2/fulfilments`,
        method: "POST",
        headers: { Authorization: `ApiKey ${config.secret("WMS_API_KEY")}` },
        correlationId: envelope.correlationId,
        // Per the contract: the reference, so a redelivery is a no-op at the WMS
        // rather than a second shipment.
        idempotencyKey: envelope.businessKey,
        body: staged.payload,
      });

      const wmsRef = stringFrom(response.body, "wmsRef", "reference");
      if (wmsRef !== undefined) {
        // Without this the request and the later confirmation are joined only by
        // the correlation id, and operations loses the WMS's own reference.
        await bc.recordOutboundResult(staged.bcMessageId, {
          externalSystemRef: wmsRef,
          correlationId: envelope.correlationId,
        });
      }

      return {
        status: response.status,
        bcMessageId: staged.bcMessageId,
        ...(wmsRef === undefined ? {} : { wmsRef }),
      };
    },
  );
}

app.serviceBusQueue("sendWmsFulfilment", {
  queueName: "outbound-wms-fulfilment",
  connection: "SERVICEBUS",
  handler: sendWmsFulfilment,
});
