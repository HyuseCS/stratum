# Implementation Plan: Mods That Talk To and Start Other Sessions

**Branch**: `003-session-mods` | **Date**: 2026-10-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-session-mods/spec.md`, GitHub issue
HyuseCS/stratum #9, grilling decisions D6 to D13 in `decisions.md`.

## Summary

A spike. It answers issue questions Q1 to Q5 and gives a yes or no for Stratum by the D12 rule.
Three tests run on this machine with Claude Code 2.1.296:

- Test 3 (US1, run first, no human): the model starts a local session through Bash
  (`claude -p`, then `claude --bg`), reads the exact reply text, and stops it.
- Test 1 (US2, manual): a mod `spike-send` sends one message with `$.session.send` to a second
  session the user opened, and a `session.receive` hook puts the reply in a pane.
- Test 2 (US3, manual): a mod `spike-start` starts `claude -p` with `$.process.spawn` and shows
  running, done or failed in a pane.

The docs already settle much of Q1 (research R1 to R4): a mod can send (`$.session.send`), can
receive (`session.receive`), and can start host processes (`$.process.run`, `$.process.spawn`).
The tests prove what the docs claim. One script, `spikes/check.sh`, is written first and fails
until the report is complete, the verdict matches the D12 parts, no marked process is alive and
`git status` shows only allowed paths. `spikes/cleanup.sh` runs before and after every test.

## Technical Context

**Language/Version**: TypeScript/TSX for mods (the engine's own module runtime, no Node), Bash 5.3 for `check.sh` and `cleanup.sh`, Markdown for the report

**Primary Dependencies**: Claude Code 2.1.296 (`claude --version`): `--plugin-dir`, `-p`, `--bg`, `agents --json`, `logs`, `stop`, `rm`, `-w`, hidden `--max-turns` (accepted, research R5), `plugin validate`, `plugin test`. jq 1.8.2, GNU coreutils `timeout` 9.12, procps `pgrep`/`pkill`, git. No new package.

**Storage**: Files only. `research.md` is the report. Mod state is `$.state` (session only).

**Testing**: `bash specs/003-session-mods/spikes/check.sh` (report, verdict, processes, git paths). `claude plugin test <mod dir>` for each mod (`*.test.tsx`, kit `claude-code/testing`). `claude plugin validate <mod dir>`.

**Target Platform**: Linux, this machine. Local sessions only (D8).

**Project Type**: Spike inside a Claude Code plugin repo. Throwaway test mods, not shipped.

**Performance Goals**: N/A

**Constraints**: Started sessions use `--model haiku`, one short prompt, `--max-turns 3` (or no tools where the start method refuses a turn limit, D14), and a stop within 300 seconds (FR-012). `--tools ""` on every started session, so no tool and no permission prompt can stop it. No `--dangerously-skip-permissions`, no `--bare` (research R6). At most 3 approaches per test (D13). No change outside `specs/003-session-mods/` and `.stratum/state.json`.

**Scale/Scope**: 2 mods (4 to 5 files each), 2 scripts, 1 report. 3 tests. At most about 8 Haiku sessions in total.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md`. The gates come from the orchestrator's rules, the
spec and decisions D6 to D13, as in feature 002.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that can fail, before its build task | Pass. `check.sh` (T001) is red on the empty outline (T002). Each mod has a `*.test.tsx` that is red before `register.tsx` exists (T011, T017). FR map in tasks.md |
| G2. Shipped plugin unchanged (FR-001, SC-005) | Pass. All new files are under `specs/003-session-mods/`. `check.sh` R6 fails on any other changed path |
| G3. Cost limits (FR-012, AS1) | Pass. One fixed argv form for every started session (section Started sessions). `check.sh` R4 checks every row of the Started sessions table |
| G4. Cleanup (FR-006, AS2) | Pass. `cleanup.sh` before and after each test. `check.sh` R5 fails on any live marked process, marked background session, worktree or branch |
| G5. Privacy (FR-013, AS3) | Pass. Report holds only test text. `check.sh` R8 fails on a secret-like value or an unmarked session row |
| G6. At most 3 approaches per test (D13, FR-007) | Pass. Approaches are fixed below. `check.sh` R1 fails on a fourth |
| G7. Minimal, no speculative work | Pass. A third approach runs only if the first two fail. No stop command, no evidence folder, no contracts/ |

Post-design re-check: all gates pass. No violations, so Complexity Tracking stays empty.

## Approaches

**A different approach (CHK007)** is a different mechanism for the step: a different entry point
(a `$` call, a tool, or a CLI command) or a different kind of session (`-p` headless, `--bg`
background, `-w` worktree). A change of arguments, address form, prompt text or timing, or a fix
of a bug in the spike's own code, is a retry of the same approach. Retries are not counted. An
approach ends when the engine or the CLI returns the same error after the spike's own bugs are
fixed. That error text is the approach's limit.

The next approach runs only when the one before it fails, with one exception: C2 always runs,
because only a session that stays alive can show in ListAgents and receive a SendMessage
(FR-016, D15).

| Test | ID | Mechanism | Pass shape |
|------|----|-----------|------------|
| 1 | A1 | Mod command `/spike-send <to>` calls `$.session.send({ to, text })`. `<to>` is the name `spike-peer`, or `sid:<uuid>` for `{ sessionId }` (a retry, same approach) | full pass |
| 1 | A2 | Mod calls `$.tool.call({ tool: 'SendMessage', to, message })` | full pass |
| 1 | A3 | The model in the first session calls SendMessage. The mod only shows the reply | partial pass |
| 2 | B1 | Mod command `/spike-start` runs `$.process.spawn` on the started-session argv in a loop that outlives the hook (reference.md, `$.process.spawn` example 2). Status from the stream and the exit | pass |
| 2 | B2 | Mod runs `$.process.run(['claude', '--bg', ...])`, polls `claude agents --json` with `$.clock.every`, reads `claude logs`, ends with `claude stop` and `claude rm` | pass |
| 2 | B3 | As B1 with `-w spk003-t2c` (worktree session), worktree removed by `cleanup.sh` | pass |
| 3 | C1 | Bash: started-session argv with `--output-format json`. Reply is the JSON `result` field (field name confirmed on first run) | pass |
| 3 | C2 | Bash: `claude --bg` form, then `claude agents --json`, ListAgents, SendMessage, `claude logs`, `claude stop`, `claude rm` | pass |
| 3 | C3 | Bash: started-session argv with `-w spk003-t3c` | pass |

Reply in test 1: the mod hooks `session.receive` with no matcher, keeps deliveries whose
`e.origin.kind` is `peer` or `peer-send-message` and whose text holds `spk003`, writes the text
to `$.state`, and returns `next(e)`. The pane reads that state. The peer delivery kinds are in the
types file (research R2).

`$.agent.spawn` starts a subagent inside the same session. It is not a session, so it is not an
approach for test 2 or 3 (research R4).

## Started sessions

Marker (CHK002): every process, background session, worktree and branch the spike starts carries
`spk003` in its argv or name. The user's own sessions never do. The test mods are named
`spike-send` and `spike-start`, the user's first session is named `spike-main`, and the second
session the user opens by hand for test 1 is named `spike-peer`, so none of them match. The peer
carries no marker on purpose: `cleanup.sh` kills marked processes, and it runs at the start of
every retry, so a marked peer would be killed mid-test. The user closes the peer at the end of
test 1 (quickstart.md section 5). It is not a session the test started (FR-006), and it runs no
work of its own. Scripts search with the pattern `spk00[3]` so the pattern text does not match itself
in a shell's argv. They call `command pgrep` and `command pkill`, because the Bash tool's shell
wraps `pkill`.

Argv for every headless started session (FR-012), with `<id>` such as `t3a`:

```text
timeout 300 claude -p --model haiku --max-turns 3 --tools "" --strict-mcp-config
  --no-session-persistence -n spk003-<id>
  "spk003-<id>: reply with exactly the text spk003-<id>-ok and nothing else."
```

The `--bg` form is the same without `timeout`, `-p` and `--no-session-persistence`, plus `--bg`.
`timeout` cannot bound a command that returns at once, so the caller runs `claude stop` before 300
seconds pass and records both times. If a start method refuses `--max-turns`, the run records the
error, drops the flag and keeps `--tools ""` as the limit (FR-012, D14). The Turn limit column of
the Started sessions table says which limit was used. Dropping the flag is a retry, not a new
approach.

T006 writes the argv that worked into the block above. That plan.md edit gets its own commit before
T017 starts (D16).

"Result back" (FR-005, CHK009) holds when the reply text equals `spk003-<id>-ok` after trimming
white space, as read in the first session (Bash output, `claude logs` output, or the pane). The
Evidence field quotes the raw reply, and `check.sh` R1 checks it.

"Human step" (D17): any human action after the start call and before the result, an answered
permission prompt included. For test 2, the user's `/spike-start` is the trigger and does not
count. Tests 2 and 3 record it in a `- Human step:` field, and `pass` needs `none`.

"Stopped" (CHK001), by kind:

| Kind | Stopped when |
|------|--------------|
| `-p` (C1, B1) | `pgrep -f` finds no marked process |
| `--bg` (C2, B2) | as above, and `claude agents --json` lists no session whose name holds the marker, and `claude rm <id>` exited 0 |
| `-w` (B3, C3) | as above, and `git worktree list --porcelain` and `git branch --list` show no marked path or branch |
| Hand-opened peer `spike-peer` (test 1, not marked) | the user typed `/exit` in it, and `claude agents --json` lists no `spike-peer` |

Cleanup after a stopped test (CHK004, FR-006): `spikes/cleanup.sh` runs before each test and after
it, also after a crash or a stop by the user. It kills marked processes, stops and removes marked
background sessions, removes marked worktrees and branches, and prints each thing it removed.
Then `check.sh` must show no `FAIL R5` line before the next test starts.

Nested start: this session sets `CLAUDECODE`, `CLAUDE_CODE_CHILD_SESSION`,
`CLAUDE_CODE_MESSAGING_SOCKET` and `CLAUDE_CODE_MESSAGING_TOKEN`. A started session inherits them.
If `claude -p` refuses to start under them, the retry is `env -u <name> ...` with the names the
error points to. The run records which names were unset. Values are never printed (S4).

## Security Notes

These tasks touch an external service (model calls), host processes, messages between sessions,
a secret in the environment, and the privacy of the user's other sessions.

- **S1. Cost (T006, T007, T008, T013, T014, T019, T020).** Each started session is a model call on the
  user's account. Bound: Haiku, one prompt, 3 turns, 5 minutes, no tools (FR-012). About 8
  sessions at most. The test 1 peer and the `spike-main` sessions also run on Haiku.
- **S2. Host processes from a mod (T018, T020).** `spike-start` runs `claude` and `timeout`
  on the host through `$.process.*`. The argv is fixed in the mod. Nothing from the prompt or a
  delivery goes into it. `claude plugin validate --json` lists whether the engine gates these calls
  (research R7, recorded as Q2 evidence).
- **S3. Messages between sessions (T007, T012, T013, T014).** `spike-send` sends only fixed test text,
  to the name `spike-peer` or a session id the user gives. The `session.receive` hook stores only
  deliveries whose text holds `spk003` and drops nothing. The sender plugin name on a received
  delivery is the sender's claim (types file, `SessionReceiveOrigin.plugin`), so the mod never
  trusts it.
- **S4. Secret in the environment (T001, T005, T006).** `CLAUDE_CODE_MESSAGING_TOKEN` is in this session's
  environment and a started session inherits it. Print variable names only
  (`env | cut -d= -f1`), never values. `check.sh` R8 fails on a `TOKEN=`, `SECRET=` or `KEY=` value
  in the report or the spike folder. T028 also greps the feature folder for the token value itself,
  passed by file (`grep -rlF -f <(printenv CLAUDE_CODE_MESSAGING_TOKEN)`), never in argv or output.
- **S5. The user's other sessions (T003, T007, T013, T022, T028).** `claude agents --json` and ListAgents list
  every session of the user, with names, folders and ids. The report copies only rows whose name
  holds `spk003` (`jq` select on the name), one compact row per line (`jq -c`). `check.sh` R8 fails
  on any report line holding `"sessionId"` that holds neither `spk003` nor `spike-`.
- No sign-in change, no data model, no access rule, no minors' data. No cloud session (D8).

## Project Structure

### Documentation (this feature)

```text
specs/003-session-mods/
├── spec.md
├── decisions.md
├── plan.md
├── research.md            # Phase 0 notes, then the Spike report the build fills (D7)
├── data-model.md          # the report's line format, which check.sh reads
├── quickstart.md          # exact manual steps (FR-014)
├── checklists/
└── tasks.md
```

### Spike files (all new, under the feature folder)

```text
specs/003-session-mods/spikes/
├── check.sh               # the test: R1 to R9 (data-model.md)
├── cleanup.sh             # stops and removes everything marked spk003
├── spike-send/            # test 1 mod
│   ├── .claude-plugin/plugin.json
│   ├── hooks/hooks.json
│   ├── hooks/register.tsx
│   ├── hooks/register.test.tsx
│   └── types/index.d.ts
└── spike-start/           # test 2 mod, same five files
```

The engine lays `.claude-plugin/types/` and `tsconfig.json` into a mod folder it loads.
`tsconfig.json` is in the root `.gitignore`. The root pattern `.claude-plugin/types/` is anchored
to the repo root and does not match a spike folder (`git check-ignore` confirms). The engine also
lays a `.gitignore` of `*` inside the types folder (`mods/st-tree/.claude-plugin/types/.gitignore`
on disk, not tracked on branch `st-tree`). T013 checks this on the first load.

**Structure Decision**: Each mod is its own plugin folder with the layout of `mods/st-tree` on
branch `st-tree` (manifest with `"types": "./types/index.d.ts"`, `hooks.json` naming
`./register.tsx`). No contracts/ folder: the only interface is the report format, and
data-model.md holds it.

## Complexity Tracking

No violations.

## Validate

Date: 2026-10-11. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | All tools present at the planned versions: claude 2.1.296, jq 1.8.2, timeout 9.12, pgrep (procps-ng 4.0.7), git 2.56.0, bash 5.3.20. Every CLI flag and subcommand the plan names is in `--help` (`--bg`, `-p`, `-n`, `--tools`, `--strict-mcp-config`, `--no-session-persistence`, `--output-format`, `-w`, `--plugin-dir`, `agents --json/--all`, `logs`, `stop`, `rm`, `plugin validate --json`, `plugin test`). Every `$` call and event the plan names is in the 2.1.296 d.ts. Branch `st-tree` has the mod layout T010 copies. The `.gitignore` claims in Project Structure hold (`git check-ignore`) |
| 2. Test coverage per requirement | CONCERN | F1, F2, F3, F7, F8, F9 |
| 3. Breaking changes | PASS | All new files are under `specs/003-session-mods/`. No public API, contract, stored data or shared code changes. `git status` today shows only the allowed paths |
| 4. Security and privacy | CONCERN | F10 |

F1. tasks.md:73, tasks.md:160-166 R6, R8 and R9 are never shown red. T002 shows R1 to R4 and R7 red, and T027 to T029 show R2, R3 and R5 red. A check that never went red is not proven. -> Add negative controls: R8 on a mktemp copy of the report with a `TOKEN=x` line, and R9 and R6 by a temporary marked change that is then removed (R9 reads the fixed quickstart path, so it needs a path argument or a short edit and restore). st-plan.

F2. data-model.md:97, tasks.md:114, tasks.md:136, tasks.md:150 R8 fails on every report line with `"name":` that does not hold `spk003`. T022 tells the build to use the `claude plugin validate --json` output of T012 and T018 as Q1 and Q2 evidence. That output most likely holds `"name": "spike-send"` (the T010 manifest name), so a correct report turns R8 red. -> Limit R8 to rows copied from `claude agents --json` or ListAgents, or tell T022 to copy only the `gatingHooks` list. st-plan.

F3. data-model.md:52, data-model.md:93, spec.md:149-150 FR-012 says 3 turns and 5 minutes. R4 checks only that each Started sessions row holds `spk003` and `haiku`. The data-model rule "Stopped minus Started is at most 300 seconds" has no check. The `--bg` sessions (C2, B2) are the only ones with no `timeout` wrapper. -> Make R4 also check Stopped minus Started <= 300 s, and `--max-turns 3` in the Argv unless the Limit field records that `--bg` refused it. st-plan.

F7. tasks.md:110, tasks.md:132 In the test kit, `$.command.run` takes the full `CommandRunInput` (d.ts 1798-1825 and `EngineCall`, 15029): `command`, `args`, `origin`, `presentation`. T011 and T017 pass only `{ command, args }`. The command is registered only in `session.start`, which neither test raises first. The red run in T011 and T017 can then fail for the wrong reason. -> Pass `origin: { kind: 'composer' }` and `presentation: { isFullscreen: false, columns: 80 }`, raise `$.session.start` first, and confirm on the first red run that the failure names the missing `register.tsx`. st-plan.

F8. tasks.md:165 T029 starts `bash -c 'exec -a spk003-nc sleep 120' &` inside one Bash tool call. The Bash tool can kill the job when the call ends. Then `check.sh` shows no `FAIL R5` and the control fails for a harness reason. -> Start it with `setsid -f bash -c 'exec -a spk003-nc sleep 120'`. st-plan.

F9. tasks.md:93, data-model.md:32 "Result back" (FR-005, exact reply text) is a field the build writes. `check.sh` checks that it is `yes` or `no`, not that the reply equals `spk003-<id>-ok`. -> Require the Evidence field of Tests 2 and 3 to quote the raw reply line, and make R1 check that the line holds `spk003-t<n><x>-ok` when Result back is `yes`. st-plan.

F10. tasks.md:72, plan.md:159-162 R8 catches only `TOKEN=`, `SECRET=` or `KEY=` followed by a value. A bare `CLAUDE_CODE_MESSAGING_TOKEN` value in pasted output passes. -> In T030, also run `grep -rlF -f <(printenv CLAUDE_CODE_MESSAGING_TOKEN) specs/003-session-mods/` (the value goes in by file, never in argv or output) and expect no match. st-plan.
