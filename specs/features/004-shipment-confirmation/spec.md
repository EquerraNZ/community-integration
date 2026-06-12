# Feature Spec: Shipment Confirmation

> The what and why for the WMS inbound shipment confirmation processor.

- **Feature id:** 004-shipment-confirmation
- **Roadmap item:** #4 in specs/roadmap.md
- **Status:** spec

## Problem

When the WMS ships goods, BC must record the shipment (full or partial), store
the carrier and tracking number, and optionally post the invoice. Today this is
manual. The extension must accept the WMS shipment-confirmation payload through
the shared inbound path and post the Sales Order shipment automatically.

## Users and roles

- **Integration layer** (external) delivers the WMS confirmation payload to
  the extension's API page.
- **Warehouse coordinator** sees the posted shipment and tracking in BC.
- **Finance** sees the posted invoice (when configured).

## Scope

- New Integration Message Type value "WMS Shipment Confirmation".
- Processor codeunit: parse the shipment-confirmation JSON, find the Sales
  Order, set shipped quantities per line (matching by SKU reverse lookup),
  record carrier and tracking, and post the shipment via standard Sales-Post.
- Partial shipment support: if `shippedQuantity` < ordered quantity on a line,
  post only the shipped amount, leaving the order open for a future shipment.
- Optional invoice posting: if WMS Setup."Post Invoice" is true, post
  Ship + Invoice together.
- Add "Post Invoice" boolean field to WMS Setup table and page.
- Idempotency: the `shipmentId` from the WMS payload is the idempotency key.
  A re-delivered confirmation does not post a second shipment.

## Out of scope

- Creating Warehouse Shipment documents (the extension uses Sales-Post directly
  since there is no warehouse management setup for this simple fulfilment flow).
- Updating the Webstore status (that is feature 005).
- Handling returns or credit memos from the WMS.
- Multi-shipment aggregation (each confirmation is processed independently).

## User flow

1. WMS ships goods and emits a shipment-confirmation payload.
2. Integration layer calls the extension's API page with the payload
   (Type = "WMS Shipment Confirmation", Idempotency Key = shipmentId,
   Correlation ID from the order reference).
3. The core stages and processes the message.
4. The processor parses the JSON, locates the Sales Order by `bcOrderNo`,
   resolves each SKU to an Item No., sets `Qty. to Ship` on matching Sales
   Lines, records Shipping Agent Code and Package Tracking No. on the Sales
   Header, and calls Sales-Post with Ship (and Invoice if configured).
5. On success the Integration Message is Completed and the Document No. field
   holds the posted Sales Shipment No.

Alternate (partial): If `shippedQuantity` < ordered quantity for a line, only
that amount is shipped. The Sales Order remains open for the remaining quantity.

Alternate (duplicate): If `shipmentId` was already processed (idempotency key
exists), the API returns the existing message. No second posting.

Alternate (order not found): If `bcOrderNo` does not match any open Sales Order,
the message fails with a clear error.

## Acceptance criteria

- [ ] Given a valid shipment-confirmation payload, when processed, then the
      Sales Order is partially or fully shipped and the posted Sales Shipment
      exists.
- [ ] Given the payload has `shippedQuantity` < ordered quantity on a line,
      then only the shipped amount posts and the Sales Order remains open.
- [ ] Given the payload has `shippedQuantity` = ordered quantity on all lines,
      then the Sales Order is fully shipped.
- [ ] Given WMS Setup."Post Invoice" is true, when processed, then an invoice
      is also posted.
- [ ] Given WMS Setup."Post Invoice" is false, when processed, then only the
      shipment is posted (no invoice).
- [ ] Given the payload `carrier` and `trackingNumber`, the Sales Header's
      Shipping Agent Code and Package Tracking No. are set before posting.
- [ ] Given a duplicate `shipmentId` (idempotency key already exists), the
      message is not re-processed and no second shipment is posted.
- [ ] Given a `bcOrderNo` that does not match any open Sales Order, the message
      fails with Status = Failed and a descriptive error.
- [ ] Given a `sku` in the payload that cannot be resolved to an Item No.
      via reverse SKU mapping, the message fails with a clear error.
- [ ] The Integration Message Document No. is set to the posted Sales
      Shipment No. on success.
- [ ] Telemetry is emitted on success and failure.

## Data and rules

- **WMS Setup** (existing table, add field): "Post Invoice" (Boolean, default
  false).
- **Inbound Integration Message**: Type = "WMS Shipment Confirmation",
  Idempotency Key = `shipmentId` from the payload, Correlation ID from
  `reference`.
- **SKU resolution**: same reverse lookup as feature 003 (Source from WMS Setup
  "SKU Source", find Item No. by External SKU).
- **Shipping Agent**: the `carrier` text from the payload is written to the
  Sales Header's Shipping Agent Code. If the carrier does not exist in the
  Shipping Agent table, create it on the fly (just the Code, no services).
- **Package Tracking No.**: written to Sales Header."Package Tracking No.".
- **Sales-Post**: called with Ship = true, Invoice = WMS Setup."Post Invoice".

## Telemetry and audit

- INTMSG-WMS03: shipment confirmation processed successfully (dimensions:
  Sales Order No., Shipment No., correlation id).
- INTMSG-WMS04: shipment confirmation failed (dimensions: Sales Order No.,
  error reason, correlation id).

## Open questions

None. The tech-design open questions #2 and #3 are resolved:
- Partial shipment: standard Sales-Post handles partial Qty. to Ship natively.
- Invoice posting: a boolean on WMS Setup controls whether Invoice = true is
  passed to Sales-Post. Posting Ship + Invoice together is safe when the order
  is released and has shipped quantities.
