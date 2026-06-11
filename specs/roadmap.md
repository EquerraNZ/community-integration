# Roadmap

> Constitution document. The ordered feature list with status. `/al-spec-feature`
> picks the next feature; `/al-implement-feature` ticks it off when merged.
>
> Status legend: `todo` | `spec` (spec written) | `planned` (plan + tasks ready)
> | `in-progress` | `done` | `parked`.

## Solution: Integration Foundation

One reusable BC integration extension: a single inbound path and a single
outbound path, with idempotency, correlation, retry, error handling, and manual
resolution built in once and reused by every integration. The Webstore and WMS
integrations are the first two modules on it, proving the pattern.

## Pre-work (not a feature folder)

Before feature 001, author `specs/contracts/integration-contract.md`: the
BC-side shapes for the single inbound API page payload and each outbound event
DTO, mapped to the fixed Webstore and WMS payloads in the brief. Doc only, no
code, no `features/` folder. Must land before 004, whose handler spec depends on
the pinned payload shape. Status: `done` (see `specs/contracts/integration-contract.md`).

## Order of delivery

The core ships first because every other feature depends on it. Then the two
integrations are built as thin modules, one business process per feature, so each
proves a different arrow of the shared mechanism. The numbering maps one-to-one
with `features/<NNN-slug>/` folders.

1. `001-integration-message-core` The spine. Integration Message table, the
   Direction / Status / Error Class enums, the extensible Message Type enum with
   the `IIntegrationMessageHandler` interface, the Integration Message management
   codeunit (staging, dedup on `External Reference + Type`, Correlation ID
   propagation, retry state), the Job Queue dispatcher that routes `New` messages
   by `Type`, the Setup table and page, telemetry, and the permission set. No
   integration-specific logic. Status: `in-progress` (spec/plan/tasks + production AL
   complete; test app and CI build pending).

2. `002-message-list-and-resolution` The operational UI: the Integration Message
   list, the resolution card, and the manual-intervention actions (Resolve,
   Confirm-by-Exception, Reassign) over failed messages. Status: `in-progress`
   (spec/plan/tasks + production AL complete; tests + CI pending).

3. `003-sku-item-mapping` The SKU to Item No. mapping table, page, and lookup,
   with a clear failure on an unmapped SKU. Shared by every integration that maps
   catalogue lines to BC items. Status: `in-progress`
   (spec/plan/tasks + production AL complete; tests + CI pending).

4. `004-webstore-order-ingest` Inbound, business process 1. The `WebstoreOrder`
   message type and its handler: create a standard Sales Order on the dedicated
   Webstore customer, map each SKU through `003`, set the order number as the
   correlation id. Idempotency on the Webstore `orderNo`: a re-delivered order
   creates no second Sales Order. Status: `in-progress`
   (spec/plan/tasks + production AL complete; tests + CI pending).

5. `005-fulfilment-request-event` Outbound, business process 2. The
   `OnSalesOrderReleased_v1` external business event and the thin sales-release
   subscriber that fires it with a stable fulfilment DTO. Optionally stage an
   Outbound request message as the correlation parent. The integration layer
   consumes the event and calls the WMS; BC makes no call. Status: `in-progress`
   (spec/plan/tasks + production AL complete; tests + CI pending).

6. `006-wms-shipment-confirmation` Inbound and long-running, business process 3.
   The `WmsShipmentConfirmation` message type and its handler: post the warehouse
   shipment (and the invoice if configured), record carrier and tracking, handle
   partial and short-shipped lines through standard `Qty. to Ship`. Idempotency on
   the WMS `shipmentId`: a re-sent confirmation posts no second shipment. Links
   back to the fulfilment request by Correlation ID. Status: `in-progress`
   (spec/plan/tasks + production AL complete; tests + CI pending).

7. `007-webstore-despatch-notify` Outbound, business process 4. The
   `OnShipmentConfirmed_v1` external business event fired after the shipment
   posts, carrying the BC order number and despatch timestamp. The integration
   layer sets the Webstore order to `Despatched`. Idempotent: a re-fire changes
   nothing on the storefront. Status: `in-progress`
   (spec/plan/tasks + production AL complete; tests + CI pending).

8. `008-subscription-health-monitor` The Job Queue monitor that lists external
   event subscriptions periodically and alerts when an expected one is missing
   (the platform removes a subscription silently with no built-in alert). Status:
   `in-progress` (spec/plan/tasks + production AL complete; tests + CI pending).

## Parked / later

These are future modules that plug into the same inbound and outbound paths with
no change to the core. They prove the reusability goal but are out of scope for
this build (see the brief non-goals).

- Real-time inventory sync to the Webstore.
- Returns / RMAs and back-order automation.
- A finance portal integration.
- A marketplace integration.
- A carrier API integration.
- Multi-warehouse routing.
- Integration Message retention / archive policy (open technical question 4).

## Done

- (none yet)
