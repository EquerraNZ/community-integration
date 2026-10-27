// Anti-pattern: the Function authenticates to Service Bus with a namespace-level shared access key
// pulled via listKeys() into a connection string. The key is long-lived, must be rotated by hand,
// and RootManageSharedAccessKey grants full control of the whole namespace, far more than sending to
// one queue needs.

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-integration-plane'
  location: location
  kind: 'functionapp'
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsServiceBus'
          value: listKeys('${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey', '2022-10-01-preview').primaryConnectionString
        }
      ]
    }
  }
}
