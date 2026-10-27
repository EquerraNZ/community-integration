# Feature Spec: Plane Health and Alerting

> The counterpart to `008`. BC watches its own subscriptions; this watches whether BC
> can still reach the plane, and whether anything has quietly stopped moving.

- **Feature id:** 012-plane-health-and-alerting
- **Roadmap item:** #12 in specs/roadmap.md
- **Status:** in-progress

## Problem

The failure this whole design is built around is the silent one. An external business
event subscription expires after about three days, and BC removes it without warning
when a delivery fails repeatedly. Nothing errors. Orders keep arriving, shipments keep
posting, and the WMS simply stops being told. By the time someone notices, it is
because a customer asked where their coffee is.

`008` added the BC-side monitor that lists subscriptions and alerts on a missing one.
That covers BC's view. It does not cover the plane's: a dead-lettered message nobody
looks at is the same silence from the other end, and a subscription that was never
re-registered after an outage stays missing until someone registers it.

## Users and roles

- **Operations:** receives the alert, and wants it to say which flow and what to do,
  not that a metric crossed a threshold.
- **The plane itself:** re-registers a missing subscription without waiting for a
  person, because the fix is mechanical and the delay is the damage.

## Scope

- `checkSubscriptionHealth`: a timer function, every six hours. Lists BC's external
  business event subscriptions, compares them with the expected set, re-registers any
  that are missing, and logs the outcome either way.
- An alert on the health check reporting drift, so a re-registration is visible even
  though it succeeded.
- Alert rules on dead-letter message count per queue, wired to the action group from
  `009`.
- Unit tests over the comparison and the re-registration decision.

## Out of scope

- Replaying a dead-lettered message. Today that is an Azure portal action, and
  whether BC should be able to ask for a replay is parked (tech design question 9).
- Paging, rosters, or an incident tool. The action group is the seam; what hangs off
  it is an operations decision, not a code one.
- Re-registering a subscription for an event the plane does not route. If
  `eventRoutes.ts` does not know it, the plane has no business subscribing to it.

## User flow

1. The timer fires. The function lists BC's subscriptions.
2. Every expected subscription is present. It logs a healthy result and stops. Nothing
   alerts, because a healthy check that alerts is a check people learn to ignore.
3. One is missing. The function re-registers it, logs the drift with the event name,
   and the drift alert fires so someone knows the plane went deaf and for how long.
4. Separately, a message dead-letters. The queue's alert fires naming the queue, and
   operations opens the dead-letter queue to see the body and the reason.

## Acceptance criteria

- [ ] Given every expected subscription present, when the check runs, then it reports
      healthy, re-registers nothing, and raises no alert.
- [ ] Given a missing subscription, then the check re-registers it, reports drift
      naming the event, and the drift alert fires.
- [ ] Given a subscription present but pointing at a different endpoint, then it is
      treated as missing and re-registered, because a subscription aimed elsewhere
      delivers nothing here.
- [ ] Given BC unreachable when the check runs, then it reports the failure and does
      not report healthy. A check that cannot tell must never say everything is fine.
- [ ] Given re-registration failing, then the failure is reported with the event name
      and the error, and the next run tries again.
- [ ] Given a message on any dead-letter queue, then that queue's alert fires naming
      the queue.
- [ ] Given the expected set, then it is derived from the plane's own routing table
      rather than written out a second time, so adding a route cannot leave the check
      behind.

## Data and rules

No persistent data. The expected set is derived from `eventRoutes.ts`, which is the
same table `receiveBusinessEvent` routes on. That is the rule that matters: one
definition of what this plane handles, used both to route and to check, so the two
cannot disagree.

| Signal | Source | Threshold | Means |
|---|---|---|---|
| Subscription drift | the health check's own log | any drift | BC stopped reaching the plane; it has been fixed, find out why |
| Dead-letter count | Service Bus metric, per queue | greater than zero | a message could not be delivered within its retries; the body is on the DLQ |
| Health check failure | the health check's own log | any failure | the check itself could not run; the plane's health is unknown, not good |

## Telemetry and audit

Check started, subscriptions listed (count), healthy, drift detected (event name),
re-registered (event name), re-registration failed (event name, error), check failed
(error). Correlation id is not meaningful here, so these log with the check's own run
id instead, and that is deliberate rather than an omission.

## Open questions

1. The exact BC API for listing and creating an external business event subscription,
   and the shape of the validation handshake (tech design question 6). The check is
   written against configuration so the endpoint is a parameter, but the response
   shape is not, and this is the part most likely to need adjusting on first contact.
2. Whether six hours is the right interval. It is well inside the roughly three-day
   expiry, and the cost of checking more often is close to nothing, so the case for
   something shorter is the time spent deaf, not the price.
