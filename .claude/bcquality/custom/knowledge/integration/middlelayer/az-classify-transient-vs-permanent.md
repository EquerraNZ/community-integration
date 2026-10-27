---
bc-version: [all]
domain: integration
keywords: [azure, transient, permanent, 4xx, 5xx, 429, retry, dead-letter, classification, middle-layer]
technologies: [json]
countries: [w1]
application-area: [all]
---

# Distinguish transient failures from permanent ones

## Description

Not every failure should be retried. Transient failures, a 408, a 429, a 5xx, a socket timeout, are the dependency briefly unavailable or throttling; the right response is retry with backoff. Permanent failures, a 400, a 401, a 404, a 422, invalid data or a rejected contract, will fail identically no matter how many times you resend; the right response is to stop and route the message to the dead-letter path or an alert. A plane that retries everything turns a permanent 4xx into an infinite loop that never succeeds and never surfaces, and a plane that retries nothing gives up on a blip that a single retry would have cleared. The classification is what makes retry and dead-lettering do the right thing.

This mirrors the BC-side error classification rule (`al-classify-integration-errors-for-resolution.md`): BC sorts failures into data error, transient, and contract change; the plane makes the same cut at the transport, so transient noise never reaches a human and permanent failures reach one fast.

## Best Practice

Retry only the transient set (408, 429, the 5xx range, connection timeouts), honouring `Retry-After` when the dependency sends it, and cap the attempts. On a permanent failure (the 4xx set other than 408/429) do not retry: dead-letter the message or raise an alert so a human or the integration owner acts on it. Encode this as a scope with a `runAfter` that branches on the status class, or as a condition that only re-enqueues transient codes. See `az-classify-transient-vs-permanent.good.json`.

## Anti Pattern

A retry policy or loop that fires on every failure regardless of status, so a 400 or a 422 is retried to exhaustion exactly like a timeout. The detection signal: a retry configuration with no status-class gate, or an error branch that re-enqueues on any non-2xx, so permanent failures consume the whole retry budget and only then (if dead-lettering exists at all) land in the DLQ, long after the owner should have been told. The consequence is wasted retries against a request that can never succeed and slow escalation of genuine contract breaks. See `az-classify-transient-vs-permanent.bad.json`.

## See also

- `al-classify-integration-errors-for-resolution.md`
- `az-retry-in-plane.md`
- `az-dead-letter-configured.md`
