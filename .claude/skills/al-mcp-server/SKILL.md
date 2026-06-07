---
name: al-mcp-server
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

# al-mcp-server

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/pipelines/al-mcp-server.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
