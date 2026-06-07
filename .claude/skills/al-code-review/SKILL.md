---
name: al-code-review
kind: action-skill
id: al-code-review
version: 1
title: AL code review (house rules)
description: Review AL code for Business Central extensions against project and Microsoft conventions, including the AL performance checklist and Copilot PromptDialog rules.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# AL Code Review

## When to use

Reviewing AL code in any BC extension, including AppSource submissions, custom extensions, and per-tenant work.

## Sources

This skill synthesises:

1. The project AL guidelines document
2. `alguidelines.dev`
3. Microsoft CAL guidelines (legacy patterns to be aware of)
4. The `microsoft/alguidelines` repository

When sources conflict, project house rules win.

## House rules

1. **Never include `ODataKeyFields` in BC API query definitions.** This is a strict rule. Flag any API query that adds it.
2. Use object IDs from the project's assigned range. Never hardcode IDs outside the assigned range.
3. Capture telemetry on every protected operation using the project's standard telemetry pattern.
4. All user-facing labels go through `Label` declarations with `Comment` populated for translators.

## Core checks

### Naming

- Tables, pages, codeunits, and reports: PascalCase, descriptive.
- Variables: PascalCase, no Hungarian notation.
- Procedures: PascalCase, verb first ("CalculateAmount" not "AmountCalculation").

### Structure

- Pages have a single purpose. Master, List, Card, Document, Worksheet, RoleCenter.
- Business logic lives in codeunits, not page triggers.
- One object per `.al` file.

### Error handling

- `Error` for user-facing failures.
- `Confirm` only when the user can sensibly answer.
- Use `ErrorInfo` for structured errors that callers can react to.

### API definitions

- Query objects use `APIPublisher`, `APIGroup`, `APIVersion`, `EntityName`, `EntitySetName`.
- Property `ODataKeyFields` is **forbidden** by project house rules.
- All API fields use `IncludeInDataSet = true` only where needed.

### Performance

- Avoid record locking in loops. Use `LockTable` once, then iterate.
- Avoid `FindFirst`/`FindLast` where `Get` would do.
- Filter on indexed fields when possible.

## Event subscribers

The project has explicit rules for event subscribers, drawn from the AL Development Standards.

- **Keep subscriber codeunits small and focused.** A new instance of the codeunit is created when an event fires. Multi-purpose subscriber codeunits create unnecessary overhead.
- **Group subscriptions by functionality.** Examples: `Subs-SalesPost` for sales posting events, `Subs-SalesHeaderLineEvents` for Sales Header and Sales Line table events.
- **Subscriber procedures are thin.** They call a Management/Handler codeunit that holds the business logic.
- **Consider `SingleInstance`** when shared cached state actually helps, but prefer stateless subscribers and avoid global variables.
- **Use `EventSubscriberInstance = Manual`** when events should only fire during a specific process and explicit control is needed.
- **Naming convention**: `ObjectName_EventName_ElementName`. Example: `Job_OnBeforeUpdateJobTaskDimension`.
- **Exit early.** Bail on temp records, wrong record type, `Session.CurrentExecutionMode <> Normal`, or any unmet precondition.
- **`SkipOnMissingLicense` / `SkipOnMissingPermission`**: for AppSource marketplace apps (BC21+), `true, true` may be acceptable. Discuss with the Product Owner. For non-marketplace/internal apps, use `false, false` so license and permission issues fail fast.

## AL performance checklist

For any PR that touches AL on a performance-sensitive path, apply the checklist captured in `templates/pr-performance-review.md`. Headlines:

- Correct data access method (`Get` > `Find` > `FindFirst` > `IsEmpty`, avoid `FindSet` unless necessary)
- Filters applied before loops, not inside
- `SetCurrentKey` when a non-primary index is required
- `ModifyAll` / `DeleteAll` instead of record-by-record loops
- Temporary tables for heavy looping or sorting
- Queries instead of nested loops
- Subscribers exit early and avoid hidden DB calls
- No auto-increment fields as primary keys
- No assumptions about small data sets

Use the PR template at `templates/pr-performance-review.md` (in this skill folder) for any PR with non-trivial AL performance impact.

## Anti-patterns to call out

- Stringly-typed option fields where an enum would be safer
- Direct DB access from pages instead of via codeunits
- Caught-and-ignored errors
- Magic strings for codes (use constants or enums)
- `FindSet` loop with `CalcFields` of a FlowField inside
- Event subscribers doing extra DB reads on the hot path
- Large multi-purpose subscriber codeunits

## PromptDialog and Copilot review

For any AL changes that touch a `PageType = PromptDialog`, also enforce these rules from `copilot-promptdialog`:

- `Extensible = false` is mandatory. Customers cannot extend Copilot pages.
- `Image = Sparkle` or `SparkleFilled` only. Other icons are non-standard.
- No repeater controls inside `area(Prompt)` or `area(Content)`.
- `area(PromptOptions)` accepts only option-type fields.
- Only the five sanctioned system actions: `Generate`, `Regenerate`, `Attach`, `OK`, `Cancel`. Reject custom system action names.
- **No trailing whitespace in action names.** Silently breaks Copilot. Caption can have trailing space, Name cannot.
- `PromptGuide` actions should each set the input variable to a templated text. They render only when `PromptMode = Prompt`.

For the AOAI codeunit behind the Copilot capability (`copilot-capability-implementation`):

- API key field must be `SecretText` type, not `Text`. `SecretText` is excluded from the debugger.
- Credentials stored via `IsolatedStorage`, or via AppSource Key Vault for marketplace apps.
- `AzureOpenAI.SetCopilotCapability(...)` must be called before `GenerateChatCompletion`.
- `RegisterCapability` must be wrapped in `IsSaaSInfrastructure()` and `IsCapabilityRegistered()` guards.
- Use `SetPrimarySystemMessage` for the metaprompt, not `AddSystemMessage`. PrimarySystemMessage persists across chat history.

## Related skills

- `copilot-promptdialog` for the full PromptDialog standard
- `copilot-capability-implementation` for the AL Copilot capability rules
