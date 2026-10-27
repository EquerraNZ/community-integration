# Feature Tasks: Outbound Event Dispatch

> Ordered implementation tasks. Work top to bottom. Tick each as it lands.

- **Feature id:** 011-outbound-event-dispatch
- **Plan:** ./plan.md
- **Status:** in-progress

## Tasks

- [x] 1. `src/shared/eventRoutes.ts`: the event name to queue and business key table, as data, with the two events from `005` and `007`.
- [x] 2. `src/functions/receiveBusinessEvent.ts`: answer the subscription validation handshake, look the event name up, enqueue, answer `200`. An unknown name answers `200`, logs, and enqueues nothing.
- [x] 3. `src/shared/sender.ts`: the one sender implementation. Optional read-back from BC, build the request from a configured builder, send with the configured auth and idempotency header, map success, duplicate, transient, and permanent onto complete, complete, rethrow, and dead-letter.
- [x] 4. `src/functions/sendWmsFulfilment.ts`: configure the sender to read the staged outbound message, POST to the WMS with `Idempotency-Key`, and record the `wmsRef`.
- [x] 5. `src/functions/sendWebstoreStatus.ts`: configure the sender to PATCH the storefront order to `Despatched` with the BC order number and the despatch timestamp.
- [x] 6. Unit tests for the router and both senders, one per row of the plan's test strategy table.
- [x] 7. Add the WMS base URL, the WMS key, and the storefront base URL to `local.settings.example.json`, `infra/main.bicep`'s app settings, and `infra/README.md`.
- [ ] 8. Register the two BC external business event subscriptions against the deployed endpoint and confirm the handshake completes.
- [ ] 9. Release an order in BC and confirm exactly one fulfilment request reaches the WMS, with the right idempotency key, and that the `wmsRef` is recorded on the outbound message.
- [ ] 10. Post a shipment and confirm the storefront order shows as despatched with the BC order number.
- [ ] 11. Re-fire both events and confirm no second fulfilment and no visible change on the storefront.
- [ ] 12. Run `azure-integration-validator` and resolve its findings.
- [ ] 13. Update the roadmap item to `done` and the feature status.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test or a verified
run, `azure-integration-validator` is clean, business processes 2 and 4 work end to
end so that an order placed on the storefront comes back marked despatched, and
roadmap item #11 is marked `done`.
