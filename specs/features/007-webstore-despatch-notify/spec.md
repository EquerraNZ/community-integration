# Feature Spec: Webstore despatch notify

- **Feature id:** 007-webstore-despatch-notify
- **Roadmap item:** specs/roadmap.md item 7
- **Business process:** 4 (notify the Webstore), outbound
- **Status:** spec

## Problem

Once BC posts the shipment, the Webstore must be told the order has shipped so the
shopper sees it. BC makes no call: it raises an external business event after the
shipment posts, and the integration layer sets the storefront order to Despatched.
A re-fire must change nothing. This closes the loop on the outbound path.

## Users and roles

- **The integration layer** subscribes to the event and PATCHes the storefront.
- **Shoppers** see the order move to Despatched.

## Scope

- An **OnShipmentConfirmed_v1** external business event carrying the storefront order
  number, the BC order number, the correlation id, and the despatch timestamp (per
  the integration contract).
- A **thin subscriber** on the posting of a sales shipment that, for a Webstore
  order, raises the event once.
- An **outbound Integration Message** staged for audit, with idempotency so a second
  (partial) shipment on the same order does not notify or stage twice.
- Permission set additions.

## Out of scope

- The storefront PATCH itself (the integration layer owns it; it is idempotent).
- Carrier and tracking on the storefront (the storefront has no such fields today).

## User flow

1. The WMS shipment confirmation handler (006) posts a sales shipment.
2. The thin shipment subscriber fires, exits early on a non-Webstore order, temp
   record, or non-Normal execution mode, and otherwise delegates.
3. The despatch management codeunit, if this order has not already been notified,
   stages an outbound message and raises OnShipmentConfirmed_v1 with the order
   number and despatch timestamp.
4. The platform delivers the event post-commit; the integration layer PATCHes the
   storefront to Despatched with the BC order number.

## Acceptance criteria

- [ ] Given a posted sales shipment for a Webstore-customer order, when the subscriber
      fires, then OnShipmentConfirmed_v1 is raised once with orderNo = the order's
      External Document No., bcOrderNo = the order No., and a despatch timestamp.
- [ ] Given that despatch, when processed, then exactly one outbound Integration
      Message exists for the order (Direction Outbound, Type DespatchNotification,
      correlation id = order number).
- [ ] Given a second (partial) shipment posts for the same order, when the subscriber
      fires again, then no second event is raised and no second outbound message is
      staged (idempotent on the order number).
- [ ] Given a posted shipment for a non-Webstore order, then no event is raised.
- [ ] Given any object this feature defines, then it is in the Integration Foundation
      permission set.

## Data and rules

- Only shipments on the configured Webstore customer notify the storefront.
- The storefront order number is the correlation id and the idempotency anchor; the
  notification is sent at most once per order.
- The event carries no carrier / tracking (the storefront has no fields for them);
  a future `_v2` can add them if the storefront gains the fields.

## Telemetry and audit

Staging the outbound message emits the feature 001 outbound-staged telemetry
(INT-0006). No payload or PII is logged.

## Open questions

None blocking.
