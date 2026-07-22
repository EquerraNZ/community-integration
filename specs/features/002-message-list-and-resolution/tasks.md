# Feature Tasks: Message list and resolution

- **Feature id:** 002-message-list-and-resolution
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Codeunit Integration Resolution Mgt.: Resolve (re-queue), ConfirmByException, Reassign — all reuse the Message ID; telemetry on each.
- [ ] 2. Page Integration Message List: filterable monitor with the three actions and open-card.
- [ ] 3. Page Integration Message Card: detail + classified error + editable payload/type while Failed; the three actions guarded to Failed.
- [ ] 4. Add the new pages and codeunit to the Integration Foundation permission set.
- [ ] 5. AL tests for each acceptance criterion (action outcomes + edit guards).
- [ ] 6. Build, run the mandatory verifier set and a BCQuality review; resolve findings.
- [ ] 7. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
