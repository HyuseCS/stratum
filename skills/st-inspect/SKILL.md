---
name: st-inspect
description: Full-lane Inspect phase. Run st-inspect (cross-artifact analysis and validate checks in one pass), bring decisions to the user, and stop at the gate "user OKs the build".
---

# /stratum:st-inspect

You are the orchestrator. You route and verify.
Plugin root (`<plugin root>`) is two levels up from this skill's base directory.

## 0. Start

1. Read `<project>/.stratum/state.json`. If there is no `feature_directory`, stop and tell the
   user to run `/stratum:st-define`.

## Steps

1. Note `git status --porcelain` and `git diff -- <feature>/plan.md`.
   Start the `st-inspect` subagent (`stratum:st-inspect`) with absolute paths: plugin root, project root, feature dir.
   Tell it: follow `<plugin root>/procedures/analyze.md` (`<PLUGIN_ROOT>` is the plugin root), then its validate checks.
   After it returns, run `git status --porcelain` again: only `plan.md` may change.
   Run `git diff -- <feature>/plan.md` again and compare it with the noted diff: it touches only its `## Validate` section.
   Any other change is a finding.
2. **Findings.** Check each finding against the source and drop the false ones (see `/stratum:st`).
   Big decisions go to the user, one at a time, each with your recommendation.
   Small ones you fix and list at the gate.
   Fixes to spec, plan or tasks go to the `st-plan` subagent (resume it with `SendMessage` if it is still alive); have `st-git` commit them.
3. If any CRITICAL finding was fixed, run `st-inspect` once more. It replaces its older `## Validate` section.
4. **Advisor.** Run `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>` from the project root in the foreground, with a Bash timeout of 600000 ms, and wait for it.
   Codex reviews spec, plan and tasks in the read-only sandbox. Risks: missed auth invariants, schema or contract breaks, hidden breaking changes.
   Improvements: a simpler or better approach, tasks to cut or merge.
   Handle its answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md`; big ones go to the user before the gate.
   A later re-run of `st-inspect` (step 5) changes `plan.md` and costs a round.
5. If a fix removed or renamed a task in step 2 or 4, grep each old ID from the fix's diff of `tasks.md` in the `## Validate` section of `plan.md`; on any hit run `st-inspect` once more.

## Gate: user OKs the build

Run `bash <plugin root>/scripts/st-advisor.sh check plan <feature dir>` and show its line; `advisor approval is stale` counts as no approval. Have `st-git` commit `<feature dir>/advisor.md` if it changed.
Show in short form: coverage, remaining findings by severity, small fixes made,
findings dropped, and the verdict.
Ask: "OK to build?" Start `/stratum:st-build` only on yes.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
