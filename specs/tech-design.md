# Technical Design: Integration Foundation

> Constitution document. The how, at the system level, for both halves of the
> solution: which standard Business Central modules and which standard Azure
> services to reuse, and where custom code is genuinely needed on each side.
> Feature plans (`plan.md`) inherit from this. Fill it in, then run
> `/al-spec-init` to review it against the brief.

## Architecture overview

One reusable integration extension. Every integration, current and future,
shares a single inbound path and a single outbound path. The cross-cutting
behaviour (idempotency, correlation, retry, error classification, manual
resolution, telemetry) is built once into the core and reused by every
integration. Adding a new integration is adding a small module (one message
type, one handler codeunit, optionally one outbound event), with no change to
the core and no new plumbing.

The spine of the whole design is one staging table, the **Integration Message**.
Nothing crosses the BC boundary without passing through it. The four arrows from
the modern-integration house rules each anchor on that table:

- **Inbound.** The external integration layer POSTs to one BC API page that
  writes an Integration Message. A Job Queue dispatcher picks up `New` messages
  and routes each by its `Type` to a handler codeunit that does the BC work
  (create a Sales Order, post a shipment). BC pulls nothing and exposes one
  endpoint for every source.
- **Outbound.** BC never makes an HTTP call. Outbound actions raise an
  `[ExternalBusinessEvent]`. Delivery is async and post-commit, so it is safe to
  fire from a release or posting path. The external integration layer subscribes
  and makes the actual call to the Webstore or the WMS.
- **Long-running.** When an external system answers later, the request and the
  later confirmation are two Integration Message rows that share one Correlation
  ID. The request message parks `Awaiting Reply`; the confirmation arrives as a
  fresh inbound message.
- **Manual.** A failed message stays editable on a resolution page. Ops fixes the
  payload, flips the status back to `New`, and the dispatcher re-runs it with the
  same Message ID and idempotency key.

```
 Webstore ──order──▶ [Integration Layer] ──POST──▶ BC API page ─▶ Integration Message (Inbound, WebstoreOrder)
                                                                        │ Job Queue dispatcher
                                                                        ▼
                                                                  Sales Order created

 Sales Order released ─▶ [ExternalBusinessEvent] OnSalesOrderReleased_v1 ─▶ [Integration Layer] ──POST──▶ WMS

 WMS ──confirmation──▶ [Integration Layer] ──POST──▶ BC API page ─▶ Integration Message (Inbound, WmsShipmentConfirmation)
                                                                        │ Job Queue dispatcher
                                                                        ▼
                                                          Warehouse Shipment posted (+ invoice if configured)
                                                                        │
                                                                        ▼
                                                  [ExternalBusinessEvent] OnShipmentConfirmed_v1 ─▶ [Integration Layer] ──PATCH──▶ Webstore (Despatched)
```

The boundary rule is absolute and structural, not advisory: there is no
`HttpClient` anywhere in this extension. Inbound is the API page; outbound is
external business events. That is what guarantees "BC never makes an outbound
HTTP call" and what keeps posting independent of any external system being up.

The `[Integration Layer]` in the diagram above is the other half of this design,
not an assumed given. It is an Azure plane built in this repository, under
`infra/` and `integration-plane/`, and it is specified from "Azure integration
layer: architecture" below. Every property the BC side relies on (a message is
not lost between the storefront and the API page, a retry carries the same
idempotency key, the correlation id survives every hop, a subscription that
disappears is noticed) is the plane's to guarantee, so the two halves are
designed together or not at all.

**Platform target.** BC 2026 release wave 1 (application and platform
`28.0.0.0`, AL runtime `17.0`), per the brief's "latest BC platform" constraint.
This matters: the outbound design uses `[ExternalBusinessEvent]`, introduced at
runtime 11.0 (BC 24), so runtime 17 supports it. The attribute is still labelled
preview, so confirm it against current docs at implementation time (open question
5).

## Standard BC modules to reuse

Build on standard BC wherever it already does the job. Custom code is only the
plumbing the platform does not provide.

- **Sales Orders.** Order ingest creates a standard Sales Header / Sales Line.
  No custom order document. Release uses standard `Release Sales Document`.
- **Warehouse Shipment and posting.** Shipment confirmation posts through the
  standard sales shipment / warehouse shipment posting routines. Partial and
  short-shipped lines use the standard `Qty. to Ship` mechanics. Invoicing, when
  configured, uses standard posting.
- **Customers and Items.** A dedicated Webstore customer (standard Customer
  record, identified in setup) carries every Webstore order. Items are standard;
  the only custom data is the SKU to Item No. mapping.
- **Job Queue.** The dispatcher and the subscription-health monitor run as
  standard Job Queue Entries. Retry cadence and scheduling are standard Job Queue
  configuration, not hand-written loops.
- **External Business Events.** Outbound notification uses the platform
  `[ExternalBusinessEvent]` mechanism (platform retry for 408 / 429 / 5xx, async
  post-commit delivery, external subscriber self-registration). No custom retry
  loop.
- **API pages.** The single inbound endpoint is a standard API page over the
  Integration Message table.
- **Isolated Storage / Key Vault.** Any secret the extension needs is read from
  secure storage. The extension holds no API keys in fields or source. In this
  build, secrets live with the external integration layer; BC stores none for the
  outbound calls because it makes none.
- **Telemetry.** Standard `Session.LogMessage` to Application Insights on every
  protected step, keyed by Correlation ID.

## Custom-code gaps

Only what standard BC cannot do:

1. **The Integration Message staging table and its lifecycle.** Standard BC has
   no general-purpose inbound/outbound staging record with status, direction,
   correlation, retry state, and classified errors. This is the core.
2. **The single inbound API page** over that table, with the `Type` field routing
   to a dispatcher. Standard BC has no generic "stage any integration message"
   endpoint.
3. **The dispatcher and the handler interface.** A Job Queue runner that reads
   `New` messages and routes each by `Type` through an `IIntegrationMessageHandler`
   interface resolved from an extensible enum. This is what makes the core
   reusable: a new integration is a new enum value plus a handler, no dispatcher
   change and no giant CASE.
4. **Idempotency and correlation enforcement.** The dedup check on
   `External Reference + Type` before staging, and Correlation ID propagation
   across every hop, are custom and centralised so no integration re-implements
   them.
5. **The SKU to Item No. mapping** table, page, and lookup, with a clear failure
   on an unmapped SKU.
6. **The manual resolution page** with Resolve, Confirm-by-Exception, and Reassign
   actions over failed messages.
7. **The integration-specific handlers**: Webstore order to Sales Order, and WMS
   confirmation to posted shipment. These are thin modules on top of the core.
8. **The outbound event declarations** (`OnSalesOrderReleased_v1`,
   `OnShipmentConfirmed_v1`) and the thin subscribers that fire them.
9. **The subscription-health monitor** job (the platform removes a subscription
   silently and gives no built-in alert).

## Object ID range

Assigned range `73298400`-`73298499` (`"from": 73298400, "to": 73298499`),
100 IDs, declared in `Integration Foundation/app.json`. Sub-allocation (a
guideline for feature plans; each plan claims its exact IDs):

| Bucket | Range | Contents |
|---|---|---|
| Tables | `73298400`-`73298409` | Integration Message, SKU Mapping, Setup |
| Enums | `73298410`-`73298419` | Direction, Status, Message Type (extensible), Error Class |
| Codeunits | `73298420`-`73298439` | Message Mgt., Dispatcher, handlers, events, subscribers, monitor, SKU Mgt. |
| Pages | `73298440`-`73298459` | Message list, resolution card, SKU mapping, setup, API page |
| Permission sets | `73298460`-`73298469` | Integration Foundation permissions |
| Reserved | `73298470`-`73298499` | future integrations and modules |

Interfaces (`IIntegrationMessageHandler`) carry no object ID.

## Data model (high level)

**Integration Message** (the spine, PK `Message ID` Guid):

- `Message ID` (Guid, PK): never reused, never the external key.
- `Direction` (enum: Inbound, Outbound).
- `Type` (enum, extensible, implements `IIntegrationMessageHandler`): routes to a
  handler. The external contract value is also kept as a stable code on the row.
- `Status` (enum: New, In Progress, Awaiting Reply, Failed, Resolved): the only
  field the dispatcher Job Queue filters on.
- `External Reference` (Text): the source system's stable id (the Webstore
  `orderNo`, the WMS `shipmentId`). Drives inbound dedup.
- `Correlation ID` (Code[40]): one trace id across BC, queues, and external
  systems. Set once at the entry point, carried on every hop.
- `Parent Message ID` (Guid): links a confirmation to its originating request.
- `Document No.` (Code[40]): the BC anchor (Sales Order No., Posted Shipment No.).
- `Request` / `Response` (Blob): the inbound and outbound payloads.
- `Error Message` (Text) + `Error Class` (enum: Transient, Permanent): last error,
  classified for retry-vs-fail.
- `Retry Count` (Integer): retry state on the row, never in code.
- Audit: `Created At`, `Last Modified At`, created/modified by.

Keys: PK on `Message ID`; a work key on `(Status, Direction, Created At)` for the
dispatcher; an idempotency key on `(External Reference, Type)` for dedup.

**Integration SKU Mapping** (PK `SKU` Code[20]): `SKU`, `Item No.`, optional
`Variant Code`, `Unit of Measure`. An unmapped SKU fails the message with a clear
error rather than guessing.

**Integration Setup** (singleton): Webstore customer no., default location code,
the post-invoice-on-shipment toggle, default shipping method, and the order-status
value sent on despatch. No secrets.

All fields carry `DataClassification`. Customer name, email, phone, and address
flowing through `Request`/`Response` blobs are `CustomerContent`.

## Integrations

- **Inbound, single endpoint.** One API page over Integration Message. The
  integration layer POSTs both Webstore orders (`Type = WebstoreOrder`) and WMS
  confirmations (`Type = WmsShipmentConfirmation`) to it. The `Type` routes; there
  is no per-source API page. The API page is keyed on SystemId (house rule).
- **Outbound, external business events.** `OnSalesOrderReleased_v1` (fired from a
  thin subscriber on sales release) and `OnShipmentConfirmed_v1` (fired after the
  shipment posts). Each carries a stable, minimal DTO of identifiers, never the BC
  record and never a secret. One events codeunit per integration version; a
  contract change is a new `_v2` procedure, never a mutated signature.
- **External systems.** Webstore (storefront API, `DG-NNNNN` order numbers) and
  WMS (REST, `FUL-` / `SHP-` references). The endpoint and payload detail is fixed
  in `brief.md`. The integration contract that pins the BC-side shapes (the API
  page payload, each event DTO) belongs in `specs/contracts/integration-contract.md`;
  that file does not exist yet and is the first roadmap doc task.
- **Idempotency.** Inbound: dedup on `External Reference + Type` before staging; a
  re-delivered order, confirmation, or status returns the prior result and creates
  nothing new. Outbound: the integration layer carries the Integration Message
  GUID (or the order number) as the `Idempotency-Key` on each WMS / Webstore call,
  so a retry is a no-op on the receiver.
- **Correlation.** The Webstore `orderNo` is the correlation id end to end. It is
  set on the first inbound message and echoed on every event payload, queue entry,
  and outbound call.

## Cross-cutting concerns (BC extension)

- **Telemetry.** Every protected step (stage, dispatch, handler success/failure,
  event fired, monitor result) logs to Application Insights with the Correlation
  ID and Message ID as custom dimensions. No payload bodies and no PII in
  telemetry.
- **Permissions.** One permission set (`Integration Foundation`) covers every
  object the extension defines. New objects are added to it as features land; the
  permission-set auditor gates this.
- **AppSource gating.** AppSource submission is a non-goal (brief). The repo was
  scaffolded from the AppSource app template, but AppSourceCop is not a release
  gate for this build. Feature plans do not chase `AS0xxx` rules unless they also
  reflect a genuine quality or upgrade concern. Revisit only if submission is
  later brought into scope.
- **Multitenancy.** Per-tenant SaaS extension. The dispatcher and monitor run as
  Job Queue entries inside one company; all reads are company-scoped. No
  cross-company or cross-tenant access.
- **Upgrade.** The Integration Message table is append-only operational data; new
  fields are additive with `ObsoleteState` discipline. Enum values
  (`Message Type`, `Status`) are extensible and additive; reordering is forbidden
  because external contracts and stored rows depend on the values. Any required
  new field gets an upgrade codeunit that backfills existing rows.
- **Error handling.** `ErrorInfo` for structured failures the dispatcher reacts
  to. Errors are classified Transient (retry, bounded by Job Queue policy) versus
  Permanent (fail to the resolution page, alert). Invalid data is never published
  to an event and never retried indefinitely.
- **Event-subscriber discipline.** Subscribers are small, focused, and thin: they
  exit early on the wrong record or non-Normal execution mode and delegate to a
  management codeunit. Group by area (sales release, posting).

## Azure integration layer: architecture

One Function App in front of one Service Bus namespace, in one resource group per
environment. Every flow is the same four steps, and only the adapters differ:
**receive and acknowledge, queue, deliver, record.**

A receiver authenticates the caller, stamps the correlation id, puts the message on a
queue, and answers immediately. A delivery function takes it off the queue and makes
exactly one call: to the BC API page for an inbound message, to the WMS or the
storefront for an outbound one. Nothing in the plane waits on anything else in the
plane, and nothing in the plane makes a business decision.

```
 Webstore ──POST──▶ receiveWebstoreOrder ─▶ [inbound-webstore-order] ─▶ stageWebstoreOrder ──POST──▶ BC API page
 WMS      ──POST──▶ receiveWmsShipment   ─▶ [inbound-wms-shipment]   ─▶ stageWmsShipment   ──POST──▶ BC API page

 BC event ──POST──▶ receiveBusinessEvent ─┬▶ [outbound-wms-fulfilment] ─▶ sendWmsFulfilment  ──POST──▶ WMS
                                          └▶ [outbound-webstore-status]▶ sendWebstoreStatus ─PATCH──▶ Webstore

                    checkSubscriptionHealth (timer) ─▶ BC event subscriptions ─▶ re-register, alert on drift
```

| Component | Trigger | Responsibility |
|---|---|---|
| `receiveWebstoreOrder` | HTTP | Check `x-api-key` against the vault value, read `x-correlation-id`, take `orderNo` as the business key, enqueue, return `202`. Touches BC not at all. |
| `receiveWmsShipment` | HTTP | The same for the WMS confirmation callback, keyed on `shipmentId`, correlated on `reference`. |
| `receiveBusinessEvent` | HTTP | The endpoint BC delivers external business events to. Answers the subscription validation handshake, routes `OnSalesOrderReleased_v1` and `OnShipmentConfirmed_v1` onto their queues by name, returns `200` fast. An unknown event name is acknowledged and dropped with a log, never an error, so one new event in BC cannot wedge delivery of the others. |
| `stageWebstoreOrder` | Service Bus | POST the inbound envelope to the BC API page with `messageType: WebstoreOrder` and `externalReference` the order number. The source body rides verbatim in `payload`. |
| `stageWmsShipment` | Service Bus | The same with `messageType: WmsShipmentConfirmation` and `externalReference` the shipment id. |
| `sendWmsFulfilment` | Service Bus | Read the staged outbound message back from BC by its reference to get the full fulfilment DTO (the event itself carries only identifiers, see the contract), POST it to the WMS with `Idempotency-Key`, then write the WMS reference back onto that message. |
| `sendWebstoreStatus` | Service Bus | PATCH the storefront order to `Despatched` with the BC order number and despatch timestamp. |
| `checkSubscriptionHealth` | Timer | List BC's external business event subscriptions, compare with the expected set, re-register a missing one, and alert. |

Four queues, one per flow (`inbound-webstore-order`, `inbound-wms-shipment`,
`outbound-wms-fulfilment`, `outbound-webstore-status`), so a stuck WMS cannot block an
incoming order. Each has dead-lettering on, a maximum delivery count, and duplicate
detection. A fifth queue, `parked`, holds what the plane has decided not to retry; see
"Dead-letter, and parking" below for why that is a queue rather than a dead-letter
call.

`sendWmsFulfilment` reading back from BC is the one place the plane calls BC for
something other than staging, and it is a direct consequence of the contract: an
`[ExternalBusinessEvent]` argument is capped at 250 characters, so a multi-line order
cannot ride on the event. The event carries the identifiers, the staged outbound
Integration Message carries the DTO, and the plane joins them on the reference. The
alternative, putting the order on the event, does not fit; the other alternative,
rebuilding the DTO in the plane from BC records, would put BC business logic in the
plane, which is exactly what this design forbids.

## Standard Azure services to reuse

Same rule as the BC side: reuse the managed service, write custom code only for the
adapters. Retry, dead-lettering, scheduling, duplicate detection, and secret storage
are configuration here, never hand-written loops.

| Service | Reuse | Why this rather than the alternative |
|---|---|---|
| Azure Functions (Node 20, TypeScript) | Every receiver, stager, sender, and the timer. | Logic Apps suit the routing but not the payload mapping, which is real code that deserves source control and tests. One technology for the whole plane beats two. |
| Service Bus queues (Standard) | Durability between receive and deliver, isolation per flow, retry through delivery count, dead-lettering. | Storage queues have no dead-letter queue and no duplicate detection. Event Grid is fan-out of events, not a work queue that must not lose a message. Event Hubs is high-volume streaming, which this is not. |
| Service Bus duplicate detection | The broker discards a redelivery with the same `MessageId` inside the window. | A custom dedup store is custom state to own and clean up, and BC already deduplicates durably on `(External Reference, Type)`. |
| Service Bus dead-letter queues | Where a message lands when it cannot be delivered within its maximum delivery count. | Logging the failure and dropping the message loses the payload and the chance to replay it. |
| Azure Key Vault | The Webstore ingest key, the Webstore status key, the WMS API key, and the WMS callback key, reached through managed identity. | App setting literals put secrets into the deployment, the portal, and anyone's `az` output. |
| Managed identity (system-assigned) | Function App to Key Vault, to Service Bus, and to BC. | Connection strings and client secrets have to be stored, rotated, and eventually leaked. |
| Application Insights and Log Analytics | Traces, dependencies, and failures at every step, keyed by correlation id. | A plane with no telemetry cannot be debugged when an integration silently stops, which is the failure mode this whole design is built around. |
| Azure Monitor metric alerts | Dead-letter depth above zero on any queue, and the health check reporting drift. | A dead-letter queue nobody is told about is the same as dropping the message. |
| Bicep | Every resource, in `infra/`, deployed by the pipeline. | A portal-created resource cannot be reviewed, recreated, or promoted. |

## Plane-side custom code

Only what the managed services do not provide:

1. **The receiver adapters.** Authenticating each external caller, reading its
   correlation header, and finding its business key. Each external system does this
   differently and no managed service knows their shapes.
2. **The BC client.** Acquiring a token for the Function App's identity, posting the
   inbound envelope to the API page, reading a staged outbound message back, and
   writing a result onto one, with each response class mapped onto success,
   duplicate, transient, or permanent.
3. **The outbound adapters.** Mapping the staged DTO onto the WMS fulfilment request
   and the BC event payload onto the storefront status patch. These are the two
   vendors' own shapes, pinned in the integration contract.
4. **Failure classification.** Deciding that a 408, 429, 5xx, or timeout is transient
   and anything else in the 4xx range is permanent, then rethrowing the first (so the
   broker retries) and dead-lettering the second with a reason (so it never retries).
5. **The business event subscription handshake and health check.** Answering BC's
   validation request, listing subscriptions, and re-registering a missing one.

## Plane cross-cutting concerns

- **Idempotency, inbound.** The receiver sets the Service Bus `MessageId` to
  `<flow>:<businessKey>`, so the broker discards an exact redelivery inside the
  detection window. The same key goes to BC as `externalReference`, where dedup on
  `(External Reference, Type)` is the durable authority. A `409` from BC meaning "this
  one already exists" is a success in the plane, not a failure, because BC did exactly
  what it was asked to do.
- **Idempotency, outbound.** Every call to the WMS carries `Idempotency-Key` set to
  the reference, per the contract. The storefront PATCH is idempotent by design and
  answers `transitioned: false` on a repeat. The plane never strips a key it was given.
- **Correlation.** The Webstore `orderNo` is the correlation id end to end. The
  receiver reads `x-correlation-id`, derives it from the business key when the caller
  sends none, sets it as a Service Bus application property, sets it as
  `x-correlation-id` on every outbound call, and logs it as a custom dimension at
  every step. It is set once and never regenerated.
- **Retry.** The Service Bus maximum delivery count is the budget, and the Functions
  host retry policy is set to a single attempt so the two do not multiply. A transient
  failure rethrows and does nothing else; retry is the broker's decision.
- **Dead-letter, and parking.** Every flow queue has a maximum delivery count of 5,
  and a message that exhausts it dead-letters with its body and properties intact, so
  it is replayable. A failure the plane has already judged permanent does not go
  there: the Node worker does not expose Service Bus message settlement, so a function
  cannot dead-letter the message it is holding, and its only choices are complete
  (return) or abandon (throw). Throwing on a 4xx would retry it five times, which is
  the "retry a 4xx forever" behaviour the review rules call a blocker. So a permanent
  failure is forwarded to one shared `parked` queue with its reason and completed.
  Operationally the parked queue and the dead-letter queues are one surface, watched
  by the same alerts: messages that stopped, with the reason attached.
- **Secrets.** Key Vault only, referenced from app settings as Key Vault references
  and read through the Function App's identity. No secret in Bicep, in a parameter
  file, in source, or in a plain app setting.
- **Plane to BC auth.** The Function App's managed identity, registered in BC as an
  Entra application and granted the extension's permission set. No BC user, no
  password, no client secret.
- **Observability.** Application Insights on the Function App, correlation id and BC
  message id as custom dimensions on every step, and no payload bodies or personal
  data in telemetry. The Webstore payload carries a shopper's name, email, phone, and
  address, and none of it is logged.
- **Subscription health.** Every six hours, because BC's subscriptions expire after
  about three days and are removed silently on a bad response. This is the one failure
  mode where everything looks healthy and nothing arrives.
- **Environments.** One resource group per environment, the same Bicep, different
  parameter files. Nothing differs between environments except parameters.

## Infrastructure, environments, and deployment

| Topic | Decision |
|---|---|
| Layout | `infra/main.bicep` composes modules under `infra/modules/`: `servicebus`, `storage`, `keyvault`, `observability`, `functionapp`, `alerts`. Parameters per environment in `infra/main.<env>.bicepparam`. |
| Naming | `<abbr>-intplane-<env>-<region>`, for example `func-intplane-dev-aue`, `sb-intplane-dev-aue`, `kv-intplane-dev-aue`. |
| Scope | Resource-group scoped. The resource group itself is created once, outside the deployment. |
| Deployment | `.github/workflows/DeployIntegrationPlane.yaml`: workload identity federation (no stored secret), `az deployment group create`, then publish the Function App package. Path-filtered to `infra/` and `integration-plane/`. |
| Secret seeding | The four external secrets are written to Key Vault out of band by a person with access. The pipeline never receives them and the template never takes them as parameters. |
| Plan | Consumption. Nothing synchronous waits on the plane, so cold start is acceptable, and an idle environment is close to free. |
| Code layout | `integration-plane/src/functions/` one file per function, `integration-plane/src/shared/` the BC client, correlation, classification, envelope, config, and telemetry helpers, `integration-plane/test/` unit tests over all of it. |
| Review gate | `azure-integration-validator` runs on any change under `infra/` or `integration-plane/`, beside the AL verifier set. |

## Open technical questions

1. **Outbound staging row.** External business events are async and durable, so an
   outbound action may not need its own Integration Message row. Decide per
   outbound flow whether to also stage an Outbound message for audit and
   correlation, or rely on the event plus inbound confirmation. Leaning toward
   staging an Outbound row for the fulfilment request so the request and the WMS
   confirmation share a visible parent.
2. **Invoice posting toggle.** The brief says "post the invoice if configured."
   Confirm whether invoicing posts in the same handler run as the shipment, or as
   a separate staged stage (`house:split-by-stage`) with its own lock and retry.
3. **Webstore customer modelling.** One shared Webstore customer for all orders
   versus customer-per-shopper. The brief specifies a dedicated Webstore customer;
   confirm shopper name and address ride on the Sales Order ship-to, not a new
   customer per order.
4. **Message retention.** Define a retention or archive policy for Resolved
   Integration Messages so the table does not grow without bound.
5. **External business event preview status.** Availability is resolved: the
   target is runtime 17.0 (BC 28) and `[ExternalBusinessEvent]` exists from
   runtime 11.0. It is still labelled preview, so confirm it is GA or acceptable
   as preview at implementation time, and keep the documented fallback (stage an
   Outbound message the integration layer polls) in case the preview status
   blocks the build.

6. **BC token audience and the plane's registration.** The exact audience and scope
   for a managed identity calling a BC API page, and the BC-side step that registers
   the Function App's identity as an Entra application with the extension's permission
   set. The BC client reads both from configuration so settling them is a parameter
   change, but the path has to be proven before any flow depends on it.

7. **Duplicate detection window.** Set at queue creation and not changeable
   afterwards, so it is settled in the plane foundation feature rather than by the
   first flow to need it. The proposal is one hour, on the basis that BC's own dedup
   is what covers anything longer.

8. **Reading the outbound DTO back from BC.** The plane reads a staged outbound
   Integration Message to get the fulfilment DTO the event cannot carry. Confirm the
   read path on the API page (and the permission it needs) at the same time as
   question 6, since it is the same credential and the same endpoint.

9. **Replaying a dead-lettered message.** Today that is an Azure portal action.
   Whether BC should be able to ask for a replay from the Integration Message
   resolution page is a real question, and it is parked rather than answered, because
   it adds an inbound path that exists only for operations.
