// Best practice: business documents (orders, shipments) ride Service Bus, which gives ordering,
// dead-lettering, and no loss. Discrete reactive notifications use Event Grid. A high-volume
// telemetry stream uses Event Hubs. Each carrier matches the shape of its traffic.

// Business transactions: durable, ordered, dead-lettered.
resource orderQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'inbound-orders'
  properties: {
    requiresDuplicateDetection: true
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
  }
}

// Reactive "something happened" fan-out with filtering.
resource blobEvents 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: 'evgt-dropfolder'
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

// High-volume telemetry stream, read by partition, retained for replay.
resource telemetry 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eventHubNamespace
  name: 'device-telemetry'
  properties: {
    partitionCount: 8
    messageRetentionInDays: 3
  }
}
