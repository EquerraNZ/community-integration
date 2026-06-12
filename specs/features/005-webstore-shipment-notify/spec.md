# Feature Spec: Webstore Shipment Notify

> The what and why for notifying the Webstore when a shipment is posted.

- **Feature id:** 005-webstore-shipment-notify
- **Roadmap item:** #5 in specs/roadmap.md
- **Status:** spec

## Problem

When BC posts a Sales Shipment (from the WMS confirmation in feature 004), the
Webstore must be told the order is despatched so the shopper can see shipment
status. Today this notification does not happen. The extension must raise a
business event carrying the Webstore status-update payload so the integration
layer can call the Webstore.

## Users and roles

- **Integration layer** (external) subscribes to the business event and calls
  the Webstore PATCH endpoint.
- **Shopper** sees their order status change to "Despatched" on the storefront.

## Scope

- Subscribe to Sales Shipment posting (detect when a Sales Shipment is posted
  from a Sales Order that has an External Document No., meaning it originated
  from the Webstore).
- Build the status-update payload: `{ "status": "Despatched", "bcOrderNo":
  "{Sales Order No.}", "despatchedAt": "{posted datetime}" }`.
- Stage an outbound Integration Message (Type = "Webstore Shipment Notify",
  Status = Completed).
- Raise a `[BusinessEvent]` OnAfterShipmentNotify carrying the Webstore order
  number and the payload, so the integration layer can PATCH the storefront.

## Out of scope

- Making the HTTP PATCH call to the Webstore (that is the integration layer).
- Handling the Webstore response.
- Notifying on partial shipments (only notify when the order is fully shipped,
  i.e. all quantities shipped). Actually per the brief, the storefront only
  has `Despatched`, so we notify on every shipment posting regardless of
  partial/full. The storefront is idempotent.

## User flow

1. WMS shipment confirmation is processed (feature 004) and Sales-Post runs.
2. The extension detects the shipment posting, checks the Sales Order has an
   External Document No. (Webstore order marker).
3. Builds the status-update payload and stages an outbound Integration Message.
4. Raises OnAfterShipmentNotify business event.
5. Integration layer PATCHes the Webstore.

## Acceptance criteria

- [ ] Given a posted Sales Shipment from a Sales Order with External Document
      No., when shipment posts, then an Integration Message of Type "Webstore
      Shipment Notify" with Status = Completed is created.
- [ ] Given the message is created, the payload contains `status` =
      "Despatched", `bcOrderNo` = Sales Order No., and `despatchedAt` = posting
      timestamp in ISO 8601 format.
- [ ] Given a Sales Order with no External Document No. (not from Webstore),
      when shipment posts, then no notification message is created.
- [ ] Given the same shipment is somehow posted twice (should not happen, but
      idempotency key prevents duplicate messages), only one message is staged.
- [ ] The `[BusinessEvent]` OnAfterShipmentNotify carries the Webstore order
      number (correlation) and the payload text.
- [ ] Telemetry is emitted on successful notification staging.

## Data and rules

- **Trigger**: subscribe to OnAfterPostSalesDoc (or the Sales Shipment Header
  OnAfterInsert, or the posting event that fires after Sales-Post completes
  with Ship = true).
- **Filter**: only fire when the Sales Header."External Document No." is
  non-empty (Webstore orders carry the storefront order number there).
- **Outbound Integration Message**: Type = "Webstore Shipment Notify",
  Idempotency Key = `{External Document No.}-SHIP` (deterministic),
  Correlation ID from External Document No., Request Content = payload JSON.
- **Payload schema** (from the brief):
  ```json
  { "status": "Despatched", "bcOrderNo": "S-ORD101001", "despatchedAt": "2026-06-11T15:02:00Z" }
  ```

## Telemetry and audit

- INTMSG-WEB01: Webstore shipment notification staged (dimensions: Sales Order
  No., Webstore Order No., correlation id).

## Open questions

None. The Webstore status-update endpoint is idempotent (re-sending Despatched
returns `"transitioned": false`), so notifying on every shipment (partial or
full) is safe.
