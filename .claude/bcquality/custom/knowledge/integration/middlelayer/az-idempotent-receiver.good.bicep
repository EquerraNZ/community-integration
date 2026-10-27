// Best practice: duplicate detection is on, so a redelivery of the same MessageId inside the
// window is dropped by the broker before a consumer ever runs. The consumer sets MessageId to the
// source event id and forwards that id to BC, so BC's idempotency check is the second line.

resource topic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'shipment-events'
  properties: {
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    supportOrdering: true
  }
}

resource subscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: topic
  name: 'bc-staging'
  properties: {
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
  }
}
