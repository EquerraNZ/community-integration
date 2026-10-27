// Anti-pattern: no maxDeliveryCount and no dead-letter-on-expiration, paired with a short TTL.
// A poison message redelivers until it expires, then disappears with no DLQ entry and no audit
// trail. On an ordered/session queue it also blocks every message behind it in the meantime.

resource queue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'outbound-shipments'
  properties: {
    defaultMessageTimeToLive: 'PT30M'
    lockDuration: 'PT1M'
  }
}
