# Elevate Shipping, Test Guide

The companion to `USER_GUIDE.md`. The user guide covers the happy path for users; this guide covers the **state pivots, edge cases, and audit categories** the happy path is structurally blind to.

Every category below catches a class of bug. For each category, this guide:

1. Defines the category and what it catches.
2. Lists the procedure to exercise it.
3. Inventories every field, flow, or surface in the extension that falls into the category.

When adding a new feature, triage it against every category in §0 and add the new field/flow to each applicable inventory. When running a release pass, exercise every entry in every inventory.

---

## 0. Category index

| # | Category | What it catches |
|---|---|---|
| 1 | Lookup audit (happy + inline-create) | Noisy auto-create dialogs, missing QuickEntry, mandatory PK asterisks |
| 2 | Type-conditional TableRelation | Lookup target swap by sibling type/subtype, broken validation per type |
| 3 | Eligibility filters on lookups | Pick-then-error: lookup lists records that downstream code rejects |
| 4 | Visibility / Editable conditionals | UI state vars that don't refresh on the pivot they depend on |
| 5 | StandardDialog Mode pivots | Each Mode value untested end-to-end, hidden fields stay editable |
| 6 | Subpage FK persistence | SubPageLink not propagating PK on inserted rows |
| 7 | State machine transitions | Each documented transition + each documented rejection |
| 8 | Permission boundaries | Each permission set's RIMD claims actually hold |
| 9 | Telemetry events | Each documented event fires with the documented payload |
| 10 | Mobile / tablet smoke | Pages render without horizontal scroll on 375px viewport |
| 11 | Cross-company isolation | Singletons (Setup, No. Series state) don't leak across companies |
| 12 | Upgrade paths | Schema changes preserve data across version-to-version installs |

---

## 1. Lookup audit (happy + inline-create)

**Catches:** noisy auto-create dialogs, missing `QuickEntry`, mandatory red-asterisk on auto-series PKs, optional-metadata fields in inline-create dialogs.

**Procedure.** For every TableRelation lookup field exposed on a user-facing page, exercise **both** paths:

1. **Happy path.** Open the lookup list, pick an existing record. Verify cascading auto-fill works (e.g. Container Type → Tare Weight / Internal Volume).
2. **Inline-create path.** Type a value that does not exist, accept BC's "Do you want to create…?" prompt, and confirm the inline-create dialog:
   - Shows only fields the user must fill (`QuickEntry = true`).
   - Has no auto-assigned PK fields (`No.` driven by a No. Series).
   - Has no optional metadata (Notes, Last Date Modified, Assignment Count, full Address block, etc.).
   - Has no red asterisks on fields that auto-populate.
   - `Cancel` returns to the original field with no orphan record.
   - `OK` creates a record visible on the master list page.

**Fix when broken.** Set `QuickEntry = false` on the offending fields on the target Card page. Default every auto-series, auto-derived, or optional metadata field to `QuickEntry = false` from the start on any new Card page.

**Inventory:**

| Source field | Target table | Target Card page |
|---|---|---|
| Freight Movement Line → Container No. | Shipping Container | `Container Card_SHP_EQL` |
| Freight Movement Line → Booked Container Type Code | Container Type | (BC list) |
| Freight Movement → Freight Carrier Code | Freight Carrier | `Freight Carrier Card_SHP_EQL` |
| Freight Movement → Shipping Agent Code | Shipping Agent | (BC standard) |
| Freight Movement → Port of Loading / Port of Discharge | Other Place | `Other Place Card_SHP_EQL` |
| Movt Ln / Doc Line Packing Spec → Pack UoM Code | Unit of Measure | (BC standard) |

---

## 2. Type-conditional TableRelation

**Catches:** lookup target swap by sibling type/subtype selector, broken validation per type, orphan-code after type change, wrong-target inline-create per type.

**Procedure.** For each type-conditional field, exercise **every** value of the selector. Each value is effectively a separate lookup. Per value:

- Lookup list opens against the correct target table.
- Validation rejects codes that don't exist in that target.
- Changing the type after a code is set blanks the code (no orphan reference).
- Inline-create dialog (where allowed) targets the correct Card page for the chosen type.
- The combined happy + inline-create audit from §1 applies per value.

**Run-time floor.** 4 values × 2 paths = 8 runs per Origin / Destination field. 3 values × 2 paths = 6 runs per Linkage Source Type. Skipping non-default type values is the most common way this category quietly regresses.

**Inventory:**

| Selector | Source field | Selector value → target |
|---|---|---|
| Freight Movement → Origin Type | Origin Code | Vendor → Vendor, Customer → Customer, Location → Location, Other Place → `Other Place_SHP_EQL` |
| Freight Movement → Destination Type | Destination Code | Vendor → Vendor, Customer → Customer, Location → Location, Other Place → `Other Place_SHP_EQL` |
| Document Line Linkage → Source Type | Source Document No. / Source Line No. | Sales → Sales Header / Sales Line, Purchase → Purchase Header / Purchase Line, Transfer → Transfer Header / Transfer Line |

---

## 3. Eligibility filters on lookups

**Catches:** pick-then-error. A lookup lists records that downstream code rejects at OK time. The user picks one, hits OK, gets a wall of error, has no idea which other records would have worked.

**Procedure.** For every lookup whose downstream `OnValidate` / OK handler rejects a subset of the target table, confirm the lookup itself pre-filters out the rejected subset. Verify by:

1. Creating one record in each disallowed state and one in an allowed state.
2. Opening the lookup; the disallowed records must not appear.
3. Confirming the OK-time validation still rejects if someone bypasses the lookup (e.g. typing the code directly).

**Inventory:**

| Lookup | Rejected at OK time | Should pre-filter lookup |
|---|---|---|
| Add Lines to Movement Line → Movement Line No. | Status in (Departed, PartiallyDeparted, Arrived, PartiallyArrived, Closed) | Yes |
| Add Lines to Movement Line → Freight Movement No. | Movement-level Departed / Arrived / Closed (if introduced) | Yes when applicable |
| Freight Movement → Freight Carrier Code | Blocked = true | Yes |
| Freight Movement → Origin Code (Other Place) | Blocked = true | Yes |
| Freight Movement → Destination Code (Other Place) | Blocked = true | Yes |

**Open product decision:** Movement-Line eligibility on the Add Lines dialog should also be considered for **Destination match** with the source doc-line ship-to. Hard filter vs. soft filter (sort by relevance) is a model choice, capture the decision here when made.

---

## 4. Visibility / Editable conditionals

**Catches:** UI state vars (`Visible = pageVar`, `Editable = pageVar`) that don't refresh on the pivot they depend on. Most common on StandardDialog pages where BC doesn't auto-`CurrPage.Update()` after a non-bound option change.

**Procedure.** For every page var that drives `Visible` or `Editable` on one or more fields, test each value of the driver and confirm:

- The dependent fields visually flip on the same interaction that flips the driver (not on the next click).
- `OnValidate` on the driver explicitly calls `CurrPage.Update(false)` if BC doesn't auto-refresh.
- Hidden fields are also non-editable (a hidden-but-editable field can be filled via keyboard tab on some hosts).

**Inventory:**

| Page | Driver | Affects | Tested at |
|---|---|---|---|
| `Movt. Line Add Lines_SHP_EQL` | Mode (Use Existing / Create New) | Movement Line No., Booked Container Type | Mode pivot on dialog open + after switch |
| Freight Movt. Ln Card | Rec."Needs Review" | "Needs Review Reason" visible | Toggling Needs Review on/off |

---

## 5. StandardDialog Mode pivots

**Catches:** Each `Option` / `Enum` mode on a StandardDialog must be tested end-to-end including the commit, not just the open. Common failure: hidden field in the OFF mode silently stays bound to a separate var, OK uses the wrong var, insert/update silently fails or creates orphan data.

**Procedure.** For every StandardDialog with a Mode selector, run each Mode value through:

1. Open dialog → confirm correct field set is visible per §4.
2. Fill required fields.
3. Click OK → confirm the documented side effect actually occurs (insert / update / link).
4. Click OK with each required field blank → confirm a clear, mode-specific error.
5. Click Cancel → confirm no side effects.

**Inventory:**

| Dialog | Modes |
|---|---|
| `Movt. Line Add Lines_SHP_EQL` | Use Existing, Create New |

For each Mode: visible-field set documented, OK side effect documented, error-on-blank documented, Cancel verified no-op.

---

## 6. Subpage FK persistence

**Catches:** `SubPageLink` not propagating the parent PK into newly-inserted subpage rows. The UI looks fine but rows save with blank FK and end up outside the filter on next open (banner: "the view is filtered, and the entry is outside the filter").

**Procedure.** For every subpage embedded in a Card via a part with `SubPageLink`:

1. Open the parent record.
2. Add a new subpage row; commit (move off row).
3. F5 / hard-reload the parent.
4. Confirm the row reappears in the same filtered view (no "outside filter" banner).
5. Open BC Page Inspector on the subpage; verify the FK fields on the persisted row match the parent's PK.
6. If a FactBox depends on the subpage data (e.g. reconciliation), verify it updates.

**Fix when broken.** Use explicit `SetParentKeys()` pattern: parent calls `CurrPage.Subpage.PAGE.SetParentKeys(...)` in `OnAfterGetCurrRecord`; subpage stores in private vars and applies in `OnNewRecord`. Don't rely on `SubPageLink` initial-value defaulting alone for nontrivial FKs.

**Inventory:**

| Parent page | Subpage | FK fields |
|---|---|---|
| `Freight Movt Ln Card_SHP_EQL` → PackingSpecs | `Movt Ln Pack Specs FB_SHP_EQL` | Movement No., Movement Line No. |
| `Freight Movement Card_SHP_EQL` → Movement Lines | `Movt. Lines Part_SHP_EQL` | Movement No. |

---

## 7. State machine transitions

**Catches:** missing transitions, broken transitions, missing rejections. The happy path covers the documented success transitions; this category also covers every **disallowed** move from every source state.

**Procedure.** For each state machine, build a transition table with allowed / disallowed for every (from, to) pair. Test:

- Every allowed transition fires its documented side effects.
- Every disallowed transition errors with a clear message and does not mutate state.
- Auto-transitions (triggered by side effects elsewhere) actually fire.

**Inventory:**

Freight Movement Line status machine (`Status_SHP_EQL` enum):

| From | To | Allowed | Trigger |
|---|---|---|---|
| New | Loaded | yes | First doc-line link |
| New | Planned | yes | Manual via Release (movement-level) |
| Planned | Booked | yes | Manual via Release |
| Loaded | Booked | yes | Release |
| Booked | Departed | yes (phase 6) | Mark Departed |
| Departed | Arrived | yes (phase 6) | Mark Arrived |
| Arrived | Closed | yes (phase 6) | Mark Closed |
| Any of (Departed, PartiallyDeparted, Arrived, PartiallyArrived, Closed) | (linkage edit) | no | Linkage code errors |

Freight Movement Header status machine (`Status_SHP_EQL` enum on header): similar table, populate when phase 6 lands.

---

## 8. Permission boundaries

**Catches:** RIMD claims on permission sets that don't hold in practice, usually missing Indirect or wrong RIMD letter on a related table.

**Procedure.** For each permission set, log in as a user with **only** that set assigned and run a smoke pass covering:

- Read on every table the set claims to read.
- Insert / Modify / Delete on every table the set claims to mutate.
- Attempted write on tables the set should **not** be able to write, must error.
- Attempted read on setup tables from SHIP-USER if SHIP-USER is documented as read-only on setup.

**Inventory:**

| Permission set | RIMD claim | Tables to verify |
|---|---|---|
| SHIP-USER | Read setup, RIMD movements / containers / linkages / packing specs | Shipping Setup, Freight Movt. Header, Freight Movement Line, Shipping Container, Document Line Linkage, Doc Line Packing Spec, Movt Ln Packing Spec |
| SHIP-SETUP | SHIP-USER + modify on setup tables | Above + Other Place, Container Type, Freight Carrier, Shipping Setup |
| SHIP-ADMIN | Full including delete on setup | Above with delete |

---

## 9. Telemetry events

**Catches:** documented events that don't fire, or fire with the wrong payload.

**Procedure.** Enable telemetry (Shipping Setup → Telemetry Enabled). Trigger each documented event and confirm in App Insights / telemetry trace:

- Event ID matches (prefix `SHP-EQL-`).
- Payload keys match the spec.
- Payload values are not user content (item content, quantities), privacy commitment in §7 of the user guide.

**Inventory:**

| Event | Trigger | Documented payload |
|---|---|---|
| Install | Extension install | `InstallVersion`, `InstallDate` |
| Carrier Created | New Freight Carrier inserted | `CarrierCode` |
| Movement Created | Freight Movement inserted | `MovementNo` |
| Movement Released | Status → Booked | `MovementNo`, `PrevStatus` |
| Container Created | Shipping Container inserted | `ContainerNo` |
| Container Linked | Container No. set on Movement Line | `MovementLineNo`, `ContainerNo` |
| Movement Line Created | Freight Movement Line inserted | `MovementLineNo` |
| Doc Line Linked | Linkage inserted | `MovementLineNo`, `SourceType`, `SourceDocNo`, `SourceLineNo` |
| Line Edit Warning | Linked doc line mutated | `MovementLineNo`, `FieldChanged` |
| Packing Specs Copied to Posted | Posting | `PostedDocNo` |

---

## 10. Mobile / tablet smoke

**Catches:** pages that render with horizontal scroll, fat-finger conflicts, off-screen action ribbons, illegible inline-create dialogs on phone-class viewports.

**Procedure.** Open each top-level user-facing page on a 375×812 viewport (BC phone client or Chrome DevTools device mode). Confirm:

- No horizontal scroll on the main page.
- Action ribbon collapses cleanly to overflow menu.
- Subpage repeaters scroll vertically within the parent, not horizontally.
- Inline-create dialogs render with reachable OK / Cancel buttons.

**Inventory:**

| Page | Variant |
|---|---|
| Freight Movements list | Phone, Tablet |
| Freight Movement card | Phone, Tablet |
| Freight Movement Line card | Phone, Tablet |
| Shipping Containers list | Phone, Tablet |
| Add Lines to Movement Line dialog | Phone, Tablet |

---

## 11. Cross-company isolation

**Catches:** singleton tables (Shipping Setup, No. Series state) leaking across companies. Setup changes in Company A visible in Company B is a common BC pitfall when records are inserted with `DataPerCompany = false` by mistake.

**Procedure.**

1. In Company A, set Shipping Setup → Telemetry Enabled = true, set a distinctive No. Series start.
2. Switch to Company B.
3. Confirm Shipping Setup is its own record (defaults, not Company A's values).
4. Confirm No. Series state in Company B starts fresh (does not increment from Company A's counter).
5. Create a movement in Company B; confirm it does not appear in Company A's Freight Movements list.

**Inventory:**

| Table | DataPerCompany expected |
|---|---|
| Shipping Setup | true |
| Freight Movt. Header | true |
| Freight Movement Line | true |
| Shipping Container | true |
| Other Place | true |
| Freight Carrier | true |
| Container Type | true |
| Document Line Linkage | true |
| Movt Ln Packing Spec | true |
| Doc Line Packing Spec | true |

---

## 12. Upgrade paths

**Catches:** schema changes that drop or corrupt data on version-to-version upgrade. Renames, type changes, PK changes, removed fields.

**Procedure.** For each release with schema changes:

1. Install the **previous** version on a clean tenant.
2. Seed data covering every table affected by the upgrade.
3. Note row counts and key field values.
4. Install the new version (forced upgrade via App Management → Upload Extension).
5. Confirm row counts unchanged, key field values intact, derived/migrated fields populated correctly.
6. Run a smoke pass against the upgraded data.

**Inventory:** Per release. Maintain a delta in this section per version bump:

### v27 → v28

- **Renamed:** Shipping Container → Freight Movement Line + new Container child table.
- **PK change:** Freight Movement Line PK is now compound (Movement No., Line No. Integer auto-step).
- **FK change:** Document Line Linkage and Movt Ln Packing Spec FK now compound (Movement No., Movement Line No.).
- **Upgrade codeunit covers:** schema rename, data migration, ID re-keying.

Upgrade smoke test items: every Freight Movement Line from v27 carries forward with Line No. assigned, every Linkage / Packing Spec FK rewritten correctly, no orphan rows.

---

## Run report template

Each release pass produces a run report capturing category coverage. Use `WEBCLIENT_RUN_REPORT.md` as the rolling document; the per-release entry should look like:

```
## v<version>: <date>

Categories run (mark each PASS / FAIL with notes):
1. Lookup audit: PASS (n fields × 2 paths each)
2. Type-conditional TableRelation: FAIL (Origin Type → Location not tested)
3. Eligibility filters: PASS
4. Visibility / Editable conditionals: PASS
5. StandardDialog Mode pivots: PASS
6. Subpage FK persistence: PASS
7. State machine transitions: PARTIAL (phase 6 transitions n/a)
8. Permission boundaries: PASS
9. Telemetry events: PASS
10. Mobile / tablet smoke: n/a (no mobile changes this release)
11. Cross-company isolation: n/a (no setup-table changes this release)
12. Upgrade paths: PASS (v27 → v28 covered)
```

A release is shippable when every applicable category is PASS. `n/a` is acceptable when the release genuinely doesn't touch the category surface. `PARTIAL` is acceptable only when the partial scope is documented and a follow-up task is opened.
