using './main.bicep'

// No secret appears here, and none ever should. The four external credentials
// are written into Key Vault out of band; this file only names the environment.

param environmentName = 'dev'
param regionCode = 'aue'

param bcBaseUrl = 'https://api.businesscentral.dynamics.com/v2.0/<tenant-id>/sandbox/api/equerra/integrationFoundation/v1.0'
param bcCompanyId = '<company-guid>'

param webstoreBaseUrl = 'https://swa-harbour-demo.azurestaticapps.net'
param wmsBaseUrl = 'https://wms.example.com'

param alertEmail = 'integration-alerts@example.com'
