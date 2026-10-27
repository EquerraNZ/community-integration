/**
 * The one stager implementation. Both inbound queue functions configure it.
 *
 * Its whole job is to hand BC the envelope and get out of the way. It parses
 * nothing, maps nothing, and decides nothing about the payload: the handler for
 * that message type in BC does all of it.
 */

import type { InvocationContext } from "@azure/functions";
import { BcClient, type MessageType } from "./bcClient.js";
import type { Flow } from "./envelope.js";
import { runQueueStep } from "./queueStep.js";

export interface StagerConfig {
  flow: Flow;
  messageType: MessageType;
}

export async function handleStage(
  cfg: StagerConfig,
  raw: unknown,
  context: InvocationContext,
  bc: BcClient = new BcClient(),
): Promise<void> {
  await runQueueStep(
    context,
    raw,
    cfg.flow,
    { started: "stage.started", succeeded: "stage.succeeded", failed: "stage.failed" },
    async (envelope) => {
      const result = await bc.stageMessage(envelope, cfg.messageType);

      // A duplicate is success. BC deduplicated on (External Reference, Type),
      // which is what it was asked to do, and parking it would stop every
      // legitimate redelivery.
      return {
        status: result.outcome === "created" ? 201 : 200,
        bcMessageId: result.bcMessageId,
        ...(result.outcome === "duplicate" ? { reason: "already staged" } : {}),
      };
    },
  );
}
