/**
 * Watch whether Business Central can still reach the plane.
 *
 * This exists for the one failure mode where nothing errors: a business event
 * subscription expires after about three days, or BC removes it silently after
 * repeated failed deliveries, and from then on orders keep arriving, shipments
 * keep posting, and the WMS simply stops being told. By the time anyone notices
 * it is because a customer asked where their order is.
 *
 * A missing subscription is re-registered without waiting for a person, because
 * the fix is mechanical and the delay is the damage. It alerts anyway: the plane
 * was deaf for up to six hours and the cause is worth knowing, not just the
 * recovery.
 */

import { app, type InvocationContext, type Timer } from "@azure/functions";
import { randomUUID } from "node:crypto";
import { BcClient } from "../shared/bcClient.js";
import { expectedSubscriptions } from "../shared/eventRoutes.js";
import { compareSubscriptions } from "../shared/subscriptionHealth.js";
import { logStep } from "../shared/telemetry.js";

export async function checkSubscriptionHealth(
  _timer: Timer,
  context: InvocationContext,
  bc: BcClient = new BcClient(),
): Promise<void> {
  const runId = randomUUID();
  logStep(context, "health.started", { runId });

  const expected = expectedSubscriptions();

  let actual;
  try {
    actual = await bc.listEventSubscriptions();
  } catch (error) {
    // A check that cannot tell must never report health. Treating an
    // unreachable BC as "no drift" would turn an outage into a green dashboard.
    logStep(context, "health.failed", {
      runId,
      reason: error instanceof Error ? error.message : String(error),
    });
    return;
  }

  logStep(context, "health.listed", { runId, count: actual.length });

  const report = compareSubscriptions(expected, actual);
  if (report.healthy) {
    // Nothing alerts on a healthy run. An alert that fires on every check is one
    // people learn to ignore, and this is the alert that has to be read.
    logStep(context, "health.healthy", { runId, count: report.actualCount });
    return;
  }

  for (const missing of report.missing) {
    logStep(context, "health.drift", {
      runId,
      eventName: missing.expected.eventName,
      reason: missing.reason,
    });

    try {
      await bc.createEventSubscription(missing.expected);
      logStep(context, "health.reregistered", { runId, eventName: missing.expected.eventName });
    } catch (error) {
      // Report and carry on to the next one. There is no retry machinery here on
      // purpose: the check is idempotent and runs again in six hours.
      logStep(context, "health.failed", {
        runId,
        eventName: missing.expected.eventName,
        reason: error instanceof Error ? error.message : String(error),
      });
    }
  }
}

app.timer("checkSubscriptionHealth", {
  // Every six hours, comfortably inside the roughly three-day expiry. The cost of
  // checking is near zero, so the only argument for shorter is how long the plane
  // may be deaf before anyone knows.
  schedule: "0 0 */6 * * *",
  handler: checkSubscriptionHealth,
});
