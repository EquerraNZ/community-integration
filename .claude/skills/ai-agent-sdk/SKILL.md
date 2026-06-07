---
name: ai-agent-sdk
kind: action-skill
id: al-ai-agent-sdk
version: 1
title: BC Agent SDK Definition Review
description: Reviews AL source that defines and registers a custom Business Central agent with the AI Agent SDK and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# ai-agent-sdk

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/copilot/al-ai-agent-sdk.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
