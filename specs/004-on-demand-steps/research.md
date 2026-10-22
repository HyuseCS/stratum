# Research: Run Stratum Steps On Demand

Facts checked on 2026-10-14 against Claude Code 2.1.296 (`/opt/claude-code/bin/claude`) and the
repo at `1e73f80`.

## R1. Which agents lack a command

- Decision: add `skills/st-review/`, `skills/st-test/`, `skills/st-debug/`, `skills/st-git/`.
- Rationale: `agents/` holds 10 files. 6 have a skill of the same name (`st-build`, `st-close`,
  `st-fast`, `st-inspect`, `st-plan`, `st-quick`). The other 4 have none. After US2 the 3 new
  agents (`st-impeccable`, `st-ponytail-audit`, `st-ponytail-debt`) match skills that exist today.
  So SC-001 is 0 after the build.
- Alternatives considered: none. D1 names these 4.

## R2. Skill and agent with the same name

- Decision: a skill folder and an agent file share the name, as `st-plan` and `st-quick` do.
- Rationale: `/stratum:st-plan` resolves to the skill, and `stratum:st-plan` is the agent's
  `subagent_type`. Both work today with no clash.
- Alternatives considered: `disable-model-invocation: true` on the new skills. Rejected. No thin
  skill uses it, and when the model tries the Skill tool the client answers "do not replicate this
  skill's workflow by other means" (binary text). That could stop a lane from starting the
  `stratum:st-git` agent.

## R3. Agents run in the background by default

- Decision: the new skills set no `run_in_background` flag. They act when the agent reports.
- Rationale: the Agent tool's `run_in_background` text in 2.1.296: "Agents run in the background
  by default; you will be notified when one completes." The four commands act on the report, so
  they wait for it. The background agents run in the background with no flag.
- Alternatives considered: set `run_in_background: false` on the four commands (adds a flag no
  other skill sets).

## R4. The fork

- Decision: mid-session `st-handoff` starts the Agent tool with `subagent_type: "fork"`. If the
  fork cannot start, it writes the file in the main session and says so.
- Rationale: binary text: a fork "inherits your full conversation context, runs in the background,
  and keeps its tool output out of your context". Its definition: `tools: ["*"]`,
  `model: "inherit"`, `permissionMode: "bubble"`. `model` and `effort` are ignored for a fork. The
  fork is gated: `CLAUDE_CODE_FORK_SUBAGENT` false or a disabled gate turns it off, hence the
  fallback. The fork inherits the skill text that says "start a fork", so its prompt says it is
  the fork and writes the file itself.
- Alternatives considered: `context: fork` in the skill frontmatter (runs a subagent that does
  not get the conversation, so it cannot name the decisions, spec US3 scenario 1).

## R5. `hooks/st-models.py` needs no change

- Decision: no hook change. `templates/models.json` gets no entry for the new agents.
- Rationale: `AGENTS` is read from `agents/*.md` (`hooks/st-models.py:8-9`). The 3 new names become
  valid keys in `.stratum/models.json` with no code change, so `/stratum:st-model` can change them
  (spec assumption). `st-inspect` and `st-review` have no template entry either. A fork has
  `subagent_type: "fork"`, not `stratum:...`, so the hook ignores it (`hooks/st-models.py:47-48`).
- Alternatives considered: template entries (change `tests/test_model_files.sh:12` and every new
  project's cost with no request).

## R6. `hooks/st-phase.py` needs no change

- Decision: no change.
- Rationale: `NAME` matches only `define|plan|inspect|build|close` (`hooks/st-phase.py:10`).
  `/stratum:st-review` and the other new commands do not change `phase`.
- Later: change 004 (#24, commit b12b8da) added `fast|quick|full` to `NAME` (`hooks/st-phase.py:11`).
  The rationale above still holds for the new commands.

## R7. Read-only modes of the three skills

- Decision: `st-impeccable` runs only `audit` in the background. `st-ponytail-audit` and
  `st-ponytail-debt` run as they are, and never write the ledger file.
- Rationale:
  - `skills/st-impeccable/reference/audit.md:1`: "Don't fix issues; document them". Read-only.
  - `skills/st-impeccable/reference/critique.md:3,187`: critique persists a snapshot to
    `.impeccable/critique/` (breaks FR-007), must end with a question to the user
    (`critique.md:15`, breaks FR-008's no-questions rule), and must start two sub-agents
    (`critique.md:6`). Not read-only.
  - All other impeccable commands edit code.
  - `skills/st-ponytail-audit/SKILL.md:44`: "Lists findings, applies nothing."
  - `skills/st-ponytail-debt/SKILL.md:42`: "Reads and reports only", but it writes a ledger file
    when asked. The agent never does.
- Alternatives considered: critique with persistence and the question skipped. That is a degraded
  critique by its own rules (`critique.md:9`).

## R8. Tools of the background agents

- Decision: `st-ponytail-audit` and `st-ponytail-debt`: `tools: Read, Grep, Glob, Skill`.
  `st-impeccable`: `tools: Read, Grep, Glob, Bash, Skill`.
- Rationale: no agent gets Edit or Write. The ponytail skills need only a tree search, which the
  Grep tool does (`st-ponytail-debt/SKILL.md:20` is a `grep -rnE`; the same pattern works in Grep).
  Impeccable audit runs `impeccable context` and `impeccable detect` (`SKILL.md` Setup step 1,
  `reference/audit.md:60`), so it needs Bash. `Skill` loads the skill, as `agents/st-build.md:4,40`
  does for `st-ui-ux`.
- Test of the impeccable commands (scratch git repo with one `index.html`, 2026-10-14):
  `impeccable context` exit 0, `impeccable detect --json index.html` printed `[]`, and
  `git status --porcelain --ignored` printed nothing. Neither writes into the project.
- The launcher downloads the engine from `github.com/pbakaus/impeccable/releases` on first use into
  `~/.impeccable/bin/<version>/`, with a sha256 check (`scripts/impeccable` lines 75-200). This
  machine has `~/.impeccable/bin`. That write is outside the working tree.
- Alternatives considered: Bash for all three (no need, and it widens what can write).

## R9. Where the background rule lives

- Decision: one more sentence in the `Stratum rule` that `hooks/st-session-start.sh:16` prints.
- Rationale: FR-008 must hold in any session. The session-start line is the only always-on
  Stratum rule. `skills/st/SKILL.md` loads only when `/stratum:st` runs. The agent descriptions
  ("Use when the user asks to run ... in the background") are in every session's agent list, so
  the start works either way. The refusal and the before/after check need the rule.
- Alternatives considered: `skills/st/SKILL.md` `## Always` (not loaded in a plain session).

## R10. The check after each command (FR-004)

- Decision, from what the orchestrator does after each agent in a lane:
  - `st-review`: check each finding against the source (`skills/st-build/SKILL.md:46`,
    `skills/st/SKILL.md` Always).
  - `st-test`: re-run the test and confirm it fails for the right reason
    (`skills/st-build/SKILL.md:21`). Not `st-verify.sh`: it reports a red test as `FAIL`
    (`scripts/st-verify.sh:4-9`).
  - `st-debug`: `bash <plugin root>/scripts/st-verify.sh '<test command>' <files>`
    (`skills/st-build/SKILL.md:25-26`). It re-runs the test and checks for added comment lines,
    as scenario 3 asks.
  - `st-git`: `git log -1 --name-only --format=` against the given list (scenario 5).
- `agents/st-git.md:18` says to stop when no file list is given. The new skill gets the list from
  the user before the agent starts, so the agent file does not change.

## R11. Missing inputs

- Decision: feature from `feature_directory` in `.stratum/state.json`, range `main..HEAD`.
  `st-review`, `st-test` and `st-debug` need a feature. `st-git` does not. A missing task ID
  (`st-test`, `st-debug`), a missing `main` branch, or a missing test command (`st-debug`) gives one
  line and a stop.
- Rationale: D1 fills only the feature and the range. Picking a task from `tasks.md` would guess
  scope.

## R12. Tests that pin the agent list

Adding 3 agents turns these red until the docs follow (they are the guards for the US2 build):

- `tests/test_inspect.sh:89` "10 agents", and its phrase `Show a table of the 10 agents`
  (`tests/test_inspect.sh:97`, `skills/st-init/SKILL.md:26`).
- `tests/test_inspect.sh:110-118` "README agents": one `` | `<agent>` | <Model> | `` row per agent,
  both ways.
- `tests/test_model_hook.py:202-203` `test_module_constants`; `test_st_model_skill_matches_hook`
  and `test_docs_cover_feature` (each agent in backticks in `skills/st-model/SKILL.md` and
  `README.md`).
- `tests/test_model_files.sh:42` "st-model names every agent".
- `tests/test_session_hooks.sh:43` loops every agent for its report tag. The new agents pass it
  when they carry the line.
- `README.md:172` holds the pinned phrase "`st-inspect` and `st-review` have no entry and keep
  the plugin default". The new agents get their own sentence. That one stays.

Adding the 4 skills turns `tests/test_inspect.sh` "README skills" red until `README.md` lists
them. Adding `tests/test_on_demand.sh` turns "README tests" red until `README.md` lists it.

## R13. Version

- Decision: no version bump in this plan.
- Rationale: the spec does not ask for one. Bumps are separate commits (`9d9d85f`), and the 5
  commits since 0.1.27 did not bump.
