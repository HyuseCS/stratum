#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skill="${ST_PR_SKILL:-$root/skills/st-pr/SKILL.md}"
fail=0

while IFS=$'\t' read -r name phrase; do
  if grep -qF -- "$phrase" "$skill" 2>/dev/null; then
    echo "ok   $name"
  else
    echo "FAIL $name: $phrase"
    fail=1
  fi
done <<'EOF'
FR-002 commits	more than 30 commits
FR-002 files	more than 40 changed files
FR-002 script	Call `Workflow({name: "stratum:pr", args})`.
FR-002 ultracode	Ultracode is on when the latest system-reminder about Ultracode says so.
FR-003 current	Else take the current path: steps 2 to 4.
FR-004 message	Say the path in one line, with both counts and the Ultracode state
FR-005 read-only	git status --porcelain --untracked-files=all
FR-006 blocked	`blocked` is true: show the warnings and stop before the gate. Nothing is pushed.
FR-010 args	Pass `args` as a JSON object, not a string
L11 background	The workflow runs in the background: wait for its task notification.
L11 in progress	Never start a second run while one runs.
L11 no result	If the call cannot start, the run fails, or it returns no `bodyPath`
L11 fallback	then run steps 2 to 4 on the current path.
review F5 stop	If an output differs, show the difference and stop before the gate.
review F6 stale body	Delete `<scratchpad>/pr-body.md` if it exists.
review C3 diff hash	git diff HEAD | sha256sum
review C3 untracked hash	`sha256sum` of each `??` path in that status
review F8 gate	go to `## 5. Gate`
EOF

exit $fail
