# Feature Plan: Webstore order ingest

- **Feature id:** 004-webstore-order-ingest
- **Spec:** ./spec.md
- **Status:** planned

## Approach

One enum value plus one handler codeunit, the canonical "new integration is a
module" shape. The handler parses the staged JSON, reads Integration Setup, and
builds a standard Sales Header / Sales Line, mapping SKUs through feature 003. All
work runs inside the dispatcher's per-message `Codeunit.Run`, so any failure rolls
the order back cleanly. Idempotency is the staging dedup plus a defensive lookup for
an existing order with the same External Document No.

## Standard BC reused

- **Sales Header / Sales Line** (Document Type Order) created through standard
  `Validate` calls and `Insert(true)`; No. assignment via standard No. Series.
- **Customer**, **Item**, **Location**, **Shipment Method** standard masters.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Webstore Message Types | enumextension | 73298414 | new | Adds WebstoreOrder (ordinal 10) implementing the handler. |
| Webstore Order Handler | codeunit | 73298427 | new | Parse payload, create the Sales Order. |
| Integration JSON Helper | codeunit | 73298429 | new | Shared defensive JSON readers (used by 004 and 006). |
| Integration Foundation | permissionset | 73298460 | extend | Add the handler; grant standard sales tabledata. |

## Data model

No new tables. Writes standard Sales Header / Sales Line. Reads Integration Setup,
Integration SKU Mapping, and the staged Integration Message Request blob.

## Integration points

- Inbound only; consumes the staged message. No `HttpClient`.
- SKU resolution through `Integration SKU Mgt.TryGetMapping`.
- Idempotency: dedup at staging on `(orderNo, WebstoreOrder)`; defensive check for an
  existing Sales Order with External Document No. = `orderNo`.

## Cross-cutting

- Permissions: add `codeunit "Webstore Order Handler" = X` and the standard sales
  tabledata the handler writes (`tabledata "Sales Header" = RIM`,
  `tabledata "Sales Line" = RIM`).
- Telemetry: reuses the 001 dispatch events; no new event ids.
- Upgrade: enum value is additive; ordinal 10 is fixed and must not be reordered.
- Performance: one order, a bounded set of lines; SKU lookups are PK `Get`. No loop
  over unbounded data.

## Risks and decisions

- **Permanent vs transient classification.** Unmapped SKU and missing setup are
  Permanent (raised via `MessageMgt.CreatePermanentError`); they must not retry.
  Unexpected errors stay Transient (default) for one bounded retry.
- **Price authority.** Line unit price is taken from the payload, not recalculated,
  because the storefront is the authority for the order as placed.
- **JSON robustness.** Missing or null fields are read defensively; a malformed body
  fails Permanent rather than producing a half-built order.

## Test strategy

Tests seed the Webstore customer, items, and SKU mappings, stage a WebstoreOrder
message, run the dispatcher, and assert: one Sales Order with the right lines and
Document No. on the message; a duplicate stages once; an unmapped SKU fails
Permanent with nothing left behind; missing setup fails Permanent.
