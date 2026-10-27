// Best practice: HTTPS only, TLS floor pinned to 1.2, and an access restriction so the Function is
// reachable only from the APIM subnet. The one public route is through the gateway and its policies.

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-receiver'
  location: location
  kind: 'functionapp'
  properties: {
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ipSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictions: [
        {
          vnetSubnetResourceId: apimSubnet.id
          action: 'Allow'
          priority: 100
          name: 'apim-only'
        }
      ]
    }
  }
}
