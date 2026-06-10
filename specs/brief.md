# Project Brief: Integration Foundation

> Constitution document. The what and the why: high-level customer requirements
> and business processes, in plain language. No AL, no object names. Every agent
> reads this before doing anything.

## Customer / context

The "customer" here is any Business Central partner or product team that needs to
integrate BC with an external system: a storefront, a warehouse system, a payment
provider, a tax service, a long-running approval flow. Today every team reinvents
the same plumbing: a staging table, a way to route messages to handlers, duplicate
protection, error capture, retry, and a screen for operations to fix stuck work.
The reinvention is inconsistent, rarely cloud-safe, and almost never gets the hard
parts (idempotency, correlation, manual recovery) right.

Integration Foundation is a single, reusable AL extension that ships that plumbing
once, correctly, as a framework other apps depend on. It is a framework only. It
contains no business scenario of its own and no sample connectors. A consuming app
adds a handler and, optionally, pipeline stages; it never edits the framework.

## Goals

- Give BC one shared staging record (the Integration Message) that every inbound
  and outbound integration pattern builds on.
- Route each incoming item to the right handler by its type, so adding an
  integration means adding a handler, not changing the framework.
- Guarantee idempotent processing: a repeated request keyed on a stable external
  reference never causes a second side effect, and the caller cannot tell a retry
  from the first attempt.
- Capture handler failures durably and classify them out of band, with a swappable
  classifier so a smarter implementation can replace the default later.
- Support delayed replies: accept a request now, correlate the eventual reply back
  to it across a long-running flow.
- Move a message through ordered, independently retryable stages, with a traceable
  link between a parent request and any work it spawns.
- Make manual recovery a first-class experience modelled on the standard BC inbound
  staging and resolution flow (inspect, retry, resolve, reassign, with counts of
  failed / in progress / waiting work).

## Non-goals

- No sample business scenario, connector, or demo data.
- No test app (the framework ships without a companion test extension).
- No external AI dependency. The error classifier is swappable so an AI classifier
  can be added later by a consuming app, but the framework ships a plain default.
- No Azure-side components. Webhook receivers, queues, and Functions live in the
  consuming solution's Azure plane, not in this extension.
- No bundled API authentication scheme beyond what BC provides for its own API
  pages. Consuming apps own their endpoint exposure decisions.

## Key business processes

The framework supports four integration "arrows" through one staging record:

1. **Inbound.** An external item arrives, is staged, deduplicated on its external
   reference, and dispatched to a handler chosen by its type.
2. **Outbound.** Work to notify a downstream system is staged and sent later by a
   background process, never inline from posting, carrying an idempotency key.
3. **Long-running.** A request is accepted and parked "awaiting reply"; the
   eventual reply is correlated back to the original by a shared correlation id.
4. **Manual.** When automation cannot finish, a person inspects the message, fixes
   the payload, retries, resolves by exception, or reassigns it.

A staged pipeline runs a message through ordered stages, each retryable on its own,
with parent/child links for spawned work.

## Constraints and assumptions

- Business Central online (SaaS), latest AL runtime. Cloud-safe constructs only.
- Ships complete and installable: valid app.json, permission sets covering every
  new object, telemetry on the key lifecycle events, captions and tooltips,
  interfaces over hard dependencies, sensible keys and table relations.
- Assigned object ID range: 73298400 to 73298499.
- Background processing uses the standard BC Job Queue. The framework provides the
  processor logic; scheduling is the consuming app's or administrator's choice.
- The framework follows the shape of the standard BC inbound staging and resolution
  experience (the E-Document model) so it feels native to operations users.

## Success measures

- The extension compiles against the current BC AL toolchain with no errors and
  installs on a clean SaaS tenant.
- A developer can register a new integration type and a new pipeline stage without
  editing any framework object (verified by the extensibility design, not a sample).
- Two requests with the same external reference and type produce exactly one side
  effect; the second returns the first result.
- A failing handler leaves a durable, classified error record; classification runs
  after the failure, not inline, and the classifier can be swapped by configuration.
- A parked request can be matched to a later reply by correlation id.
- A staged message advances one stage at a time and a single failed stage can be
  retried without re-running the stages that already succeeded.
- The key lifecycle transitions emit telemetry that an administrator can monitor.
