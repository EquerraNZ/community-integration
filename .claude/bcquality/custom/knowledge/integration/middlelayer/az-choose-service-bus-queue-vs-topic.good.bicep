// Best practice: a queue for the single-consumer command (process this inbound order), and a topic
// for the event that several independent consumers each need a copy of (shipment posted -> WMS,
// analytics, notifications), each as its own filtered subscription with its own dead-letter.

// Point-to-point: one logical processor.
resource processOrders 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'process-inbound-orders'
  properties: { maxDeliveryCount: 10, deadLetteringOnMessageExpiration: true }
}

// Pub-sub: one event, many independent consumers.
resource shipmentPosted 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'sales-shipment-posted'
  properties: { requiresDuplicateDetection: true }
}

resource toWms 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: shipmentPosted
  name: 'wms-connector'
  properties: { maxDeliveryCount: 10, deadLetteringOnFilterEvaluationExceptions: true }
}

resource toAnalytics 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: shipmentPosted
  name: 'analytics-feed'
  properties: { maxDeliveryCount: 10 }
}
