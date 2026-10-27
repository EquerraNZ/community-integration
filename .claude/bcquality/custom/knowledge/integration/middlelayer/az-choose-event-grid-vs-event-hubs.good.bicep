// Best practice: Event Grid reacts to a discrete trigger (a file landed in the drop container) and
// pushes it to a Function, with filtering, retry, and dead-letter handled for us. Event Hubs is used
// for the genuine high-volume telemetry stream, read by partition with retention for replay. Each
// service matches its traffic shape.

// Discrete reactive notification -> push to a handler.
resource dropFolderEvents 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: storageSystemTopic
  name: 'on-file-dropped'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: { resourceId: importFunction.id }
    }
    filter: {
      includedEventTypes: [ 'Microsoft.Storage.BlobCreated' ]
      subjectBeginsWith: '/blobServices/default/containers/dropfolder/'
    }
    deadLetterDestination: {
      endpointType: 'StorageBlob'
      properties: { resourceId: deadLetterStorage.id, blobContainerName: 'eg-deadletter' }
    }
  }
}

// High-volume stream -> read by partition, retained for replay.
resource telemetry 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eventHubNamespace
  name: 'device-telemetry'
  properties: { partitionCount: 16, messageRetentionInDays: 7 }
}
