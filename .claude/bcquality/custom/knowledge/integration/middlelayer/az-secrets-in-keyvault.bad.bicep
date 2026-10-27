// Anti-pattern: the storefront API key is a parameter with an inline default and is written straight
// into an app setting as a literal. The value is now in the template, in git history, in deployment
// logs, and in plain text in the portal. Rotating it means rewriting history, not updating a vault.

@description('Storefront API key')
param storefrontApiKey string = 'PLACEHOLDER-inline-secret-belongs-in-key-vault'

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-integration-plane'
  location: location
  kind: 'functionapp'
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'StorefrontApiKey'
          value: storefrontApiKey
        }
      ]
    }
  }
}
