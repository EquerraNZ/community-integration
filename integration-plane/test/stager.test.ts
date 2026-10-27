import { beforeEach, describe, expect, it, vi } from "vitest";

const park = vi.fn(async () => undefined);
vi.mock("../src/shared/serviceBus.js", () => ({
  sendEnvelope: vi.fn(async () => undefined),
  park,
  deliveryCountOf: () => 1,
  PARKED_QUEUE: "parked",
}));

const { handleStage } = await import("../src/shared/stager.js");
const { HttpFailure } = await import("../src/shared/classify.js");
const { envelopeFor, testContext, entryFor } = await import("./helpers.js");

const CONFIG = { flow: "webstore-order", messageType: "WebstoreOrder" } as const;

function bcStub(behaviour: () => Promise<unknown>) {
  return { stageMessage: vi.fn(behaviour) } as never;
}

beforeEach(() => {
  park.mockClear();
});

describe("handleStage", () => {
  it("stages the envelope with its message type and completes", async () => {
    const bc = bcStub(async () => ({ outcome: "created", bcMessageId: "bc-1" }));
    const context = testContext();

    await handleStage(CONFIG, envelopeFor("webstore-order", "DG-00001"), context, bc);

    expect(entryFor(context, "stage.succeeded")?.["bcMessageId"]).toBe("bc-1");
    expect(park).not.toHaveBeenCalled();
  });

  it("completes a duplicate without parking it", async () => {
    const bc = bcStub(async () => ({ outcome: "duplicate", bcMessageId: "bc-existing" }));
    const context = testContext();

    await handleStage(CONFIG, envelopeFor("webstore-order", "DG-00001"), context, bc);

    expect(entryFor(context, "stage.succeeded")?.["reason"]).toBe("already staged");
    expect(park).not.toHaveBeenCalled();
  });

  it("rethrows a transient failure so the broker redelivers", async () => {
    // Retry is the broker's decision, and the delivery count is the only budget.
    const bc = bcStub(async () => {
      throw new HttpFailure("Business Central", 503);
    });

    await expect(handleStage(CONFIG, envelopeFor("webstore-order", "DG-00001"), testContext(), bc)).rejects.toThrow(
      HttpFailure,
    );
    expect(park).not.toHaveBeenCalled();
  });

  it("parks a permanent failure and does not throw", async () => {
    const bc = bcStub(async () => {
      throw new HttpFailure("Business Central", 400, "bad payload");
    });
    const context = testContext();

    await expect(
      handleStage(CONFIG, envelopeFor("webstore-order", "DG-00001"), context, bc),
    ).resolves.toBeUndefined();

    expect(park).toHaveBeenCalledTimes(1);
    expect(entryFor(context, "stage.failed")?.["classification"]).toBe("permanent");
  });

  it("records the delivery count, so a retry is visible as a retry", async () => {
    const bc = bcStub(async () => ({ outcome: "created", bcMessageId: "bc-1" }));
    const context = testContext();

    await handleStage(CONFIG, envelopeFor("webstore-order", "DG-00001"), context, bc);

    expect(entryFor(context, "stage.started")?.["deliveryCount"]).toBe(1);
  });

  it("refuses a queue message that is not an envelope", async () => {
    const bc = bcStub(async () => ({ outcome: "created", bcMessageId: "bc-1" }));
    await expect(handleStage(CONFIG, { not: "an envelope" }, testContext(), bc)).rejects.toThrow(/not an envelope/);
  });
});
