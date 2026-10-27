# Feature Plan: Inbound Receivers and Staging

> Two receivers and two stagers, on the foundation from `009`.

- **Feature id:** 010-inbound-receivers-and-staging
- **Spec:** ./spec.md
- **Status:** in-progress

## Approach

Both inbound flows are the same four lines of logic over different adapters, so the
receivers share one helper that does the work (authenticate, find the business key,
build the envelope, enqueue, answer) and differ only in their key name, their secret,
and their queue. The same for the stagers, which differ only in their `messageType`.

Resisting a per-flow copy here is the whole point: the moment the second inbound
system is a copy of the first, the third is a copy of the second, and the shared
behaviour drifts. If adding a third inbound system is not a handful of lines, this
feature has failed even if its tests pass.

**Decision: the plane validates the business key and nothing else.** It is tempting to
check the payload against a schema at the edge and reject early. That puts BC's rules
in two places and guarantees they diverge, and the plane would then reject a payload BC
would have accepted. The business key is the exception because without it the message
cannot be deduplicated anywhere, by anyone.

## Standard Azure services reused

| Service | How |
|---|---|
| Functions HTTP trigger | Both receivers. Anonymous at the platform level, authenticated in code against the Key Vault value, because the caller's scheme is a shared key in a header. |
| Functions Service Bus trigger | Both stagers. The host manages the lock, the delivery count, and the dead-letter move. |
| Service Bus duplicate detection | A redelivered or double-posted order with the same `MessageId` is discarded by the broker. |
| Service Bus dead-letter | Where a permanent failure lands, with a reason set by the function. |

## AL objects to add or extend

None. This feature is Azure-only. It consumes the API page from `001` and the handlers
from `004` and `006` without changing either.

## Azure components to add or change

| Component | Kind | Where | New/Change | Purpose |
|---|---|---|---|---|
| `receiveWebstoreOrder.ts` | function (HTTP) | `integration-plane/src/functions/` | new | The storefront's ingest endpoint. |
| `receiveWmsShipment.ts` | function (HTTP) | `integration-plane/src/functions/` | new | The WMS confirmation callback endpoint. |
| `stageWebstoreOrder.ts` | function (Service Bus) | `integration-plane/src/functions/` | new | Stage a queued order into BC. |
| `stageWmsShipment.ts` | function (Service Bus) | `integration-plane/src/functions/` | new | Stage a queued confirmation into BC. |
| `receiver.ts` | shared | `integration-plane/src/shared/` | new | The one receiver implementation both HTTP functions configure. |
| `stager.ts` | shared | `integration-plane/src/shared/` | new | The one stager implementation both queue functions configure, over `queueStep.ts` from `009`. |

Plane requirements from `brief.md` satisfied here: 1 (accept and acknowledge fast),
3 (stage, do not post), 4 (carry the idempotency key), 5 (dedup on the plane's own
side). Requirements 2, 6, 7, 8, 9, and 10 come from `009` and are inherited.

## Data model

None. The envelope and the inbound envelope are both pinned in
`specs/contracts/integration-contract.md`.

## Integration points

| Hop | Receives | Acknowledges | Queue | Delivers | On duplicate | On transient | On permanent |
|---|---|---|---|---|---|---|---|
| Webstore order | `POST /api/webstore/orders`, `x-api-key` | `202` before any BC call | `inbound-webstore-order` | `POST` to the BC API page | broker discards inside the window; BC answers `409` beyond it, which is success | rethrow, broker redelivers | dead-letter with a reason |
| WMS confirmation | `POST /api/wms/shipments`, `x-api-key` | `202` before any BC call | `inbound-wms-shipment` | `POST` to the BC API page | the same | the same | the same |

## Cross-cutting

- **Permissions:** no new role assignment. The identity from `009` already has Service
  Bus Data Sender, Data Receiver, and Key Vault Secrets User.
- **Telemetry:** the six events in the spec, through `telemetry.ts`. A receiver logs
  the business key, never the body.
- **Performance:** a receiver does one vault-backed setting read (cached by the host
  as an app setting) and one queue send. Nothing else is on the request path.
- **Privacy:** the Webstore payload carries a shopper's name, email, phone, and
  address. It rides in the envelope and into BC, and it never reaches a log.

## Risks and decisions

| Risk or decision | Position |
|---|---|
| Shared-key auth at the edge | Not our choice: the storefront and the WMS offer nothing better. Mitigated by keeping the keys in Key Vault and comparing in constant time. |
| One receiver helper for both systems | Deliberate. Two copies would drift. The configuration per flow is three values. |
| A `202` suggests more than it means | It means queued, not accepted by BC. Documented in the contract, and the Integration Message list is where acceptance is visible. |
| BC `409` treated as success | Correct, and worth stating: BC deduplicated, which is what it was asked to do. Treating it as a failure would dead-letter every legitimate redelivery. |

## Test strategy

| Acceptance criterion | Test |
|---|---|
| `202` on a valid order | `receiver` with a stubbed sender, asserting the status and the sent message. |
| `401` on a bad key | The same, asserting nothing was sent. |
| `400` with no business key | The same. |
| One message on a double post | `MessageId` is identical for both, which is what the broker deduplicates on. |
| Correlation derived | No header, and the envelope's correlation id is the order number. |
| Envelope shape into BC | `stager` with a stubbed BC client, asserting `messageType`, `externalReference`, and a verbatim payload. |
| `409` completes | `stager` over a duplicate response, asserting no throw and no dead-letter. |
| `503` rethrows | `stager`, asserting it throws. |
| `400` dead-letters | `stager`, asserting the dead-letter call and no throw. |
| WMS keys and correlation | `receiveWmsShipment` over a confirmation, asserting the key is `shipmentId` and the correlation id is `reference`. |
| Nothing called on the request path | The receiver tests pass no BC client at all, so a call would fail the test by construction. |

`azure-integration-validator` runs on this feature. The rules it is directly
accountable for are `az-receiver-stages-to-bc`, `az-receiver-acknowledges-fast`,
`az-forward-idempotency-key`, `az-idempotent-receiver`, and
`az-classify-transient-vs-permanent`.
