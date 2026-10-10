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
2. Order check: `phase` should be `plan` or `inspect`. If not, warn once in one line, then run.
3. Set `phase` to `inspect` in state.json (keep the other keys).

## Steps

1. Note `git status --porcelain`.
   Start the `st-inspect` subagent (`stratum:st-inspect`) with absolute paths: plugin root, project root, feature dir.
   Tell it: follow `<plugin root>/procedures/analyze.md` (`<PLUGIN_ROOT>` is the plugin root), then its validate checks.
   After it returns, run `git status --porcelain` again: only `plan.md` may change.
   Run `git diff` on `plan.md`: it touches only its `## Validate` section.
   Any other change is a finding.
2. **Findings.** Check each finding against the source and drop the false ones (see `/stratum:st`).
   Big decisions go to the user, one at a time, each with your recommendation.
   Small ones you fix and list at the gate.
   Fixes to spec, plan or tasks go to the `st-plan` subagent (resume it with `SendMessage` if it is still alive); have `st-git` commit them.
3. If any CRITICAL finding was fixed, run `st-inspect` once more. It replaces its older `## Validate` section.
4. **Advisor.** If an advisor is set (`/advisor`), consult it on the plan before the gate: missed
   auth invariants, schema or contract breaks, hidden breaking changes. Treat its notes as
   findings: check each against the source, then fix or bring to the user.

## Gate: user OKs the build

Show in short form: coverage, remaining findings by severity, small fixes made,
findings dropped, and the verdict.
Ask: "OK to build?" Start `/stratum:st-build` only on yes.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
