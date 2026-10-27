/**
 * What every queue-triggered function does around its one call out.
 *
 * The shape is always the same and getting it wrong is always the same bug, so
 * it lives here once: a transient failure rethrows and nothing else happens, so
 * the broker redelivers and the retry budget stays in the queue's delivery count;
 * a permanent failure is parked with its reason and the message is completed, so
 * it is never retried. See `serviceBus.ts` for why parking is not a dead-letter
 * call.
 */

import type { InvocationContext } from "@azure/functions";
import { classifyError, HttpFailure } from "./classify.js";
import type { Envelope, Flow } from "./envelope.js";
import { deliveryCountOf, park } from "./serviceBus.js";
import { logStep, type Step } from "./telemetry.js";

export interface StepNames {
  started: Step;
  succeeded: Step;
  failed: Step;
}

/** What a delivery reports back, purely so the success log can say it. */
export interface DeliveryOutcome {
  status?: number;
  wmsRef?: string;
  bcMessageId?: string;
  reason?: string;
}

export async function runQueueStep(
  context: InvocationContext,
  raw: unknown,
  flow: Flow,
  names: StepNames,
  deliver: (envelope: Envelope) => Promise<DeliveryOutcome | void>,
): Promise<void> {
  const envelope = asEnvelope(raw, flow);
  const deliveryCount = deliveryCountOf(context);

  logStep(context, names.started, {
    flow,
    businessKey: envelope.businessKey,
    correlationId: envelope.correlationId,
    ...(deliveryCount === undefined ? {} : { deliveryCount }),
  });

  try {
    const outcome = (await deliver(envelope)) ?? {};
    logStep(context, names.succeeded, {
      flow,
      businessKey: envelope.businessKey,
      correlationId: envelope.correlationId,
      ...(outcome.status === undefined ? {} : { status: outcome.status }),
      ...(outcome.wmsRef === undefined ? {} : { wmsRef: outcome.wmsRef }),
      ...(outcome.bcMessageId === undefined ? {} : { bcMessageId: outcome.bcMessageId }),
      ...(outcome.reason === undefined ? {} : { reason: outcome.reason }),
    });
  } catch (error) {
    const classification = classifyError(error);
    const status = error instanceof HttpFailure ? error.status : undefined;
    const reason = error instanceof Error ? error.message : String(error);

    logStep(context, names.failed, {
      flow,
      businessKey: envelope.businessKey,
      correlationId: envelope.correlationId,
      classification,
      reason,
      ...(status === undefined ? {} : { status }),
      ...(deliveryCount === undefined ? {} : { deliveryCount }),
    });

    if (classification === "transient") {
      // Rethrow and do nothing else. Retry is the broker's decision, and the
      // delivery count is the only budget.
      throw error;
    }

    await park(context, {
      envelope,
      reason,
      classification,
      ...(status === undefined ? {} : { status }),
    });
  }
}

/**
 * The Service Bus trigger hands back whatever was on the queue. Only this plane
 * writes to these queues, so a message that is not an envelope is a bug or a
 * hand-crafted replay, and either way there is nothing to park it as.
 */
function asEnvelope(raw: unknown, flow: Flow): Envelope {
  if (typeof raw !== "object" || raw === null) {
    throw new Error(`A ${flow} queue message is not an object.`);
  }
  const candidate = raw as Partial<Envelope>;
  if (typeof candidate.businessKey !== "string" || typeof candidate.correlationId !== "string") {
    throw new Error(`A ${flow} queue message is not an envelope.`);
  }
  return candidate as Envelope;
}
