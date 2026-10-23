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

## 2026-10-23: 006-pr-workflow-script

### L14. Review fixes to prompt text left the contract's prompt table behind

- What happened: Commit `cf7feae` added rules to the agent prompts in `workflows/pr.js` (scan command flag, "Do not stage, commit, push or run gh." on the draft and fixers, a template search order, a no-feature-dir refuter line, the `facts:tests` JSON handoff) and a `bodyPath` missing case to the skill. `contracts/pr-workflow.md` section 2.4 and 4.2 and the fake `pipeline` in section 6 kept the old text until this close. The node test only checks five prompt strings, so no check failed.
- Rule: A review fix that changes a prompt string in `workflows/pr.js` must change the matching row of `contracts/pr-workflow.md` section 2.4 in the same commit, and any rule a prompt must hold goes into the `prompt rules` case of `tests/test_pr_workflow.mjs`.

### L15. A prompt-only scan has a volume ceiling that reads as a clean result

- What happened: `facts:scan` is one agent that reads every patch in the range, and `--diff-merges=first-parent` repeats main's delta for each merge of main. On a big branch it can run out of context and return `{finds: []}`, the same value as a clean scan. The schema cannot tell the two apart.
- Rule: A scan that gates a push must return a count of commits it read, and the script must add `unverified: facts:scan` when that count is lower than `commits.length`.

## 2026-10-23: 006-codex-advisor

### L16. A hash step that ignored tool failures let a stale approval pass

- What happened: Diff-point Codex rounds 2 and 3 found that a missing `sha256sum`, an unreadable file or a failing `git` command left an empty or partial digest, and `check` matched it against an older record (D20, D21). Round 2's fix added the readable-file test and the 64-hex digest check only; round 3 found the `git` exit codes still ignored.
- Rule: A script that hashes an input to gate an approval must have one test per producer (each tool in the pipeline, each unreadable input) where that producer fails, and the test must fail unless the script exits non-zero with no record written.

### L17. A fixed defect had a second entry point that the first fix left open

- What happened: The hash failure above took three review rounds because each fix closed one producer (D20) and the next round found another (D21). Both rounds were used on one gate pass, and the user had to approve an extra round.
- Rule: When a review finding is a failure mode of a shared step, list every command that feeds that step before the fix and give each one a failing test in the same commit.

### L18. Commit lines in the skills assumed the advisor always wrote a record

- What happened: The first skill text told `st-git` to commit `<feature dir>/advisor.md` at three gates. With mode off, no codex or no record, the file does not exist, and the commit would fail. The diff-point review found it (D19) and the lines now say "if it changed".
- Rule: A skill line that commits a generated file must say "if it changed", and the phrase table must hold a row for that wording at every gate that names the file.

### L19. A parallel worktree task ran the advisor from the wrong directory

- What happened: The `[P]` escalation text sent the test-point advisor run and `st-debug` to the main session without a path. The record, the diff and the fix would land outside the worktree that held the failing test. The diff-point review found it (D19); the text now says to run from the worktree root and pass the worktree path to `st-debug`.
- Rule: Any skill text that moves work from a worktree subagent to the main session must name the worktree path that the next command runs in, and the phrase table must hold that wording.

### L20. A guard test must have its own negative control before the fix is trusted

- What happened: The D20 hash fix was proven red before and green after with a `sha256sum` stub that prints nothing, and the D21 fix with a `chmod 000` untracked file. The first Codex-reported cause (an unreadable input and `sha256sum`) was real but incomplete (L17).
- Rule: Each guard added after a review finding must have a test that is red on the previous commit of the script, and the fix commit message must name that test.
