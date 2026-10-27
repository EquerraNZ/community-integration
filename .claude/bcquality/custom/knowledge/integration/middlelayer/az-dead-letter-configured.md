---
bc-version: [all]
domain: integration
keywords: [azure, dead-letter, dlq, service-bus, max-delivery-count, poison-message, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Enable dead-lettering with a defined max delivery count

## Description

A message that cannot be processed, a poison payload, a permanent downstream rejection, a bug in the consumer, must have somewhere to go. On Service Bus that place is the dead-letter queue, and the trigger is `maxDeliveryCount`: after that many failed delivery attempts the broker moves the message to the DLQ instead of redelivering it forever. A subscription or queue without dead-lettering configured does one of two bad things, it either redelivers a poison message endlessly (burning the consumer and blocking the queue head on an ordered subscription) or, worse, silently drops it when it expires. Both are data loss with no audit trail. Dead-lettering turns an unprocessable message into a visible, inspectable artifact that an operator can triage.

This is the plane-side companion to BC's manual-resolution rule (`al-make-failed-integration-messages-manually-resolvable.md`): BC parks a failed Integration Message for an operator; the plane parks a poison transport message in the DLQ for the same reason.

## Best Practice

Set `maxDeliveryCount` explicitly on every queue and subscription (a small number, commonly 5 to 10, so a poison message gives up quickly rather than looping). Enable `deadLetteringOnMessageExpiration` so a message that ages out lands in the DLQ rather than vanishing. Monitor the DLQ depth and alert on it, a growing DLQ is the signal that something needs a human. See `az-dead-letter-configured.good.bicep`.

## Anti Pattern

A queue or subscription with no `maxDeliveryCount` set (or set so high it never triggers) and no dead-letter-on-expiration, so failed messages either redeliver without end or expire into nothing. The detection signal: a Service Bus queue/subscription resource in Bicep/ARM/Terraform missing `maxDeliveryCount` and `deadLetteringOnMessageExpiration`, especially paired with a short message TTL. The consequence is a poison message that blocks an ordered subscription head, or silent loss of messages that should have been triaged. See `az-dead-letter-configured.bad.bicep`.

## See also

- `al-make-failed-integration-messages-manually-resolvable.md`
- `az-classify-transient-vs-permanent.md`
- `az-idempotent-receiver.md`
