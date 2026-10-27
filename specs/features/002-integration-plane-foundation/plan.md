# Feature Plan: Integration Plane Foundation

> The shared Azure plane: one Bicep template, one Function App, the pieces every
> flow reuses. No flow of its own.

- **Feature id:** 002-integration-plane-foundation
- **Spec:** ./spec.md
- **Status:** planned

## Approach

Provision one resource group's worth of managed services with Bicep, and give the
Function App a system-assigned managed identity that is the only credential in the
system. Everything the plane needs to be resilient is a setting on a managed service:
dead-lettering, maximum delivery count, duplicate detection, and retry backoff. The
custom code is the small set of helpers every flow needs, and nothing more.

**Open question resolved: the retry budget lives in Service Bus.** The queue's maximum
delivery count is 5 and the Functions host retry policy is set to a single attempt, so
a failed delivery returns to the broker immediately rather than being retried inside
the function first. Two retry mechanisms multiply: five deliveries times five host
retries is twenty-five calls to a struggling external system, which is how a retry
policy turns an outage into an incident. One budget, in one place, visible in the
queue's delivery count.

**Open question resolved: the duplicate detection window is 1 hour.** It covers the
redelivery and double-post cases it exists for, and it is deliberately not the longer
window it could be, because the durable authority on duplicates is BC's dedup on
`External Reference + Type`, which never expires. Treating Service Bus as the
long-term dedup store would put business state in the broker.

**Open question deferred: BC token audience and registration.** The BC client is built
against the documented service-to-service flow, with the audience and scope read from
configuration rather than hardcoded, so settling the value is a parameter change and
not a code change. The registration step is written up in `infra/README.md` as a
one-off per environment.

## Standard Azure services reused

| Service | How |
|---|---|
| Service Bus (Standard) | Four queues, one per flow. Dead-lettering on, maximum delivery count 5, duplicate detection on a 1 hour window, lock duration 5 minutes. No custom queueing, no custom retry. |
| Azure Functions (Node 20, TypeScript, v4 programming model) | Every receiver, stager, sender, and timer. HTTP and Service Bus triggers, so no polling code. |
| Key Vault | The four external secrets. Referenced from app settings as Key Vault references, so the Function App never calls the vault in code. |
| Managed identity (system-assigned) | The Function App's identity to Key Vault, Service Bus, and BC. No connection string, no client secret. |
| Application Insights and Log Analytics | Traces and failures, with the correlation id as a custom dimension. |
| Azure Monitor metric alerts | Dead-letter message count greater than zero on any queue. |
| Workload identity federation | The pipeline's credential to Azure. Nothing stored in GitHub except the client, tenant, and subscription ids, none of which is a secret. |

## AL objects to add or extend

None. This feature is Azure-only.

## Azure components to add or change

| Component | Kind | Where | New/Change | Purpose |
|---|---|---|---|---|
| `main.bicep` | template | `infra/` | new | Composes every module for one environment. Resource-group scoped. |
| `servicebus.bicep` | module | `infra/modules/` | new | Namespace and the four queues with their dead-letter, delivery count, and duplicate detection settings. |
| `keyvault.bicep` | module | `infra/modules/` | new | Vault with RBAC authorization. Takes no secret values. |
| `storage.bicep` | module | `infra/modules/` | new | Function App host storage, HTTPS only, TLS 1.2 minimum, no public blob access. |
| `observability.bicep` | module | `infra/modules/` | new | Log Analytics workspace and Application Insights. |
| `functionapp.bicep` | module | `infra/modules/` | new | Consumption plan, Function App with system-assigned identity, app settings including Key Vault references, HTTPS only, TLS 1.2 minimum. |
| `alerts.bicep` | module | `infra/modules/` | new | Action group and the dead-letter metric alert per queue. |
| `main.dev.bicepparam` | parameters | `infra/` | new | The dev environment's values. No secrets. |
| `infra/README.md` | doc | `infra/` | new | The one-off steps: resource group, federated credential, secret seeding, BC registration. |
| `config.ts` | shared | `integration-plane/src/shared/` | new | Reads and validates every setting at first use, failing with the setting's name. |
| `correlation.ts` | shared | `integration-plane/src/shared/` | new | Reads, derives, carries, and logs the correlation id. |
| `classify.ts` | shared | `integration-plane/src/shared/` | new | Transient against permanent, from a status code or a thrown error. |
| `envelope.ts` | shared | `integration-plane/src/shared/` | new | The queue envelope and its `MessageId` rule. |
| `bcClient.ts` | shared | `integration-plane/src/shared/` | new | Token through managed identity, POST to the inbound API page, response classification. |
| `telemetry.ts` | shared | `integration-plane/src/shared/` | new | The one logging shape, with correlation and message id dimensions and no payload bodies. |
| `host.json` | config | `integration-plane/` | new | Service Bus extension settings and the single-attempt host retry policy. |
| `DeployIntegrationPlane.yaml` | workflow | `.github/workflows/` | new | Federated login, Bicep deployment, Function App publish. |

## Data model

The plane owns no persistent data. The only shape it defines is the queue envelope in
`envelope.ts`, described in the spec under "Data and rules". It exists in memory and
on a queue, never in a database.

## Integration points

| Hop | Receives | Acknowledges | Queue | Delivers | On duplicate | On transient | On permanent |
|---|---|---|---|---|---|---|---|
| (none in this feature) | | | the four queues exist and are empty | | broker discards inside the window | rethrow, broker redelivers | dead-letter with a reason |

The table is empty by design. This feature builds the road, and features 004, 006,
008, and 010 put traffic on it. The columns are the questions each of those features
has to answer, so they are stated here once.

Authentication, in both directions:

- Inbound to the plane: a shared key in a header, per external system, compared
  against the Key Vault value. The storefront and the WMS offer nothing better.
- Plane to BC: the Function App's managed identity, registered in BC as an Entra
  application and granted the extension's permission set.
- Plane to Azure (Key Vault, Service Bus): the same managed identity, through RBAC
  role assignments in the template.
- Pipeline to Azure: workload identity federation.

## Cross-cutting

- **Secrets:** four Key Vault secrets (`webstore-ingest-key`, `webstore-status-key`,
  `wms-api-key`, `wms-callback-key`), seeded out of band. The template creates the
  vault, not the values. The callback key is the one the WMS must present to the
  plane; the API key is the one the plane presents to the WMS. Two directions, two
  keys, so rotating one does not take the other down.
- **Telemetry:** every helper logs through `telemetry.ts` so the dimension names are
  identical everywhere. A log call that takes a payload body is a review failure.
- **Permissions:** three role assignments in the template, each scoped to the one
  resource it needs, never at subscription scope.
- **Performance:** Consumption plan cold start is acceptable because every caller is
  acknowledged asynchronously and no user waits on it.
- **Cost:** Service Bus Standard is the only fixed monthly charge in the plane. Every
  other resource is consumption-priced and an idle environment is close to free.

## Risks and decisions

| Risk or decision | Position |
|---|---|
| Service Bus Standard is a fixed cost, Basic is cheaper | Basic has no duplicate detection and no topics. Duplicate detection is load-bearing here, so Standard it is. |
| Duplicate detection cannot be changed after creation | Accepted, and the reason the window is settled in this feature rather than left to the first flow. Changing it later means recreating the queue. |
| Consumption plan cold start | Accepted. Nothing synchronous waits on the plane. Revisit only if a receiver starts timing out its caller. |
| Managed identity to BC is unproven in this repo | The highest-risk item in the feature. The BC client's audience and scope are configuration, so a wrong assumption costs a parameter, not a rewrite. Prove it before feature 004 depends on it. |
| One Function App for every flow | Accepted for this size. A noisy flow cannot starve another because each has its own queue, but they do share a plan. Split only when a real noisy neighbour appears. |

## Test strategy

Unit tests with Vitest over everything that is pure logic, because that is where the
rules live and it needs no Azure:

| Acceptance criterion | Test |
|---|---|
| Transient classification | `classify.ts` over 408, 429, 500, 502, 503, 504, and a thrown timeout. |
| Permanent classification | `classify.ts` over 400, 401, 403, 404, 409, 422. |
| Correlation carried | `correlation.ts` reads the header, and the envelope and log entry both carry it. |
| Correlation derived | With no header, the business key becomes the correlation id. |
| Envelope and `MessageId` | `envelope.ts` produces `<flow>:<businessKey>`, and rejects a missing business key. |
| BC client on `201` | Records the returned message id. |
| BC client on `409` | Treats an existing message as success, not as a failure, because BC deduplicated it. |
| BC client on `500` | Reports transient. |
| BC client on `400` | Reports permanent. |
| Configuration failure | A missing setting throws naming the setting. |

The infrastructure criteria (resources exist, no secret in the template, dead-letter
and alert behaviour) are verified by deploying into an empty resource group and by
`azure-integration-validator` reading the template, not by a unit test.

Running `azure-integration-validator` is part of this feature's definition of done.
The rules it will apply to this code are listed in
`.claude/bcquality/custom/skills/integration/al-azure-integration-review.md`, and the
ones this feature is directly accountable for are `az-receiver-acknowledges-fast`,
`az-retry-in-plane`, `az-dead-letter-configured`,
`az-classify-transient-vs-permanent`, `az-correlation-header`,
`az-observability-wired`, `az-secrets-in-keyvault`, `az-managed-identity`, and
`az-https-only`.
