---
bc-version: [all]
domain: integration
keywords: [azure, correlation-id, tracing, header, service-bus, application-insights, end-to-end, middle-layer]
technologies: [json]
countries: [w1]
application-area: [all]
---

# Carry the correlation id on every hop

## Description

When an integration flow breaks, the first question is always "where," and the only way to answer it quickly is to follow one id from BC, through every plane hop, to the external system and back. BC sets a Correlation ID once when it stages a message (see `al-propagate-a-correlation-id-across-every-hop.md`). The plane's duty is to carry that id unbroken: read it off the inbound message, set it on the Service Bus message header and on every outbound HTTP call, and log it at each step so one trace joins all three tiers. A hop that drops the correlation id, or mints a new one, severs the trace exactly where a reviewer needs it most, turning a two-minute "the WMS rejected it at 14:03" into an hour of cross-referencing timestamps across three logging systems.

Correlation is not idempotency: the idempotency key makes a retry safe, the correlation id makes a flow observable. They travel together on the same hops but answer different questions, and both must survive the plane.

## Best Practice

Treat the correlation id as pass-through metadata. Read it from the inbound header or message property, propagate it onto the outbound HTTP header and the Service Bus `CorrelationId` property, and include it in every log/trace the hop emits. Keep the W3C `traceparent` header flowing as well where the dependencies honour it, so Application Insights stitches the distributed trace automatically. Never generate a new correlation id mid-flow; a new id belongs only at the true origin of a new flow. See `az-correlation-header.good.json`.

## Anti Pattern

A hop that calls onward without the correlation header, or sets it from a fresh `guid()`, so the trace restarts at that hop. The detection signal: an outbound action or Service Bus send whose correlation header/property is absent or bound to a newly generated value rather than the id received from the previous hop, and log statements that omit it. The consequence is a broken trace: the flow can be reconstructed in each tier but not joined across them, which is precisely the join you need during an incident. See `az-correlation-header.bad.json`.

## See also

- `al-propagate-a-correlation-id-across-every-hop.md`
- `az-forward-idempotency-key.md`
- `az-observability-wired.md`
