---
kind: action-skill
id: modern-integration-patterns
version: 1
title: Modern BC Integration Patterns Review
description: Reviews Business Central integration code on the inbound, outbound, long-running, and manual arrows against the modern-integration house rules, and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Modern BC Integration Patterns Review

Reviews any Business Central integration that crosses the BC boundary (pulling orders from a storefront, pushing shipments to a WMS, calling a payment provider, handling a long-running external process that answers hours later) and emits a findings report. This is the canonical rule set distilled from the BCTechDays 2026 "Modern Integrations" session. This is a leaf action skill: it invokes no sub-skills. For the Azure-plane side of the same flows the orchestrator pairs it with `al-azure-integration-review`; for the broad architectural framing, with `al-bc-integrations`.

An orchestrator invokes this skill with either a `pr-diff` (the standard PR-review entry point) or a `file-path` (single-file review). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the modern-integration house rules below, plus the `integration` knowledge domain in BCQuality where a deck anti-pattern maps onto a curated rule. Read the BCQuality knowledge index once and take the `integration` domain entries (and the `performance` and `security` entries named in the overlap table) as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The house rules the corpus does not vendor are emitted as `house:<slug>` with empty `references[]`. See `al-bcquality-integration` for the citation contract.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the consuming app's `app.json`, or `unknown`.
- `technologies` - `[al]`.
- `countries` - from the app's `app.json`, else `unknown`.
- `application-area` - the union of areas declared by the changed objects; pass the actual set, do not substitute `[all]`.

Discard files not applicable to AL extensions. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; cap their findings at `medium` confidence and name the unknown dimension.

## Worklist

Every pattern lives on one of four arrows. Place the code on the arrow first, then apply the rules for that arrow.

- **Inbound:** pulling data from systems we do not control (storefront to BC).
- **Outbound:** notifying systems downstream of us (BC to WMS).
- **Long-running:** the external system answers later, not in the same call.
- **Manual:** a human fixes a record when automation cannot.

The spine of all four is one staging table, the **Integration Message**. If a flow does not pass through staging, it is almost always wrong. The fields that matter for review:

- `Message ID` (Guid, PK): never reused, never the only external key.
- `Direction` (Enum): splits inbound and outbound at a glance.
- `Type` (Code[40]): drives a dispatcher codeunit. No giant CASE statement.
- `Status` (Enum): New, In Progress, Awaiting Reply, Failed, Resolved. The only field the Job Queue queries.
- `External Reference` (Text): the stable id from the source system. Drives inbound dedup.
- `Correlation ID` (Code[40]): one trace id across BC, queues, and external systems.
- `Parent Message ID` (Guid): span parent for staged pipelines and spawned work.
- `Document No.` (Code[40]): the BC document anchor (sales order, shipment).
- `Request` / `Response` (Blob): payloads in and out.
- `Error Message` + class: last error, classified.
- `Retry Count` (Integer): retry state on the message, never in code.

Recommended keys: PK on `Message ID`, a work key on `(Status, Direction, Created At)`, and an idempotency key on `(External Reference, Type)`.

A rule enters the worklist when the diff touches the arrow or field it governs: a webhook/poll handler, a posting subscriber, an `HttpClient` call, a business-event declaration, a Job Queue entry, or a resolution page.

## Action

For each worklist item, evaluate the change and emit findings. The slugs below are emitted as `house:<slug>` with empty `references[]`; where a deck anti-pattern maps onto a vendored BCQuality rule (see the overlap table) cite that file in `references` instead. Each rule is hard unless marked otherwise: a clear violation of a hard rule is a `blocker`, a contradiction of a softer recommendation is `major`, and a hygiene gap is `minor`. When a rule is clearly applicable but no violation is found, emit `info`.

### Staging

1. **`house:stage-everything`** Inbound and outbound both stage to the Integration Message. Posting must never depend on an external system being up. A webhook handler or poll handler that posts inline is a block.
2. **`house:no-callout-from-posting`** Never call an external service (`HttpClient.Send`) from inside a posting routine or a posting subscriber (`OnAfterPostSalesDoc`, `OnAfterFinalizePosting`, and similar). The locks are held on the document. Stage the work and let the Job Queue send it.
3. **`house:no-synchronous-wait-loop`** Never `Sleep`-and-poll an external service inside an inbound API handler waiting for completion. Accept the work, return `202 Accepted` with a status URL backed by the Integration Message, and let a background processor finish it.

### Inbound

4. **`house:inbound-framing-record`** Polling needs a framing record: last fetch datetime, max window, a lock flag, and optionally a cursor token. Pull a bounded incremental window. Never "fetch all".
5. **`house:polling-lock`** Two Job Queue runs must not fetch the same window. Acquire a lock on the framing record (with a stale-lock timeout) before fetching, release it on exit.
6. **`house:inbound-idempotency-check`** Before staging an inbound message, look up `External Reference + Type`. If found and Resolved, return the previous response. If found and In Progress, wait or reject. Use the source system's stable id, never the internal Message ID, as the dedup key. Duplicates are a guarantee, not an edge case (re-fetch on restart, upstream false retry).
7. **`house:single-staging-endpoint`** Expose the Integration Message as one API page. The Type field routes to the right dispatcher. Do not version a separate API page per source.

### Outbound

8. **`house:outbound-idempotency-key`** Every outbound call carries an `Idempotency-Key` header set to the Integration Message GUID. Same key on every retry, so the receiver returns the same response with no second side effect.
9. **`house:business-events-for-outbound`** Prefer Business Events over a custom AL HTTP retry loop for outbound notification. The platform retries 408, 429, and 5xx for up to 36 hours; subscribers self-serve with no AL change. Do not hand-write a retry loop where a Business Event would do.
10. **`house:one-events-codeunit-per-version`** One events codeunit per integration version. A contract change means a new codeunit and a new versioned procedure name (`OnShipmentReleased_v1`). Never mutate a published event signature.
11. **`house:stable-dto-payload`** A Business Event payload is a contract. Pass a stable, minimal DTO of identifiers plus just enough context. Never pass the BC record or expose secrets in the payload.
12. **`house:validate-before-publish`** Validate the payload before firing the event. Invalid data must not be published and retried indefinitely. Classify transient (network, subscriber down: retry) versus permanent (invalid data: fail and alert). Consider a dead-letter path for events needing manual fix.
13. **`house:subscription-health-monitor`** BC removes a subscription silently when a subscriber responds with anything other than 408, 429, or 5xx. There is no built-in alert. A monitor job must list subscriptions periodically and compare against expected.

#### External business events (the cross-boundary flavour of rule 9)

Rule 9 says prefer Business Events for outbound. When the subscriber is outside BC (an Azure Function, a Logic App, any HTTP endpoint), the specifics are:

- **Declare it `[ExternalBusinessEvent]`, not `[BusinessEvent]`.** Plain `[BusinessEvent]` is consumed in-process by other AL extensions only and is not delivered outside BC. `[ExternalBusinessEvent('name', 'Display', 'Desc', Category)]` is the externally deliverable one. Its procedure parameters become the notification payload (keep them a minimal DTO of identifiers, per `house:stable-dto-payload`). Fire it from a thin subscriber on the real event (release, post). Available from runtime 11; still labelled preview, so confirm against current docs.
- **Delivery is async and post-commit.** BC sends the notification only after the firing transaction commits, and never if it rolls back. This is why firing an external business event from a release or posting path does not violate `house:no-callout-from-posting`: it is not an HTTP call, and nothing leaks for work that rolls back.
- **The external subscriber registers directly.** An Azure subscriber does not need Power Automate or Dataverse. It POSTs to `api/microsoft/runtime/v1.0/externaleventsubscriptions` with `eventName`, `appId`, `notificationUrl`, and a `clientState`. BC then POSTs notifications to `notificationUrl`, echoing `clientState` (which the receiver validates as the shared secret). This is a different mechanism from the data-change webhook subscriptions (`api/v2.0/subscriptions`), which use a validationToken handshake and a 3-day expiry; the docs do not state those for the business-events endpoint. The subscriber app needs the `Ext. Events - Subscr` permission set.
- **There is no Service Bus or Event Grid direct delivery for BC.** Delivery is an HTTP webhook to `notificationUrl`. To land events on Service Bus, point `notificationUrl` at a thin Function that forwards to the queue, then stage from there. `house:subscription-health-monitor` still applies: confirm the subscription survives and the receiver returns 2xx fast.

See `specs/contracts/integration-contract.md` (contracts C and G) for a worked example, and the BC docs page "Business events on Business Central".

### Correlation and durability

14. **`house:correlation-id-propagation`** Set the Correlation ID once at the entry point. Carry it on every subsequent message, event payload, queue header, and outbound call. Log it on every step. It is the second most important field on the message after the key.
15. **`house:long-running-status-url`** When the external system returns `202 Accepted`, park the message Awaiting Reply with the status URL on it. A scheduled Job Queue or a Logic App timer polls until the answer arrives. Two Integration Message rows (request and confirmation) share one Correlation ID.
16. **`house:retry-state-on-message`** Retry count and last error live on the Integration Message, not in code. Retrying re-runs the same Message ID; the idempotency check stops a second insert.

### Staged pipelines

17. **`house:split-by-stage`** A multi-step flow splits into stages, each its own Job Queue entry with its own lock window and retry policy. One big handler is one big lock and one big rollback. A failed stage rolls back only its own work.
18. **`house:stage-interface`** Stages implement an `IIntegrationStage` interface dispatched from an extensible enum. Adding a stage is one new codeunit, no orchestrator change. Status is the cursor that records position; do not create a new row per stage.
19. **`house:no-cross-stage-state`** Stages must not share state. Cache item, customer, and location lookups inside a single stage run (a Dictionary cleared on each invocation). No cross-stage or global cache. If a lookup is hot enough to need a global cache, the design is wrong.

### Orchestration boundary

20. **`house:orchestration-boundary`** The Job Queue owns short, BC-bounded work units. If a flow leaves BC for more than ~30 seconds, give it to external orchestration (Logic App, Durable Function, Service Bus). Do not schedule long external retries in a Job Queue tight loop.

### Manual intervention

21. **`house:manual-resolution-first-class`** Failed messages stay editable. Ops fixes the payload, status flips to New, the processor picks it up again with the same Message ID and idempotency key. Provide a resolution page with Resolve, Confirm-by-Exception (no retry, audit kept), and Reassign actions.
22. **`house:edocument-parallel`** The shape is the same one Microsoft ships in the box: E-Document has inbound staging, a manual resolution page, a status enum, retry actions, and an audit trail. If unsure a design is sound, compare it side by side with E-Document.

### Project house rule (carried from al-code-review)

23. **`house:no-odatakeyfields`** Never add `ODataKeyFields` to a BC API or query definition unless the design genuinely needs it.

### Where these overlap with BCQuality

Some deck anti-patterns map onto vendored BCQuality rules. When they do, cite the BCQuality file in `references` instead of a `house:` slug:

- Commit inside an iteration: `performance/avoid-commit-inside-loops.md`.
- A Confirm or user prompt inside a posting transaction: `performance/avoid-user-prompts-inside-transactions.md`.
- A Business Event or integration event payload that leaks secrets: `security/integrationevent-must-not-expose-secrets.md`.
- Reading a row but using few fields before a large `FindSet`: `performance/use-setloadfields-for-partial-records.md`.

### Decision matrix (the expected pattern per scenario)

| Scenario | Pattern | Why |
|----------|---------|-----|
| External pushes data to us, fast | Webhook receiver in Azure plus staging POST | BC cannot subscribe directly. Always stage. |
| External only exposes a paged API | Job Queue polling plus framing record | Bounded window. Lock. Last fetch. |
| BC publishes to many subscribers | Business Events plus versioned codeunit | Platform retry. Subscribers self-serve. |
| BC calls one external system | Staged Integration Message plus Job Queue sender | Never call out from posting. Idempotency-Key every request. |
| External answers hours later | 202 Accepted plus status URL plus durable poll | Two Integration Messages, one Correlation ID. |
| Multi-step flow, short locks | IIntegrationStage plus per-stage Job Queue | Short locks. Targeted retry. Per-stage rollback. |
| Humans fix payloads | Resolution page on Integration Message | Same shape as E-Document. Audit trail kept. |

Set `confidence` to `high` for unambiguous pattern matches (a literal `HttpClient.Send` in a posting subscriber, a `[BusinessEvent]` where an external subscriber is intended, a `Sleep`-poll loop in an API handler), `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. Provide `suggested-code` only for mechanical, local fixes (add the `Idempotency-Key` header, rename `[BusinessEvent]` to `[ExternalBusinessEvent]`, remove an `ODataKeyFields` line); otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract, and `al-code-review` for the general AL house rules.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the change touches no integration code on any of the four arrows; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "modern-integration-patterns", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 5, "items-evaluated": 5 }
  },
  "findings": [
    {
      "id": "house:no-callout-from-posting",
      "severity": "blocker",
      "message": "An HttpClient.Send call to the WMS is made inside an OnAfterPostSalesDoc subscriber, holding the document locks across the external call. Recommendation: stage the work to the Integration Message and let the Job Queue send it after commit.",
      "location": {
        "file": "src/Integration/ShipmentNotifier.Codeunit.al",
        "line": 58,
        "range": { "start-line": 58, "end-line": 64 }
      },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "house:outbound-idempotency-key",
      "severity": "major",
      "message": "The outbound POST to the payment provider does not set an Idempotency-Key header, so a retry can charge twice. Recommendation: set Idempotency-Key to the Integration Message GUID and reuse it on every retry.",
      "location": { "file": "src/Integration/PaymentSender.Codeunit.al", "line": 91 },
      "references": [],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
