---
kind: action-skill
id: al-mcp-server
version: 1
title: AL MCP Server Wiring Review
description: Reviews how the standalone AL MCP Server is wired into a CI or agent workflow and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al, powershell]
countries: [w1]
application-area: [all]
---

# AL MCP Server Wiring Review

Reviews how the standalone AL MCP Server (`altool launchmcpserver`) is wired into a CI pipeline or agent workflow - server startup and transport, the tool calls and their JSON-RPC envelopes, authentication, and the per-tool parameters - and emits a findings report. The server exposes AL developer tools (build, compile, publish, symbols, diagnostics, auth) to any MCP-compatible client; the central concerns are correct envelope shape, using the right tool for the job, and offline-safe CI configuration. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (a whole-repo audit of MCP server wiring in CI scripts and agent config) or a `file-path` (a targeted re-check of a single workflow script or MCP client config). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the AL MCP Server reference: transport selection, the JSON-RPC envelope conventions, the tool table and per-tool parameter cheat sheet, the authentication flow, and the documented gotchas. This is tooling configuration that the curated BCQuality knowledge domains do not cover. Read the BCQuality knowledge index once (the `knowledge-index.json` Entry's preparation step regenerates over the already-filtered clone); no curated domain maps onto AL MCP Server wiring, so for each concrete violation emit an agent finding within this skill's tooling-configuration domain. Do not open individual article bodies at this step; open an article only once it enters the Worklist.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the extension's `app.json`, or `unknown` if unavailable.
- `technologies` - `[al, powershell]` (the server drives AL tooling, typically invoked from PowerShell-based CI scripts).
- `countries` - the countries declared in the app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas declared by the extension; pass the actual set, do not substitute `[all]`.

Discard tasks with no AL MCP Server wiring to review. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

Narrow the reference to the wiring present in the script, config, or change under review. Group the candidate worklist by area:

- **Startup and transport** - `altool launchmcpserver` uses the right transport (`stdio` default for most agents, `--transport http --port <n>` for network-attached agents); the prerequisites (.NET 8, AL Language extension 17.0+, network access for server-hitting tools) are met for the tools invoked.
- **JSON-RPC envelope** - calls follow the standard MCP shape (`jsonrpc`, `id`, `method: "tools/call"`, `params.name`, `params.arguments`); `al_symbolsearch` is the only tool whose arguments wrap under a `parameters` key, while every other tool puts arguments at the top level under `params.arguments`.
- **Tool selection** - `al_compile` (validate without packaging, faster) is used for PR-gate checks, not `al_build`; `al_compile` is AL MCP only and has no VS Code equivalent (use `al_build` with `scope: "current"` there); `al_build` produces a `.app` only on zero errors (warnings still produce one).
- **CI offline safety** - `al_downloadsymbols` uses `globalSourcesOnly: true` in CI (no BC connection or auth, only Microsoft NuGet feeds and AppSource).
- **Authentication** - `al_auth_login` is called first per session for cloud calls; tokens cache on disk and are reused; `noCache: true` forces a fresh sign-in when cached scopes are wrong; on-prem Windows auth needs no explicit sign-in.
- **Per-tool parameters** - `al_publish` provides one of `appPath`/`projectPath` plus cloud or on-prem connection params; `al_symbolsearch` filters and limits (max 200) are well-formed; diagnostic `Location` is parsed as `"File.al(line,col)"`.

A rule enters the worklist when the script, config, or agent invocation under review touches its area.

## Action

For each worklist item, evaluate the wiring and emit findings. These are agent findings within this skill's tooling-configuration domain (`references: []`, `id` prefixed `agent:`, severity capped per `skills/do.md`), since no curated knowledge file covers the AL MCP Server:

- A wiring fault that makes the call fail outright is a `blocker`: an `al_symbolsearch` call that puts its arguments at the top level instead of wrapping them under the `parameters` key, or a tool invoked without its required connection parameters (`al_publish` with neither `appPath` nor `projectPath`, or with no cloud/on-prem block).
- A misuse that produces wrong or slow results is `major`: `al_build` used for a PR gate where `al_compile --onlyErrors` is the correct fast gate, a CI `al_downloadsymbols` without `globalSourcesOnly: true` (forces an unnecessary BC connection/auth in CI), or `al_auth_login` not called before a cloud `al_publish`/`al_downloadsymbols`.
- A hygiene gap is `minor`: restarting the server between calls instead of reusing the single persistent compilation session, an `al_symbolsearch` `limit` over 200, or a doc link using the wrong `al-tool-symbolsearch` slug instead of `al-tool-symbol-search`.
- When a rule is clearly applicable but no violation is detected, emit `info`.

Set `confidence` to `high` for unambiguous envelope/parameter matches (a missing `parameters` wrapper, a missing required arg), `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. For mechanical fixes (wrap `al_symbolsearch` args under `parameters`, add `globalSourcesOnly: true`, switch a PR gate from `al_build` to `al_compile`), emit `findings[].suggested-code` with the literal replacement; otherwise set `suggested-code-omission-reason`. Hold every agent finding to the precision bar in `skills/do.md`; when in doubt, omit. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the task context has no AL MCP Server wiring to review; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-mcp-server", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:al-symbolsearch-missing-parameters-wrapper",
      "severity": "blocker",
      "message": "al_symbolsearch is called with query and filters at the top level of arguments. al_symbolsearch is the only tool whose arguments must wrap under a 'parameters' key; the call will fail otherwise. Recommendation: nest the arguments under 'parameters'.",
      "location": { "file": "ci/symbol-search.ps1", "line": 22 },
      "references": [],
      "confidence": "high",
      "suggested-code": "  \"arguments\": { \"parameters\": { \"query\": \"Post\", \"filters\": { \"kinds\": [\"Codeunit\"] } } }"
    },
    {
      "id": "agent:downloadsymbols-missing-globalsourcesonly-in-ci",
      "severity": "major",
      "message": "al_downloadsymbols is invoked in a CI gate without globalSourcesOnly: true, forcing a BC server connection and auth that CI does not need. Recommendation: set globalSourcesOnly: true to pull only from Microsoft NuGet feeds and AppSource.",
      "location": { "file": "ci/pr-gate.ps1", "line": 14 },
      "references": [],
      "confidence": "high",
      "suggested-code": "  \"arguments\": { \"globalSourcesOnly\": true }"
    }
  ],
  "suppressed": []
}
```
