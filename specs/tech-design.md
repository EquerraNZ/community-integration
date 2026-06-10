# Technical Design: Integration Foundation

> Constitution document. The how, at the system level: which standard Business
> Central modules to reuse, and where custom code is genuinely needed. Feature
> plans (`plan.md`) inherit from this.

## Architecture overview

One staging table, the Integration Message, is the spine of the whole framework.
Every pattern reads and writes that one record. Around it sit a small set of
codeunits and a manual-recovery UI:

- A **dispatcher** reads a message's Type and routes it to a handler resolved from
  an extensible enum that maps to an `IIntegrationHandler` interface. The engine
  never grows a CASE statement; a new integration is a new enum value plus a new
  codeunit.
- An **idempotency check** keyed on (External Reference, Type) runs before any
  side effect, so retries and upstream duplicates collapse to one outcome.
- **Error handling** wraps each handler run. A failure is captured durably on the
  message (error text, stack, failure time) and the message is flipped to Failed.
  An out-of-band **classifier**, resolved through an `IErrorClassifier` interface,
  later assigns an error class (Transient / Permanent / Unknown). The default
  classifier is rule-based; a consuming app can register a smarter one.
- **Correlation** is set once at the entry point and carried on every message,
  including the request/reply pair of a long-running flow. A parked message sits in
  status Awaiting Reply with a status URL and is matched to its reply by
  Correlation ID.
- A **staged pipeline** runs a message through ordered stages. Each stage is a
  codeunit implementing `IIntegrationStage`, dispatched from an extensible enum.
  Status records the cursor (the current stage); a single stage can be retried
  without re-running prior stages. Spawned work links back via Parent Message ID.
- A **resolution UI** (list with status counts, plus a card) lets operations
  inspect, retry, resolve, resolve-by-exception, and reassign messages. It mirrors
  the standard BC inbound staging and E-Document resolution experience.

This is a framework. There is no sample handler, connector, or business object. The
extensibility surface (interfaces and extensible enums) is the product.

## Standard BC modules to reuse

- **Job Queue** for all background processing (dispatch, classification, pipeline
  advance, long-running poll). The framework supplies the processor codeunits;
  scheduling them is an administrator action. No custom scheduler.
- **Telemetry** via `Session.LogMessage` with a stable custom-dimension shape, so
  the key lifecycle transitions surface in Application Insights / the admin center.
- **API pages** (standard BC web services) for exposing the Integration Message as
  a single inbound staging endpoint. No custom auth layer.
- **E-Document / inbound staging experience** as the design reference for the
  manual resolution page (status counts, retry, resolve, audit trail).
- **Isolated Storage / standard setup table** pattern for framework configuration
  (which classifier is active, default retry ceilings).

## Custom-code gaps

Only the integration plumbing BC does not ship as a reusable unit:

- The Integration Message staging table and its status lifecycle.
- The type-to-handler dispatch via an extensible enum and `IIntegrationHandler`.
- The (External Reference, Type) idempotency gate and stored response replay.
- The swappable `IErrorClassifier` and the default rule-based classifier.
- The `IIntegrationStage` pipeline engine and stage cursor.
- The correlation and request/reply matching for long-running flows.
- The manual resolution pages and actions.

## Object ID range

73298400 to 73298499 (100 objects), as assigned in `app.json`. Every object sits
inside this range. The plan allocates sub-bands per pattern.

## Data model (high level)

The single staging table, **Integration Message**, with at least:

- `Message ID` (Guid, primary key). Never reused, never the external key.
- `Direction` (enum: Inbound, Outbound).
- `Type` (Code[40]) drives the dispatcher.
- `Status` (enum: New, In Progress, Awaiting Reply, Failed, Resolved).
- `External Reference` (Text) the stable source-system id; drives inbound dedup.
- `Correlation ID` (Code[40]) one trace id across the whole flow.
- `Parent Message ID` (Guid) span parent for pipelines and spawned work.
- `Document No.` (Code[40]) optional BC document anchor.
- `Request` / `Response` (Blob) payloads in and out.
- `Error Message` (Text/Blob) plus an `Error Class` enum, set out of band.
- `Retry Count` (Integer), `Current Stage` (enum), and lifecycle timestamps.

Recommended keys: PK on `Message ID`; a work key on (Status, Direction, Created
At) for the Job Queue; an idempotency key on (External Reference, Type).

## Integrations

- **Inbound:** one API page over the Integration Message; the Type field routes.
  Idempotency check on (External Reference, Type) before any side effect.
- **Outbound:** staged messages sent by a Job Queue processor. The framework
  surfaces the message GUID as the idempotency key consuming senders must use.
- **Long-running:** Awaiting Reply status plus a status URL; reply correlated by
  Correlation ID. The framework does not itself call external systems; it stages
  and parks, and provides the matching logic.
- **Business events:** out of scope for the framework core. A consuming app fires
  its own external business events from thin subscribers; the framework gives it
  the staging record to write from.

## Cross-cutting concerns

- **Telemetry:** emit on message staged, dispatched, handler succeeded, handler
  failed, classified, parked (awaiting reply), reply matched, stage advanced, and
  manually resolved/reassigned. Stable event ids and custom dimensions including
  Message ID, Correlation ID, Type, Status.
- **Permissions:** one permission set covering every object, plus a read-only
  variant for operations viewers if it adds value. No object omitted.
- **Multitenancy:** all data is tenant/company scoped through normal BC records;
  no cross-company reads. Job Queue processors run in company context.
- **Upgrade:** the table ships at v1 with its full status enum and keys. Enum
  values are append-only thereafter; an upgrade codeunit backfills any field added
  to existing rows in later versions.

## Open technical questions

- Exact target runtime / application version to pin in `app.json` ("latest" needs
  a concrete number for the build; the plan will choose and note it).
- Whether to ship a read-only operations permission set in addition to the full
  one, or keep a single permission set for v1.
- Whether the inbound API page is part of v1 or deferred (the staging table and
  dispatch are the core; the API page is one consumption path among several).
