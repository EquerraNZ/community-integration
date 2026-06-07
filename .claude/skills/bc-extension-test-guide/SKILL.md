---
name: bc-extension-test-guide
kind: action-skill
id: al-bc-extension-test-guide
version: 1
title: BC Extension Test Guide Audit
description: Reviews a Business Central extension's QA test guide for exhaustive category coverage of every page, field, relation, state, and permission in the AL source, and emits a findings report.
inputs: [repository, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# bc-extension-test-guide

The authoritative content for this skill is maintained in BCQuality, the
single source of truth, and vendored into this repo. Read and follow:

`.claude/bcquality/custom/skills/testing/al-bc-extension-test-guide.md`

Do not edit the guidance inline here. Update the skill upstream in
EquerraNZ/community-BCQuality, then re-vendor. This pointer exists only so the
skill stays discoverable and invocable in this repo.
