---
name: al-plan-feature
kind: action-skill
id: plan-feature
version: 1
title: Feature Plan Review
description: Reviews a Business Central feature plan and task list against its approved spec, object ID range, and verifier expectations, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# al-plan-feature

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/workflow/al-plan-feature.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
