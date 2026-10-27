/**
 * The correlation id, which is the Webstore order number end to end.
 *
 * It is read from the caller where the caller sets one, and derived from the
 * message's own business key where it does not. It is never invented: a fresh
 * GUID here would be a trace id that joins nothing, which is worse than none at
 * all because it looks like it works.
 */

export const CORRELATION_HEADER = "x-correlation-id";

export function resolveCorrelationId(
  headerValue: string | null | undefined,
  fallback: string | undefined,
): string {
  const fromHeader = headerValue?.trim();
  if (fromHeader !== undefined && fromHeader !== "") return fromHeader;

  const derived = fallback?.trim();
  if (derived !== undefined && derived !== "") return derived;

  // The caller sent no correlation id and the payload has no key to derive one
  // from. The envelope builder rejects this too; failing here makes the reason
  // specific.
  throw new Error(
    `No ${CORRELATION_HEADER} header and no value to derive a correlation id from.`,
  );
}

/** The headers every outbound call carries, so no caller has to remember. */
export function correlationHeaders(correlationId: string): Record<string, string> {
  return { [CORRELATION_HEADER]: correlationId };
}
