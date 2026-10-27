# Integration Contract: BC-side payload shapes

> Constitution pre-work (roadmap "Pre-work"). Pins the BC-side shapes for the
> single inbound API page payload and each outbound event DTO, mapped to the
> fixed Webstore and WMS payloads in `brief.md`. Doc only, no code. Feature plans
> for 001 (API page), 004/006 (inbound handlers) and 005/007 (outbound events)
> inherit these shapes. This file must stay in lockstep with the brief payloads;
> a change here is a contract change and follows the `_v2` rule for events.

## Principles

- **One inbound endpoint.** The integration layer POSTs every inbound message to
  a single API page over the Integration Message table. The `messageType` field
  routes; there is no per-source endpoint. The API page is keyed on SystemId
  (house rule).
- **The source payload rides in a blob.** The API page never models the Webstore
  or WMS body field-by-field. The whole source JSON is carried verbatim in the
  `Request` blob; the handler for that `Type` parses it. This is what lets a new
  integration reuse the endpoint with no schema change.
- **Stable identifiers only on the envelope.** The envelope carries the routing
  type, the external reference (idempotency key), and the correlation id. Nothing
  else. Bodies and PII live only in the blob, never in telemetry.
- **Outbound is a minimal DTO of identifiers.** Events carry stable identifiers
  the integration layer needs to make its call, never the BC record and never a
  secret. A contract change is a new `_v2` procedure, never a mutated signature.

## Inbound envelope (the API page payload)

The integration layer POSTs this to the inbound API page. The API page is over
the Integration Message table; these are the writable fields it exposes.

```json
{
  "messageType": "WebstoreOrder",
  "externalReference": "DG-00001",
  "correlationId": "DG-00001",
  "payload": "<source system JSON as a string>"
}
```

| Envelope field | BC field | Notes |
|---|---|---|
| `messageType` | `Type` (enum, stable code) | `WebstoreOrder` or `WmsShipmentConfirmation`. Routes to the handler. Rejected if not a known value. |
| `externalReference` | `External Reference` | The source's stable id. Drives inbound dedup on `(External Reference, Type)`. |
| `correlationId` | `Correlation ID` | The Webstore `orderNo` end to end. If omitted, BC sets it from `externalReference`. |
| `payload` | `Request` (Blob) | The verbatim source body (escaped JSON string). Parsed by the handler, never by the API page. |

On insert the API page forces `Direction = Inbound` and `Status = New`; the
client cannot set them. `Message ID` (Guid PK) is assigned by BC. A POST whose
`(externalReference, messageType)` already exists returns the existing row (the
prior `Message ID` and `Status`) and stages nothing new: re-delivery is a no-op.

### Inbound payload bodies (parsed by the handler, not the envelope)

These are the verbatim bodies the integration layer puts in `payload`, lifted
unchanged from `brief.md`. They are the handler's input, documented here so the
handler specs (004, 006) can pin field access.

**`WebstoreOrder`** (brief "the order the Webstore emits"):

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

- `orderNo` is the `externalReference` and the `correlationId`.
- Each `lines[].sku` maps to a BC item through feature 003. An unmapped SKU fails
  the message Permanent with a clear error; the handler stages nothing partial.
- `customer` rides on the Sales Order ship-to (open question 3 resolved: one
  shared Webstore customer, shopper detail on the ship-to address).

**`WmsShipmentConfirmation`** (brief "the shipment confirmation the WMS emits"):

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

- `reference` is the `correlationId`; it links the confirmation back to the
  fulfilment request by `Correlation ID`.
- `shipmentId` is the `externalReference` and the idempotency key: a re-sent
  confirmation posts no second shipment.
- `bcOrderNo` is the BC Sales Order the shipment posts against.
- Each `lines[].shippedQuantity` drives standard `Qty. to Ship`; a short-shipped
  line posts a partial shipment and leaves the rest open.

## Outbound event DTOs

BC raises these as `[ExternalBusinessEvent]`. Delivery is async, post-commit, and
platform-retried. The integration layer subscribes and makes the actual call. BC
makes no HTTP call.

### `OnSalesOrderReleased_v1` (feature 005, maps to the WMS fulfilment request)

Fired from the thin sales-release subscriber. The external business event itself
carries only the stable identifiers (`reference`, `bcOrderNo`, `correlationId`),
because `[ExternalBusinessEvent]` arguments are capped at 250 characters and a
multi-line order exceeds that. The full fulfilment DTO below is stored on the
**staged outbound Integration Message** (keyed on the same `reference`); the
integration layer reads it from there and POSTs it to the WMS. The DTO is exactly
what `POST /api/v2/fulfilments` needs (brief "the fulfilment request the WMS
accepts").

```json
{
  "reference": "DG-00001",
  "bcOrderNo": "S-ORD101001",
  "correlationId": "DG-00001",
  "shipTo": { "name": "Ava Shopper", "line1": "12 Queen Street", "city": "Auckland", "postcode": "1010", "country": "NZ", "phone": "+64 21 555 0101" },
  "lines": [ { "sku": "ESP-250", "quantity": 2 }, { "sku": "FIL-250", "quantity": 1 } ],
  "shippingMethod": "Standard",
  "requestedAt": "2026-06-11T10:30:00Z"
}
```

- `reference` / `correlationId` are the Webstore `orderNo` (carried on the Sales
  Order as the external document / correlation anchor).
- `lines[].sku` is the source SKU, reverse-mapped from the BC item through 003 so
  the WMS receives its own catalogue keys.
- The integration layer uses `reference` as the `Idempotency-Key` on the WMS call.

### `OnShipmentConfirmed_v1` (feature 007, maps to the Webstore status update)

Fired after the warehouse shipment posts. Carries exactly what the Webstore
`PATCH /api/orders/{orderNo}/status` needs (brief "the status update the Webstore
accepts").

```json
{
  "orderNo": "DG-00001",
  "bcOrderNo": "S-ORD101001",
  "correlationId": "DG-00001",
  "despatchedAt": "2026-06-11T15:02:00Z"
}
```

- `orderNo` is the storefront order number the integration layer PATCHes.
- The only storefront status the integration sets is `Despatched`; the event does
  not carry a status field because the transition is fixed.
- Carrier and tracking are recorded in BC but not sent: the storefront order has
  no carrier/tracking fields today (brief). A future `_v2` can add them if the
  storefront gains the fields.

## Idempotency and correlation summary

| Flow | Idempotency key | Correlation id |
|---|---|---|
| Inbound WebstoreOrder | `(orderNo, WebstoreOrder)` | `orderNo` |
| Inbound WmsShipmentConfirmation | `(shipmentId, WmsShipmentConfirmation)` | `reference` (= `orderNo`) |
| Outbound fulfilment request | `reference` (= `orderNo`), set by integration layer | `orderNo` |
| Outbound despatch notify | storefront PATCH is idempotent (`transitioned:false` on repeat) | `orderNo` |

## Plane-side contract: what the integration layer exposes and sends

The sections above pin the BC side. This section pins the plane side, so both halves
of every hop are in one file. The plane is specified in `tech-design.md` under "Azure
integration layer" and built under `infra/` and `integration-plane/`.

### Endpoints the plane exposes

| Endpoint | Caller | Auth | Answers |
|---|---|---|---|
| `POST /api/webstore/orders` | the storefront, forwarding a placed order | `x-api-key` = `WEBSHOP_INGEST_KEY` from Key Vault | `202` once queued, `401` on a bad key, `400` with no `orderNo` |
| `POST /api/wms/shipments` | the WMS, confirming a shipment | `x-api-key` = the WMS callback key from Key Vault | `202` once queued, `401` on a bad key, `400` with no `shipmentId` |
| `POST /api/bc/events` | Business Central, delivering an external business event | the subscription's own validation handshake, then the registered endpoint token | `200` once routed, `200` echoing the validation token on a handshake |

Every receiver answers before doing any work beyond validation and enqueueing. None of
them calls BC, the WMS, or the storefront while the caller waits. A `202` means the
message is on a durable queue, nothing more, and in particular it does not mean BC has
accepted it: that is what the Integration Message list is for.

### The queue envelope

Between a receiver and its delivery function, the plane carries this. It is internal,
it is not a public contract, and it exists so that no delivery function has to call
back to the source for anything:

```json
{
  "flow": "webstore-order",
  "businessKey": "DG-00001",
  "correlationId": "DG-00001",
  "source": "webstore",
  "receivedAt": "2026-06-11T09:14:02.000Z",
  "payload": { "...": "the original body, unaltered" }
}
```

The Service Bus `MessageId` is `<flow>:<businessKey>`, so the broker discards an exact
redelivery inside the duplicate detection window. `correlationId` also travels as a
Service Bus application property, so it is readable without deserialising the body.

### What the plane sends to BC

**Staging an inbound message.** The inbound envelope from "Inbound envelope" above,
POSTed to the API page with `Idempotency-Key: <businessKey>`, `x-correlation-id`, and
a bearer token for the Function App's managed identity. A `201` is success. A `409`,
or a `200` returning an existing row, is also success: BC deduplicated, which is what
it was asked to do, and the plane records the returned `Message ID` and stops.

**Reading a staged outbound message.** `OnSalesOrderReleased_v1` carries only
`reference`, `bcOrderNo`, and `correlationId`, because an `[ExternalBusinessEvent]`
argument is capped at 250 characters. The fulfilment DTO lives on the staged outbound
Integration Message. `sendWmsFulfilment` reads it back by `externalReference` before
calling the WMS. This is the only read the plane makes against BC, and it carries no
business logic: the DTO is taken as it stands.

**Recording the result.** After a successful WMS call the plane writes the `wmsRef`
onto the same outbound message, so the request and the later confirmation are joined
in BC by more than the correlation id alone.

### What the plane sends outward

| Call | Headers the plane must set | Source of each value |
|---|---|---|
| `POST {WMS_BASE_URL}/api/v2/fulfilments` | `Authorization: ApiKey {WMS_API_KEY}`, `Idempotency-Key: {reference}`, `x-correlation-id: {correlationId}` | key from Key Vault; reference and correlation id from the event |
| `PATCH {WEBSTORE}/api/orders/{orderNo}/status` | `x-api-key: {WEBSITE_STATUS_KEY}`, `x-correlation-id: {correlationId}` | key from Key Vault; order number and correlation id from the event |

Bodies are exactly the shapes in `brief.md`: the fulfilment request as the WMS accepts
it, and `{ "status": "Despatched", "bcOrderNo": ..., "despatchedAt": ... }` as the
storefront accepts it. The plane adds no field and drops none.

### Failure classification, which is part of the contract

The same split applies on every hop, in both directions, and it is a contract because
the two sides have to agree on what a retry means:

| Response | Plane behaviour |
|---|---|
| `2xx` | Success. Complete the queue message. |
| `409` from BC on a staging POST | Success. The message already existed; record it and complete. |
| `408`, `429`, `5xx`, timeout, connection failure | Transient. Rethrow, so Service Bus redelivers with backoff until the maximum delivery count. |
| any other `4xx`, or a payload that fails validation | Permanent. Park with a reason and complete. Never retried. |

Retrying a `4xx` forever is the failure that looks like a working integration while
nothing moves, so it is forbidden rather than discouraged.

"Park" rather than "dead-letter" is a deliberate word. The Node worker does not expose
Service Bus message settlement, so a function cannot dead-letter the message it is
holding; it can only complete it or abandon it, and abandoning means retry. A
permanent failure is therefore forwarded to one shared `parked` queue with its reason
and completed. A message that dead-letters by exhausting its delivery count still goes
to its queue's own dead-letter queue. Both are watched by the same alerts and both
keep the original body, so to operations they are one surface: messages that stopped,
with the reason attached.
