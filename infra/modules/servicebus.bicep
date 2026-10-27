// The namespace and queues the plane runs on. One queue per flow, so a stuck WMS
// cannot block an incoming order, plus one shared parked queue for messages the
// plane has decided not to retry.

param name string
param location string

@description('Deliveries before Service Bus dead-letters the message. This is the plane\'s whole retry budget: the Functions host retry policy is set to a single attempt so the two do not multiply.')
param maxDeliveryCount int = 5

@description('Duplicate detection window. Settled here rather than by the first flow to need it, because it cannot be changed after the queue is created. BC\'s dedup on (External Reference, Type) is what covers anything longer.')
param duplicateDetectionWindow string = 'PT1H'

@description('Lock duration. Long enough for a read from BC plus a call to an external system, short enough that a crashed invocation is redelivered promptly.')
param lockDuration string = 'PT5M'

var flowQueues = [
  'inbound-webstore-order'
  'inbound-wms-shipment'
  'outbound-wms-fulfilment'
  'outbound-webstore-status'
]

resource namespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: name
  location: location
  sku: {
    // Standard rather than Basic: Basic has no duplicate detection, and
    // duplicate detection is load-bearing here.
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

resource queues 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = [
  for queueName in flowQueues: {
    parent: namespace
    name: queueName
    properties: {
      maxDeliveryCount: maxDeliveryCount
      lockDuration: lockDuration
      deadLetteringOnMessageExpiration: true
      requiresDuplicateDetection: true
      duplicateDetectionHistoryTimeWindow: duplicateDetectionWindow
      defaultMessageTimeToLive: 'P14D'
      enablePartitioning: false
    }
  }
]

// Where a permanent failure lands. The Node worker cannot settle a message
// explicitly, so a function cannot dead-letter the message it is holding; parking
// it here and completing it is how a 4xx avoids being retried five times.
// Operationally this queue and the dead-letter queues are one surface: messages
// that stopped, with the reason attached.
resource parked 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: namespace
  name: 'parked'
  properties: {
    maxDeliveryCount: maxDeliveryCount
    lockDuration: lockDuration
    deadLetteringOnMessageExpiration: true
    // Deliberately off: the same business key must be able to park twice, from
    // two different failures, and duplicate detection would hide the second.
    requiresDuplicateDetection: false
    defaultMessageTimeToLive: 'P14D'
    enablePartitioning: false
  }
}

output namespaceId string = namespace.id
output fullyQualifiedNamespace string = '${namespace.name}.servicebus.windows.net'
output queueNames array = concat(flowQueues, [parked.name])
output watchedQueueNames array = flowQueues
