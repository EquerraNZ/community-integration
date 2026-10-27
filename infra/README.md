# infra/

The Azure integration layer's infrastructure. One resource group per environment,
one template, parameters per environment. Nothing is created in the portal, so an
environment can always be rebuilt from here.

What it provisions, and why each piece is there, is in
`specs/tech-design.md` under "Azure integration layer". This file is the operator's
side: the steps the pipeline cannot do for you.

## Layout

```
infra/
  main.bicep              one environment, composing the modules
  main.dev.bicepparam     dev's values. No secrets, ever.
  modules/
    observability.bicep   Log Analytics workspace and Application Insights
    storage.bicep         the Function App host's storage
    keyvault.bicep        the vault, created empty
    servicebus.bicep      the namespace, four flow queues, and the parked queue
    functionapp.bicep     the plan, the app, its identity, and its role assignments
    alerts.bicep          the action group and the dead-letter, parked, and drift alerts
```

## One-off steps for a new environment

The pipeline deploys the template. These four are yours, and nothing works until
they are done.

### 1. The resource group

The template is resource-group scoped and does not create its own group, so the
group's name, location, tags, and policy are decided where they should be rather
than by a deployment.

```bash
az group create --name rg-intplane-dev-aue --location australiaeast
```

### 2. The pipeline's credential

Workload identity federation, so nothing secret is stored in GitHub. Create an app
registration, add a federated credential for this repository and branch, and grant
it Contributor plus User Access Administrator on the resource group. User Access
Administrator is needed because the template creates role assignments, and it is
scoped to the one group for that reason.

Then set three repository variables, none of which is a secret:
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

### 3. The four external secrets

Written by a person with access, directly into the vault. The pipeline never sees
them and the template never takes them as parameters, which is why
`main.dev.bicepparam` has no secret in it and must stay that way.

```bash
az keyvault secret set --vault-name kv-intplane-dev-aue --name webstore-ingest-key --value '<value>'
az keyvault secret set --vault-name kv-intplane-dev-aue --name webstore-status-key --value '<value>'
az keyvault secret set --vault-name kv-intplane-dev-aue --name wms-api-key         --value '<value>'
az keyvault secret set --vault-name kv-intplane-dev-aue --name wms-callback-key    --value '<value>'
```

| Secret | Used for |
|---|---|
| `webstore-ingest-key` | What the storefront must present to `POST /api/webstore/orders`. |
| `webstore-status-key` | What the plane presents when it PATCHes the storefront order to `Despatched`. |
| `wms-api-key` | What the plane presents when it POSTs a fulfilment request. |
| `wms-callback-key` | What the WMS must present to `POST /api/wms/shipments`. |

### 4. Registering the plane in Business Central

The Function App's managed identity is the only credential the plane has for BC.
Take `functionAppPrincipalId` from the deployment output, register it in BC as an
Entra application, and grant it the Integration Foundation permission set. It needs
to stage an inbound message, read a staged outbound message, record a result on
one, and list and create business event subscriptions.

**This is the least proven part of the plane** (tech design questions 6 and 8).
`BC_TOKEN_SCOPE` is a parameter precisely so that settling it is a parameter
change rather than a code change. When you have a working value, record it here:

```
Audience / scope that worked:   <fill in>
BC permission set granted:      <fill in>
Registered on:                  <fill in>
```

## Deploying by hand

The workflow does this, and it is worth being able to run it yourself when
something is wrong.

```bash
az deployment group what-if --resource-group rg-intplane-dev-aue --template-file infra/main.bicep --parameters infra/main.dev.bicepparam
```

```bash
az deployment group create --resource-group rg-intplane-dev-aue --template-file infra/main.bicep --parameters infra/main.dev.bicepparam
```

## Things worth knowing before you change something

- **Duplicate detection cannot be changed after a queue is created.** Changing
  `duplicateDetectionWindow` means deleting and recreating the queue, which drops
  anything on it. It is set to one hour deliberately: BC's dedup on
  `(External Reference, Type)` is the durable authority, and the broker is not a
  place to keep business state.
- **The retry budget is `maxDeliveryCount`, and only that.** The Functions host
  retry policy in `integration-plane/host.json` is one attempt on purpose. Raising
  it multiplies: five deliveries times five host retries is twenty-five calls to a
  struggling external system.
- **`disableLocalAuth` is on for the namespace.** There is no connection string to
  fall back to, which is the point. If a trigger cannot connect, the role
  assignment is what to look at.
- **The parked queue has duplicate detection off.** The same business key must be
  able to park twice from two different failures, and detection would hide the
  second.
- **Secrets are app settings that are Key Vault references.** The Function App
  never calls the vault in code and holds no vault client. If a setting reads back
  as the literal `@Microsoft.KeyVault(...)` string, the identity is missing its
  Key Vault Secrets User role.
