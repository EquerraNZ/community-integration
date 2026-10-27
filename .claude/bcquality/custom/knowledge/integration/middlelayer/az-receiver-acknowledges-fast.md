---
bc-version: [all]
domain: integration
keywords: [azure, receiver, acknowledge, 202, timeout, async, upstream, false-retry, middle-layer]
technologies: [json]
countries: [w1]
application-area: [all]
---

# Azure receivers acknowledge the caller fast

## Description

Once a receiver has staged the message (see `az-receiver-stages-to-bc.md`), it must tell the upstream caller quickly: a 2xx when the work is accepted and complete, or a 202 Accepted when the real work runs asynchronously behind the plane. The caller's timeout, not BC's, is the clock that matters here. Storefronts, payment gateways, and partner platforms give a webhook target a few seconds to answer before they declare the delivery failed and retry it. Every second the receiver spends doing work before it responds is a second closer to a false retry, and a false retry is a duplicate side effect waiting to happen.

Acknowledging fast is a different concern from staging first: a receiver can stage correctly and still hold the response open while it does something slow afterward (logging to a chatty sink, calling an enrichment API, waiting on a downstream confirmation). The response must come right after the staging write.

## Best Practice

Return immediately after the staging write succeeds. If anything beyond staging has to happen (enrichment, fan-out, notification), schedule it after the response rather than before it: a Service Bus message, a Durable Function, or a second BC Job Queue stage. Prefer 202 Accepted with the staged message id in the body so the caller can correlate later. See `az-receiver-acknowledges-fast.good.json` for the response landing straight after staging, with the slow work queued rather than awaited.

## Anti Pattern

A receiver that performs retrieval, enrichment, or confirmation work on the request thread before sending its response, so the upstream caller waits on the full chain. The detection signal: one or more long-running actions (an external Http call, a loop, a delay, a wait-for-downstream) sequenced before the `Response` action in the receiver. The consequence is upstream timeouts and the retries they trigger, which hit precisely when a slow dependency has already made the system fragile. The fix is to answer after staging and move the rest off the request path. See `az-receiver-acknowledges-fast.bad.json`.

## See also

- `az-receiver-stages-to-bc.md`
- `al-accept-async-work-instead-of-synchronous-wait-loops.md`
- `az-202-status-poll.md`
