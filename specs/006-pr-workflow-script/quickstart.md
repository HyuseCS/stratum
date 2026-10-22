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
git diff -U0 main -- skills/st-pr/SKILL.md | grep -c '^-[^-]'
git status --porcelain
```

Expected red states between tasks:

| After | Red | Green |
|-------|-----|-------|
| T001 | `node tests/test_pr_workflow.mjs` (`FAIL load`, the script does not exist), every row of `bash tests/test_pr_skill.sh` | `bash tests/test_inspect.sh` (README lines name files that exist) |
| T002 | every row of `bash tests/test_pr_skill.sh` | `node tests/test_pr_workflow.mjs`, all 15 cases |
| T003 | nothing | all of the above. The `grep -c` line prints `0` (no line of the old skill changed, FR-003, FR-010). `git status --porcelain` lists only the planned files |

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
| C7 | `k 's#workflows/pr.js#workflows/x.js#'` | `FR-002 script` |
| C8 | `k '/Never start a second run while one runs/d'` | `L11 background`, `L11 in progress` |
| C9 | `k '/returns no .bodyPath./d'` | `L11 no result`, `L11 fallback` |
| C10 | `k '/stop before the gate. Nothing is pushed./d'` | `FR-006 blocked` |

Each control gives exactly the FAIL lines in its row and no others. Then `rm -rf "$s"`.

## 3. Manual demos

Ultracode on means the latest system-reminder in the session says Ultracode is on. Answer
**Abort** at every gate, so nothing is pushed.

| ID | Steps | Expected |
|----|-------|----------|
| M1 | Ultracode on. On branch `22-workflow-scripts`, run `/stratum:st-pr main`. | One line `Path: current. Ultracode on, <c> commits (not more than 30), <f> files (not more than 40).` No workflow starts. The gate shows as before. (US2 scenario 1, SC-002) |
| M2 | Ultracode off. Run `/stratum:st-pr p1-lane-wording-test` (59 commits, 66 files on 2026-10-23, more after the build). | One line `Path: current. Ultracode off, ...`. No workflow starts. (US2 scenario 2) |
| M3 | Ultracode on. Run `/stratum:st-pr p1-lane-wording-test`. | One line `Path: workflow. Ultracode on, <c> commits (more than 30), <f> files (more than 40).` One workflow run with phases Facts, Draft, Verify, Fix, about 15 agents. The gate shows body, title, base, existing PR handling, warnings and the one question. Check the body by step 4 by hand: each named path exists at HEAD with its letter, each FR claim matches, each command exists. Zero edits needed. (US1 scenarios 1, 3, 5, SC-001) |
| M4 | Ultracode on. `git switch -c demo-secret`, then `printf 'token = ghp_%s\n' "$(openssl rand -hex 18)" > demo.txt && git add demo.txt && git commit -m 'demo secret'`. Run `/stratum:st-pr p1-lane-wording-test`. | The run stops after Facts. st-pr shows `blocking: <commit> demo.txt:1 <kind>`, does not show the gate, and pushes nothing. The token value is not in the output. Then `git switch 22-workflow-scripts`. Deleting `demo-secret` is your call. (US1 scenario 4, SC-003) |
