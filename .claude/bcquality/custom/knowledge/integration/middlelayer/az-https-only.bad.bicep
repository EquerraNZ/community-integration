// Anti-pattern: httpsOnly is unset (so plain HTTP is accepted), minTlsVersion is pinned to a
// deprecated 1.0, and there is no access restriction, so the Function is reachable directly on its
// default hostname and the APIM gateway in front of it is bypassed by anyone who knows the URL.

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-receiver'
  location: location
  kind: 'functionapp'
  properties: {
    siteConfig: {
      minTlsVersion: '1.0'
    }
  }
}
