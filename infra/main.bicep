// One environment of the Azure integration layer, in one resource group.
// Everything differs between environments by parameters only, so dev and prod are
// the same template with different values.
targetScope = 'resourceGroup'

@description('Environment name, used in every resource name. Keep it short: storage and Key Vault names are length-limited.')
@allowed(['dev', 'test', 'prod'])
param environmentName string = 'dev'

@description('Short region code for naming, e.g. aue for Australia East.')
param regionCode string = 'aue'

param location string = resourceGroup().location

@description('The BC API root the plane stages messages to.')
param bcBaseUrl string

@description('The BC company the plane writes into.')
param bcCompanyId string

@description('The token audience for the plane\'s managed identity calling BC. A parameter on purpose: the exact value is tech design question 6, and settling it must not require a code change.')
param bcTokenScope string = 'https://api.businesscentral.dynamics.com/.default'

@description('The storefront base URL.')
param webstoreBaseUrl string

@description('The WMS base URL.')
param wmsBaseUrl string

@description('Where dead-letter, parked, and subscription drift alerts go.')
param alertEmail string

var namePrefix = 'intplane-${environmentName}-${regionCode}'
var storageName = toLower(replace('stintplane${environmentName}${regionCode}', '-', ''))
var functionAppName = 'func-${namePrefix}'

module observability 'modules/observability.bicep' = {
  name: 'observability'
  params: {
    namePrefix: namePrefix
    location: location
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    name: storageName
    location: location
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    name: 'kv-${namePrefix}'
    location: location
  }
}

module serviceBus 'modules/servicebus.bicep' = {
  name: 'servicebus'
  params: {
    name: 'sb-${namePrefix}'
    location: location
  }
}

module functionApp 'modules/functionapp.bicep' = {
  name: 'functionapp'
  params: {
    name: functionAppName
    location: location
    storageAccountName: storage.outputs.name
    appInsightsConnectionString: observability.outputs.connectionString
    serviceBusNamespaceName: 'sb-${namePrefix}'
    keyVaultName: keyVault.outputs.name
    appSettings: {
      BC_BASE_URL: bcBaseUrl
      BC_COMPANY_ID: bcCompanyId
      BC_TOKEN_SCOPE: bcTokenScope
      BC_EVENT_ENDPOINT_URL: 'https://${functionAppName}.azurewebsites.net/api/bc/events'
      WEBSTORE_BASE_URL: webstoreBaseUrl
      WMS_BASE_URL: wmsBaseUrl
    }
    // Every secret is a Key Vault reference. No secret value appears in this
    // template, in a parameter file, or in the deployment history, which is
    // what `az-secrets-in-keyvault` is checking for.
    keyVaultSecretNames: {
      WEBSTORE_INGEST_KEY: 'webstore-ingest-key'
      WEBSTORE_STATUS_KEY: 'webstore-status-key'
      WMS_API_KEY: 'wms-api-key'
      WMS_CALLBACK_KEY: 'wms-callback-key'
    }
  }
  dependsOn: [
    serviceBus
  ]
}

module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  params: {
    namePrefix: namePrefix
    location: location
    serviceBusNamespaceName: 'sb-${namePrefix}'
    appInsightsId: observability.outputs.componentId
    watchedQueueNames: serviceBus.outputs.watchedQueueNames
    alertEmail: alertEmail
  }
}

output functionAppName string = functionApp.outputs.name
output functionAppHost string = functionApp.outputs.defaultHostName
output serviceBusNamespace string = serviceBus.outputs.fullyQualifiedNamespace
output keyVaultName string = keyVault.outputs.name
@description('Register this principal in Business Central before any flow will work. See infra/README.md.')
output functionAppPrincipalId string = functionApp.outputs.principalId
