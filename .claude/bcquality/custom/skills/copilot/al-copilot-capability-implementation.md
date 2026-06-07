---
kind: action-skill
id: al-copilot-capability-implementation
version: 1
title: BC Copilot Capability Implementation Review
description: Reviews the AL implementation of a Business Central Copilot capability built on the System.AI Azure OpenAI module and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC Copilot Capability Implementation Review

Reviews the AL side of a Business Central Copilot feature built on the `System.AI` module (the Azure OpenAI wrapper): capability registration, billing-type selection, key storage, the chat-completion call, prompt construction, and token budgeting. It emits a findings report. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with either a `pr-diff` (the standard PR-review entry point for a Copilot capability change) or a `file-path` (single-file review of an install codeunit, setup table, or the generation codeunit). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is this skill's own Copilot-capability knowledge plus BCQuality knowledge entries whose domain covers the concerns it touches (security for secret handling and `DataClassification`, style for user-facing labels). Read the BCQuality knowledge index once and take the `security` and `style` domain entries as the citable candidate set across every enabled layer; do not open an article body until it enters the Worklist. The `System.AI` API contract, the billing-type validation matrix, and the capability-registration lifecycle are not covered by the corpus; for a concrete violation there, emit an agent finding within this skill's Copilot-capability domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the consuming app's `app.json`, or `unknown`.
- `technologies` - `[al]`.
- `countries` - from the app's `app.json`, else `unknown`.
- `application-area` - the union of areas declared by the changed objects; pass the actual set.

Discard files not applicable to AL. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; cap their findings at `medium` confidence and name the unknown dimension.

## Worklist

Narrow to the rules that apply to the change under review. A rule enters the worklist when the diff or file touches its area:

- **Capability registration** - an `enumextension` of `Copilot Capability` exists and is registered at install, guarded by both `IsSaaSInfrastructure()` and `IsCapabilityRegistered()` before `RegisterCapability`, with valid availability and billing enum values.
- **Billing type** - the chosen `Copilot Billing Type` is legal for the resource model in use (the validation matrix below).
- **Key storage** - the Azure OpenAI key is a `SecretText`, never a plain `Text` field, and is persisted via `IsolatedStorage` (or AppSource Key Vault for marketplace apps); the setup table carries the right `DataClassification`.
- **The AOAI call** - `SetCopilotCapability` is called before generation so credit tracking and gating work; `SetAuthorization` uses the correct `AOAI Model Type`; the response is checked with `IsSuccess()` before reading.
- **Prompt construction** - the metaprompt goes through `SetPrimarySystemMessage` (persists across history) rather than `AddSystemMessage` (transient).
- **Token budgeting** - generation reserves enough output tokens for the model's context window.

## Action

For each worklist item, evaluate the AL and emit findings. Reframe the correct-build rules as defects to flag:

- **API key stored as `Text` instead of `SecretText`.** A plain `Text` key is visible in the debugger and at risk of logging. Flag `blocker` and cite the `security` secret-handling rule when one matches:

  ```al
  procedure SetApiKey(NewKey: SecretText)
  begin
      IsolatedStorage.Set('AOAI_KEY', NewKey, DataScope::Module);
  end;
  ```

- **`RegisterCapability` without the `IsSaaSInfrastructure()` and `IsCapabilityRegistered()` guards.** Missing the SaaS guard registers on unsupported infrastructure; missing the registered guard throws on re-install. Flag `major`.
- **Illegal billing-type and resource combination.** Validate against the matrix; an illegal pairing fails billing validation at runtime. Flag `major`.

  | Partner billing type | BC AI resources | Own AOAI resource |
  |---|---|---|
  | `Microsoft Billed` | Production OK | Sandbox only |
  | `Custom Billed` | Never allowed | OK |
  | `Not Billed` | OK (no consumption) | OK (no consumption) |

- **`SetCopilotCapability` not called before generation.** Without it, credit tracking and capability gating do not apply. Flag `major`.
- **Response read without `IsSuccess()`.** Reading `GetLastMessage()` before checking `AOAIOperationResponse.IsSuccess()` surfaces empty or error content. Flag `major`.
- **Metaprompt placed in `AddSystemMessage` instead of `SetPrimarySystemMessage`.** The metaprompt (role, format, guardrails) must persist across evicted history; `AddSystemMessage` content does not. Using the wrong call lets the guardrails silently drop mid-conversation. Flag `minor`.
- **No output-token reservation against the context window.** A `SetMaxTokens` value plus estimated input that can exceed the model's context window produces truncated responses. Flag `minor` and recommend an `ApproximateTokenCount` check.
- **Unsupported `System.AI` feature assumed.** Image (DALL-E) or speech (Whisper) usage is out of scope for the module. Flag `major`.

Cite a `security` or `style` knowledge file in `references` when a finding maps onto one (for example a missing `DataClassification` on the setup table, or a user-facing error built from a string literal rather than a `Label`); otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`, severity capped per `skills/do.md`). Set `confidence` to `high` for unambiguous type or API matches, `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. For mechanical fixes (change a field type to `SecretText`, add the install guards, swap `AddSystemMessage` for `SetPrimarySystemMessage`), emit `findings[].suggested-code`; otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the change touches no Copilot capability or `System.AI` surface; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-copilot-capability-implementation", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 1, "major": 1, "minor": 0, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:aoai-key-not-secrettext",
      "severity": "blocker",
      "message": "The Azure OpenAI API key is held in a Text field, so it is exposed in the debugger and at risk of logging. Recommendation: change the field and accessor to SecretText and persist it via IsolatedStorage.",
      "location": { "file": "src/Copilot/MyCopilotSetup.Table.al", "line": 9 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:response-read-without-issuccess",
      "severity": "major",
      "message": "GetLastMessage() is read without first checking AOAIOperationResponse.IsSuccess(), so an error or empty completion is treated as valid output. Recommendation: branch on IsSuccess() and raise a friendly Error otherwise.",
      "location": { "file": "src/Copilot/GenerateJobProposal.Codeunit.al", "line": 44 },
      "references": [],
      "confidence": "high"
    }
  ],
  "suppressed": []
}
```
