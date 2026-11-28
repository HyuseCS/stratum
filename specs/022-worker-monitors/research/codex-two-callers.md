# Research: two callers of a Codex point of st-advisor.sh in one checkout
Written by: st-research

## Round 1

### Scope

Feature 022 (worker monitors, `specs/022-worker-monitors/spec.md`) can have several monitor agents of one orchestrator session, all in the main checkout, and each one can call a Codex point of `scripts/st-advisor.sh`. This round finds what the script does when two callers run a point at the same time. Design sources: `skills/st-build/advisor.md` and `specs/013-codex-shared-tab/decisions.md` read in full. `specs/013-codex-shared-tab/spec.md` read by keyword grep plus its edge cases (lines 64-72). `specs/013-codex-shared-tab/contracts/advisor-tab.md` lines 31-80 and `specs/013-codex-shared-tab/research.md` R13 also read.

### Key facts

#### Q1. Herdr Codex tab path: locks, pid files and busy checks

The tab path runs when `HERDR_ENV=1`, `HERDR_WORKSPACE_ID` is set and `herdr` is on PATH (`scripts/st-advisor.sh:249`). Its guards, in run order:

- F1. Tab name. `tabname` gives `st-codex-<workspace label slug>`, or `st-codex-worker-<id>` when `.stratum/worker` exists (`scripts/st-advisor.sh:7-27`). Two callers in the same checkout and workspace get the same name.
- F2. The one lock. The whole tab run is wrapped in `st-lock.sh --name "codex-$HERDR_WORKSPACE_ID" --timeout 50` (`scripts/st-advisor.sh:254`). The lock is the folder `<git common dir>/stratum-codex-<workspace id>.lock`, made with `mkdir` (`scripts/st-lock.sh:16-19`), with `pid` and `since` files in it (`scripts/st-lock.sh:36-37`). Its key is the repo (the git common dir, shared by the main checkout and its worktrees) plus the herdr workspace id. It is not keyed on the feature or the caller. A waiter polls once per second (`scripts/st-lock.sh:31-32`). A dead holder pid makes the waiter remove the folder and retry (`scripts/st-lock.sh:20-24`). After 50 s of waiting it prints `lock: waited ...; ran nothing` on stderr and exits 75 (`scripts/st-lock.sh:27-30`). The lock is released when the wrapped command ends (`scripts/st-lock.sh:34`). A known race is marked: two waiters that see a dead owner in the same second can both run (`scripts/st-lock.sh:22`).
- F3. Exit 75 handling. `[ $rc = 75 ] && block "Codex agent busy with another review"` (`scripts/st-advisor.sh:255`). `block` appends a BLOCKED record and exits 1 (`scripts/st-advisor.sh:205-209`).
- F4. Name clash check inside the lock. If an agent with the tab name exists in another workspace or another cwd, `st-codex-agent.sh` exits 5 (`scripts/st-codex-agent.sh:52-61`), and st-advisor goes headless with `codex: headless (Codex tab name $name in use elsewhere)` (`scripts/st-advisor.sh:261`).
- F5. Tab state busy check inside the lock. `herdr agent get` status `working` or `blocked` gives `codex: tab in use`, exit 3 (`scripts/st-codex-agent.sh:90-92`). A prompt call that returns `agent_blocked` also gives exit 3 (`scripts/st-codex-agent.sh:105-106`). st-advisor maps 3 to headless with `codex: headless (Codex tab in use)` (`scripts/st-advisor.sh:260`).
- F5b. Pane busy check on a new tab, inside the lock. `herdr agent start` with error `agent_pane_busy` is retried up to 10 times with `sleep 1`, then `ERROR: ...`, exit 1 (`scripts/st-codex-agent.sh:77-83`). st-advisor prints the last `ERROR:` line and goes headless with `codex: headless (Codex tab failed)` (`scripts/st-advisor.sh:263`).
- F6. Review pid file. `mark` writes `$$` to `$tabs/$name.review` (`scripts/st-codex-agent.sh:43-46`, `$tabs` is `${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-tabs`, `scripts/st-advisor.sh:6`). It is removed after the prompt (`scripts/st-codex-agent.sh:102`) and by the EXIT trap. It is not a lock: only `watch` and `answer` read it, to see if a review is live (`scripts/st-advisor.sh:38`). It is keyed on the tab name, so two callers' `watch` and `answer` commands see the same file and the same tab screen (`scripts/st-advisor.sh:36-54`).
- F7. Settings record `$tabs/$name` (tab id plus options, `scripts/st-codex-agent.sh:85`) only drives the `the Codex tab runs with ...` line (`scripts/st-codex-agent.sh:64-71`).
- F8. No time limit inside the lock. The tab run has no `timeout` around it (`scripts/st-advisor.sh:254`, contract `specs/013-codex-shared-tab/contracts/advisor-tab.md:52`, decision D11 at `specs/013-codex-shared-tab/decisions.md:13`). So the lock is held for the full length of the first review, while a second caller waits at most 50 s.

Design:
- 013 research R13 "Parallel points": the lock "keeps one tab run per workspace at a time. A second point waits up to 50 s, then ends `BLOCKED: Codex agent busy with another review`" (`specs/013-codex-shared-tab/research.md:83-85`). The 013 contract keeps rc 75 "as today" (`specs/013-codex-shared-tab/contracts/advisor-tab.md:58`).
- The rule first came in feature 010: "Exit 75 from the lock: `BLOCKED: Codex agent busy with another review`, no fallback" (`specs/010-workflow-overhaul/contracts/scripts.md:134-135`, `specs/010-workflow-overhaul/changes/001-codex-tab.md:34`), in commit 66b06fd. Feature 017 keeps it unchanged (`specs/017-st-advisor/contracts/review-point.md:44`).
- 013 decisions: D3, a busy tab sends the point headless at once (`specs/013-codex-shared-tab/decisions.md:5`). D4, one Codex tab per workspace and folder (`specs/013-codex-shared-tab/decisions.md:6`). D11, no time limit in the tab (`specs/013-codex-shared-tab/decisions.md:13`). D15, the tab name is computed before the lock (`specs/013-codex-shared-tab/decisions.md:17`). No decision in D1 to D20 names two Stratum callers at the same time.
- 013 spec: acceptance 6, a second feature in the same workspace and folder uses the same tab (`specs/013-codex-shared-tab/spec.md:28`). Edge case: a user change during a review fails the point because the check cannot tell who changed it (`specs/013-codex-shared-tab/spec.md:72`).

#### Q2. Headless path

The headless block is `scripts/st-advisor.sh:266-278`. It runs `timeout -k 10 $left codex exec -s read-only --ignore-user-config ... --ephemeral` (`scripts/st-advisor.sh:273`), with a limit of 540 s, or 1800 s for the review point (`scripts/st-advisor.sh:266-268`). It takes no lock and reads no pid file. Each caller uses its own `mktemp -d` folder for the prompt, schema and answer (`scripts/st-advisor.sh:183-184`). Nothing in the script stops two headless runs at the same time, so they can run in parallel. The only shared guard is the git snapshot around the run (`scripts/st-advisor.sh:272-277`, see Q5).

A caller reaches the headless path when it is not in herdr (`scripts/st-advisor.sh:248`), or after a tab exit of 3, 5, 6 or another non-4, non-75 code (`scripts/st-advisor.sh:258-264`). With `st-lock.sh`, a tab run with exit 3 ends and frees the lock, so a second caller can take the lock, see the same busy tab and also go headless. Two headless runs then overlap.

#### Q3. What the second caller does

- In herdr, while the first caller holds the lock, the second caller blocks inside `st-lock.sh` for up to 50 s (`scripts/st-lock.sh:19-33`). The `lock: waiting for codex-<ws> (pid N)` line goes to stderr (`scripts/st-lock.sh:26`), which is captured in `$tmp/tab` (`scripts/st-advisor.sh:254`) and not printed. st-advisor prints only the `codex: the Codex tab runs with` lines, `codex: tab` and `ERROR:` lines from that file (`scripts/st-advisor.sh:256-263`).
- If the first review ends within 50 s, the second caller takes the lock and runs its own review in the same tab.
- If the first review takes longer than 50 s, the second caller fails. It does not fall back to headless. It prints `BLOCKED: Codex agent busy with another review` and `record: <record path>` (`scripts/st-advisor.sh:207`), appends a BLOCKED record (`scripts/st-advisor.sh:206`), and exits 1 (`scripts/st-advisor.sh:208`). The `via` line is not printed because `block` exits first.
- The second caller's BLOCKED record for a lane point is written into the work tree while the first review still runs, and so can also block the first caller (Q5, read from code, not run).
- The handover is not ordered. The first caller's lock ends when `st-codex-agent.sh` ends (`scripts/st-advisor.sh:254`, `scripts/st-lock.sh:34`). Its verdict record is written later, outside the lock (`scripts/st-advisor.sh:280-288`). A waiting second caller polls the lock once per second (`scripts/st-lock.sh:31`), then takes its `before` snapshot (`scripts/st-codex-agent.sh:89`). If the first record lands after that snapshot and the record is a lane record in the work tree, the second caller's after snapshot differs (Q5, read from code, not run).
- The skill says a `BLOCKED: <reason>` line means stop and show the user, with `continued` on the user's word, and no retry in this gate pass (`skills/st-build/advisor.md:40`).
- In the headless path the second caller neither waits nor fails because of the first. It runs at once (Q2).

#### Q4. Record file with two writers

Record paths: lane points write `$f/advisor.md` (`scripts/st-advisor.sh:77`). The review point writes `$main/.stratum/advisor/<branch slug>.md` in the main checkout (`scripts/st-advisor.sh:130-133`). The review record folder is git-ignored (`.gitignore:13`). A feature folder `advisor.md` under `specs/` is not ignored.

Append methods. No write takes a lock on the record file.

- `block`, `note`, `talk`, `continued` and `waive` use a shell group `{ [ -s "$rec" ] && echo; printf ...; } >> "$rec"` (`scripts/st-advisor.sh:90`, `:98`, `:108`, `:201`, `:206`). `>>` opens with O_APPEND. The blank line `echo` and the `printf` are two separate writes, and the `-s` test runs before them.
- A verdict uses Python `open(f, "a")` and one `r.write(...)` of the whole record, with a leading newline when `r.tell()` is not 0 (`scripts/st-advisor.sh:286-288`).

Fact on concurrency: two writers append to the same file only when both use the same feature folder (lane points) or the same branch (review point). No code orders or locks two writers. With O_APPEND, each single write lands at the end of the file. A record written by the shell group is two writes, so a second writer's text can land between its blank line and its header. The `-s` and `r.tell()` checks decide the blank separator before the write, without a lock. Whether a Python write of a long record is split into more than one system call was not tested here.

The `check` and `waive` commands read the last matching record (`scripts/st-advisor.sh:103`, `:125`), so record order between two writers changes what they read.

#### Q5. The snapshot check and writes by other agents

Code: `snap` and `snapdiff` in `scripts/common.sh:26-47`. Headless path: `before=$(snap)` before `codex exec`, `after=$(snap)` after, a difference gives `block "files or HEAD changed during the review: <paths>"` (`scripts/st-advisor.sh:272-277`). Tab path: `before=$(snap)` (`scripts/st-codex-agent.sh:89`), `after=$(snap)` (`scripts/st-codex-agent.sh:103`), a difference gives `BLOCKED: Codex changed files during the review: <paths>`, exit 4 (`scripts/st-codex-agent.sh:104`), which st-advisor turns into a BLOCKED record with no headless run (`scripts/st-advisor.sh:257`). Both run from the project root (`scripts/st-codex-agent.sh:7`).

What `snap` covers:
- `HEAD <sha>` (`scripts/common.sh:30`). A commit, by st-git or anyone, moves HEAD and blocks the point.
- The staged index, from `git diff --cached --raw` (`scripts/common.sh:31-34`). A `git add` blocks it.
- Every path in `git status --porcelain=v1 --untracked-files=all` with its status code, file mode and content sha256 (`scripts/common.sh:35-38`). A changed tracked file, and an added, changed or removed untracked file that is not ignored, block the point.
- Nested repos, recursively (`scripts/common.sh:39-41`).
- Pathspec `-- .` from the project root, so the whole work tree (`scripts/common.sh:27`).

What `snap` leaves out:
- `.stratum/state.json` and syncthing temp files, excluded by pathspec (`scripts/common.sh:27`).
- Ignored files. `git status` runs without `--ignored` (`scripts/common.sh:35`). This includes `.stratum/advisor/` (`.gitignore:13`), so review point records do not change the snapshot. Other ignored paths in this repo are listed in `.gitignore`.
- Files outside the work tree, such as a record in the session scratchpad under `/tmp`, the per-caller `mktemp -d` folders, `$tabs` under the XDG state folder, and the lock folder inside `.git` (`scripts/st-lock.sh:17`).
- Refs other than HEAD, and a file changed and then restored to the same content between the two snapshots.

Effects on one caller's point when another agent writes in the same checkout during it:
- A record file in the scratchpad outside the repo: not seen, the point is not blocked.
- An untracked, not ignored file inside the repo: seen, the point is blocked (headless: `files or HEAD changed during the review`, tab: `Codex changed files during the review`). The message blames Codex in the tab path even when another agent wrote the file.
- A commit by st-git: HEAD moves, and the point is blocked.
- A second caller's own record write. A lane point record `specs/<feature>/advisor.md` is inside the work tree and not ignored, so it is in the snapshot. In the headless path, caller A's verdict record (`scripts/st-advisor.sh:280-288`) or BLOCKED record lands in a feature folder while caller B's review runs, and B's after snapshot differs, so B is blocked. A writes its own record after its own after snapshot (`scripts/st-advisor.sh:275` comes before `:280`), so A itself is not blocked by it. In the tab path, the second caller's `BLOCKED: Codex agent busy with another review` record (`scripts/st-advisor.sh:255`, `:206`) is written while the first caller's review still runs (it holds the lock). When the lane record is in the work tree, the first caller's after snapshot (`scripts/st-codex-agent.sh:103`) then differs and the first caller ends `BLOCKED: Codex changed files during the review: specs/<feature>/advisor.md`. A review point record under `.stratum/advisor/` is ignored and does not do this. The same applies at the lock handover (Q3): the first caller's verdict record is written after its lock ends, and can land inside the second caller's snapshot window.

Conflict: the 017 contract says "A headless run has no change check, the same as the other points" (`specs/017-st-advisor/contracts/review-point.md:45`). The code has one for every headless run (`scripts/st-advisor.sh:272-277`), and G-fp1 to G-fp4 test it.

The skill states the rule for the single caller: change no file in the project folder and run no `st-git` until the point ends (`skills/st-build/advisor.md:13`). Spec 013 FR-008 requires the before and after record of changed and untracked files (`specs/013-codex-shared-tab/spec.md:85`).

#### Q6. Tests for two callers or the busy case

No test starts two `st-advisor.sh` processes at the same time. A grep for a backgrounded `st-advisor.sh` call in `tests/*.sh` gives no match.

- `tests/test_lock.sh`: (a) free lock runs the command and passes its exit code, (b) a second run from a worktree waits, prints the holder pid once and runs after the holder ends, (c) `--timeout 1` with the lock held gives exit 75, the `ran nothing` message, and runs nothing, (d) a stale lock with a dead pid runs at once, (e) a lock taken from a worktree sits in the git common dir, (f) `--name codex-w1` runs while the `test` lock is held, (g) outside git exit 2, (h) usage errors exit 2, (i) no pgrep, flock, pkill or ps in the script.
- `tests/test_advisor_matrix.sh`: (k5) a pre-made `.git/stratum-codex-$ws.lock` held by a live pid gives first line `BLOCKED: Codex agent busy with another review` and no `codex exec` (lines 341-352, with the lock's `sleep 1` patched out). (M3) runs two feature folders one after the other in a loop, not at the same time, and both use `st-codex-demo` (lines 362-363). (M4) a `working` tab gives headless with `codex: headless (Codex tab in use)` (line 368). (M6) Codex writing a file in the tab gives `BLOCKED: Codex changed files during the review: new.txt` (line 379). (M7, M8) `answer` with no `.review` marker or a dead pid sends no keys (lines 395, 399). (M17) and (R4) a tab name live elsewhere gives headless (lines 540, 590). (R3) the review point with a working tab goes headless (line 586).
- `tests/test_codex_agent.sh`: C4 and C5 a `working` or `blocked` tab exits 3 with `codex: tab in use`, sends no prompt and writes no marker (lines 163, 167). C22 the marker is not written before the in-use check (line 164) and holds a live pid during the prompt and is gone after (line 350). C7 a prompt that returns `agent_blocked` exits 3 (line 176). C9 the name live in another workspace or cwd exits 5 (lines 179, 182). Tests at lines 250-253 cover `agent_pane_busy` retries on agent start.
- `tests/test_advisor.sh`: G-fp1 to G-fp4 on the headless snapshot: a commit, an untracked file or an index-only change during the point gives `BLOCKED: files or HEAD changed during the review` with a BLOCKED record, and no change gives APPROVED (lines 633-662). The change comes from the fake Codex itself, not from a second caller.

- Other files that match `busy` or `st-lock` are not about the Codex point: `tests/test_st_worker.sh:25-26` and `:446-450` test `agent_pane_busy` retries of worker start, `tests/test_plan_rules.sh:13`, `tests/test_lane_steps.sh:32`, `:48`, `:54` and `tests/test_st_worker.sh:331` check `[lock]` test-lock text, and `tests/test_approve_hook.py:605` names `st-lock.sh` in a hook test. `tests/test_inspect.sh` has no match for `busy`, `st-lock` or `stratum-codex`.

No test covers: two real callers racing for the lock, the 50 s wait ending in success, two headless runs at the same time, two writers on one record file, or one caller's record write blocking another caller's snapshot.

### Open questions

- [planner] Whether feature 022 monitors call `st-advisor.sh` from inside herdr (the tab path, one lock per workspace, 50 s wait) or not (headless, no lock). The env a monitor subagent inherits was not checked.
- [planner] How the Python `r.write` of a long record maps to system calls under two writers was not measured. No test was run (not allowed by the brief).
- [planner] The cross-caller effects in Q5 (a second caller's BLOCKED or verdict record blocking the first caller's snapshot) are read from the code and were not reproduced by a run.

### Commands

- cat sr-opus-5.md
- cat procedures/research.md
- wc -l scripts/st-advisor.sh skills/st-build/advisor.md
- ls specs/013-codex-shared-tab/ specs/022-worker-monitors/
- ls graphify-out
- wc -l scripts/st-lock.sh scripts/st-codex-agent.sh scripts/common.sh
- grep -n 'snap' scripts/common.sh
- ls tests/
- grep -rln 'busy\|st-lock\|75' tests/
- cat .gitignore
- git check-ignore -v .stratum/advisor/x.md specs/022-worker-monitors/advisor.md .stratum/state.json
- git ls-files .stratum
- grep -n 'busy\|75\|st-lock\|codex-\$\|concurr\|parallel\|two \|both run\|at the same time\|changed during' tests/test_codex_agent.sh tests/test_advisor*.sh tests/test_lock*.sh
- sed -n 325,370p tests/test_advisor_matrix.sh
- grep -n 'in use\|\.review\|headless (Codex' tests/test_advisor_matrix.sh tests/test_codex_agent.sh tests/test_advisor.sh
- cat tests/test_lock.sh
- sed -n 372,400p tests/test_advisor_matrix.sh
- sed -n 630,700p tests/test_advisor.sh
- grep -n -i 'lock\|busy\|same time\|concurren\|two \|second\|75\|headless\|in use' specs/013-codex-shared-tab/spec.md specs/013-codex-shared-tab/decisions.md
- git log --oneline -S'Codex agent busy with another review' -- scripts/st-advisor.sh
- git log --oneline -S'--timeout 50' -- scripts/st-advisor.sh
- grep -rn -i 'busy with another\|codex-\$HERDR\|lock' specs/013-codex-shared-tab/plan.md specs/013-codex-shared-tab/research.md specs/013-codex-shared-tab/contracts/*
- grep -n -i 'codex\|advisor' specs/022-worker-monitors/spec.md
- grep -n 'st-advisor.sh.*&\s*$\|st-advisor.sh.*& [a-z]*=\$!' tests/*.sh
- grep -n 'C22\|C7 \|marker' tests/test_codex_agent.sh
- grep -n 'k5\|D15' specs/013-codex-shared-tab/tasks.md
- grep -n '(k5)\|(M3)\|(M4)\|(M6)\|(M7)\|(M8)\|(M17)\|(R3)\|(R4)\|^mkdir -p "\$tmp/sc"\|^for fd' tests/test_advisor_matrix.sh
- grep -n 'G-fp\|FP_CASE\|^cat > "\$tmp/fpbin' tests/test_advisor.sh
- grep -n 'C22 marker\|C7 \|C9 ' tests/test_codex_agent.sh
- cat specs/013-codex-shared-tab/decisions.md
- sed -n 40,80p specs/013-codex-shared-tab/contracts/advisor-tab.md
- grep -rn 'busy with another' specs skills
- grep -n 'busy\|st-lock\|stratum-codex' tests/test_st_worker.sh tests/test_inspect.sh tests/test_approve_hook.py tests/test_plan_rules.sh tests/test_lane_steps.sh
- sed -n 64,72p specs/013-codex-shared-tab/spec.md
- sed -n 80,88p specs/013-codex-shared-tab/research.md
- sed -n 128,137p specs/010-workflow-overhaul/contracts/scripts.md
- sed -n 40,46p specs/017-st-advisor/contracts/review-point.md
- grep -n 'rc 75' specs/013-codex-shared-tab/contracts/advisor-tab.md
- grep -n 'R13\|cannot tell who' specs/013-codex-shared-tab/research.md specs/013-codex-shared-tab/spec.md
- grep -n 'no change check' specs/017-st-advisor/contracts/review-point.md
- grep -n 'no fallback' specs/010-workflow-overhaul/contracts/scripts.md
