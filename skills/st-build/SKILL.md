---
name: st-build
description: Full-lane Build phase. Run the build loop over tasks.md - test first, build, verify, commit per task; debug after 2 failed tries; review each story.
---

# /stratum:st-build

You are the orchestrator. You route and verify; subagents write the code.
Plugin root (`<plugin root>`) is two levels up from this skill's base directory. Pass every
subagent absolute paths: plugin root, project root, feature dir, and its task IDs.

## 0. Start

1. Read `<project>/.stratum/state.json`. If there is no `feature_directory`, stop and tell the
   user to run `/stratum:st-define`.
2. Order check: `phase` should be `check` or `build`. If not, warn once in one line, then run.
3. Set `phase` to `build` in state.json (keep the other keys).
4. Read `<feature>/tasks.md`. Work on unticked tasks in order, phase by phase.

## Per task

1. A test task goes to `st-test` (`stratum:st-test`). It writes the test and shows it fails.
   Check the failing output yourself. A test that passes before the build is wrong.
2. The build tasks that follow go to `st-build` (`stratum:st-build`). It builds until that test
   passes and ticks the task `[X]` in tasks.md. Setup tasks with no test go straight to `st-build`.
3. **Verify.** Re-run the test yourself. Grep the diff for added comment lines:
   `git diff -U0 -- . ':!*.md' | grep -E '^\+\s*(//|#|/\*|\*)' | grep -v -e ponytail: -e '^+++' -e '#!'`
   Send any hit back to `st-build`.
4. **Two tries.** If the test is still red after 2 `st-build` tries, consult the advisor if one
   is set (`/advisor`): root cause or rabbit hole? Then start `st-debug` (`stratum:st-debug`)
   with the task, the test, both failure outputs, and the advisor's answer.
5. **Commit.** `st-git` (`stratum:st-git`) commits the exact paths of the task, with tasks.md.

## Parallel tasks `[P]`

When the project is this session's own repo, run each `[P]` task of a phase in its own subagent
with `isolation: "worktree"`, all started in one message. Each runs the per-task steps in its
worktree. Then check each branch (tests green, no added comments) and merge it into `main`
yourself. Keep each worktree and branch after the merge. Delete one only when the user says so.
Never delete a remote branch: the user does that. If the project is another repo, run `[P]` tasks one after another.

## Per story (after its last task)

1. `st-review` (`stratum:st-review`) on the story's diff.
2. Run the `st-ponytail-review` skill on the same diff.
3. For screen work, run the `st-impeccable` skill on the changed screens.
4. Check each finding against the source first (see `/stratum:st`). Send the real, small ones to
   `st-build`; verify and commit them like a task. Big ones go to the user. Drop the false ones.
5. Run the story's steps from `<feature>/quickstart.md`. Give the user exact steps for any
   step you cannot run.

## Stop only when

- A subagent is blocked, or a big decision falls outside the plan (see `/stratum:st`). Bring it
  to the user, one question at a time, with your recommendation. Decide small ones yourself.
- Work touches a higher impact area than the lane allows: move up a lane.

When all tasks are ticked, consult the advisor if one is set (`/advisor`) on the feature's full
diff: hidden regressions, broken rules from the constitution. Handle its notes like review
findings. Then say so, list the small decisions and findings (fixed and dropped), and name the
next phase: `/stratum:st-close`.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
