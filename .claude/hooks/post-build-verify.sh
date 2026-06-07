#!/usr/bin/env bash
# PostToolUse hook: after a Business Central build/compile, remind Claude to run
# the mandatory verifier agents and a BCQuality review before finishing.
#
# Contract: reads the PostToolUse JSON on stdin. Exits 2 with guidance on stderr
# (which Claude Code feeds back to the model) ONLY when the executed command looks
# like an AL build/compile. Exits 0 silently for everything else.
#
# Requires bash and (ideally) jq. On Windows this runs under Git Bash, which is
# Claude Code's default shell when present. If jq is absent the script falls back
# to scanning the raw payload, which is slightly less precise but still works.

payload="$(cat)"
[ -z "$payload" ] && exit 0

# Extract just the executed command so we do not match on unrelated tool output.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  [ -z "$cmd" ] && cmd="$payload"
else
  cmd="$payload"
fi

# AL build / compile signatures. Tight enough not to fire on config reads.
#   alc / alc.exe          the AL compiler
#   Run-AlPipeline         AL-Go / BcContainerHelper local build
#   Compile-AppInContainer BcContainerHelper compile
#   Compile-App            BcContainerHelper compile (host)
build_re='Run-AlPipeline|Compile-AppInContainer|Compile-App([^a-zA-Z]|$)|(^|[^a-zA-Z])alc(\.exe)?([^a-zA-Z]|$)'

if printf '%s' "$cmd" | grep -Eiq "$build_re"; then
  cat >&2 <<'MSG'
A Business Central build/compile just ran. Per repo policy (see AGENTS.md), before
treating this feature's Implement step complete you MUST:

  1. Run the four mandatory verifier agents IN PARALLEL:
     al-code-quality-reviewer, al-readability-checker,
     al-test-coverage-validator, al-test-validator.
  2. Run a BCQuality review over the changed AL: consume .claude/bcquality
     (al-code-review), citing matched knowledge files in each finding's references[].

Do not consider the task done until these have run and their findings are
resolved or explicitly acknowledged.
MSG
  exit 2
fi

exit 0
