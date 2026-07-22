# Feature Spec: Subscription health monitor

- **Feature id:** 008-subscription-health-monitor
- **Roadmap item:** specs/roadmap.md item 8
- **Status:** spec

## Problem

BC silently drops an external business event subscription when the subscriber's
endpoint returns anything other than 408 / 429 / 5xx (a 404 after a redeploy, a 401
on an expired token). There is no built-in alert, and a dropped subscription looks
exactly like a quiet feed, so the gap is found only when someone downstream
complains. The fix is to check actively on a schedule and alert on any expected
subscription that has gone missing.

## Users and roles

- **The platform / Job Queue** runs the monitor on a schedule.
- **Operations** maintain the expected-subscription set and act on alerts.
- **The integration layer** supplies the live subscription list (see the design note;
  BC makes no outbound call).

## Scope

- An **expected-subscription configuration** table and maintenance page: the set the
  integration expects to exist, so registering an integration also registers its
  monitoring expectation.
- A **Job Queue monitor** that diffs the expected set against the live set and raises
  an alert plus telemetry for each missing subscription.
- An **extension point** (`OnCollectLiveSubscriptions`) the integration layer
  subscribes to, supplying the live subscription keys. This keeps the core free of
  any `HttpClient`, honouring the constitution's absolute boundary rule; the layer
  that registered the subscriptions is the natural source of the live list.
- An **alert extension point** (`OnMissingSubscription`) so operations can wire email
  / Teams / a ticket without changing the core.
- Permission set additions.

## Out of scope

- The actual transport that fetches live subscriptions from the runtime API (the
  integration layer owns it; the core never calls out).
- Auto re-registering a dropped subscription (an operational decision).

## User flow

1. Ops records the expected subscriptions (event name + notification URL).
2. The monitor runs on its Job Queue schedule. It collects the live subscription keys
   through the extension point and diffs them against the expected set.
3. For each expected subscription missing from the live set, it emits warning
   telemetry (event name and URL) and raises the missing-subscription event for
   alerting.
4. Ops re-registers the dropped subscription before the gap grows.

## Acceptance criteria

- [ ] Given an expected subscription that is present in the live set, when the monitor
      runs, then no alert is raised for it.
- [ ] Given an expected subscription that is absent from the live set, when the monitor
      runs, then exactly one missing-subscription alert and one warning telemetry entry
      are produced for it, carrying the event name and notification URL.
- [ ] Given no expected subscriptions configured, when the monitor runs, then it
      completes without error and raises no alerts.
- [ ] Given the live set is supplied by a subscriber to the collection event, then the
      monitor uses it; with no subscriber the live set is empty and every expected
      subscription is reported missing (fail loud, not silent).
- [ ] Given any object this feature defines, then it is in the Integration Foundation
      permission set.

## Data and rules

- The subscription key is `EventName|NotificationURL`; expected and live keys are
  compared on that exact string.
- A missing subscription is an incident, not a filterable warning (telemetry
  Verbosity Warning).
- The core raises no `HttpClient` call; the live list arrives through the event.

## Telemetry and audit

- INT-0011 (Warning): an expected subscription is missing, with `eventName` and
  `notificationUrl` dimensions.
- INT-0012 (Normal): the monitor ran, with the expected and missing counts.

## Open questions

None blocking. Auto re-registration stays an operational, out-of-scope decision.
