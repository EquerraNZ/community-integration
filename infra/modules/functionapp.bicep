// The Function App and the role assignments its managed identity needs. The
// identity is the only credential in the plane: there is no connection string, no
// client secret, and no BC user.

param name string
param location string
param storageAccountName string
param appInsightsConnectionString string
param serviceBusNamespaceName string
param keyVaultName string

@description('Non-secret settings. Every secret is passed in keyVaultSecretNames instead and becomes a Key Vault reference.')
param appSettings object

@description('Setting name to Key Vault secret name. Each becomes a Key Vault reference, so the value never appears in the template, the deployment, or the portal.')
param keyVaultSecretNames object

var keyVaultUri = 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'

var secretSettings = [
  for secret in items(keyVaultSecretNames): {
    name: secret.key
    value: '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/${secret.value}/)'
  }
]

var plainSettings = [for setting in items(appSettings): { name: setting.key, value: setting.value }]

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'plan-${name}'
  location: location
  sku: {
    // Consumption. Nothing synchronous waits on the plane, so cold start is
    // acceptable, and an idle environment is close to free.
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Node|20'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      appSettings: concat(
        [
          {
            name: 'AzureWebJobsStorage'
            value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
          }
          {
            name: 'FUNCTIONS_EXTENSION_VERSION'
            value: '~4'
          }
          {
            name: 'FUNCTIONS_WORKER_RUNTIME'
            value: 'node'
          }
          {
            name: 'WEBSITE_NODE_DEFAULT_VERSION'
            value: '~20'
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: appInsightsConnectionString
          }
          {
            // Identity-based connection for the Service Bus triggers. The paired
            // disableLocalAuth on the namespace means there is no connection
            // string that could be used instead.
            name: 'SERVICEBUS__fullyQualifiedNamespace'
            value: '${serviceBusNamespaceName}.servicebus.windows.net'
          }
          {
            name: 'SERVICEBUS__credential'
            value: 'managedidentity'
          }
        ],
        plainSettings,
        secretSettings
      )
    }
  }
}

// Role assignments, each scoped to the one resource it is for. Never at
// subscription scope: the identity should not be able to read a vault or a queue
// that belongs to something else.

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespaceName
}

var keyVaultSecretsUser = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)
var serviceBusDataSender = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
)
var serviceBusDataReceiver = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
)

resource vaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, functionApp.id, keyVaultSecretsUser)
  properties: {
    roleDefinitionId: keyVaultSecretsUser
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource busSender 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: serviceBus
  name: guid(serviceBus.id, functionApp.id, serviceBusDataSender)
  properties: {
    roleDefinitionId: serviceBusDataSender
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource busReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: serviceBus
  name: guid(serviceBus.id, functionApp.id, serviceBusDataReceiver)
  properties: {
    roleDefinitionId: serviceBusDataReceiver
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output name string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName

@description('Register this in Business Central as an Entra application and grant it the extension permission set. See infra/README.md.')
output principalId string = functionApp.identity.principalId
