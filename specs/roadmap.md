# Roadmap

> Constitution document. The ordered feature list with status. `/al-spec-feature`
> picks the next feature; `/al-implement-feature` ticks it off when merged.
>
> Status legend: `todo` | `spec` (spec written) | `planned` (plan + tasks ready)
> | `in-progress` | `done` | `parked`.

## Solution: Integration Foundation

A reusable Business Central integration extension. One shared inbound/outbound
mechanism with idempotency, correlation, retry, and error handling, proving the
pattern with a Webstore and a WMS as the first two modules.

## Order of delivery

1. `001-core-messaging` Integration Message table, Type enum, interface,
   processing codeunit, API page, retry via Job Queue. The shared backbone
   everything else builds on. Status: `todo`.

2. `002-webstore-order-ingest` Webstore module: parse inbound order JSON, create
   Sales Order, SKU-to-Item mapping, Webstore Setup, idempotency on order
   number. Status: `todo`.

3. `003-fulfilment-request` WMS module outbound: subscribe to Sales Order
   release, raise `OnAfterFulfilmentRequested` business event with structured
   payload, WMS Setup. Status: `todo`.

4. `004-shipment-confirmation` WMS module inbound: parse shipment confirmation
   JSON, post Warehouse Shipment (partial or full), record carrier and tracking,
   optional invoice posting. Status: `todo`.

5. `005-webstore-shipment-notify` Webstore module outbound: subscribe to
   shipment posted, raise `OnAfterShipmentPosted` business event with order
   number, BC order number, and despatch timestamp. Status: `todo`.

6. `006-permissions-and-setup` Permission set covering all objects, setup pages
   for Webstore and WMS modules, setup validation. Status: `todo`.

## Parked / later

- Real-time inventory sync to Webstore (non-goal per brief).
- Returns and RMA processing.
- Multi-currency support.
- AppSource submission hardening.

## Done

- (none yet)
