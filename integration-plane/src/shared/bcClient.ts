/**
 * The plane's one way of talking to Business Central.
 *
 * Authentication is the Function App's managed identity, so there is no BC user,
 * no password, and no client secret anywhere in the plane. The audience and the
 * base URL are configuration, which is deliberate: the exact scope for a managed
 * identity calling a BC API page is tech design question 6, and settling it has
 * to be a parameter change rather than a rewrite.
 *
 * Every method turns an unsuccessful response into an `HttpFailure`, so the
 * caller classifies it with `classify.ts` instead of each call site inventing its
 * own idea of what a 409 means.
 */

import { DefaultAzureCredential, type TokenCredential } from "@azure/identity";
import { config } from "./config.js";
import { correlationHeaders } from "./correlation.js";
import type { Envelope } from "./envelope.js";
import { HttpFailure } from "./classify.js";

export type MessageType = "WebstoreOrder" | "WmsShipmentConfirmation";

export interface StageResult {
  /** `created` on a 201, `duplicate` where BC already had this reference. */
  outcome: "created" | "duplicate";
  bcMessageId: string;
}

export interface OutboundMessage {
  bcMessageId: string;
  externalReference: string;
  correlationId: string;
  /** The DTO the event could not carry. Taken as it stands, never rebuilt. */
  payload: unknown;
}

export interface EventSubscription {
  eventName: string;
  notificationUrl: string;
}

type Fetch = typeof globalThis.fetch;

export interface BcClientOptions {
  credential?: TokenCredential;
  fetchImpl?: Fetch;
}

export class BcClient {
  readonly #credential: TokenCredential;
  readonly #fetch: Fetch;

  constructor(options: BcClientOptions = {}) {
    this.#credential = options.credential ?? new DefaultAzureCredential();
    this.#fetch = options.fetchImpl ?? globalThis.fetch;
  }

  /**
   * Stage an inbound message. A 409, or a 200 naming an existing row, is success:
   * BC deduplicated on `(External Reference, Type)`, which is exactly what it was
   * asked to do. Treating it as a failure would park every legitimate redelivery.
   */
  async stageMessage(envelope: Envelope, messageType: MessageType): Promise<StageResult> {
    const response = await this.#send("POST", this.#companyPath("integrationMessages"), {
      correlationId: envelope.correlationId,
      idempotencyKey: envelope.businessKey,
      body: {
        messageType,
        externalReference: envelope.businessKey,
        correlationId: envelope.correlationId,
        payload: JSON.stringify(envelope.payload),
      },
    });

    if (response.status === 409) {
      const existing = await readJson(response);
      return { outcome: "duplicate", bcMessageId: stringField(existing, "id", "systemId") };
    }

    await throwIfFailed("Business Central", response);

    const created = await readJson(response);
    const bcMessageId = stringField(created, "id", "systemId");
    // BC answers 200 with the prior row when the reference already existed, per
    // the integration contract. Same meaning as a 409, different status.
    const outcome = response.status === 201 ? "created" : "duplicate";
    return { outcome, bcMessageId };
  }

  /**
   * Read a staged outbound message by its reference, to get the DTO that an
   * `[ExternalBusinessEvent]` argument is too small to carry (250 characters).
   * This is the only read the plane makes against BC, and it reshapes nothing.
   */
  async readOutboundMessage(externalReference: string, correlationId: string): Promise<OutboundMessage> {
    const filter = encodeURIComponent(
      `externalReference eq '${escapeODataLiteral(externalReference)}' and direction eq 'Outbound'`,
    );
    const response = await this.#send(
      "GET",
      `${this.#companyPath("integrationMessages")}?$filter=${filter}&$top=1`,
      { correlationId },
    );
    await throwIfFailed("Business Central", response);

    const body = await readJson(response);
    const rows = Array.isArray((body as { value?: unknown }).value)
      ? ((body as { value: unknown[] }).value)
      : [];
    const row = rows[0];
    if (row === undefined) {
      // Not a transient gap to retry around: the event said this message exists
      // and BC says it does not. Retrying cannot make it appear.
      throw new HttpFailure("Business Central", 404, `no outbound message for ${externalReference}`);
    }

    const raw = stringField(row, "payload", "request");
    return {
      bcMessageId: stringField(row, "id", "systemId"),
      externalReference,
      correlationId,
      payload: JSON.parse(raw),
    };
  }

  /** Record the external system's own reference against the outbound message. */
  async recordOutboundResult(
    bcMessageId: string,
    result: { externalSystemRef: string; correlationId: string },
  ): Promise<void> {
    const response = await this.#send(
      "PATCH",
      this.#companyPath(`integrationMessages(${bcMessageId})`),
      {
        correlationId: result.correlationId,
        ifMatch: "*",
        body: { externalSystemReference: result.externalSystemRef },
      },
    );
    await throwIfFailed("Business Central", response);
  }

  async listEventSubscriptions(): Promise<EventSubscription[]> {
    const response = await this.#send("GET", `${this.#root()}/businessEventSubscriptions`, {});
    await throwIfFailed("Business Central", response);

    const body = await readJson(response);
    const rows = Array.isArray((body as { value?: unknown }).value)
      ? ((body as { value: unknown[] }).value)
      : [];
    return rows.map((row) => ({
      eventName: stringField(row, "eventName", "name"),
      notificationUrl: stringField(row, "notificationUrl", "endpoint"),
    }));
  }

  async createEventSubscription(subscription: EventSubscription): Promise<void> {
    const response = await this.#send("POST", `${this.#root()}/businessEventSubscriptions`, {
      body: subscription,
    });
    await throwIfFailed("Business Central", response);
  }

  #root(): string {
    return config.bcBaseUrl();
  }

  #companyPath(resource: string): string {
    return `${this.#root()}/companies(${config.bcCompanyId()})/${resource}`;
  }

  async #send(
    method: "GET" | "POST" | "PATCH",
    url: string,
    options: {
      correlationId?: string;
      idempotencyKey?: string;
      ifMatch?: string;
      body?: unknown;
    },
  ): Promise<Response> {
    const token = await this.#credential.getToken(config.bcTokenScope());
    if (token === null) {
      throw new HttpFailure("Business Central", 401, "no token for the plane's managed identity");
    }

    const headers: Record<string, string> = {
      Authorization: `Bearer ${token.token}`,
      Accept: "application/json",
    };
    if (options.body !== undefined) headers["Content-Type"] = "application/json";
    if (options.correlationId !== undefined) Object.assign(headers, correlationHeaders(options.correlationId));
    if (options.idempotencyKey !== undefined) headers["Idempotency-Key"] = options.idempotencyKey;
    if (options.ifMatch !== undefined) headers["If-Match"] = options.ifMatch;

    return this.#fetch(url, {
      method,
      headers,
      ...(options.body === undefined ? {} : { body: JSON.stringify(options.body) }),
    });
  }
}

async function throwIfFailed(target: string, response: Response): Promise<void> {
  if (response.ok) return;
  // The detail is the remote system's own error text, which is about the request
  // rather than its contents. Payload bodies never reach a log from here.
  const detail = await response.text().catch(() => "");
  throw new HttpFailure(target, response.status, detail.slice(0, 500));
}

async function readJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (text.trim() === "") return {};
  return JSON.parse(text);
}

/** Picks the first of several field names BC might use, so one rename is one edit. */
function stringField(row: unknown, ...names: string[]): string {
  if (typeof row === "object" && row !== null) {
    for (const name of names) {
      const value = (row as Record<string, unknown>)[name];
      if (typeof value === "string" && value !== "") return value;
    }
  }
  throw new HttpFailure("Business Central", 502, `response is missing ${names.join(" or ")}`);
}

function escapeODataLiteral(value: string): string {
  return value.replace(/'/g, "''");
}
