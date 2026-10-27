// Best practice: the Function app has a system-assigned Managed Identity and is granted the scoped
// Service Bus Data Sender role on the one queue it writes to. No connection string, no shared key,
// no secret to rotate. The host binding authenticates with the identity via the fullyQualifiedNamespace.

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-integration-plane'
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    httpsOnly: true
    siteConfig: {
      appSettings: [
        { name: 'ServiceBus__fullyQualifiedNamespace', value: '${serviceBusNamespace.name}.servicebus.windows.net' }
      ]
    }
  }
}

resource dataSender 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(outboundQueue.id, functionApp.id, 'sb-data-sender')
  scope: outboundQueue
  properties: {
    // Azure Service Bus Data Sender, scoped to the single queue.
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
