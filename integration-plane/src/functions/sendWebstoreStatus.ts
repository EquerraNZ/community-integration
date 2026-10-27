/**
 * Tell the storefront the order has shipped. Business process 4, second hop, and
 * the last link in the loop.
 *
 * The storefront's PATCH is idempotent by design: a repeat answers
 * `transitioned: false` and changes nothing, so a redelivery costs a call and
 * nothing else. Carrier and tracking are recorded in BC but not sent, because the
 * storefront has no fields for them; adding them is a `_v2` of the event when it
 * does.
 */

import { app, type InvocationContext } from "@azure/functions";
import { config } from "../shared/config.js";
import { runQueueStep } from "../shared/queueStep.js";
import { callExternal } from "../shared/sender.js";

interface ShipmentConfirmedPayload {
  orderNo?: string;
  bcOrderNo?: string;
  despatchedAt?: string;
}

export async function sendWebstoreStatus(message: unknown, context: InvocationContext): Promise<void> {
  await runQueueStep(
    context,
    message,
    "webstore-status",
    { started: "dispatch.started", succeeded: "dispatch.succeeded", failed: "dispatch.failed" },
    async (envelope) => {
      const payload = envelope.payload as ShipmentConfirmedPayload;
      const orderNo = payload.orderNo ?? envelope.businessKey;

      const response = await callExternal({
        target: "Webstore",
        url: `${config.webstoreBaseUrl()}/api/orders/${encodeURIComponent(orderNo)}/status`,
        method: "PATCH",
        headers: { "x-api-key": config.secret("WEBSTORE_STATUS_KEY") },
        correlationId: envelope.correlationId,
        body: {
          // The only status the integration sets. The transition is fixed, which
          // is why the event carries no status field.
          status: "Despatched",
          bcOrderNo: payload.bcOrderNo,
          despatchedAt: payload.despatchedAt,
        },
      });

      return { status: response.status };
    },
  );
}

app.serviceBusQueue("sendWebstoreStatus", {
  queueName: "outbound-webstore-status",
  connection: "SERVICEBUS",
  handler: sendWebstoreStatus,
});
