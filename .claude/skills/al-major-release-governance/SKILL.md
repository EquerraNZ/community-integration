---
name: al-major-release-governance
kind: action-skill
id: al-major-release-governance
version: 1
title: Major version upgrade readiness review
description: Reviews Business Central major-version upgrade governance, NextMajor branching, compatibility testing, and app.json version bumps, and emits a findings report.
inputs: [pr-diff, repository]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# al-major-release-governance

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/appsource/al-major-release-governance.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
