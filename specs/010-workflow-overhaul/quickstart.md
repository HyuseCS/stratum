# Quickstart: Workflow Overhaul

Run every command from the repo root. Each section names its scoped tests. No section runs all
of `tests/`. Interfaces: `contracts/scripts.md`. Text: `contracts/phrases.md`.

## 0. Prerequisites

- `bash`, `python3`, `git`, `jq`. For sections 3L and 4L: `herdr` 0.9.4 and a herdr pane
  (`HERDR_ENV=1`), `codex` logged in, `claude` 2.1.312 or later.
- Python tests run with `PYTHONDONTWRITEBYTECODE=1` (L8).

## 1. US1: fewer advisor runs, scoped tests

```bash
bash tests/test_advisor_waive.sh
bash tests/test_advisor_rules.sh
bash tests/test_test_scope.sh
bash tests/test_advisor.sh
bash tests/test_on_demand.sh
```

Expected: every line `ok`, exit 0. Hand check in a scratch clone with a feature dir that has
`spec.md`, `plan.md`, `tasks.md`:

1. `bash scripts/st-advisor.sh waive plan specs/<f> "fix-only change"` prints `WAIVED sha256 <h>`
   and `reason: fix-only change`. `codex` was not called.
2. `bash scripts/st-advisor.sh check plan specs/<f>` prints `WAIVED sha256 <h>`, exit 0.
3. Change `tasks.md`, run step 2 again: `advisor approval is stale`, exit 1.
4. `bash scripts/st-advisor.sh count specs/<f>` prints `advisor calls: codex <a>, waived 1, /advisor <c>`.
5. `bash scripts/st-advisor.sh diff specs/<f> HEAD` prints `no change since HEAD: skip`.

## 2. US2: git guard and test lock

```bash
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py
bash tests/test_lock.sh
bash tests/test_lock_rules.sh
bash tests/test_st_worker.sh
```

Hand check (two terminals, in this repo):

1. Terminal A: `bash scripts/st-lock.sh -- sleep 20`.
2. Terminal B: `bash scripts/st-lock.sh -- echo second`. It prints `lock: waiting for test (pid <A>)`
   and `second` after A ends.
3. Terminal A again: `bash scripts/st-lock.sh -- sleep 20`. Terminal B:
   `bash scripts/st-lock.sh --timeout 3 -- echo never`. After 3 s it prints
   `lock: waited 3 s for test; held by pid <A> since <time>; ran nothing`, exit 75, and no `never`.
4. Terminal A: `bash scripts/st-lock.sh -- sleep 60`, then `kill -9` that `st-lock.sh` pid.
   Terminal B: `bash scripts/st-lock.sh -- echo freed` prints `freed` at once.

## 3. US3: risk and advisor matrix

```bash
bash tests/test_advisor_matrix.sh
bash tests/test_codex_agent.sh
bash tests/test_risk_rules.sh
bash tests/test_advisor.sh
bash tests/test_design_lane.sh
bash tests/test_on_demand.sh
```

### 3L. Live Codex tab review (T024)

In a herdr pane, in a scratch clone with `.stratum/advisor.json` = `{"mode": "auto"}` and
`.stratum/state.json` `risk` = `normal`:

1. `bash scripts/st-advisor.sh plan specs/<f>`. Expect: first line
   `advisors: codex (plan, risk normal)`, a new tab `Codex` in this workspace with agent
   `st-codex-<NNN>`, a verdict line, a record in `specs/<f>/advisor.md`.
2. Run it again: no second tab, the same agent.
3. Close the `Codex` tab by hand and run it again: a new tab and agent.
4. Set `risk` to `low`: `advisors: none (plan, risk low)`, no Codex call.

Record in research.md: the time, the number of answer lines read, and whether the JSON parsed.

## 4. US4: workers and autonomous build mode

```bash
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_approve_hook.py
bash tests/test_st_worker.sh
bash tests/test_statusline.sh
bash tests/test_worker_rules.sh
bash tests/test_on_demand.sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_phase_hook.py
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_model_hook.py
```

### 4L. Live worker run (T034)

In a herdr pane in this repo, on a scratch branch, with a one-line task file:

1. `printf '%s\n' "$CLAUDE_CODE_SESSION_ID" > .stratum/autonomous`.
2. `bash scripts/st-worker.sh start t990 --task <file> --test "grep -qx ok demo/ok.txt && echo PASS" --lane "plain edit, no lane" --roster <roster> --autonomous`.
   Expect: workspace `worker-t990` with tabs Main (agent and lazygit), Dev Servers, VM, and the
   folder `<worktree>/.stratum/approve/`.
   The task file says: "Run this one Bash command exactly as written, then write
   `demo/ok.txt` with the line `ok` and commit it. Owns: `demo/n.txt`, `demo/ok.txt`." The command is a heredoc with a stray quote
   and a git commit, which the guard asks for (US2 fallback, folder unknown):

   ```text
   mkdir -p demo && cat > demo/n.txt <<'EOF'
   it's a test
   EOF
   git add demo/n.txt && git commit -m "demo heredoc"
   ```
3. `bash scripts/st-worker.sh wait t990` prints `state approval`, a `request` id, the tab line,
   the input, `branch\tworker-t990` and `staged\tdemo/n.txt` (D23: own branch, owned file).
4. `bash scripts/st-worker.sh approve t990 --request <rid> --record <scratch>/approvals.txt`:
   the dialog closes, the worker goes on, the record has one line.
5. Start a second worker the same way (`t991`) and `pass` its request: the dialog stays for
   you in its Main tab, and `t990` keeps running.
6. Wait more than 120 s before one `approve` and note whether the hook still answers.
7. `rm -f .stratum/autonomous`, then `approve` again: `Autonomous build mode is off for this session.`
8. `close t990`: `.stratum/approve/` is gone.

Record each step's output in research.md (L32).

## 5. US5: plan and screen rules

```bash
bash tests/test_plan_rules.sh
bash tests/test_screen_rules.sh
bash tests/test_inspect.sh
```

## 6. US6: triage, no issue offer, no st-frontend-design

```bash
bash tests/test_triage_rules.sh
bash tests/test_no_frontend_design.sh
bash tests/test_inspect.sh
bash tests/test_design_lane.sh
```

Hand check: `git grep -n frontend-design -- ':!specs'` prints only lines of
`tests/test_no_frontend_design.sh`.

## 7. Whole feature

```bash
bash tests/test_lane_steps.sh
```

Then the negative-control run of T047: every new test file is red on the tree at `6fe9d60`.
