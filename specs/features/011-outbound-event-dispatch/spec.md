# Feature Spec: Outbound Event Dispatch

> Both outbound flows, on the plane. Completes business processes 2 and 4, and with
> them the whole loop.

- **Feature id:** 011-outbound-event-dispatch
- **Roadmap item:** #11 in specs/roadmap.md
- **Status:** in-progress

## Problem

`005` and `007` raise `OnSalesOrderReleased_v1` and `OnShipmentConfirmed_v1`, and BC
makes no call itself by design. Nothing is subscribed to those events, so releasing an
order asks the WMS for nothing and posting a shipment tells the storefront nothing.
The order reaches BC and stops there.

This feature subscribes to both events and makes the two calls. It also carries the
one piece of real complexity in the whole plane: the fulfilment DTO cannot ride on the
event, because an `[ExternalBusinessEvent]` argument is capped at 250 characters and a
multi-line order exceeds it. The event carries identifiers, the staged outbound
Integration Message carries the DTO, and the plane joins them.

## Users and roles

- **Business Central (machine caller):** delivers an external business event to the
  plane's registered endpoint, and expects a fast answer and a validation handshake it
  can complete at registration.
- **The WMS (machine callee):** receives a fulfilment request with an idempotency key.
- **The storefront (machine callee):** receives a status patch it can safely receive
  twice.
- **Operations:** sees the WMS reference recorded against the BC outbound message, and
  a dead-lettered dispatch in Azure.

## Scope

- `receiveBusinessEvent`: `POST /api/bc/events`. Answers the subscription validation
  handshake, routes by event name onto `outbound-wms-fulfilment` or
  `outbound-webstore-status`, answers `200`. An unknown event name is acknowledged,
  logged, and dropped.
- `sendWmsFulfilment`: Service Bus trigger on `outbound-wms-fulfilment`. Reads the
  staged outbound Integration Message back from BC by its reference, POSTs the DTO to
  the WMS with `Idempotency-Key`, and records the returned `wmsRef` on that message.
- `sendWebstoreStatus`: Service Bus trigger on `outbound-webstore-status`. PATCHes the
  storefront order to `Despatched` with the BC order number and the despatch
  timestamp.
- Unit tests over the router and both senders.

## Out of scope

- Registering the subscriptions and watching their health, which is feature 012.
- Carrier and tracking on the storefront. The storefront has no fields for them
  (brief), and adding them is a `_v2` of the event when it does.
- Any retry logic written by hand. Retry is the queue's.

## User flow

1. A staff member releases the Sales Order. BC raises `OnSalesOrderReleased_v1` and
   stages an outbound Integration Message carrying the fulfilment DTO.
2. BC delivers the event to `receiveBusinessEvent`, which routes it onto
   `outbound-wms-fulfilment` and answers `200`.
3. `sendWmsFulfilment` reads the DTO back from BC by its reference, POSTs it to the
   WMS with `Idempotency-Key: DG-00001`, and writes the `wmsRef` back onto the
   message.
4. Later, the WMS confirms, BC posts the shipment and raises
   `OnShipmentConfirmed_v1`.
5. `receiveBusinessEvent` routes it onto `outbound-webstore-status`, and
   `sendWebstoreStatus` PATCHes the storefront, which shows the shopper the order has
   shipped.

## Acceptance criteria

- [ ] Given a subscription validation request, when BC registers the endpoint, then
      the handshake is answered and no message is enqueued.
- [ ] Given `OnSalesOrderReleased_v1`, then a message is enqueued on
      `outbound-wms-fulfilment` with the reference as the business key and the
      correlation id from the event.
- [ ] Given `OnShipmentConfirmed_v1`, then a message is enqueued on
      `outbound-webstore-status`.
- [ ] Given an unrecognised event name, then the endpoint answers `200`, logs it, and
      enqueues nothing, so a new BC event cannot wedge delivery of the others.
- [ ] Given a queued fulfilment, when `sendWmsFulfilment` runs, then it reads the
      staged outbound message from BC and POSTs its DTO unchanged, with
      `Idempotency-Key` set to the reference and `x-correlation-id` set.
- [ ] Given the WMS answering `201` with a `wmsRef`, then that reference is recorded
      on the BC outbound message.
- [ ] Given the WMS answering `409` or returning the existing fulfilment for a repeat
      idempotency key, then the function completes and records, and does not create a
      second fulfilment.
- [ ] Given the WMS unreachable or answering `503`, then the function rethrows and the
      message is redelivered, up to the delivery count, then dead-lettered.
- [ ] Given the WMS answering `422` on an invalid payload, then the function
      dead-letters with a reason and does not retry.
- [ ] Given a queued despatch notification, then the storefront is PATCHed with
      `status: Despatched`, the BC order number, and the despatch timestamp.
- [ ] Given a repeated despatch notification, then the storefront answers
      `transitioned: false`, the function treats it as success, and the shopper sees
      no change.
- [ ] Given a staged outbound message that BC does not have, then the function
      dead-letters with a reason rather than retrying forever.

## Data and rules

No new shape. The event DTOs are pinned in
`specs/contracts/integration-contract.md` under "Outbound event DTOs", and the outward
calls under "What the plane sends outward".

| Event | Queue | Business key | Call |
|---|---|---|---|
| `OnSalesOrderReleased_v1` | `outbound-wms-fulfilment` | `reference` | `POST {WMS_BASE_URL}/api/v2/fulfilments` |
| `OnShipmentConfirmed_v1` | `outbound-webstore-status` | `orderNo` | `PATCH {WEBSTORE}/api/orders/{orderNo}/status` |

Rules:

- The plane sends the staged DTO as it stands. It adds no field and drops none, and it
  never rebuilds a DTO from BC records, because that would move BC's logic into the
  plane.
- `Idempotency-Key` is the reference, per the contract, so a redelivery is a no-op at
  the WMS rather than a second shipment.
- The storefront PATCH is idempotent by design. `transitioned: false` is success.

## Telemetry and audit

Event received (name, correlation id), routed (queue), unknown event dropped (name),
dispatch started (delivery count), DTO read from BC (message id), dispatch succeeded
(downstream status, `wmsRef` where there is one), dispatch failed (classification,
dead-lettered or not). No DTO body in telemetry: it carries the shopper's name,
address, and phone.

## Open questions

None outstanding. This feature depends on the BC read path from tech design question 8;
if the read is not available, the fulfilment flow cannot complete, and that is the
single point of failure worth watching during implementation.
