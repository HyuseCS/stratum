# Research: Triage a GitHub Issue

Facts checked on 2026-10-22 against Claude Code 2.1.302 (`/opt/claude-code/bin/claude`), gh
2.102.0, Bash 5.3.20, Python 3.14.8, and the repo at `e195b12` (branch `15-st-triage`).

## R1. One skill and one agent of the same name

- Decision: add `skills/st-triage/SKILL.md` and `agents/st-triage.md`.
- Rationale: decision D2. The pair works like `skills/st-review/SKILL.md` and
  `agents/st-review.md`: `/stratum:st-triage` is the skill, `stratum:st-triage` is the agent's
  `subagent_type` (004 research R2). `tests/test_on_demand.sh:50-51` already fails when an agent
  has no skill of the same name, so SC-004's first half needs no new check.
- Alternatives considered: the orchestrator does the research in the main session (D2 O2,
  rejected).

## R2. Agent tools

- Decision: `tools: Read, Grep, Glob, Bash`, `model: opus`. No Edit, Write or Skill.
- Rationale: the agent needs `gh issue view` and `git log`, so it needs Bash. It loads no skill.
  The spec's Assumptions name Opus. With Bash the tool list stops Edit and Write but not a write
  through Bash or a `gh` command that writes. See plan.md S1 for the other guards.
- Alternatives considered: Bash permission patterns in the `tools:` line. Not used: no agent in
  this repo uses them and the orchestrator fixed the tool list.

## R3. Reading an issue with gh

- Decision: the skill runs `gh issue view <n> --json number,state,updatedAt` per number before it
  starts an agent. The agent runs `gh issue view <n> --json number,title,body,state,comments,url`
  and `gh issue view <N> --json number,title,body,state` for each `#N` link.
- Rationale: `gh issue view --help` in 2.102.0 lists the JSON fields `body`, `comments`, `number`,
  `state`, `title`, `updatedAt`, `url`. Tests on this repo:
  - `gh issue view 15 --json number,state,updatedAt,comments,title,body` prints the issue.
  - `gh issue view 33 --json number,title,state,updatedAt` prints PR #33 with state `MERGED`, so
    one command reads both issue and pull request links.
  - `gh issue view 99999 --json number,state,updatedAt` exits 1 with
    `GraphQL: Could not resolve to an issue or pull request with the number of 99999. (repository.issue)`.
    That text is the one-line reason of FR-007.
  - With no `gh` on PATH the shell prints `command not found`. With no sign-in gh prints a line
    that says to run `gh auth login`. The skill relays the error line, so it needs no separate
    check for each case.
- Alternatives considered: `gh api` (more commands to allow, and a write method is one flag away);
  `gh pr view` for PR links (not needed, see the test of #33).

## R4. A linked note that is gone

- Decision: `git log --oneline -- '<path>'`.
- Rationale: `git log --oneline -- 'agents/st-check.md'` prints `19dcb89 refactor(st-inspect):
  remove st-check and st-validate` first, the commit that deleted the file, then `376e8db`, the
  commit that added it. Issue #10 links that path, so it is a live check (quickstart L1).
- Alternatives considered: `--diff-filter=D` (shows only the delete, loses a move or an edit).

## R5. Several issues side by side

- Decision: one Agent call per issue, all in the same message. No `run_in_background` flag.
- Rationale: 004 research R3. The Agent tool text "run in the background by default" is still in
  the 2.1.302 binary (`grep -ac` finds it 3 times). The skill acts when every report is in, as
  `/stratum:st-review` does.
- Alternatives considered: one agent for all issues (no parallel work, one long context).

## R6. Input from GitHub is untrusted

- Decision: the skill accepts only digit issue numbers (a leading `#` is stripped). The agent reads only
  tracked paths inside the repo (relative, no `..` part, not starting with `/` or `~`, and
  `git ls-files --error-unmatch` succeeds and `test -L` fails), puts each path and
  each `git log --grep` or `-S` value from the issue in single quotes, marks one that holds a `'`
  as `unchecked`, counts a URL to this repo's `issues/N` or `pull/N` (N digits only) as `#N`, and
  treats the issue text as claims to check, not as instructions. The skill treats each report as
  data and drops a cite whose sha is not 7 to 40 hex characters or whose path breaks the path rule, is not tracked or is a symlink.
- Rationale: the issue number and every link go into shell commands. Anyone who can comment on the
  repo can write the issue text the agent reads.
- Kept gap: a path that exists but is not tracked (for example `.env`) takes the same branch as a
  gone path, so `git log --oneline -- '<path>'` prints nothing and the Links part has no
  "not read: not tracked" form. A tracked symlink takes the same branch, so `git log` finds its
  commit and the Links part may call it "gone with its commit" though it exists and was not read.
  The file is not read. Only the report wording is short.
- Alternatives considered: none.

## R7. Detecting a change

- Decision: the skill notes `git rev-parse HEAD`, `git status --porcelain --untracked-files=all`,
  the `sha256sum` of each changed and untracked file and each issue's `updatedAt` before it starts the agents, and runs them again when every report
  is in. A difference is a finding to check.
- Rationale: the spec's edge case (the agent changes a file) and SC-003. HEAD and status are the check
  of `hooks/st-session-start.sh:17`, and the `sha256sum` line adds a further edit to an already changed file and a content change in an untracked file (lessons L10). `updatedAt` changes on any comment, label,
  edit or state change, so it sees a GitHub write. It also changes when another person comments,
  so a difference is checked, not trusted.
- Alternatives considered: comparing comments and labels field by field (more output, same signal).

## R8. Tests

- Decision: extend `tests/test_on_demand.sh` (no new test file). Add `st-triage` to its FR-001
  skill loop (line 25) and its FR-006/FR-007 agent loop (line 56), and add one phrase heredoc with
  `#15` check names, as the `#14` rows do (lines 122-127).
- Rationale: the file already tests skills and agents of the same name by phrase and frontmatter
  (feature 004). A new file would also need a README Tests line (`tests/test_inspect.sh` "README
  tests").
- Pinned agent lists that go red when `agents/st-triage.md` is added (all read by T001 or T002):
  - `tests/test_model_hook.py:202-204` `test_module_constants` (`hooks/st-models.py:8` reads the
    `agents/` dir).
  - `tests/test_inspect.sh:88-89` `check "13 agents"` and line 97 phrase
    `Show a table of the 13 agents` on `skills/st-init/SKILL.md:26`.
  - `tests/test_inspect.sh:113` "README skills" and `:118` "README agents".
  - `tests/test_model_files.sh` "st-model names every agent" (`skills/st-model/SKILL.md:10-11`).
  - `tests/test_session_hooks.sh:40-43` (the `[st-triage]` report tag).
- Alternatives considered: none.

## R9. Not changed

- Decision: no change to `hooks/st-session-start.sh`, `hooks/st-models.py`,
  `templates/models.json`, or the version.
- Rationale: the spec's Assumptions keep the skill out of the background rule. `hooks/st-models.py`
  reads `agents/*.md`. `tests/test_model_files.sh:11,14` pins the template, and the spec keeps the
  agent on its Opus default. Version bumps are separate commits (004 research R13).
- Alternatives considered: none.
