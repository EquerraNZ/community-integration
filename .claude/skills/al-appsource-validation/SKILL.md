---
name: al-appsource-validation
kind: action-skill
id: appsource-validation
version: 1
title: AppSource submission validation
description: Reviews a Business Central extension against the AppSource marketplace submission checklist and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# al-appsource-validation

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/appsource/al-appsource-validation.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
