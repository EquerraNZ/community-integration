# Feature Spec: Integration Message core

> Produced by `/al-spec-feature`. The what and why for one feature. No AL, no object
> names yet (those belong in `plan.md`). Stop for human review before planning.

- **Feature id:** 001-integration-message-core
- **Roadmap item:** specs/roadmap.md item 1
- **Status:** spec

## Problem

Every integration needs the same plumbing: a place to stage a message that has
crossed the boundary, a way to recognise a re-delivery, a single trace id across
hops, a retry-vs-fail decision, and a record an operator can act on when
something breaks. Building that per integration is where integrations rot. This
feature builds the plumbing once: the staging spine that every inbound and
outbound flow rides on, with no integration-specific logic. Features 002-008
plug into it.

## Users and roles

- **The external integration layer** (a system account) POSTs inbound messages to
  one API endpoint and subscribes to outbound events. It never sees BC internals.
- **The platform / Job Queue** runs the dispatcher that processes staged messages.
- **Operations staff** (covered by feature 002) act on failed messages. This
  feature only gives them the data and status model; the UI is 002.
- **Integration developers** add a new integration as one enum value plus one
  handler codeunit, with no change to the core.

## Scope

- The **Integration Message** staging table: one row per message crossing the
  boundary, inbound or outbound, carrying external reference, type, status,
  direction, correlation id, parent link, document anchor, request/response
  payloads, classified error, retry count, and audit fields.
- The **enums**: Direction, Status, Error Class, and the extensible Message Type
  that implements the handler interface.
- The **`IIntegrationMessageHandler` interface** every message type implements.
- The **Integration Message management codeunit**: stage a message (with dedup on
  `External Reference + Type`), set/propagate the correlation id, mark
  In Progress / Resolved / Failed, classify and record errors, increment retry
  state. The single seam every feature calls; no feature touches the table
  directly.
- The **dispatcher**: a Job Queue codeunit that reads `New` inbound messages and
  routes each by `Type` through the handler interface, with classified error
  handling and retry.
- The **single inbound API page** over the table: the one endpoint for every
  source, routing by `messageType`, dedup at insert, keyed on SystemId.
- The **Integration Setup** singleton table and card: the configuration the later
  features read (Webstore customer, default location, invoice-on-shipment toggle,
  shipping method, despatch status). No secrets.
- **Telemetry** on every protected step, keyed by correlation id and message id.
- The **permission set** covering every object this feature defines.

## Out of scope

- The operational list / resolution UI and the manual actions (feature 002).
- The SKU mapping (003) and any integration-specific handler (004-007).
- Outbound event declarations (005, 007) and the subscription monitor (008).
- Any `HttpClient` call. The core never makes one.
- A retention / archive policy for Resolved messages (open question 4, parked).

## User flow

Inbound (the path this feature delivers end to end with a test stub handler):

1. The integration layer POSTs `{ messageType, externalReference, correlationId,
   payload }` to the inbound API page.
2. The page stages one Integration Message: Direction Inbound, Status New, the
   payload in the Request blob, correlation id set (from the body, or from the
   external reference if absent).
3. If `(externalReference, messageType)` already exists, no new row is created;
   the existing row's id and status are returned. Re-delivery is a no-op.
4. The dispatcher Job Queue entry picks up New inbound messages, marks each
   In Progress, resolves the handler from `Type`, and runs it.
5. On success the handler sets Status Resolved and the document anchor. On failure
   the message goes Failed with an Error Message and an Error Class; a Transient
   error is left for Job Queue retry, a Permanent error waits for manual
   resolution (002).

Outbound rows are staged by later features (005) through the same management
codeunit; this feature provides the table shape and the staging call.

## Acceptance criteria

- [ ] Given a POST with a known `messageType`, a new external reference, and a
      payload, when it is received, then exactly one Integration Message is staged
      with Direction Inbound, Status New, the payload in Request, and a non-empty
      Correlation ID.
- [ ] Given a POST whose `correlationId` is empty, when staged, then the
      Correlation ID is set to the `externalReference`.
- [ ] Given an Integration Message already exists for `(externalReference,
      messageType)`, when a second POST with the same pair arrives, then no second
      row is created and the existing Message ID and Status are returned.
- [ ] Given a New inbound message and a registered handler for its Type, when the
      dispatcher runs, then the handler is invoked once and the message ends
      Resolved (for a handler that succeeds).
- [ ] Given a handler that raises a Permanent error, when the dispatcher runs the
      message, then the message ends Failed with the Error Message recorded and
      Error Class Permanent, and Retry Count is not incremented for retry.
- [ ] Given a handler that raises a Transient error, when the dispatcher runs the
      message, then the message is left in a retryable state with Error Class
      Transient and Retry Count incremented.
- [ ] Given a message Type with no registered handler, when the dispatcher reaches
      it, then it fails Permanent with a clear "no handler" error rather than
      silently skipping.
- [ ] Given the Integration Setup singleton, when first opened, then a single
      record exists (auto-inserted) and its fields are editable.
- [ ] Given any object this feature defines, then it is included in the
      Integration Foundation permission set.

## Data and rules

- **Primary key** is a system-assigned Guid `Message ID`; it is never the external
  key and never reused.
- **Dedup key** is a unique key on `(External Reference, Type)`. A duplicate
  insert fails at the database, not in a race.
- **Status** is the only field the dispatcher filters on: New -> In Progress ->
  Resolved | Failed | Awaiting Reply. A Failed message can return to New (002).
- **Direction** distinguishes inbound from outbound rows in the one table.
- **Correlation ID** is set once at staging and never regenerated downstream.
- **Error Class** is Transient (retry) or Permanent (fail to resolution). The
  classification is recorded on failure, never left blank.
- **Retry Count** lives on the row, not in code; the Job Queue policy bounds it.
- The Type enum is **extensible** and its values **implement the handler
  interface**; reordering values is forbidden (external contracts depend on them).

## Telemetry and audit

Protected steps emit `Session.LogMessage` to Application Insights with Correlation
ID and Message ID as custom dimensions, no payload bodies and no PII:

- message staged (with direction and type), dedup hit (re-delivery ignored),
  dispatch started, handler success, handler failure (with error class, not the
  raw customer-content error text), message resolved.

Audit fields (`Created At`, `Created By`, `Last Modified At`, `Last Modified By`)
are stamped by the management codeunit on staging and status change.

## Open questions

- Outbound staging row (tech-design open question 1): resolved for this feature by
  providing the staging call; whether a given outbound flow uses it is decided in
  005. No blocker here.
- External business event preview status (open question 5) does not affect the
  core; it is an outbound concern (005/007).
