# Technical Design: Integration Foundation

> Constitution document. The how, at the system level: which standard Business
> Central modules to reuse, and where custom code is genuinely needed. Feature
> plans (`plan.md`) inherit from this. Fill it in, then run `/al-spec-init` to
> review it against the brief.

## Architecture overview

The extension has three layers:

1. **Core** (`src/Core/`): the shared integration mechanism. One table
   (Integration Message) stages every inbound and outbound payload. One
   extensible enum (Integration Message Type) dispatches processing through an
   interface. One API page exposes the inbound path; one set of business events
   exposes the outbound path. Idempotency, correlation, retry, status tracking,
   and error capture live here once and are inherited by every module.

2. **Webstore module** (`src/Webstore/`): implements the Webstore integration on
   top of the core. Handles inbound order ingestion (mapping the JSON payload to
   a Sales Order) and outbound shipment notification (raising a business event
   when a shipment posts). Owns the SKU-to-Item mapping table and the Webstore
   setup page.

3. **WMS module** (`src/WMS/`): implements the WMS integration on top of the
   core. Handles outbound fulfilment requests (raising a business event when a
   Sales Order is released) and inbound shipment confirmations (posting the
   warehouse shipment from the WMS payload). Owns its own setup page.

The integration layer (Azure Functions, Logic Apps, or equivalent) sits outside
BC. It subscribes to the business events the extension raises (outbound) and
calls the extension's API page (inbound). BC never makes an outbound HTTP call.

```
Webstore ──► Integration Layer ──► [API Page] ──► Core (stage) ──► Webstore Module (process)
                                                                         │
WMS ◄── Integration Layer ◄── [Business Event] ◄── Core ◄── WMS Module ◄┘
```

## Standard BC modules to reuse

| Module | Reuse |
|---|---|
| Sales Orders (Sales Header, Sales Line) | The order created from a Webstore payload is a standard Sales Order. No custom document type. |
| Warehouse Shipments (Warehouse Shipment Header/Line) | Shipment confirmation posts through the standard warehouse shipment posting routine. |
| Sales Invoice posting | Optional: post invoice together with shipment via standard Sales-Post. |
| Item table | Items matched by SKU through a mapping table. No custom item structure. |
| Customer table | A dedicated Webstore customer record, standard Customer table. |
| Shipping Agent / Shipping Agent Services | Carrier and tracking stored in standard fields on shipment. |
| Job Queue | Retry of failed Integration Messages driven by standard Job Queue. |

## Custom-code gaps

| Gap | Why custom code is needed |
|---|---|
| Integration Message table | BC has no built-in generic staging table with idempotency key, correlation, status, and blob payloads. This is the reusable backbone. |
| Integration Message Type enum + interface | Standard BC has no dispatch-by-type mechanism for staged messages. The extensible enum plus interface pattern lets modules register without changing the core. |
| Inbound API page | Standard BC API pages expose records. The extension needs a custom API page that accepts a JSON payload, stages it, and returns an acknowledgement. |
| Business events for outbound actions | Standard posting routines do not raise events with the payload shape the integration layer needs. Custom `[BusinessEvent]` procedures on Release and Post Shipment carry the structured data. |
| SKU-to-Item mapping | Standard Item has No., but external SKUs are not stored anywhere usable for lookup. A small mapping table is needed. |
| Webstore and WMS setup pages | Configuration (customer template, default location, posting options) has no standard home. |
| Processing codeunits per module | The logic to parse an inbound JSON, create a Sales Order, or build the outbound payload is domain-specific and has no standard equivalent. |

## Object ID range

`73298400` to `73298499` (100 objects), assigned to publisher "Equerra Limited".
Budget allocation:

| Range | Layer |
|---|---|
| 73298400-73298419 | Core (tables, enums, interfaces, API page, codeunits) |
| 73298420-73298449 | Webstore module |
| 73298450-73298479 | WMS module |
| 73298480-73298489 | Permissions |
| 73298490-73298499 | Reserve (future modules) |

## Data model (high level)

```
┌─────────────────────────────┐
│ Integration Message         │  (Core)
│  PK: Message ID (Guid)     │
│  SK: Idempotency Key       │
│  SK: Correlation ID        │
│  Type, Status              │
│  Request/Response/Error    │
│  Parent Message ID         │
└─────────────────────────────┘
        │
        │ Type dispatches to
        ▼
┌─────────────────────────────┐     ┌─────────────────────────────┐
│ Webstore Order (type value) │     │ WMS Shipment Confirm (type) │
│  → creates Sales Order      │     │  → posts Whse. Shipment     │
└─────────────────────────────┘     └─────────────────────────────┘

┌─────────────────────────────┐
│ Integration SKU Mapping     │  (Webstore)
│  PK: Source, External SKU   │
│  → Item No.                 │
└─────────────────────────────┘

┌─────────────────────────────┐     ┌─────────────────────────────┐
│ Webstore Setup (singleton)  │     │ WMS Setup (singleton)       │
│  Customer No., Location,    │     │  Location, Post Invoice,    │
│  Posting options            │     │  Shipping Agent defaults    │
└─────────────────────────────┘     └─────────────────────────────┘
```

The Integration Message table is the single staging point for all payloads.
Modules do not create their own staging tables; they add a value to the
Integration Message Type enum and implement the processing interface.

## Integrations

### Inbound path (shared, one API page)

External systems deliver payloads to the extension's API page. The page stages an
Integration Message (Status = New, Idempotency Key from the caller) and returns
`201` with the Message ID. A Job Queue entry (or immediate processing, configurable)
picks up New messages, dispatches by Type, and moves them to Completed or Failed.

Idempotency: if the Idempotency Key already exists, the API returns the existing
message and does not create a duplicate.

### Outbound path (shared, business events)

When a BC action should notify an external system, the responsible module raises a
`[BusinessEvent]` carrying a structured payload (the correlation id, the data the
external system needs). The integration layer subscribes to these events and
delivers the call. BC does not make HTTP calls.

### Business events raised

| Event | Trigger | Subscriber (external) |
|---|---|---|
| `OnAfterFulfilmentRequested` | Sales Order released (Webstore order) | Integration layer calls WMS |
| `OnAfterShipmentPosted` | Warehouse Shipment posted from WMS confirmation | Integration layer calls Webstore status update |

### Inbound message types

| Type enum value | Module | Processing |
|---|---|---|
| `Webstore Order` | Webstore | Parse JSON, create Sales Order |
| `WMS Shipment Confirmation` | WMS | Parse JSON, post Warehouse Shipment |

## Cross-cutting concerns

| Concern | Approach |
|---|---|
| **Idempotency** | Unique secondary key on Integration Message.Idempotency Key. Duplicate inbound calls return existing record. Outbound events carry the same key so the integration layer can deduplicate downstream. |
| **Correlation** | Every message carries a Correlation ID (the Webstore order number as a deterministic Guid, or the raw text in a secondary key). All hops log it. |
| **Retry** | Failed messages stay in the table with Status = Failed. A Job Queue entry retries them on a schedule. Max retry count on setup. |
| **Error handling** | Processing errors are caught, written to Error Content and Error Code on the message, and the status is set to Failed. No silent swallowing. |
| **Telemetry** | Custom telemetry dimensions on message stage, process start, process complete, process fail. Correlation ID is a dimension on every signal. |
| **Permissions** | One permission set granting full access to extension objects. The API page requires a dedicated permission (no broader access). |
| **Multitenancy** | All data is company-scoped (standard BC behaviour). No cross-company reads. Setup is per-company. |
| **Upgrade** | Upgrade codeunit handles new fields on Integration Message if schema changes. Each feature plan owns its own upgrade path. |
| **Secrets** | No secrets stored in AL. The integration layer holds API keys in Azure Key Vault. BC setup pages store only non-secret configuration. |

## Open technical questions

1. **Immediate vs. queued processing.** Should inbound messages process
   immediately on the API call (simpler, but ties the caller to processing time)
   or always via Job Queue (decoupled, but adds latency)? Recommendation:
   immediate by default, with a setup toggle for queued mode. Settle during
   feature 001 planning.

2. **Partial shipment handling.** When the WMS ships fewer items than ordered,
   does the extension post a partial shipment and leave the order open, or fail?
   The brief says "short-shipped line posts a partial shipment and leaves the
   rest open". Confirm during feature 004 planning that standard Warehouse
   Shipment posting handles this without custom code.

3. **Invoice posting toggle.** The brief says "posts the invoice if configured".
   This is a boolean on WMS Setup. Confirm during feature 004 that calling
   Sales-Post with Invoice = TRUE after shipment posting is safe in all order
   states.
