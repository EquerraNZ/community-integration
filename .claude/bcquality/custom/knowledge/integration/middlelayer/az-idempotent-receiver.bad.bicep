// Anti-pattern: duplicate detection is left off (the default), so the broker happily redelivers the
// same event, and the consumer, which keys the BC message off a per-delivery value, stages it twice.
// Every redelivery becomes a second document in BC.

resource topic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'shipment-events'
  properties: {
    // requiresDuplicateDetection defaults to false, and nothing downstream dedups either.
    supportOrdering: true
  }
}

resource subscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: topic
  name: 'bc-staging'
  properties: {
    maxDeliveryCount: 10
  }
}
