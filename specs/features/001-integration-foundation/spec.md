# Feature Spec: Integration Foundation

> The what and why for one feature. No AL, no object names yet (those belong in
> `plan.md`). Stop for human review before planning.

- **Feature id:** 001-integration-foundation
- **Roadmap item:** specs/roadmap.md, item 1 (`001-integration-foundation`)
- **Status:** spec

## Problem

Every BC team that integrates with an external system rebuilds the same plumbing:
a staging record, a way to route messages to handlers, duplicate protection,
durable error capture, retry, correlation for slow replies, and a screen for
operations to fix stuck work. The rebuilds are inconsistent and usually get the
hard parts wrong (idempotency, correlation, manual recovery). This feature ships
that plumbing once, correctly, as a reusable framework. It is a framework only:
no business scenario, no connector, no demo data, no test app. Consuming apps add
a handler (and optionally pipeline stages); they never edit the framework.

## Users and roles

- **Integration developer** (consuming app author): registers a new integration
  type and its handler, and optionally new pipeline stages, by adding objects in
  their own app against the framework's extension points. Never edits framework
  objects.
- **Operations / support user:** monitors the staging queue, and inspects,
  retries, resolves, resolves-by-exception, and reassigns stuck or failed
  messages from a screen modelled on standard BC inbound staging.
- **Administrator:** schedules the background processors (Job Queue), configures
  retry ceilings, and selects which error classifier is active. Monitors the
  lifecycle telemetry.

## Scope

The single staging record (the Integration Message) and six patterns built on it:

1. **Dispatch foundation.** One staging record holds every inbound and outbound
   item. An engine routes each item to a handler chosen by the item's Type. Adding
   an integration is adding a handler, not changing the engine.
2. **Duplicate detection.** Processing is idempotent, keyed on a stable external
   reference plus type. A repeated request never causes a second side effect, and
   the caller cannot tell a retry from the first attempt (it gets the first result).
3. **Error classification.** A handler failure is captured durably on the message,
   then classified out of band (not inline). The classifier is swappable through an
   interface so a smarter (for example AI based) implementation can replace the
   default later without touching callers. No external AI dependency now.
4. **Delayed reply.** A request can be accepted and answered later. The eventual
   reply is correlated back to the original across a long-running flow.
5. **Durable staged pipeline.** A message advances through ordered stages; each
   stage runs and can be retried independently, with a traceable link between a
   parent request and any work it spawns.
6. **Operations and recovery.** A first-class manual experience to inspect, retry,
   resolve, resolve-by-exception, and reassign stuck or failed work, with visible
   counts of how much is failed, in progress, or waiting.

Cross-cutting, in scope: permission set(s) covering every object, telemetry on the
key lifecycle transitions, captions and tooltips on all user-facing surfaces,
interfaces over hard dependencies, sensible keys and table relations, and a README
explaining the objects, how dispatch works, and how a consuming app plugs in a new
integration type and a new pipeline stage.

## Out of scope

- Any sample business scenario, connector, or demo data.
- A companion test app.
- Any external AI dependency (the classifier is swappable; the shipped default is
  rule-based).
- Azure-plane components (webhook receivers, queues, Functions).
- Outbound HTTP calling itself and business-event declarations: the framework
  stages and parks the work and exposes the idempotency key; the consuming app
  owns the actual outbound call and any external business events.
- A bundled API authentication scheme beyond standard BC web service auth.

## User flow

**Developer plugging in a new integration (the headline flow):**

1. In their own app, the developer defines a new value on the framework's
   integration-type extension point and implements the handler interface for it.
2. They write inbound items to the staging record with that Type (via the API page
   or directly), setting the external reference and correlation id.
3. The background processor picks up New messages, runs the idempotency check, and
   dispatches each to the matching handler. No framework object changed.

**Operations recovering a failed message:**

1. A handler fails; the message is captured as Failed with its error text, and is
   later classified (Transient / Permanent / Unknown).
2. The operations user opens the resolution list, sees counts of Failed / In
   Progress / Awaiting Reply, and opens a failed message.
3. They fix the payload and retry (status returns to New, same Message ID and
   idempotency key), or resolve by exception (no retry, audit kept), or reassign
   it to another user. The processor re-runs it idempotently.

**Long-running request:**

1. A request is staged and accepted; the framework parks it Awaiting Reply with a
   status URL and a correlation id.
2. Later, a reply arrives carrying the same correlation id; the framework matches
   it to the parked request and the flow completes. Two rows (request and reply)
   share one correlation id.

**Staged pipeline:**

1. A message enters the pipeline at its first stage. Each stage runs as its own
   background work unit with its own retry, advancing the stage cursor on success.
2. If a stage fails, only that stage is retried; earlier successful stages are not
   re-run. Work spawned by a stage links back to the parent by parent message id.

## Acceptance criteria

Testable, unambiguous. Each becomes at least one test in the Implement step.
(The framework ships without a test app; these are verified by framework-internal
test means chosen in the plan, for example a test-only handler registered through
the public extension point, without shipping a separate test extension.)

- [ ] **Compiles clean.** The extension compiles against the current BC AL
  toolchain with zero errors and installs on a clean SaaS tenant.
- [ ] **Extensible without framework edits.** A new integration type and handler
  can be registered entirely from a separate app, with no change to any framework
  object, and the engine dispatches to it by Type with no CASE statement edit.
- [ ] **Idempotent dispatch.** Given a message already processed for an (external
  reference, type), when a second message with the same pair is dispatched, then
  no second side effect occurs and the caller receives the original stored result.
- [ ] **Concurrent duplicate is safe.** Given a message In Progress for an (external
  reference, type), when a duplicate is dispatched, then it does not start a second
  handler run (it is rejected or made to wait), keeping side effects to one.
- [ ] **Durable, out-of-band error capture.** Given a handler that throws, when it
  runs, then the error is recorded durably on the message and the status is Failed,
  and the error class is assigned by a separate classification step, not inline.
- [ ] **Swappable classifier.** Given a consuming app registers an alternative
  error classifier through the interface, when classification runs, then the
  alternative classifier is used and no caller or framework object is modified.
- [ ] **Delayed reply correlates.** Given a request parked Awaiting Reply with a
  correlation id, when a reply with that correlation id arrives, then it is matched
  to the original request and both rows share the one correlation id.
- [ ] **Staged advance and single-stage retry.** Given a message in a multi-stage
  pipeline, when stage N succeeds then the cursor advances to stage N+1; when a
  stage fails and is retried, only that stage re-runs and earlier stages are not
  re-executed.
- [ ] **Parent/child traceability.** Given a stage spawns additional work, when
  that work is staged, then it references the originating message as its parent.
- [ ] **Manual recovery actions.** From the resolution UI an operations user can
  inspect a message, retry it (returns to New, same Message ID), resolve it,
  resolve it by exception (no retry, audit kept), and reassign it; the list shows
  current counts of Failed / In Progress / Awaiting Reply.
- [ ] **Permissions complete.** A user granted the framework permission set can use
  every object; no object is missing from a permission set.
- [ ] **Telemetry on lifecycle.** Staging, dispatch, handler success, handler
  failure, classification, parking, reply match, stage advance, and manual
  resolution each emit telemetry with the Message ID and Correlation ID.

## Data and rules

- **One staging record** is the spine. Every pattern reads and writes it.
- **Message ID** is a system-generated GUID primary key, never reused, never the
  external dedup key.
- **Status lifecycle:** New, In Progress, Awaiting Reply, Failed, Resolved.
  Background processors query Status. Allowed transitions: New to In Progress;
  In Progress to Resolved, Failed, or Awaiting Reply; Awaiting Reply to In Progress
  (on reply) or Failed; Failed to New (manual retry) or Resolved (resolve / resolve
  by exception). Reassign changes the owner without changing status history.
- **Idempotency key** is (External Reference, Type). The check runs before any side
  effect. A Resolved match replays the stored response; an In Progress match does
  not start a second run.
- **Error capture** is durable on the message (error text, time, retry count) and
  classification is a distinct step assigning an Error Class enum.
- **Correlation ID** is set once at entry and carried on every related row,
  including the request/reply pair.
- **Stage cursor** records pipeline position; status is the cursor, not a new row
  per stage. Parent Message ID links spawned work.
- **Retry count and last error live on the record,** not in code; retrying re-runs
  the same Message ID and the idempotency check prevents a duplicate insert.

## Telemetry and audit

Protected/lifecycle operations that must emit telemetry (house rule): message
staged, dispatched, handler succeeded, handler failed, classified, parked
(awaiting reply), reply matched, stage advanced, manually retried, resolved,
resolved by exception, and reassigned. Custom dimensions include Message ID,
Correlation ID, Type, Direction, Status, and (where relevant) Error Class. Manual
recovery actions keep an audit trail visible on the message.

## Open questions

All open questions were resolved with the owner at the spec review gate
(2026-06-10):

- **Target runtime / application version.** RESOLVED: pin the latest GA, BC 26
  (`application 26.0.0.0`, `runtime 15.0`, `platform 1.0.0.0`).
- **Inbound API page in v1?** RESOLVED: yes. v1 ships one read/insert API page as
  the canonical single staging endpoint, with the Type field routing to handlers.
- **One permission set or two?** RESOLVED: two. A full all-objects set, plus a
  read-only operations-viewer set for users who inspect but do not modify.
- **How to test without a test app.** RESOLVED: defer automated tests. v1 ships no
  test app and no AL test codeunits. Acceptance criteria are verified by a
  documented manual install / smoke check in the README, plus the mandatory
  verifier set and a BCQuality review on the source. Automated coverage is added
  if and when a test app is later approved (tracked in the roadmap "Parked"
  section).
