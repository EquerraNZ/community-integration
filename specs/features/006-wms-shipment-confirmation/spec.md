# Feature Spec: WMS shipment confirmation

- **Feature id:** 006-wms-shipment-confirmation
- **Roadmap item:** specs/roadmap.md item 6
- **Business process:** 3 (confirm the shipment), inbound + long-running
- **Status:** spec

## Problem

When the WMS confirms a shipment, BC must post the warehouse shipment (and the
invoice if configured), record carrier and tracking, and handle partial / short
shipments through standard quantities, without a re-sent confirmation posting twice.
This is the long-running arrow: the confirmation arrives later as a fresh inbound
message that links back to the fulfilment request by correlation id.

## Users and roles

- **The integration layer** POSTs the WMS confirmation to the inbound API page with
  `messageType = WmsShipmentConfirmation`.
- **The dispatcher** routes it to the WMS shipment handler.
- **Operations** see the posted shipment and the resolved message.

## Scope

- A **WmsShipmentConfirmation** message type implementing the handler.
- A **handler** that parses the confirmation, finds the Sales Order (by bcOrderNo or
  by the order number), sets `Qty. to Ship` per line from the shipped quantities,
  records tracking, and posts the shipment (and invoice if `Post Invoice On
  Shipment` is set), through standard posting.
- **Idempotency** on the WMS `shipmentId` (the external reference): a re-sent
  confirmation posts no second shipment.
- **Correlation**: the message links back to the fulfilment request outbound message
  by correlation id (Parent Message ID).
- **Partial / short shipment**: a shipped quantity below the ordered quantity posts a
  partial shipment and leaves the rest open (standard `Qty. to Ship`).
- Permission set additions.

## Out of scope

- Notifying the Webstore (feature 007, fired by the shipment posting).
- Returns / RMAs and back-orders (non-goals).
- Carrier master-data setup; carrier is recorded as supplied, tracking on the order.

## User flow

1. A staged WmsShipmentConfirmation message is New.
2. The dispatcher runs the handler. It parses the payload and finds the Sales Order.
3. It sets each line's `Qty. to Ship` from the shipped quantities (lines not in the
   confirmation ship zero), records the tracking number, and links the message to
   the fulfilment request by correlation id.
4. It posts the shipment (and invoice if configured) through standard posting,
   inside the dispatcher's per-message transaction.
5. It records the posted shipment number on the message and resolves it. A re-sent
   confirmation with the same `shipmentId` dedups at staging and posts nothing more.

## Acceptance criteria

- [ ] Given a confirmation for an order with all lines fully shipped, when the handler
      runs, then a posted Sales Shipment exists for the order, the message Document No.
      is the posted shipment number, the tracking number is recorded, and the message
      is Resolved.
- [ ] Given the same `shipmentId` delivered twice, when both are processed, then only
      one posted shipment exists (the second dedups at staging).
- [ ] Given a confirmation that short-ships a line (shipped quantity below ordered),
      when the handler runs, then the shipment posts the shipped quantity and the
      remainder stays open on the order.
- [ ] Given `Post Invoice On Shipment` is set, when the handler runs, then the invoice
      is posted in the same run; when it is not set, only the shipment posts.
- [ ] Given a confirmation whose SKU is unmapped or whose order cannot be found, when
      the handler runs, then nothing is posted (rolled back) and the message Fails
      Permanent with a clear error.
- [ ] Given the confirmation, when resolved, then the message Parent Message ID links
      to the fulfilment request outbound message sharing the correlation id (when one
      exists).
- [ ] Given any object this feature defines, then it is in the Integration Foundation
      permission set.

## Data and rules

- `shipmentId` is the external reference and idempotency key.
- `reference` (order number) is the correlation id linking to the fulfilment request.
- Shipped quantities drive standard `Qty. to Ship`; short shipment leaves the rest
  open; lines absent from the confirmation ship zero.
- Posting runs inside the dispatcher's per-message transaction with commit suppressed,
  so a failure rolls back cleanly and a transient error can retry.

## Telemetry and audit

Reuses the feature 001 dispatch telemetry. The posted shipment number is recorded on
the message; no payload or PII is logged.

## Open questions

Open question 2 (invoice posting): resolved here as posting the invoice in the same
handler run when configured, inside the same transaction, rather than a separate
staged stage. Revisit if invoicing needs an independent retry boundary.
