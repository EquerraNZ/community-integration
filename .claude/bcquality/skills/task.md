---
kind: meta-skill
id: task
version: 1
title: Task Skill, the template every task skill follows
---

# TASK

A task skill is a markdown file that tells an agent how to **perform** one concrete piece of Business Central work: write a feature spec, set up an Entra security group, register an environment for AL-Go deployment, implement a Copilot capability. Where an action skill (see DO) reviews code and emits a findings-report, a task skill produces an artifact or effects a change. This document is the template every task skill follows.

This contract is stable. Changes require a PR approved by both maintainers.

## How a task skill differs from an action skill

| | Action skill (DO) | Task skill (this file) |
|---|---|---|
| `kind` | `action-skill` | `task-skill` |
| Purpose | Review, audit, or analyse | Perform work, produce an artifact |
| Invoked by | Entry dispatch (routed automatically) | A developer or orchestrator, **directly** |
| Output | A JSON findings-report (DO contract) | The artifact or effect the skill describes (a file, a configured resource, a generated guide) |
| Structure | Fixed four-step pattern (Source → Relevance → Worklist → Action) | Freeform operational guidance |

A task skill is **not** routed by Entry. Entry's Relevance step admits only `kind: action-skill` candidates, so task skills are excluded by construction. They are invoked by name when a developer (or an orchestrator that knows the skill id) wants the work done. A task skill therefore never emits a findings-report and never participates in super-skill composition.

## What a task skill is

A single markdown file with YAML frontmatter, living inside a layer's `skills/` folder, in a category subfolder:

- `/microsoft/skills/<category>/` for platform-endorsed task skills.
- `/community/skills/<category>/` for community-contributed task skills.
- `/custom/skills/<category>/` for partner or customer task skills (typically in a fork).

Category subfolders group related work, for example `workflow/`, `pipelines/`, `copilot/`, `integration/`, `appsource/`, `operations/`.

## Frontmatter schema

```yaml
---
kind: task-skill
id: spec-feature
version: 1
title: Write a feature specification
description: Produces specs/features/<id>/spec.md for one BC feature, grounded in the project constitution.
produces: [spec.md]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---
```

`kind`, `id`, `version`, `title`, `description` are required.

`produces` is optional: a list naming the artifact(s) or effect(s) the skill creates (`spec.md`, `plan.md`, `permission-set`, `configured-environment`). It is documentation for a consumer choosing a skill; it is not a machine contract like an action skill's `outputs`.

`bc-version`, `technologies`, `countries`, `application-area` are optional filters with the same semantics as in READ. They let a consumer pre-select applicable skills. Omit a dimension to mean "unconstrained".

`references` is optional: a list of repo-relative paths to knowledge files the skill builds on. A task skill MAY cite BCQuality knowledge while it works, but is not required to.

## Sections

A task skill body is freeform operational guidance: the steps, decisions, examples, and conventions needed to do the work. Fenced code blocks are allowed (unlike knowledge files); a task skill is a working document, not a retrieval-optimised knowledge atom. There is no fixed required-section set as there is for action skills, because a task skill does not feed an orchestrator that parses its structure.

A task skill SHOULD, near the top, state when to reach for it (and when not to) and what it produces, so a consumer knows the trigger and the expected result before invoking it.

## How a consumer invokes a task skill

1. A developer or orchestrator selects the task skill by `id` (often surfaced as a slash command in the consuming tool).
2. The agent reads the skill file and follows its body to perform the work.
3. The result is the artifact or effect the skill describes. There is no JSON envelope; the skill's own body defines what "done" looks like.

A consuming repo that bundles its own invocable-skill mechanism (for example Claude Code's `.claude/skills/<name>/SKILL.md`) MAY keep a thin wrapper that defers to the task skill here, so the authored content lives once in BCQuality and the consumer's wrapper only handles discovery and triggering.
