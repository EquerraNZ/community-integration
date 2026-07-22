# Feature Tasks: SKU to Item mapping

- **Feature id:** 003-sku-item-mapping
- **Plan:** ./plan.md
- **Status:** planned

## Tasks

- [ ] 1. Table Integration SKU Mapping: SKU PK, Item No./Variant/UoM with TableRelation, reverse key on (Item No., Variant Code).
- [ ] 2. Page Integration SKU Mappings (List) to maintain mappings.
- [ ] 3. Codeunit Integration SKU Mgt.: TryGetItem / GetItem (clear error) forward, TryGetSku reverse.
- [ ] 4. Add the new objects to the Integration Foundation permission set.
- [ ] 5. AL tests for each acceptance criterion.
- [ ] 6. Build, run the mandatory verifier set and a BCQuality review; resolve findings.
- [ ] 7. Update feature docs and tick the roadmap item.

## Done when

Every acceptance criterion in `spec.md` is covered by a passing test, the verifier
set is clean, and the roadmap item is marked done.
