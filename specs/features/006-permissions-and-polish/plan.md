# Feature Plan: Permissions and Polish

> From approved `spec.md`. One permission set covering all extension objects.

- **Feature id:** 006-permissions-and-polish
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Create a single permissionset object (73298480) that grants RIMD on all
extension tables and X on all codeunits and pages. This is the standard pattern
for a per-tenant extension where one permission set covers everything.

## AL objects to add

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration Found. | permissionset | 73298480 | new | Full access to all extension objects |

## Object inventory to cover

### Tables (RIMD)
- 73298400 "Integration Message"
- 73298420 "Integration SKU Mapping"
- 73298421 "Webstore Setup"
- 73298450 "WMS Setup"

### Codeunits (X)
- 73298400 "Integration Msg. Process"
- 73298401 "Integration Msg. Retry"
- 73298402 "Integration Msg. Stage"
- 73298420 "Webstore Order Processor"
- 73298421 "Webstore Ship. Notify Proc."
- 73298422 "Webstore Shipment Notify"
- 73298450 "Fulfilment Req. Processor"
- 73298451 "Fulfilment Request Mgt."
- 73298452 "Integration Events"
- 73298453 "Shipment Confirm. Proc."

### Pages (X)
- 73298400 "Integration Messages API"
- 73298401 "Integration Messages"
- 73298402 "Integration Message Card"
- 73298420 "Integration SKU Mapping"
- 73298421 "Webstore Setup"
- 73298450 "WMS Setup"

## Test strategy

The permission set is validated by compilation. No runtime test needed since
BC's permission system is a platform feature.
