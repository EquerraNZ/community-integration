# Feature Spec: Integration Plane Foundation

> The Azure plane's equivalent of `001`: no flow of its own, and every flow
> depends on it.

- **Feature id:** 009-integration-plane-foundation
- **Roadmap item:** #9 in specs/roadmap.md
- **Status:** in-progress

## Problem

Features 001 to 008 built an extension that deliberately makes no outbound HTTP call
and holds no external credential. That is the right design, and on its own it is inert:
nothing calls the API page, nothing consumes the external business events, and the
subscription monitor has no subscriber to watch.

Something outside BC has to terminate the Webstore and WMS connections, hold the keys,
guarantee delivery once it has accepted a message, and retry without duplicating. If
each flow built that for itself, the Azure side would repeat the duplication that `001`
exists to prevent on the BC side. This feature is the shared plane: the resources, the
identity, and the handful of helpers every flow reuses.

## Users and roles

- **Integration developer:** adds a receiver or a sender for a flow without
  provisioning anything, and without writing retry, correlation, authentication, or
  logging again.
- **Operations:** watches dead-letter depth, replays a dead-lettered message, and
  follows one correlation id across every hop in Application Insights.
- **Deployment pipeline:** creates and updates every resource in an environment from
  this repository, with no portal step.

## Scope

- A resource-group scoped Bicep template provisioning one environment:
  - Service Bus Standard namespace and the four flow queues
    (`inbound-webstore-order`, `inbound-wms-shipment`, `outbound-wms-fulfilment`,
    `outbound-webstore-status`), each with dead-lettering on, maximum delivery count
    5, and duplicate detection, plus the shared `parked` queue for what the plane has
    decided not to retry;
  - Key Vault with RBAC authorization, holding the four external secrets, with no
    secret value in the template or its parameters;
  - a storage account for the Function App host, HTTPS only, TLS 1.2 minimum;
  - a Log Analytics workspace and an Application Insights resource;
  - a Consumption plan and a Function App with a system-assigned managed identity,
    HTTPS only, TLS 1.2 minimum, and the role assignments that identity needs;
  - an action group and a dead-letter message count alert per queue.
- A Function App project with the shared pieces and no flows: configuration,
  correlation, failure classification, the queue envelope, telemetry, and the BC
  client (stage a message, read a staged outbound message, record a result).
- A deployment workflow authenticating with workload identity federation, deploying
  the Bicep, then publishing the Function App.
- Unit tests over everything in `src/shared/`.
- `infra/README.md` covering the one-off steps a new environment needs.

## Out of scope

- Any flow. The receivers, stagers, senders, and routing are features 010 and 011.
- The subscription health check and its alert, which is feature 012.
- A second environment, and promotion between environments.
- Replaying a dead-lettered message from inside BC (parked, open question 9).

## User flow

No end-user flow. The flow is the developer's and the pipeline's:

1. An operator creates the resource group and the federated credential once, and
   writes the four external secrets into Key Vault.
2. A push that touches `infra/` or `integration-plane/` runs the workflow, which
   deploys the Bicep and publishes the Function App.
3. A developer adds a function for a flow. The queue, the identity, the secrets, the
   logging, the retry policy, and the BC client are already there.
4. Operations searches one correlation id in Application Insights and sees every step
   the plane took for it.

## Acceptance criteria

- [ ] Given an empty resource group, when the workflow runs, then every resource in
      scope exists and the Function App starts healthy, with no portal step.
- [ ] Given the deployed plane, when the template and its parameter files are
      searched, then no secret value appears in either; every secret is a Key Vault
      reference.
- [ ] Given the Function App, when it reads a secret, then it does so through its
      managed identity, and removing the role assignment makes the read fail.
- [ ] Given a message that cannot be delivered after 5 attempts, then it lands on that
      queue's dead-letter queue with its body and properties intact, and the alert
      fires.
- [ ] Given a failure the plane has judged permanent, then the message lands on the
      `parked` queue with its reason and classification attached, is not retried, and
      raises the parked alert.
- [ ] Given a 408, 429, 500, 502, 503, or 504, or a timeout, when the classifier runs,
      then it reports transient.
- [ ] Given a 400, 401, 403, 404, or 422, when the classifier runs, then it reports
      permanent.
- [ ] Given a 409 from a BC staging POST, when the BC client runs, then it reports
      success with the existing message id, not a failure.
- [ ] Given an inbound request carrying `x-correlation-id`, then that value appears as
      a queue message property, on the outbound call, and on every log entry.
- [ ] Given an inbound request with no correlation header, then the correlation id is
      derived from the business key rather than invented.
- [ ] Given an envelope with no business key, then building it fails, because without
      one the message cannot be deduplicated anywhere.
- [ ] Given a missing or malformed setting, then the failure names the setting.

## Data and rules

The plane holds no business state. The only shape it owns is the queue envelope, in
`specs/contracts/integration-contract.md` under "The queue envelope". Rules:

- A receiver that cannot authenticate its caller returns `401` and enqueues nothing.
- A receiver that finds no business key returns `400` and enqueues nothing.
- The Service Bus `MessageId` is `<flow>:<businessKey>`.
- A permanent failure in a queue-triggered function is parked with a reason and the
  message completed. It never rethrows, because rethrowing means retry. It parks
  rather than dead-letters because the Node worker cannot settle a message
  explicitly; the two land in the same place operationally.
- A transient failure rethrows and does nothing else, so the retry budget stays in one
  place: the queue's delivery count.

## Telemetry and audit

Every step logs through one helper, with `correlationId` and, once known,
`bcMessageId` as custom dimensions: receiver accepted, receiver rejected (with the
status returned), enqueued, delivery started (with the delivery count), delivery
succeeded (with the downstream status), delivery failed (with the classification and
whether it was dead-lettered).

No payload body and no personal data is logged. The Webstore payload carries a
shopper's name, email, phone, and address, and none of it goes into telemetry.

## Open questions

1. The BC token audience and scope for a managed identity calling the API page, and
   the BC-side registration that grants it (tech design question 6). The BC client
   reads both from configuration, so settling them is a parameter change, but the path
   has to be proven before feature 010 depends on it.
2. The duplicate detection window, which cannot be changed after the queue is created
   (tech design question 7).
3. The read path for a staged outbound message and the permission it needs (tech
   design question 8). Feature 011 depends on it.
