# Feature Tasks: Fulfilment request event

- **Feature id:** 005-fulfilment-request-event
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Enum Integration Event Category (73298418) and enumextension Fulfilment Message Types (73298415, FulfilmentRequest=30).
- [ ] 2. Codeunit Integration Outbound Events: OnSalesOrderReleased_v1 external business event (Category, Version '1.0').
- [ ] 3. Codeunit Fulfilment Request Mgt.: build DTO (reverse SKU map), stage outbound parent, raise event.
- [ ] 4. Codeunit Subs-Sales Release: thin subscriber on OnAfterReleaseSalesDoc with early exits, delegating to the mgt codeunit.
- [ ] 5. Add the new codeunits to the Integration Foundation permission set.
- [ ] 6. AL tests for each acceptance criterion.
- [ ] 7. Build, run the mandatory verifier set (incl. al-event-subscriber-auditor) and a BCQuality review; resolve findings.
- [ ] 8. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
