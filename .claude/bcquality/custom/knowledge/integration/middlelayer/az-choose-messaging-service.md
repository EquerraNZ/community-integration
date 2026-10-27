---
bc-version: [all]
domain: integration
keywords: [azure, service-bus, event-grid, event-hubs, messaging, component-selection, architecture, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Choose the right messaging service for the job

## Description

Azure has three messaging services and they are not interchangeable. Picking the wrong one is an architecture mistake that is expensive to undo once the plane is built on it, so the choice belongs at design time, not after. The three answer different questions:

- **Service Bus** is enterprise messaging for discrete business transactions that must not be lost: orders, shipments, invoices. It gives you ordering (sessions), transactions, dead-lettering, duplicate detection, and at-least-once delivery with a broker that holds the message until a consumer commits. This is the default carrier for BC integration work, because BC integration is business transactions.
- **Event Grid** is a reactive event-routing service for discrete, low-volume "something happened" notifications (a blob was created, a resource changed, a custom domain event). It pushes small events to many subscribers with filtering and its own retry, but it is not a durable work queue and does not guarantee order.
- **Event Hubs** is a high-throughput streaming ingestion service for telemetry and event streams, millions of events, read by partition offset, retained for replay. It is for analytics and bulk ingestion, not for routing a handful of business documents.

The rule: match the service to the shape of the traffic (reliable business transactions, reactive notifications, or high-volume streams), not to whichever one the team used last.

## Best Practice

Default BC integration flows (inbound documents to stage, outbound documents to send) to Service Bus, because they are business transactions that need ordering, dead-lettering, and no loss. Use Event Grid when the plane needs to react to discrete platform or domain events and fan them out to subscribers with filtering. Use Event Hubs only when ingesting a genuine high-volume stream (device telemetry, clickstream, bulk feeds) that will be processed by partition and possibly replayed. It is legitimate to combine them (Event Grid triggers a Function that stages to Service Bus), but each hop should use the service that fits its traffic. See `az-choose-messaging-service.good.bicep`.

## Anti Pattern

Forcing one service to do another's job: an Event Hub carrying a dozen business orders a day (paying for and operating a streaming platform to move a trickle of transactions, with no dead-letter and consumer-managed offsets), Event Grid used as a durable work queue for order processing (no ordering, no transactional hand-off, events dropped after its retry budget), or Service Bus used to ingest millions of telemetry events (throttling and cost where Event Hubs is built for the volume). The detection signal: the provisioned service does not match the traffic shape the flow actually carries. See `az-choose-messaging-service.bad.bicep`.

## See also

- `az-choose-service-bus-queue-vs-topic.md`
- `az-choose-event-grid-vs-event-hubs.md`
- `az-choose-logic-app-vs-function-app.md`
