---
kind: action-skill
id: plan-feature
version: 1
title: Feature Plan Review
description: Reviews a Business Central feature plan and task list against its approved spec, object ID range, and verifier expectations, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Feature Plan Review

Reviews the technical plan and ordered task list (`plan.md` + `tasks.md`) for a Business Central feature whose `spec.md` is approved, and emits a findings report. This is the bridge from what to how, with no production AL written yet, so the review checks that the plan maps the spec onto AL objects with IDs inside the assigned range, reuses standard BC first, declares the data model and cross-cutting concerns, lists verifiable tasks, and pre-flights cleanly against the verifier agents. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (audit `plan.md`/`tasks.md` against the spec, the technical design, and the house rules) or a `file-path` (review the `plan.md` alone). The skill produces a single JSON document conforming to the DO output contract. See `AGENTS.md`.

## Source

The rule set is the planning discipline: the approved-spec precondition, the object-ID-range constraint, the reuse-standard-BC-first principle, the required `plan.md` and `tasks.md` sections, and the verifier pre-flight. Where a check maps onto a curated BCQuality rule (object ID range, IDataAccess seam, `ODataKeyFields` prohibition, upgrade step for schema changes), read the BCQuality knowledge index once and take the `style`, `performance`, and `upgrade` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The plan-structure rules are not covered by the corpus; for a concrete gap there, emit an agent finding within this skill's plan-governance domain. The house rules the plan must respect are referenced via `al-code-review`.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from `tech-design.md` or the solution's `app.json`, or `unknown`.
- `technologies` - `[al]`.
- `countries` - the customer localisation; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the application areas the planned objects touch; pass the actual set, do not substitute `[all]`.

Discard files that are not feature plans. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension.

## Worklist

Narrow to the plan rules that apply to the documents under review. A rule enters the worklist when the plan or task list exists, or its precondition is unmet.

- **Approved-spec precondition** - `specs/features/<id>/spec.md` must exist and be approved with acceptance criteria and open questions resolved. If criteria or open questions are unresolved, planning is premature and `al-spec-feature` must run first.
- **Inputs read** - the plan must reflect the feature `spec.md`, `specs/tech-design.md` (reuse standard BC, object ID range, data model), and the house rules in `al-code-review`. A plan inconsistent with the technical design is a finding.
- **Reuse first, justify custom** - the plan must decide which standard BC modules to reuse and what custom AL is genuinely needed. Unjustified custom AL where a standard module fits is a finding.
- **Object IDs in range** - every new object gets an ID inside the assigned range. An object ID outside the range is a finding.
- **`plan.md` sections** - (from `specs/templates/feature-plan.md`) approach, standard BC reused, the AL object table (name, type, id, new/extend, purpose), data model, integration points, cross-cutting concerns (permissions, telemetry, upgrade/migration, performance), risks, and test strategy. A missing required section is a gap.
- **`tasks.md` sections** - (from `specs/templates/feature-tasks.md`) an ordered, checkable list including explicit tasks for permission-set entries, telemetry, tests per acceptance criterion, the build-and-verify pass, and docs/roadmap. A missing class of task (especially a test per acceptance criterion) is a finding.
- **Verifier pre-flight** - the plan must be sanity-checked against what the verifiers enforce: object IDs in range, an IDataAccess seam where logic touches the DB, no `ODataKeyFields`, an upgrade step for any schema change. A plan that would fail a verifier on contact is a finding.
- **Roadmap status** - the roadmap item moves to `planned`. A stale status is a finding.

## Action

For each worklist item, evaluate the plan and task list and emit findings:

- A plan written against an unapproved spec (acceptance criteria or open questions unresolved), or an `app.json`/object plan that allocates object IDs outside the assigned range, is a `blocker`: the implement step would start unclean or out of bounds.
- A planned schema change with no upgrade step, logic that touches the DB with no IDataAccess seam, a planned `ODataKeyFields` usage, unjustified custom AL where a standard module fits, or a `tasks.md` missing a test task per acceptance criterion, is `major`.
- A missing `plan.md` cross-cutting-concern (telemetry or performance not addressed), a missing permission-set-entry task, or a stale roadmap status, is `minor`.
- When a rule is clearly applicable and the plan satisfies it, emit `info`.

Cite a `style`, `performance`, or `upgrade` knowledge file in `references` when one matches (object ID range, IDataAccess, `ODataKeyFields`, upgrade step); otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`). Set `confidence` `high` for unambiguous gaps (an out-of-range ID, a missing test task, a planned `ODataKeyFields`), `medium` for judgement calls (whether custom AL is justified) or `unknown`-dimension cases. Keep inline references such as `al-spec-feature` (run first if the spec is unapproved), `al-code-review` (house rules), `al-performance-profiler`, `al-major-release-governance` (if the plan changes schema), `al-appsource-validation` (if bound for AppSource), and `al-implement-feature` (the next stage once approved) as prose; do not invoke them. This skill reviews the plan only; AL-level defects belong to the verifier skills. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every applicable plan rule was evaluated; `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the task context has no feature plan to review; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "plan-feature", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 8, "items-evaluated": 8 }
  },
  "findings": [
    {
      "id": "agent:object-id-outside-range",
      "severity": "blocker",
      "message": "plan.md allocates table 60110 'Movement Header', but tech-design.md assigns the range 50100..50149. Object IDs outside the assigned range are rejected by the verifier and break AppSource ID-range rules. Recommendation: renumber the planned objects inside 50100..50149.",
      "location": { "file": "specs/features/003-shipment/plan.md" },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:schema-change-no-upgrade-step",
      "severity": "major",
      "message": "plan.md adds a non-empty field to an existing table but tasks.md has no upgrade-codeunit task. The verifier al-upgrade-checker will flag this. Recommendation: add an upgrade step that migrates existing rows and a corresponding task in tasks.md.",
      "location": { "file": "specs/features/003-shipment/tasks.md" },
      "references": [],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
