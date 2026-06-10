# Feature Plan: Integration Foundation

> Produced from the approved `spec.md`. The how. Inherits from
> `specs/tech-design.md` and the house rules in `.claude/skills/al-code-review`
> and `.claude/skills/al-modern-integration-patterns`. Stop for human review
> before implementing.

- **Feature id:** 001-integration-foundation
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Build one staging table, the Integration Message, and a thin set of codeunits and
pages around it. Extensibility is the product: handlers, stages, and the error
classifier are all selected through extensible enums that `implement` an
interface, so a consuming app adds an enum value bound to its own codeunit and the
framework dispatches to it with no CASE statement and no framework edit. Reuse
standard BC for everything around the edges: the Job Queue runs every background
processor, telemetry goes through `Session.LogMessage`, the inbound endpoint is a
standard API page, and the operations UI follows the E-Document inbound-staging
shape. Error capture is done out of the failing transaction using `Codeunit.Run`
isolation so the durable Failed record survives the rollback, and classification
runs later as its own Job Queue pass.

## Standard BC reused

- **Job Queue** runs the dispatcher, the classifier pass, and the pipeline engine.
  The framework supplies the processor codeunits; an administrator schedules them.
- **`Session.LogMessage` telemetry** with a stable custom-dimension shape for the
  lifecycle events. No custom telemetry store.
- **API page** (standard BC web service) as the single inbound staging endpoint.
- **E-Document inbound staging / resolution experience** as the UX model for the
  Integration Messages list, card, and recovery actions.
- **Cue (Activities) pattern** for the failed / in progress / waiting counts.
- **`Codeunit.Run` transaction isolation** to capture a handler error durably
  without the status write being rolled back with it.

## AL objects to add or extend

Interfaces carry no object ID in AL and so are not numbered. Everything numbered
sits inside the assigned range `73298400-73298499`.

### Tables

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration Message | table | 73298400 | new | The single staging record. The spine of every pattern. |
| Integration Setup | table | 73298401 | new | Single-instance setup: active error classifier, retry ceiling, stale-lock timeout. |
| Integration Message Log | table | 73298402 | new | Append-only audit trail of lifecycle and manual-recovery events per message. |
| Integration Cue | table | 73298403 | new | One blank record with FlowField counts for the Activities cue. |

### Interfaces (no object ID)

| Object | Type | Purpose |
|---|---|---|
| IIntegrationHandler | interface | `Process(var IntegrationMessage)`. The handler contract a Type binds to. |
| IErrorClassifier | interface | `Classify(var IntegrationMessage): Enum "Integration Error Class"`. Swappable classifier contract. |
| IIntegrationStage | interface | `Run(var IntegrationMessage)` and `GetNextStage(): Enum "Integration Stage"`. A pipeline stage. |

### Codeunits

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration Message Mgt. | codeunit | 73298410 | new | Public facade and sole data-access point for the table: stage, transition, read/write payloads, spawn child, append log. |
| Integration Dispatcher | codeunit | 73298411 | new | Job Queue entry. Picks New single-handler messages, runs idempotency, isolates and runs the handler, routes the outcome. |
| Integration Handler Runner | codeunit | 73298412 | new | `TableNo = Integration Message`. Resolves Type to `IIntegrationHandler` and calls `Process`. Run via `Codeunit.Run` for error isolation. |
| Integration Idempotency Mgt. | codeunit | 73298413 | new | The (External Reference, Type) dedup check and stored-response replay. |
| Integration Error Handler | codeunit | 73298414 | new | Captures the last error durably on the message after the isolated run fails. No inline classification. |
| Integration Classifier Job | codeunit | 73298415 | new | Job Queue entry. Picks Failed, unclassified messages and runs the active `IErrorClassifier`. |
| Default Error Classifier | codeunit | 73298416 | new | `implements IErrorClassifier`. Rule-based default (error-text heuristics to Transient / Permanent). No AI. |
| Integration Reply Mgt. | codeunit | 73298417 | new | Park a request Awaiting Reply with a status URL; match a later reply to it by Correlation ID. |
| Integration Pipeline Engine | codeunit | 73298418 | new | Job Queue entry. Advances pipeline messages one stage at a time; retries only the current stage. |
| Integration Stage Runner | codeunit | 73298419 | new | `TableNo = Integration Message`. Resolves Current Stage to `IIntegrationStage` and runs it. Run via `Codeunit.Run`. |
| Integration Telemetry | codeunit | 73298420 | new | `SingleInstance`. Emits the lifecycle telemetry with stable event ids and dimensions. |
| Default Integration Handler | codeunit | 73298421 | new | `implements IIntegrationHandler` for the Unspecified type. Errors clearly: no handler registered. Safety net. |
| Integration Foundation Install | codeunit | 73298422 | new | `Subtype = Install`. Seeds the setup record and the cue record; stamps the data version. |

### Enums

| Object | Type | ID | Extensible | Purpose |
|---|---|---|---|---|
| Integration Direction | enum | 73298440 | no | Inbound, Outbound. |
| Integration Status | enum | 73298441 | no | New, In Progress, Awaiting Reply, Failed, Resolved. |
| Integration Error Class | enum | 73298442 | yes | Unknown, Transient, Permanent. Extensible so smarter classifiers can add classes. |
| Integration Type | enum | 73298443 | yes | `implements IIntegrationHandler`. Default value Unspecified bound to Default Integration Handler. Consuming apps add values. |
| Integration Stage | enum | 73298444 | yes | `implements IIntegrationStage`. Values None (0) and Completed (terminal). Consuming apps add ordered stages. |
| Error Classifier Type | enum | 73298445 | yes | `implements IErrorClassifier`. Default bound to Default Error Classifier; setup selects the active one. |
| Integration Log Event | enum | 73298446 | yes | Staged, Dispatched, Succeeded, Failed, Classified, Parked, ReplyMatched, StageAdvanced, Retried, Resolved, ResolvedByException, Reassigned. |

### Pages

| Object | Type | ID | Purpose |
|---|---|---|---|
| Integration Messages | page (List) | 73298450 | Operations list. No FlowField columns (perf). Recovery actions. |
| Integration Message Card | page (Card) | 73298451 | Inspect/edit one message; Retry, Resolve, Resolve by Exception, Reassign; payload viewers; log factbox. |
| Integration Setup | page (Card) | 73298452 | The setup record. |
| Integration Message Log Part | page (ListPart) | 73298453 | Audit-trail factbox on the card. |
| Integration Activities | page (CardPart, cue) | 73298454 | Failed / In Progress / Awaiting Reply counts from the cue table. |
| Integration Message Entity | page (API) | 73298455 | The single inbound staging endpoint. Type routes. No `ODataKeyFields`. |

### Permission sets

| Object | Type | ID | Purpose |
|---|---|---|---|
| Integration Foundation - Full | permissionset | 73298460 | RIMD on all table data; X on all objects. |
| Integration Foundation - Read | permissionset | 73298461 | R on table data and read access to the operations pages. Inspect, not modify. |

## Data model

**Integration Message (73298400)** fields:

- `Message ID` (Guid) primary key, system-assigned, never reused.
- `Direction` (enum Integration Direction).
- `Type` (enum Integration Type) drives dispatch.
- `Status` (enum Integration Status).
- `External Reference` (Text[250]) the stable source id; half the idempotency key.
- `Correlation ID` (Code[40]) one trace id across the whole flow.
- `Parent Message ID` (Guid) links spawned work and reply-to-request.
- `Document No.` (Code[40]) optional BC document anchor.
- `Source System` (Text[100]) optional origin label.
- `Current Stage` (enum Integration Stage) the pipeline cursor; None means a
  single-handler message, not a pipeline.
- `Status URL` (Text[2048]) the poll URL for a long-running reply.
- `Request` / `Response` (Blob) payloads in and out (with text accessors).
- `Error Message` (Blob) last error text; `Error Class` (enum); `Classified`
  (Boolean) gate for the out-of-band classifier.
- `Retry Count` (Integer).
- `Assigned To User ID` (Code[50]) for reassign.
- Lifecycle datetimes: rely on `SystemCreatedAt`/`SystemModifiedAt` plus
  `Processed At` and `Resolved At` where a distinct business time is needed.

Keys: PK `Message ID`; work key `(Status, Direction, SystemCreatedAt)`;
idempotency key `(External Reference, Type)`; `(Correlation ID)`;
pipeline key `(Current Stage, Status)`; `(Parent Message ID)`.

**Integration Setup (73298401):** `Primary Key` (Code[10]); `Active Error
Classifier` (enum Error Classifier Type); `Default Retry Limit` (Integer);
`Stale Lock (minutes)` (Integer).

**Integration Message Log (73298402):** `Message ID` (Guid) + `Entry No.`
(Integer, AutoIncrement) compound PK; `Event` (enum Integration Log Event);
`Description` (Text[250]); user and timestamp via system fields.

**Integration Cue (73298403):** `Primary Key` (Code[10]); FlowField counts
(`Failed`, `In Progress`, `Awaiting Reply`, `New`) as CalcFormula Count of
Integration Message filtered by Status. FlowFields live here, never on the list.

## Integration points

- **Inbound:** Integration Message Entity API page (73298455). Insert stages a
  message; the dispatcher Job Queue picks it up. Idempotency on (External
  Reference, Type) before any side effect; a Resolved twin replays its Response.
- **Outbound:** the framework stages the message and exposes `Message ID` as the
  idempotency key a consuming sender must put on its `Idempotency-Key` header. The
  framework itself makes no `HttpClient` call (none from any posting path).
- **Long-running:** `Integration Reply Mgt.` parks Awaiting Reply with the status
  URL and matches a later reply by Correlation ID. Request and reply are two rows
  sharing one Correlation ID; the reply's `Parent Message ID` points at the request.
- **Dispatch isolation:** the handler and each stage run inside `Codeunit.Run` so a
  thrown error rolls back only that unit of work; the dispatcher then writes the
  durable Failed record and commits it.

## Cross-cutting

- **Permissions:** every object listed above is in `Integration Foundation - Full`;
  the operations pages and table reads are in `Integration Foundation - Read`. The
  `al-permission-set-auditor` must pass with zero gaps.
- **Telemetry:** `Integration Telemetry` emits on staged, dispatched, succeeded,
  failed, classified, parked, reply matched, stage advanced, retried, resolved,
  resolved by exception, reassigned. Stable event ids (for example `IF-0001`..),
  dimensions: messageId, correlationId, type, direction, status, errorClass,
  stage. Every protected operation emits (house rule).
- **Upgrade/migration:** v1 is the initial install; `Integration Foundation
  Install` seeds setup and cue and stamps the data version. No upgrade codeunit is
  needed yet; enum values are append-only from here, and any future field added to
  the table gets a backfill step in an upgrade codeunit at that time.
- **Performance:** no FlowField columns on the Integration Messages list (counts
  live on the cue). Processors use `SetCurrentKey` on the work/pipeline keys,
  `SetLoadFields` before partial reads, and never call out or `Commit` inside a
  record loop. Locking is taken once per unit of work, not per row.

## Risks and decisions

- **Type as an extensible enum, not Code[40].** The integration-patterns rule
  lists `Type` as `Code[40]`. We use an extensible enum that `implements
  IIntegrationHandler` instead, because that is the AL-idiomatic way to dispatch
  with no CASE and to let a consuming app bind a handler in one declaration. This
  satisfies the rule's intent (Type drives a dispatcher, no giant CASE) more
  strongly than a string. Flagged for the reviewer.
- **Stage ordering via `GetNextStage()`.** Each stage names its successor (terminal
  is Completed). Adding a brand-new pipeline is new codeunits with no framework
  edit; inserting a stage into an existing pipeline does touch the predecessor's
  `GetNextStage`. A data-driven sequence table is the documented future option if
  configurable ordering is needed. Accepted for v1 to keep the object count down.
- **Single data-access facade, no `IDataAccess` interface.** All table access goes
  through `Integration Message Mgt.`. We do not introduce an `IDataAccess`
  interface for a single internal table; the facade is the data-access layer.
  Flagged for the `al-code-quality-reviewer`.
- **No automated tests in v1.** Per the resolved open question, acceptance criteria
  are verified by a documented manual smoke check plus the verifier set and a
  BCQuality review. The extension points are exercised by the manual check, not by
  a shipped sample handler.

## Test strategy

No AL test codeunits and no test app ship in v1 (resolved open question). Instead:

- A **manual smoke-check script** in the README walks each acceptance criterion:
  stage a message through the API page, watch the dispatcher resolve it, send a
  duplicate and confirm the stored response replays, force a handler error and
  confirm a durable Failed record then an out-of-band class, park and match a
  reply by Correlation ID, run a two-stage pipeline and retry one stage, and drive
  every recovery action from the card.
- The mandatory verifier set (`al-code-quality-reviewer`, `al-readability-checker`,
  `al-test-coverage-validator`, `al-test-validator`) and a BCQuality review run on
  the source. `al-test-coverage-validator` will report zero automated coverage by
  design; that is recorded against the deferred-tests decision, not resolved by
  inventing a test app.
- The integration-review playlist (`al-integration-pattern-reviewer`,
  `azure-integration-validator`, `al-event-subscriber-auditor`) runs because this
  is integration code, even though no Azure artifact ships.
