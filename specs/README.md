# specs/

This folder is the source of truth for **what** the solution does. Code is the
muscle; these specs are the brain. See `AGENTS.md` at the repo root for the full
contract.

## Layout

```
specs/
  brief.md          # constitution: customer requirements (the what and why)
  tech-design.md    # constitution: reuse standard BC, name the custom-code gaps
  roadmap.md        # constitution: ordered features with status
  templates/        # blank templates for each per-feature artifact
  features/
    <NNN-slug>/     # one folder per feature, e.g. 001-first-feature
      spec.md       # requirements, scope, acceptance criteria
      plan.md       # technical plan: objects/structure, ID range, data model
      tasks.md      # ordered, checkable implementation tasks
```

## Workflow (Spec-Driven Development)

At each stage you draft the artifact, with the agent's help, then run the
matching skill as a review gate before moving on:

1. `/al-spec-init`: reviews `brief.md`, `tech-design.md`, `roadmap.md` (once per project).
2. `/al-spec-feature`: reviews `features/<id>/spec.md` for the next roadmap item.
3. `/al-plan-feature`: reviews `plan.md` and `tasks.md` against the approved spec.
4. `/al-implement-feature`: reviews the implementation, then the verifier agents and a BCQuality review run.

One feature, one chat session. Always start by reading the constitution.

## Feature folder naming

`NNN-short-slug`, zero-padded and ordered (for example `001-first-feature`,
`002-overdue-notifications`). The number matches the roadmap order.
