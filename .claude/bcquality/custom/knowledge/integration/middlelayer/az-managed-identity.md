---
bc-version: [all]
domain: integration
keywords: [azure, managed-identity, rbac, authentication, connection-string, shared-key, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Authenticate with Managed Identity, not static keys

## Description

Every static key or connection string is a secret that has to be stored, rotated, and eventually leaked. Managed Identity removes the secret entirely: the platform issues and rotates the credential, and the component authenticates as itself with no key to hold. For plane-to-BC auth, plane-to-Service-Bus, plane-to-Storage, plane-to-Key-Vault, and plane-to-Azure-resource calls generally, Managed Identity is the default and a static key is the exception that needs justifying. A connection string with an embedded shared key is both a secret-management problem (see `az-secrets-in-keyvault.md`) and an over-grant problem: shared keys usually carry far more access than the component needs, where an RBAC role assignment can be scoped to exactly the one queue or one secret it uses.

The two rules reinforce each other: Key Vault is where a secret lives when one is genuinely unavoidable; Managed Identity is what lets a component read that secret, and most others, without any secret of its own.

## Best Practice

Give each plane component a system-assigned (or a dedicated user-assigned) Managed Identity and grant it the least-privilege RBAC role on each resource it touches: Service Bus Data Sender/Receiver on the specific entity, Key Vault Secrets User on the specific vault, Storage Blob Data Contributor on the specific container. Use the identity for BC auth where the BC API supports Azure AD. Fall back to a key only where a service has no AAD support, and then keep that key in Key Vault. See `az-managed-identity.good.bicep`.

## Anti Pattern

A component wired to Service Bus, Storage, or BC with a connection string or shared access key instead of a Managed Identity, especially a namespace-level `RootManageSharedAccessKey` that grants full control. The detection signal: an `AzureWebJobsServiceBus`/`*ConnectionString` app setting carrying a shared key, a `listKeys()` call feeding a connection string into config, or a SAS-based connection where an RBAC role assignment would do. The consequence is a long-lived over-privileged secret that must be rotated by hand and grants more than the component needs. See `az-managed-identity.bad.bicep`.

## See also

- `az-secrets-in-keyvault.md`
- `az-https-only.md`
