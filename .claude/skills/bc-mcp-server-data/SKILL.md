---
name: bc-mcp-server-data
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

# bc-mcp-server-data

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/integration/al-bc-mcp-server-data.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
