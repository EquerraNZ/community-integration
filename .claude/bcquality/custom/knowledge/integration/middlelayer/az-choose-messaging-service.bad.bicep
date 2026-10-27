// Anti-pattern: a handful of business orders a day are pushed through an Event Hub. A streaming
// ingestion platform is now the carrier for a trickle of transactions it is the wrong shape for:
// there is no dead-letter, no at-least-once broker hand-off, and consumers must track partition
// offsets by hand. The same orders on a Service Bus queue would get ordering, dead-lettering, and
// duplicate detection for free.

resource ordersAsStream 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eventHubNamespace
  name: 'inbound-orders'
  properties: {
    partitionCount: 4
    messageRetentionInDays: 1
  }
}
