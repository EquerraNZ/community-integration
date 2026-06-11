# Feature Plan: Subscription health monitor

- **Feature id:** 008-subscription-health-monitor
- **Spec:** ./spec.md
- **Status:** planned

## Approach

A small configuration table holds the expected subscriptions; a Job Queue codeunit
diffs them against a live set collected through an integration event, and raises an
alert plus telemetry for each missing one. The live-set collection is an event
(`OnCollectLiveSubscriptions`) rather than an HTTP call, so the core stays free of
`HttpClient` per the constitution; the integration layer (which registered the
subscriptions) subscribes and supplies the list.

## Standard BC reused

- **Job Queue Entries** for scheduling (hourly, by configuration).
- **Session.LogMessage** for the alert telemetry.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration Expected Subscription | table | 73298403 | new | The expected-subscription set. |
| Integration Expected Subscriptions | page | 73298445 | new | Maintain the expected set (List). |
| Subscription Health Monitor | codeunit | 73298435 | new | Job Queue runner: diff, alert, telemetry, extension points. |
| Integration Foundation | permissionset | 73298460 | extend | Add the table, page, codeunit. |

## Data model

**Integration Expected Subscription** (PK `Event Name`, `Notification URL`):
`Event Name` Text[100], `Notification URL` Text[250]. DataClassification
SystemMetadata (endpoint configuration, not PII).

## Integration points

- No `HttpClient`. `OnCollectLiveSubscriptions(var LiveSubscriptions: List of [Text])`
  is the seam the integration layer fills with the live subscription keys.
- `OnMissingSubscription(ExpectedSubscription)` is the alert seam for ops wiring.

## Cross-cutting

- Permissions: add the table (RIMD), page (X), codeunit (X).
- Telemetry: INT-0011 (Warning, missing), INT-0012 (Normal, monitor ran), with
  DataClassification SystemMetadata and no PII.
- Upgrade: greenfield table, additive.
- Performance: the diff is a single pass over a small configuration table against an
  in-memory list; negligible cost per scheduled run.

## Risks and decisions

- **No HttpClient resolution.** The constitution forbids `HttpClient`, but the
  canonical pattern fetches live subscriptions from the runtime API over HTTP. The
  decision is to delegate that fetch to the integration layer through
  `OnCollectLiveSubscriptions`, keeping BC call-free. With no subscriber the live set
  is empty, so the monitor fails loud (reports everything missing) rather than silent.
- **Key format coupling.** Expected and live keys must both be `EventName|URL`; the
  format is documented on the collection event so the subscriber matches it.

## Test strategy

Tests seed expected subscriptions, supply a live set via a test subscriber to
`OnCollectLiveSubscriptions`, run `CheckHealth`, and assert: a present subscription
raises nothing; an absent one raises exactly one alert (counted via a test subscriber
to `OnMissingSubscription`); an empty expected set completes cleanly; no live
subscriber means everything is reported missing.
