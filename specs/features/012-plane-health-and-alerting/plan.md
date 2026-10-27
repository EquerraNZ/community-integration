# Feature Plan: Plane Health and Alerting

> One timer function, one derived expected set, and the alert rules that make silence
> audible.

- **Feature id:** 012-plane-health-and-alerting
- **Spec:** ./spec.md
- **Status:** in-progress

## Approach

A timer function lists BC's external business event subscriptions, compares them with
a set derived from `eventRoutes.ts`, and re-registers anything missing. The comparison
and the decision are pure functions, so they are testable without Azure and without
BC; the BC calls sit behind the client from `009`.

**Decision: the expected set is derived, never written twice.** The obvious
implementation is a list of event names in the health check. It would be correct on
the day it was written and wrong the first time someone added a route, and it would be
wrong silently, which is the exact failure mode this feature exists to prevent. The
check reads the same table the router routes on.

**Decision: re-register automatically, and alert anyway.** Re-registering is
mechanical and waiting for a person extends the outage for no gain. Alerting even
though it is fixed is the point: the plane was deaf for up to six hours and someone
should find out why, not just that it recovered.

**Decision: a failed check never reports healthy.** A check that cannot reach BC
reports that it could not tell. The tempting shortcut, treating an empty list as "no
drift", would turn a BC outage into a green dashboard.

## Standard Azure services reused

| Service | How |
|---|---|
| Functions timer trigger | The six-hourly schedule. No scheduler to write, no job to supervise. |
| Azure Monitor metric alerts | Dead-letter message count per queue, on the Service Bus metric. No polling code. |
| Azure Monitor log alert | Drift and check failure, on the health check's own trace. |
| Action group | The one seam to whatever operations actually uses. Created in `009`, reused here. |

## AL objects to add or extend

None. This feature is Azure-only. It is the counterpart to `008`, which covers BC's
own view, and neither changes the other.

## Azure components to add or change

| Component | Kind | Where | New/Change | Purpose |
|---|---|---|---|---|
| `checkSubscriptionHealth.ts` | function (timer) | `integration-plane/src/functions/` | new | The six-hourly check and re-registration. |
| `subscriptionHealth.ts` | shared | `integration-plane/src/shared/` | new | The pure comparison: expected against actual, returning what is missing and why. |
| `eventRoutes.ts` | shared | `integration-plane/src/shared/` | change | Export the expected subscription set derived from the routing table. |
| `bcClient.ts` | shared | `integration-plane/src/shared/` | change | Add list and create for business event subscriptions. |
| `alerts.bicep` | module | `infra/modules/` | change | Add the drift and check-failure log alerts beside the dead-letter metric alerts from `009`. |

Plane requirement from `brief.md` satisfied here: 11 (watch its own BC subscriptions).
Requirement 8's alerting half lands here too: `009` configured dead-lettering, and
this feature is what tells somebody it happened.

## Data model

None. The expected set is computed from `eventRoutes.ts` at run time.

## Integration points

| Hop | Receives | Delivers | On transient | On permanent |
|---|---|---|---|---|
| Health check | timer | `GET` then `POST` BC's subscription endpoints | log the failure, next run retries | log the failure, next run retries |

There is no queue and no dead-letter here, deliberately: the check is idempotent and
runs again in six hours, so a failed run needs no retry machinery of its own. Adding
some would be plumbing with nothing to carry.

## Cross-cutting

- **Permissions:** the identity from `009` needs read and create on BC's business
  event subscriptions. If that is a different permission set from staging a message,
  it is added in `infra/README.md`'s registration step.
- **Telemetry:** the seven events in the spec. These log with the run id rather than a
  correlation id, because no business message is involved.
- **Performance:** two calls every six hours. Immaterial.
- **Cost:** a log alert rule and four metric alert rules. Immaterial.

## Risks and decisions

| Risk or decision | Position |
|---|---|
| The BC subscription API shape is the least certain thing in the plane | Accepted and isolated: it lives behind two client methods, so first contact changes those and nothing else. |
| Automatic re-registration could fight a deliberate removal | Real but narrow. If someone removes a subscription on purpose, they remove its route too, and the derived expected set then agrees with them. That is the reason for deriving it. |
| Six hours against a three-day expiry | Comfortable. The cost of checking is near zero, so the only argument for shorter is how long the plane may be deaf before anyone knows. |
| Alerting on a self-healed condition | Deliberate. The alert is about the cause, not the symptom. |

## Test strategy

| Acceptance criterion | Test |
|---|---|
| Healthy, nothing done | `subscriptionHealth` with expected equal to actual, asserting no drift and nothing to register. |
| Missing, re-registered | One expected absent, asserting it is returned as missing and the function calls create once. |
| Wrong endpoint counts as missing | Present by name but with a different notification URL, asserting it is treated as missing. |
| BC unreachable | The client throws, asserting the function reports failure and does not report healthy. |
| Re-registration failure | Create throws, asserting the event name and error are reported and nothing else is swallowed. |
| Expected set is derived | A test adds a route and asserts the expected set grows, with no second list to edit. |

The two alerting criteria (dead-letter alert fires, drift alert fires) are verified by
deploying and forcing each condition, not by a unit test, since they are Azure Monitor
rules rather than code.

`azure-integration-validator` runs on this feature. The rule it is directly
accountable for is `az-subscription-health-check`, with `az-observability-wired` and
`az-dead-letter-configured` exercised through the alert rules.
