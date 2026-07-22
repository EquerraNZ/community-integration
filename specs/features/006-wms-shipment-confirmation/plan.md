# Feature Plan: WMS shipment confirmation

- **Feature id:** 006-wms-shipment-confirmation
- **Spec:** ./spec.md
- **Status:** planned

## Approach

One enum value plus one handler. The handler parses the confirmation, finds the
order, sets `Qty. to Ship` per line from the shipped quantities, records tracking,
links the correlation parent, and posts through standard `Codeunit "Sales-Post"`
with commit suppressed so it stays inside the dispatcher's per-message transaction.
Idempotency is the staging dedup on `shipmentId`.

## Standard BC reused

- **Sales-Post** (Codeunit 80) for shipment and optional invoice posting.
- **Sales Header / Sales Line** `Qty. to Ship` mechanics for partial / short ship.
- **Sales Shipment Header** to read back the posted shipment number.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| WMS Message Types | enumextension | 73298416 | new | Adds WmsShipmentConfirmation (ordinal 20) implementing the handler. |
| WMS Shipment Handler | codeunit | 73298428 | new | Parse, set quantities, post, resolve. |
| Integration Foundation | permissionset | 73298460 | extend | Add the handler; grant posting tabledata. |

## Data model

No new tables. Writes Sales Header / Sales Line quantities and tracking; posts via
standard routines producing a Sales Shipment Header (and invoice). Sets the message
Parent Message ID and Document No.

## Integration points

- Inbound only; consumes the staged confirmation. No `HttpClient`.
- SKU resolution through `Integration SKU Mgt.`.
- Idempotency: staging dedup on `(shipmentId, WmsShipmentConfirmation)`.
- Correlation: link to the fulfilment outbound message by `(reference,
  FulfilmentRequest)` for the Parent Message ID.

## Cross-cutting

- Permissions: add `codeunit "WMS Shipment Handler" = X` and the posting tabledata
  the run touches (`tabledata "Sales Shipment Header" = R`, plus the sales
  tabledata already granted). Posting permissions otherwise come from the user's
  base license.
- Telemetry: reuses 001 dispatch events.
- Upgrade: enum value additive (ordinal 20 fixed).
- Performance: bounded lines; posting is the dominant cost and is standard. The
  order/line lookups use keys, no table scans.

## Risks and decisions

- **Posting inside the handler.** Allowed because it runs from the Job Queue
  dispatcher over staged data, not inline in a webhook (the rule forbids posting in
  the intake path, not in the processor). `SetSuppressCommit(true)` keeps it in the
  dispatcher transaction so the per-message rollback and retry hold.
- **Invoice in the same run.** Resolves open question 2: invoice posts with the
  shipment when configured. If an independent retry boundary is later needed, split
  into a staged invoice stage.
- **Order match.** Prefer `bcOrderNo`; fall back to the order number on the Webstore
  customer. A missing order fails Permanent.

## Test strategy

Tests seed an order (from 004), stage a confirmation, run the dispatcher, and
assert: a posted shipment with tracking and the shipment no. on the message; a
duplicate `shipmentId` posts once; a short-ship leaves the remainder open; the
invoice posts only when configured; an unmapped SKU or missing order fails Permanent
with nothing posted; the Parent Message ID links the fulfilment outbound message.
