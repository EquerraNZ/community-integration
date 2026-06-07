---
name: al-implement-feature
kind: action-skill
id: implement-feature
version: 1
title: Feature Implementation Review
description: Reviews a Business Central feature implementation against its approved spec, plan, and tasks, the house rules, and acceptance-criteria coverage, and emits a findings report.
inputs: [pr-diff, repository]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# al-implement-feature

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/workflow/al-implement-feature.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
