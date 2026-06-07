---
kind: action-skill
id: al-saas-restore-runbook
version: 1
title: BC SaaS Point-in-Time Restore Review
description: Reviews a Business Central SaaS point-in-time restore plan against the platform limits and recovery runbook and emits a findings report.
inputs: [repository]
outputs: [findings-report]
bc-version: [all]
technologies: [al]
countries: [w1]
application-area: [all]
---

# BC SaaS Point-in-Time Restore Review

Reviews whether a planned or executed Business Central SaaS point-in-time restore respects the platform's hard limits and follows the recovery runbook, and emits a findings report. The governing principle is that a restore is irreversible relative to the chosen point and constrained by non-negotiable platform limits, so a restore promised outside the allowed window or path, or a runbook step skipped, leaves the customer with data loss or a half-reconnected environment. This is a leaf action skill: it invokes no sub-skills.

An orchestrator invokes this skill with a `repository` (an audit of the restore plan, incident runbook, or post-restore checklist checked into the repo or attached to the ticket). The skill produces a single JSON document conforming to the DO output contract.

## Source

The rule set is the BC SaaS point-in-time restore runbook: the platform's hard limits, the allowed restore paths, prerequisites, and the pre- and post-restore checklists. BCQuality's curated knowledge domains do not cover SaaS restore operations, so this skill carries its own rule set in full. Read the BCQuality knowledge index once to confirm no curated domain claims this area (the `knowledge-index.json` Entry's preparation step regenerates over the already-filtered clone); do not open individual article bodies. Findings here are agent findings within this skill's restore-governance domain. Restricting access during the restore window is owned by `al-security-group-setup`; CI/CD reattachment is owned by `al-go-environment-onboarding`.

## Relevance

Apply the frontmatter matching rules defined in READ against the task context:

- `bc-version` - the target environment's BC version, or `unknown` if unavailable.
- `technologies` - `[al]`.
- `countries` - the customer's localisation context, else `unknown`; relevant because a localisation change during restore is not allowed.
- `application-area` - `[all]`.

Discard artifacts that do not describe a restore plan, runbook execution, or post-restore checklist. Retain conditionally applicable rules (any dimension `unknown`) only when configuration permits; findings derived from them have `confidence` no higher than `medium` and name the unknown dimension in the `message`.

## Worklist

Narrow the runbook to the rules that apply to the plan under review. Group the candidate worklist by area:

- **Hard limits** - at most 10 restores per calendar month; the chosen point is within the 28-day retention window; same Azure region only (no cross-region); no localisation change during restore; no Sandbox-to-Production restore; the path is one of Prod to Prod, Prod to Sandbox, or Sandbox to Sandbox. Production restores bypass the sandbox capacity limit by design; sandbox restores do not, so a sandbox at cap requires soft-deleting an existing sandbox first.
- **Prerequisites** - the operator holds the `D365 BACKUP/RESTORE` permission set; the customer has a paid (not trial) subscription; the target environment exists or a new one is being created.
- **Pre-restore checklist** - restore point confirmed within 28 days; region confirmed; permission confirmed; Job Queues paused on the source; access restricted if sensitive (via `al-security-group-setup`); the original renamed with `-DONOTUSE` if the name is being reused; the installed-app list snapshotted for PTE reinstall.
- **What gets restored versus cleaned** - business data, posted documents, master and setup data, dimensions, and journal entries are restored; AppSource apps come back at latest hotfix (Microsoft policy, not configurable); dev-only VS Code extensions are not restored and need manual reinstall; integrations (Document Exchange, Currency Exchange Rates, VAT validation, Graph Mail, CRM/CDS, webhooks) come up disabled; OCR passwords, SMTP config, Exchange URLs, and Outlook REST accounts are cleared.
- **Post-restore checklist** - AppSource app versions verified; PTEs reinstalled; disabled integrations re-enabled and tested one by one; webhook subscriptions reconfigured; API consumers re-added; smoke tests run across Sales, Purchase, Finance, and Reporting; access unrestricted; customer notified; `-DONOTUSE` original deleted only after the customer confirms.
- **Customer communication** - before: estimated downtime, integrations come up disabled, work after the restore point is lost; after: smoke tests run, which credentials the customer must re-enter, the new environment name and access changes.

A rule enters the worklist when the plan, runbook, or checklist under review touches its area.

## Action

For each worklist item, evaluate the plan and emit findings (all are agent findings within this skill's domain: `references: []`, `id` prefixed `agent:`, `confidence` capped at `medium` per `skills/do.md`):

- A plan that violates a hard limit (a restore point older than 28 days, a cross-region target, a Sandbox-to-Production path, a localisation change, or an 11th restore in the month) is a `major` agent finding (the agent-finding ceiling), with a self-contained `message` naming the limit and the consequence. These are stop-the-line conditions for the operator even though the agent severity is capped.
- A missing prerequisite (operator lacks `D365 BACKUP/RESTORE`, a trial subscription, no target environment) or a skipped post-restore reconnection that leaves an integration firing on stale data or silently off is a `major` agent finding.
- A pre-restore omission that risks recoverability or cleanup (Job Queues left running on the source, no `-DONOTUSE` rename before name reuse, no installed-app snapshot, sensitive data not access-restricted) is a `minor` agent finding.
- A communication or hygiene gap (no downtime estimate to the customer, no smoke-test plan, no post-restore confirmation before deleting `-DONOTUSE`) is a `minor` agent finding.
- When a rule is clearly applicable but no violation is detected, emit `info`.

Set `confidence` to `high` when the plan states a concrete value that breaches a limit (a dated restore point, a named cross-region target), `medium` for heuristic detection or when any frontmatter dimension was `unknown`. Restore-plan findings are rarely mechanical; provide `suggested-code` only when the fix is a literal edit to a checked-in artifact, otherwise set `suggested-code-omission-reason`. See `skills/do.md` for the full contract.

Outcome selection: `completed` when every worklist item was evaluated (including an empty `findings` array); `no-knowledge` when no applicable rule survived Relevance and configuration filtering; `not-applicable` when the task context describes no restore plan, runbook, or checklist; `partial` when a budget was hit before the worklist was exhausted; `failed` on an unrecoverable error (`outcome-reason` required).

## Output

Output conforms to the DO output contract. A populated example:

```json
{
  "skill": { "id": "al-saas-restore-runbook", "version": 1 },
  "outcome": "completed",
  "summary": {
    "counts": { "blocker": 0, "major": 1, "minor": 1, "info": 0 },
    "coverage": { "worklist-size": 6, "items-evaluated": 6 }
  },
  "findings": [
    {
      "id": "agent:restore-point-outside-retention-window",
      "severity": "major",
      "message": "The plan targets a restore point 35 days before today, but BC SaaS retains backups for only 28 days. This restore cannot be performed as specified. Recommendation: pick the earliest available point within the 28-day window and confirm with the customer that data before it is unrecoverable from backup.",
      "location": { "file": "docs/incidents/restore-plan.md", "line": 12 },
      "references": [],
      "confidence": "high"
    },
    {
      "id": "agent:disabled-integrations-not-in-post-restore-plan",
      "severity": "minor",
      "message": "The post-restore checklist does not re-enable the integrations that BC disables on restore (Document Exchange, Currency Exchange Rates, VAT validation, Graph Mail, CRM/CDS, webhooks). Leaving them unaddressed means they stay off silently. Recommendation: add a step to re-enable and test each integration one by one before notifying the customer.",
      "location": { "file": "docs/incidents/restore-plan.md", "line": 40 },
      "references": [],
      "confidence": "medium"
    }
  ],
  "suppressed": []
}
```
