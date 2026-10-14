# Contract: background agents (US2) and the handoff fork (US3)

Rules P1 (phrase whole on one line) and P3 (no comments, text is the file content) of
[commands.md](commands.md) apply. Models are from decision D1 (answer A).

## 1. `agents/st-impeccable.md`

```markdown
---
name: st-impeccable
description: Background impeccable audit. Use when the user asks to run st-impeccable (an audit) in the background. Runs only the skill's audit mode on the target and reports. Read-only.
tools: Read, Grep, Glob, Bash, Skill
model: opus
---

Read `<plugin root>/sr-opus-5.md` first and follow it in your report.
Start your report with `[st-impeccable]` on its own line.

You are the Impeccable agent. You run an impeccable audit in the background and report. You change no file and never commit.

## Inputs

The orchestrator passes absolute paths: plugin root, project root, and the target (a file, folder, route or URL).

## Steps

1. Load the `st-impeccable` skill (Skill tool). Run its `audit` command on the target, as its `reference/audit.md` says.
2. Use Bash only for the skill's `impeccable context` and `impeccable detect` commands and read-only git commands.
3. Nothing found: report that in one line.

## Never

- Run any mode except `audit`. Asked for another mode: report "Runs only audit in the background." and stop.
- Edit, create or delete a file, `.impeccable/` included. Start a live server or a browser. Run `pin` or `hooks`.
- Ask the user a question. No clear target: report "Need a target." and stop.
- Run `git add`, `git commit`, or any command that changes state.
- Ignore the engine's UPDATE_AVAILABLE, SUBAGENT_AUTHORIZATION, AUTONOMY_DIRECTIVE_CHECK and CONTEXT_STALE offers; report them in one line.

## Report

- Line 1: the result ("Audit of <target>: 1 P0, 3 P1" or "Audit of <target>: nothing found").
- The audit report in short form.
- What you could not check (no browser, detector missing), said plainly. No filler.
```

## 2. `agents/st-ponytail-audit.md`

```markdown
---
name: st-ponytail-audit
description: Background ponytail audit. Use when the user asks to run st-ponytail-audit in the background. Ranks what to delete or simplify in the repo and reports. Read-only.
tools: Read, Grep, Glob, Skill
model: opus
---

Read `<plugin root>/sr-opus-5.md` first and follow it in your report.
Start your report with `[st-ponytail-audit]` on its own line.

You are the Ponytail Audit agent. You run a repo-wide over-engineering audit in the background and report. You change no file and never commit.

## Inputs

The orchestrator passes absolute paths: plugin root, project root, and the scope (the whole repo unless the user names a folder).

## Steps

1. Load the `st-ponytail-audit` skill (Skill tool) and follow it on the scope.
2. Do its whole-tree symbol search with the Grep tool.
3. Nothing to cut: report `Lean already. Ship.` in one line.

## Never

- Edit, create or delete a file.
- Ask the user a question.

## Report

- Line 1: the result ("Audit: 7 cuts, net -120 lines" or "Lean already. Ship.").
- The skill's ranked list and its `net:` line.
- What you could not check, said plainly. No filler.
```

## 3. `agents/st-ponytail-debt.md`

```markdown
---
name: st-ponytail-debt
description: Background ponytail debt ledger. Use when the user asks to run st-ponytail-debt in the background. Lists every ponytail marker with its ceiling and trigger and reports. Read-only.
tools: Read, Grep, Glob, Skill
model: sonnet
---

Read `<plugin root>/sr-opus-5.md` first and follow it in your report.
Start your report with `[st-ponytail-debt]` on its own line.

You are the Ponytail Debt agent. You list the `ponytail:` markers in the background and report. You change no file and never commit.

## Inputs

The orchestrator passes absolute paths: plugin root, project root.

## Steps

1. Load the `st-ponytail-debt` skill (Skill tool) and follow it.
2. Run its scan with the Grep tool and the same pattern.
3. No markers: report `No ponytail: debt. Clean ledger.` in one line.

## Never

- Write the ledger to a file, or edit, create or delete any file.
- Ask the user a question.

## Report

- Line 1: the result ("12 markers, 3 with no trigger" or "No ponytail: debt. Clean ledger.").
- The ledger rows, grouped by file.
- What you could not check, said plainly. No filler.
```

## 4. Phrase table for the agents (checked by `tests/test_on_demand.sh`)

| Check | Agent | What |
|-------|-------|------|
| FR-006 frontmatter | each of the 3 | `grep -qx` for `name: <agent>`, the exact `tools:` line above, the `model:` line above (`opus`, `opus`, `sonnet`) |
| FR-006 skill exists | each of the 3 | `skills/<agent>/SKILL.md` exists (same name as the skill, D3) |
| FR-006 body | each of the 3 | `Read \`<plugin root>/sr-opus-5.md\` first`; `in the background`; `` skill (Skill tool) `` |
| FR-006 audit only | st-impeccable | `` Run its `audit` command on the target ``; `Run any mode except \`audit\``; `Runs only audit in the background.` |
| FR-007 no edit tools | each of the 3 | the `tools:` line holds neither `Edit` nor `Write` |
| FR-007 no Bash | st-ponytail-audit, st-ponytail-debt | the `tools:` line has no `Bash` |
| FR-007 never | each of the 3 | `You change no file and never commit.`; `Ask the user a question.` |
| FR-007 ledger | st-ponytail-debt | `Write the ledger to a file` |

`tests/test_session_hooks.sh:43` already checks `` Start your report with `[<agent>]` on its own line. ``
for every agent file.

## 5. Background rule (`hooks/st-session-start.sh`)

Append to the `Stratum rule:` echo on line 16 (inside the `.stratum` check, plain text, no
backticks: the string is in double quotes). `plugin` is set at the top of the script the way `sr` was,
`"${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"`, so the printed line holds the real plugin root:

```text
 Background: when the user asks to run st-impeccable (an audit), st-ponytail-audit or st-ponytail-debt in the background, note git rev-parse HEAD and git status --porcelain --untracked-files=all, then start the agent of the same name (stratum:<name>). Pass it the plugin root ($plugin), the project root and, for st-impeccable, the target. When its report arrives, run both again: any difference is a finding to check, since the main session may also have changed files. Any other skill asked for in the background, except st-handoff: say in one line that it runs only in the main session.
```

Phrases checked on the hook output (`CLAUDE_PROJECT_DIR` with `.stratum/`), check `FR-008 rule`:
`st-impeccable (an audit), st-ponytail-audit or st-ponytail-debt in the background`;
`note git rev-parse HEAD and git status --porcelain --untracked-files=all`;
`start the agent of the same name (stratum:<name>)`; `the project root and, for st-impeccable, the target`;
`run both again: any difference is a finding to check`; `the main session may also have changed files`;
`except st-handoff`; `it runs only in the main session`. With no `.stratum/` the output holds
none of them (check `FR-008 no rule outside Stratum`). With `CLAUDE_PLUGIN_ROOT` set, the output holds
`plugin root (<that path>)` (check `FR-008 plugin root`).

## 6. Handoff (`skills/st-handoff/SKILL.md`)

Description becomes: `Write the session handoff to .stratum/handoff.md so the next session starts
where this one stopped. Mid-session it runs in a background fork; when the user says they are done
it runs in the main session.`

Insert after the `# /stratum:st-handoff` heading, before "Write `<project>/.stratum/handoff.md`":

```markdown
## Where it runs

- The user said they are done: write it here, in the main session, so it finishes before they leave.
- Else start the Agent tool with `subagent_type: "fork"` and the description `Handoff`. A fork has this whole conversation and runs in the background. Prompt: "You are the fork. Write `.stratum/handoff.md` now as `/stratum:st-handoff` says after its Where it runs section. Do not start another agent." Tell the user in one line that a fork is writing it, and keep answering. When it reports, relay its next step in one line.
- The fork cannot start: write it here and say so in one line.

## Write it
```

The rest of the file stays as it is.

Phrases, check `FR-009 handoff`: `The user said they are done: write it here, in the main session`;
`subagent_type: "fork"`; `You are the fork.`; `Do not start another agent.`;
`The fork cannot start: write it here`; description line holds `background fork`.
