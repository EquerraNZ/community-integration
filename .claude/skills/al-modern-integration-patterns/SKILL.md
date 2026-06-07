---
name: al-modern-integration-patterns
kind: action-skill
id: modern-integration-patterns
version: 1
title: Modern BC Integration Patterns Review
description: Reviews Business Central integration code on the inbound, outbound, long-running, and manual arrows against the modern-integration house rules, and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# al-modern-integration-patterns

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/integration/al-modern-integration-patterns.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
