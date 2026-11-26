# Implementation Plan: worker monitors

**Branch**: `stratum-51` | **Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/022-worker-monitors/spec.md`, grill decisions D8 to D28 in [decisions.md](decisions.md)

## Summary

The main orchestrator starts one new background subagent, `stratum:st-monitor`, for each pane worker. The monitor runs `st-worker.sh wait` in a loop and settles only the four routine events, with the lists of `skills/st-worker/SKILL.md` step 6. It ends its run with `finished`, `stopped`, `gone` or `needs you`, and the main session continues it with SendMessage. Small changes to `scripts/st-worker.sh` tie every answer to its screen and write each answer to a record file. A rule in `hooks/st-approve.py` lets the monitor run only its own commands. A `stale` command and the Monitor tool let the main session find a monitor that gives no sign of life. Results, reviews, follow-ups, merges, ticks and closes stay with the main orchestrator.

The first build task is a live probe of `approve` from a subagent. If it fails, the feature stops for a new decision (D26, D28).

## Technical Context

**Language/Version**: Bash 5 (`scripts/st-worker.sh`), Python 3 (`hooks/st-approve.py`), Markdown agent and skill files, LikeC4 1.60.0 model files.

**Primary Dependencies**: herdr CLI, Claude Code 2.1.331 (Agent tool in the background, SendMessage, TaskStop, Monitor, the `advisor` server tool), `codex` CLI through `scripts/st-advisor.sh`, jq.

**Storage**: Files. Per monitor: `<scratchpad>/monitor-<id>-<key>/record.tsv` in the main session's scratchpad. See [data-model.md](data-model.md).

**Testing**: `bash tests/test_st_worker.sh` (herdr stub), `python3 tests/test_approve_hook.py`, `bash tests/test_worker_rules.sh` and the other phrase tests, `bash tests/test_harness_model.sh`. Live runs in [quickstart.md](quickstart.md).

**Target Platform**: Linux and macOS, in herdr, workers on this machine and on saved machines (`--machine`).

**Project Type**: Claude Code plugin (harness).

**Performance Goals**: Two monitors act at the same time (SC-002). The time from a dialog to its answer is measured in T001.

**Constraints**: The lane steps and gates, the worker's brief and `/goal` do not change (FR-033). The approve lock and the locks inside a worker session do not change (FR-032). A Bash call stays under the 600 s cap (`wait` is bound at 540 s).

**Scale/Scope**: One monitor per pane worker. No limit on the count of rounds.

## Constitution Check

This repo has no `.stratum/constitution.md` and no `apps/*/ORDINANCE.md`. Gates: none. The design keeps the rules that the repo's own skills set: no herdr call outside `st-worker.sh`, file changes only with the Write or Edit tool, push only on the user's word, and autonomous build mode only from the user's `/stratum:st-autonomous on`.

Re-check after design: no rule is broken. Two choices touch existing rules and are named here:

- The never check in `answer` (research.md R5, guard 2) also applies to the main session's fallback path. It refuses only what `skills/st-worker/SKILL.md:28` already says never to send.
- `tests/test_on_demand.sh:50` (every agent has a skill of its own name) gets one exception for `st-monitor` (research.md R9).

## Project Structure

### Documentation (this feature)

```text
specs/022-worker-monitors/
├── spec.md
├── decisions.md
├── research/              # st-research files
├── research.md
├── plan.md
├── data-model.md
├── contracts/
│   ├── st-worker-cli.md
│   ├── monitor-guard.md
│   ├── monitor-agent.md
│   └── st-worker-skill.md
├── quickstart.md
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
agents/st-monitor.md                 # new
scripts/st-worker.sh                 # screen line for questions, --record, never check, stale
hooks/st-approve.py                  # monitor guard, --never
skills/st-worker/SKILL.md            # step 6, end of run, step 8
README.md, DESIGN.md                 # agent tables and model lists
skills/st-model/SKILL.md, skills/st-init/SKILL.md
docs/harness/model/agents.c4, docs/harness/model/skills-tools.c4
docs/harness/atlas/data.mjs, atlas.html, SYSTEM.md, docs/harness/README.md
tests/test_st_worker.sh, tests/test_approve_hook.py, tests/test_worker_rules.sh
tests/test_inspect.sh, tests/test_model_hook.py, tests/test_on_demand.sh
```

**Structure Decision**: no new folder. One new agent file. The rest are edits to files that exist.

## Design

### D-1. The monitor agent (FR-001 to FR-006, FR-010 to FR-019, FR-024 to FR-029)

`agents/st-monitor.md` holds the text of [contracts/monitor-agent.md](contracts/monitor-agent.md). `model: opus`, `tools: Read, Bash, Write`. It uses the lists of `skills/st-worker/SKILL.md` step 6 by reference, so the lists stay in one place (FR-006). It runs in the background, so each monitor acts for its own worker at the same time (US1-6). A headless worker and a Codex tab get none (FR-002). The model is set the same way as for the other agents (FR-024).

### D-2. Screen tie and record (FR-005, FR-007, FR-008, FR-014)

[contracts/st-worker-cli.md](contracts/st-worker-cli.md). `wait` and `watch` print a `screen` hash for a work question. `answer --screen` checks it before it sends. `answer` and `resend` take `--record`. The record is in the main session's scratchpad, written by the script after each send, so it outlives the monitor and changes no project file. For a worker on a saved machine every call passes `--machine` and the record stays on this machine.

### D-3. Guards (FR-010 to FR-016, FR-035, SC-003)

Three guards that a test can turn red (research.md R5):

1. The monitor guard in `hooks/st-approve.py` ([contracts/monitor-guard.md](contracts/monitor-guard.md)).
2. The never check in `answer` ([contracts/st-worker-cli.md](contracts/st-worker-cli.md)).
3. The `tools:` line of the agent.

A lane gate question has no script guard: the monitor must relay the user's own answer to it (US2-5). Its guard is the agent rule. Finding F1 of the report names this.

Own worker only (FR-035, D36, research.md R11): the lock is who makes the call. Every allowed command names a monitor folder whose name holds the command's worker id (`pass` gets `--record` for this). On the first monitor call for a folder, the hook makes `<folder>/owner` with an exclusive create and writes the hook input's `agent_id` into it; after that, a call on that folder is allowed only with the same `agent_id`. A call with no `agent_id` is denied. A continue with SendMessage keeps the same monitor; a new monitor after a stopped one gets a new folder. The folder name keeps a 16-character `mktemp` key, made by the main session before the first start and given only in that monitor's brief, so the seconds before the first call are safe from a guess. When the main session stops using a folder, for any reason, it writes `<old folder>/revoked`, and the hook denies every monitor call on it, so a worker has one usable folder at a time (FR-003 by code). A monitor command with `--record`, `--beat`, `--screen`, `--machine` or `--request` given twice is denied. The one limit: Read is any path, so a tricked monitor can find a new folder's full name in the main session's transcript and race the right monitor's first call; then the right monitor's first call is denied, the main session revokes that folder, which ends the takeover, starts a monitor with a new folder and tells the user (research.md R11). T001 proves the fact this rests on before anything is built: the hook input of a subagent's call holds an `agent_id`, recorded against the id the Agent tool gives the main session, and it stays the same after a SendMessage continue; if not, the feature stops before T002. Quickstart section 3 step 5 (T013) checks the same on the shipped monitor, and a call that names another monitor's full folder.

### D-4. Sign of life and restarts (FR-003, FR-020, FR-021, FR-022)

One beat file per monitor, `<scratchpad>/monitor-<id>-<key>/beat`, is the sign of life. The main session writes it just before each start or continue, and `wait --beat <file>` refreshes it. `st-worker.sh stale` names a beat file that is older than the bound or missing. The main session runs it with the Monitor tool, and on a `stale` line stops the monitor with `TaskStop`, confirms the stop, and continues the same monitor with SendMessage (research.md R6). The bound is 550 s plus two times the gap measured in T001, rounded up to a whole minute. When the Agent call for a monitor fails, the main session watches that worker with `wait` as today and says so in one line.

### D-5. Big decisions (FR-027 to FR-030)

The hard part always goes up. The soft part (spec, scope, approach) needs, in order: autonomous build mode on (the monitor reads `.stratum/autonomous/<session id>` of the main checkout before each one), the effect inside the task's `Owns:` files, a clear yes from `advisor`, and a Codex yes. Only `APPROVED` counts as a Codex yes (research.md R8). The Codex call is `HERDR_ENV=0 bash <plugin root>/scripts/st-advisor.sh round decisions <monitor folder> 1 <views file>` (D30). Just before its first Codex call, the monitor writes the placeholder `spec.md` in its own folder from the task text of its brief (contracts/monitor-agent.md, Big decisions step 4). In P1 the agent has no Big decisions section: every spec, scope or approach question ends with `needs you`. US3 adds the section. Before the merge the main session shows each big decision, and a "no" sends a follow-up round that undoes it (FR-030, [contracts/st-worker-skill.md](contracts/st-worker-skill.md) C5).

### D-6. Skill text (FR-009, FR-023, FR-031)

Only `skills/st-worker/SKILL.md` changes, as [contracts/st-worker-skill.md](contracts/st-worker-skill.md) says (C1 to C5). Steps 7 to 11 stay, except the two added lines of C4 and C5. The main session still runs the worker's test before and after the merge (FR-023).

### D-7. Agent lists and the harness model (FR-034)

research.md R9: every pin of the agent list and count, the README and DESIGN tables, the harness model element, one atlas structure, the atlas rebuild and the README export.

## Security notes

- **Access rules.** The monitor approves through the approve channel of the main session (`scripts/st-worker.sh:757`): the session id lock and the `.stratum/autonomous/<session id>` check do not change (FR-032). The monitor guard in `hooks/st-approve.py` is a new rule for one agent type. It cannot widen what any agent may do: it runs after `lock2`, only denies (its one write is the `owner` file of a monitor folder), and prints nothing for a call it allows, so the user's permission rules still judge that call. It fails closed for `stratum:st-monitor`, but it fails open when the hook input does not carry that `agent_type` (known from the docs only), so quickstart section 3 step 3 must pass live before the release. It is a text guard on the same OS user, like `lock2` (`hooks/st-approve.py:104`): a guard against mistakes and simple prompt injection, not a wall.
- **Prompt injection.** Pane text, request text, result text and advisor answers are data (FR-017). The guard limits what an injected instruction can make a monitor run to the five worker commands and the Codex call, and every path it can write (`--record`, `--beat`, Write) to `record.tsv`, `beat`, `spec.md` and `views-<n>.md` in the monitor folder that the main session prepared (contracts/monitor-guard.md), and to the folder that its own `agent_id` owns (D36). Claude Code sets `agent_id`, so an injected instruction that names another monitor's folder is denied; the one window is the seconds before that monitor's first call (research.md R11). The never check in `answer` refuses a yes to a never-list dialog whatever the monitor decides.
- **External service.** Codex gets the decision text of a big decision only, through `scripts/st-advisor.sh` in the read-only sandbox (headless). The prompt head tells it never to open secrets (`scripts/st-advisor.sh:217-221`). The monitor must not paste secrets or `.env` values into the decision text.
- **Personal data and secrets.** The record file holds up to 600 characters of each answered screen. A dialog can show a command with a secret in it. The file stays in the main session's scratchpad on this machine, under the user's own account, and is shown only to the user at the end of the run. No record goes to a remote machine or to Codex.
- **Data model and contracts.** The record line format and the report format are new contracts inside the harness. No project data model changes.

## Shortcuts

- Owner check by first call (D36), with an alternative not taken: the main session would write each folder's `owner` with the agent id that the Agent tool gives it, and the monitor's first command would wait until that file exists. It would remove the `mktemp` key in the folder name and the takeover branch of C1 (the deny of a new monitor's first call, `revoked` on takeover, the one-line message). Its cost: the start of each monitor would wait on the main session, which is the part that gets overloaded, and a slow main session would make first commands fail or wait. Trigger to switch: T001 shows that the id the main session gets equals the hook's `agent_id`, and the takeover branch fires in real runs or proves hard to keep right.
- Path rules in the monitor guard (contracts/monitor-guard.md, "Monitor folder"): the guard judges paths that the monitor passes, by rules. Limit: this rule got three findings in a row in Inspect (too wide, too strict for macOS, path form). Upgrade trigger: one more hole in the path rule, in review or in a live run. Upgrade: the monitor passes no path; the main session records one monitor base folder, and the script and the hook compute the exact allowed files from it and compare for an exact match.
- Placeholder `spec.md` in the monitor folder (research.md R8, contracts/monitor-agent.md Big decisions step 4). `scripts/st-advisor.sh` needs a readable `spec.md` in every folder it is given (`:73-76`), and no point is written for a decision that is not made yet, so the monitor uses `round decisions` and writes the task text of its brief as `spec.md` in its own folder just before its first Codex call. Limit: the `round` prompt speaks of "a talk with another advisor" about views, not of one decision a monitor is about to make, and `spec.md` is not a spec. Upgrade trigger: a new point of its own in `scripts/st-advisor.sh`, if the round wording gives wrong verdicts in real runs (a Codex verdict that does not answer the decision asked).

## Decisions

Codes from decisions.md:

- D29: T001 gets its approval request from a temporary `ask` rule that the user adds and removes by hand.
- D30: `round decisions` headless, only `APPROVED` is a yes, placeholder `spec.md`, no new point and no usage line change.
- D31: one exception in `tests/test_on_demand.sh:50` for `st-monitor`, no `skills/st-monitor/SKILL.md` (research.md R9).
- D32: the guard for SC-003 is the monitor rule in `hooks/st-approve.py` plus the never check in `answer` (research.md R5). The never check also changes the main session's own `answer`.
- D33: the record files of monitors cover one session; they are shown before the handoff when workers still run, and a new session starts new ones and says in one line that the earlier records are not shown again.
- D34: SC-003 leaves out the gate part of FR-012 and names its check: the agent rule and quickstart section 3 step 2; the outward effect of a wrong PR gate answer is still stopped by the push dialog and the never check.
- D35: the three safety fixes of the first Inspect run: the monitor rule runs after `lock2` and only adds denies, the never check fails closed, and a monitor writes only `record.tsv`, `beat`, `spec.md` and `views-<n>.md` in a prepared `monitor-<id>` folder.
- D36: a monitor is locked to its own worker by code, by who makes the call (the user's pick for F24, option O51). The hook ties each monitor folder to the `agent_id` of its first monitor call with an `owner` file and denies a call with another or no `agent_id`; every command names its folder (`pass` gets `--record`). The `mktemp` key in the folder name stays only to keep the seconds before the first call safe. A new monitor after a stopped one gets a new folder, so no `owner` is ever removed. The Read allow list of the secret-name form is gone. A folder the main session stops using gets a `revoked` file, and the hook denies every call on it. A flag given twice is denied. Limit: Read is any path, so a tricked monitor can learn a new folder's name from the main session's transcript and own it before the right monitor's first call; the main session sees the deny, revokes that folder and starts a monitor with a new one (research.md R11).

## Safety checklist items this plan settles

- CHK002: the main session of the new session starts a monitor for each worker that step 12 finds (C1).
- CHK003: the main session keeps one agent id per worker and checks it before it starts a monitor; a stopped one is confirmed with a second `TaskStop` (D-4).
- CHK006: the hash covers the question block for a typed answer and an option answer alike (contracts/st-worker-cli.md).
- CHK007: the record is in the scratchpad, written by the script (research.md R4).
- CHK009: the gate list adds the Fast-lane change plan and the Close gate (contracts/monitor-agent.md).
- CHK010: a cut-off dialog gets its No; a rerun request goes only with a screen hash, else `needs you`.
- CHK011: advisor answers and Codex findings are data too.
- CHK012: the approve lock and `lock2` stay; the monitor guard is added for one agent type.
- CHK013: data-model.md maps each `wait` result to one end state.
- CHK014: while a `needs you` waits, the worker waits at its dialog; an approval request waits at most 300 s, then shows in the worker's pane.
- CHK015: no sign of life is a beat file older than the bound; T001 measures the gap.
- CHK016: an answer that was not sent is not in the record; the next monitor reads the screen again.
- CHK017: the fallback is a named, visible state with its own one-line message; SC-001 counts only workers that have a monitor.
- CHK020: `advisor`: a clear yes with no condition; Codex: `APPROVED` only.
- CHK021: the effect must stay inside the task's `Owns:` paths.
- CHK023: weaker is `sonnet` and `haiku`; `opus` and `fable` are not.
- CHK024: a strong monitor with no advisor set still needs `advisor` for a big decision, so a big decision goes up; a small question needs no advisor on a strong model.
- CHK025: T001 is the probe, with its stop rule.
- CHK026: T001 measures the dialog-to-answer time and the gap for the bound.
- CHK028: SC-001 is counted from the main session's transcript (quickstart section 2).
- CHK029: each negative control is named in tasks.md.

Not settled here: CHK001, CHK004, CHK005, CHK008, CHK018, CHK019, CHK022, CHK027 are requirement wording points for the spec reviewer.

## Complexity Tracking

No constitution, no violations.

## Validate

Date: 2026-11-26 (run 6). Verdict: PASS

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | F10 |
| 2. Test coverage per requirement | PASS | none |
| 3. Breaking changes | PASS | none |
| 4. Security and privacy | PASS | F35 |

Run 1 findings: F1, F2, F3, F5 to F9, F11 to F16, F18, F20, F21 and F22 are closed. F4 is closed by D34 (O1), which the user must still OK at the build gate. F17 is open (low, accepted), F19 is closed by the "not sure" rule of contracts/monitor-agent.md:59, and F10 has not changed.

Run 2 findings: F23 is closed (contracts/monitor-guard.md:20, with the T006 allow row for a symlinked parent and its negative control). F25 is closed (contracts/monitor-guard.md:11, with the T006 fail-closed row, which also expects no output for `stratum:st-build`, and its negative control). F26 is closed (quickstart.md:59), F27 is closed (quickstart.md:57), and F28 is closed (plan.md:136-138).

Run 3 findings: F24 is replaced by D36 (O51) and FR-035. The key in the folder name works only if no channel shows a monitor another folder's name, and F30 and F31 are two such channels. F29 is closed: contracts/monitor-guard.md:15 adds the path form rule, and T006 has the relative and `..` rows with the negative controls "drop the path form check" and "drop the symlink check".

F10. tasks.md:40 (low) Every tool is present: bash 5.3.20, Python 3.14.10, jq 1.8.2, Claude Code 2.1.331, herdr 0.9.5, codex-cli 0.172.0, node 24.14.1, and `~/.claude/skills/system-atlas/assets/` for the atlas build line. `npx -y likec4@1.60.0` was not run, because it needs the network. -> none.

Run 4 findings: F30 is closed. The Read allow list is gone (contracts/monitor-guard.md:46), and the lock no longer rests on a secret name: it rests on the `owner` file and the hook input's `agent_id` (:26-32). F31 is closed. A leaked folder name now matters only in the window before a new monitor's first call, which is the stated limit.

Run 5 findings:

- F32 is closed. contracts/monitor-guard.md:32 adds the revoked rule. C1 says when the main session writes `revoked` (contracts/st-worker-skill.md:19 for any stop of a folder, and :23 for the taken folder), and research.md R11 states the full limit. T006 has the revoked rows with the negative control "drop the revoked check", and T007 has the skill rows.
- F33 is closed. contracts/monitor-guard.md:40 adds the given-twice rule. T006 has the two rows with the negative control "check only the first occurrence". The forms that rule does not catch never run: `--record=<path>`, a short form and `--` all reach `*) usage` (exit 2) at `scripts/st-worker.sh:51`, and a flag after `--keys` or `--text` is a value, which `scripts/st-worker.sh:64` refuses because it starts with `-`.
- F34 is closed. contracts/monitor-guard.md:29 and :31 pin the exact-bytes compare and deny an `agent_id` with a control character. T006 has the "leaves no `owner`" rows and the newline and control-character rows, with the negative controls "make owner first" and "strip the agent id or allow control characters".

F35. contracts/monitor-guard.md:32 (low, FR-035) "A folder holding a file `revoked`" can be built with `os.path.isfile`, which is false for a folder or a broken symlink named `revoked`. Only the main session writes `revoked`, and it writes a regular file with the Write tool, so no actor in this design can make the other kinds. -> st-plan, optional: deny when any entry named `revoked` exists (`os.path.lexists`), and add one row with `revoked` as a folder.
