# Project Brief: Business Central Integration Extension

> A self-contained brief for one Business Central extension. It states what the
> extension does and why, and it carries the endpoint and payload detail for the
> already-built external systems it integrates with (a Webstore and a WMS), since
> those are fixed inputs to the build. It does not describe the extension's internal
> design (data model, objects, events); that is worked out in the technical design.
> It references no other file, so it can be copied into any repository.

## What the extension is

A reusable Business Central integration extension. The goal is to build one
integration extension that can handle any integration, current or future, through a
single shared mechanism, so that connecting the next external system is a matter of
adding a small module rather than re-architecting or re-building the plumbing. The
extension provides one inbound path and one outbound path, with idempotency,
correlation, retry, and error handling built in once and reused by every integration.

BC is the system of record for orders, fulfilment, and invoicing. The first two
integrations built on the extension, and the ones this brief specifies, connect BC to
an online Webstore and a third-party Warehouse Management System (WMS): orders placed
on the Webstore become Sales Orders in BC; releasing an order asks the WMS to ship it;
the WMS shipment confirmation posts the shipment in BC; and the Webstore is told when
the order has shipped. Future integrations (a finance portal, a marketplace, a carrier
API, an ERP feed) plug into the same paths without changing the core.

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

## Non-goals

- Payment capture or settlement (taken on the Webstore; BC records the order as
  configured).
- Real-time inventory sync to the Webstore (a candidate future module, not in this
  build).
- Returns, RMAs, multi-warehouse routing, back-order automation.
- Multi-currency (NZD only).
- AppSource submission.

## What the extension does (business processes)

1. **Ingest an order.** The Webstore sends a placed order to the extension. The
   extension creates a standard Sales Order, mapping each catalogue SKU to a BC item
   and using a dedicated Webstore customer. A duplicate of the same order does not
   create a second Sales Order.
2. **Release and request fulfilment.** A staff member reviews and releases the Sales
   Order. Releasing it makes the extension ask the WMS to fulfil the order.
3. **Confirm the shipment.** The WMS confirms the shipment with the carrier,
   tracking, and shipped quantities. The extension posts the warehouse shipment (and
   the invoice if configured) and records the tracking. A re-sent confirmation does
   not post a second shipment.
4. **Notify the Webstore.** Once the shipment is posted, the extension sets the
   Webstore order to shipped, recording the BC order number.

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