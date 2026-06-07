---
kind: action-skill
id: page-scripting-e2e
version: 1
title: BC Page Scripting E2E Review
description: Reviews a Business Central Page Scripting (.yml) end-to-end test layer for correct layering, determinism, and replay-harness wiring, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC Page Scripting E2E Review

Reviews a Business Central extension's browser-level test layer built on BC's native Page Scripting (record/replay `.yml`) plus the `e2e-replay` harness, and emits a findings report. This is the layer that catches UI regressions the AL TestPage suite is structurally blind to. The review checks that each flow sits in the cheapest layer that can verify it, that every recording is deterministic against seeded fixtures, and that the recordings are wired so the whole set replays from one command. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (audit the whole Page Scripting layer, the plan, the seed factory, and the harness wiring) or a `file-path` (review one `.yml` recording or the `E2E-PLAN.md`). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the three-layer test model and the Page Scripting recording discipline: layer selection, the residue that needs a rendered client, the recording plan shape, determinism via a seeded Test Seed Factory and reset No. Series, the record/tidy step, and the `e2e-replay` harness wiring with its known gotchas. Where a check maps onto a curated BCQuality rule (test determinism, test isolation), read the BCQuality knowledge index once and take the `testing` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The Page Scripting and harness rules are not covered by the corpus; for a concrete violation there, emit an agent finding within this skill's e2e-testing domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the extension's `app.json`, or `unknown` if unavailable.
- `technologies` - `[al]`.
- `countries` - the countries declared in the app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas exercised by the recorded flows; pass the actual set, do not substitute `[all]`.

Discard files not applicable to AL extensions or Page Scripting tests. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension.

## Worklist

Narrow to the rules that apply to the recordings, plan, seed, and harness under review. A rule enters the worklist when the artifact it governs is present in the change or repository.

- **Layer selection (the three-layer model)** - every flow belongs to exactly one layer, placed in the cheapest that can verify it. Layer 1 is the AL TestPage suite (logic, state transitions, validation errors, action enable/disable gates, proportional math, FlowField values, permission RIMD); it is fast, deterministic, runs in a container/CI, and is the default. Layer 2 is Page Scripting `.yml` (this skill's layer): the rendered-UI residue layer 1 cannot observe. Layer 3 is the manual checklist (phone viewport, subjective "does it look right").
- **Page Scripting residue (and not an AL test)** - only things that need a rendered client belong here: notification toasts (`Notification.Send` is silent in TestPage), cue/tile rendering and Style, page visibility/editability refresh after a field change, FactBox refresh on row change, dropdown/lookup population and filter-as-you-type narrowing, modal/dialog flow a user clicks through, and real posting through standard codeunits driven from the UI. If a check can be made by reading a record or asserting a field after invoking a codeunit, it belongs in layer 1 and must not be recorded.
- **Recording plan** - `Page Scripting/E2E-PLAN.md` is a numbered chain of small single-purpose recordings, one flow each. Each captures: file name `E2E-NN <flow>.yml` (the `NN` prefix sorts the folder into play order), the exact click-path (Tell Me to page to field to value to action), the deterministic precondition, and what residue item it verifies.
- **Determinism (the seed)** - a recording that depends on ambient data is not repeatable. Each recording anchors to seeded, deterministically named fixtures: a Test Seed Factory codeunit (gated behind an `Allow Test Data Seed` toggle, DEV/UAT only) that `Clear`s then `Seed`s a known set with a fixed prefix (e.g. `FE2E-`), idempotent. Recordings that create records repoint the relevant No. Series at a freshly reset test series during seed so a recorded "New" always yields the same No. (e.g. `FE2E-MOV-001`), restoring the default on clear. `E2E-00 Clear and Seed.yml` heads every batch. Lookups type the full code as a filter-as-you-type value to narrow to exactly one row; never "click the first row".
- **Record and tidy** - recorded in the web client (Settings to Page scripting (Preview) to Start new to drive to Stop to Save), then each raw `.yml` is tidied with a real name + description, the replay prerequisite, and intent-readable step descriptions, keeping the recorder's `telemetryId`/`runtimeId`/targeting exactly as captured (the replay engine correlates on them). Saved into `Page Scripting/`.
- **Replay harness** - the `e2e-replay` harness (scaffolded into the `bc-extension` template) batch-replays every recording in order via `run.ps1` or the "E2E: Replay Page Scripting recordings" VS Code task. Adding a recording is dropping a file in `Page Scripting/`.
- **Harness gotchas (already solved, do not relearn)** - bc-replay cannot run from a path with a space (its `npx playwright test "<spec>"` splits a spaced `node_modules` path and reports "No tests found"); `run.ps1` installs into a space-free dir and junctions the recordings in. No interactive-login mode: credentials come from env vars (AAD); push MFA works only headed-with-manual-approve, and unattended/CI needs a TOTP or password-only account. The recordings globber rejects `..`; keep recordings reachable without a parent traversal (the default pattern is `**/recordings/*.yml`).

## Action

For each worklist item, evaluate the recordings, plan, seed, and harness and emit findings:

- A Page Scripting recording that verifies something a layer-1 AL TestPage could assert (reading a record or a field after invoking a codeunit) is a `major` layering violation: it belongs in the cheaper, deterministic layer. A recording that depends on ambient data with no seeded, deterministically named fixture (or a create flow that does not reset the No. Series, so run 2 drifts to `-002`) is a `major` determinism defect.
- A recording that relies on "click the first row" instead of filter-as-you-type to a single match, a missing `E2E-00 Clear and Seed.yml` head of batch, a recording whose `telemetryId`/`runtimeId`/targeting was altered from the capture (breaking replay correlation), or recordings placed where the harness path contains a space or requires a `..` traversal, is `major`.
- A missing or out-of-order `E2E-NN` prefix, a recording covering more than one flow, or a Test Seed Factory not gated behind the `Allow Test Data Seed` DEV/UAT toggle, is `minor`.
- When a rule is clearly applicable and the artifact follows it, emit `info`.

Cite a `testing` knowledge file in `references` when one matches; otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`, severity capped at `minor` per `skills/do.md` for agent findings). Set `confidence` `high` for unambiguous matches (a literal "click first row", a missing seed head, an asserted record read), `medium` for heuristic or `unknown`-dimension cases. Provide `suggested-code` only for mechanical fixes (rename a file to add the `NN` prefix, quote a value); otherwise set `suggested-code-omission-reason`. A one-off exploratory drive of the UI (no durable artifact) belongs to the `al-bc-webclient-runner` agent, and subjective or mobile-only checks belong to the manual checklist, so neither is flagged here. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated; `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the task context has no Page Scripting layer to review; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "page-scripting-e2e", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 0, "major": 2, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:e2e-wrong-layer",
      "severity": "major",
      "message": "Recording 'E2E-03 Posted entry amount.yml' asserts a posted ledger entry amount, which an AL TestPage can verify by reading the record after posting. This belongs in layer 1 (al-userguide-test-writer), not Page Scripting. Recommendation: move the assertion to the AL TestPage suite and keep only the rendered-UI residue here.",
      "location": { "file": "Page Scripting/E2E-03 Posted entry amount.yml" },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:e2e-nondeterministic-seed",
      "severity": "major",
      "message": "Recording 'E2E-02 New movement.yml' creates a record but the No. Series is not reset to a test series during seed, so a second run yields FE2E-MOV-002 and the recorded assertion on FE2E-MOV-001 drifts. Recommendation: repoint the No. Series to a freshly reset FE2E- series in the Test Seed Factory and restore it on clear.",
      "location": { "file": "Page Scripting/E2E-02 New movement.yml" },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
