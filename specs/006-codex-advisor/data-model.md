# Data Model: Codex Advisor

No database. Two files and the answer Codex writes. Exact formats are in
[contracts/advisor.md](contracts/advisor.md).

## Advisor settings (`.stratum/advisor.json`)

- Fields (spec Key Entities "Advisor settings", FR-010, FR-014, D8, D11):
  - `mode`: required in the file, one of `codex`, `both`, `off`.
  - `model`: optional string; Python `re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}", v)`.
    Passed as `-m <model>`.
  - `effort`: optional string; `re.fullmatch(r"[a-z]{1,16}", v)`. Passed as
    `-c model_reasoning_effort="<effort>"`.
  - `fullmatch`, not `re.match` with `$`: `$` also matches before a trailing newline, so
    `"high\n"` would pass.
  - No other key is allowed.
- Example: `{"mode": "codex", "model": "gpt-6-astra", "effort": "high"}`.
- Committed with the project (research R9, R10). `st-init` step 11 writes `{"mode": "<answer>"}`
  only, when the file is missing. The user adds `model` or `effort` by hand.
- No file means off (D11): the script prints
  `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".`,
  exits 0, writes no record and does not run Codex. Projects set up before this feature have no
  file and keep the old flow until the owner writes it.
- Validation: a file that is not a JSON object, has another key, has no `mode`, has a non-string
  value, a mode not in the three, or a `model` or `effort` that fails its `fullmatch` is
  `BLOCKED: bad advisor.json` (research R11). A file that sets `model` without `mode` is bad: the
  owner chooses the mode, Stratum never assumes `codex`. Read as bytes and
  decoded by `json.loads` (lessons L3).
- `model` and `effort` are the only source of the model and effort: the call passes
  `--ignore-user-config` (D23), so without them Codex uses its own default. Stratum checks
  their shape, not whether OpenAI accepts them: a wrong value comes back as a Codex error, which
  is `BLOCKED: codex exited <rc>` (research R11).
- Effect: `codex` runs Codex. `both` runs Codex and prints
  `mode both: also consult /advisor if one is set` as the first line. `off` prints
  `no advisor: mode off`, exits 0, runs nothing, writes no record.

## Verdict

- One of `APPROVED`, `REVISE`, `BLOCKED` (FR-003).
- From Codex: the `verdict` field of the answer.
- From the script, when the answer is not usable: `BLOCKED` with a reason (FR-004).
- From the user: `BLOCKED, user continued`, written by `st-advisor.sh continued` (FR-006).
- Exit status of a run: `APPROVED` and `REVISE` exit 0, `BLOCKED` exits 1, `no advisor` exits 0,
  bad arguments exit 2, `cannot hash inputs` exits 2.

## Finding

- Fields: `claim`, `evidence`, `location` (file and line when known, else free text), `severity`
  (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`). All four are required strings (FR-003, Key Entities).
- `APPROVED` with zero findings is valid. `REVISE` with zero findings is
  `BLOCKED: REVISE with no findings`. `APPROVED` with findings is `BLOCKED: APPROVED with findings`.
- Untrusted text: Codex read repo content to write it. Newlines and carriage returns in each field
  become spaces before the finding is printed or recorded, so no finding can start a record line
  (plan.md S3).

## Advisor answer (the `-o` file)

- JSON object `{verdict, summary, findings[]}`, shape fixed by the schema the script passes with
  `--output-schema` (research R1).
- Mapping to results, in this order (first match wins):
  1. Codex timed out (exit 124 or 137): `BLOCKED: timed out`.
  2. Codex exited non-zero: `BLOCKED: codex exited <rc>`. The last stderr line that starts
     `ERROR:` goes to stdout only, never to the record (D16, research R2).
  3. `-o` file missing or empty (only whitespace): `BLOCKED: empty answer`.
  4. Not JSON, or not an object: `BLOCKED: malformed answer`.
  5. `verdict` missing or not one of the three: `BLOCKED: no verdict`.
  6. `findings` missing or not a list, or a finding that is not an object with the four string
     fields: `BLOCKED: malformed answer`.
  7. `REVISE` with an empty list: `BLOCKED: REVISE with no findings`. `APPROVED` with a non-empty
     list: `BLOCKED: APPROVED with findings`.
  8. `BLOCKED` from Codex: `BLOCKED: <summary>`, then the finding lines.
  9. Else the verdict, as given.

## Advisor record (`specs/<feature>/advisor.md`)

- One entry per run of `plan` or `test` that reaches a verdict (every row of the answer
  mapping above, plus `BLOCKED: bad advisor.json`) and per `continued` call (FR-007). No entry
  for `no advisor` lines or bad arguments.
- Format: an empty line goes before a record when the file already has content, never after one
  (contract section 6).
- Fields: point, UTC date and time, SHA256 of the input, verdict, then a summary or reason line
  and one line per finding.
- The header line is the only line that starts with `## `. The latest header line for a point is
  the record that counts (US3 scenario 3).
- Committed. The lane commits it with its next `st-git` commit (plan.md, Project Structure).
- Input hashed per point (FR-007, research R6):
  - `plan`: the bytes of `<feature>/spec.md`, then `<feature>/plan.md` without its `## Validate`
    section, then `<feature>/tasks.md`, no separator (D10, D27):
    `{ cat spec.md && awk '/^## Validate$/{s=1;next} /^## /{s=0} !s' plan.md && cat tasks.md; } | sha256sum`.
    The left-out lines run from a line that is exactly `## Validate` up to, not including, the
    next line that starts with `## `. So `st-inspect` writing or replacing that section keeps the
    approval from `st-plan` step 4 fresh. Any other change to the three files makes it stale.
  - `test`: the bytes of failure output 1, then the bytes of failure output 2.
- Hash failure (D20, D21): every input must be a readable regular file, and the digest must be 64
  lowercase hex characters. Else, or when `cat`, `awk` or `sha256sum` fails, the script prints
  `cannot hash inputs`, exits 2 and writes no record. `check` stops the same way, so an empty or
  partial digest never matches an old record.
- State over one gate pass: no record, then `APPROVED` (go on), or `REVISE` (fix, then one more
  run: round 2), or `BLOCKED` (stop; user continues: `BLOCKED, user continued`). After round 2 the
  user decides. A record whose hash no longer matches the current input is stale and counts as no
  approval (FR-008).
