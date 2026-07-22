# Feature Plan: Webstore despatch notify

- **Feature id:** 007-webstore-despatch-notify
- **Spec:** ./spec.md
- **Status:** planned

## Approach

A thin subscriber on `Sales Shipment Header` insert (a stable table event, low
signature-drift risk) delegates to a despatch management codeunit. The codeunit is
idempotent on the order number: it stages the outbound message and raises the event
only if no despatch notification exists yet for that order, so a second partial
shipment does not double-notify. The event lives in the shared outbound-events
codeunit alongside OnSalesOrderReleased_v1.

## Standard BC reused

- **Sales Shipment Header** `OnAfterInsertEvent` as the post-shipment hook.
- **Platform external business events** for async, post-commit, retried delivery.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Despatch Message Types | enumextension | 73298417 | new | Adds DespatchNotification (ordinal 40), outbound, default handler. |
| Integration Outbound Events | codeunit | 73298430 | extend | Adds OnShipmentConfirmed_v1. |
| Despatch Notification Mgt. | codeunit | 73298433 | new | Idempotent stage + raise. |
| Subs-Sales Shipment | codeunit | 73298434 | new | Thin subscriber on shipment insert. |
| Integration Message Mgt. | codeunit | 73298420 | extend | Add OutboundExists for the idempotency guard. |
| Integration Foundation | permissionset | 73298460 | extend | Add the new codeunits. |

## Data model

No new tables. Stages an outbound Integration Message; reads Sales Shipment Header.

## Integration points

- Outbound only, via `[ExternalBusinessEvent]`. No `HttpClient`.
- Idempotency: at most one DespatchNotification per order number, enforced by the
  `OutboundExists` guard and backed by the unique `(External Reference, Type)` key.
- Correlation: order number as correlation id on the message and the event.

## Cross-cutting

- Permissions: add the two new codeunits (X); reuse message + shipment tabledata.
- Telemetry: outbound-staged INT-0006.
- Subscriber discipline: `Subs-Sales Shipment` is single-purpose and thin; exits on
  temp record, non-Normal execution mode, and non-Webstore customer before
  delegating.
- Upgrade: enum value additive (ordinal 40 fixed); the event is versioned
  (`OnShipmentConfirmed_v1`, '1.0') with a frozen signature.

## Risks and decisions

- **Double notify on partial shipment.** Guarded by `OutboundExists`: the second
  shipment finds an existing DespatchNotification and exits. Without this guard the
  unique key would throw inside the posting transaction.
- **Timestamp source.** Despatch timestamp is the current time at notification, which
  is close enough to the post; the storefront only needs a despatched-at marker.

## Test strategy

Tests post a shipment for a Webstore order and assert: one outbound
DespatchNotification message (correlation id = order no); a second shipment on the
same order stages nothing more; a non-Webstore order notifies nothing. The event
raise is exercised through the management codeunit (the event body is empty).
