# Feature Plan: Integration Plane Foundation

> One Bicep template, one Function App, the pieces every flow reuses.

- **Feature id:** 009-integration-plane-foundation
- **Spec:** ./spec.md
- **Status:** in-progress

## Approach

Provision one resource group of managed services with Bicep, and give the Function App
a system-assigned managed identity that is the only credential in the system.
Everything that makes the plane resilient is a setting on a managed service:
dead-lettering, maximum delivery count, duplicate detection, retry. The custom code is
the small set of helpers every flow needs, and nothing else.

**Open question resolved: the retry budget lives in Service Bus.** Maximum delivery
count is 5, and the Functions host retry policy is set to a single attempt. Two retry
mechanisms multiply: five deliveries times five host retries is twenty-five calls to a
struggling external system, which is how a retry policy turns an outage into an
incident. One budget, in one place, visible as the queue's delivery count.

**Open question resolved: the duplicate detection window is 1 hour.** It covers the
redelivery and double-post cases it exists for. It is deliberately not longer, because
the durable authority on duplicates is BC's dedup on `(External Reference, Type)`,
which never expires. Treating the broker as a long-term dedup store would put business
state in the broker.

**Found in implementation: a permanent failure is parked, not dead-lettered.** The
Node worker does not expose Service Bus message settlement, so a function cannot
dead-letter the message it is holding; it can complete it (return) or abandon it
(throw), and abandoning means retry. Throwing on a 4xx would retry it five times,
which is exactly what `az-classify-transient-vs-permanent` calls a blocker. So the
plane forwards a permanent failure to one shared `parked` queue with its reason and
completes it. Both the parked queue and the dead-letter queues are watched by the
same alerts, so operations sees one surface.

**Open question deferred, deliberately: the BC token audience and the read path.** The
BC client takes the audience, the scope, and the base URL from configuration, so
settling them is a parameter change and not a rewrite. The registration step is written
up in `infra/README.md`. This is the highest-risk item in the feature and it is called
out as such rather than buried.

## Standard Azure services reused

| Service | How |
|---|---|
| Service Bus (Standard) | Four flow queues plus `parked`. Dead-lettering on message expiration, maximum delivery count 5, duplicate detection on a 1 hour window, 5 minute lock duration. No custom queueing, no custom retry. |
| Azure Functions (Node 20, TypeScript, v4 model) | Every receiver, stager, sender, and timer. HTTP and Service Bus triggers, so no polling code anywhere. |
| Key Vault (RBAC authorization) | The four external secrets, reached as Key Vault references from app settings, so the Function App never calls the vault in code. |
| Managed identity (system-assigned) | To Key Vault, Service Bus, and BC. No connection string, no client secret. |
| Application Insights and Log Analytics | Traces and failures, correlation id as a custom dimension. |
| Azure Monitor metric alerts | Dead-letter message count greater than zero, per queue. |
| Workload identity federation | The pipeline's credential. Nothing stored in GitHub but client, tenant, and subscription ids, none of which is a secret. |

## AL objects to add or extend

None. This feature is Azure-only.

## Azure components to add or change

| Component | Kind | Where | New/Change | Purpose |
|---|---|---|---|---|
| `main.bicep` | template | `infra/` | new | Composes every module for one environment. Resource-group scoped. |
| `servicebus.bicep` | module | `infra/modules/` | new | Namespace and the four queues with their dead-letter, delivery count, and duplicate detection settings. |
| `storage.bicep` | module | `infra/modules/` | new | Function App host storage. HTTPS only, TLS 1.2, no public blob access. |
| `keyvault.bicep` | module | `infra/modules/` | new | Vault with RBAC authorization and soft delete. Takes no secret values. |
| `observability.bicep` | module | `infra/modules/` | new | Log Analytics workspace and Application Insights. |
| `functionapp.bicep` | module | `infra/modules/` | new | Consumption plan, Function App with system-assigned identity, app settings with Key Vault references, and three role assignments. |
| `alerts.bicep` | module | `infra/modules/` | new | Action group and the dead-letter alert per queue. |
| `main.dev.bicepparam` | parameters | `infra/` | new | The dev environment's values. No secrets. |
| `infra/README.md` | doc | `infra/` | new | Resource group, federated credential, secret seeding, BC registration. |
| `config.ts` | shared | `integration-plane/src/shared/` | new | Reads and validates every setting, failing with the setting's name. |
| `telemetry.ts` | shared | `integration-plane/src/shared/` | new | The one log shape. No parameter accepts a payload body. |
| `correlation.ts` | shared | `integration-plane/src/shared/` | new | Read, derive, and carry the correlation id. |
| `classify.ts` | shared | `integration-plane/src/shared/` | new | Transient against permanent, from a status or a thrown error. |
| `envelope.ts` | shared | `integration-plane/src/shared/` | new | The queue envelope and the `MessageId` rule. |
| `bcClient.ts` | shared | `integration-plane/src/shared/` | new | Token through managed identity; stage a message, read a staged outbound message, record a result. |
| `serviceBus.ts` | shared | `integration-plane/src/shared/` | new | Sending through the SDK (so `messageId` and the correlation property can be set, which an output binding cannot do), and parking. |
| `queueStep.ts` | shared | `integration-plane/src/shared/` | new | What every queue-triggered function does around its one call out: rethrow a transient failure, park a permanent one. |
| `host.json` | config | `integration-plane/` | new | Service Bus extension settings and the single-attempt host retry policy. |
| `DeployIntegrationPlane.yaml` | workflow | `.github/workflows/` | new | Federated login, Bicep deployment, Function App publish. Path-filtered. |

Plane requirements from `brief.md` satisfied here: 2 (never lose an accepted message),
6 (correlation on every hop), 7 (retry transient only), 8 (dead-letter), 9 (secrets in
the store), 10 (observable). Requirements 1, 3, 4, 5, 11, and 12 are satisfied by the
flows in features 010, 011, and 012, on top of what this one provides.

## Data model

None persistent. The queue envelope exists in memory and on a queue, and its shape is
pinned in `specs/contracts/integration-contract.md`.

## Integration points

No flow in this feature. The authentication paths it establishes, which every flow
then uses:

| Path | Credential |
|---|---|
| External caller to the plane | A shared key per system, compared against the Key Vault value. The storefront and the WMS offer nothing better. |
| Plane to BC | The Function App's managed identity, registered in BC as an Entra application with the extension's permission set. |
| Plane to Key Vault and Service Bus | The same managed identity, through RBAC role assignments in the template, each scoped to the one resource it needs. |
| Pipeline to Azure | Workload identity federation. No stored secret. |

## Cross-cutting

- **Secrets:** four Key Vault secrets (`webstore-ingest-key`, `webstore-status-key`,
  `wms-api-key`, `wms-callback-key`), seeded out of band. The template creates the
  vault, not the values.
- **Telemetry:** every helper logs through `telemetry.ts` so dimension names are
  identical everywhere. A log call that takes a payload body is a review failure.
- **Permissions:** Key Vault Secrets User on the vault, Service Bus Data Sender and
  Data Receiver on the namespace. Never at subscription scope.
- **Performance:** Consumption cold start is acceptable because nothing synchronous
  waits on the plane. Revisit only if a receiver starts timing out its caller.
- **Cost:** Service Bus Standard is the only fixed monthly charge. Everything else is
  consumption-priced and an idle environment is close to free.

## Risks and decisions

| Risk or decision | Position |
|---|---|
| Service Bus Standard is a fixed cost, Basic is cheaper | Basic has no duplicate detection. Duplicate detection is load-bearing here, so Standard. |
| Duplicate detection is immutable after creation | Accepted, and the reason the window is settled here rather than by the first flow. Changing it later means recreating the queue. |
| Consumption cold start | Accepted. Nothing synchronous waits on the plane. |
| Managed identity to BC is unproven in this repo | The highest-risk item. Audience and scope are configuration, so a wrong assumption costs a parameter. Prove it before feature 010 depends on it. |
| One Function App for every flow | Accepted at this size. Per-flow queues already stop one stuck system blocking another, though they do share a plan. Split when a real noisy neighbour appears. |

## Test strategy

Vitest over everything that is pure logic, which is where the rules live and needs no
Azure:

| Acceptance criterion | Test |
|---|---|
| Transient classification | `classify` over 408, 429, 500, 502, 503, 504, and a thrown timeout. |
| Permanent classification | `classify` over 400, 401, 403, 404, 422. |
| BC `409` is success | `bcClient.stageMessage` returns success with the existing id. |
| BC `5xx` is transient, `4xx` is permanent | `bcClient.stageMessage` over both. |
| Correlation carried | `correlation` reads the header; envelope and log entry both carry it. |
| Correlation derived | With no header, the business key becomes the correlation id. |
| Envelope and `MessageId` | `<flow>:<businessKey>`, and a missing business key throws. |
| Configuration failure | A missing setting throws naming the setting. |

The infrastructure criteria (resources exist, no secret in the template, dead-letter
and alert behaviour) are verified by deploying into an empty resource group and by
`azure-integration-validator` reading the template, not by a unit test.

`azure-integration-validator` is part of this feature's definition of done. The rules
it is directly accountable for here are `az-retry-in-plane`,
`az-dead-letter-configured`, `az-classify-transient-vs-permanent`,
`az-correlation-header`, `az-observability-wired`, `az-secrets-in-keyvault`,
`az-managed-identity`, and `az-https-only`.
