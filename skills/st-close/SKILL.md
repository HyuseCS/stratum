---
name: st-close
description: Full-lane Close phase. Start st-close for drift fixes, an optional gap report, lessons, and the shortcut list; update the docs graph; push only on the user's "push".
---

# /stratum:st-close

You are the orchestrator. You route and verify.
Plugin root (`<plugin root>`) is two levels up from this skill's base directory.

## 0. Start

1. Read `<project>/.stratum/state.json`. If there is no `feature_directory`, stop and tell the
   user to run `/stratum:st-define`.

## Steps

1. **Gap report or not.** If tasks.md has unticked tasks, make a gap report; otherwise skip
   it. Say which in one line; the user can override.
2. Start the `st-close` subagent (`stratum:st-close`) with absolute paths: plugin root, project
   root, feature dir, whether to make the gap report, and the base for the shortcut list. On a
   branch, the base is `main`. On `main`, the base is
   `git rev-parse "$(git log --diff-filter=A --format=%H -- <feature dir>/spec.md | tail -1)^"`.
   Tell it: the gap report follows `<plugin root>/procedures/converge.md` (`<PLUGIN_ROOT>` is the
   plugin root), steps 1 to 6 only.
3. **Verify.** Check each drift change against the code it names.
4. **Gaps.** For each gap, the user picks: send back, defer, or drop.
   - Send back is allowed once per feature. If tasks.md already has a `Convergence` phase, offer
     only defer or drop.
   - On send back: resume the same `st-close` with `SendMessage` to append the tasks (converge
     step 7), run `/stratum:st-build`, then return here without a gap report.
   - Defer and drop: `st-close` records them in spec.md.
5. **Lessons.** `st-close` appends proposed lessons to `docs/lessons.md`. Show the user any
   proposed constitution or harness change. Never apply one without their OK.
6. **Shortcuts.** `st-close` reports the rows from `scripts/st-shortcuts.sh`. Show each row.
   For each, the user picks fix now or keep.
   - Fix now: the `st-build` agent (`stratum:st-build`) fixes it, then verify with
     `bash <plugin root>/scripts/st-verify.sh '<test command>' <files touched>`. Then the `st-git`
     agent (`stratum:st-git`) commits the files the fix touched, with exact paths.
   - Keep: no record. The marker stays in the code, and `st-ponytail-debt` finds kept markers
     across the whole repo.
7. **Docs graph.** Run the `st-graphify` skill once to update the docs graph.
8. `st-git` commits the changed docs with exact paths.
9. Set `phase` to `done` in state.json.

## Gate

Report in short form: drift fixes, gaps and their fate, lessons, shortcuts and their fate. Then
say: "Say push to push." Push only on the user's "push".

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
