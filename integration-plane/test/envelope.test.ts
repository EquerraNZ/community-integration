import { describe, expect, it } from "vitest";
import { buildEnvelope, EnvelopeError, messageIdFor } from "../src/shared/envelope.js";
import { CORRELATION_HEADER, resolveCorrelationId } from "../src/shared/correlation.js";

describe("buildEnvelope", () => {
  it("carries the business key, the correlation id, and the payload unaltered", () => {
    const payload = { orderNo: "DG-00001", lines: [{ sku: "ESP-250", quantity: 2 }] };
    const envelope = buildEnvelope({
      flow: "webstore-order",
      source: "webstore",
      businessKey: "DG-00001",
      correlationId: "DG-00001",
      payload,
    });

    expect(envelope.businessKey).toBe("DG-00001");
    expect(envelope.correlationId).toBe("DG-00001");
    expect(envelope.payload).toEqual(payload);
  });

  it("refuses a message with no business key", () => {
    // Without one it cannot be deduplicated by the broker, by BC, or by the
    // system we would send it to, so there is nothing useful to do with it.
    expect(() =>
      buildEnvelope({
        flow: "webstore-order",
        source: "webstore",
        businessKey: undefined,
        correlationId: "DG-00001",
        payload: {},
      }),
    ).toThrow(EnvelopeError);
  });

  it("refuses a blank business key as well as a missing one", () => {
    expect(() =>
      buildEnvelope({
        flow: "wms-shipment",
        source: "wms",
        businessKey: "   ",
        correlationId: "DG-00001",
        payload: {},
      }),
    ).toThrow(EnvelopeError);
  });
});

describe("messageIdFor", () => {
  it("is flow and business key, which is what duplicate detection compares", () => {
    expect(messageIdFor({ flow: "webstore-order", businessKey: "DG-00001" })).toBe(
      "webstore-order:DG-00001",
    );
  });

  it("scopes by flow, so the same reference on two flows is two messages", () => {
    expect(messageIdFor({ flow: "webstore-order", businessKey: "DG-00001" })).not.toBe(
      messageIdFor({ flow: "wms-fulfilment", businessKey: "DG-00001" }),
    );
  });
});

describe("resolveCorrelationId", () => {
  it("prefers the caller's header", () => {
    expect(resolveCorrelationId("DG-00009", "DG-00001")).toBe("DG-00009");
  });

  it("derives from the business key when there is no header", () => {
    // Never a fresh GUID: a trace id that joins nothing is worse than none,
    // because it looks like it works.
    expect(resolveCorrelationId(null, "DG-00001")).toBe("DG-00001");
  });

  it("ignores a blank header", () => {
    expect(resolveCorrelationId("   ", "DG-00001")).toBe("DG-00001");
  });

  it("fails when there is neither", () => {
    expect(() => resolveCorrelationId(null, undefined)).toThrow(CORRELATION_HEADER);
  });
});
