---
bc-version: [all]
domain: integration
keywords: [azure, service-bus, queue, topic, subscription, pub-sub, fan-out, component-selection, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Choose a Service Bus queue or a topic by the number of consumers

## Description

Within Service Bus the next decision is queue versus topic, and it turns on one question: does exactly one logical consumer act on each message, or do several independent consumers each need their own copy? A queue is point-to-point: one message, one competing-consumer pool, consumed once. A topic is publish-subscribe: one message is copied to every subscription, and each subscription is an independent consumer with its own filter and its own dead-letter. Getting this wrong is painful to reverse. Start with a queue when a second consumer appears later and you cannot give it the message without stealing it from the first, you have to migrate the producers to a topic. Start with a topic for a single consumer and you have paid for fan-out machinery, and risk an orphaned subscription silently accumulating messages, for a shape that never needed it.

The cost of a topic's flexibility is real: every subscription is a separate queue to monitor and dead-letter, and a subscription nobody drains fills up and eventually dead-letters everything.

## Best Practice

Use a **queue** for a command or a work item that one consumer handles: "process this inbound order," "send this shipment to the WMS." One producer or many, but one logical processor. Use a **topic with subscriptions** for an event that multiple independent consumers each react to: a "sales shipment posted" Business Event that the WMS connector, the analytics feed, and the customer-notification flow all need, each as its own filtered subscription with its own dead-letter. Let the filter live on the subscription so a consumer only sees what it cares about. See `az-choose-service-bus-queue-vs-topic.good.bicep`.

## Anti Pattern

A queue where several consumers genuinely need the same message, so teams bolt on a second queue and make the producer write twice (or a consumer re-publishes), reinventing pub-sub by hand. Or a topic with a single subscription that will never have a second, carrying the operational weight of fan-out for a plain point-to-point flow. The detection signal: a producer writing the same payload to multiple queues to simulate fan-out, or a topic whose only subscription is 1:1 with one producer. Match the primitive to the consumer count. See `az-choose-service-bus-queue-vs-topic.bad.bicep`.

## See also

- `az-choose-messaging-service.md`
- `az-dead-letter-configured.md`
- `az-idempotent-receiver.md`
