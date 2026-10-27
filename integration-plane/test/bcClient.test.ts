import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { BcClient } from "../src/shared/bcClient.js";
import { HttpFailure } from "../src/shared/classify.js";
import { resetConfigCache } from "../src/shared/config.js";
import { envelopeFor, fakeCredential, fetchStub } from "./helpers.js";

const SAVED = { ...process.env };

beforeEach(() => {
  resetConfigCache();
  process.env["BC_BASE_URL"] = "https://api.businesscentral.example/v2.0/api/equerra/if/v1.0";
  process.env["BC_COMPANY_ID"] = "11111111-2222-3333-4444-555555555555";
  process.env["BC_TOKEN_SCOPE"] = "https://api.businesscentral.example/.default";
});

afterEach(() => {
  process.env = { ...SAVED };
  resetConfigCache();
});

function clientWith(responses: Array<{ status: number; body?: unknown }>) {
  const fetchImpl = fetchStub(responses);
  return { client: new BcClient({ credential: fakeCredential, fetchImpl }), fetchImpl };
}

describe("stageMessage", () => {
  it("sends the contract envelope with the idempotency key and the correlation header", async () => {
    const { client, fetchImpl } = clientWith([{ status: 201, body: { id: "bc-1" } }]);

    await client.stageMessage(envelopeFor("webstore-order", "DG-00001", { orderNo: "DG-00001" }), "WebstoreOrder");

    const call = fetchImpl.calls[0]!;
    const headers = call.init.headers as Record<string, string>;
    expect(headers["Idempotency-Key"]).toBe("DG-00001");
    expect(headers["x-correlation-id"]).toBe("DG-00001");
    expect(headers["Authorization"]).toBe("Bearer test-token");

    const body = JSON.parse(String(call.init.body)) as Record<string, unknown>;
    expect(body["messageType"]).toBe("WebstoreOrder");
    expect(body["externalReference"]).toBe("DG-00001");
    // The source body rides verbatim. The plane reshapes nothing.
    expect(JSON.parse(String(body["payload"]))).toEqual({ orderNo: "DG-00001" });
  });

  it("reports created on a 201", async () => {
    const { client } = clientWith([{ status: 201, body: { id: "bc-1" } }]);
    await expect(client.stageMessage(envelopeFor("webstore-order", "DG-00001"), "WebstoreOrder")).resolves.toEqual({
      outcome: "created",
      bcMessageId: "bc-1",
    });
  });

  it("treats a 409 as success, because BC deduplicated", async () => {
    // Parking this would stop every legitimate redelivery.
    const { client } = clientWith([{ status: 409, body: { id: "bc-existing" } }]);
    await expect(client.stageMessage(envelopeFor("webstore-order", "DG-00001"), "WebstoreOrder")).resolves.toEqual({
      outcome: "duplicate",
      bcMessageId: "bc-existing",
    });
  });

  it("treats a 200 naming an existing row as a duplicate", async () => {
    const { client } = clientWith([{ status: 200, body: { id: "bc-existing" } }]);
    const result = await client.stageMessage(envelopeFor("webstore-order", "DG-00001"), "WebstoreOrder");
    expect(result.outcome).toBe("duplicate");
  });

  it("raises a transient failure on a 503", async () => {
    const { client } = clientWith([{ status: 503, body: { error: "busy" } }]);
    await expect(
      client.stageMessage(envelopeFor("webstore-order", "DG-00001"), "WebstoreOrder"),
    ).rejects.toSatisfy((error: unknown) => error instanceof HttpFailure && error.classification === "transient");
  });

  it("raises a permanent failure on a 400", async () => {
    const { client } = clientWith([{ status: 400, body: { error: "bad" } }]);
    await expect(
      client.stageMessage(envelopeFor("webstore-order", "DG-00001"), "WebstoreOrder"),
    ).rejects.toSatisfy((error: unknown) => error instanceof HttpFailure && error.classification === "permanent");
  });
});

describe("readOutboundMessage", () => {
  it("returns the staged DTO parsed, and nothing else", async () => {
    const dto = { reference: "DG-00001", lines: [{ sku: "ESP-250", quantity: 2 }] };
    const { client } = clientWith([
      { status: 200, body: { value: [{ id: "bc-2", payload: JSON.stringify(dto) }] } },
    ]);

    const result = await client.readOutboundMessage("DG-00001", "DG-00001");
    expect(result.bcMessageId).toBe("bc-2");
    expect(result.payload).toEqual(dto);
  });

  it("raises a permanent 404 when BC has no such message", async () => {
    // The event said it exists and BC says it does not. Retrying cannot make it
    // appear, so this must not look transient.
    const { client } = clientWith([{ status: 200, body: { value: [] } }]);
    await expect(client.readOutboundMessage("DG-00001", "DG-00001")).rejects.toSatisfy(
      (error: unknown) => error instanceof HttpFailure && error.classification === "permanent",
    );
  });
});
