# Feature Plan: Message list and resolution

- **Feature id:** 002-message-list-and-resolution
- **Spec:** ./spec.md
- **Status:** planned

## Approach

A List page and a Card page over the Integration Message table, plus one resolution
management codeunit that holds the three action behaviours so the pages stay thin.
The card exposes the Request blob as an editable multiline text bound to a page
variable, written back through the table's SetRequest accessor on validate. All
re-queue logic reuses the existing Message ID; the codeunit never inserts.

## Standard BC reused

- Standard List / Card page patterns and actions; standard `Editable` property
  expressions to lock everything except payload and type while Failed.

## AL objects to add or extend

| Object | Type | ID | New/Extend | Purpose |
|---|---|---|---|---|
| Integration Message List | page | 73298443 | new | Monitor and filter messages. |
| Integration Message Card | page | 73298444 | new | Resolution card with editable payload. |
| Integration Resolution Mgt. | codeunit | 73298426 | new | Resolve / Confirm by Exception / Reassign. |
| Integration Foundation | permissionset | 73298460 | extend | Add the new pages and codeunit. |

The core table's `LookupPageId` / `DrillDownPageId` already point at
`Integration Message List`; this feature supplies it.

## Data model

No new tables. Reads and writes the Integration Message table through the feature
001 accessors (`GetRequest`, `SetRequest`) and the resolution codeunit.

## Integration points

None external. The Resolve / Reassign actions set Status back to New so the feature
001 dispatcher re-runs the message on its next scheduled pass.

## Cross-cutting

- Permissions: add the two pages and the resolution codeunit (X), reusing the
  message tabledata grant from 001.
- Telemetry: INT-0008 (resolve), INT-0009 (confirm by exception), INT-0010
  (reassign) via the 001 telemetry codeunit.
- Performance: the list shows no FlowFields; the editable payload blob is read only
  on the card (`OnAfterGetRecord`), never on the list repeater.

## Risks and decisions

- **Editing a blob through a page variable.** The card loads the payload into a
  text var on `OnAfterGetRecord` and writes it back on validate via `SetRequest` +
  `Modify`. Decision: acceptable because edits are confined to Failed messages and
  the field is small operationally; large payloads remain readable.
- **Resolve vs Reassign.** Both re-queue; Reassign additionally re-resolves the
  Type from the corrected Type Code. Kept as two actions so the audit trail
  distinguishes a payload fix from a routing fix.

## Test strategy

A test codeunit drives a Failed message through each action via the resolution
codeunit and asserts the resulting Status, Retry Count, preserved error text, and
unchanged Message ID; and asserts the actions are guarded when not Failed.
TestPage coverage confirms the payload/type fields are editable only while Failed.
