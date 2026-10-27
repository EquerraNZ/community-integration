// Best practice: the storefront API key lives in Key Vault. The Function app reads it through a
// Key Vault reference resolved by its Managed Identity, so the secret value never appears in the
// template, the pipeline, or the portal's app settings. Rotation happens in the vault alone.

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-integration-plane'
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'StorefrontApiKey'
          value: '@Microsoft.KeyVault(SecretUri=${kv.properties.vaultUri}secrets/storefront-api-key/)'
        }
      ]
    }
  }
}

// Minimal role: Key Vault Secrets User for this identity only.
resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, functionApp.id, 'secrets-user')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
