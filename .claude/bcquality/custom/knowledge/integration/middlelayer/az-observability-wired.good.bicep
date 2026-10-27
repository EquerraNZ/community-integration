// Best practice: Application Insights is provisioned and bound to the Function app, and a diagnostic
// setting routes the app's logs and metrics to a Log Analytics workspace. Runs, failures, and
// dependency calls all land somewhere queryable and alertable.

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-integration-plane'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
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
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'func-diagnostics'
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [ { categoryGroup: 'allLogs', enabled: true } ]
    metrics: [ { category: 'AllMetrics', enabled: true } ]
  }
}
