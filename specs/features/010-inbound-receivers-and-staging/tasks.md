# Feature Tasks: Inbound Receivers and Staging

> Ordered implementation tasks. Work top to bottom. Tick each as it lands.

- **Feature id:** 010-inbound-receivers-and-staging
- **Plan:** ./plan.md
- **Status:** in-progress

## Tasks

- [x] 1. `src/shared/receiver.ts`: the one receiver implementation. Authenticate against a named secret, read or derive the correlation id, find the business key by a configured path, build the envelope, send, answer `202`. Returns `401` and `400` without sending.
- [x] 2. `src/shared/stager.ts`: the one stager implementation. Build the inbound envelope for a configured `messageType`, call the BC client, and map success, duplicate, transient, and permanent onto complete, complete, rethrow, and dead-letter.
- [x] 3. `src/functions/receiveWebstoreOrder.ts`: configure the receiver for `orderNo`, the ingest key, and `inbound-webstore-order`.
- [x] 4. `src/functions/receiveWmsShipment.ts`: configure the receiver for `shipmentId`, the WMS callback key, `reference` as the correlation source, and `inbound-wms-shipment`.
- [x] 5. `src/functions/stageWebstoreOrder.ts`: configure the stager for `WebstoreOrder` on `inbound-webstore-order`.
- [x] 6. `src/functions/stageWmsShipment.ts`: configure the stager for `WmsShipmentConfirmation` on `inbound-wms-shipment`.
- [x] 7. Unit tests for both receivers and both stagers, one per row of the plan's test strategy table.
- [x] 8. Add the two new secret names to `local.settings.example.json`, `infra/main.bicep`'s app settings, and `infra/README.md`.
- [ ] 9. Deploy and run both flows against the real storefront and a WMS stub, confirming a Sales Order and a posted shipment in BC.
- [ ] 10. Confirm a double post produces one Sales Order, and that a BC outage dead-letters rather than loses the order.
- [ ] 11. Run `azure-integration-validator` and resolve its findings.
- [ ] 12. Update the roadmap item to `done` and the feature status.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test or a verified
run, `azure-integration-validator` is clean, business processes 1 and 3 work end to
end from the storefront to a posted BC document, and roadmap item #10 is marked
`done`.
