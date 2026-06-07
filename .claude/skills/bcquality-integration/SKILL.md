---
name: bcquality-integration
kind: action-skill
id: al-bcquality-integration
version: 1
title: BCQuality Consumption Review
description: Reviews whether a consuming repo and its verifier agents consume the BCQuality knowledge corpus correctly and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# bcquality-integration

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/meta/al-bcquality-integration.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
