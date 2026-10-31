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
2. Read `<feature>/tasks.md`. Work on unticked tasks in order, phase by phase, except stories that tasks.md says share no files (see Parallel tasks).

## Per task

1. A test task goes to the `st-test` agent (`stratum:st-test`). It writes the test and shows it fails.
   Check the failing output yourself. A test that passes before the build is wrong.
2. The build tasks that follow go to the `st-build` agent (`stratum:st-build`). It builds until that test
   passes and ticks the task `[X]` in tasks.md. Setup tasks with no test go straight to `st-build`.
   On a `lock:` timeout line from an agent, tell the user the line and the test that waits, in short words.
3. **Verify.** From the project root, run
   `bash <plugin root>/scripts/st-verify.sh '<test command>' <files the task touched>`.
   It re-runs the test, greps the diff for added comment lines, and prints one line. Send any
   `FAIL` back to `st-build`.
   A test marked `[lock]` runs only through the test lock: `bash <plugin root>/scripts/st-lock.sh -- <test command>`.
4. **Two tries.** If the test is still red after 2 `st-build` tries, run the advisor (see Advisor): save the task text and both failure outputs to files in your scratchpad, then run
   `bash <plugin root>/scripts/st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>`: root cause or rabbit hole?
   For a `[P]` task in a worktree, run it in the main session after the subagent reports both failures, with the working directory at that worktree's root and `<feature dir>` as the main checkout's absolute path, so the record lands in the main checkout. Start `st-debug` from the main session too, with the worktree path; it diagnoses, fixes and verifies in that worktree.
   Then start the `st-debug` agent (`stratum:st-debug`) with the task, the test, both failure outputs, and the advisor's answer.
5. **Commit.** The `st-git` agent (`stratum:st-git`) commits the exact paths of the task, with tasks.md, and `<feature dir>/advisor.md` if it changed.

A task marked `[screen: <mode>]` goes to `/stratum:st-design` (Skill tool) in that mode, not to `st-build`. Go on with the other tasks while the screen waits, and show the screen's report with the story review.
If the Design lane cannot start (its tool check fails, or no dev server answers), pause only that task. Tell the user what is missing in short, simple words, and go on with the other tasks. On the user's "go", run the screen again from `/stratum:st-design` step 1.
Never move a `[screen]` task to `st-build` and `st-ui-ux` without telling the user.
If `/stratum:st-design` ends with no report, the screen task stays open: tell the user.
After the user's OK and the st-design commit, tick the `[screen]` task and have `st-git` commit tasks.md.
A task that is both `[P]` and `[screen]` goes to `/stratum:st-design` in the main session, not to a worktree subagent.

## Parallel tasks `[P]`

When the user said "build with workers" or named a machine ("US2 on the laptop"), run the phase's `[P]` tasks with `/stratum:st-worker` (Skill tool), one worker per task. Otherwise use subagents:

When the project is this session's own repo, run each `[P]` task of a phase in its own subagent
with `isolation: "worktree"`, all started in one message.
User stories that tasks.md says share no files run at the same time.
Each runs the per-task steps in its worktree, except step 4: a subagent whose test is still red after 2 tries stops and reports both failures.
Then check each branch (tests green, no added comments) and merge it into the feature branch yourself. Keep each worktree and branch after the merge. Delete one only when the user says so.
Never delete a remote branch: the user does that. If the project is another repo, run `[P]` tasks one after another.

## Per story (after its last task)

1. The `stratum:st-review` agent on the story's diff.
   Send the story's small-decision list to the advisors: `bash <plugin root>/scripts/st-advisor.sh decisions <feature dir> <list file>`.
2. For screen work not done by the Design lane, run the `st-impeccable` skill on the changed screens.
3. Check each finding against the source first (see `/stratum:st`). Send the real, small ones to
   `st-build`; verify and commit them like a task. Big ones go to the user. Drop the false ones.
4. Run the story's steps from `<feature>/quickstart.md`. Give the user exact steps for any
   step you cannot run.

## Stop only when

- A subagent is blocked, or a big decision falls outside the plan (see `/stratum:st`). Bring it
  to the user, one question at a time, with your recommendation. Decide small ones yourself.
- Work touches a higher impact area than the lane allows: move up a lane.

Note `git rev-parse HEAD` after each story's review fixes are committed: that is the story's review point.
When all tasks are ticked, run the end-of-Build advisor pass.
Skip the end-of-Build advisor pass when every story had an `st-review` and no code changed after the last one.
Otherwise run it once, on the changes after the last review only: `bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <last review sha>`.
Handle its notes like review findings.
Then run `bash <plugin root>/scripts/st-advisor.sh count <feature dir>` and show its line word for word.
Then say the build is done, list the small decisions and findings (fixed and dropped), and name
the next phase: `/stratum:st-close`.

## Advisor

The advisor is Codex (the `codex` CLI), a model from another vendor. In mode `auto` the risk level picks the advisors at each point:

| Point | high | normal | low | none |
|-------|------|--------|-----|------|
| plan before the Plan gate (`st-plan` step 4, stale-checked at the build gate by `st-inspect`) | both | Codex | none | none |
| test red after 2 tries | Codex, then both if still red | Codex | `/advisor` | none |
| story small decisions | both | Codex | `/advisor` | none |
| diff at the end of Build | both | Codex | `/advisor` | none |

Every Fast-lane point uses `/advisor`. The Quick lane has no advisor.

- Run `bash <plugin root>/scripts/st-advisor.sh <point> ...` from the project root in the foreground, with a Bash timeout of 600000 ms, and wait for it. No background run, no polling.
- Codex only reviews, in the read-only sandbox. Never run `codex` to build or fix. Codex runs in the background as before, also in herdr.
- `no advisor: codex not found`, `no advisor: mode not set` (show the user its line) or `no advisor: mode off`: go on as before; consult `/advisor` only if the user set one.
- First line `mode both: also consult /advisor if one is set`: after Codex, consult `/advisor` on the same input if one is set.
- `advisors: codex`: Codex runs. `advisors: both`: Codex runs, then consult `/advisor` on the same input, then hold the talk. `advisors: /advisor`: consult `/advisor` only. `advisors: none`: no advisor at this point, and skip `check plan`.
- At a High point both advisors first answer alone. Then hold the talk: at most 3 rounds of `bash <plugin root>/scripts/st-advisor.sh round <point> <feature dir> <n> <views file>`, each with `/advisor`'s answer to the same views.
  In round 3 each advisor proposes a compromise for every open point. A compromise both accept is a combined finding. A point with no compromise both accept goes to the user with both views, in short, simple words.
  If one advisor has no answer (`no advisor`, mode off), the point runs with the one left, and the talk record says so.
  After the talk, record it: `bash <plugin root>/scripts/st-advisor.sh talk <point> <feature dir> <file>` with the rounds, the agreed points, the compromises, the points sent to the user and the calls.
- `APPROVED`: go on.
- `WAIVED sha256 <hash>`: the plan changed only by fixes, and `check plan` passes until the input changes again.
- `REVISE`: handle each finding like a review finding: check it against the source, fix the real small ones, bring big ones to the user, drop the false ones.
  A `REVISE` with only MEDIUM and LOW findings counts as passed: handle each finding and do not run the point again.
  Run the point again only when a CRITICAL or HIGH fix changed the plan, or the plan's approach changed.
  The approach changed when a user story or task was added or removed, a file outside the plan's file list is now touched, or a design choice in `plan.md` was replaced. A fix inside a task's own text and files is not an approach change.
  Two rounds at most per point per gate pass, then the user decides. A later gate pass starts a new count.
- `no change since <base>: skip`: nothing changed after the last review, so the pass is skipped.
- After each `/advisor` call, run `bash <plugin root>/scripts/st-advisor.sh note <point> <feature dir> "<one-line summary>"`.
- `BLOCKED: <reason>`: stop and show the user the reason. Nothing passes the gate. If the user says to continue, run `bash <plugin root>/scripts/st-advisor.sh continued <point> <feature dir>` and skip the point. Do not retry it in this gate pass.
- Each run appends a record to `<feature dir>/advisor.md`: the point, the time, the SHA256 of the input, the verdict and the findings. The mode comes from `.stratum/advisor.json`: `auto` (the default when the file has no `mode`), `codex`, `both` or `off`. No file means off, with the `mode not set` line.
- At the build gate, `check plan` compares the latest plan record with the current input. `advisor approval is stale` or `no record` counts as no approval: run the plan point once more, as a round. Skip the check after a `no advisor` line.
- Exit 2 with a `usage:` line or `cannot hash inputs`: the script could not read or hash its inputs. Nothing was recorded and nothing was sent. Fix the input or the tool and run the point again.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
