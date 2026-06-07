---
kind: action-skill
id: al-bc-integrations
version: 1
title: BC Integration Architecture Review
description: Reviews how a Business Central extension integrates with external systems against architectural patterns and anti-patterns, and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC Integration Architecture Review

Reviews the architecture of any integration between Business Central and an external system (Shopify, 3PL, WMS, custom services, partner platforms) and emits a findings report. It checks the high-level choices: middleware versus direct API, inbound publisher patterns, outbound business events, idempotency, sync direction, and error escalation. This is a leaf action skill: it invokes no sub-skills. For the detailed BC-side house rules it pairs with `al-modern-integration-patterns`, and for the Azure plane with `al-azure-integration-review`.

An orchestrator invokes this skill with either a `pr-diff` (the standard PR-review entry point) or a `file-path` (single-file review of an integration object). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is this skill's integration architecture guidance, plus the `integration` knowledge domain in BCQuality where an architectural choice maps onto a curated rule (stage-every-integration-message, never-call-external-services-from-posting, prefer-business-events-over-handwritten-retry-loops, deduplicate-inbound-messages-with-an-idempotency-check). Read the BCQuality knowledge index once and take the `integration` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. Architectural framing the corpus does not cover is emitted as an agent finding within this skill's integration domain (`references: []`, `id` prefixed `agent:`).

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the consuming app's `app.json`, or `unknown`.
- `technologies` - `[al]`.
- `countries` - from the app's `app.json`, else `unknown`.
- `application-area` - the union of areas declared by the changed objects; pass the actual set, do not substitute `[all]`.

Discard files not applicable to AL extensions. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; cap their findings at `medium` confidence and name the unknown dimension.

## Worklist

Narrow to the architectural concerns that apply to the change under review. A concern enters the worklist when the diff touches integration code: `HttpClient` use, API pages, business events, isolated storage access, or polling/Job Queue logic against an external boundary. The candidate worklist:

- **Direct API vs middleware** - does AL call a third-party API directly, or route through the Azure Integration Services plane (Logic Apps, Service Bus, APIM)?
- **Inbound to BC** - for external-to-BC flows, is the API publisher pattern with custom API pages used, OData for typed access, SOAP only when the consumer cannot do OData?
- **Outbound from BC** - for BC-to-external flows, are business events used instead of polling BC from outside, and is the external-subscriber path (`[ExternalBusinessEvent]`) wired correctly?
- **Idempotency** - does every inbound write carry an idempotency key stored on the record so repeated calls are no-ops?
- **Sync vs replicate** - is the sync direction (sync / replicate / hybrid with per-field owner) explicit and documented?
- **Error escalation** - are transient, permanent, and business-rule errors routed distinctly?

## Action

For each worklist item, evaluate the change and emit findings. Cite the matching `integration`-domain knowledge file in `references` where one exists; otherwise emit an agent finding within this skill's domain.

### Architectural choices

- **Direct API vs middleware.** Use Azure Integration Services as the integration plane; do not call third-party APIs directly from AL. Retry, dead-letter, and observability sit in the plane; BC stays free of external credential management; third-party schema evolution does not break BC. Exception: simple one-shot lookups (currency conversion, address validation) may use `HttpClient` from AL directly, with timeouts and explicit error handling. A direct callout from a posting or business-logic path is a `blocker`.
- **Inbound to BC.** Prefer the API publisher pattern with custom API pages. Use OData for typed access, SOAP only when the consumer cannot do OData.
- **Outbound from BC.** Publish business events; never poll BC from outside when events are available. For a subscriber outside BC, declare an `[ExternalBusinessEvent]` (not the in-process `[BusinessEvent]`) and fire it from a thin subscriber on the real event (release, post). Delivery is asynchronous and post-commit, so it is safe to fire from a posting or release path and nothing is delivered if the transaction rolls back. The external subscriber registers directly by POSTing to `api/microsoft/runtime/v1.0/externaleventsubscriptions` with a `notificationUrl` and a `clientState` (the shared secret echoed on every notification); it needs the `Ext. Events - Subscr` permission set. BC delivers by HTTP webhook to that URL. There is no direct Service Bus or Event Grid delivery for BC, so to land events on a queue, point `notificationUrl` at a thin Function that forwards to it. See `al-modern-integration-patterns` for the citable rules and `specs/contracts/integration-contract.md` for a worked example.

### Common patterns

- **Idempotency.** Every inbound write needs an idempotency key. Project convention: the external system passes a correlation ID, BC stores it on the record, repeated calls with the same ID are no-ops. A missing idempotency check on an inbound write is a `major`.
- **Sync vs replicate.** Sync: BC is the source of truth, external mirrors. Replicate: external is the source of truth, BC mirrors. Hybrid: each field has a defined owner, documented. Pick one and write it down; implicit sync direction causes the worst integration bugs.
- **Error escalation.** Transient errors retry with backoff in the integration plane; permanent errors dead-letter, notify the support inbox, and log to telemetry; business-rule rejections surface to the user via the relevant role centre cue.

### Anti-patterns (flag where present)

- Polling BC every 30 seconds for changes when events are available (`blocker` when it replaces an available event path, else `major`).
- Storing external credentials in BC isolated storage instead of Key Vault via the integration plane.
- One giant payload containing all entities rather than one per business object.
- Direct DB-to-DB sync that bypasses BC business logic.

Set `confidence` to `high` for unambiguous matches (a literal `HttpClient.Send` from a posting subscriber, isolated-storage credential write), `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. When the change is clearly applicable to a rule but no violation is detected, emit `info` citing it. Provide `suggested-code` only for mechanical, local fixes; otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the change touches no integration code; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-bc-integrations", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "custom/knowledge/integration/al-never-call-external-services-from-posting.md",
      "severity": "blocker",
      "message": "A third-party WMS API is called via HttpClient directly from an OnAfterPostSalesDoc subscriber, holding document locks across an external call. Recommendation: stage the work to the Integration Message and let the Job Queue send it outside the posting transaction.",
      "location": { "file": "src/Integration/ShipmentNotifier.Codeunit.al", "line": 47 },
      "references": [
        { "path": "custom/knowledge/integration/al-never-call-external-services-from-posting.md" }
      ],
      "confidence": "high"
    },
    {
      "id": "custom/knowledge/integration/al-deduplicate-inbound-messages-with-an-idempotency-check.md",
      "severity": "major",
      "message": "The inbound order-import write does not check the external reference before inserting, so an upstream retry creates a duplicate sales order. Recommendation: store the source system's stable id and make repeated calls with the same id no-ops.",
      "location": { "file": "src/Integration/OrderImport.Codeunit.al", "line": 112 },
      "references": [
        { "path": "custom/knowledge/integration/al-deduplicate-inbound-messages-with-an-idempotency-check.md" }
      ],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
