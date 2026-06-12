# Feature Tasks: 004-shipment-confirmation

- **Feature id:** 004-shipment-confirmation
- **Plan:** ./plan.md
- **Status:** done

## Tasks

- [x] 1. Add "Post Invoice" field to WMS Setup table (73298450) and WMS Setup page (73298450).
- [x] 2. Create enumextension "Shipment Confirm. Type" (73298451): add value "WMS Shipment Confirmation" (73298451) to Integration Message Type.
- [x] 3. Create codeunit "Shipment Confirm. Proc." (73298453): implements IIntegration Msg. Processor. Parses JSON, finds Sales Order, resolves SKUs, sets Qty. to Ship, records carrier and tracking, calls Sales-Post, sets Document No.
- [x] 4. Write AL test codeunit covering all acceptance criteria.
- [x] 5. Build and resolve any compiler errors.
- [x] 6. Run mandatory verifier set and resolve findings.
- [x] 7. Update roadmap item to `done`.
