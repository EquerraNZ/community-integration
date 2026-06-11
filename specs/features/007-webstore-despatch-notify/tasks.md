# Feature Tasks: Webstore despatch notify

- **Feature id:** 007-webstore-despatch-notify
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Enumextension Despatch Message Types (73298417, DespatchNotification=40).
- [ ] 2. Add OnShipmentConfirmed_v1 external business event to Integration Outbound Events.
- [ ] 3. Add OutboundExists guard to Integration Message Mgt.
- [ ] 4. Codeunit Despatch Notification Mgt.: idempotent stage + raise from a posted shipment.
- [ ] 5. Codeunit Subs-Sales Shipment: thin subscriber on Sales Shipment Header OnAfterInsertEvent.
- [ ] 6. Add the new codeunits to the Integration Foundation permission set.
- [ ] 7. AL tests for each acceptance criterion.
- [ ] 8. Build, run the mandatory verifier set (incl. al-event-subscriber-auditor) and a BCQuality review; resolve findings.
- [ ] 9. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
