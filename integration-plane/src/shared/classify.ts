/**
 * Transient or permanent. The single most consequential decision the plane makes,
 * and the one the Azure integration review calls out as a blocker when it is got
 * wrong (`az-classify-transient-vs-permanent`).
 *
 * Transient means retry: the call might work in a minute. Permanent means stop:
 * it will never work, and retrying it is a loop that looks like a working
 * integration while nothing moves.
 */

import type { Classification } from "./telemetry.js";

export type { Classification };

/** Statuses below 500 that still mean "come back later". */
const TRANSIENT_CLIENT_STATUSES = new Set([408, 429]);

/** Node and undici error codes that are a network hiccup rather than a refusal. */
const TRANSIENT_ERROR_CODES = new Set([
  "ETIMEDOUT",
  "ECONNRESET",
  "ECONNREFUSED",
  "ENOTFOUND",
  "EAI_AGAIN",
  "EPIPE",
  "UND_ERR_CONNECT_TIMEOUT",
  "UND_ERR_HEADERS_TIMEOUT",
  "UND_ERR_BODY_TIMEOUT",
  "UND_ERR_SOCKET",
]);

export function classifyStatus(status: number): Classification {
  if (status >= 500) return "transient";
  if (TRANSIENT_CLIENT_STATUSES.has(status)) return "transient";
  return "permanent";
}

export function classifyError(error: unknown): Classification {
  if (error instanceof HttpFailure) return classifyStatus(error.status);

  const code = extractCode(error);
  if (code !== undefined && TRANSIENT_ERROR_CODES.has(code)) return "transient";

  if (error instanceof Error && /timeout|timed out|socket hang up/i.test(error.message)) {
    return "transient";
  }

  // An error we cannot place is permanent. The opposite default retries an
  // unknown bug until the delivery count runs out, five times per message,
  // against an external system that is working fine.
  return "permanent";
}

function extractCode(error: unknown): string | undefined {
  if (typeof error !== "object" || error === null) return undefined;
  const code = (error as { code?: unknown }).code;
  if (typeof code === "string") return code;
  const cause = (error as { cause?: unknown }).cause;
  return cause === undefined ? undefined : extractCode(cause);
}

/** An unsuccessful HTTP response from BC, the WMS, or the storefront. */
export class HttpFailure extends Error {
  readonly status: number;
  readonly target: string;

  constructor(target: string, status: number, detail?: string) {
    super(`${target} answered ${status}${detail ? `: ${detail}` : ""}`);
    this.name = "HttpFailure";
    this.status = status;
    this.target = target;
  }

  get classification(): Classification {
    return classifyStatus(this.status);
  }
}
