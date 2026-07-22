# Feature Spec: SKU to Item mapping

- **Feature id:** 003-sku-item-mapping
- **Roadmap item:** specs/roadmap.md item 3
- **Status:** spec

## Problem

The Webstore and the WMS speak in SKUs; BC speaks in Item No. Every integration
that maps catalogue lines to BC items needs one shared, maintainable join. Without
it each handler invents its own mapping and an unmapped SKU silently picks the
wrong item or a blank line. This feature provides the one mapping table, its
maintenance page, and a lookup that fails clearly on an unmapped SKU.

## Users and roles

- **Integration administrator** maintains the SKU to Item mappings.
- **Inbound handlers** (004, 006) call the lookup to resolve a SKU to an item.
- **Outbound events** (005) call the reverse lookup to put the source SKU back on
  the payload.

## Scope

- An **Integration SKU Mapping** table keyed on SKU, mapping to Item No. with
  optional Variant Code and Unit of Measure.
- A **list page** to maintain mappings.
- A **lookup codeunit**: forward (SKU to item) and reverse (item to SKU), each
  with a "try" variant that returns false on a miss so the caller decides how to
  fail, plus a clear-error variant.
- Permission set entries for the new objects.

## Out of scope

- Auto-creating items from a SKU. A missing item is a setup task, not an import.
- Bulk import of mappings (a future convenience).
- Any integration-specific logic; this is a shared lookup only.

## User flow

1. The administrator opens SKU Mappings and adds a row: SKU, Item No., optionally
   Variant Code and Unit of Measure.
2. An inbound handler resolves each line's SKU through the lookup. On a hit it gets
   the item, variant, and unit of measure. On a miss the handler fails the message
   Permanent with a clear "SKU not mapped" error (the lookup surfaces the miss; the
   handler classifies it).

## Acceptance criteria

- [ ] Given a mapping for SKU `ESP-250` to item `1000`, when the forward lookup is
      called with `ESP-250`, then it returns item `1000` (with the variant and unit
      of measure stored on the mapping).
- [ ] Given no mapping for SKU `ZZZ-999`, when the "try" forward lookup is called,
      then it returns false and writes no item, and the clear-error variant raises a
      message naming the unmapped SKU.
- [ ] Given a mapping for item `1000` to SKU `ESP-250`, when the reverse lookup is
      called with item `1000`, then it returns `ESP-250`.
- [ ] Given a SKU already mapped, when a second mapping for the same SKU is added,
      then the insert is rejected by the primary key (a SKU maps to one item).
- [ ] Given any object this feature defines, then it is in the Integration
      Foundation permission set.

## Data and rules

- SKU is the primary key: one SKU maps to exactly one item (plus variant / UoM).
- Item No., Variant Code, and Unit of Measure are validated against standard BC
  tables by `TableRelation`; a mapping cannot point at a non-existent item.
- The lookup never guesses: an unmapped SKU is a clear failure, never a silent
  default.

## Telemetry and audit

The lookup itself is a hot, read-only path and does not emit telemetry per call.
The handler that fails on an unmapped SKU emits the standard handler-failure
telemetry (feature 001), with the SKU available on the error message, not in
telemetry dimensions (no PII / catalogue leakage rule is not triggered; SKU is a
non-sensitive code, but the body still carries no payload).

## Open questions

None blocking.
