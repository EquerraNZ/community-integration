// Anti-pattern: three consumers each need the "shipment posted" event, so instead of a topic the
// design uses three queues and makes the producer write the same payload to all three. This is
// pub-sub reinvented by hand: the producer now knows every consumer, adding a fourth means changing
// the producer, and the three copies can drift. A topic with three subscriptions is the primitive
// built for exactly this.

resource toWmsQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'shipment-posted-wms'
  properties: { maxDeliveryCount: 10 }
}

resource toAnalyticsQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'shipment-posted-analytics'
  properties: { maxDeliveryCount: 10 }
}

resource toNotifyQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'shipment-posted-notify'
  properties: { maxDeliveryCount: 10 }
}
