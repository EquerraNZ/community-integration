# Feature Spec: Core Messaging

> The shared integration backbone. Everything else builds on this.

- **Feature id:** 001-core-messaging
- **Roadmap item:** #1 in specs/roadmap.md
- **Status:** spec

## Problem

The extension needs a single, reusable mechanism for receiving inbound payloads
and dispatching outbound notifications. Without it, each module would build its
own staging, idempotency, retry, and error handling, duplicating effort and
creating inconsistency. This feature is the foundation: it must exist before any
module (Webstore, WMS) can be built.

## Users and roles

- **Integration layer (machine caller):** posts inbound payloads to the API page
  and receives acknowledgements. Subscribes to business events for outbound
  actions.
- **BC administrator:** monitors Integration Messages (list page), retries
  failed messages, reviews error details.
- **Module developer (future):** adds a new integration by extending the Type
  enum and implementing the processing interface. Does not touch the core.

## Scope

- Integration Message table with Guid PK, Idempotency Key (unique), Correlation
  ID, Type (extensible enum), Status (enum), Request/Response/Error blob fields,
  Parent Message ID, and helper methods.
- Integration Message Status enum: New, In Progress, Completed, Failed.
- Integration Message Type extensible enum (starts empty; modules add values).
- An interface that each Type value implements for processing dispatch.
- An API page that accepts a JSON body, stages an Integration Message (Status =
  New), and returns 201 with the Message ID. If the Idempotency Key already
  exists, returns the existing message (no duplicate).
- A processing codeunit that picks up New messages, dispatches by Type through
  the interface, and transitions Status to Completed or Failed.
- A retry mechanism: a Job Queue codeunit that re-processes Failed messages up to
  a configurable max retry count.
- An Integration Messages list page for administrators (view status, error,
  retry, filter by type/status/date).
- Telemetry signals on stage, process start, process complete, process fail.

## Out of scope

- Any specific message type implementation (Webstore Order, WMS Shipment
  Confirmation). Those belong to features 002-005.
- Setup pages for modules (delivered with each module).
- Permission sets (feature 006).
- Outbound business event definitions (raised by modules, not the core).
- HTTP calls from BC (never happens, by design).

## User flow

### Inbound (machine caller)

1. External system POSTs a JSON body to the API page with an Idempotency Key
   header/field and a Correlation ID.
2. The API page checks whether the Idempotency Key already exists.
   - If yes: returns the existing Integration Message (200, no side effect).
   - If no: inserts a new Integration Message (Status = New), returns 201 with
     Message ID.
3. The processing codeunit picks up the message (immediately or via Job Queue).
4. It reads the Type, resolves the interface implementation, and calls Process.
5. On success: Status moves to Completed, Response Content is set (if any).
6. On failure: Status moves to Failed, Error Content and Error Code are set.

### Retry (administrator)

1. Administrator opens the Integration Messages list page, filters to Failed.
2. Selects a message and chooses Retry (action).
3. The message is set back to New and picked up by the processing codeunit.
4. Automatic retry: a Job Queue entry runs periodically, finds Failed messages
   with retry count below the max, and resets them to New.

### Monitoring (administrator)

1. Administrator opens the Integration Messages list page.
2. Sees status, type, timestamps, correlation ID, error code at a glance.
3. Drills into a message to see full Request, Response, or Error content.

## Acceptance criteria

- [ ] Given an inbound POST with a new Idempotency Key, when the API page
      processes it, then an Integration Message is created with Status = New
      and the response is 201 with the Message ID.
- [ ] Given an inbound POST with an Idempotency Key that already exists, when
      the API page processes it, then no new record is created and the response
      contains the existing Message ID (idempotent).
- [ ] Given an Integration Message with Status = New and a valid Type, when the
      processing codeunit runs, then the interface implementation for that Type
      is called.
- [ ] Given processing succeeds, when the interface returns, then the message
      Status is Completed.
- [ ] Given processing raises an error, when the processing codeunit catches it,
      then the message Status is Failed, Error Content contains the error text,
      and Error Code is populated.
- [ ] Given a Failed message, when an administrator triggers Retry, then the
      message Status resets to New and it is reprocessed.
- [ ] Given automatic retry is configured, when the Job Queue codeunit runs,
      then Failed messages below the max retry count are set to New. Messages
      at or above the max retry count are not retried.
- [ ] Given a message is staged, when telemetry is emitted, then it contains the
      Correlation ID as a custom dimension.
- [ ] Given the Correlation ID is missing from the inbound call, when the API
      page stages the message, then a new Guid is generated and assigned.

## Data and rules

### Integration Message table

| Field | Type | Rule |
|---|---|---|
| Message ID | Guid | PK, auto-generated on insert. |
| Document No. | Text[50] | Human-readable, from a number series (optional). |
| Type | Enum (extensible) | Mandatory. Determines the interface to dispatch. |
| Status | Enum | New → In Progress → Completed or Failed. Only forward transitions during processing; Retry resets Failed → New. |
| Idempotency Key | Text[50] | Unique secondary key. Reject (or return existing) on duplicate. |
| Correlation ID | Guid | Secondary key. Carried on every telemetry signal. |
| Parent Message ID | Guid | Optional. Links a child message to a parent (staged pipelines). |
| Request Content | Blob | The inbound payload (JSON). Set once on stage. |
| Response Content | Blob | Optional. Set on Completed if the processor produces output. |
| Error Content | Blob | Set on Failed. Cleared on Retry. |
| Error Code | Code[20] | Set on Failed. Cleared on Retry. |
| Retry Count | Integer | Incremented each time the message is retried. |
| Created At | DateTime | Set on insert, never updated. |
| Processed At | DateTime | Set when Status leaves New. |

### Status transitions

```
New ──► In Progress ──► Completed
                   └──► Failed ──► New (retry)
```

No other transitions are valid.

### Idempotency rule

The Idempotency Key is the external system's own reference for the payload. If a
record with that key already exists (any status), the API page returns that
record without inserting. This guarantees at-most-once staging regardless of
caller retries.

## Telemetry and audit

| Signal | Dimensions |
|---|---|
| Message staged | Message ID, Type, Idempotency Key, Correlation ID |
| Processing started | Message ID, Type, Correlation ID |
| Processing completed | Message ID, Type, Correlation ID, duration (ms) |
| Processing failed | Message ID, Type, Correlation ID, Error Code |
| Retry triggered | Message ID, Type, Correlation ID, Retry Count |

All signals use custom telemetry (LogMessage with DataClassification = SystemMetadata).

## Open questions

1. **Immediate vs. queued processing.** The tech design recommends immediate by
   default with a setup toggle. This feature will implement immediate processing
   in the API page call. The Job Queue path (for queued mode) is a follow-on
   within this same feature. If time-boxed, immediate-only ships first and
   queued is added before feature 002 needs it.
