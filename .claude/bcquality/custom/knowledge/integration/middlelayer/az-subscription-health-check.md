---
bc-version: [all]
domain: integration
keywords: [azure, business-events, subscription, health-check, expiry, drift, webhook, middle-layer]
technologies: [ps1]
countries: [w1]
application-area: [all]
---

# Health-check Business Event subscriptions from the plane

## Description

When the plane relies on Business Central Business Event (or API webhook) subscriptions to be notified of changes, those subscriptions are a silent point of failure. BC webhook subscriptions expire on their own (around three days) and must be renewed, and BC removes a subscription with no warning if the receiver returns a bad response a few times in a row. Either way the symptom is identical and quiet: events simply stop arriving, nothing errors, and the gap is noticed only when someone asks why data went stale. This is the plane-side companion to `al-monitor-external-event-subscription-health.md`: BC should monitor the subscriptions it created, and the plane that depends on them should independently verify they still exist and alert on drift, because the two sides fail at different layers.

A plane that never checks its subscriptions is trusting a lease that expires by design and a delivery that is removed on error, with no alarm on either.

## Best Practice

Run a scheduled job (a timer-triggered Function or a scheduled PowerShell/pipeline task) that lists the current BC subscriptions, compares them against the set the plane expects, and renews or recreates any that are missing or near expiry. Alert when the live set drifts from the expected set, that alert is the only thing that catches a silently removed subscription. Emit the result to the same telemetry sink as the rest of the plane (see `az-observability-wired.md`). See `az-subscription-health-check.good.ps1`.

## Anti Pattern

A plane that creates its subscriptions once at deploy time and never checks them again, with no renewal and no drift alert. The detection signal: subscriptions registered during provisioning with no scheduled task that lists and reconciles them, and no alert on a missing or expiring subscription. The consequence is events that stop silently on expiry or after a transient receiver outage, discovered days later as stale data. See `az-subscription-health-check.bad.ps1`.

## See also

- `al-monitor-external-event-subscription-health.md`
- `az-observability-wired.md`
- `az-correlation-header.md`
