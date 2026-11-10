# Implementation Plan: Workers in their own herdr workspaces, each with its own Codex tab

**Branch**: `worker-f94` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/020-worker-workspaces/spec.md`

## Summary

`st-worker.sh start` makes one new herdr workspace per worker (`workspace create --cwd <worktree> --label "<orchestrator> / <id>: <task words>" --no-focus`) and renames its default tab to `worker-<id>`. It no longer adds a tab to the orchestrator's workspace, and the saved-machine path (main checkout workspace, `st-workers`) goes away: the same call runs with `--machine`. `close` closes the whole workspace when it holds only the worker tab and `Codex` tabs, else only the worker tab. `list` adds the workspace label as the last field. `st-advisor.sh` `tabname` names the Codex agent `st-codex-<branch>` when the current branch is a worker branch (`worker-<id>`). The skill text drops the old layout.

## Technical Context

**Language/Version**: Bash 5 (scripts), Python 3 inline in `st-advisor.sh` (unchanged)

**Primary Dependencies**: herdr 0.9.4 (`workspace create`, `tab rename <TAB_ID> <LABEL>`, `workspace close <id>`, `tab list --workspace`), jq, git

**Storage**: N/A (herdr state only)

**Testing**: `bash tests/test_st_worker.sh` (herdr, ssh, git stubs), `bash tests/test_advisor_matrix.sh` (fake herdr in `hbin2`), `bash tests/test_worker_rules.sh` (skill phrase greps)

**Target Platform**: Linux, PC and laptop (saved machine through `herdr --machine`)

**Project Type**: CLI scripts inside the Stratum Claude Code plugin

**Performance Goals**: N/A. `start` adds one local `workspace list` and one `tab rename`. `close` adds one `tab list --workspace`. `list` adds one `workspace list`.

**Constraints**: Keep the diff small: issue #93 changes `answer`, the `wait`/`watch` screen hashing and the Codex answer reader in the same scripts. Touch only `start`, `close`, `list` and `tabname`. herdr agent names must match `[a-z][a-z0-9_-]{0,31}` (32 characters max, `herdr --skill` line 57).

**Scale/Scope**: about 30 changed lines in `scripts/st-worker.sh`, 2 in `scripts/st-advisor.sh`, 3 lines of skill text, and test changes.

## Constitution Check

No `.stratum/constitution.md` in this repo (base repo, no constitution). No app ordinances. Gate: pass.

Build code rules (from the brief):

- Minimal code. No new functions, helpers or options. Reuse `h`, `get`, `rx`, `stop`, `jq` the way the code around them does.
- No explanatory comments. Only `# ponytail: <limit>, <when to upgrade>` markers on deliberate shortcuts: the 30-character cut of the task words, the 32-character cut of the Codex name (D14), and the `Codex` label match in `close`.
- Do not touch `answer`, `wait`, `watch`, `screen`, `find_worker`, or `scripts/st-codex-agent.sh`.

## Design

### start (`scripts/st-worker.sh` lines 281-308)

1. After the `--repo ~` resolution (line 275), build the label `L` (rules in [data-model.md](data-model.md)). The orchestrator part comes from a plain `herdr workspace list` (never `"${H[@]}"`: the orchestrator is local) only when `HERDR_ENV=1` and `HERDR_WORKSPACE_ID` is set. A failed or empty lookup falls back to `basename "$repo"`, with no stop.
2. Delete the `if [ -z "$m" ]; then WS=... else ... st-workers ... fi` block (lines 281-294).
3. Replace `tab create` (line 301) with `workspace create --cwd "$path" --label "$L" --no-focus`, read `WS`, `TAB` (`.result.tab.tab_id`) and `PANE` (`.result.root_pane.pane_id`), then `tab rename "$TAB" "$N"`. Neither call goes through `h`: `h` stops on failure and overwrites `$r`. The task-word cut runs with `LC_ALL=C.UTF-8` so it counts characters. A `workspace create` answer without a workspace, tab or pane id goes to the undo below with `no <key> in the herdr answer`. Use the `if ! r=$("${H[@]}" ... 2>"$e")` form of today's `tab create`.
4. FR-008: if `workspace create` fails, undo the worktree and branch as today. If `tab rename` fails, also run `"${H[@]}" workspace close "$WS"` (not through `h`) before the undo, and go on to the undo even if that close fails. `WS` comes from `.result.workspace.workspace_id`. Clear `TAB= PANE=` with `BR= WT=` before the stop. The `stopped:` line keeps the herdr message, and the worktree undo failure keeps its `; left <path> and branch <N>` text.

### close (`scripts/st-worker.sh` lines 520-530)

Replace `h tab close "$TAB"` and the `st-workers` block with:

- `h tab list --workspace "$WS"` stops with `no .result.tabs in the herdr answer` when the answer has no tabs array.
- If the worker tab `$N` is in the list, every tab label there is `$N` or `Codex`, and (with no `--machine`) `$HERDR_WORKSPACE_ID` is not empty and `$WS` differs from it: `h workspace close "$WS"`. Otherwise: `h tab close "$TAB"`. A local close with an empty `HERDR_WORKSPACE_ID` closes only the tab.
- With `--machine` the id guard is skipped: workspace ids are per server, so a remote id can equal the local one.
- The agent and tab check loop after it stays as is.

### list (`scripts/st-worker.sh` lines 540-565)

One `h workspace list` before the loop. An answer with no `.result.workspaces` array stops with `no .result.workspaces in the herdr answer`. Each `found` line gets the label of the tab's workspace as a new last field, `-` when not found or when the label is empty or missing, with control characters replaced by a space (jq `gsub("[[:cntrl:]]"; " ")`) so a tab in a user label cannot shift the fields.

### tabname (`scripts/st-advisor.sh` lines 6-22)

First line of `tabname`: when `git symbolic-ref -q --short HEAD` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`, print `st-codex-<branch>` and return. Else the label slug path runs as today, so the orchestrator name does not change. The Codex tab already opens in `$HERDR_WORKSPACE_ID`, which is the worker's own workspace (live probe, spec Assumptions). Why the branch: see [research.md](research.md) R2.

Long ids (D14): `st-codex-worker-` is 16 characters, so ids over 16 characters give a name over herdr's 32-character limit. `tabname` cuts the name to 32 characters, as the label slug path does today. Two ids over 16 characters with the same first 16 clash, and the second point goes headless ("in use elsewhere"). This gets a `# ponytail:` marker.

### Docs (D15)

`README.md:266`, `README.md:270` and `skills/st-build/SKILL.md:97` get one clause each for the worker name `st-codex-worker-<id>`. Rows R7 and R17 in `tests/test_risk_rules.sh` grep lines 97 and 266 word for word, so they change first.

### Skill (`skills/st-worker/SKILL.md`)

Step 4: replace the layout sentence (tested as W14 in `tests/test_worker_rules.sh`) with the per-worker workspace and its name. Step 11: `close` closes the worker's workspace with its Codex tab. Step 12: `found` lines end with the workspace name. No `st-workers`.

## Decisions taken in Plan

- D14: cut `st-codex-worker-<id>` to 32 characters (herdr name limit).
- D15: add the worker Codex name to `README.md:266,270` and `skills/st-build/SKILL.md:97`, and update rows R7 and R17 in `tests/test_risk_rules.sh`.

No open decisions.

## Security and safety notes

- `workspace close` kills every pane and agent in that workspace. Guards: it runs only after every existing refusal of `close` (working or blocked worker, open PR, unreadable PRs, symlinked `.stratum`). It closes only a workspace whose tabs are all `worker-<id>` or `Codex`. Locally it never closes `$HERDR_WORKSPACE_ID`. It never uses `--group`.
- The workspace label comes from the task file and from herdr. It goes to herdr as one argv element and never into an `rsh`, `ssh` or `bash -c` string.
- External services: herdr (local and `--machine`) and ssh, as today. No secrets, no personal data, no data model or access-rule change.

## Project Structure

### Documentation (this feature)

```text
specs/020-worker-workspaces/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/cli.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/st-worker.sh          # start, close, list
scripts/st-advisor.sh         # tabname
skills/st-worker/SKILL.md     # steps 4, 11, 12
skills/st-build/SKILL.md      # line 97, worker Codex name (D15)
README.md                     # lines 266, 270, worker Codex name (D15)
tests/test_risk_rules.sh      # rows R7, R17 (D15)
tests/test_st_worker.sh       # stub: workspace create writes tc.json, tab rename; start, close, list cases
tests/test_advisor_matrix.sh  # worker Codex name cases
tests/test_worker_rules.sh    # W14 phrase, st-workers gone row
```

**Structure Decision**: existing layout, no new files outside the feature folder.

## Complexity Tracking

None.

## Validate

Date: 2026-11-09. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | Local only. herdr 0.9.4 client and server (`herdr status`). `workspace create --cwd --label --no-focus`, `tab rename <TAB_ID> <LABEL>` and `workspace close <workspace_id>` exist (`--help`). `herdr --skill` line 89: `workspace create` returns `.result.workspace`, `.result.tab` and `.result.root_pane`. Line 57: agent names match `[a-z][a-z0-9_-]{0,31}`. jq 1.8.2, bash 5.3.20, git and python3 are installed. No new dependency. Baseline: test_st_worker, test_advisor_matrix, test_worker_rules, test_risk_rules, test_on_demand, test_state and test_lane_steps exit 0 with no FAIL line. Not checked: the laptop (ssh timed out), so the remote herdr version and remote `tab rename` are not proven. Quickstart step 6 is the proof. |
| 2. Test coverage per requirement | CONCERN | F2, F3, F4, F5 |
| 3. Breaking changes | CONCERN | F6, F7. The `list` line gets a new last field. Only the skill (step 12) and the tests L1, L2 and R12 read it, and T010 and T012 change them. No stored data, no migration. |
| 4. Security and privacy | PASS | `workspace close` runs only after every refusal of `close`. It runs only when every tab label is `worker-<id>` or `Codex`, and locally never on `$HERDR_WORKSPACE_ID`. NC8 (T007) proves that guard can fail. No `--group`. The label goes to herdr as one argv element, never into `rx`/`rsh`. `list` replaces control characters in the label (L3). No secrets and no personal data. |

F2. tasks.md:77 (T014), spec.md:145 (FR-012). FR-012 says all existing tests must pass, but T014 and T012 run only 7 suites. `tests/test_advisor.sh` and `tests/test_advisor_waive.sh` load the changed `scripts/st-advisor.sh`, and no task runs them. Low risk: both unset `HERDR_ENV` (line 39), so `tabname` does not run. -> st-plan: add both suites to the T014 test command.
F3. tasks.md:33 (T004), plan.md:47-48. The `tab rename` failure path has three gaps. (1) T004 reads `TAB` and `PANE` before the rename. "Today's undo" (`scripts/st-worker.sh:304`) clears only `BR= WT=`, but S13c (tasks.md:31) and contracts/cli.md:17-18 expect `-` in fields 4 to 7. (2) T004 does not say what to do when the cleanup `workspace close` fails. Through `h`, `stop` runs before the worktree undo. (3) T004 names no jq path for `WS`. -> st-plan: add `TAB= PANE=` to the undo. Run `workspace close` without `h`, and on failure continue to the worktree undo. Read `WS` from `.result.workspace.workspace_id`, as `scripts/st-worker.sh:292` does.
F4. spec.md:122, spec.md:126, tasks.md:31 (WS4). Two spec edge cases have no test. (1) The orchestrator's workspace exists but has an empty label. WS4 tests only a missing workspace (`HWS=wNone`). (2) A leftover workspace with the same label but no `worker-<id>` tab does not block `start`. -> st-plan: add both cases to T002.
F5. tasks.md:56 (T007), tests/test_st_worker.sh:1564. T007 adds CL1 to CL4, but `CL1` already exists in that file ("CL1 close: exit 0, the approve folder is gone"). -> st-plan: use new ids, for example WC1 to WC4.
F6. tasks.md:45 (T005), branch `093-autonomous-prompts` specs/019-autonomous-prompts/tasks.md:104 (T016). Issue #93 adds M25, M26 and M27 to `tests/test_advisor_matrix.sh`, and T005 adds M25a to M25d to the same file. Both features also change `scripts/st-worker.sh`, `tests/test_st_worker.sh` and `tests/test_worker_rules.sh`. The hunks are in different regions (#93: `:168-170`, `:253`, `answer`, autonomous-on). -> st-plan: give T005 ids that #93 does not use, for example M30a to M30d. Whichever branch merges second rebases and runs test_st_worker, test_advisor_matrix and test_worker_rules again.
F7. research.md:18, data-model.md:31, scripts/st-worker.sh:291. Two transition leftovers. (1) research.md:18 says the extra Codex tab of an old-layout worker "ends when those workers close". It does not end: an old-layout worker sits in the orchestrator's workspace, so `close` takes the tab-only path. Its `Codex` tab and its `st-codex-worker-<id>` agent stay there. (2) An `st-workers` workspace on the laptop keeps the first tab that its own `workspace create` made. The new rule never closes it after its last old worker closes, but the old rule did. -> st-plan: correct R2 and add a one-time by-hand note to skill step 11 or to quickstart.

## Round 3: worker folder and branch named by project and issue (US6, US7)

**Date**: 2026-11-10 | **Input**: spec.md US6, US7, FR-013 to FR-025, decisions.md D21 to D26

**Status**: Final. D27 = A, D28 = A, D29 = B (answers 2026-11-10), D30 to D33 as taken in Plan. All are in decisions.md. Round 3 tasks: tasks.md T015 to T031.

### Summary

`start` names the worktree folder and the branch `<project>[-<env>]-<feature>` and writes a marker `.stratum/worker` with the worker id. Every command still finds a worker by its tab `worker-<id>`; `find_worker` and `list` then read the real folder and branch from the worktree whose path is the pane's folder. `result`, `close`, `list`, the guard file, the brief and the `/goal` prompt use that real branch. The worker checks (lock 2 in `hooks/st-approve.py`, the orchestrator-only check in `scripts/st-worker.sh`, the research skill check) see a worker by the marker, a `worker-*` branch, or `.stratum/approve`. Lock 2 also guards the marker. `tabname` takes the id from the marker, else from a `worker-*` branch.

### Build gate (D25)

Build of round 3 starts only after #93 (`093-autonomous-prompts`) is merged into main and origin/main is merged into worker-f94. Code was read on both: worker-f94 at `31b9e39` and `origin/093-autonomous-prompts` at `daac275`. Line numbers in this section are from worker-f94 `31b9e39` and are only a pointer: tasks name functions and case ids.

### Where #93 moves the code round 3 touches

| File | #93 changes | Round 3 touches | Overlap |
|---|---|---|---|
| `scripts/st-worker.sh` | `usage()` (approve `--input-hash`), the argument loop (`approve --input-hash`, drops `instdin`), the argument check `case` (`approve` line), the `approve` stdin block (removed), `st()`, `screen()`, new `block()`, `approval()`, `brief()` rule 5, `answer`, `approve \| pass`, `autonomous-on` hint | `usage()`, the argument loop (new `start` cases next to `start --repo`), the `start` line of the argument check `case`, the worker check before `D=$MAIN/.stratum/autonomous`, the `/goal` prompt block, `find_worker`, `brief()` Branch line and rule 1, the `start`, `goal`, `followup`, `result`, `close`, `list` cases | same lines: `usage()` and `brief()` (rule 1 sits two lines above #93's rule 5). Neighbouring lines: the argument loop and check `case`. #93 leaves `find_worker`, `start`, `goal`, `followup`, `result`, `close`, `list` and the worker check as they are. |
| `hooks/st-approve.py` | adds `CONTROL`, `JOIN`, `unjudgeable()`, `drop()`; changes the `words =` line of `lock2()`, `split_commands()`, `commit_words()`, `commit_check()`, `request()` | `REASON`, `worker_session()`, `locked_path()`, the `if any(".stratum/approve" in w ...` line of `lock2()` (right after #93's `words =` line), and `main()` (`--worker`, D27) | `lock2()` only. #93 leaves `worker_session()`, `locked_path()` and `main()` as they are. |
| `scripts/st-advisor.sh` | the `via` case (`6)` line), one ponytail comment near `lim` | `tabname()` | none |
| `tests/test_st_worker.sh` | approve cases (`--input-hash`), `dropped`, block hash cases | stub, `fresh()`, `run()`, start, find, result, close, list cases | different cases. The WT2 approve call takes #93's `--input-hash` form after the merge. |
| `tests/test_approve_hook.py` | commit form tables, new methods at the end | new `test_marker_*` methods, `DENY_REASON` | `DENY_REASON` only if #93 changes it (it does not) |
| `tests/test_advisor_matrix.sh` | M25 to M28 | new M31a to M31d after the M30 loop | none |

New test ids, free on both branches (grep 2026-11-10): `NM` (names), `MK` (marker), `OW` (old workers), `RB` (real branch in result, close, list), `WT6`+, `M31a`-`M31d`, `test_marker_*`, rule rows `W40`+ and `G20`+.

### Code rules for the round 3 build

- Minimal code. Reuse `fail`, `stop`, `h`, `rx`, `rsh`, `quote`, `jq` the way the code around them does. Two shared pieces only: the helper `goalp` (three callers build the same `/goal` prompt, D30) and one jq filter for the worktree pick (path first, legacy `worker-<id>` branch fallback), defined once and used by `find_worker` and `list`. No other new function, option or abstraction.
- No explanatory comments. Only `# ponytail: <limit>, <when to upgrade>` markers on deliberate shortcuts.
- Each test task runs red before its build task.
- Round 1's "do not touch `find_worker`" is lifted for `find_worker` only (FR-018). #93 does not change it. `answer`, `wait`, `watch`, `screen`, `block` stay untouched.
- Keep the diff small: #93's PR touched the same files.

### Design

#### Flags (D30, plan)

`start` gains `--project <p>`, `--env <e>`, `--issue <n>` and the switch `--issue-task`. With `--issue-task` the feature part is `<issue>_<id lower-case>`: the worker id already is the task id (spec Key Entities), so a separate `--task-id` value could only disagree with it. `--issue-task` without `--issue` is a usage error (exit 2). `usage()` names the four.

#### Name (FR-013 to FR-015)

Rules in [data-model.md](data-model.md) "Worker name". Built in the `start` case right after `repo` is known (line 263), before the guard file `G` (line 264) and before `h tab list`:

1. Move the task-words line `W=...` (line 280) up to here. The workspace label line keeps using it.
2. `<project>`: `--project`, else `basename "$repo"`. On a saved machine that is the `--repo` value as given, before `~` is resolved (`~/proj` gives `proj`; a bare `~` is refused). Lower-case it.
3. `<feature>`: the issue (`_<id>` added with `--issue-task`), else `W` lower-cased with every run of other characters than `a-z0-9` turned into one `_` (`LC_ALL=C sed -E 's/[^a-z0-9]+/_/g'`), else the id lower-cased.
4. `B=<project>[-<env>]-<feature>`. `path="$(dirname "$repo")/$B"` replaces the `<repo>-$N` path (line 276), after the `~` resolution.

#### Safe tokens (FR-016)

- `--project`, `--env` and `--issue` values are checked in the argument checks, next to the model check (lines 86-89): lower-cased, `^[a-z0-9][a-z0-9._-]*$`, no `..`. A bad value fails with one line before any git or herdr call: `Name part <value> must be letters, digits, dot, underscore or dash, start with a letter or digit, and have no "..".`
- The task id is the worker id, already checked at line 60.
- The default project is known only after `git rev-parse` (local) or from `--repo` (saved machine). It is checked with the same rule right after it is made, before any herdr call and before anything is made: `The repo folder name <name> is not a safe name part. Pass --project <name>.`
- `# ponytail: the token rule does not check git ref rules (a part ending in "." or ".lock"), git refuses those at worktree add before anything is made; check with git check-ref-format if a refusal confuses users`.

#### Taken name (FR-017)

No new check. The existing `rx` string in `start` already refuses both before anything is made: `[ ! -e $qp ]` for the folder, and `git worktree add -b <B>` for the branch (probe: exit 255, `fatal: a branch named '<B>' already exists`, no folder made; research R7). The `|| exit 1` after `worktree add` keeps a remote 255 from reading as an ssh failure. Both run before `workspace create`, here and over ssh. Only the tests change: the git stub's `worktree add` refuses with git's message when `refs/heads/<B>` exists in the real repo.

#### start (other changes)

- `G` (guard file) takes `--arg b "$B"`.
- `goalp "$B"` builds and checks the `/goal` prompt before `h tab list`, so P6 still fails with no herdr call.
- `worktree add -q -b $B`, `BR=$B`, and the undo `branch -D $B` / `left $path and branch $B`. `B` is a safe token, so it goes into the `rx` string unquoted, as `N` did.
- Marker (FR-020): `.stratum/worker` holds one line, the id lower-cased. Local: add `"$WT/.stratum/worker"` to the symlink and exists loop and write it after the guard file. Saved machine: add `$Q/.stratum/worker` to the `for p in ...` list of the `rsh` string and append `&& printf '%s\n' <id> > $Q/.stratum/worker` after the guard write.
- `brief()`: `- Branch: $BR`. Rule 1 (D29): `Never commit brief.md, result.md, .stratum/git-guard.json, .stratum/worker or .stratum/approve/, and never write in .stratum/approve/.`
- Roster own-row branch check (D28): the roster loop already keeps the own row (`own=1; orepo=...`); it also keeps that row's branch field. Right after `B` is made, before `goalp` and before any herdr call: `[ "$obr" = "$B" ] || fail "Roster row for $N must name branch $B."`.

#### `/goal` prompt (FR-018, D30)

The block at lines 106-109 becomes the helper `goalp`: `P="/goal \`$test\` exits 0, the change is committed on branch $1, and result.md is written; read brief.md in this folder first and follow it"`, then the 4000-character check with the same message. Callers: `start` (with `$B`, before `h tab list`), `goal` and `followup` (with `$BR`, right after `find_worker`). `goal` gains a `find_worker` call as its first line: three read-only herdr calls (`tab list`, `pane list`, `worktree list`).

#### find_worker (FR-018, FR-019)

After `h worktree list --cwd "$C"`: the shared worktree-pick filter takes the worktree whose `.path` is the pane folder `$C`, else (old workers whose pane left its folder) the one whose `.branch` is `$N`. `find_worker` and `list` both use this one filter; each keeps its own output and failure handling. Set `WT` from its `.path` and `BR` from its `.branch`. None, or no branch: `No worker $N on <machine>.` as today. Same three herdr calls, so `wait`, `watch` and `answer` call counts do not change (FR-004).

#### followup, result, close (FR-018, FR-020)

- `followup`: `refs/heads/$BR` in the autonomous base sha line (line 379).
- `result` on a saved machine: `git fetch -- <target>:<WT> "$BR:$BR"` and `git rev-parse --verify "$BR"`. The `fetched` line keeps its fields.
- `close`: `gh pr list --head "$BR"`. The marker goes with the guard file: local `rm -f "$WT/.stratum/git-guard.json" "$WT/.stratum/worker"`, remote `rm -f $Q/.stratum/git-guard.json $Q/.stratum/worker`. Messages unchanged. The Codex name match (`st-codex-$N` cut to 32) does not change: the marker holds the same id `N` is made from.

#### list (FR-009, FR-018, D31)

The shared worktree-pick filter of `find_worker` (path, else old branch); `list` keeps its own `-` output when nothing is found. Each `found` line gets the branch as a new last field, after the workspace label, `-` when no worktree was found:
`found	<N>	<machine>	<tab>	<pane>	<status>	<path>	<workspace label>	<branch>`.
Why: a new session (skill step 12) has no roster, and steps 8 and 11 need the branch.

#### Worker checks (FR-021, FR-022, FR-023)

- `worker_session()` in `hooks/st-approve.py`: add a third clause, a plain-file marker (`os.path.isfile` and not `os.path.islink`) at `<d>/.stratum/worker` for any folder `d` in the chain it already walks. The `.stratum/approve` clause and the `worker-*` branch clause stay.
- `locked_path()`: add `"/.stratum/worker/" in p + "/"`. This also denies Read, Grep and Glob of the marker in a worker, as for `.stratum/approve` (accepted).
- `lock2()` Bash words: add an exact match, `w == ".stratum/worker" or w.endswith("/.stratum/worker")`. A substring match would also hit `.stratum/worker-setup.sh`.
- `REASON` and the test's `DENY_REASON`: `.stratum/approve/, .stratum/autonomous and .stratum/worker are written only by the orchestrator.`
- `tabname()` in `scripts/st-advisor.sh`: when `$(git rev-parse --show-toplevel)/.stratum/worker` is a plain file, `l=worker-<its first line>`; else `l` is the branch as today. The existing regex line then decides, so a bad marker gives the label slug. The output stays `st-codex-worker-<id>` cut to 32, the same string `close` matches.
- `main()` (D27): `if sys.argv[1:2] == ["--worker"]: sys.exit(0 if worker_session(os.getcwd()) else 1)`, next to the `--render` branch. It reads no stdin and prints nothing.
- `st-worker.sh` orchestrator-only check (the `if` before `D=$MAIN/.stratum/autonomous`, D27): its condition becomes `python3 "$(cd "$(dirname "$0")/.." && pwd)/hooks/st-approve.py" --worker`, the same path form `render()` uses. Message unchanged. `run()` in `tests/test_st_worker.sh` adds `-u CLAUDE_PROJECT_DIR` to its `env`, since the hook rule also walks that folder.
- Research skill step 4 (D27): the first command becomes `python3 <plugin root>/hooks/st-approve.py --worker`; exit 0 means a worker session: the mode is on. Rest of step 4 unchanged.

#### Skill and README (FR-024)

`skills/st-worker/SKILL.md`:
- Step 2: read the worktree naming rule from `.stratum/constitution.md`, or the `ORDINANCE.md` of the app the task touches, when there is one (for example a "Worktree Folders" rule). Its project part goes to `--project`, its env part to `--env`. The issue number from the request or the spec's Input line goes to `--issue <n>`; a worker on one task of that issue also gets `--issue-task`.
- Step 3: the roster's branch field is the real branch, written by the rule `<project>[-<env>]-<issue>` (`_<id lower-case>` added for a one-task worker); with no issue, the task heading lower-cased with each run of other characters than letters and digits as one `_`, else the id. If `start` refuses with `Roster row for <N> must name branch <B>.`, put `<B>` in that row and run `start` again (D28).
- Step 4: the start command gains `[--project "<p>"] [--env "<e>"] [--issue "<n>" [--issue-task]]`.
- Step 8: `<base>..<branch>` and `git merge --no-ff --no-edit <branch>`, with `<branch>` from the worker's roster row.
- Step 11: `gh pr view <branch>` and `gh pr list --head <branch>`.
- Step 12: each `found` line ends with the workspace name and the branch.

`README.md`: the "Worker guard" bullet gets the folder and branch name rule and the marker. The "Autonomous build mode" bullet (row W15) names `.stratum/worker` with `.stratum/approve/` and `.stratum/autonomous`. Lines 266 and 270 (rows R7, R17) do not change.

Tests that grep these lines: `tests/test_worker_rules.sh` (W14, W15, new W40+), `tests/test_on_demand.sh` (`#17 FR-009 review`, `#17 FR-009 merge`, `#pr-flow worker close after merged`, `#pr-flow worker close refuses`), `tests/test_state.sh` (S6), `tests/test_lane_steps.sh`.

### Security notes (round 3)

- Access rule: lock 2 and `worker_session()` change (FR-021, FR-022). The marker adds a way to be seen as a worker and never removes one: the `worker-*` branch and `.stratum/approve` clauses stay. Lock 2 blocks shell and edit-tool writes of the marker. A worker that deletes the marker by a run-time path and switches branch stops being seen; the spec accepts this (Assumptions): it could already switch its branch.
- Trust boundary: `--project`, `--env`, `--issue` and the repo folder name reach `git worktree add -b`, a path, an `ssh` command string and `gh pr list --head`. Each is a checked safe token first. `B` holds only `[a-z0-9._-]`, so it is shell-safe in the `rx` string. The path still goes through `quote`.
- Saved machine: the marker is written over ssh with the same symlink and exists guards as `brief.md` and the guard file.
- A committed marker merged into main would make the orchestrator's checkout a worker: lock 2 would then block its own `approve` and `pass` calls. D29: brief rule 1 names `.stratum/worker`, and it is in this repo's `.gitignore`, the `IGNORE` list of `scripts/st-update.sh` and the ignore list of `skills/st-init/SKILL.md` step 2, as `.stratum/git-guard.json` is. User projects get the `.gitignore` line through `st-update` (an `ignore` row) or `st-init`.
- `--worker` (D27) adds a hook command that only reads the folder chain and git branches. It cannot write or allow anything.

### Lane F: ignore lists (D29)

- `.gitignore`: add `.stratum/worker` after `.stratum/git-guard.json`.
- `scripts/st-update.sh`: add `".stratum/worker"` to `IGNORE` after `".stratum/git-guard.json"`.
- `skills/st-init/SKILL.md` step 2: add `` `.stratum/worker` `` after `` `.stratum/git-guard.json` ``. Keep `` `graphify-out/`. `` last: the negative control in `tests/test_update_items.sh` seds that text.
- Tests: `tests/test_update_items.sh` (st-init names must be st-update items) and a new `U27` case in `tests/test_st_update.sh` after U7: the audit of `$tmp/proj` gives an `ignore` row `.stratum/worker` with state `new`.
- External services: herdr, ssh, git fetch and `gh`, as today. No secrets, no personal data.

### Decisions (round 3)

- D27 (user): A. The hook gains `--worker`; `st-worker.sh` and research step 4 call it.
- D28: A. `start` refuses a roster row for itself that names another branch.
- D29 (user): B. Brief rule 1, `.gitignore`, the `st-update.sh` `IGNORE` list and the `st-init` ignore list name `.stratum/worker`.
- D30: flags `--project`, `--env`, `--issue <n>`, `--issue-task`. One helper `goalp`; `goal` calls `find_worker`.
- D31: `list` prints the branch as a new last field.
- D32: FR-017 uses the existing folder check and `worktree add -b` refusal, no new check.
- D33: the marker holds the id lower-cased, one line; `tabname` prefixes `worker-` and reuses its regex.

No open decisions.
