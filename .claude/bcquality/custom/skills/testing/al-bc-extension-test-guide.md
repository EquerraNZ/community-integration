---
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

# BC Extension Test Guide Audit

Reviews whether a Business Central extension's `DOCS/TEST_GUIDE.md` is exhaustive by construction against the extension's AL source, and emits a findings report. Every field, relation, action, and reachable data state in the AL must appear in at least one of the twelve category inventories; happy-path coverage is not enough, because this guide is the contract that catches the state pivots ship-then-regret bugs hide behind. This skill audits the guide and the source it is derived from rather than generating the guide. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (audit the whole extension's source against its `TEST_GUIDE.md`) or a `file-path` (re-check a single category or a changed object against the guide). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the test-guide exhaustiveness contract: the twelve fixed categories and the per-category inventory requirements that map every AL artifact to a category. Where a category maps onto a curated BCQuality rule (subpage FK persistence, permission boundaries, cross-company isolation, upgrade paths), read the BCQuality knowledge index once and take the `testing`, `security`, and `upgrade` domain entries as the citable candidate set across every enabled layer; do not open an article's body until it enters the Worklist. The category-coverage and inventory-completeness rules are not covered by the corpus; for a concrete gap there, emit an agent finding within this skill's test-guide-coverage domain.

A worked example is shipped at `examples/elevate-shipping-TEST_GUIDE.md` in this skill folder. It shows the inventory granularity expected; it is for that extension only, so the structure transfers but every inventory row must come from the target extension's AL.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the extension's `app.json`, or `unknown` if unavailable.
- `technologies` - `[al]`.
- `countries` - the countries declared in the app's `app.json`; default to the orchestrator's configured context, else `unknown`.
- `application-area` - the union of application areas declared by the extension's objects; pass the actual set, do not substitute `[all]`.

Discard files not applicable to AL extensions. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension.

## Worklist

The candidate worklist is the twelve categories that form the contract; every generated guide has exactly these twelve in this order. A category enters the active worklist when the AL source contains the artifact that category inventories.

| # | Category | Inventory requirement |
|---|---|---|
| 1 | Lookup audit (happy + inline-create) | Every page field whose underlying table field has `TableRelation` to another table, both directions, cross-checked against `TableRelation` in `src/`. |
| 2 | Type-conditional TableRelation | Every field whose `TableRelation` is conditional on a sibling field (`where(...)`, or `OnLookup`/`OnValidate` branching on a sibling), plus each enum/option value of the selector mapped to its target. |
| 3 | Eligibility filters on lookups | Every lookup whose downstream `OnValidate`/OK handler errors on a subset of the target (status-blocked, `Blocked = true`); the rejected predicate and whether the lookup pre-filters it. |
| 4 | Visibility / Editable conditionals | Every `Visible = <var>` and `Editable = <var>` on every page, every driver, and whether the driver's `OnValidate` calls `CurrPage.Update(false)` to force refresh. |
| 5 | StandardDialog Mode pivots | Every `PageType = StandardDialog` with an `Option`/enum `Mode` selector; each Mode's visible-field set, OK side effect, and error on blank required input, tested through the commit. |
| 6 | Subpage FK persistence | Every `part(...)` with `SubPageLink`, the FK fields propagated, and whether `SetParentKeys()` explicit-push is used or the subpage relies on `SubPageLink` default behaviour alone (a known fragility point, flag it). |
| 7 | State machine transitions | Every status `enum` on a table, the full from×to matrix marking allowed vs. disallowed with the trigger, and every code path mutating Status (`Status :=`, `Validate("Status",`). |
| 8 | Permission boundaries | Every `permissionset` object, full RIMD per table, page/codeunit claims, cross-referenced against actual tables/pages. |
| 9 | Telemetry events | Every custom telemetry call site, event ID, trigger, payload keys, cross-checked against `LogEvent`/`LogMessage` in `src/`. |
| 10 | Mobile / tablet smoke | Every top-level user-facing page (`UsageCategory <> None` or reachable from a top-level page) renders on a 375×812 viewport without horizontal scroll. |
| 11 | Cross-company isolation | Every table, its `DataPerCompany` value (default true), and any singleton/shared-state table called out explicitly. |
| 12 | Upgrade paths | Every upgrade codeunit (`Subtype = Upgrade`), each documented schema change vs. the previous shipped version, and test seed instructions per change. |

The exhaustiveness contract is the discovery basis for the audit: read `app.json` (id, version, dependencies, idRanges) and `.AL-Go/settings.json` (appFolders, testFolders), then inventory tables (fields, relations, triggers, keys, FlowFields), pages (PageType, SourceTable, field flags, actions, parts, page triggers), enums, permission sets, and codeunits (upgrade, subscribers, telemetry call sites).

## Action

For each category, compare the guide's inventory against the AL source and emit findings:

- A category whose inventory has fewer rows than the AL warrants (a `TableRelation` missing from Cat 1/2, a dynamic `Visible`/`Editable` missing from Cat 4, a `StandardDialog` with a Mode missing from Cat 5, a `SubPageLink` missing from Cat 6, a status enum without a transition matrix in Cat 7, a `permissionset` without full RIMD in Cat 8, a telemetry call site missing from Cat 9, an upgrade codeunit or schema delta missing from Cat 12) is a `major` coverage gap: the guide is incomplete by contract. A subpage relying on `SubPageLink` default behaviour with no `SetParentKeys()` push is flagged here per the fragility rule.
- Categories present but out of order, a missing category section, or a missing run-report scorecard is `minor`.
- A `TODO`/`n/a` placeholder left in an inventory table (rather than one explicit line stating the category genuinely does not apply), or a missing `USER_GUIDE.md` cross-link to the guide, is `minor`.
- When a category is clearly applicable and its inventory matches the source, emit `info` confirming coverage.

Run the self-audit greps as evidence: every `TableRelation` must land in Cat 1 or 2; every dynamic `Visible`/`Editable` in Cat 4; every `PageType = StandardDialog` with a Mode in Cat 5; every `SubPageLink` in Cat 6; every `permissionset` in Cat 8; every `LogEvent`/`LogMessage` in Cat 9. When a grep count exceeds the inventory rows, the missing entries are the findings. Cite a `testing`, `security`, or `upgrade` knowledge file in `references` when one matches; otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`). Set `confidence` `high` for unambiguous grep-versus-inventory counts, `medium` for heuristic mapping or `unknown`-dimension cases. This skill audits the guide; it does not run tests, infer seed data, or write AL test codeunits, so defects in those domains belong to other skills and must not be emitted here. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every applicable category was evaluated; `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the task context has no AL extension or no test guide to audit; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-bc-extension-test-guide", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 0, "major": 2, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 12, "items-evaluated": 12 }
  },
  "findings": [
    {
      "id": "agent:test-guide-category1-incomplete",
      "severity": "major",
      "message": "grep for TableRelation in src/ returns 11 fields but Category 1 (Lookup audit) inventories only 7 rows. The guide is incomplete by the exhaustiveness contract. Missing: Shipment.\"Customer No.\", Shipment.\"Ship-to Code\", Movement.\"Bin Code\", Movement.\"Item No.\". Recommendation: add a Cat 1 or Cat 2 row for each, with source field and target Card page.",
      "location": { "file": "DOCS/TEST_GUIDE.md" },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:test-guide-subpagelink-fragility",
      "severity": "major",
      "message": "Page 'Movement Document' has a part(...) with SubPageLink but no SetParentKeys() explicit push; Category 6 lists it without flagging the default-value reliance, a known FK-persistence fragility point. Recommendation: flag the row and add a test that the PK propagates to inserted subpage rows.",
      "location": { "file": "DOCS/TEST_GUIDE.md" },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
