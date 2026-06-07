---
name: bc-integrations
kind: action-skill
id: al-bc-integrations
version: 1
title: BC Integration Architecture Review
description: Reviews how a Business Central extension integrates with external systems against architectural patterns and anti-patterns, and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# bc-integrations

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/integration/al-bc-integrations.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
