# Feature Plan: Shipment Confirmation

> From approved `spec.md`. Parse WMS shipment-confirmation JSON, post Sales
> Shipment (partial or full), record carrier and tracking, optionally invoice.

- **Feature id:** 004-shipment-confirmation
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Add a new inbound Integration Message Type ("WMS Shipment Confirmation") with a
processor codeunit that parses the WMS JSON, locates the Sales Order, sets
Qty. to Ship per line, records Shipping Agent and tracking, and calls standard
Sales-Post. Extend WMS Setup with a "Post Invoice" toggle. The standard inbound
path (API page → Stage → Process) handles idempotency and error capture.

## Standard BC reused

- **Sales Header / Sales Line**: locate the order, set Qty. to Ship.
- **Sales-Post** (codeunit 80): posts the shipment (and invoice if configured).
- **Shipping Agent table**: store carrier code (auto-create if missing).
- **Package Tracking No.** on Sales Header: standard field for tracking.
- **Integration SKU Mapping** (from feature 002): reverse lookup SKU → Item No.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Shipment Confirm. Type | enumextension | 73298451 | extend Integration Message Type | Add "WMS Shipment Confirmation" value |
| Shipment Confirm. Proc. | codeunit | 73298453 | new | Implements IIntegration Msg. Processor: parse, post, record |
| WMS Setup | table | 73298450 | extend (add field) | Add "Post Invoice" boolean |
| WMS Setup | page | 73298450 | extend (add field) | Show "Post Invoice" toggle |

## Data model

### WMS Setup (existing table 73298450, add field)

| Field | Type | Default |
|---|---|---|
| Post Invoice | Boolean | false |

### Integration Message (existing, no schema change)

- Type = "WMS Shipment Confirmation" (new enum value 73298451)
- Idempotency Key = `shipmentId` from the WMS payload
- Correlation ID = derived from `reference` (the Webstore order number)
- Request Content = the full confirmation JSON
- Document No. = posted Sales Shipment No. on success

## Integration points

- **Inbound via API page**: the integration layer POSTs the confirmation
  payload. The core stages and processes it using the standard path.
- **No outbound action** in this feature (feature 005 handles the Webstore
  notification).
- **Idempotency**: `shipmentId` as Idempotency Key. Duplicate delivery returns
  existing message from the API page (handled by core).

## Cross-cutting

- **Permissions**: Shipment Confirm. Proc. codeunit (X). To be added in
  feature 006.
- **Telemetry**: INTMSG-WMS03 on success, INTMSG-WMS04 on failure.
- **Upgrade**: New field "Post Invoice" on WMS Setup. No migration needed
  (defaults to false).
- **Performance**: one FindSet over Sales Lines (bounded by order size), one
  SKU Mapping FindFirst per line. Acceptable for typical order sizes.

## Risks and decisions

- **Carrier auto-create**: if the `carrier` text from the WMS does not exist as
  a Shipping Agent Code, the processor creates a minimal Shipping Agent record.
  This keeps processing from failing on an unknown carrier. The code truncates
  the carrier to Code[10].
- **Sales-Post vs. Warehouse Shipment**: the brief describes a simple
  fulfilment (no warehouse management setup). Using Sales-Post with Ship = true
  is simpler and does not require warehouse location setup with "Require
  Shipment". If the tenant later enables full WMS, this would need revisiting.
- **Partial shipment**: Sales-Post natively handles Qty. to Ship < Quantity.
  The order remains open with Outstanding Quantity > 0.

## Test strategy

AL test codeunit using Library - Sales to create released Sales Orders, then
call the processor directly (or use StageAndProcess). Assert:
- Posted Sales Shipment exists with correct quantities.
- Partial shipment leaves order open.
- Invoice posted when toggle is true.
- Carrier and tracking recorded on Sales Header.
- Duplicate shipmentId returns existing (no second post).
- Unknown bcOrderNo fails with error.
- Unmapped SKU fails with error.
- Document No. on Integration Message = posted shipment no.
