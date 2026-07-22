# Feature Tasks: Subscription health monitor

- **Feature id:** 008-subscription-health-monitor
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Table Integration Expected Subscription (Event Name + Notification URL PK).
- [ ] 2. Page Integration Expected Subscriptions (List) to maintain the expected set.
- [ ] 3. Codeunit Subscription Health Monitor: Job Queue OnRun, CheckHealth diff, OnCollectLiveSubscriptions + OnMissingSubscription integration events, INT-0011/INT-0012 telemetry.
- [ ] 4. Add the table, page, codeunit to the Integration Foundation permission set.
- [ ] 5. AL tests for each acceptance criterion (present, missing, empty, no-subscriber).
- [ ] 6. Build, run the mandatory verifier set and a BCQuality review; resolve findings.
- [ ] 7. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
