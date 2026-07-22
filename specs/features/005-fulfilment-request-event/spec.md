# Feature Spec: Fulfilment request event

- **Feature id:** 005-fulfilment-request-event
- **Roadmap item:** specs/roadmap.md item 5
- **Business process:** 2 (release and request fulfilment), outbound
- **Status:** spec

## Problem

Releasing a Webstore order must ask the WMS to ship it, without BC ever making an
HTTP call. The outbound arrow is an external business event: BC raises it on
release, the integration layer subscribes and calls the WMS. This proves the
outbound path on the foundation.

## Users and roles

- **Sales staff** release the Sales Order in BC.
- **The integration layer** subscribes to the event and calls the WMS.

## Scope

- An **OnSalesOrderReleased_v1** external business event carrying the fulfilment
  DTO (per the integration contract): reference, bcOrderNo, correlationId, shipTo,
  lines (source SKUs), shippingMethod, requestedAt.
- A **thin subscriber** on sales release that, for a Webstore order, builds the DTO
  and raises the event.
- An **outbound Integration Message** staged as the correlation parent (Awaiting
  Reply), so the request and the later WMS confirmation share a visible parent
  (resolves open question 1 for this flow).
- Permission set additions.

## Out of scope

- The actual WMS call (the integration layer owns it).
- Posting the shipment (feature 006).
- Any retry loop: external business event delivery is platform-retried.

## User flow

1. Staff release a Sales Order on the Webstore customer.
2. The thin release subscriber fires, exits early on a non-Webstore order, a temp
   record, preview, or non-Normal execution mode, and otherwise delegates.
3. The fulfilment management codeunit builds the DTO (reverse-mapping each item to
   its source SKU), stages an outbound message keyed on the order number, and
   raises OnSalesOrderReleased_v1.
4. The platform delivers the event post-commit to the subscribed integration layer,
   which calls the WMS with the order number as the Idempotency-Key.

## Acceptance criteria

- [ ] Given a released Sales Order on the Webstore customer with mapped items, when
      the release subscriber fires, then OnSalesOrderReleased_v1 is raised once with
      reference = the order's External Document No., bcOrderNo = the order No., and
      the correlation id. The full fulfilment DTO (one line per item, reverse-mapped
      to the source SKU and quantity) is on the staged outbound message, because
      external business event arguments are capped at 250 characters.
- [ ] Given that release, when it is processed, then exactly one outbound Integration
      Message exists for the order (Direction Outbound, Status Awaiting Reply,
      correlation id = order number).
- [ ] Given a released order that is not on the Webstore customer, when release
      fires, then no event is raised and no outbound message is staged.
- [ ] Given the release runs in preview or a non-Normal execution mode, then no event
      is raised (the subscriber exits early).
- [ ] Given any object this feature defines, then it is in the Integration
      Foundation permission set.

## Data and rules

- Only orders on the configured Webstore customer trigger fulfilment.
- The order number (External Document No.) is the reference, the correlation id, and
  the integration layer's Idempotency-Key.
- The event payload carries source SKUs (reverse-mapped), never BC item numbers, so
  the WMS receives its own catalogue keys.
- The event carries no secret and no full BC record, only stable identifiers.

## Telemetry and audit

Staging the outbound message emits the feature 001 outbound-staged telemetry
(INT-0006) with correlation id and message id. The event itself is observable
through the platform's business-event delivery; no payload is logged by BC.

## Open questions

None blocking. Open question 1 is resolved for this flow: stage an outbound parent.
