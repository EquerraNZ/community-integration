# Feature Plan: SKU to Item mapping

- **Feature id:** 003-sku-item-mapping
- **Spec:** ./spec.md
- **Status:** planned

## Approach

One small master table keyed on SKU, a list page, and a stateless lookup codeunit
that wraps the reads so handlers never touch the table directly (the data-access
seam). Forward and reverse lookups both offer a `Try*` boolean variant (caller
decides how to fail) and a clear-error variant.

## Standard BC reused

- **Item**, **Item Variant**, **Item Unit of Measure** for `TableRelation`
  validation; no custom item data.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration SKU Mapping | table | 73298401 | new | SKU to Item No. join. |
| Integration SKU Mappings | page | 73298442 | new | Maintain mappings (List). |
| Integration SKU Mgt. | codeunit | 73298425 | new | Forward/reverse lookup seam. |
| Integration Foundation | permissionset | 73298460 | extend | Add the new objects. |

## Data model

**Integration SKU Mapping** (PK `SKU` Code[20]): `SKU`, `Item No.`
(TableRelation Item), `Variant Code` (TableRelation Item Variant within the item),
`Unit of Measure Code` (TableRelation Item Unit of Measure within the item). All
`DataClassification` SystemMetadata (catalogue codes, not PII).

## Integration points

None external. Pure in-BC lookup consumed by handlers (004, 006) and events (005).

## Cross-cutting

- Permissions: add tabledata RIMD for the mapping, X for the codeunit and page.
- Telemetry: none in the lookup (hot read path); failures are reported by the
  calling handler's standard telemetry.
- Upgrade: greenfield table, additive.
- Performance: PK lookup by `Get(SKU)` for forward; a `(Item No., Variant Code)`
  key for the reverse lookup so it is a single indexed read, not a table scan.

## Risks and decisions

- **Reverse lookup ambiguity.** Two SKUs could map to one item. The reverse lookup
  returns the first by the index and is only used to label an outbound line; the
  decision is acceptable because the WMS keys on its own SKU and the order line
  already pins the item. Documented, not guarded.

## Test strategy

A test codeunit seeds mappings into a temporary/real mapping table and asserts:
forward hit returns item/variant/UoM; forward miss returns false and the
clear-error variant errors naming the SKU; reverse hit returns the SKU; duplicate
SKU insert is rejected by the PK.
