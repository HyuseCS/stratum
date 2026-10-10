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
