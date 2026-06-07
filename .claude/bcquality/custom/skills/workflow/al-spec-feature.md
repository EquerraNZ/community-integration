---
kind: action-skill
id: spec-feature
version: 1
title: Feature Specification Review
description: Reviews a Business Central feature specification for constitution-consistency, testable acceptance criteria, and resolved open questions, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Feature Specification Review

Reviews a feature specification (`specs/features/<id>/spec.md`) for one Business Central feature against the project constitution, and emits a findings report. The spec captures the what and why; it must not name AL objects (that is `al-plan-feature`). The review checks that the constitution exists, that the spec is consistent with all three constitution documents, that its acceptance criteria are concrete enough to become tests, that open questions are recorded rather than guessed away, and that the roadmap status reflects the spec stage. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (audit a feature spec against the constitution and roadmap) or a `file-path` (review the `spec.md` alone). The skill produces a single JSON document conforming to the DO output contract. See `AGENTS.md`.

## Source

The rule set is the feature-spec discipline: the precondition that the constitution exists, the required spec sections, the testability bar for acceptance criteria, the open-questions rule, and the roadmap-status update. Where a check maps onto a curated BCQuality rule (testable acceptance criteria, process gating), read the BCQuality knowledge index once and take the `process` and `testing` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The spec-structure rules are not covered by the corpus; for a concrete gap there, emit an agent finding within this skill's spec-governance domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the constitution or the solution's `app.json`, or `unknown`.
- `technologies` - `[al]`.
- `countries` - the customer localisation from `brief.md`/`app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the application areas the feature touches; pass the actual set, do not substitute `[all]`.

Discard files that are not feature specs. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension.

## Worklist

Narrow to the spec rules that apply to the document under review. A rule enters the worklist when the spec exists, or its precondition is unmet.

- **Constitution precondition** - `specs/brief.md` and `specs/tech-design.md` must exist and have content. If either is missing or empty, the spec has no grounding and `al-spec-init` must run first.
- **Consistency with the constitution** - the spec must be consistent with `brief.md`, `tech-design.md`, and `roadmap.md` (goals, non-goals, constraints, the in-play modules). A spec contradicting the constitution is a finding.
- **Feature identity** - the feature uses the next `todo` roadmap item or the feature the user named, with a confirmed id and slug (`NNN-slug`) matching the roadmap number. A mismatched or missing id/slug is a finding.
- **Required spec sections** - `spec.md` (from `specs/templates/feature-spec.md`) covers: problem, users and roles, scope, out of scope, user flow, acceptance criteria, data and rules, telemetry, open questions. A missing required section is a gap.
- **Testable acceptance criteria** - acceptance criteria must be concrete enough to become tests. A vague, unmeasurable, or untestable criterion is a finding (this becomes the basis for test coverage downstream).
- **No AL, no object names** - the spec captures what and why; naming AL objects is `al-plan-feature`'s job. AL or object names leaking into the spec is a finding.
- **Open questions resolved or recorded** - ambiguities (scope edges, rules, user roles) must be recorded under Open questions rather than guessed. An unresolved open question silently resolved by a guess is a finding.
- **Roadmap status** - the roadmap item moves to `spec`. A stale roadmap status is a finding.

## Action

For each worklist item, evaluate the spec and emit findings:

- A spec written with no constitution present (`brief.md`/`tech-design.md` missing or empty), or a spec that directly contradicts a constitution goal, non-goal, or constraint, is a `blocker`: downstream planning would build on an ungrounded or inconsistent spec.
- An acceptance criterion that is not testable, a missing required spec section, AL or object names appearing in the spec, or an ambiguity resolved by a guess rather than recorded as an open question, is `major`.
- A mismatched feature id/slug versus the roadmap number, a stale roadmap status, or a thin telemetry section, is `minor`.
- When a rule is clearly applicable and the spec satisfies it, emit `info`.

Cite a `process` or `testing` knowledge file in `references` when one matches; otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`). Set `confidence` `high` for unambiguous structural gaps (a missing section, an unresolved open question, a literal object name), `medium` for judgement calls (whether a criterion is truly testable) or `unknown`-dimension cases. Keep inline references such as `al-spec-init` (run first if the constitution is missing), `al-plan-feature` (the next stage once approved), and `al-bc-integrations`, `al-copilot-promptdialog`, `al-ai-agent-sdk` (scoping behaviour when relevant) as prose; do not invoke them. This skill reviews the spec only. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every applicable spec rule was evaluated; `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the task context has no feature spec to review; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "spec-feature", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 0, "major": 2, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 8, "items-evaluated": 8 }
  },
  "findings": [
    {
      "id": "agent:acceptance-criterion-not-testable",
      "severity": "major",
      "message": "Acceptance criterion 'the shipment process should be fast and user-friendly' is not testable: no measurable threshold or observable outcome. Downstream tests cannot be derived from it. Recommendation: restate as a concrete, observable criterion (e.g. 'posting a shipment of up to 50 lines completes in under 3 seconds and shows a confirmation toast').",
      "location": { "file": "specs/features/003-shipment/spec.md" },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:object-names-in-spec",
      "severity": "major",
      "message": "spec.md names AL objects ('codeunit Shipment Post Mgt', 'table 50110 Movement Header'). Object naming belongs to plan-feature; the spec must stay at what and why. Recommendation: remove the object references and move them into plan.md during planning.",
      "location": { "file": "specs/features/003-shipment/spec.md" },
      "references": [],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
