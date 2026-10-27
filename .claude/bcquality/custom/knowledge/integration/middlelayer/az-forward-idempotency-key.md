---
bc-version: [all]
domain: integration
keywords: [azure, idempotency-key, forward, header, plane, dedup, side-effect, middle-layer]
technologies: [json]
countries: [w1]
application-area: [all]
---

# The Azure plane forwards the idempotency key

## Description

Idempotency on an integration flow only works if the key survives every hop. BC sets a stable `Idempotency-Key` on every outbound call (see `al-send-an-idempotency-key-on-every-outbound-call.md`), derived from the Integration Message GUID so the first attempt and every retry carry the same value. The middle layer sits on that path: a Logic App, a Function, an APIM policy, or a Service Bus message relays the call onward to the external system. If any of those hops drops the header, maps it to a per-run value, or regenerates it, the external receiver can no longer recognise a retry, and an uncertain failure followed by a replay double-applies the side effect. The plane's job is to be transparent to the key, not to own it.

The inbound direction is the same rule in reverse: the receiver must forward the source system's stable id to BC (as the External Reference / idempotency value on the staged message) so BC can deduplicate. The plane carries the key in both directions and mints a new one in neither.

## Best Practice

On every outbound hop, copy the incoming `Idempotency-Key` header straight to the outgoing request. On every inbound hop, pass the source system's event id to the BC staging endpoint as the message's stable reference. Where the hop is a Service Bus message rather than HTTP, carry the key as a message property (and set `MessageId` to it so the broker's own duplicate detection reinforces the contract). Never use a workflow run id, a `guid()` expression, or a timestamp as the key. See `az-forward-idempotency-key.good.json`.

## Anti Pattern

A plane hop that calls the external system without an `Idempotency-Key` header, or that sets it from a value which changes per run (`@workflow().run.name`, `@guid()`, `@utcNow()`). The detection signal: an outbound action in a Logic App/Function/APIM policy whose idempotency header is absent, or bound to a run-scoped or freshly generated value rather than to the key received from BC. The consequence is duplicate charges and duplicate shipments on replay, with the plane, not BC, as the point where safety was lost. See `az-forward-idempotency-key.bad.json`.

## See also

- `al-send-an-idempotency-key-on-every-outbound-call.md`
- `az-idempotent-receiver.md`
- `az-correlation-header.md`
