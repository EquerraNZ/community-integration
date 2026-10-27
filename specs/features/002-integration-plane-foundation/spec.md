# Feature Spec: Integration Plane Foundation

> The shared Azure plane. Everything that crosses the BC boundary runs on this.

- **Feature id:** 002-integration-plane-foundation
- **Roadmap item:** #2 in specs/roadmap.md
- **Status:** spec

## Problem

The extension deliberately makes no outbound HTTP call and holds no external
credential, so on its own it cannot reach the Webstore or the WMS, and nothing can
reach it. Something outside BC has to terminate those connections, hold the keys,
guarantee delivery, and retry safely.

Without a shared plane, each integration would build its own receiver, its own retry,
its own secret handling, and its own logging, which is the same duplication on the
Azure side that feature 001 exists to prevent on the BC side. This feature is the
plane's equivalent of the core: no flow of its own, but every flow depends on it.

## Users and roles

- **Integration developer:** adds a receiver and a sender for a new external system
  on top of this foundation, without provisioning anything or writing retry,
  correlation, or authentication code again.
- **Operations:** watches dead-letter depth and the health alert, replays a
  dead-lettered message, and reads one correlation id across every hop.
- **Deployment pipeline:** creates and updates every resource in an environment from
  this repository, with no portal step.

## Scope

- A resource-group scoped Bicep template that provisions, for one environment:
  - a Service Bus namespace with the four queues (`inbound-webstore-order`,
    `inbound-wms-shipment`, `outbound-wms-fulfilment`, `outbound-webstore-status`),
    each with dead-lettering on, a maximum delivery count, and duplicate detection;
  - a Key Vault holding the external credentials, with no secret value in the
    template or its parameters;
  - a storage account for the Function App host;
  - a Log Analytics workspace and an Application Insights resource;
  - a Function App on a Consumption plan with a system-assigned managed identity, and
    the role assignments that identity needs (Key Vault Secrets User, Service Bus Data
    Sender and Receiver);
  - alert rules on dead-letter message count.
- A Function App project with no flows yet, carrying the shared pieces every flow uses:
  - a configuration reader that fails fast and loudly on a missing setting;
  - correlation handling: read an inbound correlation id, carry it on the queue
    message, set it on outbound calls, and put it on every log entry;
  - a failure classifier that decides transient against permanent;
  - a BC client that acquires a token for the Function App's managed identity and
    posts a message to the extension's inbound API page;
  - the envelope the plane puts on a queue, so every receiver and sender agrees on it.
- A deployment workflow that authenticates without a stored secret, deploys the Bicep,
  and publishes the Function App.
- Unit tests over the shared pieces: classification, correlation, envelope, and the BC
  client's handling of each response class.
- A README in `infra/` covering the one-off steps a new environment needs: the
  resource group, the workload identity federation credential, the secret values, and
  registering the plane's identity in BC.

## Out of scope

- Any actual flow. No Webstore receiver, no WMS sender, no business event routing.
  Those are features 004, 006, 008, and 010.
- The subscription health check and its alert rule, which is feature 011.
- A second environment and promotion between environments.
- Replaying a dead-lettered message from inside BC.

## User flow

This feature has no end-user flow. Its flow is the developer's and the pipeline's:

1. An operator creates the resource group and the federated credential once, and
   writes the three external secrets into Key Vault.
2. A push to the default branch runs the workflow, which deploys the Bicep and
   publishes the Function App.
3. An integration developer adds a function for a new flow. The queue, the identity,
   the secrets, the logging, the retry policy, and the BC client are already there.
4. Operations opens Application Insights, searches one correlation id, and sees every
   step the plane took for it.

## Acceptance criteria

- [ ] Given an empty resource group, when the workflow runs, then every resource in
      scope exists and the Function App starts healthy, with no portal step.
- [ ] Given the deployed plane, when the template or its parameter files are searched,
      then no secret value appears in either; every secret is a Key Vault reference.
- [ ] Given the Function App, when it reads a secret, then it does so through its
      managed identity, and removing the role assignment makes the read fail.
- [ ] Given a message put on any of the four queues, when it cannot be delivered after
      the maximum delivery count, then it lands on that queue's dead-letter queue with
      its body and properties intact, and the alert rule fires.
- [ ] Given a response of 408, 429, 500, 502, 503, or 504, or a timeout, when the
      classifier runs, then it reports transient.
- [ ] Given a response of 400, 401, 403, 404, 409, or 422, when the classifier runs,
      then it reports permanent.
- [ ] Given an inbound request carrying `x-correlation-id`, when the plane handles it,
      then that value appears as a queue message property, on the outbound call, and as
      a custom dimension on every log entry for that message.
- [ ] Given an inbound request with no correlation header, when the plane handles it,
      then it derives a correlation id from the payload's business key rather than
      inventing an unrelated one.
- [ ] Given the BC client and a staged message, when BC answers `201`, then the
      returned BC message id is recorded on the log entry for that correlation id.
- [ ] Given a missing or malformed configuration setting, when the Function App
      starts or the setting is first read, then it fails with a message naming the
      setting, rather than failing later with a null.

## Data and rules

The plane holds no business state. The only data it owns is the envelope it puts on a
queue, which must be enough for any sender or stager to do its work without calling
back to the source:

| Field | Rule |
|---|---|
| `flow` | Which flow this message belongs to. Drives the queue and the BC message type. |
| `businessKey` | The external system's stable id: the Webstore `orderNo`, the WMS `shipmentId`. Used as the idempotency key and as part of the Service Bus `MessageId`. |
| `correlationId` | The Webstore order number, carried end to end. Never regenerated once set. |
| `receivedAt` | When the plane accepted the message, not when the source created it. |
| `source` | Which external system or BC event it came from. |
| `payload` | The original body, unaltered. The plane does not reshape a payload before it is staged. |

Rules:

- A receiver that cannot authenticate the caller returns `401` and enqueues nothing.
- A receiver that cannot find a business key in the payload returns `400` and enqueues
  nothing, because without one the message cannot be deduplicated anywhere.
- The Service Bus `MessageId` is `<flow>:<businessKey>`, so the broker discards an
  exact redelivery inside the detection window.
- A permanent failure in a queue-triggered function dead-letters the message with a
  reason and returns. It never rethrows, because rethrowing means retry.
- A transient failure rethrows and does nothing else, so retry is the broker's
  decision and its budget is configured in one place.

## Telemetry and audit

Every step logs with `correlationId` and, once known, the BC message id as custom
dimensions:

- receiver accepted, with flow and business key;
- receiver rejected, with the reason and the status returned;
- queue message enqueued;
- delivery attempt started, with the delivery count;
- delivery succeeded, with the downstream status;
- delivery failed, with the classification and whether it was dead-lettered.

No payload body and no personal data is logged. The Webstore payload carries a
shopper's name, email, phone, and address; none of it goes into telemetry.

## Open questions

1. The exact BC API and token audience for posting to the extension's inbound API page
   with a managed identity, and the BC-side registration step that grants it. Blocks
   the BC client.
2. The duplicate detection window, which cannot be changed after the queue is created.
3. Whether the retry budget lives in the Service Bus maximum delivery count or the
   Functions host retry policy. Both retry, and only one should.
