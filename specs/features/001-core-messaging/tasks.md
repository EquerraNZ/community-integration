# Feature Tasks: Core Messaging

> Ordered implementation tasks. Work top to bottom. Tick each as it lands.

- **Feature id:** 001-core-messaging
- **Plan:** ./plan.md
- **Status:** done

## Tasks

- [x] 1. Create enum "Integration Message Status" (73298400): New, In Progress, Completed, Failed.
- [x] 2. Create enum "Integration Message Type" (73298401): extensible, starts empty (value 0 reserved for unknown/unset if needed).
- [x] 3. Create interface "IIntegration Msg. Processor" with procedure `Process(var IntegrationMessage: Record "Integration Message")`.
- [x] 4. Create table "Integration Message" (73298400): all fields per plan, keys PK/SK1/SK2/SK3, helper procedures for blob read/write.
- [x] 5. Create codeunit "Integration Msg. Process" (73298400): pick up New messages, dispatch by Type via interface, transition Status, catch errors to Error Content/Error Code, emit telemetry (INTMSG-002, INTMSG-003, INTMSG-004).
- [x] 6. Create API page "Integration Messages API" (73298400): POST stages message (idempotency check on Idempotency Key), returns Message ID, emits telemetry (INTMSG-001). GET returns message by ID.
- [x] 7. Create codeunit "Integration Msg. Retry" (73298401): Job Queue handler, filter Failed below MaxRetryCount, reset to New, increment Retry Count, clear error fields, emit telemetry (INTMSG-005).
- [x] 8. Create list page "Integration Messages" (73298401): admin view with Status, Type, Idempotency Key, Correlation ID, Error Code, timestamps. Action: Retry (resets selected message to New).
- [x] 9. Create card page "Integration Message Card" (73298402): detail view showing blob content (Request, Response, Error) as text fields.
- [x] 10. Write AL test codeunit: mock IIntegration Msg. Processor implementation (test enum value + test codeunit), covering all nine acceptance criteria.
- [x] 11. Build and resolve any compiler errors.
- [x] 12. Run mandatory verifier set (al-code-quality-reviewer, al-readability-checker, al-test-coverage-validator, al-test-validator) and resolve findings.
- [x] 13. Update roadmap item to `done`, update feature status.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the
mandatory verifier set is clean, and roadmap item #1 is marked `done`.
