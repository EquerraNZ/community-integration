# Feature Tasks: Integration Foundation

> Produced alongside `plan.md`. An ordered, checkable list the Implement step works
> top to bottom. Tick each as it lands. Patterns are implemented in order;
> summarize after each pattern before moving on.

- **Feature id:** 001-integration-foundation
- **Plan:** ./plan.md
- **Status:** in-progress (tasks 1-35 implemented; task 36 verifier set run and
  findings resolved, build on the AL toolchain still pending; task 37 on merge)

## Tasks

### Pattern 1: Dispatch foundation

- [ ] 1. `app.json`: pin `application 26.0.0.0`, `runtime 15.0`, `platform 1.0.0.0`; fill brief/description; remove the scaffold `HelloWorld.al`.
- [ ] 2. Enums: Integration Direction (440), Integration Status (441) — fixed enums with captions.
- [ ] 3. Interface IIntegrationHandler (`Process`). Default Integration Handler (73298421) implementing it with a clear "no handler registered" error.
- [ ] 4. Enum Integration Type (73298443, extensible) `implements IIntegrationHandler`; Unspecified bound to Default Integration Handler.
- [ ] 5. Table Integration Message (73298400): fields, keys, and blob text accessors. Serves the staging-record acceptance criteria.
- [ ] 6. Codeunit Integration Message Mgt. (73298410): the data-access facade (stage, transition, payload get/set, append log, spawn child).
- [ ] 7. Codeunit Integration Handler Runner (73298412, TableNo): resolve Type to handler, call Process.
- [ ] 8. Codeunit Integration Dispatcher (73298411): Job Queue entry; pick New single-handler messages; run via Codeunit.Run isolation; route outcome. Serves "extensible without framework edits".
- [ ] 9. Pattern 1 summary, then proceed.

### Pattern 2: Duplicate detection

- [ ] 10. Codeunit Integration Idempotency Mgt. (73298413): (External Reference, Type) lookup; Resolved twin replays stored Response; In Progress twin does not start a second run.
- [ ] 11. Wire the idempotency check into staging and into the dispatcher before any side effect. Serves "idempotent dispatch" and "concurrent duplicate is safe".
- [ ] 12. Pattern 2 summary, then proceed.

### Pattern 3: Error classification

- [ ] 13. Enum Integration Error Class (73298442, extensible): Unknown, Transient, Permanent.
- [ ] 14. Interface IErrorClassifier; Default Error Classifier (73298416) rule-based, no AI.
- [ ] 15. Enum Error Classifier Type (73298445, extensible) `implements IErrorClassifier`; Default bound.
- [ ] 16. Codeunit Integration Error Handler (73298414): durable capture after isolated run fails (error text to blob, status Failed, retry count, telemetry). No inline classification.
- [ ] 17. Codeunit Integration Classifier Job (73298415): Job Queue entry; pick Failed + unclassified; run the active classifier from setup. Serves "durable out-of-band capture" and "swappable classifier".
- [ ] 18. Pattern 3 summary, then proceed.

### Pattern 4: Delayed reply

- [ ] 19. Integration Message fields Status URL and the Awaiting Reply status path.
- [ ] 20. Codeunit Integration Reply Mgt. (73298417): park Awaiting Reply with status URL; match a reply by Correlation ID; link reply to request via Parent Message ID. Serves "delayed reply correlates".
- [ ] 21. Pattern 4 summary, then proceed.

### Pattern 5: Durable staged pipeline

- [ ] 22. Interface IIntegrationStage (`Run`, `GetNextStage`). Enum Integration Stage (73298444, extensible) `implements IIntegrationStage`; None (0) and Completed.
- [ ] 23. Codeunit Integration Stage Runner (73298419, TableNo): resolve Current Stage to stage, run it.
- [ ] 24. Codeunit Integration Pipeline Engine (73298418): Job Queue entry; advance one stage at a time via Codeunit.Run; on success set GetNextStage; on failure retry only the current stage. Spawn-child helper sets Parent Message ID. Serves "staged advance and single-stage retry" and "parent/child traceability".
- [ ] 25. Pattern 5 summary, then proceed.

### Pattern 6: Operations and recovery

- [ ] 26. Table Integration Cue (73298403) + Integration Activities cue page (73298454): Failed / In Progress / Awaiting Reply / New counts.
- [ ] 27. Table Integration Message Log (73298402) + enum Integration Log Event (73298446) + Integration Message Log Part (73298453): the audit trail.
- [ ] 28. Page Integration Messages list (73298450): no FlowField columns; navigation; counts via the cue.
- [ ] 29. Page Integration Message Card (73298451): payload viewers, log factbox, and the Retry / Resolve / Resolve by Exception / Reassign actions (each logged and telemetered). Serves "manual recovery actions".
- [ ] 30. Pattern 6 summary, then proceed.

### Cross-cutting and close-out

- [ ] 31. Table Integration Setup (73298401) + Integration Setup page (73298452) + Integration Foundation Install (73298422) seeding setup and cue.
- [ ] 32. Codeunit Integration Telemetry (73298420): all lifecycle events; wire every protected operation to emit. Serves "telemetry on lifecycle".
- [ ] 33. Page Integration Message Entity API (73298455): single inbound staging endpoint; Type routes; no ODataKeyFields. Serves "inbound API page in v1".
- [ ] 34. Permission sets Full (73298460) and Read (73298461) covering every object. Serves "permissions complete".
- [ ] 35. README.md: objects, how dispatch works, how to plug in a new integration type and a new pipeline stage, and the manual smoke-check script.
- [ ] 36. Build, then run the mandatory verifier set and the integration-review playlist and a BCQuality review; resolve findings.
- [ ] 37. Tick the roadmap item to done.

## Done when

Every acceptance criterion in `spec.md` is covered by the documented manual
smoke-check, the verifier set is clean (the zero automated-coverage report is
recorded against the deferred-tests decision, not resolved by a test app), the
extension compiles with no errors, and the roadmap item is marked done.
