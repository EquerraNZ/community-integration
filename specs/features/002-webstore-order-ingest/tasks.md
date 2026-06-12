# Feature Tasks: Webstore Order Ingest

> Ordered implementation tasks for the Webstore order ingestion module.

- **Feature id:** 002-webstore-order-ingest
- **Plan:** ./plan.md
- **Status:** done

## Tasks

- [x] 1. Create table "Integration SKU Mapping" (73298420): Source (Code[20]) + External SKU (Code[50]) as PK, Item No. (Code[20]) with TableRelation to Item.
- [x] 2. Create list page "Integration SKU Mapping" (73298420): admin page for managing mappings.
- [x] 3. Create table "Webstore Setup" (73298421): singleton, Customer No. (Code[20]) with TableRelation to Customer, Location Code (Code[10]) with TableRelation to Location.
- [x] 4. Create card page "Webstore Setup" (73298421): admin setup page with Customer No. and Location Code fields.
- [x] 5. Create enumextension "Webstore Order Type" (73298420): add value "Webstore Order" to Integration Message Type with Implementation = "Webstore Order Processor".
- [x] 6. Create codeunit "Webstore Order Processor" (73298420) implementing IIntegration Msg. Processor: parse JSON, resolve SKUs, create Sales Header + Sales Lines, set Integration Message Document No., emit telemetry.
- [x] 7. Write AL test codeunit covering all nine acceptance criteria: valid order creates Sales Order, multi-line, SKU resolved, unmapped SKU fails, duplicate idempotency, Document No. set, missing setup fails, ship-to populated, posting date set.
- [x] 8. Build and resolve any compiler errors.
- [x] 9. Run mandatory verifier set and resolve findings.
- [x] 10. Update roadmap item to `done`.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the
mandatory verifier set is clean, and roadmap item #2 is marked `done`.
