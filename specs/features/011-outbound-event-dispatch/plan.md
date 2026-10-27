# Feature Plan: Outbound Event Dispatch

> One event endpoint, two senders, and the read-back that makes the fulfilment DTO
> reachable.

- **Feature id:** 011-outbound-event-dispatch
- **Spec:** ./spec.md
- **Status:** in-progress

## Approach

`receiveBusinessEvent` is a router and nothing more: validate, look the event name up
in a table, enqueue, answer. Keeping the routing table as data rather than a `switch`
means adding an event in BC is adding a row, and an unknown name is an entry that is
not there yet rather than a crash.

The two senders are the mirror of the two stagers in `010`: one shared sender
implementation, configured per flow with its secret, its URL, its body builder, and
its idempotency header. The only asymmetry is that `sendWmsFulfilment` reads from BC
first, because the DTO is not on the event.

**Decision: the read-back is a read, not a rebuild.** The alternative to reading the
staged outbound message is for the plane to assemble the fulfilment request from BC's
Sales Order and the SKU mapping. That is a second implementation of `005`'s logic, in
another language, that would silently diverge the first time either changed. The read
is one extra call on a path that is already asynchronous.

**Decision: an unknown event name is a `200`, not a `400`.** BC delivers events on a
subscription, and a delivery that errors counts against the subscription's health; on
repeated failures BC removes it silently. Rejecting an event this plane does not know
would therefore risk the subscription that carries the events it does know. It is
acknowledged, logged, and dropped.

## Standard Azure services reused

| Service | How |
|---|---|
| Functions HTTP trigger | The event endpoint. Answers the validation handshake and routes. |
| Functions Service Bus trigger | Both senders. The host owns the lock, the delivery count, and the dead-letter move. |
| Service Bus duplicate detection | A redelivered event with the same `MessageId` is discarded inside the window. |
| Service Bus dead-letter | Where a permanent dispatch failure lands, with a reason. |

## AL objects to add or extend

None. This feature consumes the events from `005` and `007` and the API page from
`001` without changing any of them.

## Azure components to add or change

| Component | Kind | Where | New/Change | Purpose |
|---|---|---|---|---|
| `receiveBusinessEvent.ts` | function (HTTP) | `integration-plane/src/functions/` | new | BC's delivery endpoint: handshake, route, acknowledge. |
| `sendWmsFulfilment.ts` | function (Service Bus) | `integration-plane/src/functions/` | new | Read the DTO from BC, POST to the WMS, record the `wmsRef`. |
| `sendWebstoreStatus.ts` | function (Service Bus) | `integration-plane/src/functions/` | new | PATCH the storefront to `Despatched`. |
| `sender.ts` | shared | `integration-plane/src/shared/` | new | The one sender implementation both queue functions configure. |
| `eventRoutes.ts` | shared | `integration-plane/src/shared/` | new | The event name to queue table, as data. |
| `bcClient.ts` | shared | `integration-plane/src/shared/` | change | Already carries `readOutboundMessage` and `recordOutboundResult` from `009`; this feature is their first caller. |

Plane requirements from `brief.md` satisfied here: 1 (acknowledge fast, for the event
endpoint), 4 (carry the idempotency key outward), 12 (drive the wait, in the degenerate
case where the WMS answers immediately; a `202` plus status URL would extend the same
sender). Requirement 11 is feature 012.

## Data model

None. Every shape is in `specs/contracts/integration-contract.md`.

## Integration points

| Hop | Receives | Acknowledges | Queue | Delivers | On duplicate | On transient | On permanent |
|---|---|---|---|---|---|---|---|
| Release event | `POST /api/bc/events` from BC | `200` before any call out | `outbound-wms-fulfilment` | `POST` to the WMS with `Idempotency-Key` | WMS returns the existing fulfilment; recorded, completed | rethrow, broker redelivers | dead-letter with a reason |
| Shipment event | the same endpoint | `200` | `outbound-webstore-status` | `PATCH` to the storefront | storefront answers `transitioned: false`; success | the same | the same |

Authentication outward: `Authorization: ApiKey {WMS_API_KEY}` to the WMS,
`x-api-key: {WEBSITE_STATUS_KEY}` to the storefront, both from Key Vault. Inward: BC's
subscription validation at registration, then the registered endpoint's own token.

## Cross-cutting

- **Permissions:** no new role assignment. `009`'s identity already covers the vault,
  the namespace, and BC.
- **Telemetry:** the seven events in the spec, through `telemetry.ts`. The `wmsRef`
  and the BC message id are logged; the DTO body is not.
- **Performance:** `sendWmsFulfilment` makes two calls (read BC, POST WMS) and one
  more to record the result. All three are off the request path.
- **Privacy:** the fulfilment DTO carries the shopper's name, address, and phone. It
  goes to the WMS, which needs it to deliver, and nowhere else. Never to a log.

## Risks and decisions

| Risk or decision | Position |
|---|---|
| The read-back is a single point of failure | Acknowledged. If BC cannot be read, the fulfilment cannot be sent, and the message dead-letters rather than guessing. That is the right failure: a fabricated fulfilment is worse than a late one. |
| The 250-character event argument cap | The reason for the read-back at all. Worth knowing before designing any future event: identifiers ride on the event, bodies ride on a staged message. |
| An unknown event name answered `200` | Deliberate, and the reasoning is in the approach above. The log entry is what makes the dropped event visible. |
| Recording the `wmsRef` is a third call | Accepted. Without it, the request and the later confirmation are joined only by the correlation id, and operations loses the WMS's own reference. |

## Test strategy

| Acceptance criterion | Test |
|---|---|
| Validation handshake | `receiveBusinessEvent` over a handshake request, asserting the echo and that nothing was sent. |
| Release routes | The event name maps to `outbound-wms-fulfilment` with the reference as the business key. |
| Shipment routes | The event name maps to `outbound-webstore-status`. |
| Unknown event | Answers `200`, sends nothing, logs the name. |
| DTO sent unchanged | `sendWmsFulfilment` with a stubbed BC client and HTTP client, asserting the posted body equals the staged DTO and the headers carry the key and the correlation id. |
| `wmsRef` recorded | The same, asserting `recordOutboundResult` was called with the returned reference. |
| WMS repeat is success | A `409` or an existing fulfilment completes without a second POST. |
| WMS `503` rethrows | Asserting it throws. |
| WMS `422` dead-letters | Asserting the dead-letter call and no throw. |
| Storefront PATCH shape | `sendWebstoreStatus`, asserting the URL, the status, the BC order number, and the timestamp. |
| Repeat despatch is success | `transitioned: false` completes the message. |
| Missing staged message | A `404` from the read dead-letters with a reason. |

`azure-integration-validator` runs on this feature. The rules it is directly
accountable for are `az-forward-idempotency-key`, `az-idempotent-receiver`,
`az-correlation-header`, `az-classify-transient-vs-permanent`, `az-retry-in-plane`,
and `az-202-status-poll` (applicable but not violated: the WMS answers synchronously
today, and the sender is the place a status poll would go if it stops doing so).
