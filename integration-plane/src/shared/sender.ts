/**
 * The plane's one way of calling an external system.
 *
 * Both senders go through it so that the headers the contract requires
 * (`Idempotency-Key`, `x-correlation-id`) are set in one place, and so that an
 * unsuccessful response becomes an `HttpFailure` for `queueStep.ts` to classify
 * rather than each sender inventing its own idea of what to retry.
 */

import { HttpFailure } from "./classify.js";
import { correlationHeaders } from "./correlation.js";

type Fetch = typeof globalThis.fetch;

export interface ExternalCall {
  target: string;
  url: string;
  method: "POST" | "PATCH";
  /** Auth and anything else the vendor wants. Never logged. */
  headers: Record<string, string>;
  correlationId: string;
  /** Per the contract, the reference, so a retry is a no-op at the receiver. */
  idempotencyKey?: string;
  body: unknown;
}

export interface ExternalResponse {
  status: number;
  body: unknown;
}

export async function callExternal(
  call: ExternalCall,
  fetchImpl: Fetch = globalThis.fetch,
): Promise<ExternalResponse> {
  const headers: Record<string, string> = {
    ...call.headers,
    ...correlationHeaders(call.correlationId),
    "Content-Type": "application/json",
    Accept: "application/json",
  };
  if (call.idempotencyKey !== undefined) headers["Idempotency-Key"] = call.idempotencyKey;

  const response = await fetchImpl(call.url, {
    method: call.method,
    headers,
    body: JSON.stringify(call.body),
  });

  const text = await response.text().catch(() => "");
  const body: unknown = text.trim() === "" ? {} : safeParse(text);

  if (!response.ok) {
    throw new HttpFailure(call.target, response.status, text.slice(0, 500));
  }

  return { status: response.status, body };
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

export function stringFrom(body: unknown, ...names: string[]): string | undefined {
  if (typeof body !== "object" || body === null) return undefined;
  for (const name of names) {
    const value = (body as Record<string, unknown>)[name];
    if (typeof value === "string" && value !== "") return value;
  }
  return undefined;
}
