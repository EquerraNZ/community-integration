# Feature Plan: Integration Message core

> Produced by `/al-plan-feature` from an approved `spec.md`. The how. Inherits from
> `specs/tech-design.md` and the house rules in `.claude/skills/al-code-review`.
> Stop for human review before implementing.

- **Feature id:** 001-integration-message-core
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Build the staging spine and nothing integration-specific. One table (Integration
Message) with a Guid PK, a unique dedup key, and a dispatcher work key. All access
to it is funnelled through one management codeunit so no other object touches the
table directly (the data-access seam). Routing is an extensible enum that
implements `IIntegrationMessageHandler`, so the dispatcher resolves a handler with
`Type.AsInteger()`-free polymorphism and never grows a CASE. The inbound endpoint
is a single API page; the dispatcher is a Job Queue codeunit. Telemetry is a thin
shared codeunit wrapping `Session.LogMessage`.

## Standard BC reused

- **API pages** (`PageType = API`) for the single inbound endpoint over the table.
- **Job Queue Entries** for the dispatcher; retry cadence is standard Job Queue
  configuration, not a hand-written loop.
- **Codeunit.Run** for the per-message transaction boundary so a handler failure
  rolls back that message's work without touching siblings.
- **`Session.LogMessage`** to Application Insights for telemetry.
- **`ErrorInfo`** for structured, classified failures.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration Message | table | 73298400 | new | The staging spine. |
| Integration Setup | table | 73298402 | new | Singleton configuration. |
| Integration Direction | enum | 73298410 | new | Inbound, Outbound. |
| Integration Msg. Status | enum | 73298411 | new | New, InProgress, AwaitingReply, Failed, Resolved. |
| Integration Message Type | enum | 73298412 | new | Extensible, implements the handler interface. Empty in 001. |
| Integration Error Class | enum | 73298413 | new | Transient, Permanent. |
| IIntegrationMessageHandler | interface | (none) | new | `HandleMessage(var IntegrationMessage)`. |
| Integration Message Mgt. | codeunit | 73298420 | new | Staging, dedup, correlation, status, error, retry. The seam. |
| Integration Msg. Dispatcher | codeunit | 73298421 | new | Job Queue runner; routes New inbound by Type. |
| Integration Telemetry | codeunit | 73298422 | new | `Session.LogMessage` wrapper, custom dimensions. |
| Integration Message API | page | 73298440 | new | Single inbound API endpoint over the table. |
| Integration Setup | page | 73298441 | new | Setup card (singleton). |
| Integration Foundation | permissionset | 73298460 | new | All objects this extension defines. |

All IDs sit inside `73298400`-`73298499`. The dispatcher handler enum extension
points (handlers, events) consume `73298423`+ in later features.

## Data model

**Integration Message** (PK `Message ID` Guid):

- `Message ID` Code? No: Guid, `AutoIncrement = false`, set with `CreateGuid` on
  stage if empty.
- `Direction` enum Integration Direction.
- `Type` enum Integration Message Type.
- `Status` enum Integration Msg. Status.
- `External Reference` Text[100].
- `Correlation ID` Code[40].
- `Parent Message ID` Guid.
- `Document No.` Code[40].
- `Request` Blob, `Response` Blob (subtype JSON via accessor on the codeunit).
- `Error Message` Text[2048].
- `Error Class` enum Integration Error Class.
- `Retry Count` Integer.
- `Created At` DateTime, `Created By` Code[50], `Last Modified At` DateTime,
  `Last Modified By` Code[50].

Keys: PK `Message ID`; unique `Key(Idempotency; External Reference, Type)`; work
`Key(Dispatch; Status, Direction, Created At)`.

`DataClassification`: identifiers and audit `SystemMetadata` /
`CustomerContent` as appropriate; the Request/Response blobs carry customer
content so the fields are `CustomerContent`. `External Reference`, `Correlation
ID`, `Document No.` are `SystemMetadata` (system-generated references, not PII).

**Integration Setup** (singleton, PK `Primary Key` Code[10] always `''`):
`Webstore Customer No.` (relation Customer), `Default Location Code` (relation
Location), `Post Invoice On Shipment` Boolean, `Default Shipping Method Code`
(relation Shipping Agent / Shipment Method), `Despatch Status` Text[20] (the
storefront value, default `Despatched`). No secrets.

## Integration points

- **Inbound API page**: `APIPublisher = 'equerra'`, `APIGroup = 'integration'`,
  `APIVersion = 'v1.0'`, `EntityName = 'integrationMessage'`,
  `EntitySetName = 'integrationMessages'`. Writable: `messageType`,
  `externalReference`, `correlationId`, `payload` (text mapped to Request blob).
  Forced on insert: Direction = Inbound, Status = New. The page is keyed on
  SystemId (house rule); no custom OData key is declared. Dedup in the page
  `OnInsertRecord` by delegating to the mgt codeunit, which returns the existing
  row on a hit.
- **Handler interface**: `IIntegrationMessageHandler.HandleMessage(var
  IntegrationMessage: Record "Integration Message")`. Each Type enum value
  carries `Implementation = IIntegrationMessageHandler = <handler codeunit>`.
- **Idempotency**: dedup on `(External Reference, Type)` before insert, backed by
  the unique key.
- **No outbound calls** in this feature.

## Cross-cutting

- **Permissions**: `Integration Foundation` permission set grants RIMD on both
  tables and X on all codeunits/pages, plus the Job Queue object access the
  dispatcher needs.
- **Telemetry**: event ids `INT-0001`..`INT-0007` (staged, dedup-hit, dispatch-
  start, handler-success, handler-failure, resolved, no-handler) via the
  telemetry codeunit; custom dimensions `correlationId`, `messageId`,
  `messageType`, `errorClass`. No payload bodies, no PII (privacy rules
  `no-pii-in-telemetry-message-string`, `session-logmessage-requires-dataclassification`).
- **Upgrade**: greenfield table; no upgrade codeunit yet. New fields later are
  additive with ObsoleteState discipline; enum values are additive only.
- **Performance**: dispatcher reads by the `Dispatch` key (Status, Direction);
  `SetLoadFields` on the dispatch scan; dedup is a single indexed read on the
  unique key. No FlowFields. The blob is read only inside the handler, never on
  a list scan.

## Risks and decisions

- **Routing without a CASE.** Using `Enum ... implements Interface` plus
  `GetMessageType().HandleMessage(...)` keeps the dispatcher closed to
  modification. Risk: an enum value added without an implementation; mitigated by
  the "no handler" Permanent failure path and a test.
- **Per-message transaction.** The dispatcher runs each handler in its own
  `Codeunit.Run` so one bad message cannot roll back the batch. Decision: the
  dispatcher commits status transitions between messages; the handler's own work
  is inside the run.
- **Blob access seam.** Request/Response are blobs; the mgt codeunit exposes
  `SetRequest(Text)/GetRequest(): Text` so handlers and the API page never touch
  the blob's `CalcFields`/`InStream` plumbing directly.
- **IDataAccess.** The mgt codeunit is the single data-access seam for the table;
  logic codeunits and the dispatcher go through it, satisfying the design-quality
  reviewer's routing expectation without a separate interface layer.

## Test strategy

A test codeunit (`Subtype = Test`) in the test app exercises each acceptance
criterion against a test handler stub registered on a test-only enum value:

- staging creates exactly one row with the right defaults and a correlation id;
- empty correlation id falls back to external reference;
- a duplicate `(External Reference, Type)` stage returns the existing row and
  inserts nothing;
- the dispatcher invokes the handler and resolves on success;
- a Permanent error fails the message with class and error text, no retry bump;
- a Transient error leaves it retryable with the count incremented;
- an unmapped Type fails Permanent with the "no handler" error;
- the Setup singleton auto-inserts.

A `TransactionModel = AutoRollback` test isolation and a test handler that can be
told to succeed / fail Transient / fail Permanent drive the dispatcher paths.
The API-page insert path is covered with a `TestPage`/`Codeunit` insert exercising
the dedup branch.
