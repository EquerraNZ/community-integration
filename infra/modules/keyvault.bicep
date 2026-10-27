// The vault holding the four external credentials. It is created empty on
// purpose: secret values are written out of band by a person with access, so
// the pipeline never receives one and the template never takes one as a
// parameter.
param name string
param location string
param tenantId string = subscription().tenantId

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    // RBAC rather than access policies, so the Function App's role assignment is
    // the one place that grants it anything and `az role assignment list` is the
    // whole answer to who can read these.
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

output id string = vault.id
output name string = vault.name
output uri string = vault.properties.vaultUri
