# AGENTS.md

The contract between you and every agent that works in this repository. This is
the canonical guidance file. `CLAUDE.md` imports it so Claude Code loads it
automatically; other agent tools read `AGENTS.md` directly.

## What this repo is

A community-maintained Business Central integration repository built on
[AL-Go for GitHub](https://github.com/microsoft/AL-Go), packaged with a curated
set of AI agents and skills for AL development, and driven by Spec-Driven
Development.

## How we build here: Spec-Driven Development

**The spec is the brain, the agent is the muscle.** You do not write production
AL until an approved spec exists for the feature. Specs are durable artifacts
under `specs/`; a chat session is not. The developer architects the decisions in
the spec; the agent executes them.

### The constitution (read first, every session)

- `specs/brief.md` — customer requirements and business processes (the what and why).
- `specs/tech-design.md` — implementation strategy: which standard BC modules to
  reuse, and where custom code is genuinely needed.
- `specs/roadmap.md` — ordered list of features with status.
- `AGENTS.md` (this file) — conventions, quality gates, and the workflow.

### The per-feature loop

For each feature: **Feature Spec -> Plan -> Implement -> Test -> Docs -> Merge**,
then replan the next feature. Use one chat session per feature, and start it by
reading the constitution.

1. **Spec.** Draft `specs/features/<id>/spec.md`: the problem, the users, scope,
   acceptance criteria, and what is out of scope. Then run `/al-spec-feature` to
   review it against the constitution and confirm the acceptance criteria are
   testable. Stop for human review. No code yet.
2. **Plan.** Draft `plan.md` and `tasks.md` next to the spec: the BC objects to
   add or extend, the object ID range, the data model, integration points, and an
   ordered task list. Then run `/al-plan-feature` to review them against the
   approved spec. Stop for human review.
3. **Implement.** Work the tasks in order, applying the house rules and citing
   BCQuality. Then run `/al-implement-feature` to review the implementation
   against its spec, plan, and tasks.
4. **Test.** Building the app triggers the post-build hook, which prompts the
   mandatory verifier agents and a BCQuality review. Resolve every finding.
5. **Docs and Merge.** Update the feature docs, tick the roadmap item, open a PR.

### Bootstrapping

At the start of a project (or when the high-level requirements change), draft
`brief.md`, `tech-design.md`, and `roadmap.md`, then run `/al-spec-init` once to
review the constitution for completeness and consistency before any feature work.

## Layout

- `specs/`: the constitution and per-feature specs (the source of truth for what to build).
- `.AL-Go/`, `.github/workflows/`: AL-Go for GitHub build, test, and release pipelines.
- `.claude/agents/`: focused reviewer and verifier subagents for AL code.
- `.claude/skills/`: invocable review skills, including the SDD review gates above.
  Most are thin pointers: the authoritative content lives in BCQuality
  (the single source of truth) as `action-skill` (review) files under
  `.claude/bcquality/custom/skills/<category>/`, and each pointer mirrors the
  upstream skill's frontmatter (the BCQuality `kind`/`id`/`version`/`title`/
  `inputs`/`outputs` and dimension schema) plus the `name`/`description` the
  runtime needs to discover and trigger it.
  Edit the skill upstream in EquerraNZ/community-BCQuality and re-vendor, not the
  pointer. `al-code-review` is the exception: it stays a full local skill because it
  carries this project's house rules.
- `.claude/bcquality/`: a vendored, Microsoft-authored subset of the
  [BCQuality](https://github.com/EquerraNZ/community-BCQuality) knowledge corpus.
  Plain committed files; there is no submodule to initialise. The `custom/skills/`
  layer holds this project's reusable `action-skill` review skills; the runtime pointers in
  `.claude/skills/` defer to them.
- `al.code-workspace`: opens the workspace and defines the agent task playlists.

## BCQuality: the knowledge source agents cite

BCQuality is a remedial, machine-readable knowledge base for BC. Agents cite it
so that findings are backed by a vetted rule rather than paraphrased from memory.
Read [`.claude/skills/bcquality-integration/SKILL.md`](.claude/skills/bcquality-integration/SKILL.md)
for the full contract. The essentials:

- **Where it lives.** `.claude/bcquality/`. Knowledge files are under
  `.claude/bcquality/<layer>/knowledge/<domain>/`. The Microsoft layer vendors
  domains `performance`, `privacy`, `security`, `style`, `testing`, `ui`,
  `upgrade`. The `community/` layer adds `performance` and `security` rules, and
  the `custom/` layer adds `api`, `integration`, `operations`, `performance`,
  and `process` knowledge plus review and testing skills.
- **How it is consumed.** An agent invokes `.claude/bcquality/skills/entry.md`
  first. Entry returns a dispatch record naming the action skill(s) to run.
  Action skills follow the four-step pattern (Source, Relevance, Worklist,
  Action) defined in `.claude/bcquality/skills/do.md`, reading `read.md` on demand.
- **Knowledge file format.** Atomic markdown with YAML frontmatter (`bc-version`,
  `domain`, `keywords`, `technologies`, `countries`, `application-area`). Each
  rule is `<slug>.md` with optional `<slug>.good.al` and `<slug>.bad.al` siblings.

## How agents cite knowledge (the finding contract)

Each verifier agent has a **Knowledge sources** section naming the BCQuality
folder it sources from. When a finding maps onto a BCQuality knowledge file:

- Set the finding `rule` (or `id`) to the knowledge file slug.
- Populate `references` with `[{ "path": ".claude/bcquality/microsoft/knowledge/<domain>/<slug>.md" }]`.
- Do not paraphrase a rule you can cite.

When a finding does not map onto any vendored BCQuality file, use a `rule` slug
prefixed `house:` (or the agent's own rule id, for example an `AS0xxx` AppSource
rule) and leave `references: []`. Never cite a path that does not exist under
`.claude/bcquality/`.

## Agent-to-domain map

| Agent | BCQuality domain |
|---|---|
| `al-code-quality-reviewer` | performance, security, privacy |
| `al-readability-checker` | style, ui |
| `al-performance-reviewer` | performance |
| `al-upgrade-checker` | upgrade |
| `al-test-validator` | testing |
| `al-integration-pattern-reviewer` | performance, security (plus the `al-modern-integration-patterns` house rules) |

The integration validators source their rules from skills rather than a single
BCQuality domain. `al-integration-pattern-reviewer` cites the
`al-modern-integration-patterns` house rules and the mapped BCQuality
performance/security files named in that skill. `azure-integration-validator`
cites the `azure-integration-review` house rules with empty references, since no
BCQuality Azure domain is vendored.

Other agents (`al-appsource-validator`, `al-multitenancy-reviewer`,
`al-translation-auditor`, `al-permission-set-auditor`, `al-obsolete-tracker`,
`al-event-subscriber-auditor`, `azure-integration-validator`,
`al-test-coverage-validator`, `al-test-coverage-enforcer`) report against their
own rule ids with empty references until matching knowledge files land upstream.

## Mandatory verifier set

Before marking any BC development task (the Implement step of a feature)
complete, run these four verifiers in parallel and resolve their findings:

- `al-code-quality-reviewer`
- `al-readability-checker`
- `al-test-coverage-validator`
- `al-test-validator`

The `al.code-workspace` task "AI: Playlist: pre-completion" runs exactly this
set. Other playlists exist for AppSource submission, schema changes, subscriber
changes, hot-path review, integration review, and release readiness. After an AL
build/compile the post-build hook reminds you to run them.

When an integration is touched (an inbound or outbound flow, a Business Event, a
staging endpoint, a Job Queue sender, or any Azure integration artifact), run the
"AI: Playlist: integration-review" set: `al-integration-pattern-reviewer`
validates the BC app build, `azure-integration-validator` validates the Azure
component build, and `al-event-subscriber-auditor` checks the event wiring.

## House rules

Project-specific AL conventions (the `house:` rules) live in
[`.claude/skills/al-code-review/SKILL.md`](.claude/skills/al-code-review/SKILL.md).
They are applied in addition to BCQuality, not instead of it. When sources
conflict, house rules win.

## Style

Agent prompts and docs in this repo use a direct, practical voice and avoid em
dashes (use commas, colons, or periods instead). Keep that convention in any new
agent, skill, or spec so the content stays consistent.
