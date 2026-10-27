// Best practice: maxDeliveryCount bounds the retries and sends a poison message to the DLQ;
// deadLetteringOnMessageExpiration catches anything that ages out. The DLQ depth is alerted on
// elsewhere so a human sees the pile-up.

resource queue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'outbound-shipments'
  properties: {
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P14D'
    lockDuration: 'PT1M'
  }
}
