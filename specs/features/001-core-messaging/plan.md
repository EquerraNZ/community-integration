# Feature Plan: Core Messaging

> The shared integration backbone: one staging table, one dispatch interface,
> one API page, one retry mechanism.

- **Feature id:** 001-core-messaging
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Build the Integration Message table as the single staging point for all
integration payloads. Processing is dispatched through an extensible enum that
implements an interface, so modules register by adding an enum value with no
change to the core. An API page accepts inbound payloads and enforces
idempotency. Processing runs immediately on the API call by default; a Job Queue
codeunit handles retry of failed messages. All objects reuse the standard Job
Queue for scheduling and standard BC telemetry for signals.

**Open question resolved:** immediate processing by default. The API page stages
the message and calls the processing codeunit inline. Queued-only mode (stage
then return, process later) is deferred: it can be added as a setup toggle in a
later feature if latency on the API response becomes an issue. This keeps the
first delivery simple and testable.

**Retry configuration:** a constant `MaxRetryCount` (default 3) in the
processing codeunit. Promoted to a setup field if modules need per-company
configuration (deferred to feature 006 hardening pass).

## Standard BC reused

| Module | How |
|---|---|
| Job Queue (Job Queue Entry, Job Queue Management) | Retry codeunit registered as a Job Queue handler. Standard scheduling, no custom scheduler. |
| Telemetry (Session.LogMessage) | All signals use LogMessage with custom dimensions. No custom telemetry infrastructure. |
| Number Series (optional) | Document No. on Integration Message from a number series if configured. Standard NoSeriesManagement. |

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration Message | table | 73298400 | new | Staging table: PK Message ID (Guid), blobs, status, idempotency key, correlation. |
| Integration Message Status | enum | 73298400 | new | New, In Progress, Completed, Failed. |
| Integration Message Type | enum | 73298401 | new | Extensible. Starts empty; modules add values. |
| IIntegration Msg. Processor | interface | — | new | `procedure Process(var IntegrationMessage: Record "Integration Message")` |
| Integration Msg. Process | codeunit | 73298400 | new | Picks up New messages, dispatches by Type via interface, transitions status. |
| Integration Msg. Retry | codeunit | 73298401 | new | Job Queue handler. Finds Failed messages below max retry, resets to New. |
| Integration Messages API | page (API) | 73298400 | new | Inbound API page. Accepts JSON body, stages message, returns Message ID. Idempotency check. |
| Integration Messages | page (list) | 73298401 | new | Admin list page. View, filter, drill-down, manual Retry action. |
| Integration Message Card | page (card) | 73298402 | new | Card page for a single message. Shows blob content (request, response, error). |

**Note:** Interface objects do not consume an ID from the range.

## Data model

### Integration Message (table 73298400)

| Field No. | Field | Type | Length | Key |
|---|---|---|---|---|
| 1 | Message ID | Guid | — | PK |
| 2 | Document No. | Text | 50 | — |
| 3 | Type | Enum "Integration Message Type" | — | — |
| 4 | Status | Enum "Integration Message Status" | — | — |
| 5 | Idempotency Key | Text | 50 | SK1 (Unique) |
| 6 | Correlation ID | Guid | — | SK2 |
| 7 | Parent Message ID | Guid | — | — |
| 8 | Request Content | Blob | — | — |
| 9 | Response Content | Blob | — | — |
| 10 | Error Content | Blob | — | — |
| 11 | Error Code | Code | 20 | — |
| 12 | Retry Count | Integer | — | — |
| 13 | Created At | DateTime | — | — |
| 14 | Processed At | DateTime | — | — |

**Keys:**

| Key | Fields | Unique | Clustered |
|---|---|---|---|
| PK | Message ID | yes | yes |
| SK1 | Idempotency Key | yes | no |
| SK2 | Correlation ID | no | no |
| SK3 | Status, Type | no | no |

SK3 supports the retry codeunit filter (Status = Failed) and the admin list
filter (by status, by type).

**Relations:** Parent Message ID → Integration Message.Message ID (optional
self-reference).

### Helper procedures on the table

- `SetRequestContent(Content: Text)` / `GetRequestContent(): Text`
- `SetResponseContent(Content: Text)` / `GetResponseContent(): Text`
- `SetErrorContent(Content: Text)` / `GetErrorContent(): Text`

These read/write the blob via InStream/OutStream internally.

## Integration points

### API page (inbound)

- **Route:** `api/equerra/integration/v1.0/integrationMessages`
- **Method:** POST (create), GET (read).
- **Auth:** BC standard API auth (OAuth2 / Web Service Access Key).
- **Idempotency:** on POST, if a record with the supplied Idempotency Key
  exists, return it (200) without inserting. Otherwise insert (201).
- **Payload in:** JSON body written to Request Content blob. Type and
  Idempotency Key are top-level fields on the API page entity.
- **Payload out:** Message ID, Status, Document No.

### Business events (outbound, published by this feature)

None. The core publishes no business events of its own. Modules (features
002-005) add events. The core provides the infrastructure they rely on.

### Job Queue (retry)

- Codeunit "Integration Msg. Retry" registered as a recurring Job Queue Entry.
- Filter: Status = Failed, Retry Count < MaxRetryCount.
- Action: set Status = New, increment Retry Count, clear Error Content and
  Error Code.
- Frequency: configurable on the Job Queue Entry (recommend every 5 minutes).

## Cross-cutting

### Permissions

Objects added by this feature will be included in the extension permission set
(feature 006). During development, rely on SUPER for testing.

### Telemetry

| Operation | Event ID | Dimensions |
|---|---|---|
| Message staged | INTMSG-001 | Message ID, Type, Idempotency Key, Correlation ID |
| Processing started | INTMSG-002 | Message ID, Type, Correlation ID |
| Processing completed | INTMSG-003 | Message ID, Type, Correlation ID, Duration (ms) |
| Processing failed | INTMSG-004 | Message ID, Type, Correlation ID, Error Code |
| Retry triggered | INTMSG-005 | Message ID, Type, Correlation ID, Retry Count |

All signals: `Session.LogMessage`, `DataClassification::SystemMetadata`,
verbosity `Normal` (001-003, 005) or `Warning` (004).

### Upgrade/migration

First delivery: no upgrade codeunit needed (no prior schema).

### Performance

- The API page inserts one record per call: no loop, no lock escalation.
- The retry codeunit uses `SetRange(Status, Status::Failed)` with SK3 to avoid
  a table scan.
- Blob reads (GetRequestContent etc.) are on-demand, not on list page load.

## Risks and decisions

| Decision | Rationale |
|---|---|
| Immediate processing (not queued) | Keeps the first delivery simple. The caller gets a synchronous result. If a module's processing is slow, that module can choose to stage a child message and return early. |
| MaxRetryCount as constant (not setup) | Avoids a setup table in the core at this stage. Promoted to setup in feature 006 if needed. |
| No Document No. series initially | The field exists but will be populated by modules if they need a human-readable reference. The core does not mandate a number series. |
| Guid PK (not autoincrement) | Avoids contention on insert. The API caller can pre-generate the Guid if desired (for correlation), or let BC generate it. House rule: no auto-increment PKs. |

## Test strategy

Each acceptance criterion maps to at least one AL test method in a test
codeunit. Tests use a mock implementation of `IIntegration Msg. Processor` (a
test enum value + test codeunit implementing the interface) to verify dispatch,
success, and failure paths without depending on Webstore or WMS modules.

| Acceptance criterion | Test approach |
|---|---|
| New message staged (201) | Insert via API page, assert record exists with Status = New. |
| Duplicate idempotency key (200) | Insert twice with same key, assert one record. |
| Dispatch by Type | Register a test Type, stage a message, process, assert the test processor was called. |
| Status → Completed | Process a message with a succeeding mock, assert Status. |
| Status → Failed, error captured | Process with a failing mock, assert Status, Error Content, Error Code. |
| Manual retry | Set Failed, call Retry action, assert Status = New. |
| Auto retry respects max | Set Retry Count = max, run retry codeunit, assert still Failed. |
| Telemetry includes Correlation ID | Use TestSubscriber on LogMessage, assert dimension present. |
| Missing Correlation ID generates Guid | POST without Correlation ID, assert field is non-empty Guid. |
