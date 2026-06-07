---
name: al-spec-init
kind: action-skill
id: spec-init
version: 1
title: SDD Constitution Review
description: Reviews a Business Central project's Spec-Driven Development constitution (brief, tech design, roadmap) for completeness and consistency, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# al-spec-init

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/workflow/al-spec-init.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
