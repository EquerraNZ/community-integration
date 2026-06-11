# Feature Tasks: Webstore order ingest

- **Feature id:** 004-webstore-order-ingest
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Enumextension Webstore Message Types (73298414): add WebstoreOrder (10) implementing the handler. Shared Integration JSON Helper (73298429) for defensive readers.
- [ ] 2. Codeunit Webstore Order Handler: parse payload, guard setup, create Sales Order + lines via SKU mapping, set message Document No. / Response, idempotent existing-order check.
- [ ] 3. Permanent failures for unmapped SKU and missing setup via MessageMgt.CreatePermanentError.
- [ ] 4. Add the handler and required standard sales tabledata to the permission set.
- [ ] 5. AL tests for each acceptance criterion.
- [ ] 6. Build, run the mandatory verifier set and a BCQuality review; resolve findings.
- [ ] 7. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
