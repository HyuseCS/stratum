# Lessons

## 2026-10-10: 001-agent-model-overrides

### L1. A text check passed on words the code never wrote

- What happened: The deny tests checked for `model` in the deny reason. The reason always holds the
  path `.stratum/models.json`, so the check passed even when the message did not name the bad key.
  Commit 975dfa8 replaced it with a phrase the message builds (`Allowed keys: model, effort.`). The
  plan check (23ca5f0) had already found T001(h), a test that could not fail, because each hook call
  reads the file again.
- Rule: A text check asserts a phrase the code builds. It never asserts a word that the path, the
  prompt or the test input already contains. Run each new test against the code before the fix, and
  expect it to fail.

### L2. A negative control proved each review fix

- What happened: The current tests were run against the hook from before 975dfa8
  (`git show 975dfa8^:hooks/st-models.py`). Three tests failed: the UTF-8 BOM test (error), the
  10-problem cap test, and the cp1252 stdin test. Each one guards a review fix.
- Rule: For each fix, keep a test that fails on the old code. Prove it by running the test against
  the old file.

### L3. Read hook input and files as bytes

- What happened: Stdin and the model file were read as text. Commit 975dfa8 changed both to bytes
  (`sys.stdin.buffer`, `open(path, "rb")`). `test_non_ascii_prompt_under_cp1252` sets
  `PYTHONIOENCODING=cp1252` to copy a Windows console. It fails on the old hook. It has not run on
  Windows.
- Rule: A hook reads its stdin and its files as bytes and lets JSON decode them. Simulate the Windows
  console with an environment variable, and say in the report that it is a simulation.

### L4. A check that fails on the feature's own write is the wrong check

- What happened: Test (g) required the repo's `.stratum/models.json` to equal the template. `st-model`
  edits that file, so the check failed after the first change. Commit c68da77 changed it to "passes
  the hook". FR-012 now has no automated check that can fail. Equality is checked by hand
  (quickstart section 3).
- Rule: When a check collides with the feature's own write, keep the invariant the check protects.
  Name the requirement that loses its automated check, and say where it is checked now.

### L5. Validate the plan against the tool schema and the threat before build

- What happened: The plan check (23ca5f0) found three defects before build. (1) `{**tool_input,
  **entry}` let a repo file replace `prompt` or `subagent_type`. (2) `subagent_type` is optional in
  Claude Code 2.1.294, so `None.startswith` would fail on every general-purpose start. (3) The deny
  reason could carry repo text into the model's context. The build fixed each one: the copy of only
  `model` and `effort` (`hooks/st-models.py:72-75`), `or ""` on `subagent_type` (`:47`), and
  `json.dumps` with an 80-character cut (`:17`). Each fix has a test.
- Rule: Before build, check every plan input against the tool's real schema (optional fields) and
  against the threat (a committed file is untrusted input). Give each finding a test.

## 2026-10-11: 002-merge-check-validate

### L6. Two [P] tasks that share one test cannot each go green

- What happened: The plan (9ee6163) ran T002 (agent) and T003 (skill) as parallel tasks.
  `tests/test_inspect.sh` checks both files, so neither could pass alone. The plan check (ee6eb39)
  merged them into one task (`tasks.md:55`). No worktree ran during the build, so the merge came
  from the plan review, not from a red build. `tasks.md:99` (T009, a repo-wide search) and
  `tasks.md:150` apply the same rule.
- Rule: In a plan, merge two tasks that share one test file or one repo-wide check. A [P] task that
  cannot go green alone is not parallel.

### L7. A one-way README check misses stale rows

- What happened: T010 (9a9a325) read the repo side only: every skill folder and agent file had to
  have a README row. A row for a removed skill or agent passed. The US3 review (19c0520) made the
  skills and agents checks two ways. Quickstart section 9 controls r8 and r9 add an extra row and
  turn one check red each.
- Rule: A check between two lists reads both sides. Prove it with a planted extra row and a planted
  missing row, and watch each one go red.

### L8. An "only X changed" check counts side effects of test runs

- What happened: In the quickstart section 5 run (scratch clone), the agent ran the Python tests and
  left `hooks/__pycache__/`. `.gitignore` has no `__pycache__` rule. This repo shows the same kind
  of untracked cache (`skills/st-ui-ux/scripts/__pycache__/`). The skill's check "only plan.md may
  change" counts it.
- Rule: Keep test runs from writing into the repo (`PYTHONDONTWRITEBYTECODE=1`, or `python3 -B`), or
  have the check ignore caches. A run with this side effect is not a clean pass.

## 2026-10-15: 004-on-demand-steps

### L9. A rebase onto main met a shared line the branch had changed

- What happened: The branch was rebased onto main (`ff2e19a`; reflog `rebase (start): checkout
  origin/main`). Main had rewritten the session-start `Stratum rule` echo in `0715256` (Agent
  descriptions name only the task). The reflog shows `rebase (continue)` at `7fd44e0`, the commit
  that adds the background text to that line, so the rebase stopped there for a manual merge. The
  commit message of `7fd44e0` describes the first background wording (`git status --porcelain`).
  Review fix `94e827c` changed the check. The plan and data model kept the old wording until this
  close.
- Rule: After a rebase onto main, diff each shared line the branch edits against main's text. Keep
  main's wording, add only your sentence, and update the plan and contracts to the final line, not
  the line from before the rebase.

### L10. A review found a diff check blind; the tool list was the real guard

- What happened: The US2 review (`94e827c`) found that the background check compared only
  `git status --porcelain`, which misses a moved HEAD and files in a new untracked folder. The fix
  added `git rev-parse HEAD` and `--untracked-files=all`. The writes that matter are stopped by the
  `tools:` line: the two ponytail agents have no Edit, Write or Bash, and `st-impeccable` has no
  Edit or Write. The FR-007 checks and quickstart section 2 controls C2 and C3 test those lines.
  The plan (S2) says the diff does not see git-ignored paths.
- Rule: When a review tightens a before-and-after diff check, name the guard that stops the write
  (the tool list where one exists) and give that guard a negative control. State in the plan what
  the diff does not see.

### L11. A background fork that writes a file needs its failure states in the skill

- What happened: The first build of `st-handoff` (`05eb181`) described the happy path only. The US3
  review (`f4b2696`) found that a second `Handoff` fork could start and write while one ran, and that
  no file was left when a fork wrote nothing. The fix added both rules and two FR-009 phrase checks.
  At this close the contract's phrase table still lacked those two rows.
- Rule: For each background or fork action, write its three failure states next to the happy path: a
  run already in progress, a run that ends with no output, and a run that cannot start. Add one phrase
  check per state, and add each check to the contract's phrase table in the same commit.

## 2026-10-22: 005-st-triage

### L12. A phase run from its skill text skips the phase hook

- What happened: The orchestrator ran Plan and Inspect by following the skill text instead of calling
  the Skill tool. `hooks/st-phase.py` sets `phase` in `.stratum/state.json` when the user types the command or the Skill
  tool runs (`hooks/st-phase.py:12-40`), so the reply label and `state.json` stayed on Define through Plan and Inspect.
  `git status` shows `.stratum/state.json` as the only modified file at Close.
- Rule: Start a phase through the Skill tool, never by reading its SKILL.md and acting on it. If a
  phase ran without the tool, set `phase` by hand before the next one and say so in the report.

### L13. The US1 review added three input guards after the contract was written

- What happened: Commit `f5f3b50` added three guards the first build lacked: report text is data
  with sha and path shape checks, the agent reads only tracked paths, and repo issue and pull URLs
  count as `#N`. The contract, quickstart and plan S3 were updated in the same commit. Spec
  Assumptions, research R6 and the data model kept the old wording until this close.
- Rule: When a review adds a guard, update spec Assumptions, research and the data model in the
  same commit, not only the contract and plan.

## 2026-10-11: 003-session-mods

### L14. A Bash command line with the kill marker kills its own shell

- What happened: The marker `spk003` in a Bash command line makes the shell that runs it a marked
  process. `cleanup.sh` then kills that shell, and the Bash call ends early. The orchestrator reports
  that this happened twice in this build. No commit records it. The rule is in `tasks.md` (Rules),
  and the scripts search with the pattern `spk00[3]`.
- Rule: Keep the marker text out of Bash command lines. Run cleanup and check in a Bash call of their
  own. Write a grep or pgrep pattern as `spk00[3]`, which does not match its own text.

### L15. A mod test must answer every host call the mod makes

- What happened: The mod test kit answers only `$.state` and `session.append`. The spike-send test
  (a65c127) answers `session.start`, `command.register`, `ui.open` and `session.receive` itself. The
  spike-start test (5138e25) also answers `process.spawn`.
- Rule: Before the first red run, list every host call the mod makes, and answer each one in the
  test. Then a red run points at the mod, not at a call the kit left unanswered.

### L16. Op events answer `{ value }` in the test

- What happened: The test answers for `command.register`, `ui.open` and `process.spawn` return
  `{ value: ... }` (spike-send `hooks/register.test.tsx:8-9`, spike-start `hooks/register.test.tsx:12-13,
  47, 62, 82`). The engine declaration defines op answers as `ValueOrDeny` of `OpValueOf` (d.ts 7205
  and 14683). The answers for `session.send` and `session.receive` are plain objects, because those
  events are not op events (d.ts 4652, 4660). No commit records a failure from a missing wrapper.
- Rule: Before you write a test answer, check whether the event is in `OpValueOf`. An op event
  answers `{ value }` or `{ deny }`. Any other event answers its own shape.

### L17. A conditional task ticked without a run looks done

- What happened: T008, T014 and T020 were ticked `[X]` with no note. Each one runs only when an
  earlier approach fails, and none did. Only `research.md` recorded the skip.
- Rule: When you tick a conditional task whose condition is false, write `Not run, <earlier result>
  passed.` in the task text.

## 2026-10-23: 007-herdr-workspace

### L18. A negative control run after earlier cases changed shared state cannot fail

- What happened: The NC1 and NC3 controls (broken copies of the script) ran after cases that had already changed the stub's shared state, so a red result could not be told from a changed baseline. Fixed in 7330d29.
- Rule: Right before each broken copy runs, the test asserts the real script is green on the same input and state, and the control counts only when that baseline is green and the broken copy is red.

### L19. Stub ids with a guessable pattern let a script build ids instead of reading them

- What happened: The stub `herdr` gave ids like `w1:p1`, so a script that built ids from a counter would pass. Fixed in 022defd: stub ids have a random part, and expectations come from the stub's log (the R2 case runs with `stubid0001`).
- Rule: A stub gives every id a random part per run, and the test reads the expected ids from the stub's log, so a script that builds an id fails.

### L20. A report row written before the call it describes lies on a stop

- What happened: US1 review F10: the report listed a program on a pane before `pane run` had succeeded, so a stop at the first `pane run` still showed `claude`. Fixed in 022defd (`prog` set after `pane run`; case L20).
- Rule: A report row shows a program or state only after the call that sets it succeeded, and a test that stops the run at that call asserts the row still says `shell` and `-`.

### L21. `herdr pane wait-output` matches the shell's echo of the typed command

- What happened: D7 used `pane wait-output` to see `claude` and `lazygit` start. The planner (F2) found it matches the echo of the typed command, so it cannot fail. D20 replaced it with `pane process-info` (71cc766, 0054744).
- Rule: "Program started" is decided from `herdr pane process-info` foreground process names, and a test where `process-info` fails must report `not seen` (case L16).

## 2026-10-23: 006-pr-workflow-script

### L22. Review fixes to prompt text left the contract's prompt table behind

- What happened: Commit `cf7feae` added rules to the agent prompts in `workflows/pr.js` (scan command flag, "Do not stage, commit, push or run gh." on the draft and fixers, a template search order, a no-feature-dir refuter line, the `facts:tests` JSON handoff) and a `bodyPath` missing case to the skill. `contracts/pr-workflow.md` section 2.4 and 4.2 and the fake `pipeline` in section 6 kept the old text until this close. The node test only checks five prompt strings, so no check failed.
- Rule: A review fix that changes a prompt string in `workflows/pr.js` must change the matching row of `contracts/pr-workflow.md` section 2.4 in the same commit, and any rule a prompt must hold goes into the `prompt rules` case of `tests/test_pr_workflow.mjs`.

### L23. A prompt-only scan has a volume ceiling that reads as a clean result

- What happened: `facts:scan` is one agent that reads every patch in the range, and `--diff-merges=first-parent` repeats main's delta for each merge of main. On a big branch it can run out of context and return `{finds: []}`, the same value as a clean scan. The schema cannot tell the two apart.
- Rule: A scan that gates a push must return a count of commits it read, and the script must add `unverified: facts:scan` when that count is lower than `commits.length`.

## 2026-10-23: 008-herdr-workers

### L24. herdr makes a worktree only from the main checkout

- What happened: The first live `start` ran from a linked worktree (`stratum-003-demo`) with `--cwd` set to the calling folder. herdr answered `linked_worktree_source` at once and nothing was made (research R1, R3). Every Stratum feature runs in a linked worktree, so `start` broke in the normal case. Fixed in 012a33f.
- Rule: `st-worker.sh start` passes the main checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`) as `--cwd` and in `--path`, and test S10 runs it from a linked worktree of the temp repo.

### L25. `agent start` right after `worktree create` answers `agent_pane_busy`

- What happened: The second live `start` failed 0.1 s after `worktree create`: the new pane's shell was not at its prompt. The stub answered `agent start` at once, so 308 stub checks hid it. Fixed in 77369ae with a 10-try retry, 1 s apart.
- Rule: `start` retries `agent start` on `agent_pane_busy` and stops with herdr's line after the 10th try, and tests S11 (busy N times, then ok) and S11b (busy every time, exactly 10 calls) check both.

### L26. The CLI printed text where the schema said JSON

- What happened: `herdr api schema --json` gave `pane_read` with `.result.read.text`, but `herdr agent read` prints plain text. The script piped it through `jq` and printed an empty `pane text:` on blocked, stopped and no-result stops, while the stub answered JSON and every test stayed green (research R1, third attempt; fixed in b39c626). This repeats the schema-versus-reality gap of L5.
- Rule: A stub for a herdr call answers in the format the real CLI printed in a recorded live run (`agent read`: plain text), and the case for each stop that shows pane text asserts the stub's `STUB PANE` marker appears.

### L27. A stub that answers at once hides timing bugs, so each state path needs a live run

- What happened: `agent_pane_busy` (L25), `blocked` lingering about 2 s after a dialog key, and an `agent read` format mismatch (L26) all passed 300 stub checks and showed only in T005 and T008. The live task order (T005, T008, T012, T015) found all three before the feature closed.
- Rule: A task that adds a herdr or `claude` call is ticked only after a live run of its start, blocked, finished and close paths is recorded in research.md, or `Not run, <first error line>` is written beside the tick.

### L28. A review fix that adds `--` to a real CLI call broke the call

- What happened: A review fix for option injection made `answer` send `herdr agent send-keys worker-t901 -- 1`. herdr took `--` as a key and answered `invalid_key: unsupported key --`; nothing was sent (research R7, live T008). The fix was to refuse a value that starts with `-` before any herdr call (case A4) and pass no `--`.
- Rule: A review fix that adds a flag or `--` to a call of a real CLI is run once against that CLI before the commit, and test A1 asserts the exact argv without it.

### L29. `blocked` lingers about 2 s after a dialog key

- What happened: In live T008 every `answer` printed `state blocked` and exit 4 right after the key, and an `agent get` 2 s later said `working`. The orchestrator would read exit 4 as a failed answer. 6fb6e4d added `agent wait --until working --timeout 5000` before the last `agent get`.
- Rule: `answer` waits for the worker to leave `blocked` before it reads the state, and test A1 asserts the order `send-keys`, `agent wait --until working`, `agent get`.

### L30. The models hook builds its allowed names from `agents/*.md`

- What happened: D27 reads an `st-worker` entry from `.stratum/models.json`, but `st-worker` is not an agent file. A models.json holding only that key made the hook deny an `st-git` start with `unknown agent "st-worker"` (research R16). D28 added the name to `hooks/st-models.py`.
- Rule: A new key in `.stratum/models.json` is added to `hooks/st-models.py` in the same task, and `tests/test_model_hook.py` has a case where a file holding only that key does not deny an agent start.

### L31. A quiet test command gives the `/goal` evaluator no evidence

- What happened: The headless run used `grep -qx h demo/h.txt`, which prints nothing on success. Goal turn 1 ended `met: false` ("insufficient evidence in transcript") and turn 2 re-ran the test with `&& echo PASS` (research R12). The run took 9 model requests instead of about 5.
- Rule: A test command that goes into a `/goal` condition prints a line on success (for example `&& echo PASS`), and the quickstart and task examples for `st-worker` show one.

### L32. Two brief rules that used the word "merge" were read as a clash

- What happened: Team rule 2 said "merge its branch" and rule 4 said "Never merge". In live T012 worker-t913 read rule 2 as the teammate case and merged without asking. 823708e reworded rule 4 to "Never merge into the base branch and never push." The same run showed the brief had no plugin root. The contract had the old rule 4 text.
- Rule: A rule in the brief that forbids an action names the target it forbids, test S1 asserts the whole rule 4 text, and a change to a brief line changes contracts/script.md section 3 in the same commit.
