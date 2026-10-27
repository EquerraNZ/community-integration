/**
 * One log shape for the whole plane, so a correlation id search returns every hop
 * with the same dimension names.
 *
 * `Dimensions` is a closed type on purpose. There is no `payload`, no `body`, and
 * no `customer` field, so logging the shopper's name, email, phone, or address is
 * not an oversight anyone can make here: it does not compile.
 */

import type { InvocationContext } from "@azure/functions";

export type Classification = "transient" | "permanent";

export interface Dimensions {
  /** The Webstore order number, carried end to end. Absent only on the timer. */
  correlationId?: string;
  /** The Integration Message GUID, once BC has told us what it is. */
  bcMessageId?: string;
  /** Which flow this belongs to, e.g. `webstore-order`. */
  flow?: string;
  /** The source system's stable id: the order number, the shipment id. */
  businessKey?: string;
  /** Which queue the message is on or going to. */
  queue?: string;
  /** The external business event name, on the event endpoint. */
  eventName?: string;
  /** The HTTP status returned to a caller, or received from one. */
  status?: number;
  /** Service Bus delivery count, so a retry is visible as a retry. */
  deliveryCount?: number;
  /** Transient or permanent, on any failure. */
  classification?: Classification;
  /** Why something was rejected or parked. Never includes payload content. */
  reason?: string;
  /** The WMS fulfilment reference, once the WMS has allocated one. */
  wmsRef?: string;
  /** This run of the health check. Used where no business message exists. */
  runId?: string;
  /** A count, e.g. subscriptions listed. */
  count?: number;
}

export type Step =
  | "receiver.accepted"
  | "receiver.rejected"
  | "queue.enqueued"
  | "stage.started"
  | "stage.succeeded"
  | "stage.failed"
  | "event.received"
  | "event.routed"
  | "event.unknown"
  | "dispatch.started"
  | "dispatch.read"
  | "dispatch.succeeded"
  | "dispatch.failed"
  | "message.parked"
  | "health.started"
  | "health.listed"
  | "health.healthy"
  | "health.drift"
  | "health.reregistered"
  | "health.failed";

export function logStep(context: InvocationContext, step: Step, dimensions: Dimensions = {}): void {
  const entry = { step, ...dimensions };
  if (step.endsWith(".failed") || step === "receiver.rejected" || step === "message.parked") {
    context.warn(JSON.stringify(entry));
    return;
  }
  context.log(JSON.stringify(entry));
}
