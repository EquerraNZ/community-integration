---
kind: action-skill
id: appsource-validation
version: 1
title: AppSource submission validation
description: Reviews a Business Central extension against the AppSource marketplace submission checklist and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# AppSource submission validation

Reviews a Business Central extension for AppSource submission readiness against the marketplace checklist and emits a findings report. This is a leaf action skill: it invokes no sub-skills. Run it before a first submission, or before publishing a new version of an already-listed app.

An orchestrator invokes this skill with a `repository` (whole-extension audit before submission) or a `file-path` (a targeted re-check, for example `app.json` alone). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the AppSource marketplace submission requirements: manifest correctness, signing, code constraints, test coverage, and Partner Center listing metadata. Where a checklist item maps onto a curated BCQuality rule, cite it instead of paraphrasing: read the BCQuality knowledge index once (the `knowledge-index.json` Entry's preparation step regenerates over the already-filtered clone) and take the `security`, `style`, and `upgrade` domain entries as the citable candidate set across every enabled layer. Do not open individual article bodies at this step; open an article only once it enters the Worklist. The marketplace-listing and Partner Center rules are not covered by the corpus; for a concrete violation there, emit an agent finding within this skill's submission-readiness domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the extension's `app.json`, or `unknown` if unavailable.
- `technologies` - `[al]`.
- `countries` - the countries declared in the app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas declared by the extension; pass the actual set, do not substitute `[all]`.

Discard files not applicable to AL extensions. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

Narrow the checklist to the items that apply to the extension or changes under review. Group the candidate worklist by area:

- **app.json manifest** - `id` is a stable, never-reused GUID; `name`/`publisher`/`version` match the Partner Center listing exactly; `application` and `platform` set to the current minimum supported versions; `dependencies` include the System and Base Application; `idRanges` match the publisher's assigned range; `target` is `Cloud`; `runtime` matches the targeted BC runtime; `showMyCode` is `true` only when intentional.
- **Signing** - the `.app` is signed via Azure Key Vault through the AL-Go pipeline; `NavSip.dll` is present on the build runner for local verification.
- **Code** - no `Confirm` dialogs in event subscribers; upgrade codeunits carry a corresponding `previousVersionTag`; user-facing strings use `Label` declarations with translations; telemetry is tagged with the publisher tag.
- **Tests** - a test app exists and runs; a coverage report is attached; the permission set is published and used by tests.
- **Partner Center listing** - search summary 100 characters or under; description leads with the value proposition; logo SVG meets size requirements; demo video (if any) under 90 seconds; privacy policy and T&C URLs live and reachable.
- **Project-specific** - the shared T&Cs template is used (not hand-rolled per app); the privacy policy aligns with NZ and Australian privacy law; the support email points to the project support inbox, not a personal address.

A rule enters the worklist when the manifest, source, or listing metadata under review touches its area.

## Action

For each worklist item, evaluate the extension and emit findings:

- A submission-blocking violation (for example `target` not `Cloud`, an unsigned `.app`, a reused app `id`, or a `Confirm` in an event subscriber) is `blocker`. Cite the curated rule in `references` when one matches (`security`, `style`, `upgrade`); otherwise emit an agent finding within this skill's domain.
- A requirement that will fail validation but is mechanical to fix (missing `previousVersionTag`, a non-`Label` user-facing string, an untagged telemetry call, a search summary over 100 characters) is `major`.
- A listing or hygiene gap that weakens the submission without failing it (description that leads with a feature list, missing demo video) is `minor`.
- When a rule is clearly applicable but no violation is detected, emit `info` citing the rule.

Set `confidence` to `high` for unambiguous manifest or syntax matches, `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. For mechanical fixes (set `target` to `Cloud`, add a `DataClassification`, wrap a literal in a `Label`, shorten a summary), emit `findings[].suggested-code` with the literal replacement; otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the task context has no AL extension to review; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "appsource-validation", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:appsource-target-must-be-cloud",
      "severity": "blocker",
      "message": "app.json declares target 'Internal'. AppSource submissions require target 'Cloud'. Recommendation: set \"target\": \"Cloud\" and rebuild.",
      "location": { "file": "app.json", "line": 14 },
      "references": [],
      "confidence": "high",
      "suggested-code": "  \"target\": \"Cloud\","
    },
    {
      "id": "microsoft/knowledge/style/user-facing-text-uses-labels.md",
      "severity": "major",
      "message": "A user-facing message is built from a string literal rather than a Label, so it cannot be translated for the marketplace listing's supported languages.",
      "location": { "file": "src/Setup/Onboarding.Codeunit.al", "line": 88 },
      "references": [
        { "path": "microsoft/knowledge/style/user-facing-text-uses-labels.md" }
      ],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
