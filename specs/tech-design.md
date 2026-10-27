# Technical Design: Integration Foundation

> Constitution document. The how, at the system level, for both halves of the
> solution: which standard Business Central modules and which standard Azure
> services to reuse, and where custom code is genuinely needed on each side.
> Feature plans (`plan.md`) inherit from this. Fill it in, then run
> `/al-spec-init` to review it against the brief.

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

The integration layer sits outside BC, in Azure. It subscribes to the business
events the extension raises (outbound) and calls the extension's API page
(inbound). BC never makes an outbound HTTP call. The plane is the second half of
this design, not an assumed given: its architecture, services, custom code, and
deployment are specified below under "Azure integration layer".

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

## Cross-cutting concerns (BC extension)

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

## Azure integration layer: architecture

One Function App in front of one Service Bus namespace, in one resource group per
environment. Every flow has the same four steps, and only the adapters differ:

**receive and acknowledge, queue, deliver, record.**

A receiver validates the caller, stamps the correlation id, puts the message on a
queue, and answers immediately. A delivery function takes it off the queue and makes
exactly one call: to BC for an inbound message, to the Webstore or the WMS for an
outbound one. Nothing in the plane waits on anything else in the plane.

```
Webstore --POST--> receiveWebstoreOrder --> [inbound-webstore-order] --> stageWebstoreOrder --POST--> BC API page
WMS      --POST--> receiveWmsShipment   --> [inbound-wms-shipment]   --> stageWmsShipment   --POST--> BC API page

BC event --POST--> receiveBusinessEvent --> [outbound-wms-fulfilment] --> sendWmsFulfilment  --POST--> WMS
                                        \-> [outbound-webstore-status]--> sendWebstoreStatus --PATCH-> Webstore

                   checkSubscriptionHealth (timer) --> BC business event subscriptions --> alert on drift
```

| Component | Kind | Responsibility |
|---|---|---|
| `receiveWebstoreOrder` | HTTP trigger | Authenticate the storefront, stamp correlation, enqueue, return `202`. No BC call. |
| `receiveWmsShipment` | HTTP trigger | The same, for the WMS shipment confirmation callback. |
| `receiveBusinessEvent` | HTTP trigger | The endpoint BC delivers external business events to. Answers the subscription validation handshake, routes by event name onto the matching outbound queue, returns `200` fast. |
| `stageWebstoreOrder` | Service Bus trigger | POST the payload to the BC API page as type `Webstore Order`, carrying the order number as the idempotency key. |
| `stageWmsShipment` | Service Bus trigger | POST to the BC API page as type `WMS Shipment Confirmation`, keyed on the shipment id. |
| `sendWmsFulfilment` | Service Bus trigger | POST the fulfilment request to the WMS with `Idempotency-Key` and `x-correlation-id`. |
| `sendWebstoreStatus` | Service Bus trigger | PATCH the storefront order to `Despatched`. |
| `checkSubscriptionHealth` | Timer trigger | List BC business event subscriptions, compare with the expected set, re-register and alert on drift. |

Four queues, one per flow, so one slow or stuck external system cannot block another:
`inbound-webstore-order`, `inbound-wms-shipment`, `outbound-wms-fulfilment`,
`outbound-webstore-status`. Each has dead-lettering on with a maximum delivery count.

## Standard Azure services to reuse

The same rule as the BC side: reuse the managed service, write custom code only for
the adapters. Retry, dead-lettering, scheduling, duplicate detection, and secret
storage are all configuration here, never hand-written loops.

| Service | Reuse | Why this rather than the alternative |
|---|---|---|
| Azure Functions (Node, TypeScript) | Every receiver, stager, sender, and the timer. | Logic Apps would suit the routing but not the payload mapping, which is real code and belongs in source control with tests. One technology for the whole plane beats two. |
| Service Bus queues (Standard) | Durability between receive and deliver, per-flow isolation, retry through delivery count, dead-lettering. | Storage queues have no dead-letter queue and no duplicate detection. Event Grid is for fan-out of events, not for a work queue that must not lose a message. Event Hubs is for high-volume streaming, which this is not. |
| Service Bus duplicate detection | A redelivered message with the same `MessageId` is discarded by the broker inside the detection window. | A custom dedup table is custom state to own, back up, and clean up. BC remains the durable authority on duplicates beyond the window. |
| Service Bus dead-letter queues | Where a message lands when it cannot be delivered within its maximum delivery count. | Dropping or logging the failure loses the payload and the chance to replay it. |
| Azure Key Vault | The Webstore status key, the Webstore ingest key, and the WMS API key, read through managed identity. | App setting literals put secrets in the deployment, the portal, and anyone's `az` output. |
| Managed identity | Function App to Key Vault, to Service Bus, and to BC. | Connection strings and client secrets have to be stored, rotated, and leaked. |
| Application Insights and Log Analytics | Traces, dependencies, and failures from every step, keyed by correlation id. | A plane with no telemetry cannot be debugged when an integration silently stops. |
| Azure Monitor alert rules | Dead-letter message count above zero, and the subscription health check reporting drift. | A dead-letter queue nobody is told about is the same as dropping the message. |
| Bicep | Every resource, in `infra/`, deployed by the pipeline. | A portal-created resource cannot be recreated, reviewed, or promoted between environments. |

## Plane-side custom code

| Gap | Why custom code is needed |
|---|---|
| Receiver adapters | Authenticating each external caller, reading its correlation header, and shaping its payload into the plane's envelope is specific to each external system and has no managed equivalent. |
| BC client | Acquiring a token for the Function App's identity and posting to the BC API page with the idempotency key, including the transient and permanent split on the response. |
| Outbound adapters | Mapping a BC event payload into the WMS fulfilment request and the Webstore status patch, which are the two vendors' own shapes. |
| Failure classification | Deciding that a 4xx is permanent and a 408, 429, 5xx, or timeout is transient, then dead-lettering the first and rethrowing the second so Service Bus retries it. |
| Business event subscription handshake and health check | Answering BC's subscription validation, listing current subscriptions, and re-registering a missing one. BC removes a subscription silently, and nothing else will catch it. |

## Plane cross-cutting concerns

| Concern | Approach |
|---|---|
| **Idempotency (inbound)** | The receiver sets the Service Bus `MessageId` to `<flow>:<business key>` (the Webstore `orderNo`, the WMS `shipmentId`), so the broker discards a duplicate inside the detection window. The same key goes to BC as the idempotency key, and BC's dedup on `External Reference + Type` is the durable authority beyond the window. |
| **Idempotency (outbound)** | Every call to the WMS and the Webstore carries `Idempotency-Key` set to the BC message id, so a retry is a no-op at the receiver. The plane never strips a key it was given. |
| **Correlation** | The Webstore order number is the correlation id end to end. The receiver reads `x-correlation-id`, or derives it from the payload where the caller sends none, sets it as a Service Bus application property, sets it as `x-correlation-id` on every outbound call, and logs it as a custom dimension at every step. |
| **Retry** | Service Bus delivery count plus the Functions host retry policy, configured explicitly in `host.json`, never a loop inside a function. A transient failure rethrows so the message is redelivered with backoff. |
| **Transient against permanent** | Timeout, 408, 429, and 5xx are transient and rethrow. Any other 4xx, and any payload that fails schema validation, is permanent: the function dead-letters the message with a reason and returns, so it is never retried. |
| **Dead-letter** | On every queue, with a maximum delivery count of 5. An alert fires on a non-zero dead-letter count. A dead-lettered message is replayable with its original body and properties. |
| **Secrets** | Key Vault only, referenced from app settings as Key Vault references and read through the Function App's managed identity. No secret in Bicep, in a parameter file, in source, or in a plain app setting. |
| **Plane to BC auth** | The Function App's managed identity, registered in BC as an Entra application with the extension's permission set. No BC user, no password, no client secret. |
| **Observability** | Application Insights on the Function App, with correlation id and BC message id as custom dimensions on every step. Payload bodies and personal data are never logged. |
| **Subscription health** | The timer function lists BC's business event subscriptions every six hours, compares them with the expected set, re-registers a missing one, and alerts. BC subscriptions expire after about three days and are removed silently on a bad response. |
| **Environments** | One resource group per environment, the same Bicep, different parameter files. Nothing differs between environments except parameters. |

## Infrastructure, environments, and deployment

| Topic | Decision |
|---|---|
| Layout | `infra/main.bicep` composes modules under `infra/modules/`: `servicebus`, `functionapp`, `keyvault`, `observability`, `storage`, `alerts`. Parameters per environment in `infra/main.<env>.bicepparam`. |
| Naming | `<abbr>-intplane-<env>-<region>`, for example `func-intplane-dev-aue`, `sb-intplane-dev-aue`, `kv-intplane-dev-aue`. |
| Scope | One resource group per environment, created outside the deployment. The template is resource-group scoped. |
| Deployment | A GitHub Actions workflow authenticates with an Entra workload identity federation credential, so no secret is stored, deploys the Bicep, then publishes the Function App package. |
| Secret seeding | Secret values are written to Key Vault out of band, by a person with access. The pipeline never receives them and the template never takes them as parameters. |
| Function App plan | Consumption, which is the right size for this volume and keeps an idle environment close to free. |
| Code layout | `integration-plane/src/functions/` one file per function, `integration-plane/src/shared/` the BC client, correlation, classification, and configuration helpers, `integration-plane/test/` unit tests over the shared helpers and the adapters. |

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

4. **Business event subscription registration.** Confirm the exact BC API for
   registering and listing external business event subscriptions on the target
   version, the shape of the validation handshake, and the real expiry window.
   The design assumes registration by API and expiry after about three days.
   Settle it during the plane foundation feature, because the health check and
   the re-registration logic both depend on it.

5. **Duplicate detection window.** Service Bus duplicate detection is set when
   the queue is created and cannot be changed afterwards. Pick the window during
   the plane foundation feature, and accept that BC's own dedup is what covers
   anything beyond it.

6. **Who owns the retry budget.** The Service Bus maximum delivery count and the
   Functions host retry policy both retry. Decide during the plane foundation
   feature which one is the budget and set the other to pass through, so a
   message is not retried twenty-five times when the intent was five.

7. **Plane identity in BC.** Registering the Function App's managed identity as
   an Entra application in BC, and granting it the extension's permission set, is
   a per-tenant setup step. Decide whether it is scripted, documented, or both,
   and where the step lives for a new environment.
