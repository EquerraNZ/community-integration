# Feature Plan: Fulfilment request event

- **Feature id:** 005-fulfilment-request-event
- **Spec:** ./spec.md
- **Status:** planned

## Approach

A thin release subscriber delegates to a fulfilment management codeunit that builds
the DTO, stages the outbound parent message, and raises the external business event.
The event lives in a shared outbound-events codeunit (one per integration version),
so feature 007 adds its event to the same object. Delivery is platform-managed and
post-commit, so it is safe to raise inside the release path.

## Standard BC reused

- **Release Sales Document** integration event `OnAfterReleaseSalesDoc` as the
  release hook.
- **Platform external business events** for async, post-commit, retried delivery.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Fulfilment Message Types | enumextension | 73298415 | new | Adds FulfilmentRequest (ordinal 30), outbound, default handler. |
| Integration Event Category | enum | 73298418 | new | Category for the external business events. |
| Integration Outbound Events | codeunit | 73298430 | new | Holds OnSalesOrderReleased_v1 (and later OnShipmentConfirmed_v1). |
| Fulfilment Request Mgt. | codeunit | 73298431 | new | Build DTO, stage outbound, raise event. |
| Subs-Sales Release | codeunit | 73298432 | new | Thin subscriber on sales release. |
| Integration Foundation | permissionset | 73298460 | extend | Add the new codeunits. |

## Data model

No new tables. Stages an outbound Integration Message via `StageOutbound`. Reads
Sales Header / Sales Line and the SKU mapping (reverse lookup).

## Integration points

- Outbound only, via `[ExternalBusinessEvent]`. No `HttpClient`.
- Idempotency: the order number is the reference the integration layer uses as the
  WMS Idempotency-Key; the outbound message is keyed `(orderNo, FulfilmentRequest)`.
- Correlation: order number set as the correlation id on the outbound message and
  the event payload.

## Cross-cutting

- Permissions: add the three codeunits (X); reuses message + sales tabledata grants.
- Telemetry: outbound-staged INT-0006 from feature 001.
- Subscriber discipline: `Subs-Sales Release` is single-purpose and thin; exits on
  temp record, preview, non-Normal execution mode, wrong document type, and
  non-Webstore customer before delegating.
- Upgrade: enum value additive (ordinal 30 fixed); the event is versioned
  (`OnSalesOrderReleased_v1`, Version '1.0') and its signature is frozen; a change
  is a new `_v2`.

## Risks and decisions

- **Event signature drift.** `OnAfterReleaseSalesDoc` is subscribed by exact
  signature; a mismatch is a compile error (not a silent no-fire), and
  `al-event-subscriber-auditor` verifies it against the symbols.
- **What triggers fulfilment.** Only orders on the Webstore customer, to avoid
  asking the WMS to ship unrelated sales orders. Documented and guarded.

## Test strategy

A test releases a Webstore-customer order with mapped items and asserts: one
outbound message staged (Awaiting Reply, correlation id = order no); the DTO built
by the management codeunit carries reverse-mapped SKUs and the right quantities; a
non-Webstore order stages nothing. The external event raise is exercised through the
management codeunit path (the event procedure body is empty by design).
