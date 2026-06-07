---
kind: action-skill
id: al-bcquality-integration
version: 1
title: BCQuality Consumption Review
description: Reviews whether a consuming repo and its verifier agents consume the BCQuality knowledge corpus correctly and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BCQuality Consumption Review

Reviews how a consuming repo and its verifier agents (`al-code-quality-reviewer`, `al-readability-checker`, `al-test-validator`, `al-test-coverage-validator`, and their peers) consume the Microsoft-maintained BCQuality knowledge corpus, and emits a findings report. The corpus is the source of citable, Microsoft-vetted BC quality rules; the central concern is that agents cite the matching BCQuality file rather than paraphrasing a rule from memory, vendor the corpus correctly, and keep project-specific house rules separate from cited Microsoft rules. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (a whole-repo audit of how the consuming project wires in BCQuality and how its agents cite it) or a `file-path` (a targeted re-check of one agent definition or one vendored consumption file). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the BCQuality consumption contract: how the corpus is vendored, how agents map to knowledge domains, the cite-over-paraphrase rule, the separation of house rules from cited rules, and the refresh procedure. These are integration rules about a consuming repo, not curated knowledge in this corpus, so they are not covered by the BCQuality knowledge domains. Read the BCQuality knowledge index once (the `knowledge-index.json` Entry's preparation step regenerates over the already-filtered clone); no curated domain maps onto consumption hygiene, so for each concrete violation emit an agent finding within this skill's integration-hygiene domain. Do not open individual article bodies at this step; open an article only once it enters the Worklist. The consuming-repo files this skill reasons about - `bcquality/agent-consumption.md`, the `agents/al-*.md` definitions, and the vendored tree under `.claude/bcquality/...` - live in the consumer project, not in this repo; they are referenced inline as prose, never as `references` frontmatter.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the consuming app's target BC version from its `app.json`, or `unknown` if unavailable.
- `technologies` - `[al]`.
- `countries` - the countries declared in the consuming app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas declared by the consuming extension; pass the actual set, do not substitute `[all]`.

Discard tasks with no BCQuality-consuming repo to review. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

Narrow the consumption contract to the artifacts present in the consuming repo or change under review. Group the candidate worklist by area:

- **Vendoring layout** - the Microsoft-authored subset is vendored as plain committed files under `.claude/bcquality/` (no submodule to initialise); the tree carries `skills/` (`entry.md`, `do.md`, `read.md`, `write.md`, `README.md`), `microsoft/skills/review/` (the seven review skills), `microsoft/knowledge/` (the area folders: `performance/`, `privacy/`, `security/`, `style/`, `testing/`, `ui/`, `upgrade/`, each rule as `<rule>.md` plus paired `<rule>.bad.al` / `<rule>.good.al`), `LICENSE` (MIT), `README.md`, and `agent-consumption.md`.
- **Agent-to-domain mapping** - each verifier agent has a **Knowledge sources** section naming its relevant BCQuality folder(s): `al-code-quality-reviewer` to `performance/`, `security/`, `privacy/`; `al-readability-checker` to `style/`, `ui/`; `al-performance-reviewer` to `performance/`; `al-upgrade-checker` to `upgrade/`; `al-test-validator` to `testing/`; `al-test-coverage-validator` to none (coverage is structural). Agents without a one-to-one domain (`al-appsource-validator`, `al-multitenancy-reviewer`, `al-translation-auditor`, `al-permission-set-auditor`, `al-obsolete-tracker`, `al-event-subscriber-auditor`) report against their own rule ids with `references: []`.
- **Cite-over-paraphrase** - when a finding maps onto an existing BCQuality knowledge file, the agent cites it via a `references[]` entry (with `path` relative to the consumer root and the pinned `sha`) rather than restating the rule from memory.
- **House rules** - project-specific rules (no `ODataKeyFields`, the project's object ID range, telemetry pattern, subscriber naming) live in the `al-code-review` skill, applied in addition to BCQuality, and carry `references: []` with a rule slug prefixed `house:`.
- **Refresh** - the vendored subset is re-vendored from upstream and committed (`chore: bump vendored BCQuality to <new-sha>`), with the diff reviewed because rule-content changes affect agent findings.

A rule enters the worklist when the consuming repo's vendored tree, an agent definition, or a finding's reference shape touches its area.

## Action

For each worklist item, evaluate the consuming repo or change and emit findings. These are agent findings within this skill's integration-hygiene domain (`references: []`, `id` prefixed `agent:`, severity capped per `skills/do.md`), since no curated knowledge file covers BCQuality consumption:

- A violation that breaks the audit trail or update-propagation guarantee is a `blocker`: an agent that paraphrases a rule from memory when a matching BCQuality knowledge file exists instead of citing it via `references[]` (the reviewer cannot open the bad/good examples, and the finding goes stale silently when Microsoft updates the rule), or a finding citing a `path` that does not resolve under `.claude/bcquality/`.
- A mapping or hygiene fault is `major`: a verifier agent missing its **Knowledge sources** section or pointing at the wrong domain folder, a house rule emitted with a populated `references[]` (project rules must carry `references: []` and a `house:`-prefixed slug), or a project-specific rule cited as if it were Microsoft-vetted BCQuality content.
- A weaker gap is `minor`: a refresh commit that does not pin or bump the `sha`, a vendored tree missing the `LICENSE` or `agent-consumption.md`, or a `references[]` entry that omits the `sha` needed to verify provenance.
- When a rule is clearly applicable but no violation is detected, emit `info`.

Set `confidence` to `high` for unambiguous structural matches (a missing `references[]` where a knowledge file plainly exists, an unresolvable path), `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. For mechanical fixes (add the `references[]` entry, prefix a house rule slug with `house:`, set `references: []`), emit `findings[].suggested-code` with the literal replacement; otherwise set `suggested-code-omission-reason`. Hold every agent finding to the precision bar in `skills/do.md`; when in doubt, omit. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the task context has no BCQuality-consuming repo to review; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-bcquality-integration", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 5, "items-evaluated": 5 }
  },
  "findings": [
    {
      "id": "agent:paraphrased-rule-instead-of-citing-bcquality",
      "severity": "blocker",
      "message": "al-code-quality-reviewer emits a Commit-inside-loop finding paraphrased from memory while .claude/bcquality/microsoft/knowledge/performance/avoid-commit-inside-loops.md exists. Per the cite-over-paraphrase rule the agent must cite the file via references[] so reviewers can open the bad/good examples and the finding inherits upstream updates. Recommendation: add the references[] entry with the vendored path and pinned sha.",
      "location": { "file": "agents/al-code-quality-reviewer.md", "line": 64 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:house-rule-carries-references",
      "severity": "major",
      "message": "A project-specific 'no ODataKeyFields' rule is emitted with a populated references[]. House rules are not Microsoft-vetted BCQuality content; they must carry references: [] and a 'house:'-prefixed slug. Recommendation: set references: [] and rename the rule slug to house:no-odata-key-fields.",
      "location": { "file": "agents/al-code-quality-reviewer.md", "line": 120 },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
