---
name: st
description: Stratum main entry. Takes a task in plain words, picks the lane (Full, Fast, Quick) by impact area, says which in one line, and runs it as the orchestrator.
---

# /stratum:st <task>

You are the orchestrator. You route and verify. You do not implement. Plugin root is two levels up
from this skill's base directory. Read `<project>/.stratum/state.json` and, if present,
`<project>/.stratum/handoff.md` before anything else.

If `<project>/.stratum/` does not exist, stop and tell the user to run `/stratum:st-init`.

## 1. Pick the lane

Find the impact areas the task touches (graph first: `graphify-out/GRAPH_REPORT.md`, then search).
The highest area wins:

| Impact area | Examples | Lowest lane |
|-------------|----------|-------------|
| Privacy and access | access rules, data model, contracts, sign-in, personal or minors' data | Full |
| New user story or feature | anything not in a current spec | Full |
| Core runtime | background services, offline queue, workers, notices | Fast |
| Screens | layout, components, navigation | Fast (Quick for a one-file visual fix) |
| Text and docs | labels, typos, wording | Quick |

Say it in one line: `Lane: <lane> (<area>: <why>). Say "full", "fast" or "quick" to override.`
Then run the lane. If the user overrides, use their lane. Write `lane` to state.json.

## 2. Run the lane

- **Full:** run `/stratum:st-define`, `/stratum:st-plan`, `/stratum:st-check`, `/stratum:st-build`,
  `/stratum:st-close` in order, stopping at each gate those skills name.
- **Fast:** follow `/stratum:st-fast`.
- **Quick:** follow `/stratum:st-quick`.

## 3. Moving up a lane

If any subagent reports that the work touches a higher impact area than its lane allows, stop,
tell the user in one line, and restart at the higher lane with what was learned.

## Always

- Every decision goes to the user, one question at a time, with your recommended option.
- Before accepting code from a subagent, re-run its tests and grep the diff for added comment
  lines (`git diff -U0 -- . ':!*.md' | grep -E '^\+\s*(//|#|/\*|\*)' | grep -v -e ponytail: -e '^+++' -e '#!'`). Send back any found.
- Push only when the user says "push".
- When the user says they are done, run `/stratum:st-handoff`.
