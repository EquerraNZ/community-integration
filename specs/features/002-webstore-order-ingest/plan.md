# Feature Plan: Webstore Order Ingest

> Parse inbound Webstore order JSON, resolve SKUs, create a standard Sales Order.

- **Feature id:** 002-webstore-order-ingest
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Add a "Webstore Order" value to the Integration Message Type enum, backed by a
processing codeunit that implements IIntegration Msg. Processor. The processor
reads the JSON from Request Content, resolves SKUs via a mapping table, and
creates a standard Sales Order using Sales Header and Sales Line (standard BC,
no custom document). A Webstore Setup singleton stores the default Customer No.
and Location Code. All standard BC: Sales-Header.Init, Insert, Validate
sequences; Sales-Line.Init, Insert, Validate sequences. No custom posting, no
custom document type.

## Standard BC reused

| Module | How |
|---|---|
| Sales Header / Sales Line | Standard Sales Order creation via record Init + Insert + field validation. |
| Customer table | Webstore Setup points to an existing Customer No. |
| Item table | SKU mapping resolves to Item."No.". |
| Location table | Webstore Setup provides optional Location Code. |
| Number Series (Sales Order Nos.) | Document No. assigned by standard number series on insert. |

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration SKU Mapping | table | 73298420 | new | Maps external SKU to BC Item No. |
| Integration SKU Mapping | page (list) | 73298420 | new | Admin page for managing SKU mappings. |
| Webstore Setup | table | 73298421 | new | Singleton: Customer No., Location Code. |
| Webstore Setup | page (card) | 73298421 | new | Admin setup page. |
| Webstore Order Type | enumextension | 73298420 | extend "Integration Message Type" | Adds value "Webstore Order" with interface implementation. |
| Webstore Order Processor | codeunit | 73298420 | new | Implements IIntegration Msg. Processor: parse JSON, create Sales Order. |

All IDs in the Webstore module allocation (73298420-73298449).

## Data model

### Integration SKU Mapping (table 73298420)

| Field No. | Field | Type | Length | Key |
|---|---|---|---|---|
| 1 | Source | Code | 20 | PK1 |
| 2 | External SKU | Code | 50 | PK2 |
| 3 | Item No. | Code | 20 | — (TableRelation Item) |

### Webstore Setup (table 73298421)

| Field No. | Field | Type | Length | Key |
|---|---|---|---|---|
| 1 | Primary Key | Code | 10 | PK |
| 2 | Customer No. | Code | 20 | — (TableRelation Customer) |
| 3 | Location Code | Code | 10 | — (TableRelation Location) |

### Relationships to standard BC

- Integration SKU Mapping.Item No. → Item."No."
- Webstore Setup.Customer No. → Customer."No."
- Webstore Setup.Location Code → Location.Code
- Created Sales Header: Document Type = Order, Sell-to Customer No. from setup,
  Ship-to from JSON, External Document No. = orderNo.
- Created Sales Lines: Type = Item, No. = resolved Item No., Quantity and Unit
  Price from JSON.

## Integration points

### Inbound (via core)

The integration layer POSTs to the Integration Messages API with:
- `type`: "Webstore Order"
- `idempotencyKey`: the Webstore order number
- `requestContent`: the full order JSON

The core stages, deduplicates (idempotency key), and dispatches to the Webstore
Order Processor.

### No outbound in this feature

The outbound shipment notification is feature 005. This feature only ingests.

## Cross-cutting

### Permissions

New objects added to the extension permission set (feature 006). During dev,
SUPER suffices.

### Telemetry

| Operation | Event ID | Dimensions |
|---|---|---|
| Webstore order processed | INTMSG-W01 | Message ID, Correlation ID, Order No., BC Sales Order No. |
| SKU resolution failed | INTMSG-W02 | Message ID, Correlation ID, SKU |

### Upgrade/migration

First delivery of these tables: no upgrade codeunit needed.

### Performance

- SKU resolution is a Get on PK (Source + External SKU): O(1) per line.
- Sales Order creation is one header insert + N line inserts (N = order line
  count, typically small, under 20). No performance concern.
- No loops over large datasets.

## Risks and decisions

| Decision | Rationale |
|---|---|
| Ship-to from JSON, Sell-to from setup | The brief says "dedicated Webstore customer". The JSON customer object is for the ship-to address only. Sell-to is always the configured Webstore customer. |
| Unit Price from JSON overrides card | The Webstore has its own pricing. BC item card price is irrelevant for Webstore orders. Validate("Unit Price", ...) after line insert. |
| Error on unmapped SKU, not skip | The brief says "fails the item with a clear error rather than guessing". Entire order fails if any SKU is unmapped. |
| Source = "WEBSTORE" (constant) | The mapping table supports multiple sources for future integrations. This feature hardcodes Source = "WEBSTORE". |

## Test strategy

Each acceptance criterion maps to a test method in the test codeunit. Tests
create Integration Messages with Type = "Webstore Order" and known JSON payloads,
run ProcessMessage, and assert on the resulting Sales Order. Setup is pre-populated
in test initialize. SKU mapping is created per test for isolation.
