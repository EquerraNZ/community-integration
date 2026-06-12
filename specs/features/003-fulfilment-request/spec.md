# Feature Spec: Fulfilment Request

> The what and why for the WMS outbound fulfilment request. No AL, no object
> names yet (those belong in `plan.md`). Stop for human review before planning.

- **Feature id:** 003-fulfilment-request
- **Roadmap item:** #3 in specs/roadmap.md
- **Status:** spec

## Problem

When a staff member releases a Sales Order in BC, the WMS must be told to pick,
pack, and ship the goods. Today that handoff is manual. The extension must raise
a structured business event carrying the fulfilment payload so the external
integration layer can forward it to the WMS, with no HTTP call from BC.

## Users and roles

- **Warehouse coordinator** releases the Sales Order in BC and expects the WMS
  to begin fulfilment automatically.
- **Integration layer** (external, subscribes to the business event) receives
  the payload and calls the WMS.

## Scope

- Subscribe to standard Sales Order release.
- Build the fulfilment-request JSON payload from the released Sales Order.
- Stage an outbound Integration Message (Type = "Fulfilment Request",
  Status = Completed immediately since it is fire-and-forget from BC's
  perspective).
- Raise a `[BusinessEvent]` carrying the payload so the integration layer can
  subscribe.
- WMS Setup singleton table and page: Location Code (which warehouse location
  to use) and Shipping Method (default shipping method for requests).
- Populate ship-to address from the Sales Order's Ship-to fields.
- Map Sales Lines back to external SKUs (reverse lookup on Integration SKU
  Mapping by Item No.) so the WMS receives the SKUs it understands.

## Out of scope

- Making an HTTP call to the WMS (that is the integration layer's job).
- Handling the WMS response (feature 004).
- Partial-release or split-shipment logic (the full order is sent as one
  request).
- Drop-ship orders.

## User flow

1. Staff member opens a Sales Order (created by the Webstore ingest or
   manually).
2. Staff member clicks Release (standard action).
3. The extension detects the release, builds the payload, stages the outbound
   Integration Message, and raises the business event.
4. The integration layer (external subscriber) receives the event and calls the
   WMS.

Alternate: If the Sales Order has no lines, or the SKU reverse lookup fails for
any line, the extension does not raise the event and writes a Failed Integration
Message with a clear error.

## Acceptance criteria

- [ ] Given a released Sales Order with mapped SKUs, when Release completes,
      then an Integration Message of Type "Fulfilment Request" with
      Status = Completed is created.
- [ ] Given a released Sales Order, the outbound payload contains reference
      (External Document No., i.e. the Webstore order number), bcOrderNo
      (Sales Order No.), shipTo (from the Sales Header ship-to fields), lines
      with sku and quantity, shippingMethod (from WMS Setup), and requestedAt
      (current UTC).
- [ ] Given a released Sales Order, each line's sku in the payload is resolved
      by reverse-looking up the Item No. in Integration SKU Mapping (Source =
      "WMS" or the configured source) and returning the External SKU.
- [ ] Given a Sales Line whose Item No. has no SKU mapping, when Release is
      attempted, then the Integration Message is created with Status = Failed
      and a clear error describing the unmapped item.
- [ ] Given the business event is raised, its payload matches the WMS
      fulfilment-request schema defined in the brief (reference, bcOrderNo,
      shipTo, lines, shippingMethod, requestedAt).
- [ ] Given WMS Setup is missing Location Code, when Release is attempted,
      then the fulfilment request is not raised and the Integration Message
      records the error.
- [ ] Given the same Sales Order is released twice (re-open then release),
      a second Integration Message is created (idempotency is on the WMS side
      via Idempotency-Key in the HTTP call, not on BC's side for outbound).
- [ ] The `[BusinessEvent]` procedure is external-facing (documented, stable
      signature) and carries the payload as a Text parameter plus the
      correlation id.
- [ ] Telemetry is emitted on successful fulfilment-request creation and on
      failure.

## Data and rules

- **WMS Setup** (singleton): Location Code, Shipping Method (text), SKU Source
  (Code[20], defaults to "WMS").
- **Outbound Integration Message**: Type = "Fulfilment Request",
  Idempotency Key = Sales Order No. + "-FUL" (or similar deterministic key),
  Correlation ID = External Document No. (the Webstore order number),
  Request Content = the JSON payload.
- **Reverse SKU lookup**: given an Item No. and a Source, find the External SKU
  in Integration SKU Mapping. Error if not found.
- **Release subscription**: subscribe to the standard Sales-Release event
  (OnAfterReleaseSalesDoc or equivalent) and only fire for Order document type.

## Telemetry and audit

- Emit telemetry on fulfilment request staged (tag INTMSG-WMS01, dimensions:
  Sales Order No., correlation id).
- Emit telemetry on fulfilment request failed (tag INTMSG-WMS02, dimensions:
  Sales Order No., error reason).

## Open questions

None. The WMS payload schema is fixed in the brief. The SKU reverse lookup uses
the same Integration SKU Mapping table from feature 002 (the Source field
distinguishes Webstore SKUs from WMS SKUs, or they may be the same mapping if
both systems use the same catalogue codes).
