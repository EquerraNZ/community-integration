# Technical Design: Integration Foundation

> Constitution document. The how, at the system level: which standard Business
> Central modules to reuse, and where custom code is genuinely needed. Feature
> plans (`plan.md`) inherit from this. Fill it in, then run `/al-spec-init` to
> review it against the brief.

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

## Cross-cutting concerns

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
