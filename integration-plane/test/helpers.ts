import type { HttpRequest, InvocationContext } from "@azure/functions";
import { buildEnvelope, type Envelope, type Flow } from "../src/shared/envelope.js";

/** A context that records what was logged, so a test can assert on telemetry. */
export function testContext(triggerMetadata: Record<string, unknown> = {}): InvocationContext & {
  entries: Array<Record<string, unknown>>;
} {
  const entries: Array<Record<string, unknown>> = [];
  const record = (message?: unknown) => {
    if (typeof message === "string") {
      try {
        entries.push(JSON.parse(message) as Record<string, unknown>);
        return;
      } catch {
        /* not one of ours */
      }
    }
    entries.push({ raw: message });
  };

  return {
    entries,
    invocationId: "test",
    functionName: "test",
    triggerMetadata,
    log: record,
    warn: record,
    error: record,
    info: record,
    debug: record,
    trace: record,
    extraInputs: { get: () => undefined, set: () => undefined },
    extraOutputs: { get: () => undefined, set: () => undefined },
    options: {},
    retryContext: undefined,
  } as unknown as InvocationContext & { entries: Array<Record<string, unknown>> };
}

export function steps(context: { entries: Array<Record<string, unknown>> }): string[] {
  return context.entries.map((entry) => String(entry["step"] ?? "")).filter((step) => step !== "");
}

export function entryFor(
  context: { entries: Array<Record<string, unknown>> },
  step: string,
): Record<string, unknown> | undefined {
  return context.entries.find((entry) => entry["step"] === step);
}

export function httpRequest(options: {
  body?: unknown;
  headers?: Record<string, string>;
  query?: Record<string, string>;
  invalidJson?: boolean;
}): HttpRequest {
  const headers = new Headers(options.headers ?? {});
  const query = new URLSearchParams(options.query ?? {});
  return {
    method: "POST",
    url: "https://func-intplane-test.azurewebsites.net/api/test",
    headers,
    query,
    params: {},
    json: async () => {
      if (options.invalidJson === true) throw new SyntaxError("not json");
      return options.body;
    },
    text: async () => JSON.stringify(options.body ?? {}),
  } as unknown as HttpRequest;
}

export function envelopeFor(flow: Flow, businessKey: string, payload: unknown = {}): Envelope {
  return buildEnvelope({
    flow,
    source: "test",
    businessKey,
    correlationId: "DG-00001",
    payload,
    receivedAt: new Date("2026-06-11T09:14:02.000Z"),
  });
}

/** A `fetch` stub that answers a queue of canned responses, recording the calls. */
export function fetchStub(
  responses: Array<{ status: number; body?: unknown }>,
): typeof globalThis.fetch & { calls: Array<{ url: string; init: RequestInit }> } {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const queue = [...responses];

  const stub = (async (url: string | URL, init: RequestInit = {}) => {
    calls.push({ url: String(url), init });
    const next = queue.shift() ?? { status: 200, body: {} };
    const text = next.body === undefined ? "" : JSON.stringify(next.body);
    return {
      ok: next.status >= 200 && next.status < 300,
      status: next.status,
      text: async () => text,
    } as Response;
  }) as typeof globalThis.fetch & { calls: Array<{ url: string; init: RequestInit }> };

  stub.calls = calls;
  return stub;
}

export const fakeCredential = {
  getToken: async () => ({ token: "test-token", expiresOnTimestamp: Date.now() + 600_000 }),
};
