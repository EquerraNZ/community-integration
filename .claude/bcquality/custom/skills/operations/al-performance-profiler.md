---
kind: action-skill
id: al-performance-profiler
version: 1
title: BC Performance Profiler Practice Review
description: Reviews how Business Central performance profiling is captured and interpreted and emits a findings report.
inputs: [repository, telemetry-query]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC Performance Profiler Practice Review

Reviews whether a Business Central performance-triage exercise captures and interprets `.alcpuprofile` snapshots correctly, and emits a findings report. The governing principle is that a profile is the evidence base for any serious AL performance triage, so a capture taken outside the useful window, read in the wrong order, or used to answer a question it cannot answer produces misleading conclusions. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (an audit of profiling artifacts, capture notes, or handoff documentation checked into the repo) or a `telemetry-query` (the captured profile metadata and timing context under review). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the Performance Profiler capture-and-interpret procedure, plus the `performance` knowledge domain in BCQuality where a profiling observation maps onto a curated rule (full-table scans, FlowField cost in loops, missing `SetCurrentKey`). Read the BCQuality knowledge index once (the `knowledge-index.json` Entry's preparation step regenerates over the already-filtered clone) and take the `performance` domain entries as the citable candidate set across every enabled layer. Do not open individual article bodies at this step; open an article only once it enters the Worklist. The capture-window discipline, view-reading order, and handoff hygiene are procedure the corpus does not cover; for a concrete violation there, emit an agent finding within this skill's profiling-practice domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the extension's `app.json`, or `unknown` if unavailable.
- `technologies` - `[al]`.
- `countries` - the countries declared in the app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas declared by the extension; pass the actual set, do not substitute `[all]`.

Discard files not applicable to AL extensions. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

Narrow the procedure to the items that apply to the capture or artifact under review. Group the candidate worklist by area:

- **Capture discipline** - the profiler is started, the slow action reproduced exactly, then stopped; the captured action runs roughly 5 to 30 seconds (longer captures get noisy); the `.alcpuprofile` is downloaded and attached as plain JSON.
- **Interpretation order** - analysis starts with Active Apps to find the dominant suspect, cross-checks Time Spent for continuous (AL inefficiency) versus spiky (SQL, lock, external service) cost, reads Aggregate Results for the top functions, uses Call Tree for the chain, and By Application Object for the tables and codeunits to read next.
- **Profile-visible patterns** - `FindSet` over a large table where `FindFirst` or `IsEmpty` would do; an event subscriber on a hot path doing extra DB reads; nested loops calling `Get` per iteration; `CalcFields` of FlowFields inside a loop; a missing `SetCurrentKey` forcing a table scan.
- **Handoff hygiene** - the action is described in plain language, exact reproduction steps are included, expected versus actual timing is stated, and BC version plus the installed-extension list accompany the profile.
- **Scope boundaries** - the profile is not used to answer questions it cannot answer (network latency, SQL execution plans, Job Queue contention), which belong to telemetry such as `appi-eql-prod-tenant` and server-side telemetry instead.

A rule enters the worklist when the artifact, capture note, or handoff documentation under review touches its area.

## Action

For each worklist item, evaluate the artifact or capture context and emit findings:

- A capture that cannot support its stated conclusion (a Job Queue contention claim drawn from a user-facing profile, a network-latency claim, or an SQL-plan claim the profiler never measures) is a `blocker`: the evidence does not back the diagnosis.
- A capture-window or interpretation-order violation that materially weakens the analysis (a capture far longer than 30 seconds presented as clean signal, jumping to Call Tree before Active Apps and naming the wrong suspect app) is `major`. Cite a `performance`-domain knowledge file in `references` when the flagged pattern is a curated anti-pattern (full-table scan, FlowField-in-loop); otherwise emit an agent finding within this skill's domain.
- A handoff gap that slows the partner without invalidating the profile (missing reproduction steps, no expected-versus-actual timing, no BC version or extension list) is `minor`.
- When a rule is clearly applicable but no violation is detected, emit `info` citing the rule.

Set `confidence` to `high` for unambiguous procedure or pattern matches, `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. Agent findings carry `references: []`, an `id` prefixed `agent:`, `confidence` capped at `medium`, and a self-contained `message`. Profiling-practice findings are rarely mechanical; provide `suggested-code` only when the fix is a literal edit to a checked-in artifact, otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the task context has no profiling artifact or AL extension to review; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-performance-profiler", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 5, "items-evaluated": 5 }
  },
  "findings": [
    {
      "id": "agent:profile-cannot-prove-job-queue-contention",
      "severity": "blocker",
      "message": "The triage note blames Job Queue contention based on an .alcpuprofile captured during a user-facing page load. The profiler shows AL-side time only and does not surface queue contention; this conclusion is unsupported. Recommendation: capture during the slow user-facing operation for AL cost, and use server-side telemetry (appi-eql-prod-tenant) to evidence Job Queue contention.",
      "location": { "file": "docs/perf/triage-2026-06.md", "line": 22 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "microsoft/knowledge/performance/filter-before-find.md",
      "severity": "major",
      "message": "Aggregate Results shows FindSet over a large table dominating CPU with no prior filter, matching the documented full-table-scan anti-pattern. The capture supports fixing this first.",
      "location": { "file": "docs/perf/triage-2026-06.md", "line": 40 },
      "references": [
        { "path": "microsoft/knowledge/performance/filter-before-find.md" }
      ],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
