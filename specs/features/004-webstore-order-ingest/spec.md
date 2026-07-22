# Feature Spec: Webstore order ingest

- **Feature id:** 004-webstore-order-ingest
- **Roadmap item:** specs/roadmap.md item 4
- **Business process:** 1 (ingest an order), inbound
- **Status:** spec

## Problem

Orders placed on the Webstore must become standard Sales Orders in BC with no
re-keying, mapped to the right items and the dedicated Webstore customer, and a
re-delivery must never create a second order. This is the first integration module
on the foundation: one message type and one handler, no new plumbing.

## Users and roles

- **The integration layer** POSTs the Webstore order to the inbound API page
  (feature 001) with `messageType = WebstoreOrder`.
- **The dispatcher** routes it to the Webstore order handler.
- **Sales staff** then see and release a normal Sales Order.

## Scope

- A **WebstoreOrder** value on the Integration Message Type enum, implementing the
  handler interface.
- A **handler** that parses the staged Webstore order payload (per the integration
  contract) and creates a standard Sales Order: the dedicated Webstore customer,
  the shopper name/address on the ship-to, each SKU mapped to a BC item through
  feature 003, the storefront `orderNo` as the External Document No. and the
  message correlation id.
- **Idempotency**: re-delivery of the same `orderNo` creates no second Sales Order
  (staging dedup plus a defensive existing-order check).
- A clear **Permanent failure** on an unmapped SKU or missing setup, landing on the
  resolution page.
- Permission set additions.

## Out of scope

- Releasing the order or requesting fulfilment (feature 005).
- Pricing logic beyond taking the line unit price from the payload.
- Customer-per-shopper (resolved: one shared Webstore customer, shopper on ship-to).
- Payment capture (non-goal).

## User flow

1. A staged WebstoreOrder message is New.
2. The dispatcher runs the handler. It loads Integration Setup, parses the payload,
   and verifies the Webstore customer is configured.
3. It creates a Sales Order on the Webstore customer, sets the ship-to from the
   shopper details, sets External Document No. = `orderNo`, and applies the default
   location and shipment method.
4. For each line it resolves the SKU to an item (003) and adds a Sales Line with the
   payload quantity and unit price. An unmapped SKU fails the message Permanent.
5. On success it records the Sales Order No. on the message Document No. and a small
   response, and the message is Resolved.

## Acceptance criteria

- [ ] Given a valid WebstoreOrder payload and a configured Webstore customer and SKU
      mappings, when the handler runs, then exactly one Sales Order exists on the
      Webstore customer with External Document No. = `orderNo`, one line per payload
      line mapped to the right item, quantity, and unit price, and the message is
      Resolved with Document No. = the Sales Order No.
- [ ] Given the same `orderNo` delivered twice, when both are processed, then only
      one Sales Order exists (the second message dedups at staging; a re-run of the
      same message does not create a second order).
- [ ] Given a payload line whose SKU is not mapped, when the handler runs, then no
      Sales Order is left behind (the work rolls back) and the message is Failed with
      Error Class Permanent naming the unmapped SKU.
- [ ] Given no Webstore customer configured in setup, when the handler runs, then the
      message Fails Permanent with a clear setup error.
- [ ] Given any object this feature defines, then it is in the Integration
      Foundation permission set.

## Data and rules

- One shared Webstore customer (from setup) carries every order; shopper identity
  rides on the Sales Order ship-to fields, not a new customer.
- `orderNo` is the External Document No. and the correlation id; it is the
  idempotency key.
- Line unit price comes from the payload (the storefront is the price authority for
  the order as placed).
- All-or-nothing: a failure on any line rolls back the whole order (the handler runs
  inside the dispatcher's per-message transaction).

## Telemetry and audit

The handler relies on the feature 001 dispatch telemetry (dispatch start, handler
success/failure). No extra payload or PII is logged. The created Sales Order No. is
recorded on the message for traceability.

## Open questions

None blocking.
