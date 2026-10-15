# Data Model: Run Stratum Steps On Demand

No stored data changes shape. The entities are plugin files, one hook line, and values read from
`.stratum/state.json` and git.

## Agent / command pair

- An agent file `agents/<name>.md` and a skill `skills/<name>/SKILL.md` with the same `<name>`.
- Rule (FR-005, SC-001): every agent has one. The check is one-way: a skill may have no agent.
- New pairs: `st-review`, `st-test`, `st-debug`, `st-git` (new skills, agents unchanged; change 002 later edited `agents/st-review.md`).
  `st-impeccable`, `st-ponytail-audit`, `st-ponytail-debt` (new agents, skills unchanged).
- Command fields: frontmatter `name`, `description`; heading `# /stratum:<name> <args>`; one start
  line `` (`stratum:<name>`) ``; one check step. Text: [contracts/commands.md](contracts/commands.md).

## Command inputs

| Input | Source when the user gives none | Used by | None found |
|-------|---------------------------------|---------|------------|
| feature dir | `feature_directory` in `.stratum/state.json` | st-review, st-test, st-debug | "No current feature. Run `/stratum:st-define`." and stop |
| diff range | `main..HEAD` | st-review | no `main`: "No `main` branch. Give the range." and stop |
| story | every story in the range | st-review | n/a |
| task IDs | none | st-test, st-debug | one line, stop |
| test command | the task's line in `<feature>/tasks.md` | st-debug | "Give the test command." and stop |
| file list | `git status --porcelain --untracked-files=all`, then the user picks | st-git | empty status: "Nothing to commit." and stop |

## Background agent

- Fields: frontmatter `name` (= the skill name, D3), `description` (says "in the background"),
  `tools` (no `Edit`, no `Write`), `model` (`opus` for `st-impeccable` and `st-ponytail-audit`, `sonnet` for `st-ponytail-debt`, decision D1). Text: [contracts/background.md](contracts/background.md).
- Tools: `st-impeccable` = `Read, Grep, Glob, Bash, Skill`. `st-ponytail-audit`,
  `st-ponytail-debt` = `Read, Grep, Glob, Skill`.
- Mode: `st-impeccable` runs `audit` only (research R7). The ponytail agents run their skill as is
  and never write the ledger file.
- Output: one report to the main session. No file change (FR-007, SC-004).

## Background rule (session-start line)

- Lives in the `Stratum rule:` text that `hooks/st-session-start.sh:17` prints when the project
  has `.stratum/`. The same echo holds main's agent-naming sentence (commit 0715256: the Agent
  description is only the task). The background text follows it.
- States: the user asks for one of the 3 skills (4 after change 002 added `st-review`) in the background -> note `git rev-parse HEAD` and
  `git status --porcelain --untracked-files=all`, then start `stratum:<name>` with the plugin root,
  the project root and, for `st-impeccable`, the target. When the report arrives, run both again:
  any difference is a finding to check. The user asks for any other skill in the background
  (except `st-handoff`) -> one line: it runs only in the main session.

## Handoff run mode

| When | Where | Who writes `.stratum/handoff.md` |
|------|-------|-----------------------------------|
| The user said they are done or is ending the session | main session | the main session |
| A `Handoff` fork is already running | no new fork; wait for its report (and before the reply ends, if the user said they are done) | the running fork |
| Any other time | Agent tool, `subagent_type: "fork"`, description `Handoff`, background | the fork |
| The fork's report shows no file written | main session | the main session |
| The fork cannot start | main session | the main session, with one line saying so |

## Stop rules

- `st-git`: the agent's report must start with `Committed`. Otherwise show its text and stop.
- `st-debug`: the agent reports `Stopped`, or changes no file: show its text and stop.

## Agent list (`hooks/st-models.py` `AGENTS`)

- Read from `agents/*.md`. After the change, 13 sorted: `st-build`, `st-close`, `st-debug`,
  `st-fast`, `st-git`, `st-impeccable`, `st-inspect`, `st-plan`, `st-ponytail-audit`,
  `st-ponytail-debt`, `st-quick`, `st-review`, `st-test`.
- `.stratum/models.json` accepts the 3 new names. `templates/models.json` does not change.
