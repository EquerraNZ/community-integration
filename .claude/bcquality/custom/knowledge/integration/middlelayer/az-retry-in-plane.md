---
bc-version: [all]
domain: integration
keywords: [azure, retry, backoff, logic-app, host-json, service-bus, delivery-count, middle-layer]
technologies: [json]
countries: [w1]
application-area: [all]
---

# Configure retry in the plane, not in a hand-written loop

## Description

Retry is a property of the integration plane, and the plane already has first-class, declarative retry everywhere: the Logic App action `retryPolicy`, the Functions `host.json` retry block, the Service Bus `maxDeliveryCount`. The rule is to configure those explicitly and let the platform own the retry, rather than reimplementing it as a hand-written loop in a Function body or, worse, pushing the retry responsibility back into a BC Job Queue loop. Platform retry gives you exponential backoff, jitter, a bounded count, and dead-letter on exhaustion for free, and it keeps the retry state in the plane where it survives a consumer restart. A hand-rolled loop gets the easy parts wrong (fixed interval, no jitter, unbounded) and the hard parts wrong (lost state on crash, no dead-letter).

The other half of the rule is: do not rely on silent defaults. An unconfigured retry policy is still a retry policy, usually a short fixed count that neither matches the dependency's real recovery time nor fails loudly. Pin the values so the behaviour is a decision, not an accident.

## Best Practice

Set an explicit `retryPolicy` on each Logic App action that calls a flaky dependency: exponential type, a bounded count, and an interval tuned to how long that dependency actually takes to recover. For Functions, configure the `host.json` retry strategy; for Service Bus consumers, set `maxDeliveryCount` so exhausted messages dead-letter. Pair this with classification (`az-classify-transient-vs-permanent.md`) so only transient failures are retried, and with dead-lettering (`az-dead-letter-configured.md`) so exhausted retries have somewhere to land. See `az-retry-in-plane.good.json`.

## Anti Pattern

A Function or Logic App that wraps an outbound call in its own loop with a `Delay` action and a counter, or that leaves the retry policy at its silent default, or that disables plane retry and expects the BC Job Queue to drive re-sends. The detection signal: a `do-until`/counter loop around an HTTP action, a retry policy left unspecified on a call to an external dependency, or `retryPolicy.type` set to `none` with no deliberate reason. The consequence is fixed-interval retries that hammer a struggling dependency, retry state lost on restart, and no dead-letter when the count is spent. See `az-retry-in-plane.bad.json`.

## See also

- `al-prefer-business-events-over-handwritten-retry-loops.md`
- `az-dead-letter-configured.md`
- `az-classify-transient-vs-permanent.md`
- `az-durable-retry-not-tight-loop.md`
