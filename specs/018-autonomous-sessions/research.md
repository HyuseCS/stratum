# Research: Autonomous build mode in more than one session at the same time

All facts below are read from the code in this worktree (branch `worker-f77`, base `9fe1936`).

## R1. Layout of the mode

- Decision: one folder `<main checkout>/.stratum/autonomous/`, one empty file per session in it, named with the session id (D19).
- Rationale: two sessions never write the same file, so turning on or off in one session cannot change another. No lock and no read-modify-write are needed.
- Alternatives considered: one line per session id in the old file (O1, rejected in D19: two writers race on one file).

## R2. Where lock 2 lives

- Decision: lock 2 stays in `hooks/st-approve.py`, functions `lock2` and `locked_path` (lines 90-113). It is on the file list, so it is no open decision.
- Finding: `locked_path` (line 91) matches `p.endswith("/.stratum/autonomous")`. An edit tool on `.stratum/autonomous/<id>` gets past it. Change it to the form the approve folder uses: `"/.stratum/autonomous/" in p + "/"`. This catches the folder and every entry.
- The Bash branch (line 100) is a substring match on `.stratum/autonomous`, so `touch .stratum/autonomous/S9`, `rm -r .stratum/autonomous` and `mkdir .stratum/autonomous` are already caught. Tests will prove it.
- The level stays a text match (spec Assumptions, ponytail note at line 94).

## R3. The readers today

| Reader | Where | Today | New rule |
|---|---|---|---|
| Statusline | `statusline/st-statusline.sh:47-57` | first line of `<main>/.stratum/autonomous` equals `session_id` | `session_id` matches the id rule, folder is a dir and not a symlink, `<folder>/<id>` is a regular file and not a symlink |
| Approve hook | `hooks/st-approve.py:253-258` | first line of the flag equals first line of `<worktree>/.stratum/approve/session` | same rule, with the id from `approve/session` |
| Worker script check | `scripts/st-worker.sh:68` | `-f` flag and `head -n 1` equals `$SID` | same rule in bash, before `start --autonomous`, `approve`, `pass` |
| Worker script remote write | `scripts/st-worker.sh:277` | writes the id into `$repo/.stratum/autonomous` over ssh | makes `$repo/.stratum/autonomous/<id>` with the same rules |
| Worker script off | `scripts/st-worker.sh:690-732` | removes a flag that holds this id, else "skipped, flag held by" | removes only `<folder>/<id>`, here and per roster machine |

- The statusline has no symlink check today. FR-006 adds one.
- An old regular file at the folder path fails "folder is a dir", so it counts as off for every reader with no extra code (FR-008).

## R4. Session id rule

- Decision: `^[A-Za-z0-9-]+$` (FR-005). Python: `re.fullmatch(r"[A-Za-z0-9-]+", sid)`. Bash: `[[ $SID =~ ^[A-Za-z0-9-]+$ ]]`.
- Rationale: no `/`, no `.`, so `..` and paths are impossible (SC-004). Claude Code session ids are UUIDs (hex digits and `-`), so real ids pass.
- An id may start with `-`. Every `rm`, `touch` or `:` redirect on an entry uses the full path `<folder>/<id>`, so a leading `-` is never read as an option.
- Empty or bad id: the session is off. `start --autonomous`, `approve`, `pass` print the existing line `Autonomous build mode is off for this session.` (exit 1).

## R5. Turn-on steps and the old flag

Decision, the same steps here and on a saved machine:

1. Refuse when the id fails R4.
2. Refuse when `.stratum` (saved machine only, as today) or the folder is a symlink.
3. When the folder path is a regular file (old flag), remove it. Ignore a failed remove.
4. `mkdir -p` the folder, then check it is a dir and not a symlink.
5. Refuse when the entry is a symlink. Make the entry with `: >`.

Rationale for step 3 order: two sessions that turn on at the same moment over an old flag can both see the file. The second `rm -f` then hits a folder and fails with no harm, and `mkdir -p` succeeds. Neither session removes the other's entry.

The local turn-on step is the new subcommand `st-worker.sh autonomous-on` (D1 = A). It shares the id and symlink rules with `autonomous-off` and the saved-machine write, in one tested script. Rejected: a longer shell line in `skills/st/SKILL.md`, which only a text test could check and which would need F2 in `tests/test_worker_rules.sh` loosened.

## R6. Turn-off output

Decision (FR-003): one line per machine, TAB split, exit 1 when any line is `failed`, else 0. See `contracts/autonomous-mode.md`.
The old `autonomous off skipped\t<m>\tflag held by <id>` line goes: other sessions' entries are never read. Its slot is the "not there" line.

## R7. Two sessions at the same moment

- Decision: no lock. Each session touches only its own entry. The only shared step is `mkdir -p` of the folder, which is safe to race.
- Test: in `tests/test_st_worker.sh`, start the on step for two ids in the background at once, then off for one, and check the other entry stays.

## R8. Harness model docs

- Relationship labels (`hooks.c4:180, 243`, `scripts.c4:169-170`, `skills-core.c4:84`) render into `docs/harness/README.md`. `tests/test_harness_model.sh rebuild` diffs that file against a fresh `likec4 export markdown`. `docs/harness/README.md` and `skills-core.c4` are not on the file list.
- Element `summary` lines do not render into `docs/harness/README.md` (grep: 0 matches).
- Decision (D2 = A): change only `summary` lines: `data.c4` `stratum.autonomous` and `hooks.c4` `st-approve-py`. Labels stay true (the entry is named by the session id), so `docs/harness/README.md` is not rebuilt. `scripts.c4` has no summary that names the flag.
- `c_missing` and `c_data` take `.stratum/<name>` from the code with `\.stratum/[A-Za-z0-9_-]+`. `.stratum/autonomous/<id>` still yields `.stratum/autonomous`, so the `stratum.autonomous` element stays valid.

## R9. Atlas

- `docs/harness/atlas/data.mjs` is the source. `atlas.html` and `SYSTEM.md` are rebuilt with `META.buildCmd` (`data.mjs:6`). `~/.claude/skills/system-atlas/assets/build.mjs` and `template.html` are present on this machine.
- Only one text names the file as a file: node `S` `how` lists `autonomous` among the `.stratum` files. Change it to `autonomous/`, as `approve/` is written. The statusline node says "the autonomous flag", which stays true as a user-facing name.

## R10. Skill triggers

- `skills/st/SKILL.md:89` writes the flag with a bare `printf ... >`. `tests/test_worker_rules.sh` F2 (`(>|\brm( -f)?) +"?[^"]*\.stratum/autonomous`) would fail on a plain write to `"$d/.stratum/autonomous/$id"`. D1 = A replaces the write with `bash <plugin root>/scripts/st-worker.sh autonomous-on`.
- `README.md:293` (row W15) says the hook acts while "the main checkout's `.stratum/autonomous` and the worker's session file must match". It names the old layout and changes.
- `skills/st/SKILL.md:90` already ends the mode when the Build or worker run ends and on "stop autonomous". `skills/st/SKILL.md:93` runs the handoff only when the user is done. It gains "or will continue some other time".
- `skills/st-handoff/SKILL.md` "Where it runs" already writes in the main session when the user is done or ending the session. The fork is mid-session only, where the mode stays on. The turn-off goes in the main-session branch, before "Write it".
- `skills/st-build/SKILL.md` has no autonomous text, and `skills/st/SKILL.md:90` covers the end of a Build. No change there.
- `skills/st-worker/SKILL.md:34` (never list) and `:43` (saved machine) name the flag. `:43` changes to name the entry.

## R11. Tests in scope

- Every test file runs alone: `bash tests/<file>.sh` or `python3 tests/<file>.py`. `tests/test_harness_model.sh` takes check names as arguments (`missing summaries atlas validate rebuild`).
- Two-worktree fixtures already exist: `tests/test_statusline.sh:113-124`, `tests/test_st_worker.sh:1219-1236` (`repo-feat2`), `tests/test_approve_hook.py` `make_worker`.
- All fixtures live under `mktemp -d` or `tempfile.TemporaryDirectory`. No test touches a live `.stratum/autonomous`.
