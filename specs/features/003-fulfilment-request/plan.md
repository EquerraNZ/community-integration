# Feature Plan: Fulfilment Request

> From approved `spec.md`. The how: subscribe to Sales Order release, build the
> WMS payload, stage an outbound Integration Message, raise a business event.

- **Feature id:** 003-fulfilment-request
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Subscribe to the standard Release Sales Document event. When the document type
is Order, build the fulfilment-request JSON, stage an outbound Integration
Message, and raise a `[BusinessEvent]` carrying the payload. Use WMS Setup for
defaults (Location Code, Shipping Method, SKU Source). Reverse-lookup SKUs via
the existing Integration SKU Mapping table. No HTTP calls from BC.

## Standard BC reused

- **Sales Header / Sales Line**: read Ship-to fields and line quantities from
  the released Sales Order.
- **Release Sales Document** (codeunit 414): subscribe to
  `OnAfterReleaseSalesDoc` to detect release.
- **Integration SKU Mapping** (from feature 002): reverse lookup Item No. to
  External SKU.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| WMS Setup | table | 73298450 | new | Singleton: Location Code, Shipping Method, SKU Source |
| WMS Setup | page | 73298450 | new | Admin card for WMS configuration |
| Fulfilment Request Type | enumextension | 73298450 | extend Integration Message Type | Add "Fulfilment Request" value |
| Fulfilment Req. Processor | codeunit | 73298450 | new | Implements IIntegration Msg. Processor (no-op, outbound only) |
| Fulfilment Request Mgt. | codeunit | 73298451 | new | Subscribes to release, builds payload, stages message, raises event |
| Integration Events | codeunit | 73298452 | new | Holds the [BusinessEvent] procedure OnAfterFulfilmentRequested |

## Data model

### WMS Setup (table 73298450)

| Field | Type | Constraint |
|---|---|---|
| Primary Key | Code[10] | PK, default '' (singleton) |
| Location Code | Code[10] | TableRelation Location |
| Shipping Method | Text[50] | Default shipping method text |
| SKU Source | Code[20] | Source code for reverse SKU lookup, default 'WMS' |

### Integration Message (existing, no schema change)

- Type = "Fulfilment Request" (new enum value 73298450)
- Idempotency Key = `{Sales Order No.}-FUL`
- Correlation ID = External Document No.
- Request Content = fulfilment JSON payload
- Status = Completed (success) or Failed (error)

## Integration points

- **Event subscribed**: `OnAfterReleaseSalesDoc` (codeunit 414
  "Release Sales Document"). Filter: Doc.Type = Order only.
- **Business event raised**: `OnAfterFulfilmentRequested` on codeunit
  "Integration Events" (73298452). Parameters: CorrelationId (Text),
  Payload (Text). The integration layer subscribes externally.
- **No HTTP call** from BC. The integration layer reads the event payload and
  calls the WMS.

## Cross-cutting

- **Permissions**: WMS Setup (RIMD), Integration Events codeunit (X). To be
  added to the permission set in feature 006.
- **Telemetry**: INTMSG-WMS01 on success, INTMSG-WMS02 on failure. Dimensions:
  Sales Order No., Correlation ID.
- **Upgrade**: No schema migration needed (new table, new enum value only).
- **Performance**: The subscriber runs synchronously inside Release. It does one
  Sales Line FindSet (bounded by the order) and one SKU Mapping FindFirst per
  line. Acceptable for typical order sizes (< 50 lines).

## Risks and decisions

- **Reverse SKU lookup source**: The spec uses a configurable SKU Source on WMS
  Setup. If the Webstore and WMS share the same catalogue codes, a single
  mapping row with Source = "WEBSTORE" covers both. The default "WMS" keeps them
  separate if needed.
- **Re-release**: Releasing the same order twice creates two Integration
  Messages. Idempotency is handled by the WMS (via the Idempotency-Key header
  the integration layer sends). This is documented in the spec.
- **Blocking release on error**: If the reverse SKU lookup fails, the extension
  does NOT block the Sales Order release (that would surprise the user). Instead
  it stages a Failed Integration Message and emits telemetry. The order is
  released; the WMS just does not get notified until the mapping is fixed and
  the order is re-released.

## Test strategy

AL test codeunit with Library - Sales helpers. Create a Sales Order, populate
SKU mappings and WMS Setup, then call Release. Assert:
- Integration Message created with correct Type, Status, payload content.
- Reverse SKU resolution produces the expected external SKU in the payload.
- Missing mapping results in Failed message with error text.
- Missing WMS Setup results in Failed message.
- Business event fires (subscribe in the test codeunit to capture).
- Payload JSON matches the schema from the brief.
