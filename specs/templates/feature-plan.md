# Feature Plan: <feature name>

> Produced by `/al-plan-feature` from an approved `spec.md`. The how. Inherits from
> `specs/tech-design.md` and the house rules in `.claude/skills/al-code-review`.
> Stop for human review before implementing.

- **Feature id:** <NNN-slug>
- **Spec:** ./spec.md
- **Status:** planned

## Approach

The implementation strategy in two or three sentences. Reuse standard BC first;
state what is custom and why.

## Standard BC reused

- Module / object and how this feature builds on it.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| <Name> | table/page/codeunit/enum/permissionset | 5xxxx | new | ... |

All IDs must sit inside the assigned range from `specs/tech-design.md`.

## Data model

New tables, key fields, keys, and relations to standard BC tables.

## Integration points

External calls, events subscribed/published, APIs. Note idempotency and auth.

## Cross-cutting

- Permissions: which permission set entries.
- Telemetry: which operations emit, and the event ids.
- Upgrade/migration: any schema change that needs an upgrade codeunit step.
- Performance: hot paths to watch (filters, loops, FlowFields on lists).

## Risks and decisions

Trade-offs taken, and anything the reviewer should scrutinise.

## Test strategy

How the acceptance criteria become tests (AL test codeunits, Page Scripting, etc.).
