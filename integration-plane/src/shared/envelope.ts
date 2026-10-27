/**
 * The envelope the plane puts on a queue, between a receiver and its delivery
 * function. Internal, not a public contract, and pinned in
 * `specs/contracts/integration-contract.md` under "The queue envelope".
 *
 * It exists so that no delivery function ever has to call back to the source for
 * something the receiver already had.
 */

export type Flow =
  | "webstore-order"
  | "wms-shipment"
  | "wms-fulfilment"
  | "webstore-status";

export interface Envelope<TPayload = unknown> {
  flow: Flow;
  /** The source system's stable id. The idempotency key everywhere downstream. */
  businessKey: string;
  /** The Webstore order number, end to end. Set once, never regenerated. */
  correlationId: string;
  source: string;
  receivedAt: string;
  /** The original body, unaltered. The plane reshapes nothing before BC sees it. */
  payload: TPayload;
}

export class EnvelopeError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EnvelopeError";
  }
}

export interface BuildEnvelopeArgs<TPayload> {
  flow: Flow;
  source: string;
  businessKey: string | undefined;
  correlationId: string;
  payload: TPayload;
  receivedAt?: Date;
}

export function buildEnvelope<TPayload>(args: BuildEnvelopeArgs<TPayload>): Envelope<TPayload> {
  const businessKey = args.businessKey?.trim();
  if (businessKey === undefined || businessKey === "") {
    // Without a business key the message cannot be deduplicated by the broker,
    // by BC, or by the external system we would send it to. There is nothing
    // useful to do with it, so it never gets onto a queue.
    throw new EnvelopeError(`A ${args.flow} message carries no business key.`);
  }

  const correlationId = args.correlationId.trim();
  if (correlationId === "") {
    throw new EnvelopeError(`A ${args.flow} message carries no correlation id.`);
  }

  return {
    flow: args.flow,
    businessKey,
    correlationId,
    source: args.source,
    receivedAt: (args.receivedAt ?? new Date()).toISOString(),
    payload: args.payload,
  };
}

/**
 * `<flow>:<businessKey>`, which is what Service Bus duplicate detection compares.
 * Scoped by flow so the same order number on two different flows is two messages,
 * not one discarded by accident.
 */
export function messageIdFor(envelope: Pick<Envelope, "flow" | "businessKey">): string {
  return `${envelope.flow}:${envelope.businessKey}`;
}
