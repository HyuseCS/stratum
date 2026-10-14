# Contract: the four on-demand commands (US1)

Rules for every file below:

- P1. Each phrase in a phrase table sits whole on one line of the built file. Long lines are fine.
- P2. Each skill has exactly one line that holds `` (`stratum: ``.
- P3. No comments. Frame of `skills/st-quick/SKILL.md`. The text below is the file content. The
  build may fix grammar but keeps every phrase.
- P4. The agent files `agents/st-review.md`, `agents/st-test.md`, `agents/st-debug.md`,
  `agents/st-git.md` do not change (research R10).

## 1. `skills/st-review/SKILL.md`

```markdown
---
name: st-review
description: Run the st-review agent on demand on the current feature's diff (default main..HEAD), then check each finding against the source before showing it.
---

# /stratum:st-review [range] [story]

Plugin root is two levels up from this skill's base directory.

1. Read `<project>/.stratum/state.json`. No `feature_directory`: say "No current feature. Run `/stratum:st-define`." and stop.
2. Range: the one the user gave, else `main..HEAD`. No range given and `git rev-parse --verify main` fails: say "No `main` branch. Give the range." and stop.
3. Start the `st-review` subagent (`stratum:st-review`) with absolute paths: plugin root, project root, feature dir. Pass the story the user named (else every story in the range) and the range.
4. **Check.** Check each finding against the source before you show it: the defect is at that `file:line`, and the stated cause is the real one. Drop the false ones.
5. Show the real findings, then the dropped ones with why, in short form. Fixes go through a lane.
```

## 2. `skills/st-test/SKILL.md`

```markdown
---
name: st-test
description: Run the st-test agent on demand for task IDs of the current feature, then re-run each test and confirm it fails for the right reason.
---

# /stratum:st-test <task IDs>

Plugin root is two levels up from this skill's base directory.

1. Read `<project>/.stratum/state.json`. No `feature_directory`: say "No current feature. Run `/stratum:st-define`." and stop.
2. No task ID given: say "Give the task IDs, for example `/stratum:st-test T004`." and stop.
3. Start the `st-test` subagent (`stratum:st-test`) with absolute paths: plugin root, project root, feature dir. Pass the task IDs.
4. **Check.** Run each test command it reports again from the project root. It must exit non-zero and fail for the right reason: the line it quoted, from missing behavior, not a typo, an import error or broken setup. A test that passes is wrong: say so.
5. Show per task: test file, command, failing line. Commit nothing.
```

## 3. `skills/st-debug/SKILL.md`

```markdown
---
name: st-debug
description: Run the st-debug agent on demand for one task of the current feature, then verify with st-verify.sh (test green, no added comment lines).
---

# /stratum:st-debug <task ID> [test command]

Plugin root is two levels up from this skill's base directory.

1. Read `<project>/.stratum/state.json`. No `feature_directory`: say "No current feature. Run `/stratum:st-define`." and stop.
2. No task ID given: say "Give the task ID, for example `/stratum:st-debug T004`." and stop.
3. Test command: the one the user gave, else the one in the task's line in `<feature>/tasks.md`. None: say "Give the test command." and stop.
4. Start the `st-debug` subagent (`stratum:st-debug`) with absolute paths: plugin root, project root, feature dir. Pass the task ID, the test command, and what was tried (the user's words, else "nothing yet, run on demand").
5. It reports `Stopped`, or changed no file: show its text and stop.
6. **Check.** From the project root run `bash <plugin root>/scripts/st-verify.sh '<test command>' <files it changed>`. It re-runs the test and checks the files for added comment lines. Show its line. On `FAIL`, show the output and stop.
7. Commit nothing. The user commits with `/stratum:st-git`.
```

## 4. `skills/st-git/SKILL.md`

```markdown
---
name: st-git
description: Commit on demand through the st-git agent. With no file list, show the changed files and commit only the ones the user picks; then show the commit's file list.
---

# /stratum:st-git [files...]

Plugin root is two levels up from this skill's base directory.

1. Files: the paths the user gave. None given: run `git status --porcelain --untracked-files=all`. No output: say "Nothing to commit." and stop. Else show the changed files and ask the user which to commit. They pick none: stop.
2. Start the `st-git` subagent (`stratum:st-git`) with absolute paths: plugin root, project root. Pass the change (the user's words, else "on-demand commit") and the file list.
3. Line 1 of its report does not start with `Committed`: show its text and stop.
4. **Check.** Run `git log -1 --name-only --format=` and show it. It must list exactly the files given. If not, name the ones that differ.
5. Push only when the user says "push".
```

`--untracked-files=all` lists each new file, not its folder. `agents/st-git.md` never stages a
folder.

## 5. Phrase table (checked by `tests/test_on_demand.sh`)

Target is the skill folder under `skills/`. Each row is one check named `<FR> <skill>`.

| Check | Skill | Phrases (each `grep -qF --`) |
|-------|-------|------------------------------|
| FR-001 | st-review, st-test, st-debug, st-git | frontmatter line `name: <skill>` (`grep -qx`); heading starts `# /stratum:<skill>`; exactly 1 line holds `` (`stratum:<skill>`) `` |
| FR-002 | st-review | `` No `feature_directory` ``; `No current feature. Run`; `main..HEAD` |
| FR-002 | st-test, st-debug | `` No `feature_directory` ``; `No current feature. Run` |
| FR-003 | st-git | `git status --porcelain --untracked-files=all`; `Nothing to commit.`; `ask the user which to commit` |
| FR-004 | st-review | `Check each finding against the source before you show it` |
| FR-004 | st-test | `Run each test command it reports again`; `fail for the right reason` |
| FR-004 | st-debug | `<plugin root>/scripts/st-verify.sh '<test command>' <files it changed>` |
| FR-004 | st-git | `git log -1 --name-only --format=`; `It must list exactly the files given` |
| FR-005 | all | for every `agents/*.md`, `skills/<name>/SKILL.md` exists. The FAIL line names each agent with no command |

The FR-005 check prints `FAIL every agent has a command: <names>` so the missing agent is named
(spec US1 scenario 6). It is one-way on purpose: many skills have no agent.
