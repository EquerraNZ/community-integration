---
bc-version: [all]
domain: integration
keywords: [azure, at-least-once, dedup, service-bus, queue-consumer, duplicate-detection, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Azure receivers are built for at-least-once delivery

## Description

Every messaging primitive the plane relies on, a webhook delivery, a Service Bus subscription, an Event Grid push, is at-least-once by design. The same event will occasionally arrive twice: the sender retried after a slow ack, the broker redelivered after a consumer crash, a network blip duplicated a push. A receiver that assumes exactly-once will, sooner or later, forward a second copy of a side effect into BC. This is the plane-side companion to the BC inbound dedup rule (`al-deduplicate-inbound-messages-with-an-idempotency-check.md`): BC deduplicates on the staged External Reference, and the plane must give it a stable id to deduplicate on, and should shed obvious duplicates before they ever reach BC.

Designing for at-least-once is not pessimism, it is the actual contract of the transport. The question is never "will a duplicate arrive" but "what happens when it does."

## Best Practice

Make the business key or the source event id the dedup anchor and carry it to BC unchanged, so BC's idempotency check is the backstop. In front of that, lean on the transport's own duplicate detection: enable Service Bus duplicate detection on the queue or topic and set `MessageId` to the event id, so a redelivery inside the detection window is dropped by the broker. Treat the handler as replayable, reading and staging the same event twice must produce one staged row, never two. See `az-idempotent-receiver.good.bicep` for a topic with duplicate detection enabled.

## Anti Pattern

A queue or subscription with no duplicate detection whose consumer treats each delivery as unique, inserting a fresh BC message per delivery with a per-delivery id, so a redelivery becomes a second staged row and a second side effect. The detection signal: a Service Bus queue/topic provisioned with `requiresDuplicateDetection` false (or defaulted) while the consumer derives the BC reference from a delivery-scoped value rather than the event's own id. The consequence is duplicate documents in BC whenever the transport redelivers, which it is entitled to do at any time. See `az-idempotent-receiver.bad.bicep`.

## See also

- `al-deduplicate-inbound-messages-with-an-idempotency-check.md`
- `az-forward-idempotency-key.md`
- `az-dead-letter-configured.md`
