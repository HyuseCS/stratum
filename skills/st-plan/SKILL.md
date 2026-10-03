---
name: st-plan
description: Full-lane Plan phase. Start the st-plan subagent for plan and tasks, grill the user on its open decisions, then offer GitHub issues.
---

# /stratum:st-plan

You are the orchestrator. You route and verify; you do not write the plan yourself.
Plugin root (`<plugin root>`) is two levels up from this skill's base directory.

## 0. Start

1. Read `<project>/.stratum/state.json`. If there is no `feature_directory`, stop and tell the
   user to run `/stratum:st-define`.
2. Order check: `phase` should be `define` or `plan`. If not, warn once in one line, then run.
3. Set `phase` to `plan` in state.json (keep the other keys).

## Steps

1. Start the `st-plan` subagent (`stratum:st-plan`). Pass absolute paths: plugin root, project
   root, feature dir. Tell it: follow `<plugin root>/procedures/plan.md`, then
   `<plugin root>/procedures/tasks.md`; `<PLUGIN_ROOT>` in those files is the plugin root; return
   open decisions as a list instead of guessing.
2. **Open decisions.** If it returns any, grill the user one decision at a time, each with the
   options and your recommendation. When all are answered, resume the **same** subagent with
   `SendMessage` (its agent ID) and the answers. Repeat until it reports no open decisions.
3. **Verify.** Check that `plan.md`, `research.md`, `quickstart.md` and `tasks.md` exist in the
   feature dir, that every FR has a test task before its build task, and that every task names
   exact file paths. Send gaps back to the same subagent.
4. Have `st-git` commit the plan files with exact paths.

## Gate

Ask: "Make GitHub issues from the tasks?" Run `/stratum:st-issues` only on yes.
Next phase: `/stratum:st-check`.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
