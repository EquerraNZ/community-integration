---
kind: action-skill
id: al-major-release-governance
version: 1
title: Major version upgrade readiness review
description: Reviews Business Central major-version upgrade governance - NextMajor branching, compatibility testing, and app.json version bumps - and emits a findings report.
inputs: [pr-diff, repository]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Major version upgrade readiness review

Reviews how a customer-specific or shared extension is being carried across a Business Central major-version upgrade, and emits a findings report. The governing principle: a `NextMajor` branch is expensive (parallel maintenance), so it is deferred as long as the current Production version still compiles and runs cleanly. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `pr-diff` (a change that bumps `app.json` `application`/`platform` versions, or cuts a release branch) or a `repository` (a readiness audit when a new BC major approaches general availability). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the team's major-upgrade governance, plus the `upgrade` knowledge domain in BCQuality where a governance rule maps onto a curated rule (deprecated-API usage, obsolete-tag handling). Read the BCQuality knowledge index once and take the `upgrade` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The branching and customer-readiness rules are governance the corpus does not cover; for a concrete violation there, emit an agent finding within this skill's upgrade-governance domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the current Production major from `app.json` and the approaching major, or `unknown`.
- `technologies` - `[al]`.
- `countries` - from the app's `app.json`, else `unknown`.
- `application-area` - the areas declared by the changed objects; pass the actual set.

Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; cap their findings at `medium` confidence and name the unknown dimension.

## Worklist

Narrow to the governance rules that apply to the change or audit under review:

- **Customer (PTE) extensions** - do not cut `release/extension/NextMajor` until every customer environment running the extension is on the latest major; compatibility-test on the next major *without* changing `app.json` `application`/`platform`; resolve all warning/info messages on the current version; rely on Microsoft's minimum one-year deprecation notice rather than rushing; verify the extension still compiles on current Production after any NextMajor exploration.
- **Shared (multi-customer) extensions** - branch `release/<Extension>/NextMajor` only when all SaaS customers are on the latest major or a specific feature mandates the new platform; the extension owner owns the branch; mirror continuous-improvement commits into `Sandbox-NextMajor` regularly; refactor non-breaking changes on the current version first.
- **Early-branch justification** - an early `NextMajor` is warranted only by a feature that cannot ship on the current major (new API surface, a Microsoft-required schema change, a performance feature needed for an SLA); the driving feature must be documented in the PR, a backport task tracked, and affected customers told the branch is unavailable until they upgrade.
- **Customer-ready gate** - a customer is upgrade-ready only when every shared extension has a tested NextMajor build (or is confirmed clean on current), PTE extensions are compatibility-tested, `Sandbox-NextMajor` has run a full regression for at least one release cycle, and the customer has agreed to the window.

A rule enters the worklist when the diff bumps `app.json` versions, cuts or modifies a release branch, or the audit scope touches that extension class.

## Action

For each worklist item, evaluate the change or repository state and emit findings:

- A premature `release/extension/NextMajor` cut (customers not yet on the latest major, no mandating feature documented) or an `app.json` `application`/`platform` bump made only for compatibility testing is a `blocker`: it commits the team to parallel maintenance prematurely.
- An unresolved warning/info on the current version that does *not* require a NextMajor dependency, or an early branch with no documented driving feature and no backport task, is `major`.
- A missing `Sandbox-NextMajor` mirror cadence, or pushing a customer to upgrade only to let the team drop the old major, is `minor`.
- When a rule is clearly applicable but no violation is detected, emit `info`.

Cite an `upgrade`-domain knowledge file in `references` when the finding is a deprecated-API or obsolete-tag issue; otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`, severity capped per `skills/do.md`). Set `confidence` `high` for unambiguous `app.json`/branch evidence, `medium` for heuristic or `unknown`-dimension cases. Provide `suggested-code` only for mechanical manifest fixes; otherwise set `suggested-code-omission-reason`.

Outcome selection: `completed` when every worklist item was evaluated; `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the change does not touch upgrade governance; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-major-release-governance", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 0, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 4, "items-evaluated": 4 }
  },
  "findings": [
    {
      "id": "agent:premature-nextmajor-branch",
      "severity": "blocker",
      "message": "This PR cuts release/extension/NextMajor while two customer environments are still on the prior major and no mandating feature is documented. Per the governance rule, defer the branch until all customers are upgraded or document the specific feature that requires the new platform. Recommendation: revert the branch cut and track compatibility testing without bumping app.json.",
      "location": { "file": "app.json", "line": 11 },
      "references": [],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
