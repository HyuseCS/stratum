---
name: st-check
description: Full-lane Check phase. Run st-check (cross-artifact analysis, read-only) then st-validate, bring decisions to the user, and stop at the gate "user OKs the build".
---

# /stratum:st-check

You are the orchestrator. You route and verify.
Plugin root (`<plugin root>`) is two levels up from this skill's base directory.

## 0. Start

1. Read `<project>/.stratum/state.json`. If there is no `feature_directory`, stop and tell the
   user to run `/stratum:st-define`.
2. Order check: `phase` should be `plan` or `check`. If not, warn once in one line, then run.
3. Set `phase` to `check` in state.json (keep the other keys).

## Steps

1. Note `git status --porcelain`. Start the `st-check` subagent (`stratum:st-check`) with absolute
   paths: plugin root, project root, feature dir. Tell it: follow
   `<plugin root>/procedures/analyze.md` (`<PLUGIN_ROOT>` is the plugin root); read-only.
   After it returns, confirm `git status --porcelain` is unchanged.
2. Start the `st-validate` subagent (`stratum:st-validate`) with the same paths and the
   st-check findings.
3. **Findings.** Merge both reports. Findings that need a decision go to the user, one at a time,
   each with your recommendation. Fixes to spec, plan or tasks go to the `st-plan` subagent
   (resume it with `SendMessage` if it is still alive); have `st-git` commit them.
4. If any CRITICAL finding was fixed, run `st-check` once more.

## Gate: user OKs the build

Show in short form: coverage, remaining findings by severity, and validate's verdict.
Ask: "OK to build?" Start `/stratum:st-build` only on yes.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
