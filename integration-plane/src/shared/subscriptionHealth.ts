/**
 * Comparing what BC is subscribed to against what the plane can handle.
 *
 * Pure, so the rule that matters is testable without Azure and without BC: a
 * subscription that exists but points somewhere else is missing, because a
 * subscription aimed at another endpoint delivers nothing here, and a check that
 * counted it as present would report health while the plane was deaf.
 */

import type { EventSubscription } from "./bcClient.js";

export type MissingReason = "absent" | "wrong-endpoint";

export interface MissingSubscription {
  expected: EventSubscription;
  reason: MissingReason;
}

export interface HealthReport {
  healthy: boolean;
  missing: MissingSubscription[];
  actualCount: number;
}

export function compareSubscriptions(
  expected: readonly EventSubscription[],
  actual: readonly EventSubscription[],
): HealthReport {
  const missing: MissingSubscription[] = [];

  for (const want of expected) {
    const matches = actual.filter((have) => have.eventName === want.eventName);
    if (matches.length === 0) {
      missing.push({ expected: want, reason: "absent" });
      continue;
    }
    if (!matches.some((have) => sameEndpoint(have.notificationUrl, want.notificationUrl))) {
      missing.push({ expected: want, reason: "wrong-endpoint" });
    }
  }

  return { healthy: missing.length === 0, missing, actualCount: actual.length };
}

function sameEndpoint(a: string, b: string): boolean {
  return normalise(a) === normalise(b);
}

function normalise(url: string): string {
  return url.trim().replace(/\/+$/, "").toLowerCase();
}
