# Feature Tasks: WMS shipment confirmation

- **Feature id:** 006-wms-shipment-confirmation
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Enumextension WMS Message Types (73298416, WmsShipmentConfirmation=20) implementing the handler.
- [ ] 2. Codeunit WMS Shipment Handler: parse, find order, set Qty. to Ship per line, record tracking, link parent by correlation, post (Sales-Post, suppress commit), record shipment no., resolve.
- [ ] 3. Permanent failures for unmapped SKU / missing order; partial-ship and invoice-toggle handling.
- [ ] 4. Add the handler and posting tabledata to the permission set.
- [ ] 5. AL tests for each acceptance criterion.
- [ ] 6. Build, run the mandatory verifier set and a BCQuality review; resolve findings.
- [ ] 7. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
