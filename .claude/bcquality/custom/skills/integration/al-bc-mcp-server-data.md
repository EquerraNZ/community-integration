---
kind: action-skill
id: al-bc-mcp-server-data
version: 1
title: BC Product MCP Server Configuration Review
description: Reviews a Business Central product MCP server configuration for the API surface, operation permissions, and client authentication it exposes, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC Product MCP Server Configuration Review

Reviews a Business Central product MCP server configuration and emits a findings report. Business Central runs its own MCP server at `https://mcp.businesscentral.dynamics.com`; this skill audits how it is configured: which API pages are exposed, what CRUD operations are allowed, whether the tool surface is safe, and how clients authenticate. It is distinct from the AL MCP Server, which is a developer tool. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (an exported MCP configuration JSON checked into the repo, or a whole-extension audit of the API pages that back it) or a `file-path` (a single exported configuration). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is this skill's own product-MCP configuration guidance, plus the `security` and `integration` knowledge domains in BCQuality where a configuration concern maps onto a curated rule (over-broad write permissions, exposure of data that should stay internal). Read the BCQuality knowledge index once and take the `security` and `integration` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The MCP-product configuration switches and naming behaviour are not vendored in the corpus; for a concrete violation there, emit an agent finding within this skill's MCP-configuration domain (`references: []`, `id` prefixed `agent:`).

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the BC version of the environment the configuration targets, or `unknown`. The product MCP server is BC online (SaaS) only; an on-prem target is `not-applicable`.
- `technologies` - `[al]`; the exposed surface is BC API pages.
- `countries` - from the environment's app context, else `unknown`.
- `application-area` - the areas covered by the exposed API pages; pass the actual set, do not substitute `[all]`.

Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; cap their findings at `medium` confidence and name the unknown dimension.

## Worklist

The configuration lives on Page **8351** (`Model Context Protocol (MCP) Server Configurations`); the reviewable artifact is its exported JSON or the connection string. A concern enters the worklist when the configuration or the API pages backing it touch its area:

- **Per-configuration switches** - `Active`, `Dynamic Tool Mode`, `Discover Additional Objects`, `Unblock Edit Tools`.
- **Per-tool (per-API page) permissions** - `Allow Read`, `Allow Create`, `Allow Modify`, `Allow Delete`, `Allow Bound Actions`.
- **Exposed page eligibility** - only top-level API pages; `ListPart` and `CardPart` subpages are unsupported.
- **Tool-count ceiling** - Copilot Studio's 70-tool cap and the static-vs-dynamic tool-naming choice.
- **Connection string and headers** - `TenantId`, `EnvironmentName`, `Company`, `ConfigurationName`.
- **Authentication** - OAuth 2.0 Authorization Code with PKCE; Entra app registration for non-Microsoft clients.

## Action

For each worklist item, evaluate the configuration and emit findings. Cite a `security` or `integration` knowledge file in `references` when one matches; otherwise emit an agent finding within this skill's domain.

### Per-configuration switches

| Switch | What it does |
|---|---|
| Active | Configuration is selectable from MCP clients |
| Dynamic Tool Mode | Replaces the static tool list with `bc_actions_search`, `bc_actions_describe`, `bc_actions_invoke`. Required if you exceed Copilot Studio's 70-tool cap |
| Discover Additional Objects | Only meaningful when Dynamic Tool Mode is on |
| Unblock Edit Tools | Master switch: when off, all per-API Create/Modify/Delete/Bound Action permissions are ignored (read-only) |

### Per-tool permissions and the write gate

The default for a newly-added page is read-only. Enabling write requires `Unblock Edit Tools` on at the configuration level AND the specific permission ticked per page. Flag a configuration that opens Create/Modify/Delete on an entity whose agent workflow does not require it as a `major` over-exposure; flag write on a sensitive master or setup entity (vendors, payment setup, permissions) without a documented need as a `blocker`.

### Tool naming and the 70-tool cap

With Dynamic Tool Mode OFF, each API page generates up to five static tools:

```
List<EntityName>_PAG<ID>          # if Allow Read
Create<EntityName>_PAG<ID>        # if Allow Create
ListUpdate<EntityName>_PAG<ID>    # if Allow Modify
Delete<EntityName>_PAG<ID>        # if Allow Delete
<BoundActionName>_PAG<ID>         # each allowed bound action
```

With Dynamic Tool Mode ON, only three meta-tools are exposed:

```
bc_actions_search        # find available actions by keyword
bc_actions_describe      # get the schema for a specific action
bc_actions_invoke        # call it with parameters
```

A configuration that exceeds (or will exceed) 70 static tools without Dynamic Tool Mode is a `major`: Copilot Studio caps at 70 and silently drops the overflow.

### Page eligibility

API pages of subtype `ListPart` or `CardPart` are not supported, and only top-level API pages are picked up. A configuration referencing a part page is a `minor` (the tool will not appear); the fix is to wrap the same source table in a top-level API page.

### Connection string and authentication

The connection string from `Advanced > Connection String` carries `TenantId`, `EnvironmentName`, `Company`, and an optional `ConfigurationName`. Authentication is OAuth 2.0 Authorization Code with PKCE against Entra ID; Microsoft clients (VS Code, Copilot Studio) use a pre-registered application, while non-Microsoft clients (Claude, ChatGPT, custom) must register their own Entra application. All operations run as the signed-in user's identity, so the audit trail shows who did what. Flag a checked-in connection string or exported configuration that embeds a secret, or any reliance on a shared service-account identity that defeats per-user audit, as a `blocker`. See `al-rbac-and-access` for the Entra app-registration patterns when wiring non-Microsoft clients.

### Recommended defaults (flag deviations)

- One configuration per intended audience (e.g. `SalesTeamConfig`, `WarehouseAgentConfig`); a single mega-configuration is a `minor`.
- Default every API to Read; open Create/Modify/Delete one entity at a time, only when the workflow requires it.
- Turn on Dynamic Tool Mode for any configuration exceeding 20 APIs, to future-proof against the 70-tool cap.
- Each configuration documents its audience and intended use.

Set `confidence` to `high` for unambiguous switch/permission matches in the exported JSON, `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. Provide `suggested-code` only for mechanical, local JSON edits (flip a write permission off, set a header); otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract. For the developer-tool MCP, see `al-mcp-server`; for in-product Copilot UX, see `al-copilot-promptdialog`.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Source, Relevance, and configuration filtering; `not-applicable` when the target is on-prem or no MCP configuration is present; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-bc-mcp-server-data", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:mcp-write-on-sensitive-entity-without-justification",
      "severity": "blocker",
      "message": "The exported MCP configuration enables Allow Modify and Allow Delete on the Payment Method API page with Unblock Edit Tools on, and no documented agent workflow requires write access to payment setup. Recommendation: set this entity back to read-only and open write only for the specific entity a documented workflow needs.",
      "location": { "file": "mcp/WarehouseAgentConfig.json", "line": 34 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:mcp-exceeds-static-tool-cap",
      "severity": "major",
      "message": "The configuration exposes 31 API pages with Dynamic Tool Mode off, generating more than 70 static tools, so Copilot Studio will silently drop the overflow. Recommendation: turn on Dynamic Tool Mode to expose the three meta-tools instead.",
      "location": { "file": "mcp/SalesTeamConfig.json", "line": 4 },
      "references": [],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
