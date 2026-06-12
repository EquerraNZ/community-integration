# Feature Plan: Webstore Shipment Notify

> From approved `spec.md`. Subscribe to shipment posting, build the Webstore
> status-update payload, stage outbound message, raise business event.

- **Feature id:** 005-webstore-shipment-notify
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Subscribe to the Sales-Post completion event. When a Sales Shipment is posted
from an order that has an External Document No. (Webstore marker), build the
status payload, stage an outbound Integration Message, and raise
OnAfterShipmentNotify on the Integration Events codeunit. The integration layer
subscribes externally and PATCHes the Webstore.

## Standard BC reused

- **Sales Shipment Header**: read the posted shipment to get Order No. and
  Posting Date.
- **Sales Header**: read External Document No. from the originating order.
- **Sales-Post events**: subscribe to OnAfterPostSalesDoc to detect shipment
  posting.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Webstore Shipment Notify Type | enumextension | 73298421 | extend Integration Message Type | Add "Webstore Shipment Notify" value |
| Webstore Ship. Notify Proc. | codeunit | 73298421 | new | No-op processor (outbound-only) |
| Webstore Shipment Notify | codeunit | 73298422 | new | Subscribes to posting event, builds payload, stages message, raises event |
| Integration Events | codeunit | 73298452 | extend | Add OnAfterShipmentNotify business event |

## Data model

No new tables. Uses existing Integration Message table.

- Type = "Webstore Shipment Notify" (new enum value 73298421)
- Idempotency Key = `{External Document No.}-SHIP`
- Correlation ID = derived from External Document No.
- Request Content = `{ "status": "Despatched", "bcOrderNo": "...", "despatchedAt": "..." }`

## Integration points

- **Event subscribed**: OnAfterPostSalesDoc (codeunit 80 "Sales-Post").
  Filter: Ship = true and External Document No. is non-empty.
- **Business event raised**: OnAfterShipmentNotify on "Integration Events"
  codeunit. Parameters: WebstoreOrderNo (Text), Payload (Text).
- **No HTTP call** from BC.

## Cross-cutting

- **Permissions**: codeunits (X). Added in feature 006.
- **Telemetry**: INTMSG-WEB01 on successful staging.
- **Upgrade**: none (new enum value only).
- **Performance**: subscriber runs inline after Sales-Post. One Get on
  Sales Header, one message insert. Negligible.

## Risks and decisions

- **Partial vs. full shipment notify**: the Webstore is idempotent on
  `Despatched`. Notifying on every shipment (including partial) is safe and
  simpler than tracking whether all lines are fully shipped.
- **Idempotency key**: `{External Document No.}-SHIP` means only one
  notification per Webstore order. If multiple partial shipments fire, only the
  first stages a message. This is correct: the Webstore only needs to know
  "shipped" once.

## Test strategy

AL test codeunit: create a released Sales Order with External Document No.,
post it via Sales-Post (Ship = true), assert Integration Message created with
correct payload. Also test: no message for orders without External Document No.,
idempotency on duplicate.
