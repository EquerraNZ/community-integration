---
bc-version: [all]
domain: integration
keywords: [azure, key-vault, secrets, connection-string, credentials, bicep, managed-identity, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Keep external credentials in Key Vault

## Description

The whole reason the integration plane exists is to keep external credentials out of Business Central. That purpose is defeated the moment those credentials are pasted inline instead, into a Bicep parameter literal, an app setting value, a Logic App connection definition, or a Terraform variable committed to the repo. A secret in source is a secret leaked: it lands in git history, in deployment logs, in the portal's plain-text app settings, and in every reviewer's clone. Secrets belong in Key Vault, and components read them at runtime through a reference resolved with their Managed Identity, so the secret value never appears in a template, a pipeline variable, or a committed file.

This pairs with `az-managed-identity.md`: Key Vault holds the secret, Managed Identity is how a component is allowed to read it without a second secret to bootstrap the first.

## Best Practice

Store every external credential and connection string in Key Vault. In Bicep, reference it with the `getSecret()` function or an `existing` Key Vault resource, never an inline literal. In app settings, use a `@Microsoft.KeyVault(...)` reference so the portal shows a reference, not the value. Grant the component's Managed Identity the minimal Key Vault role (Secrets User) rather than a broad policy. Rotate secrets in the vault without redeploying the consumers. See `az-secrets-in-keyvault.good.bicep`.

## Anti Pattern

A credential supplied as an inline Bicep/ARM parameter default, an app setting literal, or a connection string hard-coded in a Logic App connection or Terraform file. The detection signal: a secret-shaped value (API key, password, connection string, SAS token, client secret) assigned as a literal in IaC or app config rather than sourced from Key Vault. The consequence is the secret in git history and deployment logs, where rotating it means scrubbing history, not just updating a vault. See `az-secrets-in-keyvault.bad.bicep`.

## See also

- `az-managed-identity.md`
- `az-https-only.md`
