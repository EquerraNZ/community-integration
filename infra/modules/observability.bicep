// Log Analytics workspace and Application Insights for the integration plane.
// A plane with no telemetry cannot be debugged when an integration silently stops,
// which is the failure this whole design is built around.
param namePrefix string
param location string

@description('Days to keep logs. 30 is the free tier allowance and is plenty for a trace that is read within hours of a failure.')
param retentionInDays int = 30

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${namePrefix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${namePrefix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    // Workspace-based, so queries join function traces with platform logs and a
    // correlation id search returns every hop in one result.
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceId string = workspace.id
output connectionString string = insights.properties.ConnectionString
output instrumentationKey string = insights.properties.InstrumentationKey
output componentId string = insights.id
