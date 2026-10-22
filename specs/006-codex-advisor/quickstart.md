# Quickstart: Codex Advisor

Run from the repo root `/home/hyuse/Desktop/stratum-18` (branch `18-codex-advisor`). Interfaces
and text: [contracts/advisor.md](contracts/advisor.md). Formats: [data-model.md](data-model.md).
Every scratch dir comes from `mktemp -d`. Set `PYTHONDONTWRITEBYTECODE=1` for every run
(lessons L8). The automated tests never run the real `codex`.

## 1. Automated tests

```bash
export PYTHONDONTWRITEBYTECODE=1
bash tests/test_advisor.sh
bash tests/test_on_demand.sh
bash tests/test_inspect.sh
bash tests/test_model_files.sh
bash tests/test_session_hooks.sh
bash tests/test_shortcuts.sh
bash tests/test_verify.sh
bash tests/test_statusline.sh
python3 -B tests/test_git_guard.py
python3 -B -m unittest tests/test_model_hook.py
python3 -B tests/test_phase_hook.py
node tests/test_token_weather.mjs
claude plugin validate .claude-plugin/plugin.json
git status --porcelain
```

Expected after the last build task: every line starts `ok`, unittest prints `OK`, each exits 0,
`claude plugin validate` passes, and `git status --porcelain` lists only the planned files (no
`advisor.md`, no `__pycache__`, nothing a test wrote).

Expected red states during the build. Do not "fix" them by editing a test:

| After | Red | Why |
|-------|-----|-----|
| T001 | every check in `tests/test_advisor.sh` except `no repo writes`, which passes early | `scripts/st-advisor.sh` does not exist |
| T003 | the US2 checks (`codex missing`, `codex error`, `empty answer` x2, `malformed answer`, `no verdict` x2, `bad finding`, `REVISE with no findings`, `timed out`, `timeout argv`, `bad args`) | failure mapping not built. A US2 check that T002's code already passes is named in the T003 report, with why |
| T005 | every `check` and `continued` check, including `diff stays fresh with an untracked record` and `untracked .env makes diff stale` | the two forms do not exist |
| T007 | `no mode file`, `mode both`, `mode off`, `mode off without codex`, `bad advisor.json` x12, `FR-014 model and effort from the file`, `FR-014 model only` | settings not read. `mode codex` passes early: T002 always runs Codex |
| T009 | every `#18` row and `#18 FR-016 old advisor text gone` in `tests/test_on_demand.sh`. `#18 FR-001 quick lane` passes early: st-quick has no advisor today | skill and README text not written |

## 2. Negative controls (each check can fail)

Run in T011. Method of feature 005: copy the whole repo without `.git`
(`rsync -a --exclude .git ./ <copy>/`, `<copy>` from `mktemp -d`). Baseline: run
`ST_ROOT=<copy> bash <copy>/tests/test_advisor.sh` and `ST_ROOT=<copy> bash <copy>/tests/test_on_demand.sh`
on the untouched copy and note the `FAIL` lines (the copy is not a git repo, so `no repo writes`
compares two equal errors and stays `ok`). Then, per control, take a fresh copy, make the one
change, run the same test, and expect exactly one more kind of `FAIL` than the baseline: the
named check. A control that adds no `FAIL` is a check that cannot fail: fix the check (lessons
L2, L10).

| ID | Change in the copy of `scripts/st-advisor.sh` | Red check |
|----|-----------------------------------------------|-----------|
| C1 | `-s read-only` to `-s workspace-write` | `FR-012 argv read-only`, `FR-012 script has no write flag` |
| C2 | always add `-m o3` after `exec` | `FR-014 no model or effort flag without keys` |
| C3 | remove the `':(exclude)<f>/advisor.md'` pathspec from the diff hash | `diff stays fresh after the record append` |
| C3b | remove the `':(exclude)<f>/advisor.md'` pathspec from the `git ls-files --others` line only | `diff stays fresh with an untracked record` |
| C4 | remove the untracked-file loop from the diff hash | `untracked file makes diff stale` |
| C5 | remove the `\n` to space step | `finding text cannot forge a record header` |
| C6 | `540` to `60` | `timeout argv` |
| C7 | map a missing `-o` file to `APPROVED` | `empty answer (no file)` |
| C7b | hash `plan.md` alone at the plan point | `check plan stale after a tasks.md change` and `plan APPROVED: exit 0, verdict line with the plan hash` |
| C8 | paste the bytes of `plan.md` into the plan prompt | `FR-009 plan prompt names paths, no plan text` |
| C9 | drop the `model` pattern check; then, in a second copy, change `re.fullmatch` to `re.match` with `^...$` for `model` | `bad advisor.json` (first: the `--dangerously-bypass-approvals-and-sandbox`, `a b` and `x\n` cases; second: the `x\n` case) |
| C10 | drop the `effort` pattern check; then, in a second copy, change `re.fullmatch` to `re.match` with `^...$` for `effort` | `bad advisor.json` (first: the `high\"x` and `high\n` cases; second: the `high\n` case) |
| C11 | stop leaving secret-looking paths out of the `Untracked files:` list | `diff point names full base and untracked files` |
| C12 | leave secret-looking paths out of the diff hash as well | `untracked .env makes diff stale` |
| C13 | delete the prompt line `Never quote a secret value in a finding.` | `FR-013 prompt: never quote a secret` |
| D1 | delete the line `Never run `codex` to build or fix.` from the copy of `skills/st-build/SKILL.md` | `#18 FR-012 review only` |

## 3. Live runs (real Codex)

Only L1 uses quota: one Codex call, about 37,000 tokens. Ask the user first. L2 reads the L1
record and calls no Codex. L3 runs logged out, L4 and L5 never start Codex: no quota.

This repo has no `.stratum/advisor.json`. For L1 to L3, write it as `{"mode": "codex"}` first,
and remove it after unless the user wants it committed.

- L1, plan point: `bash scripts/st-advisor.sh plan specs/006-codex-advisor` with a Bash timeout
  of 600000 ms. Expect exit 0 or 1, line 1 `APPROVED sha256 ...`, `REVISE sha256 ...` or
  `BLOCKED: ...`, finding lines in the contract format, and a new `## plan |` header at the end
  of `specs/006-codex-advisor/advisor.md`. Note the wall time.
- L2, stale check: `bash scripts/st-advisor.sh check plan specs/006-codex-advisor` prints the L1
  verdict and hash (of spec.md, plan.md and tasks.md joined), exit 0. Copy tasks.md aside,
  append one line to it, run the check again: `advisor approval is stale`, exit 1. Restore
  tasks.md from the copy and run the check again:
  exit 0.
- L3, logged out (no quota): `CODEX_HOME=$(mktemp -d) bash scripts/st-advisor.sh plan specs/006-codex-advisor`.
  Expect about 16 s, exit 1, `BLOCKED: ERROR: unexpected status 401 Unauthorized: ...` on one
  line, and a `## plan | ... | BLOCKED` record with a `reason:` line. Then
  `bash scripts/st-advisor.sh continued plan specs/006-codex-advisor`: `BLOCKED, user continued`.
- L4, mode off: in a scratch clone with `.stratum/advisor.json` set to `{"mode": "off"}`,
  `bash scripts/st-advisor.sh plan specs/006-codex-advisor` prints `no advisor: mode off`, exit 0,
  and writes no record.
- L5, no mode file: with no `.stratum/advisor.json`,
  `bash scripts/st-advisor.sh plan specs/006-codex-advisor` prints exactly
  `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".`,
  exit 0, and writes no record.
- After L1 to L3, remove `specs/006-codex-advisor/advisor.md` and `.stratum/advisor.json` unless the user wants them kept.
  Restore `tasks.md` if L2 left it changed.

## 4. By hand

- H1 (SC-001): in a Full-lane run of a small feature with Codex installed, the three points each
  print a verdict and leave a record with no human step. Count 3 of 3 in `advisor.md`.
- H3 (SC-002): with `codex` off PATH (for example `PATH` without `/usr/bin/codex` through a
  symlink dir, as in the test) and `.stratum/advisor.json` set to `{"mode": "codex"}`, dry-run a
  Full lane of a small feature. Every gate is the same as before this feature, and each of the
  three points adds one `no advisor: codex not found` line and no record.
- H2 (SC-006): read the README Advisor bullet alone and answer: what Codex reviews, when, what
  leaves the machine, how to turn it off.
