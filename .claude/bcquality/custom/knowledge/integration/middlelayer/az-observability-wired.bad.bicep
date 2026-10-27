// Anti-pattern: the Function app has no Application Insights connection string and no diagnostic
// setting. Its runs and failures emit nothing durable, so when the integration stops there is no
// trace to reconstruct what happened, and no signal to alert on. The outage is found by a user.

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-integration-plane'
  location: location
  kind: 'functionapp'
  properties: {
    httpsOnly: true
    siteConfig: {
      appSettings: [
        // No APPLICATIONINSIGHTS_CONNECTION_STRING, and no diagnosticSettings resource anywhere.
      ]
    }
  }
}
