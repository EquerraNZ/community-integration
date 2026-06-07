---
kind: action-skill
id: implement-feature
version: 1
title: Feature Implementation Review
description: Reviews a Business Central feature implementation against its approved spec, plan, and tasks, the house rules, and acceptance-criteria coverage, and emits a findings report.
inputs: [pr-diff, repository]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Feature Implementation Review

Reviews how a Business Central feature was implemented against its approved `spec.md`, `plan.md`, and `tasks.md`, applying the house rules and BCQuality, and emits a findings report. The spec is the brain and the implementation is the muscle, so this review checks that production AL was not written without an approved plan, that the tasks were worked in order, that the house rules hold, that every acceptance criterion is covered by a passing test, and that the mandatory verifier pass and the docs/roadmap update happened. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `pr-diff` (the standard entry point: review the implementing change against its spec/plan/tasks) or a `repository` (audit a landed feature against its constitution and artifacts). The skill produces a single JSON document conforming to the DO output contract. See `AGENTS.md` for the full contract.

## Source

The rule set is the implementation discipline: the approved-artifacts precondition, the work-in-order rule, the AL house rules, the test-per-acceptance-criterion requirement, the mandatory verifier set, and the docs/roadmap closeout. Where a check maps onto a curated BCQuality rule (object ID range, label/caption with comment, business logic in codeunits not triggers, telemetry on protected operations, no `ODataKeyFields`, permission-set entries), read the BCQuality knowledge index once and take the `style`, `security`, `performance`, and `upgrade` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The SDD-process rules are not covered by the corpus; for a concrete gap there, emit an agent finding within this skill's implementation-governance domain. The house rules and the citation contract are referenced via `al-code-review` and `al-bcquality-integration`.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the PR branch's `app.json` or the orchestrator-supplied version, else `unknown`.
- `technologies` - `[al]`.
- `countries` - the countries declared in the consuming app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas declared by the changed objects; pass the actual set, do not substitute `[all]`.

Discard files not applicable to AL extensions. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension.

## Worklist

Narrow to the implementation rules that apply to the change or feature under review. A rule enters the worklist when the diff or repository touches the corresponding artifact or token.

- **Approved-artifacts precondition** - `spec.md`, `plan.md`, and `tasks.md` for `<id>` must exist and be approved. Production AL written with no approved plan is a finding by itself.
- **Feature loaded** - the implementation must reflect the spec, plan, tasks, the constitution (`brief.md`, `tech-design.md`), and the house rules in `al-code-review`. AL diverging from the planned object list is a finding.
- **Tasks worked in order** - `tasks.md` is implemented top to bottom with each task ticked as it lands. Out-of-order or unticked completed tasks are a finding.
- **House rules** - object IDs in the assigned range; `Label` and `Caption` with `Comment`; business logic in codeunits, not triggers; telemetry on protected operations; no `ODataKeyFields`; a permission-set entry for every new object. A violation of any house rule is a finding, cited to the matching BCQuality rule.
- **Tests per acceptance criterion** - one or more tests per acceptance criterion in the spec, using `al-ai-test-driven-development` for Copilot/agent features. A missing test for an acceptance criterion is a finding.
- **Build** - the app compiles; the post-build hook prompts the verifier pass. A change that does not compile is a finding.
- **Verifier pass** - the mandatory set runs (al-code-quality-reviewer, al-readability-checker, al-test-coverage-validator, al-test-validator, plus a BCQuality review), with al-performance-reviewer for hot paths and al-upgrade-checker if the schema changed. Every blocking finding must be resolved, citing the BCQuality rule that drove the fix. An unresolved blocking verifier finding is a finding here.
- **Acceptance confirmed** - every acceptance criterion in `spec.md` is covered by a passing test, verifiers re-run until clean. An uncovered criterion is a finding.
- **Docs and roadmap** - feature docs updated (and `al-bc-extension-test-guide` re-run if a TEST_GUIDE is maintained), roadmap item set to `done`. A stale doc or roadmap status is a finding.
- **Merge** - the PR references the feature id and links the spec. A PR with no spec link is a finding.

## Action

For each worklist item, evaluate the change or repository and emit findings:

- Production AL implemented with no approved `spec.md`/`plan.md`/`tasks.md`, an object ID outside the assigned range, a `ODataKeyFields` usage, or an acceptance criterion with no covering test, is a `blocker`: the feature is unverifiable or out of bounds.
- Business logic placed in a trigger instead of a codeunit, a user-facing string without a `Label`/`Caption` + `Comment`, a protected operation with no telemetry, a new object with no permission-set entry, a schema change with no upgrade step, or an unresolved blocking verifier finding, is `major`.
- Tasks ticked out of order, a stale feature doc, a roadmap item not set to `done`, or a PR that does not link the spec, is `minor`.
- When a rule is clearly applicable and the implementation satisfies it, emit `info`.

Cite a `style`, `security`, `performance`, or `upgrade` knowledge file in `references` when one matches (object ID range, label/comment, codeunit-not-trigger, telemetry, `ODataKeyFields`, upgrade step); otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`, severity capped at `minor` per `skills/do.md` for agent findings). Set `confidence` `high` for unambiguous diff matches (an out-of-range ID, a literal `ODataKeyFields`, a string literal where a Label is required), `medium` for heuristic or `unknown`-dimension cases. Provide `findings[].suggested-code` for mechanical fixes (wrap a literal in a `Label`, add a `DataClassification`, move logic out of a trigger stub); otherwise set `suggested-code-omission-reason`. Keep inline references such as the verifier agents, `al-bcquality-integration` (the citation contract), `al-ai-test-driven-development` (Copilot/agent tests), `al-bc-extension-test-guide` (TEST_GUIDE refresh), and `al-appsource-validation` (before an AppSource submission) as prose; do not invoke them. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated; `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the change does not implement a spec-driven feature; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "implement-feature", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 9, "items-evaluated": 9 }
  },
  "findings": [
    {
      "id": "agent:acceptance-criterion-untested",
      "severity": "blocker",
      "message": "Acceptance criterion AC-4 ('a blocked customer cannot be selected on a movement') has no covering test in the diff. The feature cannot be confirmed against its spec. Recommendation: add a test that asserts the lookup rejects a blocked customer before merge.",
      "location": { "file": "test/MovementShipment.Test.al" },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "microsoft/knowledge/style/user-facing-text-uses-labels.md",
      "severity": "major",
      "message": "A user-facing Error message is built from a string literal rather than a Label with Comment, violating the house rule. Recommendation: declare a Label and reference it.",
      "location": { "file": "src/Shipment/ShipmentPost.Codeunit.al", "line": 212 },
      "references": [
        { "path": "microsoft/knowledge/style/user-facing-text-uses-labels.md" }
      ],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
