import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { compareSubscriptions } from "../src/shared/subscriptionHealth.js";
import { EVENT_ROUTES, expectedSubscriptions, routeFor } from "../src/shared/eventRoutes.js";
import { resetConfigCache } from "../src/shared/config.js";
import { checkSubscriptionHealth } from "../src/functions/checkSubscriptionHealth.js";
import { entryFor, steps, testContext } from "./helpers.js";

const ENDPOINT = "https://func-intplane-dev-aue.azurewebsites.net/api/bc/events";
const SAVED = { ...process.env };

beforeEach(() => {
  resetConfigCache();
  process.env["BC_EVENT_ENDPOINT_URL"] = ENDPOINT;
});

afterEach(() => {
  process.env = { ...SAVED };
  resetConfigCache();
});

describe("expectedSubscriptions", () => {
  it("is derived from the routing table, so a new route cannot leave the check behind", () => {
    const expected = expectedSubscriptions();
    expect(expected).toHaveLength(EVENT_ROUTES.length);
    for (const route of EVENT_ROUTES) {
      expect(expected.some((s) => s.eventName === route.eventName)).toBe(true);
      expect(routeFor(route.eventName)).toBeDefined();
    }
  });
});

describe("compareSubscriptions", () => {
  it("reports healthy when everything expected is present", () => {
    const report = compareSubscriptions(expectedSubscriptions(), expectedSubscriptions());
    expect(report.healthy).toBe(true);
    expect(report.missing).toHaveLength(0);
  });

  it("reports an absent subscription", () => {
    const [, second] = expectedSubscriptions();
    const report = compareSubscriptions(expectedSubscriptions(), [second!]);
    expect(report.healthy).toBe(false);
    expect(report.missing[0]?.reason).toBe("absent");
  });

  it("treats a subscription pointing elsewhere as missing", () => {
    // It exists, and it delivers nothing here. Counting it as present would
    // report health while the plane was deaf.
    const actual = expectedSubscriptions().map((s) => ({ ...s, notificationUrl: "https://elsewhere.example/api" }));
    const report = compareSubscriptions(expectedSubscriptions(), actual);
    expect(report.healthy).toBe(false);
    expect(report.missing.every((m) => m.reason === "wrong-endpoint")).toBe(true);
  });

  it("ignores a trailing slash and casing on the endpoint", () => {
    const actual = expectedSubscriptions().map((s) => ({ ...s, notificationUrl: `${s.notificationUrl.toUpperCase()}/` }));
    expect(compareSubscriptions(expectedSubscriptions(), actual).healthy).toBe(true);
  });
});

describe("checkSubscriptionHealth", () => {
  const timer = {} as never;

  it("does nothing and raises nothing when everything is present", () => {
    const bc = {
      listEventSubscriptions: vi.fn(async () => expectedSubscriptions()),
      createEventSubscription: vi.fn(async () => undefined),
    } as never;
    const context = testContext();

    return checkSubscriptionHealth(timer, context, bc).then(() => {
      expect(steps(context)).toContain("health.healthy");
      expect(steps(context)).not.toContain("health.drift");
    });
  });

  it("re-registers a missing subscription and still reports drift", async () => {
    // The fix is mechanical and waiting for a person extends the outage. The
    // alert is about the cause, not the recovery.
    const create = vi.fn(async () => undefined);
    const bc = {
      listEventSubscriptions: vi.fn(async () => []),
      createEventSubscription: create,
    } as never;
    const context = testContext();

    await checkSubscriptionHealth(timer, context, bc);

    expect(create).toHaveBeenCalledTimes(EVENT_ROUTES.length);
    expect(steps(context)).toContain("health.drift");
    expect(steps(context)).toContain("health.reregistered");
  });

  it("never reports healthy when it could not reach BC", async () => {
    const bc = {
      listEventSubscriptions: vi.fn(async () => {
        throw new Error("BC unreachable");
      }),
      createEventSubscription: vi.fn(async () => undefined),
    } as never;
    const context = testContext();

    await checkSubscriptionHealth(timer, context, bc);

    expect(steps(context)).toContain("health.failed");
    expect(steps(context)).not.toContain("health.healthy");
  });

  it("reports a failed re-registration with the event name and carries on", async () => {
    const bc = {
      listEventSubscriptions: vi.fn(async () => []),
      createEventSubscription: vi.fn(async () => {
        throw new Error("create refused");
      }),
    } as never;
    const context = testContext();

    await checkSubscriptionHealth(timer, context, bc);

    expect(entryFor(context, "health.failed")?.["eventName"]).toBe(EVENT_ROUTES[0]?.eventName);
  });
});
