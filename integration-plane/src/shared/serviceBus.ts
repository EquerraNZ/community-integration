/**
 * Sending to Service Bus, and parking a message the plane will not retry.
 *
 * Sending goes through the SDK rather than an output binding because the plane
 * needs `messageId` (which is what duplicate detection compares) and the
 * correlation id as an application property (so it is readable without
 * deserialising the body). An output binding sets neither.
 *
 * **Parking, and why it is not a dead-letter call.** The Node worker does not
 * expose Service Bus message settlement, so a function cannot dead-letter the
 * message it is holding; its only choices are complete (return) or abandon
 * (throw). Throwing on a permanent failure would retry it five times and then
 * dead-letter it, which is exactly the "retry a 4xx" behaviour the review rules
 * call a blocker. So a permanent failure is forwarded to one shared `parked`
 * queue with its reason and completed. Both that queue and every dead-letter
 * queue are watched by the same alert, so operationally they are one surface:
 * messages that stopped, with the reason attached.
 */

import { ServiceBusClient, type ServiceBusMessage } from "@azure/service-bus";
import { DefaultAzureCredential } from "@azure/identity";
import type { InvocationContext } from "@azure/functions";
import { config } from "./config.js";
import { type Envelope, messageIdFor } from "./envelope.js";
import { logStep, type Classification } from "./telemetry.js";

export const PARKED_QUEUE = "parked";

let client: ServiceBusClient | undefined;

function sbClient(): ServiceBusClient {
  // One client per host instance. Creating one per invocation opens a new AMQP
  // connection each time, which is the classic way to exhaust a Consumption
  // plan's sockets under load.
  client ??= new ServiceBusClient(config.serviceBusNamespace(), new DefaultAzureCredential());
  return client;
}

/** Tests only. */
export function setServiceBusClientForTesting(stub: ServiceBusClient | undefined): void {
  client = stub;
}

export async function sendEnvelope(
  context: InvocationContext,
  queueName: string,
  envelope: Envelope,
): Promise<void> {
  const message: ServiceBusMessage = {
    body: envelope,
    messageId: messageIdFor(envelope),
    correlationId: envelope.correlationId,
    contentType: "application/json",
    applicationProperties: {
      flow: envelope.flow,
      businessKey: envelope.businessKey,
      correlationId: envelope.correlationId,
    },
  };

  const sender = sbClient().createSender(queueName);
  try {
    await sender.sendMessages(message);
  } finally {
    await sender.close();
  }

  logStep(context, "queue.enqueued", {
    queue: queueName,
    flow: envelope.flow,
    businessKey: envelope.businessKey,
    correlationId: envelope.correlationId,
  });
}

export interface ParkArgs {
  envelope: Envelope;
  reason: string;
  classification: Classification;
  status?: number;
}

/**
 * Stop this message for good, with the reason attached, and complete it so it is
 * not retried. Operations finds it on the `parked` queue beside anything that
 * dead-lettered by exhausting its delivery count.
 */
export async function park(context: InvocationContext, args: ParkArgs): Promise<void> {
  const { envelope, reason, classification, status } = args;

  const sender = sbClient().createSender(PARKED_QUEUE);
  try {
    await sender.sendMessages({
      body: envelope,
      // Deliberately not `messageIdFor`: the parked queue must accept the same
      // business key from two different failures, so duplicate detection there
      // would hide the second one.
      correlationId: envelope.correlationId,
      contentType: "application/json",
      applicationProperties: {
        flow: envelope.flow,
        businessKey: envelope.businessKey,
        correlationId: envelope.correlationId,
        reason,
        classification,
        ...(status === undefined ? {} : { status }),
      },
    });
  } finally {
    await sender.close();
  }

  logStep(context, "message.parked", {
    queue: PARKED_QUEUE,
    flow: envelope.flow,
    businessKey: envelope.businessKey,
    correlationId: envelope.correlationId,
    classification,
    reason,
    ...(status === undefined ? {} : { status }),
  });
}

/** The Service Bus delivery count, where the host supplies one. */
export function deliveryCountOf(context: InvocationContext): number | undefined {
  const raw = context.triggerMetadata?.["deliveryCount"];
  return typeof raw === "number" ? raw : undefined;
}
