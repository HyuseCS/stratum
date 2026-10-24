# Quickstart: Ultracode Workflow Script for st-pr

Run from the project root `/home/hyuse/Desktop/stratum-22`. Needs node v24, bash 5, git, gh.
Shapes and phrases: [contracts/pr-workflow.md](contracts/pr-workflow.md).

## 1. Automated tests

```bash
export PYTHONDONTWRITEBYTECODE=1
node tests/test_pr_workflow.mjs
bash tests/test_pr_skill.sh
bash tests/test_inspect.sh
node tests/test_token_weather.mjs
bash tests/test_on_demand.sh
git diff --numstat main -- skills/st-pr/SKILL.md | awk '{d+=$2} END {print d+0}'
git status --porcelain
```

Expected red states between tasks:

| After | Red | Green |
|-------|-----|-------|
| T001 | `node tests/test_pr_workflow.mjs` (`FAIL load`, the script does not exist), every row of `bash tests/test_pr_skill.sh` | `bash tests/test_inspect.sh` (README lines name files that exist) |
| T002 | every row of `bash tests/test_pr_skill.sh` | `node tests/test_pr_workflow.mjs`, all 20 cases |
| T003 | nothing | all of the above. The `--numstat` line prints `0` (no line of the old skill changed or deleted, FR-003, FR-010; control C13). `git status --porcelain` lists only the planned files |

## 2. Negative controls (lessons L2)

Each control edits a scratch copy, never the real file, and points the test at it.

```bash
s=$(mktemp -d)
w() { cp workflows/pr.js "$s/pr.js"; sed -i "$1" "$s/pr.js"; ST_PR_SCRIPT="$s/pr.js" node tests/test_pr_workflow.mjs | grep '^FAIL'; }
k() { cp skills/st-pr/SKILL.md "$s/SKILL.md"; sed -i "$1" "$s/SKILL.md"; ST_PR_SKILL="$s/SKILL.md" bash tests/test_pr_skill.sh | grep '^FAIL'; }
```

| ID | Command | Expected FAIL lines |
|----|---------|---------------------|
| C1 | `w 's/const CHUNK = 25/const CHUNK = 24/'` | `chunk size 25`, `one chunk` |
| C2 | `w '/blocked: true/d'` | `blocking stop` |
| C3 | `w "s/, 'commands'\]/]/"` | `three refuters`, `sequential fixers`, `agent count` |
| C4 | by hand in `$s/pr.js`: build one thunk per lens with problems and `await parallel(thunks)` instead of the `for` loop, then `ST_PR_SCRIPT="$s/pr.js" node tests/test_pr_workflow.mjs \| grep '^FAIL'` | `sequential fixers` |
| C5 | `k 's/more than 30 commits/more than 31 commits/'` | `FR-002 commits` |
| C6 | `k 's/more than 40 changed files/more than 41 changed files/'` | `FR-002 files` |
| C7 | `k 's#stratum:pr#stratum:x#'` | `FR-002 script` |
| C8 | `k '/Never start a second run while one runs/d'` | `L11 background`, `L11 in progress` |
| C9 | `k '/returns no .bodyPath./d'` | `L11 no result`, `L11 fallback` |
| C10 | `k '/stop before the gate. Nothing is pushed./d'` | `FR-006 blocked` |
| C11 | `w 's/Read only: do not edit, stage, commit, push or install anything, and do not run gh.//'` | `prompt rules` |

Each control gives exactly the FAIL lines in its row and no others. Then `rm -rf "$s"`.

C13 proves the FR-003 guard of section 1 counts a deleted bullet. It uses a scratch repo with the
scratch repo's first commit in place of `main`:

```bash
r=$(mktemp -d); git -C "$r" init -q; cp skills/st-pr/SKILL.md "$r/SKILL.md"
git -C "$r" add SKILL.md; git -C "$r" -c user.name=t -c user.email=t@t.invalid commit -qm base
sed -i '/^- Never skip the commit guard\./d' "$r/SKILL.md"
git -C "$r" diff --numstat "$(git -C "$r" rev-list --max-parents=0 HEAD)" -- SKILL.md | awk '{d+=$2} END {print d+0}'
rm -rf "$r"
```

Expected: `1`. (Run on 2026-10-23 against the current SKILL.md: `1`. The same command with
`main` on the real file printed `0`.)

## 3. Manual demos

Load the repo plugin, not the installed cache: start `claude --plugin-dir /home/hyuse/Desktop/stratum`
from the working directory each row names (M1 to M4: `/home/hyuse/Desktop/stratum`, on branch
`d8-workflow-by-name` for M3; the `stratum-22` worktree of the first build is gone).
Ultracode on means the latest system-reminder in the session says Ultracode is on. Answer
**Abort** at every gate, so nothing is pushed.

| ID | Steps | Expected |
|----|-------|----------|
| M1 | Ultracode on. On branch `22-workflow-scripts`, run `/stratum:st-pr main`. | One line `Path: current. Ultracode on, <c> commits (not more than 30), <f> files (not more than 40).` No workflow starts. The gate shows as before. (US2 scenario 1, SC-002) |
| M2 | Ultracode off. Run `/stratum:st-pr p1-lane-wording-test` (59 commits, 66 files on 2026-10-23, more after the build). | One line `Path: current. Ultracode off, ...`. No workflow starts. (US2 scenario 2) |
| M3 | Ultracode on. Run `/stratum:st-pr p1-lane-wording-test`. | One line `Path: workflow. Ultracode on, <c> commits (more than 30), <f> files (more than 40).` One workflow run with phases Facts, Draft, Verify, Fix, and `5 + ceil(<c> / 25) + 1 + 3` agents plus up to 3 fixers. The gate shows body, title, base, existing PR handling, warnings and the one question. Check the body by step 4 by hand: each named path exists at HEAD with its letter, each FR claim matches, each command exists. Zero edits needed. (US1 scenarios 1, 3, 5, SC-001) |
| M4 | Ultracode on. `git switch -c add-config`, then `printf 'GITHUB_TOKEN=ghp_%s\n' "$(openssl rand -hex 18)" > config.env && git add config.env && git commit -m 'add config'`. Run `/stratum:st-pr p1-lane-wording-test`. | The run stops after Facts. st-pr shows `blocking: <commit> config.env:1 <kind>`, does not show the gate, and pushes nothing. The token value is not in the output. Then `git switch 22-workflow-scripts`. Deleting `add-config` is your call. (US1 scenario 4, SC-003) |
| M5 | Working directory outside the plugin dir. `git -C /home/hyuse/Desktop/stratum worktree add -b m5-demo /home/hyuse/Desktop/stratum-m5 d8-workflow-by-name` (same commits, so still over the size rule against `p1-lane-wording-test`). `cd /home/hyuse/Desktop/stratum-m5`, start `claude --plugin-dir /home/hyuse/Desktop/stratum`, Ultracode on, run `/stratum:st-pr p1-lane-wording-test`. | One line `Path: workflow. ...`. The `Workflow({name: "stratum:pr", args})` call starts the run (D8). No current-path fallback line shows, and the gate shows as in M3. Removing the `stratum-m5` worktree and the `m5-demo` branch is your call. |

M4 run on 2026-10-24 from `/home/hyuse/Desktop/stratum` (the stratum-22 worktree was gone), branch
`add-config` off main, base `p1-lane-wording-test` (221 commits, 209 files), key line
`STRATUM_API_KEY=<64 hex>`: passed. Run `wf_249e8ff2-6fc`, the `scriptPath` call started it, 14
agents (Facts only), `blocked: true` with `blocking: <commit> config.env:1 secret: ...` for both
commits, no gate, no `pr-body.md`, nothing pushed, the value in neither the result nor the journal,
the snapshot the same before and after. Extra warning `unverified: facts:scan` (the scan read fewer
than 221 commits).

M3 run on 2026-10-24 from `/home/hyuse/Desktop/stratum`, branch `d8-workflow-by-name` at
1fc255d, base `p1-lane-wording-test` (221 commits, 208 files): passed. Run `wf_04c0a780-608`,
started by `Workflow({name: "stratum:pr"})` (the loaded script was byte-equal to
`workflows/pr.js`), 20 agents (14 Facts, 1 Draft, 3 Verify, 2 fixers), `blocked: false`, the gate
showed body, title, base, no existing PR and the warnings. Step 4 by hand: every named path exists
at HEAD with its letter, the counts (110 A, 98 M, +15459 / -741) and the 17 FRs match; zero edits.
The body flagged the stale M5 text in T004 (fixed in 692974b). Snapshot the same before and
after. Answered Abort, nothing pushed.

M5 run on 2026-10-24 from `/home/hyuse/Desktop/stratum-m5` (worktree branch `m5-demo-2` at
04f5c7e; `m5-demo` was taken by the first build), `claude --plugin-dir /home/hyuse/Desktop/stratum`,
base `p1-lane-wording-test` (223 commits, 208 files): passed. `Path: workflow.`, run
`wf_2f9cec96-88b` started by `Workflow({name: "stratum:pr"})`, 20 agents, 0 errors,
`blocked: false`, no current-path fallback line, the gate showed. Answered Abort: nothing pushed,
the worktree clean, `workflows/pr.js` unchanged.

M1 and M2 run on 2026-10-24 in `/home/hyuse/Desktop/stratum` on `d8-workflow-by-name`: passed.
M1, Ultracode on, base `main`: `Path: current. Ultracode on, 5 commits (not more than 30), 8 files
(not more than 40).`, no workflow; the gate was the real D8 PR, answered Approve (PR #50). M2,
Ultracode off, base `p1-lane-wording-test`: `Path: current. Ultracode off, 224 commits, 208 files.`,
no workflow; step 4 found open PR #50, answered Abort.
