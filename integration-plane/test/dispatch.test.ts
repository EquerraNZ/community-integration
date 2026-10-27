import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const sendEnvelope = vi.fn(async () => undefined);
const park = vi.fn(async () => undefined);
vi.mock("../src/shared/serviceBus.js", () => ({
  sendEnvelope,
  park,
  deliveryCountOf: () => 1,
  PARKED_QUEUE: "parked",
}));

const { receiveBusinessEvent } = await import("../src/functions/receiveBusinessEvent.js");
const { sendWmsFulfilment } = await import("../src/functions/sendWmsFulfilment.js");
const { sendWebstoreStatus } = await import("../src/functions/sendWebstoreStatus.js");
const { HttpFailure } = await import("../src/shared/classify.js");
const { resetConfigCache } = await import("../src/shared/config.js");
const { envelopeFor, httpRequest, testContext, entryFor, steps } = await import("./helpers.js");

const SAVED = { ...process.env };
const DTO = {
  reference: "DG-00001",
  bcOrderNo: "S-ORD101001",
  lines: [{ sku: "ESP-250", quantity: 2 }],
  shippingMethod: "Standard",
};

beforeEach(() => {
  sendEnvelope.mockClear();
  park.mockClear();
  resetConfigCache();
  process.env["WMS_BASE_URL"] = "https://wms.example.com";
  process.env["WMS_API_KEY"] = "wms-secret";
  process.env["WEBSTORE_BASE_URL"] = "https://storefront.example.com";
  process.env["WEBSTORE_STATUS_KEY"] = "status-secret";
  process.env["BC_EVENT_ENDPOINT_URL"] = "https://func-intplane-dev-aue.azurewebsites.net/api/bc/events";
});

afterEach(() => {
  process.env = { ...SAVED };
  resetConfigCache();
  vi.unstubAllGlobals();
});

describe("receiveBusinessEvent", () => {
  it("answers the subscription validation handshake without enqueueing", async () => {
    const response = await receiveBusinessEvent(
      httpRequest({ query: { validationToken: "abc123" } }),
      testContext(),
    );

    expect(response.status).toBe(200);
    expect(response.body).toBe("abc123");
    expect(sendEnvelope).not.toHaveBeenCalled();
  });

  it("routes the release event onto the fulfilment queue, keyed on the reference", async () => {
    await receiveBusinessEvent(
      httpRequest({
        body: {
          eventName: "OnSalesOrderReleased_v1",
          payload: { reference: "DG-00001", bcOrderNo: "S-ORD101001", correlationId: "DG-00001" },
        },
      }),
      testContext(),
    );

    const [, queueName, envelope] = sendEnvelope.mock.calls[0] as unknown as [unknown, string, Record<string, unknown>];
    expect(queueName).toBe("outbound-wms-fulfilment");
    expect(envelope["businessKey"]).toBe("DG-00001");
  });

  it("routes the shipment event onto the storefront queue", async () => {
    await receiveBusinessEvent(
      httpRequest({
        body: {
          eventName: "OnShipmentConfirmed_v1",
          payload: { orderNo: "DG-00001", bcOrderNo: "S-ORD101001", correlationId: "DG-00001" },
        },
      }),
      testContext(),
    );

    const [, queueName] = sendEnvelope.mock.calls[0] as unknown as [unknown, string, unknown];
    expect(queueName).toBe("outbound-webstore-status");
  });

  it("acknowledges an unknown event rather than failing it", async () => {
    // BC counts a failed delivery against the subscription's health and removes
    // the subscription silently after repeated failures, so rejecting an event
    // we do not handle would risk the ones we do.
    const context = testContext();
    const response = await receiveBusinessEvent(
      httpRequest({ body: { eventName: "OnSomethingElse_v1", payload: {} } }),
      context,
    );

    expect(response.status).toBe(200);
    expect(sendEnvelope).not.toHaveBeenCalled();
    expect(entryFor(context, "event.unknown")?.["eventName"]).toBe("OnSomethingElse_v1");
  });
});

describe("sendWmsFulfilment", () => {
  function bcStub(overrides: Partial<Record<string, unknown>> = {}) {
    return {
      readOutboundMessage: vi.fn(async () => ({
        bcMessageId: "bc-2",
        externalReference: "DG-00001",
        correlationId: "DG-00001",
        payload: DTO,
      })),
      recordOutboundResult: vi.fn(async () => undefined),
      ...overrides,
    } as never;
  }

  it("posts the staged DTO unchanged, with the idempotency and correlation headers", async () => {
    const fetchImpl = vi.fn(async () => okResponse(201, { wmsRef: "FUL-558821" }));
    vi.stubGlobal("fetch", fetchImpl);

    await sendWmsFulfilment(envelopeFor("wms-fulfilment", "DG-00001"), testContext(), bcStub());

    const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://wms.example.com/api/v2/fulfilments");
    const headers = init.headers as Record<string, string>;
    expect(headers["Idempotency-Key"]).toBe("DG-00001");
    expect(headers["x-correlation-id"]).toBe("DG-00001");
    expect(headers["Authorization"]).toBe("ApiKey wms-secret");
    // The plane adds no field and drops none.
    expect(JSON.parse(String(init.body))).toEqual(DTO);
  });

  it("records the WMS reference against the outbound message", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => okResponse(201, { wmsRef: "FUL-558821" })));
    const bc = bcStub();

    const context = testContext();
    await sendWmsFulfilment(envelopeFor("wms-fulfilment", "DG-00001"), context, bc);

    expect((bc as unknown as { recordOutboundResult: ReturnType<typeof vi.fn> }).recordOutboundResult).toHaveBeenCalledWith(
      "bc-2",
      { externalSystemRef: "FUL-558821", correlationId: "DG-00001" },
    );
    expect(entryFor(context, "dispatch.succeeded")?.["wmsRef"]).toBe("FUL-558821");
  });

  it("rethrows when the WMS is unavailable, so the broker redelivers", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => okResponse(503, { error: "busy" })));

    await expect(
      sendWmsFulfilment(envelopeFor("wms-fulfilment", "DG-00001"), testContext(), bcStub()),
    ).rejects.toThrow(HttpFailure);
    expect(park).not.toHaveBeenCalled();
  });

  it("parks an invalid fulfilment rather than retrying it", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => okResponse(422, { error: "unknown sku" })));

    await expect(
      sendWmsFulfilment(envelopeFor("wms-fulfilment", "DG-00001"), testContext(), bcStub()),
    ).resolves.toBeUndefined();
    expect(park).toHaveBeenCalledTimes(1);
  });

  it("parks when BC has no staged message, instead of retrying forever", async () => {
    const bc = bcStub({
      readOutboundMessage: vi.fn(async () => {
        throw new HttpFailure("Business Central", 404, "no outbound message");
      }),
    });
    const context = testContext();

    await expect(sendWmsFulfilment(envelopeFor("wms-fulfilment", "DG-00001"), context, bc)).resolves.toBeUndefined();
    expect(park).toHaveBeenCalledTimes(1);
    expect(steps(context)).not.toContain("dispatch.read");
  });
});

describe("sendWebstoreStatus", () => {
  it("patches the storefront order to Despatched with the BC order number", async () => {
    const fetchImpl = vi.fn(async () => okResponse(200, { transitioned: true }));
    vi.stubGlobal("fetch", fetchImpl);

    await sendWebstoreStatus(
      envelopeFor("webstore-status", "DG-00001", {
        orderNo: "DG-00001",
        bcOrderNo: "S-ORD101001",
        despatchedAt: "2026-06-11T15:02:00Z",
      }),
      testContext(),
    );

    const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://storefront.example.com/api/orders/DG-00001/status");
    expect(init.method).toBe("PATCH");
    expect(JSON.parse(String(init.body))).toEqual({
      status: "Despatched",
      bcOrderNo: "S-ORD101001",
      despatchedAt: "2026-06-11T15:02:00Z",
    });
  });

  it("treats a repeat as success", async () => {
    // The storefront answers transitioned:false and changes nothing, so a
    // redelivery costs a call and nothing else.
    vi.stubGlobal("fetch", vi.fn(async () => okResponse(200, { transitioned: false })));

    const context = testContext();
    await sendWebstoreStatus(
      envelopeFor("webstore-status", "DG-00001", { orderNo: "DG-00001" }),
      context,
    );

    expect(steps(context)).toContain("dispatch.succeeded");
    expect(park).not.toHaveBeenCalled();
  });
});

function okResponse(status: number, body: unknown): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(body),
  } as Response;
}
