# Feature Tasks: Integration Message core

> Produced by `/al-plan-feature` alongside `plan.md`. An ordered, checkable list the
> Implement step works top to bottom. Keep tasks small and verifiable. Tick each
> as it lands.

- **Feature id:** 001-integration-message-core
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Enums: Direction, Msg. Status, Error Class, and extensible Message Type — the routing and lifecycle vocabulary.
- [ ] 2. Interface `IIntegrationMessageHandler` with `HandleMessage(var Integration Message)`.
- [ ] 3. Table Integration Message: fields, PK, unique idempotency key, dispatch work key, DataClassification on every field.
- [ ] 4. Table + page Integration Setup (singleton) with auto-insert.
- [ ] 5. Codeunit Integration Telemetry: LogMessage wrapper with standard custom dimensions, no PII.
- [ ] 6. Codeunit Integration Message Mgt.: StageInbound (dedup + correlation), blob get/set, MarkInProgress/Resolved/Failed, error classification, retry bump, audit stamping. The single data-access seam.
- [ ] 7. Codeunit Integration Msg. Dispatcher: Job Queue entry point, read New inbound by dispatch key, per-message Codeunit.Run, route by Type through the interface, no-handler Permanent failure.
- [ ] 8. Page Integration Message API: single inbound endpoint, forced Direction/Status, dedup via mgt codeunit, keyed on SystemId.
- [ ] 9. Permission set Integration Foundation covering every new object.
- [ ] 10. Telemetry on every protected operation named in the spec.
- [ ] 11. Test app (Integration Foundation.Test) + AL tests for each acceptance criterion, with a configurable test handler stub.
- [ ] 12. Build, then run the mandatory verifier set and a BCQuality review; resolve findings.
- [ ] 13. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
