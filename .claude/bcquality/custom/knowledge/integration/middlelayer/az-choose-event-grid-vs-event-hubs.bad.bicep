// Anti-pattern: a high-rate device telemetry stream (tens of thousands of events a minute) is pointed
// at an Event Grid subscription. Event Grid is built to push discrete notifications, not to carry a
// firehose: it will throttle, and once the per-event retry budget is spent events are dropped with no
// replay. This stream belongs on Event Hubs, read by partition with a checkpoint store.

resource telemetryOnGrid 'Microsoft.EventGrid/topics@2022-06-15' = {
  name: 'evgt-device-telemetry'
  location: location
  properties: {
    inputSchema: 'EventGridSchema'
  }
}

resource toProcessor 'Microsoft.EventGrid/topics/eventSubscriptions@2022-06-15' = {
  parent: telemetryOnGrid
  name: 'firehose-to-function'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: { resourceId: telemetryFunction.id }
    }
  }
}
