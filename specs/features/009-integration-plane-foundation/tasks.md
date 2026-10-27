# Feature Tasks: Integration Plane Foundation

> Ordered implementation tasks. Work top to bottom. Tick each as it lands.

- **Feature id:** 009-integration-plane-foundation
- **Plan:** ./plan.md
- **Status:** in-progress

## Tasks

- [x] 1. Scaffold `integration-plane/`: `package.json`, `tsconfig.json`, `host.json` with the Service Bus extension settings and the single-attempt host retry policy, `.funcignore`, `local.settings.example.json` with every setting name and no value.
- [x] 2. `src/shared/config.ts`: read and validate every setting at first use, throwing with the setting's name on a missing or malformed value.
- [x] 3. `src/shared/telemetry.ts`: the one log shape, with `correlationId` and `bcMessageId` dimensions and no parameter that takes a payload body.
- [x] 4. `src/shared/correlation.ts`: read `x-correlation-id`, derive from the business key when absent, expose it for the envelope, the outbound header, and the log.
- [x] 5. `src/shared/classify.ts`: transient for 408, 429, 5xx, and timeouts; permanent for every other 4xx and for schema failures.
- [x] 6. `src/shared/envelope.ts`: the envelope, the `<flow>:<businessKey>` `MessageId` rule, and rejection of a missing business key.
- [x] 6a. `src/shared/serviceBus.ts` and `src/shared/queueStep.ts`: sending through the SDK so `messageId` and the correlation property can be set, parking a permanent failure, and the rethrow-or-park shape every queue function uses.
- [x] 7. `src/shared/bcClient.ts`: token through managed identity with audience and scope from configuration; stage a message, read a staged outbound message, record a result; map `201`, `409`, 4xx, and 5xx onto success, duplicate, permanent, and transient.
- [x] 8. Unit tests for tasks 2 to 7, one per row of the plan's test strategy table.
- [x] 9. `infra/modules/observability.bicep`: Log Analytics workspace and Application Insights.
- [x] 10. `infra/modules/storage.bicep`: host storage, HTTPS only, TLS 1.2 minimum, public blob access off.
- [x] 11. `infra/modules/keyvault.bicep`: vault with RBAC authorization and soft delete. No secret values.
- [x] 12. `infra/modules/servicebus.bicep`: namespace plus the four flow queues, each with dead-lettering, maximum delivery count 5, duplicate detection on 1 hour, 5 minute lock duration, and the shared `parked` queue with duplicate detection off.
- [x] 13. `infra/modules/functionapp.bicep`: Consumption plan, Function App with system-assigned identity, HTTPS only, TLS 1.2 minimum, app settings with Key Vault references, and the three role assignments.
- [x] 14. `infra/modules/alerts.bicep`: action group and a dead-letter message count alert per queue.
- [x] 15. `infra/main.bicep` composing the modules, and `infra/main.dev.bicepparam`. Confirm no secret value appears in either.
- [x] 16. `infra/README.md`: resource group, workload identity federation credential, seeding the four secrets, registering the Function App identity in BC.
- [x] 17. `.github/workflows/DeployIntegrationPlane.yaml`: federated login, `az deployment group create`, Function App publish, path-filtered to `infra/` and `integration-plane/`.
- [ ] 18. Deploy into an empty resource group and confirm every resource exists and the Function App starts healthy.
- [ ] 19. Prove the managed identity path to BC end to end, since feature 010 depends on it. Record the audience and scope that worked in `infra/README.md`.
- [ ] 20. Run `azure-integration-validator` and resolve its findings.
- [ ] 21. Update the roadmap item to `done` and the feature status.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test or a verified
deployment, `azure-integration-validator` is clean, the managed identity path to BC is
proven rather than assumed, and roadmap item #9 is marked `done`.
