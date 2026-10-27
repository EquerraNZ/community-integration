# specs/

This folder is the source of truth for **what** the solution does. Code is the
muscle; these specs are the brain. See `AGENTS.md` at the repo root for the full
contract.

The solution has two parts, and both are specified here: the Business Central
extension, and the Azure integration layer that carries every message across the
boundary. A feature may deliver BC objects, Azure components, or both. There is no
separate Azure spec tree, because splitting them would let the two halves of one flow
drift apart.

## Layout

```
specs/
  brief.md          # constitution: customer requirements (the what and why)
  tech-design.md    # constitution: reuse standard BC and standard Azure services,
                    #   name the custom-code gaps on both sides
  roadmap.md        # constitution: ordered features with status
  templates/        # blank templates for each per-feature artifact
  features/
    <NNN-slug>/     # one folder per feature, e.g. 001-first-feature
      spec.md       # requirements, scope, acceptance criteria
      plan.md       # technical plan: BC objects and Azure components, IDs, data model
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

### Features that touch the Azure integration layer

A feature that adds or changes a receiver, a sender, a queue, or the infrastructure
that provisions them runs the same four stages. Two things differ:

- The plan names **Azure components** as well as AL objects: which resource, which
  module in `infra/`, which function in `integration-plane/`, and which of the plane
  requirements in `brief.md` it satisfies.
- The implement gate adds `azure-integration-validator`, which reviews the plane
  against the rules in
  `.claude/bcquality/custom/skills/integration/al-azure-integration-review.md`, beside
  the AL verifier set. A feature that changes both halves of a flow runs both.

## Feature folder naming

`NNN-short-slug`, zero-padded and ordered (for example `001-first-feature`,
`002-overdue-notifications`). The number matches the roadmap order.
