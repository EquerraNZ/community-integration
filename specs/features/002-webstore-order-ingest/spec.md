# Feature Spec: Webstore Order Ingest

> Receive a Webstore order payload and create a standard Sales Order in BC.

- **Feature id:** 002-webstore-order-ingest
- **Roadmap item:** #2 in specs/roadmap.md
- **Status:** spec

## Problem

Orders placed on the Webstore must reach BC automatically and become standard
Sales Orders. Today this is done by hand (re-keying). The core messaging backbone
(feature 001) provides the staging, idempotency, and dispatch mechanism. This
feature adds the Webstore-specific processing: parsing the order JSON, resolving
SKUs to BC Items, and creating the Sales Order with lines, customer, and address.

## Users and roles

- **Integration layer (machine caller):** delivers the Webstore order JSON to the
  Integration Messages API with Type = "Webstore Order" and Idempotency Key =
  the Webstore order number (e.g. "DG-00001").
- **BC administrator:** configures the Webstore Setup (customer, location,
  posting group defaults). Maintains the SKU-to-Item mapping. Monitors failed
  messages on the Integration Messages list.
- **BC order processor:** reviews and releases the Sales Order created by the
  integration (standard BC workflow from here).

## Scope

- A "Webstore Order" value on the Integration Message Type enum, implementing the
  processor interface to parse the order JSON and create a Sales Order.
- A Webstore Setup table and page (singleton per company): default Customer No.,
  Location Code, and posting configuration for Webstore orders.
- An Integration SKU Mapping table and page: maps an external SKU (e.g.
  "ESP-250") from a named source ("Webstore") to a BC Item No.
- Parsing of the Webstore order JSON payload (structure defined in the brief):
  customer name/address, lines with SKU, quantity, unit price, order number,
  placed-at timestamp.
- Creation of a standard Sales Order (Sales Header + Sales Lines) from the
  parsed payload:
  - Sell-to Customer from Webstore Setup.
  - Ship-to address from the order payload.
  - One Sales Line per order line, Item No. resolved via SKU mapping.
  - External Document No. set to the Webstore order number.
  - Posting Date from the order's placedAt timestamp.
- Storing the BC Sales Order No. (Document No.) back on the Integration Message
  as Document No. for traceability.
- Idempotency: the Webstore order number is the Idempotency Key. A duplicate
  delivery does not create a second Sales Order.

## Out of scope

- Releasing the Sales Order (that triggers the WMS fulfilment request, which is
  feature 003).
- Customer creation or customer template application (the setup points to a
  pre-existing Customer).
- Payment capture or settlement.
- Inventory availability checks.
- Multi-currency (NZD only, per brief).
- Outbound notification to the Webstore (feature 005).

## User flow

### Order ingestion (machine caller)

1. Integration layer receives the Webstore order (brief payload format).
2. It POSTs to the Integration Messages API with:
   - `type`: "Webstore Order"
   - `idempotencyKey`: the Webstore order number (e.g. "DG-00001")
   - `requestContent`: the full order JSON
3. The API stages the message and dispatches processing immediately.
4. The processor parses the JSON, resolves each SKU via the mapping table,
   creates the Sales Order, and sets status to Completed.
5. If a SKU is unmapped: processing fails with a clear error naming the SKU.

### Setup (administrator)

1. Administrator opens Webstore Setup page.
2. Sets the default Customer No. (the Webstore customer in BC).
3. Sets the default Location Code.
4. Opens the Integration SKU Mapping page.
5. Adds entries: Source = "Webstore", External SKU = "ESP-250", Item No. = the
   BC item number. One row per catalogue SKU.

### Monitoring (administrator)

1. A failed message appears on the Integration Messages list with an error
   naming the unmapped SKU or the validation failure.
2. Administrator fixes the mapping or data, then retries the message.

## Acceptance criteria

- [ ] Given a valid Webstore order JSON is staged with Type = "Webstore Order",
      when processing runs, then a Sales Order (Sales Header + Sales Lines) is
      created with the correct Customer, Location, and External Document No.
- [ ] Given the order JSON contains multiple lines, when processing runs, then
      one Sales Line is created per order line with the correct Item No.,
      Quantity, and Unit Price.
- [ ] Given a SKU in the order JSON has a mapping in the Integration SKU Mapping
      table, when the processor resolves it, then the correct BC Item No. is
      returned.
- [ ] Given a SKU in the order JSON has no mapping, when the processor attempts
      to resolve it, then processing fails with an error that names the unmapped
      SKU.
- [ ] Given the same Webstore order number is delivered twice (same Idempotency
      Key), when the second delivery arrives, then no second Sales Order is
      created (core idempotency).
- [ ] Given a valid order is processed, when the Sales Order is created, then the
      Integration Message Document No. is set to the BC Sales Order number.
- [ ] Given the Webstore Setup has no Customer No. configured, when processing
      runs, then it fails with a clear error indicating the missing setup.
- [ ] Given the order JSON contains a ship-to address, when the Sales Order is
      created, then the Ship-to fields on the Sales Header are populated from the
      payload.
- [ ] Given the order has a placedAt timestamp, when the Sales Order is created,
      then the Posting Date is set from that timestamp.

## Data and rules

### Integration SKU Mapping table

| Field | Type | Rule |
|---|---|---|
| Source | Code[20] | PK part 1. Identifies the external system (e.g. "WEBSTORE"). |
| External SKU | Code[50] | PK part 2. The SKU as the external system knows it. |
| Item No. | Code[20] | The BC Item No. Mandatory. TableRelation to Item. |

### Webstore Setup table (singleton)

| Field | Type | Rule |
|---|---|---|
| Primary Key | Code[10] | Single-record pattern (empty key). |
| Customer No. | Code[20] | Mandatory. The BC customer used for all Webstore orders. TableRelation to Customer. |
| Location Code | Code[10] | Optional. Default location on Sales Lines. TableRelation to Location. |

### Order JSON structure (from brief)

```json
{
  "orderNo": "DG-00001",
  "placedAt": "2026-06-11T09:14:00.000Z",
  "currency": "NZD",
  "customer": {
    "name": "Ava Shopper",
    "email": "ava@example.com",
    "phone": "+64 21 555 0101",
    "address": { "line1": "12 Queen Street", "line2": "", "city": "Auckland", "postcode": "1010", "country": "NZ" }
  },
  "lines": [
    { "sku": "ESP-250", "name": "Espresso Blend 250g", "quantity": 2, "unitPrice": 18.50 }
  ],
  "totalAmount": 54.00
}
```

### Processing rules

- Customer No. from Webstore Setup (not from the JSON customer object; the JSON
  address goes to Ship-to fields).
- External Document No. = orderNo from JSON.
- Each line: resolve SKU via Integration SKU Mapping (Source = "WEBSTORE"). If
  not found, error immediately naming the SKU.
- Unit Price on Sales Line from JSON unitPrice (overrides item card price).
- Location Code from Webstore Setup (if set).
- Posting Date = date portion of placedAt (converted from ISO 8601).
- Document No. assigned by standard Sales Order number series.

## Telemetry and audit

| Signal | Dimensions |
|---|---|
| Webstore order processed | Message ID, Correlation ID, Order No., BC Sales Order No. |
| SKU resolution failed | Message ID, Correlation ID, SKU value |

Telemetry tags: INTMSG-W01 (order processed), INTMSG-W02 (SKU resolution failed).

## Open questions

None. All rules are determined by the brief and the tech design.
