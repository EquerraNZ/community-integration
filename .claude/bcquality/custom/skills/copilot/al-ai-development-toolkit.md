---
kind: action-skill
id: al-ai-development-toolkit
version: 1
title: BC Agent Toolkit Integration Review
description: Reviews AL that integrates with the Business Central agent design experience and the Tasks AL API and emits a findings report.
inputs: [pr-diff, file-path]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC Agent Toolkit Integration Review

Reviews AL that integrates with the Business Central AI Development Toolkit: the agent design experience, the Tasks AL API under `BCApps/src/System Application/App/Agent`, agent-session detection, custom-agent enumeration, and the discipline of source-controlling and versioning agent instructions. It emits a findings report. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with either a `pr-diff` (the standard PR-review entry point for a change that wires events to agent tasks or detects agent context) or a `file-path` (single-file review). The skill produces a single JSON document conforming to the DO output contract. The toolkit is a preview feature, so the review treats missing iteration discipline (untested or unversioned instruction changes) as real findings.

## Source

The rule set is this skill's own toolkit-integration knowledge plus BCQuality knowledge entries whose domain covers the concerns it touches (security for permission gates, style for agent-only confirm suppression and telemetry). Read the BCQuality knowledge index once and take the `security` and `style` domain entries as the citable candidate set across every enabled layer; do not open an article body until it enters the Worklist. The Tasks AL API contract, agent-session detection, and the BC 28.1+ discovery model are not covered by the corpus; for a concrete violation there, emit an agent finding within this skill's toolkit-integration domain.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target BC version from the consuming app's `app.json`, or `unknown`. The discovery default changes at BC 28.1, so this dimension is load-bearing.
- `technologies` - `[al]`.
- `countries` - from the app's `app.json`, else `unknown`.
- `application-area` - the union of areas declared by the changed objects; pass the actual set.

Discard files not applicable to AL. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; cap their findings at `medium` confidence and name the unknown dimension.

## Worklist

Narrow to the rules that apply to the change under review. A rule enters the worklist when the diff or file touches its area:

- **Agent-session detection** - code that should behave differently under an agent session calls `codeunit "Agent Session".IsAgentSession(AgentMetadataProvider::"Custom Agent")` and gates the agent-only path on the result.
- **Tasks AL API usage** - calls into `codeunit "Custom Agent"` / `Record "Custom Agent Info"` enumerate agents correctly (`GetCustomAgents` then iterate the temporary record).
- **Event-driven task triggers** - AL that creates agent tasks from page actions or business events does so through the sanctioned Tasks AL API rather than ad-hoc session calls.
- **Interactive UI in an agent path** - confirms, dialogs, or `Message` calls that would block a non-interactive agent session are suppressed when `IsAgentSession` is true.
- **Permissions and discovery (BC 28.1+)** - when admin-only agent creation is intended, the `ShowCanCreateAgent` gate uses `AgentSystemPermissions.CurrentUserHasCanManageAllAgentsPermission()`.
- **Instruction iteration discipline** - agent instructions are source-controlled alongside the extension, versioned when behaviour changes, and the PR captures before/after sample task transcripts.

## Action

For each worklist item, evaluate the AL and emit findings. Reframe the correct-integration rules as defects to flag:

- **Unguarded interactive UI on a path an agent can hit.** A `Confirm`, `Message`, `Page.RunModal`, or other blocking dialog reachable from an agent session hangs or fails the task. Flag `major` and recommend gating it behind an `IsAgentSession` check:

  ```al
  local procedure IsCustomAgentRunningThis(): Boolean
  var
      AgentSession: Codeunit "Agent Session";
      AgentMetadataProvider: Enum "Agent Metadata Provider";
  begin
      exit(AgentSession.IsAgentSession(AgentMetadataProvider::"Custom Agent"));
  end;
  ```

- **Enumerating agents without `FindSet` discipline.** A `GetCustomAgents` call whose result is read without a proper `if TempAgentInfo.FindSet() then repeat ... until ... Next() = 0` loop is a `minor` correctness defect.
- **Wrong metadata provider filter.** Detecting agent context with a provider other than `::"Custom Agent"` (when the agent is a custom agent) yields false negatives. Flag `major`.
- **Admin-only intent not enforced.** When the design intends admin-only creation but `ShowCanCreateAgent` does not gate on `CurrentUserHasCanManageAllAgentsPermission()`, any user can create the agent on BC 28.1+. Flag `minor` and name the `bc-version` dimension.
- **Instruction changes with no versioning or tests.** An instruction-text change that is not versioned, not run against the evaluation suite, or lands with no before/after transcripts in the PR is a `minor` process finding. Treat agent instructions like code.
- **Hand-rolled task orchestration.** Creating or running agent tasks by bypassing the Tasks AL API is a `major` finding: it diverges from the supported runtime.

Cite a `security` or `style` knowledge file in `references` when a finding maps onto one (for example an interactive confirm that the style domain already prohibits in non-interactive paths); otherwise emit an agent finding within this skill's domain (`references: []`, `id` prefixed `agent:`, severity capped per `skills/do.md`). Set `confidence` to `high` for unambiguous API or identifier matches, `medium` for heuristic detections or when any frontmatter dimension was `unknown`, and `low` for applicability-only advisories. For mechanical fixes (add the `IsAgentSession` guard, correct the metadata-provider value), emit `findings[].suggested-code`; otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived filtering; `not-applicable` when the change touches no toolkit or Tasks AL API surface; `partial` on a budget cutoff; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-ai-development-toolkit", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 0, "major": 1, "minor": 1, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:interactive-confirm-in-agent-path",
      "severity": "major",
      "message": "A Confirm dialog is reachable from a code path that runs under a custom agent session, where there is no user to answer it. Recommendation: gate the confirm behind Agent Session.IsAgentSession(AgentMetadataProvider::\"Custom Agent\") and default to the non-interactive branch when true.",
      "location": { "file": "src/Sales/OrderPosting.Codeunit.al", "line": 73 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:agent-enumeration-no-findset",
      "severity": "minor",
      "message": "GetCustomAgents populates a temporary record that is then read without a FindSet/repeat loop, so only the first or no agent is processed. Recommendation: iterate with if TempAgentInfo.FindSet() then repeat ... until TempAgentInfo.Next() = 0.",
      "location": { "file": "src/Agent/AgentList.Codeunit.al", "line": 22 },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
