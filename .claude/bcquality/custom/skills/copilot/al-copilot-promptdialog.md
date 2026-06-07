---
kind: action-skill
id: al-copilot-promptdialog
version: 1
title: Copilot PromptDialog Page Review
description: Reviews Business Central Copilot UX implemented with the PromptDialog page type and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Copilot PromptDialog Page Review

Reviews Business Central Copilot UX built on the `PageType = PromptDialog` surface: the required page properties, the three sanctioned layout areas, the two sanctioned action areas, the `OnQueryClosePage` persistence pattern, and the AOAI retry loop. It emits a findings report. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with either a `pr-diff` (the standard PR-review entry point for a PromptDialog page change) or a `file-path` (single-file review of a PromptDialog page object). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is this skill's own PromptDialog knowledge plus BCQuality knowledge entries whose domain covers the concerns it touches (style for captions, tooltips, and action naming). Read the BCQuality knowledge index once and take the `style` domain entries as the citable candidate set across every enabled layer; do not open an article body until it enters the Worklist. The PromptDialog framework contract (allowed areas, system actions, mandatory properties) is not covered by the corpus; for a concrete violation there, emit an agent finding within this skill's PromptDialog domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the consuming app's `app.json`, or `unknown`. PromptDialog requires AL runtime 12.1 or later, so this dimension is load-bearing.
- `technologies` - `[al]`.
- `countries` - from the app's `app.json`, else `unknown`.
- `application-area` - the union of areas declared by the changed objects; pass the actual set.

Discard files not applicable to AL. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; cap their findings at `medium` confidence and name the unknown dimension.

## Worklist

Narrow to the rules that apply to the page under review. A rule enters the worklist when the diff or file touches its area:

- **Page properties** - `PageType = PromptDialog`; `Extensible = false`; `Image = Sparkle` (or `SparkleFilled`); `IsPreview` set during the preview lifecycle; deliberate `PromptMode`.
- **Layout areas** - only `Prompt`, `Content`, and `PromptOptions`; no repeater controls in `Prompt` or `Content`; `PromptOptions` carries only option-type fields.
- **Action areas** - only `SystemActions` and `PromptGuide`; only the five system actions (`Generate`, `Regenerate`, `Attach`, `OK`, `Cancel`); no custom system actions; prompt-guide actions set the input variable and render only in `Prompt` mode.
- **Action naming** - no trailing whitespace in action `Name` (the caption may have it, the name may not).
- **Persistence** - `OnQueryClosePage` saves generated content when `CloseAction = Action::OK`.
- **Generation robustness** - the AOAI call is wrapped in a bounded retry loop terminating in a friendly `Error`.
- **Discoverability** - a complex feature provides a prompt guide (at least three examples).

## Action

For each worklist item, evaluate the page object and emit findings. Reframe the correct-build rules as defects to flag:

- **Trailing whitespace in an action `Name`.** This breaks Copilot silently. Flag `blocker` because the feature fails with no visible error. The `Caption` may carry trailing space, but the `Name` may not.
- **`Extensible = true` (or omitted) on a PromptDialog page.** `Extensible = false` is mandatory to protect the AI experience from drift. Flag `blocker`:

  ```al
  page 54320 "Copilot Job Proposal"
  {
      PageType = PromptDialog;
      Extensible = false;   // mandatory
  }
  ```

- **Repeater control inside `area(Prompt)` or `area(Content)`.** Not supported. Flag `major` and recommend a list-of-text or a JSON shape rendered as a single multiline field.
- **A non-option field in `area(PromptOptions)`.** `PromptOptions` accepts only option-type (enum) fields. Flag `major`.
- **A custom system action, or an action area other than `SystemActions` / `PromptGuide`.** Only the five sanctioned system action names work and only two action areas are valid. Flag `major`.
- **Missing `Generate` system action.** Without it the Generate button never appears and the page cannot produce content. Flag `blocker`.
- **No `OnQueryClosePage` persistence on `Action::OK`.** Generated content is lost when the user keeps it. Flag `major`.
- **AOAI call with no retry loop or no terminal friendly `Error`.** A single attempt that surfaces a raw failure is poor UX. Flag `minor` and recommend the bounded retry pattern (zero-indexed up to N attempts, each `Codeunit.Run()` swallowing errors, terminal `Error` with a label).
- **`IsPreview` omitted during a preview release.** The user-facing preview note is missing. Flag `minor`.
- **No prompt guide on a complex feature.** Users cannot phrase prompts; provide at least three examples. Flag `minor`.

Cite a `style` knowledge file in `references` when a finding maps onto one (for example a missing `ToolTip` on a prompt-guide action, or a user-facing string that should be a `Label`); otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`, severity capped per `skills/do.md`). Set `confidence` to `high` for unambiguous property or syntax matches, `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. For mechanical fixes (set `Extensible = false`, strip trailing whitespace from an action name, add the `Generate` system action), emit `findings[].suggested-code`; otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the change touches no PromptDialog page; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-copilot-promptdialog", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 7, "items-evaluated": 7 }
  },
  "findings": [
    {
      "id": "agent:promptdialog-extensible-true",
      "severity": "blocker",
      "message": "This PromptDialog page does not set Extensible = false, which is mandatory for Copilot pages. Recommendation: add Extensible = false to the page properties.",
      "location": { "file": "src/Copilot/CopilotJobProposal.Page.al", "line": 4 },
      "references": [],
      "confidence": "high",
      "suggested-code": "    Extensible = false;"
    },
    {
      "id": "agent:promptoptions-non-option-field",
      "severity": "major",
      "message": "area(PromptOptions) contains a Text field; PromptOptions accepts only option-type (enum) fields, so the field will not render as an option button. Recommendation: model the choice as an enum and bind that field instead.",
      "location": { "file": "src/Copilot/CopilotJobProposal.Page.al", "line": 41 },
      "references": [],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
