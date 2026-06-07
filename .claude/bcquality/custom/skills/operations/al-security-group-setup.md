---
kind: action-skill
id: al-security-group-setup
version: 1
title: BC Environment Security Group Review
description: Reviews how a Business Central environment is restricted with a Microsoft Entra security group and emits a findings report.
inputs: [repository]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC Environment Security Group Review

Reviews whether a Business Central environment is correctly restricted with a Microsoft Entra security group, and emits a findings report. The governing principle is that once a group is bound, only users who hold a BC licence and are members of the group can sign in, so a production or sensitive environment left open, bound to a reused group, or managed by a single owner is an access-control gap. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (an audit of environment-binding documentation, group definitions, or access runbooks checked into the repo). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the BC Entra security-group setup procedure: group creation conventions, environment binding, verification, and ongoing operational guidance. BCQuality's curated knowledge domains do not cover environment access control, so this skill carries its own rule set in full. Read the BCQuality knowledge index once to confirm no curated domain claims this area (the `knowledge-index.json` Entry's preparation step regenerates over the already-filtered clone); do not open individual article bodies. Findings here are agent findings within this skill's environment-access domain. The broader Azure access model is owned by `al-rbac-and-access`; restricting access during a restore window is the typical caller via `al-saas-restore-runbook`.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the environment's BC version, or `unknown` if unavailable.
- `technologies` - `[al]`.
- `countries` - the configured context, else `unknown`.
- `application-area` - `[all]`.

Discard artifacts that do not describe an environment binding, an Entra security group for BC access, or the membership of one. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

Narrow the procedure to the rules that apply to the configuration under review. Group the candidate worklist by area:

- **Restriction coverage** - a Production environment locked to a specific user set, a UAT environment limited to its test cohort, and a sensitive sandbox (payroll, customer migration) are each bound to a group rather than left open to all licensed internal users.
- **Group creation** - the group type is Security; the name follows the `<customer>-bc-<env>-access` pattern; at least two Owners (never one); a separate group per environment (Production, UAT, and specialised sandboxes are not reusing one group).
- **Binding** - the group is bound through the BC Admin Center's Security Group define step for the correct environment; the effect (licence plus membership required to sign in) is understood, and delegated admins retain access by Microsoft design.
- **Verification** - a member sign-in succeeds; a licensed non-member is denied with a clear message; delegated admin access still works.
- **Operational guidance** - membership is preferred over direct per-user assignment (to keep the audit trail and central control); membership is reviewed quarterly; Conditional Access layers MFA or location rules on sensitive groups; the group owner contact is documented for access tickets.
- **Common confusions held as rules** - the group controls sign-in, not licence assignment; a delegated admin cannot be locked out; multiple bindings are possible but kept simple (a parent dynamic group for "A OR B"); removing the binding reverts to "all licensed users can sign in".

A rule enters the worklist when the artifact under review describes an environment binding, a group definition, or its membership.

## Action

For each worklist item, evaluate the configuration and emit findings (all are agent findings within this skill's domain: `references: []`, `id` prefixed `agent:`, `confidence` capped at `medium` per `skills/do.md`):

- A Production or explicitly sensitive environment with no Entra security-group restriction, leaving every licensed internal user able to sign in, is a `major` agent finding (the agent-finding ceiling), with a self-contained `message` naming the environment and the remediation (create a per-environment group and bind it via the Admin Center).
- A binding that defeats the control or its auditability (a single-owner group, a Production group reused for UAT, users added directly to BC instead of through the group) is a `minor` agent finding.
- An operational or hygiene gap (no documented quarterly membership review, no Conditional Access on a sensitive group, no documented owner contact, no verification that a non-member is actually denied) is a `minor` agent finding.
- When a rule is clearly applicable but no violation is detected, emit `info`.

Set `confidence` to `high` when the artifact states a concrete fact that breaches a rule (a named Production environment documented as unrestricted, a group with one owner), `medium` for heuristic detection or when any frontmatter dimension was `unknown`. These findings are rarely mechanical; provide `suggested-code` only when the fix is a literal edit to a checked-in artifact, otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Relevance and configuration filtering; `not-applicable` when the task context describes no environment binding or group to review; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-security-group-setup", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 0, "major": 1, "minor": 1, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:production-environment-not-restricted",
      "severity": "major",
      "message": "The Production environment 'acme-prod' is documented with no Entra security group bound, so every user holding a BC licence in the tenant can sign in. Recommendation: create a Security group named acme-bc-prod-access with at least two owners, add the intended members, and bind it via BC Admin Center > Security Group > Define.",
      "location": { "file": "docs/environments/acme.md", "line": 18 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:security-group-single-owner",
      "severity": "minor",
      "message": "The acme-bc-uat-access group lists a single owner. A single owner is a continuity risk for access management. Recommendation: add at least one more owner so the group can always be administered.",
      "location": { "file": "docs/environments/acme.md", "line": 27 },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
