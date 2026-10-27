---
kind: action-skill
id: al-azure-integration-review
version: 1
title: Azure Integration Plane Review
description: Reviews the Azure integration plane that sits between Business Central and external systems and emits a findings report.
inputs: [pr-diff, file-path, repository]
outputs: [findings-report]
bc-version: [all]
technologies: [powershell]
countries: [w1]
application-area: [all]
---

# Azure Integration Plane Review

Reviews the Azure side of a Business Central integration: the webhook receiver that catches a storefront event, the Logic App that routes a shipment to a WMS, the Service Bus topic that carries Business Events, the Durable Function that schedules a retry, and the Bicep, ARM, or Terraform that provisions them. The integration plane exists so that retry, dead-letter, observability, and credential handling live outside BC, so that BC stays free of external credentials and third-party schema changes do not break BC. This is a leaf action skill: it invokes no sub-skills. For the BC-side rules on the same flows, the orchestrator pairs it with `al-modern-integration-patterns`.

An orchestrator invokes this skill with a `pr-diff` or `file-path` (a change to an Azure artifact under review) or a `repository` (a plane-wide audit). The skill produces a single JSON document conforming to the DO output contract. When the repository contains no Azure artifacts, it reports that plainly and passes; it does not invent findings against files that do not exist.

## Source

The rule set is this skill's own Azure integration-plane rules, now vendored as knowledge files under `custom/knowledge/integration/middlelayer/` (each with `.good`/`.bad` examples in the relevant technology: Bicep, Logic App JSON, Durable Functions JS, or PowerShell), plus the BC-side `integration` knowledge domain where a plane rule maps onto a curated rule (idempotency, correlation, classify-transient-vs-permanent, subscription health). The `middlelayer/` files carry `domain: integration`, so reading the BCQuality knowledge index once and taking the `integration` domain entries as the citable candidate set picks them up across every enabled layer; do not open an article's body until it enters the Worklist. Each Azure plane rule below has a matching file at `custom/knowledge/integration/middlelayer/<slug>.md`, and a finding cites it by path. Only a resource-specific IaC detail with no matching vendored file emits within this skill's integration-plane domain with an `agent:` prefix and `references: []`.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the consuming app's `app.json`, or `unknown`.
- `technologies` - `[powershell]`; the plane is provisioned and reviewed through IaC and pipeline tooling rather than AL.
- `countries` - from the consuming app's `app.json`, else `unknown`.
- `application-area` - the areas served by the integration flow; pass the actual set, do not substitute `[all]`.

Discard artifacts not part of the Azure plane. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

The validator places each Azure artifact on the same four arrows the BC side uses (inbound, outbound, long-running, manual) and applies the rules below. An artifact enters the worklist by type:

- Bicep (`*.bicep`), ARM (`azuredeploy.json`, `*.template.json`), and Terraform (`*.tf`) that provision Functions, Logic Apps, APIM, Service Bus, Storage.
- Logic App / workflow definitions (`workflow.json`, `*.logicapp.json`, Standard `workflow` folders).
- Function app config (`host.json`, `function.json`, retry and binding config).
- APIM policy XML (inbound, backend, outbound, on-error sections).
- Pipeline files that deploy the above, when present.

A rule enters the worklist when the artifact under review touches its area.

## Action

For each worklist item, evaluate the artifact and emit findings. Each rule below is vendored: set the finding `id` to the rule's knowledge-file slug (for example `az-classify-transient-vs-permanent`) and populate `references[]` with `[{ "path": ".claude/bcquality/custom/knowledge/integration/middlelayer/<slug>.md" }]`. Where a BC-side `integration` file is the better match, cite that file instead. Only a resource-specific detail with no vendored file uses an `agent:`-prefixed id with empty `references[]`.

### Receiver and staging

1. **`az-receiver-stages-to-bc`** A webhook receiver (Function, Logic App, or APIM) writes to the BC staging endpoint (the Integration Message API page) and returns fast. It must not attempt to post or run BC business logic inline, and it must not block waiting for BC to finish processing.
2. **`az-receiver-acknowledges-fast`** The receiver acknowledges the upstream caller quickly (a 2xx for accepted, or 202 for async). Long synchronous work inside the receiver causes upstream timeouts and false retries.

### Idempotency

3. **`az-forward-idempotency-key`** Outbound calls from the plane to an external system forward an `Idempotency-Key` (the BC Message ID). Inbound receivers forward the source system's stable id to BC so BC can dedup. The plane must not strip the idempotency key.
4. **`az-idempotent-receiver`** Receivers and queue consumers are designed for at-least-once delivery. The same event may arrive twice. Dedup on the event id or business key before forwarding a second side effect.

### Retry, dead-letter, classification

5. **`az-retry-in-plane`** Retry policy lives in the plane (Logic App retry policy, Function `host.json` retry, Service Bus delivery count), not in a hand-written loop. Configure it explicitly; do not rely on defaults silently.
6. **`az-dead-letter-configured`** Service Bus subscriptions and queues have dead-lettering enabled with a defined max delivery count. Failed messages land in a DLQ for manual intervention, they are not dropped.
7. **`az-classify-transient-vs-permanent`** The plane distinguishes transient failures (408, 429, 5xx, timeouts: retry with backoff) from permanent failures (4xx, invalid data: do not retry, route to DLQ or alert). Retrying a 4xx forever is a block.
8. **`az-durable-retry-not-tight-loop`** Long retries are scheduled by a Durable Function or a Logic App timer, not a tight polling loop and not a BC Job Queue loop. Re-runs carry the same idempotency key.

### Correlation and observability

9. **`az-correlation-header`** The Correlation ID flows on every hop: read it from the inbound message, set it on the Service Bus message header and any outbound HTTP header, and log it at each step. Application Insights / log correlation must be wired so one trace id joins BC, the plane, and external.
10. **`az-observability-wired`** Functions and Logic Apps have Application Insights (or equivalent) configured. A plane with no telemetry cannot be debugged when an integration silently stops.

### Long-running

11. **`az-202-status-poll`** For a long-running external process, the plane handles the 202-plus-status-URL pattern: it parks the work and polls or waits on a callback, then writes the result back to the same Integration Message. It does not hold a synchronous connection open for hours.

### Subscription health

12. **`az-subscription-health-check`** When the plane relies on BC Business Event subscriptions, there is a scheduled health check that lists current subscriptions and alerts on drift. BC subscriptions expire (about 3 days) and are removed silently on a bad response; nothing else will catch it.

### Security and configuration

13. **`az-secrets-in-keyvault`** External credentials and connection strings live in Key Vault (referenced via Managed Identity), not inline in Bicep parameters, app settings literals, or Logic App connection definitions.
14. **`az-managed-identity`** Plane-to-BC and plane-to-Azure-resource auth uses Managed Identity where the service supports it, not a static key or connection string. See `al-rbac-and-access` for the role model.
15. **`az-https-only`** Receivers and Function apps enforce HTTPS only and a current TLS minimum. APIM exposes the receiver, the Function is not public where APIM is the intended front door.

### Cross-checks with the BC side

A complete review pairs this skill with `al-modern-integration-patterns`. The arrows must line up end to end:

- An outbound BC call sets an `Idempotency-Key`; the plane must forward it (`house:outbound-idempotency-key` ↔ `az-forward-idempotency-key`).
- BC sets a Correlation ID once; the plane must carry it on every hop (`house:correlation-id-propagation` ↔ `az-correlation-header`).
- BC parks a long-running message Awaiting Reply; the plane must drive the poll (`house:long-running-status-url` ↔ `az-202-status-poll`).
- BC relies on Business Event subscriptions; the plane must monitor their health (`house:subscription-health-monitor` ↔ `az-subscription-health-check`).

A violation of a hard rule that breaks the flow end to end (a receiver that posts inline, a stripped idempotency key, a 4xx retried forever, secrets inline in Bicep) is a `blocker`. A configuration gap that degrades resilience or observability without breaking the happy path (missing dead-letter config, no Application Insights, retry left on silent defaults) is `major`. A hygiene or hardening gap (TLS minimum not pinned, a Function public where APIM should front it) is `minor`. When a rule is clearly applicable but no violation is detected, emit `info` citing the rule.

Set `confidence` to `high` for unambiguous IaC or policy-XML matches, `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. Provide `suggested-code` only for mechanical, local fixes (add a `dead-letter` setting, pin `minTlsVersion`, replace an inline secret with a Key Vault reference); otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the repository contains no Azure plane artifacts to review; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-azure-integration-review", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 4, "items-evaluated": 4 }
  },
  "findings": [
    {
      "id": "az-classify-transient-vs-permanent",
      "severity": "blocker",
      "message": "The Logic App retry policy retries on every HTTP status including 4xx, so an invalid-data response is retried indefinitely instead of routed to a dead-letter path. Recommendation: classify transient (408, 429, 5xx, timeout) versus permanent (4xx) and only retry the transient set.",
      "location": { "file": "infra/logicapps/order-router.logicapp.json", "line": 62 },
      "references": [{ "path": ".claude/bcquality/custom/knowledge/integration/middlelayer/az-classify-transient-vs-permanent.md" }],
      "confidence": "high"
    },
    {
      "id": "az-secrets-in-keyvault",
      "severity": "major",
      "message": "A storefront API key is supplied as an inline Bicep parameter literal rather than referenced from Key Vault via Managed Identity. Recommendation: move the secret to Key Vault and reference it with a getSecret() call.",
      "location": { "file": "infra/main.bicep", "line": 88 },
      "references": [{ "path": ".claude/bcquality/custom/knowledge/integration/middlelayer/az-secrets-in-keyvault.md" }],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
