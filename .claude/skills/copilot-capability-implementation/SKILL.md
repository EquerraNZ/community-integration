---
name: copilot-capability-implementation
kind: action-skill
id: al-copilot-capability-implementation
version: 1
title: BC Copilot Capability Implementation Review
description: Reviews the AL implementation of a Business Central Copilot capability built on the System.AI Azure OpenAI module and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# copilot-capability-implementation

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/copilot/al-copilot-capability-implementation.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
