# Project Brief: Business Central Integration Extension and Azure Integration Layer

> A self-contained brief for one integration solution built in two parts: a Business
> Central extension, and the Azure integration layer that sits beside it. It states
> what each part does and why, and it carries the endpoint and payload detail for the
> already-built external systems they integrate with (a Webstore and a WMS), since
> those are fixed inputs to the build. It does not describe either part's internal
> design (data model, objects, events, Azure resource topology); that is worked out in
> the technical design. It references no other file, so it can be copied into any
> repository.

## What we are building

Two parts, built together, that between them carry every message across the boundary:

- **The Business Central extension.** One inbound path and one outbound path for every
  integration, current and future, with idempotency, correlation, retry state, error
  classification, and manual resolution built in once.
- **The Azure integration layer.** The plane outside BC that terminates every external
  connection, holds every external credential, makes every outbound HTTP call, and
  absorbs retry, dead-lettering, and third-party schema change.

The split is the point, not an implementation detail. It is what keeps external
credentials out of BC, keeps BC posting independent of whether a third party is up,
and lets a vendor change their API without a BC release.

## What the extension is, in more detail

The Business Central half, and half of the goal above. One integration extension that
can handle any integration, current or future, through a single shared mechanism, so
that connecting the next external system is a matter of adding a small module rather
than re-architecting or re-building the plumbing. The extension provides one inbound
path and one outbound path, with idempotency, correlation, retry, and error handling
built in once and reused by every integration.

BC is the system of record for orders, fulfilment, and invoicing. The first two
integrations built on the extension, and the ones this brief specifies, connect BC to
an online Webstore and a third-party Warehouse Management System (WMS): orders placed
on the Webstore become Sales Orders in BC; releasing an order asks the WMS to ship it;
the WMS shipment confirmation posts the shipment in BC; and the Webstore is told when
the order has shipped. Future integrations (a finance portal, a marketplace, a carrier
API, an ERP feed) plug into the same paths without changing the core.

None of those hops leaves BC through a call the extension makes itself. The extension
receives, decides, and posts; every message that crosses the boundary in either
direction is carried by the other half.

## What the integration layer is, in more detail

The Azure half, and the only thing that talks to the outside world. It terminates the Webstore and WMS connections, stages every inbound message
into BC through the extension's single inbound endpoint, subscribes to the extension's
outbound business events, and makes the resulting calls to the Webstore and the WMS.

It is built to be as reusable as the extension it serves. Adding a new integration is
adding a receiver and a sender on the same queues, the same correlation handling, the
same retry and dead-letter policy, and the same secret store. Nothing in the plane is
specific to coffee, to the Webstore, or to this WMS except the two adapters that map
their payloads.

It is deliberately thin. It does no business logic, it holds no business state, and it
never decides whether something is valid: it moves messages, guarantees delivery, and
keeps the credentials. Every business decision belongs in BC.

## Customer / context (example scenario, replace for your own)

- **Customer:** "Harbour Coffee Roasters" (fictional), a New Zealand coffee retailer
  that sells through an online Webstore and ships from a warehouse run on a
  third-party WMS.
- **Localisation:** W1, currency NZD.
- **Opportunity:** Harbour re-keys data between the Webstore, BC, and the WMS by
  hand. They want BC to be the system of record and to integrate with both systems
  automatically, with no re-keying.

## Goals

- **Build one integration extension that can handle any integration, now or in the
  future.** Every integration shares one inbound path and one outbound path, and the
  cross-cutting behaviour (idempotency, correlation, retry, error handling, telemetry)
  is provided once by the extension and reused, never re-built per integration. Adding
  a new integration is adding a module, with no change to the core and no new plumbing.
- The Webstore and WMS integrations (the first two) work end to end on that shared
  mechanism, proving the pattern:
  - Webstore orders reach BC automatically and become standard Sales Orders.
  - Releasing an order in BC asks the WMS to pick, pack, and ship it.
  - When the WMS confirms the shipment, BC posts the shipment (and the invoice, if
    configured) and records the carrier and tracking.
  - The Webstore is told when an order has shipped, so the shopper can see it.
- **Build the integration layer once, for every integration.** One set of Azure
  components carries every flow: a receiver that accepts an external message and
  acknowledges it immediately, a durable queue, a stager that writes it into BC, a
  subscriber on BC's outbound events, and a sender that calls the external system.
  Adding a new integration is adding adapters to that plane, not new plumbing.
- **Keep every external credential out of BC.** The Webstore and WMS keys live in the
  plane's secret store, read by managed identity. BC holds none of them because BC
  makes no outbound call.
- **Make the whole path traceable end to end.** One correlation id, the Webstore order
  number, joins the storefront, the plane, and BC, so a single trace answers "where is
  order DG-00001" without reading three systems.
- **Fail safely and visibly.** A message that cannot be delivered after its retries
  lands in a dead-letter queue and raises an alert. Nothing is dropped, and nothing is
  retried forever.

## Non-goals

- Payment capture or settlement (taken on the Webstore; BC records the order as
  configured).
- Real-time inventory sync to the Webstore (a candidate future module, not in this
  build).
- Returns, RMAs, multi-warehouse routing, back-order automation.
- Multi-currency (NZD only).
- AppSource submission.
- A customer-facing portal, dashboard, or admin UI over the integration layer. Its
  operational surface is the BC Integration Message list, Azure's own dead-letter
  queue, and Application Insights.
- Hosting or modifying the Webstore and the WMS. Both are fixed, already-built inputs.
- Multi-region or active-active deployment of the plane.

## What the solution does (business processes)

1. **Ingest an order.** The Webstore sends a placed order to the integration layer,
   which accepts it, answers the storefront immediately, and stages it into BC. The
   extension creates a standard Sales Order, mapping each catalogue SKU to a BC item
   and using a dedicated Webstore customer. A duplicate of the same order does not
   create a second Sales Order.
2. **Release and request fulfilment.** A staff member reviews and releases the Sales
   Order. Releasing it makes the extension raise a fulfilment request, and the
   integration layer carries it to the WMS.
3. **Confirm the shipment.** The WMS confirms the shipment with the carrier,
   tracking, and shipped quantities to the integration layer, which stages it into
   BC. The extension posts the warehouse shipment (and the invoice if configured) and
   records the tracking. A re-sent confirmation does not post a second shipment.
4. **Notify the Webstore.** Once the shipment is posted, the extension says so, and
   the integration layer sets the Webstore order to shipped, recording the BC order
   number.

### Which part owns which hop

Every business process above crosses the boundary at least once, and the same split
applies each time: the plane carries the message, BC decides what it means.

| Hop | Integration layer | BC extension |
|---|---|---|
| Webstore order arrives | receives it, acknowledges the storefront, queues it, stages it into BC | dedups on the order number, creates the Sales Order |
| Order released | subscribes to the release event, calls the WMS with the fulfilment request | raises the release event, stages the outbound request for correlation |
| WMS confirms the shipment | receives the callback, acknowledges the WMS, queues it, stages it into BC | dedups on the shipment id, posts the shipment and records tracking |
| Shipment posted | subscribes to the confirmation event, calls the storefront status endpoint | raises the confirmation event |

## Constraints and assumptions

- **BC never makes an outbound HTTP call.** The extension receives inbound data
  through its own API and raises business events on outbound actions; an external
  integration layer makes the actual calls to the Webstore and the WMS. This must be
  enforced, not just intended.
- **Idempotency and correlation are built in.** Every item that crosses the boundary
  carries the external system's reference (the Webstore order number), which is the
  idempotency key and the correlation id on every hop. Re-delivery never duplicates an
  order, a document, a shipment, a status change, or a notification.
- **Reusable by design.** Adding a new integration must not require a new inbound API
  or new cross-cutting plumbing; the extension provides one inbound path and one
  outbound path that all integrations share.
- **BC target.** BC SaaS, per-tenant extension, publisher "Equerra". Object ID range
  `73298400`-`73298499` (`"from": 73298400, "to": 73298499`). Latest BC platform.
- **Join key.** Items are matched between systems by SKU through a mapping maintained
  in BC. An unmapped SKU fails the item with a clear error rather than guessing.
- **Secrets** live in secure storage, never in plain fields or in source.
- **Azure target.** The integration layer runs in Azure, in one resource group per
  environment, deployed from this repository as infrastructure as code. No resource is
  created by hand in the portal, and no environment differs from another except by its
  parameters.
- **One plane, one owner per flow.** Each flow has exactly one receiver and one sender.
  Two components never call the same external endpoint, so "who sent that" always has
  one answer.
- **At-least-once, everywhere.** Every queue and every external caller may deliver the
  same message twice. The plane assumes it, and every receiving step is safe to run
  again with the same input.
- **Managed identity over keys** for anything in Azure that supports it: plane to Key
  Vault, plane to Service Bus, plane to BC. Static keys are only for the two external
  systems that offer nothing better.

## Integration endpoints and payloads: Webstore (already built)

The Webstore is a public storefront with its own API. It is a fixed input. With a
deployment named `harbour-demo`, its base URL is
`https://swa-harbour-demo.azurestaticapps.net` (the exact host is assigned at deploy;
read it from the deployment output).

### Authentication

- **Create order** (public storefront): anonymous, no key.
- **Order forward** (Webstore to the integration layer): shared key in header
  `x-api-key` (`WEBSHOP_INGEST_KEY`), plus `x-correlation-id: {orderNo}`.
- **Status update** (integration layer to Webstore): shared key in header `x-api-key`
  (`WEBSITE_STATUS_KEY`). A missing or wrong key is rejected with `401`.

### Endpoints

| Method + URL | Auth | Purpose |
|---|---|---|
| `GET https://swa-harbour-demo.azurestaticapps.net/api/products` | none | static catalogue |
| `POST https://swa-harbour-demo.azurestaticapps.net/api/orders` | none | shopper creates an order |
| `GET https://swa-harbour-demo.azurestaticapps.net/api/orders/{orderNo}` | none | read an order and its status |
| `PATCH https://swa-harbour-demo.azurestaticapps.net/api/orders/{orderNo}/status` | `x-api-key` = `WEBSITE_STATUS_KEY` | set the order shipped, idempotent |

### Order status vocabulary

The storefront uses a closed set: `Placed`, `Submitted`, `Despatched`, `Failed`. The
only status the integration sets is `Despatched`. There is no carrier or tracking on
the storefront order today; surfacing those would require a storefront change.

### Order number format

The storefront allocates order numbers as `DG-` plus a 5-digit sequence (for example
`DG-00001`). This is the storefront's own format; it is the external reference used as
the idempotency key and correlation id.

### Payload: the catalogue (`GET /api/products`)

SKUs are the join key to BC items.

```json
[
  { "sku": "ESP-250", "name": "Espresso Blend 250g", "unitPrice": 18.5 },
  { "sku": "FIL-250", "name": "Filter Blend 250g", "unitPrice": 17.0 },
  { "sku": "DEC-250", "name": "Decaf Blend 250g", "unitPrice": 18.0 },
  { "sku": "COL-250", "name": "Colombian Single Origin 250g", "unitPrice": 21.0 },
  { "sku": "ETH-250", "name": "Ethiopian Single Origin 250g", "unitPrice": 22.5 },
  { "sku": "SUM-250", "name": "Sumatra Single Origin 250g", "unitPrice": 21.5 }
]
```

### Payload: create an order (`POST /api/orders`)

The shopper's browser posts an order draft; the storefront allocates `orderNo` and
`placedAt` itself, so they are not in the request:

```json
{
  "currency": "NZD",
  "customer": {
    "name": "Ava Shopper",
    "email": "ava@example.com",
    "phone": "+64 21 555 0101",
    "address": { "line1": "12 Queen Street", "line2": "", "city": "Auckland", "postcode": "1010", "country": "NZ" }
  },
  "lines": [
    { "sku": "ESP-250", "name": "Espresso Blend 250g", "quantity": 2, "unitPrice": 18.50 },
    { "sku": "FIL-250", "name": "Filter Blend 250g",   "quantity": 1, "unitPrice": 17.00 }
  ],
  "totalAmount": 54.00
}
```
Response `201`: `{ "orderNo": "DG-00001", "status": "Submitted" }` (or `"status": "Failed"`
if the storefront could not forward the order after retries). An invalid order (a SKU
not in the catalogue, or a malformed body) returns `400`.

### Payload: the order the Webstore emits (to ingest)

When a shopper checks out, the storefront forwards this order to the integration layer
(`x-api-key: {WEBSHOP_INGEST_KEY}`, `x-correlation-id: {orderNo}`). This is the order
the extension ingests:

```json
{
  "orderNo": "DG-00001",
  "placedAt": "2026-06-11T09:14:00.000Z",
  "currency": "NZD",
  "customer": {
    "name": "Ava Shopper",
    "email": "ava@example.com",
    "phone": "+64 21 555 0101",
    "address": { "line1": "12 Queen Street", "line2": "", "city": "Auckland", "postcode": "1010", "country": "NZ" }
  },
  "lines": [
    { "sku": "ESP-250", "name": "Espresso Blend 250g", "quantity": 2, "unitPrice": 18.50 },
    { "sku": "FIL-250", "name": "Filter Blend 250g",   "quantity": 1, "unitPrice": 17.00 }
  ],
  "totalAmount": 54.00
}
```

### Payload: read an order (`GET /api/orders/{orderNo}`)

The stored order, as the storefront returns it:

```json
{
  "id": "DG-00001",
  "orderNo": "DG-00001",
  "status": "Despatched",
  "placedAt": "2026-06-11T09:14:00.000Z",
  "currency": "NZD",
  "customer": {
    "name": "Ava Shopper",
    "email": "ava@example.com",
    "phone": "+64 21 555 0101",
    "address": { "line1": "12 Queen Street", "line2": "", "city": "Auckland", "postcode": "1010", "country": "NZ" }
  },
  "lines": [
    { "sku": "ESP-250", "name": "Espresso Blend 250g", "quantity": 2, "unitPrice": 18.50 },
    { "sku": "FIL-250", "name": "Filter Blend 250g",   "quantity": 1, "unitPrice": 17.00 }
  ],
  "totalAmount": 54.00,
  "bcOrderNo": "S-ORD101001",
  "submittedAt": "2026-06-11T09:14:02.000Z",
  "despatchedAt": "2026-06-11T15:02:00Z"
}
```
An unknown `orderNo` returns `404`. Before despatch, `bcOrderNo` and `despatchedAt`
are `null`.

### Payload: the status update the Webstore accepts

```
PATCH https://swa-harbour-demo.azurestaticapps.net/api/orders/DG-00001/status
x-api-key: {WEBSITE_STATUS_KEY}
x-correlation-id: DG-00001
Content-Type: application/json
```
```json
{ "status": "Despatched", "bcOrderNo": "S-ORD101001", "despatchedAt": "2026-06-11T15:02:00Z" }
```
Response `200`: `{ "orderNo": "DG-00001", "status": "Despatched", "transitioned": true }`.
Re-sending `Despatched` returns `"transitioned": false` and changes nothing.

## Integration endpoints and payloads: WMS (already built)

The WMS is a third-party warehouse system with a REST API. Its base URL is the
vendor's (`WMS_BASE_URL`). The integration layer calls it to request fulfilment; the
WMS calls back with shipment confirmations. BC never calls the WMS directly.

### Authentication

- **To the WMS:** API key in header `Authorization: ApiKey {WMS_API_KEY}` (or the
  vendor's scheme / OAuth2), held in the secret store.
- **From the WMS:** shipment confirmations carry `Idempotency-Key: {orderNo}` and
  `x-correlation-id: {orderNo}`.

### Endpoints

| Direction | Method + URL | Purpose |
|---|---|---|
| To WMS | `POST {WMS_BASE_URL}/api/v2/fulfilments` | request a pick, pack, and ship |
| To WMS | `GET {WMS_BASE_URL}/api/v2/fulfilments/{wmsRef}` | optional status poll |
| From WMS | the WMS emits a shipment confirmation (delivered to the integration layer) | report carrier, tracking, shipped quantities |

### Payload: the fulfilment request the WMS accepts

```
POST {WMS_BASE_URL}/api/v2/fulfilments
Authorization: ApiKey {WMS_API_KEY}
Idempotency-Key: DG-00001
x-correlation-id: DG-00001
Content-Type: application/json
```
```json
{
  "reference": "DG-00001",
  "bcOrderNo": "S-ORD101001",
  "shipTo": { "name": "Ava Shopper", "line1": "12 Queen Street", "city": "Auckland", "postcode": "1010", "country": "NZ", "phone": "+64 21 555 0101" },
  "lines": [ { "sku": "ESP-250", "quantity": 2 }, { "sku": "FIL-250", "quantity": 1 } ],
  "shippingMethod": "Standard",
  "requestedAt": "2026-06-11T10:30:00Z"
}
```
Response `201`: `{ "wmsRef": "FUL-558821", "reference": "DG-00001", "status": "Accepted" }`.
A repeat with the same `Idempotency-Key` returns the existing fulfilment.

### Payload: the shipment confirmation the WMS emits

```json
{
  "wmsRef": "FUL-558821",
  "reference": "DG-00001",
  "bcOrderNo": "S-ORD101001",
  "shipmentId": "SHP-99001",
  "shippedAt": "2026-06-11T14:58:00Z",
  "carrier": "NZ Post",
  "trackingNumber": "NZ123456789",
  "lines": [ { "sku": "ESP-250", "shippedQuantity": 2 }, { "sku": "FIL-250", "shippedQuantity": 1 } ]
}
```
`reference` is the storefront order number (the correlation id). `shipmentId` lets the
extension post each shipment once. A short-shipped line posts a partial shipment and
leaves the rest open.

## Integration endpoints: the integration layer (to build)

The two sections above are fixed inputs. This one is a deliverable. It is in the brief
rather than left to the technical design because the Webstore and the WMS both have to
be pointed at these addresses, which makes them a commitment to somebody else's system
rather than an internal choice we can revisit quietly.

### Endpoints the layer exposes

| Method + URL | Caller | Auth | Answers |
|---|---|---|---|
| `POST /api/webstore/orders` | the Webstore, forwarding a placed order | `x-api-key`, the ingest key | `202` once queued, `401` on a bad key, `400` with no `orderNo` |
| `POST /api/wms/shipments` | the WMS, confirming a shipment | `x-api-key`, the WMS callback key | `202` once queued, `401` on a bad key, `400` with no `shipmentId` |
| `POST /api/bc/events` | Business Central, delivering an outbound event | the event subscription's own registration handshake | `200` once routed |

A `202` means the message is on a durable queue, and nothing more. It does not mean BC
has accepted it, and no caller is ever held waiting while BC posts.

### Calls the layer makes

| Call | To | Carries |
|---|---|---|
| `POST {WMS_BASE_URL}/api/v2/fulfilments` | the WMS | the WMS API key, the idempotency key, the correlation id |
| `PATCH {WEBSTORE}/api/orders/{orderNo}/status` | the Webstore | the Webstore status key, the correlation id |
| stage an inbound message | BC's own inbound endpoint | the layer's own managed identity, the idempotency key |

Four credentials, and the layer holds all four: the two keys its callers present to it,
and the two keys it presents to the Webstore and the WMS. Each direction has its own
key, so rotating one does not take the other down. BC holds none of them.

### What the layer is made of

Deliverables, not design. How they are arranged, and which Azure services carry them,
is the technical design's business.

- A receiver for each inbound caller, and a sender for each outbound call.
- A durable queue per flow, so one slow or stuck external system cannot block another,
  and so nothing accepted is lost before it reaches BC.
- A secret store holding the four credentials, reached by managed identity rather than
  by a key of its own.
- Telemetry on every step, keyed by the correlation id, with no payload bodies and no
  personal data in it.
- A scheduled check that BC can still reach the layer, because the subscription that
  carries the outbound events expires and is removed silently.
- Infrastructure as code for all of the above, so an environment can be rebuilt from
  this repository with no manual step.

## What the integration layer must do

These are the behaviours the plane is accountable for. They are requirements, not
design: how they are met is settled in the technical design.

1. **Accept and acknowledge fast.** A receiver answers the Webstore or the WMS within
   its timeout, with a 2xx for accepted work, and does no BC work inline. An upstream
   caller must never wait on BC posting.
2. **Never lose an accepted message.** Once a receiver has acknowledged, the message is
   on a durable queue. A crash between acknowledging and staging is not allowed to lose
   it.
3. **Stage into BC, do not post into BC.** The plane writes the message into the
   extension's single inbound endpoint and stops there. It does not create Sales
   Orders, post shipments, or run any BC business logic itself.
4. **Carry the idempotency key, never strip it.** The Webstore order number and the WMS
   shipment id travel with the message into BC, and the BC message id travels back out
   on every call to the Webstore and the WMS, so both ends can dedup.
5. **Dedup on its own side too.** A duplicate delivery to a receiver, or a redelivery
   from a queue, produces no second call and no second staged message.
6. **Carry the correlation id on every hop.** Read it from the inbound message, set it
   on the queue message, set it on every outbound HTTP header, log it at every step.
7. **Retry transient failures, and only transient ones.** Timeouts, 408, 429, and 5xx
   are retried with backoff, by configured policy rather than a hand-written loop.
   A 4xx is a permanent failure: it is not retried, it is dead-lettered and alerted.
8. **Dead-letter what it cannot deliver,** with a defined maximum delivery count, so a
   stuck message is visible and replayable rather than silently dropped.
9. **Hold the credentials, and only in the secret store.** No key in source, in a
   parameter file, or in a plain application setting.
10. **Be observable.** Every step logs to Application Insights with the correlation id
    and the message id, with no payload bodies and no personal data in telemetry.
11. **Watch its own BC subscriptions.** BC business event subscriptions expire after
    about three days and are removed silently on a bad response. A scheduled check
    lists them and alerts when an expected one is missing, because nothing else will
    catch it.
12. **Drive the wait when an external system answers later.** If a call returns an
    accepted-plus-status-url rather than a result, the plane polls or waits for the
    callback and writes the outcome back against the same BC message. It never holds a
    synchronous connection open waiting.

## Success measures

- A Webstore order appears in BC as a Sales Order automatically, mapped to the right
  items and customer.
- Releasing the order sends exactly one fulfilment request to the WMS.
- A WMS shipment confirmation posts the BC shipment once, records tracking, and sets
  the storefront order to shipped with the BC order number.
- Re-delivering any external message, or re-running any outbound action, produces no
  duplicate order, document, shipment, status change, or notification.
- A new integration can be added reusing the same inbound and outbound paths and the
  built-in idempotency, correlation, retry, and error handling.
- BC holds no Webstore or WMS credential, and the extension contains no outbound HTTP
  call, because the plane makes every one of them.
- Taking the WMS offline does not stop a shopper ordering, does not stop BC posting
  anything already confirmed, and loses nothing: the fulfilment requests queue, retry,
  and dead-letter where they cannot be delivered.
- One correlation id, searched once in Application Insights, returns every hop of an
  order across the storefront, the plane, and BC.
- Every Azure resource the solution uses can be recreated from this repository into an
  empty resource group, with no portal step.