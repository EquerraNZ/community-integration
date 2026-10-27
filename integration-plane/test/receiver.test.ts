import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const sendEnvelope = vi.fn(async () => undefined);
vi.mock("../src/shared/serviceBus.js", () => ({
  sendEnvelope,
  park: vi.fn(async () => undefined),
  deliveryCountOf: () => undefined,
  PARKED_QUEUE: "parked",
}));

const { handleReceive } = await import("../src/shared/receiver.js");
const { resetConfigCache } = await import("../src/shared/config.js");
const { receiveWmsShipment } = await import("../src/functions/receiveWmsShipment.js");
const { httpRequest, testContext, steps, entryFor } = await import("./helpers.js");

const SAVED = { ...process.env };

const WEBSTORE = {
  flow: "webstore-order",
  source: "webstore",
  queueName: "inbound-webstore-order",
  apiKeySettingName: "WEBSTORE_INGEST_KEY",
  businessKeyField: "orderNo",
} as const;

const ORDER = { orderNo: "DG-00001", totalAmount: 54, lines: [{ sku: "ESP-250", quantity: 2 }] };

beforeEach(() => {
  sendEnvelope.mockClear();
  resetConfigCache();
  process.env["WEBSTORE_INGEST_KEY"] = "ingest-key";
  process.env["WMS_CALLBACK_KEY"] = "wms-key";
});

afterEach(() => {
  process.env = { ...SAVED };
  resetConfigCache();
});

describe("handleReceive", () => {
  it("answers 202 and enqueues on a valid order", async () => {
    const context = testContext();
    const response = await handleReceive(
      WEBSTORE,
      httpRequest({ body: ORDER, headers: { "x-api-key": "ingest-key", "x-correlation-id": "DG-00001" } }),
      context,
    );

    expect(response.status).toBe(202);
    expect(sendEnvelope).toHaveBeenCalledTimes(1);
    const [, queueName, envelope] = sendEnvelope.mock.calls[0] as unknown as [unknown, string, Record<string, unknown>];
    expect(queueName).toBe("inbound-webstore-order");
    expect(envelope["businessKey"]).toBe("DG-00001");
    expect(steps(context)).toContain("receiver.accepted");
  });

  it("answers 401 and enqueues nothing on a wrong key", async () => {
    const context = testContext();
    const response = await handleReceive(
      WEBSTORE,
      httpRequest({ body: ORDER, headers: { "x-api-key": "wrong-key" } }),
      context,
    );

    expect(response.status).toBe(401);
    expect(sendEnvelope).not.toHaveBeenCalled();
    expect(entryFor(context, "receiver.rejected")?.["status"]).toBe(401);
  });

  it("answers 401 when no key is presented at all", async () => {
    const response = await handleReceive(WEBSTORE, httpRequest({ body: ORDER }), testContext());
    expect(response.status).toBe(401);
    expect(sendEnvelope).not.toHaveBeenCalled();
  });

  it("answers 400 and enqueues nothing when the business key is missing", async () => {
    const context = testContext();
    const response = await handleReceive(
      WEBSTORE,
      httpRequest({ body: { totalAmount: 54 }, headers: { "x-api-key": "ingest-key" } }),
      context,
    );

    expect(response.status).toBe(400);
    expect(sendEnvelope).not.toHaveBeenCalled();
  });

  it("answers 400 on a body that is not JSON", async () => {
    const response = await handleReceive(
      WEBSTORE,
      httpRequest({ invalidJson: true, headers: { "x-api-key": "ingest-key" } }),
      testContext(),
    );
    expect(response.status).toBe(400);
  });

  it("gives a double post the same MessageId, which is what the broker deduplicates on", async () => {
    const request = () => httpRequest({ body: ORDER, headers: { "x-api-key": "ingest-key" } });
    await handleReceive(WEBSTORE, request(), testContext());
    await handleReceive(WEBSTORE, request(), testContext());

    const first = sendEnvelope.mock.calls[0] as unknown as [unknown, string, { flow: string; businessKey: string }];
    const second = sendEnvelope.mock.calls[1] as unknown as [unknown, string, { flow: string; businessKey: string }];
    expect(`${first[2].flow}:${first[2].businessKey}`).toBe(`${second[2].flow}:${second[2].businessKey}`);
  });

  it("derives the correlation id from the business key when the caller sends no header", async () => {
    await handleReceive(WEBSTORE, httpRequest({ body: ORDER, headers: { "x-api-key": "ingest-key" } }), testContext());
    const [, , envelope] = sendEnvelope.mock.calls[0] as unknown as [unknown, string, Record<string, unknown>];
    expect(envelope["correlationId"]).toBe("DG-00001");
  });

  it("does nothing on the request path but enqueue and answer", async () => {
    // No BC client is passed to a receiver at all, so a call to BC would be a
    // compile error rather than a test that happens to pass. What this asserts
    // is the rest: one queue send, one log, and no other step.
    const context = testContext();
    await handleReceive(WEBSTORE, httpRequest({ body: ORDER, headers: { "x-api-key": "ingest-key" } }), context);

    expect(sendEnvelope).toHaveBeenCalledTimes(1);
    expect(steps(context)).toEqual(["receiver.accepted"]);
  });
});

describe("receiveWmsShipment", () => {
  it("keys on the shipment id and correlates on the reference", async () => {
    // The shipment id is what must not post twice; the order number is what
    // joins this hop to the rest of the order's history.
    await receiveWmsShipment(
      httpRequest({
        body: { shipmentId: "SHP-99001", reference: "DG-00001", carrier: "NZ Post" },
        headers: { "x-api-key": "wms-key" },
      }),
      testContext(),
    );

    const [, queueName, envelope] = sendEnvelope.mock.calls[0] as unknown as [unknown, string, Record<string, unknown>];
    expect(queueName).toBe("inbound-wms-shipment");
    expect(envelope["businessKey"]).toBe("SHP-99001");
    expect(envelope["correlationId"]).toBe("DG-00001");
  });
});
