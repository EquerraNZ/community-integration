# Feature Spec: Inbound Receivers and Staging

> Both inbound flows, on the plane. Completes business processes 1 and 3 end to end.

- **Feature id:** 010-inbound-receivers-and-staging
- **Roadmap item:** #10 in specs/roadmap.md
- **Status:** in-progress

## Problem

`004` and `006` built the BC handlers that turn a Webstore order into a Sales Order
and a WMS confirmation into a posted shipment, and `001` built the API page that
stages them. Nothing calls that API page. The storefront forwards its orders to a URL
that does not exist yet, and the WMS has nowhere to send a confirmation.

Both inbound flows have the same shape, which is why they are one feature: accept,
authenticate, acknowledge immediately, queue, then stage into BC. Building them
together is what proves the shape is shared rather than coincidental.

## Users and roles

- **The storefront (machine caller):** POSTs a placed order and needs an answer inside
  its own timeout, whatever BC is doing.
- **The WMS (machine caller):** POSTs a shipment confirmation, with an idempotency key
  and a correlation id it sets itself.
- **Operations:** sees the staged message in the BC Integration Message list, and sees
  a dead-lettered one in Azure.

## Scope

- `receiveWebstoreOrder`: `POST /api/webstore/orders`. Compares `x-api-key` with the
  vault value, reads `x-correlation-id`, takes `orderNo` as the business key, enqueues
  on `inbound-webstore-order`, answers `202`.
- `receiveWmsShipment`: `POST /api/wms/shipments`. The same, keyed on `shipmentId`,
  correlated on `reference`, onto `inbound-wms-shipment`.
- `stageWebstoreOrder`: Service Bus trigger on `inbound-webstore-order`. POSTs the
  inbound envelope to the BC API page with `messageType: WebstoreOrder`.
- `stageWmsShipment`: Service Bus trigger on `inbound-wms-shipment`. The same with
  `messageType: WmsShipmentConfirmation`.
- Unit tests over both receivers and both stagers.

## Out of scope

- Any outbound flow, which is feature 011.
- Reshaping a payload. The source body is staged verbatim; the BC handler parses it.
- Validating the payload beyond finding the business key. BC owns what is valid, and a
  plane that pre-judges a payload is a second place to maintain the rules.

## User flow

1. A shopper checks out. The storefront POSTs the order to `receiveWebstoreOrder` with
   its key and `x-correlation-id: DG-00001`.
2. The receiver authenticates, enqueues, and answers `202`. The shopper's checkout
   completes without waiting for BC.
3. `stageWebstoreOrder` takes the message off the queue and POSTs the envelope to the
   BC API page. BC stages it and the dispatcher creates the Sales Order.
4. Later, the WMS POSTs a shipment confirmation to `receiveWmsShipment`, which
   acknowledges and enqueues it.
5. `stageWmsShipment` stages it into BC, where the handler posts the shipment.

## Acceptance criteria

- [ ] Given a valid order and a correct key, when posted to `receiveWebstoreOrder`,
      then it answers `202` and a message is on `inbound-webstore-order`.
- [ ] Given a wrong or missing `x-api-key`, then the receiver answers `401` and
      enqueues nothing.
- [ ] Given a body with no `orderNo`, then the receiver answers `400` and enqueues
      nothing.
- [ ] Given the same order posted twice inside the duplicate detection window, then
      only one message reaches the queue, because both carry the same `MessageId`.
- [ ] Given a request with no `x-correlation-id`, then the correlation id is the order
      number, not a new value.
- [ ] Given a queued order, when `stageWebstoreOrder` runs, then BC receives
      `messageType: WebstoreOrder`, `externalReference` the order number, and the
      source body verbatim in `payload`.
- [ ] Given BC answering `409` because the order was already staged, then the function
      completes the message and does not retry.
- [ ] Given BC answering `503`, then the function rethrows and the message is
      redelivered.
- [ ] Given BC answering `400`, then the function dead-letters with a reason and does
      not retry.
- [ ] Given a WMS confirmation, then it stages with `messageType:
      WmsShipmentConfirmation`, `externalReference` the `shipmentId`, and the
      correlation id taken from `reference`.
- [ ] Given a receiver answering a caller, then nothing in the request path has called
      BC, the WMS, or the storefront.

## Data and rules

No new shape. The receivers build the envelope from
`specs/contracts/integration-contract.md`, and the stagers build the inbound envelope
from the same file. The two business keys:

| Flow | Business key | Correlation id | BC `messageType` |
|---|---|---|---|
| `webstore-order` | `orderNo` | `x-correlation-id`, else `orderNo` | `WebstoreOrder` |
| `wms-shipment` | `shipmentId` | `x-correlation-id`, else `reference` | `WmsShipmentConfirmation` |

A WMS confirmation is keyed on `shipmentId` and correlated on `reference`, and the two
are deliberately different: the shipment id is what must not post twice, and the order
number is what joins this hop to the rest of the order's history.

## Telemetry and audit

Receiver accepted (flow, business key), receiver rejected (reason, status returned),
enqueued, staging started (delivery count), staged (BC message id and status), staging
failed (classification, dead-lettered or not). Correlation id on every one. No payload
body, and in particular none of the shopper's name, email, phone, or address.

## Open questions

None outstanding. This feature depends on the BC identity path proven in `009` task 19;
if that is not settled, this feature cannot be verified end to end.
