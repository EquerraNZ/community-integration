---
kind: action-skill
id: al-go-pipelines
version: 1
title: AL-Go Pipeline Configuration Review
description: Reviews an AL-Go for GitHub CI/CD setup against the team's framework rules and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al, powershell]
countries: [w1]
application-area: [all]
---

# AL-Go Pipeline Configuration Review

Reviews how a Business Central repo runs CI/CD with AL-Go for GitHub - the settings model, repo and branching strategy, release procedure, self-upgrade auth, and any AL MCP Server wiring - and emits a findings report. AL-Go is the chosen framework for BC CI/CD on GitHub Actions, and its workflows are downloaded at runtime from upstream, so the central concern is that customisation happens through settings and never by hand-editing the AL-Go-owned workflow scripts. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (a whole-repo audit of the AL-Go setup) or a `file-path` (a targeted re-check of `.AL-Go/settings.json`, `.github/AL-Go-Settings.json`, or a workflow file). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the team's AL-Go for GitHub framework governance: the hard rules below, the two-file settings model, repo/branching strategy, the release procedure, the self-upgrade auth setup, and the AL MCP Server CI integration. This is pipeline governance that the curated BCQuality knowledge domains do not cover. Read the BCQuality knowledge index once (the `knowledge-index.json` Entry's preparation step regenerates over the already-filtered clone); no curated domain maps onto AL-Go configuration, so for each concrete violation emit an agent finding within this skill's pipeline-governance domain. Do not open individual article bodies at this step; open an article only once it enters the Worklist.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the extension's `app.json`, or `unknown` if unavailable.
- `technologies` - `[al, powershell]` (AL-Go orchestrates PowerShell-based workflows over an AL extension).
- `countries` - the countries declared in the app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas declared by the extension; pass the actual set, do not substitute `[all]`.

Discard tasks with no AL-Go repo to review. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

Narrow the framework rules to the artifacts present in the repo or change under review. Group the candidate worklist by area:

- **Hard rules** - AL-Go workflow scripts under `.github/workflows/AL-Go-*` are never hand-edited (they auto-upgrade from upstream); releases use semantic version tags (`v1.2.0`), are marked **Pre-release**, and use **Create Release Branch**; one repo per AppSource or customer PTE app (multi-project only when apps are tightly coupled); `main` is always the latest code and is never rolled back.
- **Settings model** - build/test settings live in `.AL-Go/settings.json` (per project: `projects`, `appFolders`, container country, AppSourceCop config, `appDependencyProbingPaths`); CI/CD wiring lives in `.github/AL-Go-Settings.json` (per repo: PR/CI-CD trigger branches, `environments`, `ContinuousDeployment`, dependent apps); settings changes that affect workflow shape are followed by **Update AL-Go System Files**.
- **Repo and branching** - default branch `main`; release branches are independent heads cut from `main` at release time, not long-lived forks; hotfixes are `hotfix/<description>` branches off the release branch; shared assets live in a separate `d365-dependent-artifacts` submodule.
- **d365-dependent-artifacts** - never public, never shared externally; `main` protected, PR required, no direct commits; no CI/CD by design; signed apps live here, not in the AL-Go repo.
- **Release procedure** - Create Release from `main` (first release) or the latest release branch (subsequent), semantic tag, Pre-release until validated, Create Release Branch ticked, hotfixes via `hotfix/<description>`.
- **Self-upgrade auth** - the shared AL-Go GitHub App is installed, `GHTOKENWORKFLOW` repo secret is set, and Update AL-Go System Files has been run and its PR merged.
- **AL MCP Server in CI** - `altool launchmcpserver` is used only for agent-driven or PR-gate cases AL-Go does not cover; the canonical build/test/publish path stays with AL-Go's own workflows; CI symbol pulls use `globalSourcesOnly: true`.

A rule enters the worklist when the repo's settings, workflows, branch layout, or MCP wiring touches its area.

## Action

For each worklist item, evaluate the repo or change and emit findings. These are agent findings within this skill's pipeline-governance domain (`references: []`, `id` prefixed `agent:`, severity capped per `skills/do.md`), since no curated knowledge file covers AL-Go configuration:

- A hard-rule violation that breaks the framework is a `blocker`: a hand-edit to any file under `.github/workflows/AL-Go-*` (breaks the auto-upgrade path), a signed `.app` committed into the AL-Go repo instead of `d365-dependent-artifacts`, a rollback of `main` to an older version, or a `release/extension/NextMajor` branch cut before all customer environments are on the new major (defer to `al-major-release-governance` for the upgrade governance).
- A governance gap that degrades the pipeline is `major`: a settings change that affects workflow shape with no follow-up Update AL-Go System Files, a release missing its semantic tag / Pre-release marking / Create Release Branch step, the AL MCP Server taking over the canonical build/test/publish path that AL-Go owns, or `d365-dependent-artifacts` made public or accepting direct commits to `main`.
- A hygiene gap is `minor`: a multi-project repo combining apps that are not tightly coupled, a CI symbol pull without `globalSourcesOnly: true`, or a hotfix committed directly to a release branch rather than via a `hotfix/<description>` branch.
- When a rule is clearly applicable but no violation is detected, emit `info`.

Set `confidence` to `high` for unambiguous file/settings matches (an edit inside `AL-Go-*`, a committed `.app`), `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. For mechanical settings fixes, emit `findings[].suggested-code` with the literal replacement; otherwise set `suggested-code-omission-reason` (most framework violations - a workflow hand-edit, a misplaced signed app - are not mechanical one-line fixes). Hold every agent finding to the precision bar in `skills/do.md`; when in doubt, omit. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the task context has no AL-Go repo to review; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-go-pipelines", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 7, "items-evaluated": 7 }
  },
  "findings": [
    {
      "id": "agent:al-go-workflow-script-hand-edited",
      "severity": "blocker",
      "message": "A file under .github/workflows/AL-Go-CICD.yaml has been hand-edited. AL-Go downloads these workflows at runtime from upstream; editing them in the repo breaks the auto-upgrade path. Recommendation: revert the edit and customise via .AL-Go/settings.json or .github/AL-Go-Settings.json, then run Update AL-Go System Files.",
      "location": { "file": ".github/workflows/AL-Go-CICD.yaml", "line": 1 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:settings-changed-without-update-system-files",
      "severity": "major",
      "message": "The PR changes the environments array in .github/AL-Go-Settings.json but does not run Update AL-Go System Files, so the workflow scripts that consume the new setting are not regenerated. Recommendation: run the Update AL-Go System Files workflow and merge its PR.",
      "location": { "file": ".github/AL-Go-Settings.json", "line": 3 },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
