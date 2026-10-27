# Feature Tasks: Plane Health and Alerting

> Ordered implementation tasks. Work top to bottom. Tick each as it lands.

- **Feature id:** 012-plane-health-and-alerting
- **Plan:** ./plan.md
- **Status:** in-progress

## Tasks

- [x] 1. `src/shared/eventRoutes.ts`: export the expected subscription set derived from the routing table, so there is no second list.
- [x] 2. `src/shared/bcClient.ts`: add `listEventSubscriptions` and `createEventSubscription`.
- [x] 3. `src/shared/subscriptionHealth.ts`: the pure comparison. Expected against actual, returning what is missing and why, treating a different notification endpoint as missing.
- [x] 4. `src/functions/checkSubscriptionHealth.ts`: the six-hourly timer. List, compare, re-register what is missing, log the outcome. Report failure rather than health when the list call fails.
- [x] 5. Unit tests for tasks 1, 3, and 4, one per row of the plan's test strategy table.
- [x] 6. `infra/modules/alerts.bicep`: add the drift and check-failure log alerts beside the dead-letter metric alerts.
- [ ] 7. Deploy, then force each condition: delete a subscription and confirm it is re-registered and the drift alert fires; dead-letter a message and confirm that queue's alert fires.
- [ ] 8. Confirm a healthy run raises nothing, so the alerts stay worth reading.
- [ ] 9. Confirm the identity's permission to list and create subscriptions, and record it in `infra/README.md` if it differs from staging a message.
- [ ] 10. Run `azure-integration-validator` and resolve its findings.
- [ ] 11. Update the roadmap item to `done` and the feature status.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test or a forced
condition, `azure-integration-validator` is clean, a deleted subscription is
re-registered within six hours with an alert, a dead-lettered message raises one, a
healthy run raises none, and roadmap item #12 is marked `done`.
