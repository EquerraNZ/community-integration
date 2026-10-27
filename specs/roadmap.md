# Roadmap

> Constitution document. The ordered feature list with status. `/al-spec-feature`
> picks the next feature; `/al-implement-feature` ticks it off when merged.
>
> Status legend: `todo` | `spec` (spec written) | `planned` (plan + tasks ready)
> | `in-progress` | `done` | `parked`.

## Solution: Integration Foundation

A reusable Business Central integration extension, and the Azure integration layer
that carries every message to and from it. One shared inbound and outbound mechanism
with idempotency, correlation, retry, and error handling, proving the pattern with a
Webstore and a WMS as the first two modules.

Each feature below is marked `BC` or `Azure`. Features are ordered so that both halves
of a flow land next to each other: the BC half of a flow is built first because it
defines the contract, then the Azure half that feeds or consumes it. A flow is only
demonstrable when both have landed.

## Order of delivery

1. `001-core-messaging` **BC.** Integration Message table, Type enum, interface,
   processing codeunit, API page, retry via Job Queue. The shared backbone
   everything else builds on. Status: `planned`.

2. `002-integration-plane-foundation` **Azure.** The shared plane: the Bicep that
   provisions the resource group's Service Bus namespace with its four queues and
   dead-lettering, Key Vault, Application Insights, storage, and the Function App
   with its managed identity; the shared BC client, correlation handling, and
   transient-against-permanent classification; and the deployment workflow. No flow
   yet, the same way 001 carries no integration. Status: `planned`.

3. `003-webstore-order-ingest` **BC.** Webstore module: parse inbound order JSON,
   create Sales Order, SKU-to-Item mapping, Webstore Setup page and table,
   idempotency on order number. Status: `todo`.

4. `004-webstore-ingest-receiver` **Azure.** `receiveWebstoreOrder` and
   `stageWebstoreOrder`: authenticate the storefront, stamp correlation, enqueue on
   `inbound-webstore-order`, return `202`, and stage into the BC API page. Completes
   business process 1 end to end. Status: `todo`.

5. `005-fulfilment-request` **BC.** WMS module outbound: subscribe to Sales Order
   release, raise `OnAfterFulfilmentRequested` business event with structured
   payload, WMS Setup page and table. Status: `todo`.

6. `006-wms-fulfilment-sender` **Azure.** `receiveBusinessEvent` with the
   subscription validation handshake and event routing, plus `sendWmsFulfilment`:
   take the release event off `outbound-wms-fulfilment` and POST the fulfilment
   request to the WMS with its idempotency key. Completes business process 2.
   Status: `todo`.

7. `007-shipment-confirmation` **BC.** WMS module inbound: parse shipment
   confirmation JSON, post Warehouse Shipment (partial or full), record carrier and
   tracking, optional invoice posting. Status: `todo`.

8. `008-wms-callback-receiver` **Azure.** `receiveWmsShipment` and
   `stageWmsShipment`: accept the WMS callback, acknowledge it immediately, and stage
   it into BC keyed on the shipment id. Completes business process 3. Status: `todo`.

9. `009-webstore-shipment-notify` **BC.** Webstore module outbound: subscribe to
   shipment posted, raise `OnAfterShipmentPosted` business event with order number,
   BC order number, and despatch timestamp. Status: `todo`.

10. `010-webstore-status-sender` **Azure.** `sendWebstoreStatus`: take the
    confirmation event off `outbound-webstore-status` and PATCH the storefront order
    to `Despatched`. Completes business process 4, and with it the whole loop.
    Status: `todo`.

11. `011-subscription-health-and-alerting` **Azure.** `checkSubscriptionHealth` on a
    timer, re-registering a missing BC subscription, plus the Azure Monitor alert
    rules on dead-letter depth and on health-check drift. This is what stops an
    integration failing silently. Status: `todo`.

12. `012-permissions-and-polish` **BC.** Permission set covering all objects, setup
    validation (required fields, test connection), telemetry instrumentation review.
    Setup tables and pages are delivered with their module (003, 005); this feature
    hardens them. Status: `todo`.

## Parked / later

- Real-time inventory sync to Webstore (non-goal per brief).
- Returns and RMA processing.
- Multi-currency support.
- AppSource submission hardening.
- Replay of a dead-lettered message from the BC Integration Message list, rather than
  from the Azure portal.
- A second environment (prod) and promotion between the two.

## Done

- (none yet)
