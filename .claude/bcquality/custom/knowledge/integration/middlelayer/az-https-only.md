---
bc-version: [all]
domain: integration
keywords: [azure, https-only, tls, apim, front-door, transport-security, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Enforce HTTPS and a current TLS minimum

## Description

Integration traffic carries business data and credentials, so every ingress and egress in the plane must be encrypted in transit, and the encryption floor must be a current TLS version. Two defaults work against this. First, a Function app or receiver left with `httpsOnly` off accepts plain HTTP, so a misconfigured caller (or an attacker) can send credentials and payloads in clear text. Second, a resource left on an old `minTlsVersion` silently permits TLS 1.0/1.1, which are deprecated and breakable. Neither shows up as an error, the flow still works, which is exactly why it gets missed. The related exposure is topology: when APIM (or Front Door) is the intended front door for a receiver, the backing Function must not also be reachable directly, or the gateway's policies, auth, rate limits, WAF, are simply bypassed by calling the Function's own hostname.

## Best Practice

Set `httpsOnly: true` on every Function app and web-hosted receiver, and pin `minTlsVersion` to `1.2` (or higher as the platform advances). Where APIM or Front Door fronts the receiver, lock the Function's access down to the gateway, via access restrictions, a private endpoint, or a shared secret the gateway injects, so the only public route is through the gateway and its policies. Enforce HTTPS and the TLS floor on APIM itself too. See `az-https-only.good.bicep`.

## Anti Pattern

A Function app or receiver with `httpsOnly` unset (defaulting to allowing HTTP), a `minTlsVersion` left at `1.0`/`1.1`, or a Function meant to sit behind APIM that is openly reachable on its default hostname. The detection signal: a `Microsoft.Web/sites` resource missing `httpsOnly: true`, a `minTlsVersion` below `1.2`, or no access restriction where a gateway is the intended entry point. The consequence is cleartext or weak-TLS traffic carrying business data, and a gateway whose protections are trivially bypassed. See `az-https-only.bad.bicep`.

## See also

- `az-secrets-in-keyvault.md`
- `az-managed-identity.md`
