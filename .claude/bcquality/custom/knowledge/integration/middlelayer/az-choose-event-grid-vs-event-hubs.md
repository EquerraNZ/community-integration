---
bc-version: [all]
domain: integration
keywords: [azure, event-grid, event-hubs, streaming, reactive, telemetry, throughput, component-selection, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Choose Event Grid or Event Hubs by volume and consumption model

## Description

Event Grid and Event Hubs both carry "events," but they are opposite tools and the names invite the wrong pick. Event Grid is for **discrete, reactive notifications**: a small number of distinct "this thing happened" events (a blob landed, a resource changed, a custom domain event) pushed to subscribers that react to each one, with per-event filtering, dead-lettering, and its own retry. Think dozens to thousands of meaningful events, each worth handling individually. Event Hubs is for **high-throughput streams**: millions of events ingested and read as an ordered log by partition offset, retained for a window so consumers can replay, built for telemetry, clickstream, IoT, and bulk feeds. Think firehose, processed in batches by stream consumers, not reacted to one at a time.

The decision is volume and consumption model, not the word "event." Using Event Grid for a true stream will blow through its throughput and retry model; using Event Hubs for a handful of discrete notifications means operating a partitioned streaming platform and writing offset-tracking consumers for traffic that a push subscription would have handled in one line.

## Best Practice

Use **Event Grid** when the plane reacts to discrete events: a file dropped in storage should trigger an import, a BC domain event should fan out to a few handlers, a resource change should kick off a flow. Subscribers are push endpoints (a Function, a webhook, a Service Bus queue) with server-side filters, and Event Grid handles retry and dead-letter. Use **Event Hubs** when ingesting a genuine stream, device telemetry, high-rate feeds, analytics pipelines, processed by partition with a checkpoint store and read in batches, with retention for replay. A common, correct composition: Event Grid reacts to a discrete trigger and a Function stages the result to Service Bus; Event Hubs feeds a stream processor, not BC document staging. See `az-choose-event-grid-vs-event-hubs.good.bicep`.

## Anti Pattern

Event Grid wired to carry a high-rate telemetry stream (throttling, dropped events once the retry budget is spent, no replay), or Event Hubs stood up to deliver a handful of discrete business notifications (a partitioned log, a checkpoint store, and offset-tracking consumer code for traffic Event Grid would push in one subscription). The detection signal: the service's throughput and consumption model is the opposite of the traffic, a stream on Event Grid, or trickle notifications on Event Hubs. Match the tool to volume and how consumers read it. See `az-choose-event-grid-vs-event-hubs.bad.bicep`.

## See also

- `az-choose-messaging-service.md`
- `az-choose-service-bus-queue-vs-topic.md`
- `az-subscription-health-check.md`
