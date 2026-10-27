# Feature Tasks: Integration Plane Foundation

> Ordered implementation tasks. Work top to bottom. Tick each as it lands.

- **Feature id:** 002-integration-plane-foundation
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Scaffold `integration-plane/`: `package.json`, `tsconfig.json`, `host.json` with the Service Bus extension settings and the single-attempt host retry policy, `.funcignore`, and `local.settings.example.json` with every setting name and no value.
- [ ] 2. Write `src/shared/config.ts`: read and validate every setting at first use, throwing with the setting's name on a missing or malformed value.
- [ ] 3. Write `src/shared/telemetry.ts`: the one log shape, with `correlationId` and `bcMessageId` dimensions. No parameter takes a payload body.
- [ ] 4. Write `src/shared/correlation.ts`: read `x-correlation-id`, derive from the business key when absent, and expose it for the envelope, the outbound header, and the log.
- [ ] 5. Write `src/shared/classify.ts`: transient for 408, 429, 5xx, and timeouts; permanent for every other 4xx and for schema failures.
- [ ] 6. Write `src/shared/envelope.ts`: the queue envelope, the `<flow>:<businessKey>` `MessageId` rule, and rejection of a missing business key.
- [ ] 7. Write `src/shared/bcClient.ts`: token through managed identity with audience and scope from configuration, POST to the inbound API page with the idempotency key, and map `201`, `409`, 4xx, and 5xx onto success, duplicate, permanent, and transient.
- [ ] 8. Write the unit tests for tasks 2 to 7, one per acceptance criterion in the plan's test strategy table.
- [ ] 9. Write `infra/modules/observability.bicep`: Log Analytics workspace and Application Insights.
- [ ] 10. Write `infra/modules/storage.bicep`: Function App host storage, HTTPS only, TLS 1.2 minimum, public blob access off.
- [ ] 11. Write `infra/modules/keyvault.bicep`: vault with RBAC authorization and soft delete. It takes no secret values.
- [ ] 12. Write `infra/modules/servicebus.bicep`: namespace plus the four queues, each with dead-lettering on expiration, maximum delivery count 5, duplicate detection on a 1 hour window, and a 5 minute lock duration.
- [ ] 13. Write `infra/modules/functionapp.bicep`: Consumption plan, Function App with a system-assigned identity, HTTPS only, TLS 1.2 minimum, app settings with Key Vault references, and the three role assignments (Key Vault Secrets User, Service Bus Data Sender, Service Bus Data Receiver).
- [ ] 14. Write `infra/modules/alerts.bicep`: action group and a dead-letter message count alert per queue.
- [ ] 15. Write `infra/main.bicep` composing the modules, and `infra/main.dev.bicepparam`. Confirm no secret value appears in either.
- [ ] 16. Write `infra/README.md`: resource group, workload identity federation credential, seeding the three secrets, and registering the Function App identity in BC.
- [ ] 17. Write `.github/workflows/DeployIntegrationPlane.yaml`: federated login, `az deployment group create`, then publish the Function App. Path-filtered to `integration-plane/` and `infra/`.
- [ ] 18. Deploy into an empty resource group and confirm every resource exists and the Function App starts healthy.
- [ ] 19. Prove the managed identity path to BC end to end, since feature 004 depends on it. Record the audience and scope that worked in `infra/README.md`.
- [ ] 20. Run `azure-integration-validator` and resolve its findings.
- [ ] 21. Update the roadmap item to `done` and the feature status.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test or a verified
deployment, `azure-integration-validator` is clean, the managed identity path to BC is
proven rather than assumed, and roadmap item #2 is marked `done`.
