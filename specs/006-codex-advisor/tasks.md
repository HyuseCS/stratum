---

description: "Task list for Codex Advisor"
---

# Tasks: Codex Advisor

**Input**: Design documents from `/specs/006-codex-advisor/`

**Prerequisites**: plan.md, spec.md, decisions.md, research.md, data-model.md, contracts/advisor.md, quickstart.md

**Tests**: Required. Every FR has a check that fails before its build task. Expected red states
between tasks are in quickstart.md section 1. Do not edit a test to make it green.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum-18` (branch `18-codex-advisor`).

**Rules for every task**: no comments except `ponytail:` markers, minimal diff, no new
dependency, match the style of the file it copies. Keep every contract phrase whole on one line
(contracts/advisor.md rule P1). Do not edit `spec.md`, `decisions.md` or the checklists. Line
numbers are from `f0ac746`: find each line by its text. Run every test with
`PYTHONDONTWRITEBYTECODE=1`. Never run the real `codex` in a test: the tests put a fake `codex`
and a fake `timeout` first on PATH.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 to US4 from spec.md (US5 is covered by T001, T002, T009, T010)

## Phase 1: Setup

None. `scripts/`, `tests/` and `skills/` exist. codex-cli 0.163.0, GNU `timeout` 9.12, Python
3.14.8 and git 2.56.0 are installed (research header).

## Phase 2: Foundational

None. Each story adds its own checks to `tests/test_advisor.sh` and its own code to
`scripts/st-advisor.sh`, in order.

---

## Phase 3: User Story 1 - Codex reviews at the three advisor points (Priority: P1) MVP

**Goal**: `scripts/st-advisor.sh plan|test|diff` runs Codex review-only, maps a valid answer to a
verdict, prints it, and appends a record. Also covers the script side of US5 (read-only argv,
prompt rules).

**Independent Test**: `bash tests/test_advisor.sh` shows every US1 check `ok`.

### Tests for User Story 1

- [X] T001 [US1] Create `tests/test_advisor.sh` with the harness and the US1 checks, and add `bash tests/test_advisor.sh` to the README tests list (FR-001 script part, FR-003, FR-007, FR-009, FR-012, FR-013, FR-014, FR-017; lessons L1, L8).
  - Frame from `tests/test_verify.sh`: `set -u`, `root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"` (as `tests/test_on_demand.sh:3`), `tmp=$(mktemp -d)`, `trap 'rm -rf "$tmp"' EXIT`, `fail=0`, the same `check` helper, `exit $fail`.
  - Scratch project `$tmp/proj`: `git init -q`, commit (with `-c user.name=t -c user.email=t@t`) `specs/001-demo/spec.md`, `specs/001-demo/plan.md` (holds the token `PLANBODY7f3a`), `specs/001-demo/tasks.md`, `a.py`, and `.stratum/advisor.json` as `{"mode": "codex"}` (no file means off since D11, so every Codex case needs it). Run the script as `(cd "$proj" && bash "$root/scripts/st-advisor.sh" ...)`; capture stdout and exit code.
  - `$tmp/bin/codex` (fake, `chmod +x`): writes each argument on its own line to `$tmp/argv`, stdin to `$tmp/prompt`, copies the `--output-schema` file to `$tmp/schema.json`, prints `$FAKE_ERR` to stderr if set, copies `$tmp/answer` to the `-o` path if `$tmp/answer` exists, exits `${FAKE_RC:-0}`.
  - `$tmp/bin/timeout` (fake): writes its arguments one per line to `$tmp/timeout_argv`; if `FAKE_TIMEOUT` is set, exits 124; else `shift 3; exec "$@"`.
  - `PATH="$tmp/bin:$PATH"` for every run except the no-codex runs (T003, T007).
  - Checks (names exact, used by quickstart section 2):
    - `plan APPROVED: exit 0, verdict line with the plan hash`: answer `{"verdict":"APPROVED","summary":"fine","findings":[]}`. Exit 0, line 1 is `APPROVED sha256 <hash>`, where `<hash>` is `cat spec.md plan.md tasks.md | sha256sum` in `specs/001-demo` (D10).
    - `plan record header`: the last line of `specs/001-demo/advisor.md` that starts `## plan | ` matches `^## plan \| [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| sha256 <that hash> \| APPROVED$`.
    - `REVISE prints and records findings`: answer `REVISE` with two findings (`claim-one`/`ev-one`/`a.py:3`/`HIGH` and `claim-two`/`ev-two`/`a.py:9`/`LOW`). Exit 0, line 1 starts `REVISE sha256 `, stdout and `advisor.md` both hold `- [HIGH] a.py:3: claim-one Evidence: ev-one`.
    - `Codex BLOCKED: exit 1, reason is summary`: answer `BLOCKED`, summary `cannot-review`, no findings. Exit 1, line 1 is `BLOCKED: cannot-review`.
    - `FR-012 argv read-only`: in `$tmp/argv`, line 1 is `exec`, a line `-s` is followed by `read-only`, lines `--ephemeral`, `--output-schema`, `-o` exist, the last line is `-`.
    - `FR-012 script has no write flag`: `[ -f "$root/scripts/st-advisor.sh" ] && ! grep -qE -- 'workspace-write|danger-full-access|dangerously-bypass|approve-for-me|add-dir|full-auto|exec review' "$root/scripts/st-advisor.sh"` (the file test keeps it red while the script is missing).
    - `FR-014 no model or effort flag without keys`: with the harness file `{"mode": "codex"}` (no `model`, no `effort`), remove `$tmp/argv`, run `plan`, then `[ -f "$tmp/argv" ]` and no line of `$tmp/argv` is `-m`, `--model`, `-c`, `--config`, `-p`, `--profile` or `--oss`. The file test keeps the check from passing when Codex never ran.
    - `FR-003 schema`: `$tmp/schema.json` parses; `required` is `verdict`, `summary`, `findings`; the verdict enum is `APPROVED`, `REVISE`, `BLOCKED`; the finding `required` is `claim`, `evidence`, `location`, `severity` (read with `python3 -c`).
    - `FR-013 prompt rules`: `$tmp/prompt` holds the lines `You are a reviewer for Stratum. Review only: never create, change or delete a file, and never build or fix anything.` and `Read only the inputs named below and the files they cite. Never open .env files, keys, credentials, tokens or other secret files.` (contract section 4).
    - `FR-013 prompt: never quote a secret`: `$tmp/prompt` holds the line `Never quote a secret value in a finding.` (D12).
    - `FR-009 plan prompt names paths, no plan text`: `$tmp/prompt` holds `Inputs: specs/001-demo/spec.md, specs/001-demo/plan.md, specs/001-demo/tasks.md` and not `PLANBODY7f3a`.
    - `test point pastes task, test path and both outputs`: task file `TASKTEXT1`, failure files `FAILONE1` and `FAILTWO2` in `$tmp`, test path `tests/x_test.sh`. `$tmp/prompt` holds `Point: test.`, `Test: tests/x_test.sh`, and all three tokens.
    - `test point hash is both outputs`: line 1 is `APPROVED sha256 <sha256sum of the two failure files concatenated>`, and the last header in `advisor.md` starts `## test | `.
    - `diff point names full base and untracked files`: commit one more change, pass the first commit as a short SHA (`git rev-parse --short`), create untracked `new file.txt`, `.env`, `sub/k.pem`, `c.key`, `c.p12` and `c.pfx`. `$tmp/prompt` holds the full 40-character SHA and a line `new file.txt` after the line `Untracked files:`, and none of `.env`, `sub/k.pem`, `c.key`, `c.p12`, `c.pfx` (D12); the last header starts `## diff | `. After the check, remove `new file.txt`, `.env`, `sub/` (with `k.pem`), `c.key`, `c.p12` and `c.pfx` from `$proj`, so T005's `.env` and untracked checks start clean.
    - `no repo writes`: `git -C "$root" status --porcelain` is the same at the end as at the start.
  - `README.md` Tests block: add `bash tests/test_advisor.sh` before `bash tests/test_model_files.sh` (keeps `tests/test_inspect.sh` "README tests" green).
  - Run it: every check is red (no script yet) except `no repo writes`, which passes early. Run `bash tests/test_inspect.sh`: all `ok`.

### Implementation for User Story 1

- [X] T002 [US1] Create `scripts/st-advisor.sh` with the `plan`, `test` and `diff` forms for a valid answer (FR-001, FR-003, FR-007, FR-009, FR-012, FR-013). No `-m` or `-c` yet (T008 adds them from the file). Security: plan.md S1 (OpenAI), S2 (read-only), S3 (untrusted answer and arguments).
  - Frame from `scripts/st-verify.sh`: `#!/usr/bin/env bash`, one-line results. Inline `python3 - <<'PY'` as in `hooks/st-handoff-facts.sh:8`, reading files with `open(p, "rb")` and `json.loads` (lessons L3).
  - Arguments, hash input, Codex call, schema, prompt, output and record: exactly contracts/advisor.md sections 1 to 6 and data-model.md. Codex call: `timeout -k 10 540 codex exec -s read-only --ephemeral --output-schema <tmp>/schema.json -o <tmp>/answer.json -`, stdin from the prompt file, stdout and stderr to temp files, temp dir removed on exit.
  - Diff hash input: `git diff <sha> -- . ':(exclude)<f>/advisor.md'`, then `git diff --no-index -- /dev/null <path>` for each path of `git ls-files -z --others --exclude-standard -- . ':(exclude)<f>/advisor.md'` (research R6). Every Codex text has `\r` and `\n` replaced by a space before print or record.
  - This task builds only what T001 checks. Mode reading, failure mapping, `check` and `continued` come in T004, T006, T008.
  - Run `bash tests/test_advisor.sh`: all `ok`.

**Checkpoint**: US1 works alone. A fake `codex` gives a verdict and a record at each point.

---

## Phase 4: User Story 2 - The flow keeps working without Codex (Priority: P1)

**Goal**: no `codex` is one `no advisor` line and exit 0. Every failed, empty, malformed or late
answer is a one-line `BLOCKED: <reason>` with exit 1 and a record, never approval.

**Independent Test**: `bash tests/test_advisor.sh` shows every US2 check `ok`.

### Tests for User Story 2

- [X] T003 [US2] Add the US2 checks to `tests/test_advisor.sh` (FR-004, FR-011, SC-003, spec Edge Cases; lessons L1, L11).
  - `$tmp/sys`: a symlink to every command on the current PATH except `codex` (loop over the PATH dirs, first name wins). Runs that need no codex use `PATH="$tmp/sys"`.
  - Checks (each BLOCKED check also asserts exit 1, line 1 starts `BLOCKED: `, and no `APPROVED` anywhere in stdout):
    - `codex missing: no advisor, exit 0, no record`: stdout is exactly `no advisor: codex not found`, exit 0, the number of `## ` lines in `advisor.md` is unchanged.
    - `codex error: BLOCKED with its ERROR line`: `FAKE_RC=1`, `FAKE_ERR=$'warning: retry\nERROR: unexpected status 401 Unauthorized: test-401\n'`, no answer file. Line 1 is `BLOCKED: ERROR: unexpected status 401 Unauthorized: test-401`; the new header ends `| BLOCKED` and the next line starts `reason: `.
    - `empty answer (no file)`: exit 0, no answer file. `BLOCKED: empty answer`.
    - `empty answer (empty file)`: answer is three spaces and a newline. `BLOCKED: empty answer`.
    - `malformed answer`: answer `not json`. `BLOCKED: malformed answer`.
    - `no verdict (missing)`: `{"summary":"s","findings":[{"claim":"c","evidence":"e","location":"l","severity":"LOW"}]}`. `BLOCKED: no verdict`.
    - `no verdict (unknown)`: verdict `OK`. `BLOCKED: no verdict`.
    - `bad finding`: `REVISE` with a finding that has no `evidence`. `BLOCKED: malformed answer`.
    - `REVISE with no findings`: `BLOCKED: REVISE with no findings`.
    - `timed out`: `FAKE_TIMEOUT=1`. `BLOCKED: timed out`.
    - `timeout argv`: lines 1 to 4 of `$tmp/timeout_argv` are `-k`, `10`, `540`, `codex`.
    - `bad args: exit 2, no record`: `plan` with no dir, `plan specs/none`, `plan` on a feature dir with `spec.md` and `plan.md` but no `tasks.md`, `diff specs/001-demo notacommit`, and `test` with a missing failure file. Each exits 2, line 1 starts `usage: st-advisor.sh`, `$tmp/argv` (removed before) is not written, the `## ` count is unchanged.
  - Run it: the US2 checks are red, US1 stays `ok`. Name in the report any US2 check that T002's code already passes, with why.

### Implementation for User Story 2

- [X] T004 [US2] In `scripts/st-advisor.sh`, add the no-codex line and the answer mapping of data-model.md "Advisor answer" rows 1 to 7, in that order, with the reasons of contracts/advisor.md section 5 (FR-004, FR-011). A `BLOCKED` the script sets writes a record with a `reason:` line. The Codex error reason is the last stderr line that starts `ERROR:`, else `codex exited <rc>` (D16) (research R2). Run `bash tests/test_advisor.sh`: all `ok`.

**Checkpoint**: US1 and US2 work. No path gives a silent approval.

---

## Phase 5: User Story 3 - Approval is tied to what was reviewed (Priority: P2)

**Goal**: `check plan|diff` reports the latest record's verdict when the input is unchanged and
`advisor approval is stale` when it changed. `continued` records the user's choice.

**Independent Test**: `bash tests/test_advisor.sh` shows every US3 check `ok`.

### Tests for User Story 3

- [X] T005 [US3] Add the US3 checks to `tests/test_advisor.sh` (FR-006 record, FR-008, SC-004; lessons L4, L5).
  - `check plan fresh`: after a plan `APPROVED` run, `check plan specs/001-demo` prints `APPROVED sha256 <plan hash>` (`cat spec.md plan.md tasks.md | sha256sum`), exit 0.
  - `check plan stale after a one-line change`: append one line to `plan.md`. `advisor approval is stale`, exit 1.
  - `check plan stale after a tasks.md change`: run `plan` again (fresh), then append one line to `tasks.md` alone. `advisor approval is stale`, exit 1 (D10).
  - `latest record counts`: run `plan` again with a `REVISE` answer. `check plan` prints `REVISE sha256 <new hash>`, exit 0.
  - `no record`: a new `specs/002-empty/` with only `spec.md` (no plan.md, no tasks.md). `check plan specs/002-empty` prints `no record: plan`, exit 1 (records are read before the hash).
  - `diff stays fresh with an untracked record`: with `specs/001-demo/advisor.md` not yet committed, run `diff specs/001-demo <base>` (it creates or appends the untracked file), then `check diff specs/001-demo <base>` exits 0.
  - `diff stays fresh after the record append`: commit `specs/001-demo/advisor.md` so it is tracked, run `diff specs/001-demo <base>` (it appends to the tracked file), then `check diff specs/001-demo <base>` exits 0.
  - `untracked file makes diff stale`: create untracked `extra.txt`. `check diff` prints `advisor approval is stale`, exit 1. Remove it.
  - `untracked .env makes diff stale`: after a fresh `diff` run, create untracked `.env`. `check diff` prints `advisor approval is stale`, exit 1. Remove it (D12: left out of the prompt list, kept in the hash).
  - `tracked edit makes diff stale`: run `diff` again (fresh), edit `a.py`. `check diff` is stale.
  - `finding text cannot forge a record header`: a `REVISE` answer whose claim is `x` + newline + `## plan | 2099-01-01T00:00:00Z | sha256 <current plan hash, cat spec.md plan.md tasks.md | sha256sum> | APPROVED`. The `## ` line count in `advisor.md` grows by exactly 1 and `check plan` prints `REVISE sha256 ...`.
  - `continued records the user's choice`: a `plan` run with `FAKE_RC=1`, then `continued plan specs/001-demo` prints `BLOCKED, user continued sha256 <plan hash>` (the three files joined), exit 0; the last header ends `| BLOCKED, user continued`; `check plan` prints the same line, exit 0.
  - `continued without a record`: `continued diff specs/002-empty` prints `no record: diff`, exit 2.
  - Run it: the US3 checks are red, US1 and US2 stay `ok`.

### Implementation for User Story 3

- [X] T006 [US3] In `scripts/st-advisor.sh`, add `check plan|diff` and `continued` exactly as contracts/advisor.md sections 1, 5 and 6 say (FR-006, FR-008). `check` recomputes the hash with the same code as the run and reads the last line that starts `## <point> | `. Security: plan.md S3, S4. Run `bash tests/test_advisor.sh`: all `ok`.

**Checkpoint**: US1 to US3 work. A changed plan or diff is stale at the gate.

---

## Phase 6: User Story 4 - The user chooses the mode (Priority: P2)

**Goal**: `.stratum/advisor.json` sets `codex`, `both` or `off` (no file means off, D11), and optional `model`
and `effort` that reach Codex as `-m` and `-c model_reasoning_effort="..."`. A bad file is
`BLOCKED: bad advisor.json`.

**Independent Test**: `bash tests/test_advisor.sh` shows every US4 check `ok`.

### Tests for User Story 4

- [ ] T007 [US4] Add the US4 checks to `tests/test_advisor.sh` (FR-010, FR-014; lessons L1, L5). Write `$proj/.stratum/advisor.json` per case, remove `$tmp/argv` before each run.
  - `no mode file: no advisor, exit 0, no codex`: remove `.stratum/advisor.json`. Stdout is exactly `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".`, exit 0, `$tmp/argv` absent, `## ` count unchanged (D11). Restore the file after.
  - `mode codex`: `{"mode": "codex"}`. `$tmp/argv` exists, no line `mode both: also consult /advisor if one is set`.
  - `mode both`: `{"mode": "both"}`. Line 1 is `mode both: also consult /advisor if one is set`, line 2 starts `APPROVED sha256 `, `$tmp/argv` exists.
  - `mode off`: `{"mode": "off"}`. Stdout is exactly `no advisor: mode off`, exit 0, `$tmp/argv` absent, `## ` count unchanged.
  - `mode off without codex`: same with `PATH="$tmp/sys"`. `no advisor: mode off`.
  - `bad advisor.json`: each of `{`, `{"mode": "x"}`, `[]`, `{"mode": 1}`, `{"mode": "codex", "modle": "x"}`, `{"model": "gpt-test-1"}` (no mode), `{"mode": "codex", "model": "--dangerously-bypass-approvals-and-sandbox"}`, `{"mode": "codex", "model": "a b"}`, `{"mode": "codex", "model": "x\n"}`, `{"mode": "codex", "effort": "high\"x"}`, `{"mode": "codex", "effort": "high\n"}`, `{"mode": "codex", "effort": 3}`. The `\n` is a JSON escape, so the value ends in a real newline. Line 1 `BLOCKED: bad advisor.json`, exit 1, `$tmp/argv` absent, the new header ends `| BLOCKED`.
  - `FR-014 model and effort from the file`: `{"mode": "codex", "model": "gpt-test-1", "effort": "high"}`. In `$tmp/argv` a line `-m` is followed by `gpt-test-1`, a line `-c` is followed by `model_reasoning_effort="high"`, and `-s` is still followed by `read-only`.
  - `FR-014 model only`: `{"mode": "codex", "model": "gpt-test-1"}`. `-m` then `gpt-test-1` present, no line `-c`, Codex runs.
  - Run it: `no mode file`, `mode both`, `mode off`, `mode off without codex`, the twelve `bad advisor.json` cases and both `FR-014` file cases are red. `mode codex` passes early (T002 always runs Codex).

### Implementation for User Story 4

- [X] T008 [US4] In `scripts/st-advisor.sh`, read `.stratum/advisor.json` as contracts/advisor.md sections 2 (step 3) and 3 and data-model.md "Advisor settings" say: no file prints `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".`, exit 0, no record, no Codex call (D11); allowed keys `mode`, `model`, `effort`; `mode` required, in `codex`, `both`, `off`; `model` passes Python `re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}", v)`; `effort` passes `re.fullmatch(r"[a-z]{1,16}", v)` (fullmatch, not `re.match` with `$`, which lets a trailing newline through); anything else is `BLOCKED: bad advisor.json`; read as bytes. Add `-m <model>` and the single argv element `-c` `model_reasoning_effort="<effort>"` after `-s read-only` only when the keys are set (FR-010, FR-014; lessons L3, L5). Security: plan.md S3 (a committed file sets the mode, model and effort; the patterns stop a flag or TOML in a value). Run `bash tests/test_advisor.sh`: all `ok`.

**Checkpoint**: the script is complete. `bash tests/test_advisor.sh` is all `ok`.

---

## Phase 7: Skill and README text (all stories)

**Goal**: the orchestrator calls the advisor at the three points, waits, and handles each verdict;
`st-init` asks for the mode; the README says what Codex reviews, when, what leaves the machine,
and how to turn it off (FR-001, FR-002, FR-005, FR-006, FR-015, FR-016, SC-006).

**Independent Test**: `bash tests/test_on_demand.sh` shows every `#18` check `ok`;
`bash tests/test_inspect.sh` stays `ok`.

- [X] T009 Add the `#18` checks to `tests/test_on_demand.sh` (FR-001, FR-002, FR-005, FR-006, FR-007, FR-008, FR-010, FR-011, FR-012, FR-014, FR-015, FR-016; lessons L1, L6, L11). Before `exit $fail`, add one `phrases <<'EOF'` heredoc with every row of contracts/advisor.md section 8, in table order, each `name<TAB>target<TAB>phrase` (the phrase is the cell text inside its outer backticks, no space at either end). Add the two `check` lines of section 8 (`#18 FR-001 quick lane`, `#18 FR-016 old advisor text gone`). Run it: every `#18` row and `#18 FR-016 old advisor text gone` are red; `#18 FR-001 quick lane` passes (st-quick has no advisor today). Name both in the report.
- [X] T010 Edit `skills/st-build/SKILL.md`, `skills/st-inspect/SKILL.md`, `skills/st-fast/SKILL.md`, `skills/st-init/SKILL.md` and `README.md` with the text of contracts/advisor.md section 7, in one task (one test file reads all five, lessons L6). Security: plan.md S1 (README states what goes to OpenAI and the off switch). Do not add the optional D15 sentence of section 7.5: T011 adds it only if its probe says so. Keep `big ones go to the user before the gate` whole in `skills/st-inspect/SKILL.md` (`tests/test_inspect.sh:79`), `asks for the git guard modes and any model overrides` whole in `README.md` (`tests/test_inspect.sh:143`) and `git rev-parse HEAD` in `skills/st-fast/SKILL.md` (`tests/test_shortcuts.sh:100`). Run `bash tests/test_on_demand.sh`, `bash tests/test_inspect.sh`, `bash tests/test_model_files.sh`, `bash tests/test_shortcuts.sh`, `bash tests/test_verify.sh`: all `ok`.

**Checkpoint**: all stories wired. quickstart section 1 is all `ok`.

---

## Phase 8: Polish and checks Inspect would run

- [ ] T011 Negative controls and full run (lessons L2, L8, L10). Run quickstart.md section 2: the baseline, then C1 to C13, C3b, C7b and D1, each in a fresh scratch copy, each must add exactly its named `FAIL` lines to the baseline. A control with 0 `FAIL` lines is a check that cannot fail: fix the check in `tests/test_advisor.sh` or `tests/test_on_demand.sh` and run again. Then run quickstart.md section 1 in full, including `claude plugin validate .claude-plugin/plugin.json` and the final `git status --porcelain` (no file a test wrote). Then ask the user before quickstart.md section 3 row L1, the only row that uses quota (one real Codex call, about 37,000 tokens; L2 reads the L1 record and calls no Codex), run L3, L4 and L5 (no quota), and record each result with its output and the L1 wall time. Remove `specs/006-codex-advisor/advisor.md` and `.stratum/advisor.json` after the live runs unless the user wants them kept.
  - Project config probe (D15, plan.md S3; no quota): in a `mktemp -d` scratch repo (`git init -q`), commit `.codex/config.toml` holding `model = "probe-model-x"`. From that repo run `CODEX_HOME=$(mktemp -d) codex exec -s read-only --ephemeral - <<<'ping'` (logged out, as research call 6), and read the `model:` line in the stderr header. Report the line. If it shows `probe-model-x`, add the optional sentence of contracts/advisor.md section 7.5 to the README Advisor bullet, add its phrase row (`#18 D15 readme`) to `tests/test_on_demand.sh`, and re-run `bash tests/test_on_demand.sh` and `bash tests/test_inspect.sh`: all `ok`. If not, change nothing and say so in the report.

---

## Dependencies & Execution Order

### Phase Dependencies

- No setup or foundational phase.
- US1 (T001, T002), then US2 (T003, T004), US3 (T005, T006), US4 (T007, T008), then the text
  (T009, T010), then T011.

### User Story Dependencies

- US2, US3 and US4 add to the script and the test file US1 creates, so each starts after the one
  before it.
- T009 and T010 read no script output; they could run after T002. They wait so the README names a
  script that is complete (`tests/test_inspect.sh` "README paths" needs `scripts/st-advisor.sh` to
  exist).
- Within each story the test task comes first and must be red before its build task.

### Parallel Opportunities

- None. T001 to T008 share `tests/test_advisor.sh` and `scripts/st-advisor.sh`. T009 and T010
  share `tests/test_on_demand.sh` and each must make the whole file green (lessons L6). No task
  is `[P]`.

## Parallel Example

None (see above).

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001, T002.
2. Stop: the script answers at all three points with a fake `codex`.
3. Commit per task with `st-git`.

### Incremental Delivery

1. US1: the three points with a valid answer.
2. US2: no codex and every failure path.
3. US3: stale check and `continued`.
4. US4: modes.
5. T009, T010: the orchestrator uses it. Only after T010 does a Stratum run call Codex.
6. T011 before the feature is called done.

## Notes

- One commit per task, exact paths, through `st-git`.
- No version bump in this feature.
- The automated checks prove the script with a fake `codex` and the skill text. Only quickstart
  section 3 (L1, L2) and section 4 (H1, H2) prove a real Codex run and the orchestrator's
  behavior.
- `spec.md` FR-007 already carries the plan and diff inputs (D9, D10). A later change to either input updates spec, research, data model and contract in the same commit (lessons L13).
