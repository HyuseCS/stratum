# Implementation Plan: Autonomous build mode in more than one session at the same time

**Branch**: `077-autonomous-sessions` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/018-autonomous-sessions/spec.md`, decisions D19 and D20 in `decisions.md`.

## Summary

The single flag file `<main checkout>/.stratum/autonomous` becomes a folder with one empty entry per session id (D19). Turning on makes only this session's entry, `autonomous-off` removes only it, here and on each saved machine. Every reader (statusline, approve hook, worker script) uses one rule: the id is valid, the folder and the entry are real (no symlink), and the entry exists. Lock 2 in `hooks/st-approve.py` is widened from the flag path to the folder and every entry. The skills turn the mode off at the end of a run, on "stop autonomous" and before a handoff when the user will continue later (D20). Design: `research.md`, rules: `contracts/autonomous-mode.md`.

## Technical Context

**Language/Version**: Bash 5 (`scripts/st-worker.sh`, `statusline/st-statusline.sh` wrapper), Python 3 stdlib (`hooks/st-approve.py`, statusline body), Markdown skills.

**Primary Dependencies**: git (`rev-parse --git-common-dir`), herdr and ssh only through the existing stubs in `tests/test_st_worker.sh`, jq (already used), node and likec4@1.60.0 for the harness model checks only.

**Storage**: files in `.stratum/autonomous/` (see `data-model.md`).

**Testing**: `bash tests/<file>.sh`, `python3 tests/test_approve_hook.py` (unittest). All fixtures under `mktemp -d` or `tempfile.TemporaryDirectory`.

**Target Platform**: Linux and macOS shells where Claude Code and herdr run (PC and laptop).

**Project Type**: Claude Code plugin (skills, hooks, scripts).

**Performance Goals**: none new. Readers do the same number of file checks as today.

**Constraints**: the build runs in a worker worktree, where lock 2 denies any Bash call whose text names `.stratum/autonomous` or `.stratum/approve`, so no `Test:` line or task command may contain those words (run the test files, do not grep them for the path); no new dependency; lock 2 stays a text match; no cleanup of crashed sessions' entries (D20); `.stratum/autonomous` stays untracked.

**Scale/Scope**: a few orchestrator sessions per repo.

## Constitution Check

No `.stratum/constitution.md` exists in this repo and no app has an `ORDINANCE.md`. No gate applies. Re-checked after Phase 1: still none.

## Project Structure

### Documentation (this feature)

```text
specs/018-autonomous-sessions/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/autonomous-mode.md
└── tasks.md
```

### Source Code (repository root)

```text
statusline/st-statusline.sh        # reader rule C1 (lines 47-57)
hooks/st-approve.py                # reader rule C1 in request() (253-258), lock 2 in locked_path() (91)
scripts/st-worker.sh               # reader rule C1 (68), remote turn-on (277), autonomous-off (690-732)
skills/st/SKILL.md                 # turn-on line (89), turn-off triggers (90, 93)
skills/st-worker/SKILL.md          # saved-machine sentence (43)
skills/st-handoff/SKILL.md         # turn-off before the handoff
README.md                          # line 293, the hook's on rule
DESIGN.md                          # line 194, local file table row (F5)
docs/harness/model/data.c4         # stratum.autonomous summary
docs/harness/model/hooks.c4        # st-approve-py summary (D2)
docs/harness/atlas/data.mjs        # node S: autonomous -> autonomous/
docs/harness/atlas/atlas.html      # rebuilt from data.mjs
docs/harness/atlas/SYSTEM.md       # rebuilt from data.mjs
tests/test_statusline.sh
tests/test_approve_hook.py
tests/test_st_worker.sh
tests/test_worker_rules.sh
tests/test_harness_model.sh        # run only, no edit expected
```

**Structure Decision**: no new file. Each change lands where the reader or writer is today.

## Design per file

1. `statusline/st-statusline.sh`: replace the first-line compare with rule C1 on `data.get("session_id")`. Keep the folder path as today (main checkout of `cwd`, else `proj`).
2. `hooks/st-approve.py`:
   - `request()`: rule C1 with `S` = first line of `approve/session`.
   - `locked_path()`: `"/.stratum/autonomous/" in p + "/"`, the same form as the approve folder. The Bash branch is unchanged (substring already covers entries).
   - `RISKY`: gains `autonomous-on` (D1).
3. `scripts/st-worker.sh`:
   - Line 68: rule C1 in bash: `[[ $SID =~ ^[A-Za-z0-9-]+$ ]] && [ -d "$D" ] && [ ! -L "$D" ] && [ -f "$D/$SID" ] && [ ! -L "$D/$SID" ]` with `D=$MAIN/.stratum/autonomous`.
   - New `autonomous-on` (D1, contract C2): no id argument, no options (any option prints usage). It joins `list | autonomous-off | watch` where those skip the task id (lines 9, 58) and the herdr-pane check (line 108), and joins the line-62 block (worker-worktree refusal), but skips the "mode is on" check at line 68, like `autonomous-off`. Add it to the usage line.
   - Line 277 remote write: contract C2 steps in the one `sshq` call. The error line and order (before `worktree add`) stay.
   - `autonomous-off`: id check first, then per machine C3 lines. Local and remote remove only `<folder>/<SID>`.
4. Skills: the turn-on line at `skills/st/SKILL.md:89` runs `autonomous-on` (D1). `skills/st/SKILL.md:90` text says it removes only this session's entry. `:93` adds "or will continue some other time". `skills/st-handoff/SKILL.md` gets a turn-off step in the main-session branch, before "Write it". `skills/st-worker/SKILL.md:43` names the entry.
5. Harness docs (D2 = A): `data.c4` summary describes the folder of entries; `hooks.c4` `st-approve-py` summary says "the autonomous folder" in place of "the autonomous flag". Atlas: `data.mjs` node `S` names `autonomous/`, then rebuild with `META.buildCmd`.
6. Tests: change only lines that build or check the old single file (FR-013), and add the two-session cases (FR-012).
7. D21 fixes (FR-014, FR-015):
   - `scripts/st-worker.sh` `question()` (line 172): also true when the visible pane has `Ready to submit your answers?`. The permission check (`! grep -qaE "$PERM"`) stays first and unchanged. The other callers (`followup` at 375, `wait` at 423, `watch` at 554 and 617) then also see that screen as an open question, which is the wanted result. Side effect, accepted: `wait`, `watch` and `followup` now report the review screen as an open question.
   - Known limit (review F4): the match runs over the whole pane text that `readpane` returns, not only the last screen. A stale `Ready to submit your answers?` line still in that text makes `question()` true. Upgrade only if a false answer prompt shows up in use.
   - `skills/st-worker/SKILL.md` step 6 (line 28): the sentence "The dialog must show the whole command or path. Else send no key and tell the user." is replaced by the FR-015 sentence in tasks.md T022. The never list (line 34) does not change.

`skills/st-build/SKILL.md` needs no change: it has no autonomous text, and `skills/st/SKILL.md:90` already ends the mode at the end of a Build. `README.md:293` names the old layout ("the main checkout's `.stratum/autonomous` and the worker's session file must match", row W15 in `tests/test_worker_rules.sh`). It changes to the entry rule. This corrects finding F3 of the first Plan report.

## Security notes

- S1 Access rule (lock 2, FR-007, `hooks/st-approve.py`): a worker that could make an entry could approve its own prompts. The edit-tool path match is widened to the folder and every entry. The Bash match already covers them. Tests deny Bash and every file tool on `.stratum/autonomous/<id>` and on the folder. The guard stays a text match (ponytail note at line 94): run-time built paths still get past it, as today.
- S2 Session id used as a path (FR-005, SC-004): every place that joins the id to the folder checks `^[A-Za-z0-9-]+$` first, including the approve hook. Its id comes from `approve/session`, a file under lock 2, but the hook still checks it before it uses the text as a path.
- S3 Symlinks (FR-006): no entry is made, read as on, or removed through a symlinked folder or entry, here and on a saved machine. The statusline gains this check (it has none today).
- S4 External service (ssh to a saved machine, `scripts/st-worker.sh:277` and `:720`): the id is passed through `printf %q` as today, and is already limited to `[A-Za-z0-9-]`. The remote script removes only `<repo>/.stratum/autonomous/<id>`.
- S5 Data: no personal or minors' data. Session ids are local, random UUIDs.

## Rollout and rollback

- Every roster machine needs this plugin version. A saved machine with an older version reads the old single-file flag, finds a folder, and counts as off: it fails safe, and its workers' prompts wait for the user.
- Rollback: to go back to an older plugin, remove `.stratum/autonomous/` in each main checkout, here and on each saved machine.
- Merge-time item (not a task now): if #80 (st-research) is on origin/main when this branch merges it before the PR, update st-research's autonomous flag check to the per-session layout (contract C1), with its test.

## Decisions (answered 2026-11-08)

- D1 = A. The local turn-on step is a new subcommand `st-worker.sh autonomous-on` (contract C2). The skill line becomes `bash <plugin root>/scripts/st-worker.sh autonomous-on`. It is refused from a worker worktree by the existing check (`scripts/st-worker.sh:62-66`). `autonomous-on` goes into `RISKY` (`hooks/st-approve.py:16`), `LOCK2_WORKER_CALLS` (`tests/test_approve_hook.py`) and the never-list sentence (`skills/st-worker/SKILL.md:34`, row W5). Rejected: B, a longer shell line in the skill (only text-tested, and F2 in `tests/test_worker_rules.sh` would have to be loosened).
- D2 = A. Only `summary` lines change (`data.c4` `stratum.autonomous`, `hooks.c4` `st-approve-py`). Relationship labels stay, so `docs/harness/README.md` needs no rebuild. `scripts.c4` has no summary that names the flag, so it does not change. Rejected: B, labels too, with two more files.
- F7 accepted: an entry is an empty file; `autonomous-off` and `autonomous-on` with an empty or bad id remove or make nothing and exit 1.

## Complexity Tracking

None.

## Validate

Date: 2026-11-08. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | none. bash 5.3, Python 3.14, git 2.56, jq 1.8.2, node 24.14.1 (gate 22.22.3), herdr and ssh present, atlas `build.mjs` and `template.html` present. Baseline green: `bash tests/test_statusline.sh`, `python3 tests/test_approve_hook.py`, `bash tests/test_st_worker.sh`, `bash tests/test_worker_rules.sh`, `bash tests/test_harness_model.sh coverage missing summaries links validate rebuild atlas readme nomcp` (likec4@1.60.0 validate and rebuild ok). |
| 2. Test coverage per requirement | CONCERN | F1, F2, F3, F6 |
| 3. Breaking changes | CONCERN | F4, F5 |
| 4. Security and privacy | PASS | none. S1-S5 each have a test task: lock 2 T014/T016, id rule T001(f)/T002(g)/T003 ON5 and OF2, symlinks T001(d)(e)/T002(e)(f)/T003 ON6 and OF3, ssh id passed through `printf %q` and limited to `[A-Za-z0-9-]`. No secrets, no personal data. |

F1. tasks.md:45-46, tasks.md:64-66, tasks.md:105 `[P]` build tasks share one test file that cannot go green alone. T004 changes rows W8 and G11 (`skills/st/SKILL.md`, T008) and W15 (`README.md`, T009) together, so T008 alone leaves W15 red and T009 alone leaves W8 and G11 red. Same in Phase 4: T010 changes W9 and W34 (T011), W35 (T012) and W17 (T013). tasks.md:105 says no `[P]` task needs another's result. -> st-plan: merge T008+T009 and T011+T012+T013, or keep `[P]` and state that `bash tests/test_worker_rules.sh` goes green only when the phase is complete.

F2. tasks.md:31, tasks.md:32, tasks.md:33 Negative cases that can pass with no id check. T001(f) and T002(g) (`../x` with `.stratum/x` present) prove the id rule only when the mode folder is a real directory at that moment; T001 runs (c) old file and (d) symlinked folder before (f), so (f) can pass on rule 2 alone. OF2 says "remove nothing" but names no bait file. Every statusline "no segment" case is a negated grep on stdout, so a Python error (for example `re.fullmatch` on a missing `session_id`) also passes. -> st-plan: in T001(f) and T002(g) state that the folder is a real directory with another entry; in OF2 make `$repo/.stratum/x` first and check it still exists; give each statusline no-segment case a positive check too (exit 0 and line 2 present).

F3. tasks.md:33 Contract rows with no test case: local `autonomous-off` with a symlinked entry (C3 row 3, FR-006), saved-machine `autonomous-off` with a symlinked folder or entry, `autonomous-off` over an old single-file flag ("not on for this session", data-model Old flag), and `autonomous-on` outside a git repo (C2 table row 2). -> st-plan: add OF5-OF7 and ON9 to T003.

F4. plan.md:9, data-model.md:27 Stored-data change with no rollback note. The path `<main checkout>/.stratum/autonomous` changes from a file to a folder. (a) Rollback to the earlier plugin: its turn-on `printf ... >` fails with "Is a directory" and its `autonomous-off` finds no file, so no session can turn on until the folder is removed. (b) Mixed versions across machines: a saved machine with the older plugin runs the older `st-approve.py`, which reads the folder as a file and stays silent, so that worker's prompts wait for the user (fails safe). (c) A session that is on at upgrade time drops to off with no message (spec edge case accepts it). -> st-plan: add a rollback line to plan.md and quickstart.md ("to go back, remove the `autonomous/` folder in each main checkout, here and on each saved machine") and a note that every machine in the roster needs this plugin version.

F5. DESIGN.md:194, docs/harness/model/skills-core.c4:84 Docs left on the old layout. DESIGN.md says the main checkout "holds the flag" and is not on the file list. After D1 the skill no longer writes the entry (`st-worker.sh autonomous-on` does), so `skills.st -[writes]-> stratum.autonomous` is no longer true. D2 = A kept labels on purpose. -> user decision: accept as is, or add DESIGN.md:194 to T018 (one row, no test).

F6. tasks.md:58, tasks.md:127-129 FR-009, FR-010 and FR-011 are proved only by phrase match on skill files (`tests/test_worker_rules.sh` W8, W9, W17, W34, W35). That the orchestrator runs `autonomous-off` at those moments is proved only by the by-hand steps in quickstart.md. -> no change; record it in the Close report.
