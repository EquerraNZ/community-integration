---
kind: action-skill
id: spec-init
version: 1
title: SDD Constitution Review
description: Reviews a Business Central project's Spec-Driven Development constitution (brief, tech design, roadmap) for completeness and consistency, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# SDD Constitution Review

Reviews the project constitution for Spec-Driven Development: the durable, high-level documents (`specs/brief.md`, `specs/tech-design.md`, `specs/roadmap.md`) every agent reads before doing anything. The spec is the brain, and this review checks that the brain is sound before any feature work proceeds. It evaluates whether the three documents exist, cover the required content, reuse standard BC first, justify every custom-code gap, declare a usable object ID range, and number the roadmap so feature folders match. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (audit the full `specs/` constitution against the rules) or a `file-path` (re-check a single constitution document). The skill produces a single JSON document conforming to the DO output contract. See `AGENTS.md` for the full workflow.

## Source

The rule set is the constitution discipline: what `brief.md`, `tech-design.md`, and `roadmap.md` must each contain, the reuse-standard-BC-first principle, and the roadmap-numbering convention. Where a check maps onto a curated BCQuality rule (object ID range governance, the house rules the technical design must respect), read the BCQuality knowledge index once and take the `process` and `style` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The constitution-structure rules are not covered by the corpus; for a concrete gap there, emit an agent finding within this skill's spec-governance domain. The house rules the technical design must respect are referenced via `al-code-review`.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version implied by the constitution or the solution's `app.json`, or `unknown`.
- `technologies` - `[al]`.
- `countries` - the customer localisation declared in `brief.md`/`app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the application areas implied by the business processes in the brief; pass the actual set, do not substitute `[all]`.

Discard files not part of the constitution. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension.

## Worklist

Narrow to the constitution rules that apply to the documents under review. A rule enters the worklist when the corresponding document exists, or its absence is itself the gap.

- **Read what exists first** - when `brief.md`, `tech-design.md`, or `roadmap.md` already have content, this is a refresh: decisions still valid must be preserved, not rewritten away. A refresh that discards a still-valid decision is a finding.
- **No invented facts** - the constitution must rest on stated customer requirements: customer and localisation, the business processes, goals and non-goals, constraints, the assigned object ID range, and the standard BC modules in play. A document asserting facts the inputs do not support is a finding.
- **`specs/brief.md`** - customer/context, goals, non-goals, key business processes, constraints, success measures, in plain language with no AL. A missing required heading or AL leaking into the brief is a gap.
- **`specs/tech-design.md`** - architecture overview, standard BC modules to reuse, the honest custom-code gaps, object ID range, high-level data model, integrations, cross-cutting concerns. Reuse standard BC first; every custom-code gap must be justified. An unjustified custom-code gap, a missing object ID range, or custom code where a standard module fits is a gap.
- **`specs/roadmap.md`** - an ordered, numbered feature list with status `todo`, numbered so folders match (`001-...`, `002-...`). A gap or mismatch in the numbering, or a missing status, is a finding.
- **Stop for review** - the constitution is a human decision. The review confirms the summary and open questions are surfaced; it does not approve on the user's behalf, and unresolved open questions left implicit are findings.

## Action

For each worklist item, evaluate the constitution and emit findings:

- A missing `brief.md` or `tech-design.md` (the constitution does not exist, so no feature spec should proceed), or a `tech-design.md` with no declared object ID range, is a `blocker`: downstream `al-spec-feature`/`al-plan-feature` work cannot ground itself.
- An unjustified custom-code gap where a standard BC module fits, a `roadmap.md` whose numbering does not match the feature-folder convention, a brief that contains AL or invented facts, or a refresh that discarded a still-valid prior decision, is `major`.
- A missing success measure, an unsurfaced open question, or a thin cross-cutting-concerns section in `tech-design.md`, is `minor`.
- When a document is present and satisfies its rule, emit `info`.

Cite a `process` or `style` knowledge file in `references` when one matches; otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`). Set `confidence` `high` for unambiguous structural gaps (a missing file, an absent object ID range), `medium` for judgement calls (whether a custom-code gap is justified) or `unknown`-dimension cases. Keep inline references such as `al-spec-feature` (the next stage once the constitution is approved) and `al-code-review` (house rules) as prose; do not invoke them. This skill reviews the constitution only; AL-level defects belong to other skills and must not be emitted here. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every applicable constitution rule was evaluated; `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the task context has no `specs/` constitution to review; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "spec-init", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:tech-design-missing-object-id-range",
      "severity": "blocker",
      "message": "specs/tech-design.md does not declare an assigned object ID range. Every feature plan must allocate object IDs inside this range, so planning cannot proceed. Recommendation: add the publisher's assigned ID range to the technical design before running spec-feature.",
      "location": { "file": "specs/tech-design.md" },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:unjustified-custom-code-gap",
      "severity": "major",
      "message": "specs/tech-design.md proposes a custom posting engine but does not justify it against the standard BC sales posting module, which appears to cover the described process. The constitution requires reusing standard BC first and justifying every custom-code gap. Recommendation: document why the standard module is insufficient, or reuse it.",
      "location": { "file": "specs/tech-design.md" },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
