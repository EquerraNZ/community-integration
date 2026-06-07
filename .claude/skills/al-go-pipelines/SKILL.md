---
name: al-go-pipelines
kind: action-skill
id: al-go-pipelines
version: 1
title: AL-Go Pipeline Configuration Review
description: Reviews an AL-Go for GitHub CI/CD setup against the team's framework rules and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al, powershell]
countries: [w1]
application-area: [all]
---

# al-go-pipelines

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/pipelines/al-go-pipelines.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
