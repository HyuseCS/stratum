# Contract: Codex Advisor

Exact interfaces and text for `scripts/st-advisor.sh`, `.stratum/advisor.json`,
`specs/<feature>/advisor.md`, and the skill and README edits. Field rules are in
[data-model.md](../data-model.md).

Rule P1: every phrase in section 7 sits whole on one line of its target file. Do not wrap a line
inside a phrase.

## 1. Command line

Run from the project root. `<feature dir>` is the project-relative feature path, for example
`specs/006-codex-advisor`, and must hold `spec.md`.

```text
st-advisor.sh plan <feature dir>
st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>
st-advisor.sh check plan <feature dir>
st-advisor.sh continued <plan|test> <feature dir>
```

- `<task file>` holds the task text. The two failure files hold the two failure outputs. The
  orchestrator writes all three to its scratchpad.
- The `diff` forms (`diff`, `check diff`, `continued diff`) are removed (D26): each is the usage
  line, exit 2.
- Bad arguments (wrong count, unknown form, no `<feature dir>/spec.md`, for `plan` no
  `<feature dir>/plan.md` or `<feature dir>/tasks.md`, a missing task or failure file; every input file must be a readable regular file, so a directory or an
  unreadable file is bad too, D20; a `<feature dir>/advisor.md` that is a symlink): `usage: st-advisor.sh plan|test|check|continued ...` on one line, exit 2,
  no record, no Codex call.
- `check` reads the records first. No record for the point: `no record: <point>`, exit 1, even
  when `plan.md` or `tasks.md` does not exist yet. With a record, it hashes the current input; a
  missing plan file is then the usage line, exit 2.
- `continued` with no record for that point: `no record: <point>`, exit 2.
- Arguments go to commands as quoted argv. No `eval`, no `bash -c`.

## 2. Order of a `plan` or `test` run

1. Check the arguments (section 1).
2. Compute the input hash (data-model.md, Advisor record): `plan` hashes the bytes of
   `<f>/spec.md`, `<f>/plan.md` and `<f>/tasks.md` joined in that order (D10), with
   every line from a line that is exactly `## Validate` up to, not including, the next line that starts with `## ` left out of `plan.md` (D27):
   `{ cat <f>/spec.md && awk '/^## Validate$/{s=1;next} /^## /{s=0} !s' <f>/plan.md && cat <f>/tasks.md; } | sha256sum`.
   `test` hashes the
   two failure files joined in order.
   A hash that cannot be built stops the run (D20): the digest must be 64 lowercase hex
   characters. Else print `cannot hash inputs`, exit 2, no record, no Codex call.
   A failing `cat`, `awk` or `sha256sum` also stops the run with `cannot hash inputs` (`pipefail`).
   `check` does the same, so a failed hash never matches an old record.
3. Read the settings (data-model.md, Advisor settings). No file: print
   `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".`,
   exit 0, no record, no Codex call (D11). Bad file: record `BLOCKED`, print
   `BLOCKED: bad advisor.json`, exit 1. `off`: print `no advisor: mode off`, exit 0. `both`: print
   `mode both: also consult /advisor if one is set` first and go on.
4. `command -v codex` fails: print `no advisor: codex not found`, exit 0, no record.
5. Write the schema (section 3) and the prompt (section 4) to a `mktemp -d` dir. Run the Codex
   call (section 3). Remove the temp dir on exit.
6. Map the answer (data-model.md, Advisor answer), append the record (section 6), print the
   output (section 5).

## 3. Codex call and schema

The only Codex call, exactly these arguments, stdin from the prompt file, stdout and stderr to
files in the temp dir:

```text
timeout -k 10 540 codex exec -s read-only --ignore-user-config [-m <model>] [-c model_reasoning_effort="<effort>"] --ephemeral --output-schema <tmp>/schema.json -o <tmp>/answer.json -
```

- Codex runs only when `.stratum/advisor.json` exists and is valid with mode `codex` or `both`
  (D11).
- `--ignore-user-config` is always passed: neither `~/.codex/config.toml` nor a project
  `.codex/config.toml` is read (D23).
- `model` and `effort` are checked with Python `re.fullmatch` against
  `[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}` and `[a-z]{1,16}` (not `re.match` with `$`, which accepts a
  trailing newline).
- `-m <model>` only when `advisor.json` sets `model`. `-c model_reasoning_effort="<effort>"` (one
  argv element, the quotes are part of it) only when it sets `effort`. Without the keys, neither
  is passed (FR-014, research R11).
- Never present: `workspace-write`, `danger-full-access`,
  `--dangerously-bypass-approvals-and-sandbox`, `--approve-for-me`, `--add-dir`, `--full-auto`,
  `--model`, `--config`, `-p`, `--profile`, `--oss`, `review`, and any other `-c` (FR-012,
  research R4).
- Exit 124 or 137 from `timeout`: `BLOCKED: timed out`.
- Schema, written by the script (one JSON object, no comments):

```json
{"type":"object","additionalProperties":false,"required":["verdict","summary","findings"],"properties":{"verdict":{"type":"string","enum":["APPROVED","REVISE","BLOCKED"]},"summary":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["claim","evidence","location","severity"],"properties":{"claim":{"type":"string"},"evidence":{"type":"string"},"location":{"type":"string"},"severity":{"type":"string","enum":["CRITICAL","HIGH","MEDIUM","LOW"]}}}}}}
```

## 4. Prompt

Every prompt starts with these four lines, as written:

```text
You are a reviewer for Stratum. Review only: never create, change or delete a file, and never build or fix anything.
Read only the inputs named below and the files they cite. Never open .env files, keys, credentials, tokens or other secret files.
Never quote a secret value in a finding.
Answer with verdict APPROVED (nothing to fix), REVISE (findings to fix) or BLOCKED (you cannot review, or the work must stop). Each finding has a claim, the evidence, a location (file:line when known) and a severity.
```

Then, per point (`<f>` is the feature dir):

Plan point (names paths, pastes nothing, advice only, D27):

```text
Point: plan. Advise only on how the plan could be built better or done differently for a better outcome: a simpler or better approach, tasks to cut or merge. Do not check correctness, coverage or risks: the Inspect phase does that.
Inputs: <f>/spec.md, <f>/plan.md, <f>/tasks.md
```

Test point (the only point that pastes text, FR-009):

```text
Point: test. This task's test is still red after two build tries. Root cause or rabbit hole?
Test: <test path>
Task:
<bytes of the task file>
Failure output 1:
<bytes of failure 1 file>
Failure output 2:
<bytes of failure 2 file>
```

A pasted file that does not end in a newline gets one before the next label, so a label never sits on the same line as pasted text.

## 5. Output and exit status

| Case | stdout | Exit |
|------|--------|------|
| no `.stratum/advisor.json` | `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".` | 0 |
| mode `off` | `no advisor: mode off` | 0 |
| no `codex` on PATH | `no advisor: codex not found` | 0 |
| `APPROVED` or `REVISE` | `<VERDICT> sha256 <64 hex>`, `summary: <text>`, one line per finding, `record: <f>/advisor.md` | 0 |
| `BLOCKED` from Codex | `BLOCKED: <summary>`, one line per finding, `record: <f>/advisor.md` | 1 |
| Codex exited non-zero (not 124 or 137) | `BLOCKED: codex exited <rc>`, the last stderr line that starts `ERROR:` if there is one, `record: <f>/advisor.md` | 1 |
| any other `BLOCKED` | `BLOCKED: <reason>`, `record: <f>/advisor.md` | 1 |
| the input hash cannot be built (D20) | `cannot hash inputs` | 2 |

- Mode `both` adds `mode both: also consult /advisor if one is set` as the first line of every
  row except the no-file row and `off`.
- Reasons, exactly: `timed out`, `codex exited <rc>` (the last stderr line that starts `ERROR:`
  goes to stdout only, never to the record, D16, research R2), `empty answer`,
  `malformed answer`, `no verdict`, `REVISE with no findings`, `APPROVED with findings`, `bad advisor.json`, `timeout not found`.
- Finding line: `- [<severity>] <location>: <claim> Evidence: <evidence>`.
- Every Codex text (summary, each finding field, the error line) has each `\r` and `\n` replaced
  by a space before it is printed or recorded.

`check`:

| Case | stdout | Exit |
|------|--------|------|
| latest record for the point has the current hash | `<VERDICT> sha256 <64 hex>` (the verdict as recorded, for example `BLOCKED, user continued`) | 0 |
| latest record has another hash | `advisor approval is stale` | 1 |
| no record for the point | `no record: <point>` | 1 |
| the input hash cannot be built | `cannot hash inputs` | 2 |

`continued`: appends the record (section 6) with the latest record's hash for that point and
verdict `BLOCKED, user continued`, prints `BLOCKED, user continued sha256 <64 hex>`, exit 0.

## 6. Record format (`<f>/advisor.md`)

Appended, never rewritten. Created by the first append.

```text
## <point> | <YYYY-MM-DDTHH:MM:SSZ> | sha256 <64 hex> | <VERDICT>
summary: <text>                (when Codex answered)
reason: <reason>               (when the script set BLOCKED)
- [<severity>] <location>: <claim> Evidence: <evidence>
```

- An empty line goes before a record when the file already has content, never after one, so the
  file ends with the last line of the last record and one newline.
- `<point>` is `plan` or `test` (older records may say `diff`, D26). `<VERDICT>` is `APPROVED`, `REVISE`, `BLOCKED` or
  `BLOCKED, user continued`. Time from `date -u +%Y-%m-%dT%H:%M:%SZ`.
- The header is the only line that starts with `## `. `check` reads the last line that starts
  with `## <point> | `.

## 7. Skill and README text

Replace or add exactly this text. Line numbers are from `f0ac746`. Find each line by its text.

### 7.1 `skills/st-build/SKILL.md`

Step 4 (lines 28-30) becomes:

```markdown
4. **Two tries.** If the test is still red after 2 `st-build` tries, run the advisor (see Advisor): save the task text and both failure outputs to files in your scratchpad, then run
   `bash <plugin root>/scripts/st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>`: root cause or rabbit hole?
   For a `[P]` task in a worktree, run it in the main session after the subagent reports both failures, with the working directory at that worktree's root and `<feature dir>` as the main checkout's absolute path, so the record lands in the main checkout. Start `st-debug` from the main session too, with the worktree path; it diagnoses, fixes and verifies in that worktree.
   Then start the `st-debug` agent (`stratum:st-debug`) with the task, the test, both failure outputs, and the advisor's answer.
```

Step 5 (line 31) becomes:

```markdown
5. **Commit.** The `st-git` agent (`stratum:st-git`) commits the exact paths of the task, with tasks.md, and `<feature dir>/advisor.md` if it changed.
```

The end-of-build paragraph keeps its pre-#18 text (D26, `932295b^1`):

```markdown
When all tasks are ticked, consult the advisor if one is set (`/advisor`) on the feature's full
diff: hidden regressions, broken rules from the constitution. Handle its notes like review
findings. Then say so, list the small decisions and findings (fixed and dropped), and name the
next phase: `/stratum:st-close`.
```

In "Parallel tasks `[P]`" (line 36), `Each runs the per-task steps in its
worktree.` becomes:

```markdown
Each runs the per-task steps in its worktree, except step 4: a subagent whose test is still red after 2 tries stops and reports both failures.
```

New section before `## Always`:

```markdown
## Advisor

The advisor is Codex (the `codex` CLI), a model from another vendor. It runs at two points: the plan before the Plan gate (`st-plan` step 4, stale-checked at the build gate by `st-inspect`) and a test still red after 2 tries. The full diff before the build is called done and every Fast-lane point use `/advisor`. The Quick lane has no advisor.

- Run `bash <plugin root>/scripts/st-advisor.sh <point> ...` from the project root in the foreground, with a Bash timeout of 600000 ms, and wait for it. No background run, no polling.
- Codex only reviews, in the read-only sandbox. Never run `codex` to build or fix.
- `no advisor: codex not found`, `no advisor: mode not set` (show the user its line) or `no advisor: mode off`: go on as before; consult `/advisor` only if the user set one.
- First line `mode both: also consult /advisor if one is set`: after Codex, consult `/advisor` on the same input if one is set.
- `APPROVED`: go on.
- `REVISE`: handle each finding like a review finding: check it against the source, fix the real small ones, bring big ones to the user, drop the false ones. Then run the same point once more on the changed input. Two rounds at most per point per gate pass, then the user decides. A later gate pass starts a new count.
- `BLOCKED: <reason>`: stop and show the user the reason. Nothing passes the gate. If the user says to continue, run `bash <plugin root>/scripts/st-advisor.sh continued <point> <feature dir>` and skip the point. Do not retry it in this gate pass.
- Each run appends a record to `<feature dir>/advisor.md`: the point, the time, the SHA256 of the input, the verdict and the findings. The mode comes from `.stratum/advisor.json` (`codex`, `both` or `off`). No file means off, with the `mode not set` line.
- At the build gate, `check plan` compares the latest plan record with the current input. `advisor approval is stale` or `no record` counts as no approval: run the plan point once more, as a round. Skip the check after a `no advisor` line.
- Exit 2 with a `usage:` line or `cannot hash inputs`: the script could not read or hash its inputs. Nothing was recorded and nothing was sent. Fix the input or the tool and run the point again.
```

### 7.2 `skills/st-inspect/SKILL.md`

No Codex run (D26). Step 5 becomes step 4 and refers to step 2 only:

```markdown
4. If a fix removed or renamed a task in step 2, grep each old ID from the fix's diff of `tasks.md` in the `## Validate` section of `plan.md`; on any hit run `st-inspect` once more.
```

The gate's first line (line 38) gains a sentence before it:

```markdown
Run `bash <plugin root>/scripts/st-advisor.sh check plan <feature dir>` and show its line; `advisor approval is stale` counts as no approval: run the plan point (`st-plan` step 4) once more, as a round, before the gate. Have `st-git` commit `<feature dir>/advisor.md` if it changed.
```

### 7.3 `skills/st-fast/SKILL.md`

No Codex and no `st-advisor.sh` call (D26). Steps 3 and 4 consult `/advisor`:

```markdown
3. For each test in the change plan: the `stratum:st-test` agent writes it and shows it fails; the `stratum:st-build` agent makes it
   pass. A test still red after 2 tries goes to the `stratum:st-debug` agent, with the advisor's answer
   first if one is set (`/advisor`): root cause or rabbit hole?
4. Verify with `bash <plugin root>/scripts/st-verify.sh '<test command>' <files touched>` (see `/stratum:st`). Then
   consult the advisor if one is set (`/advisor`) on the diff: hidden regressions? Handle its notes like findings.
```

Step 6 is `6. The `stratum:st-git` agent commits exact paths.` (pre-#18).

### 7.4 `skills/st-init/SKILL.md`

New step after step 10 (Tool check); step 11 (Report) becomes 12:

```markdown
11. **Advisor.** If `.stratum/advisor.json` is missing, ask the user in one question: advisor mode `codex` (recommended: Codex reviews the plan and a test red after 2 tries; needs `codex` logged in), `both` (Codex, then `/advisor` if set), or `off` (no Codex, nothing sent to OpenAI)?
   Write `.stratum/advisor.json` as `{"mode": "<answer>"}`. It is committed. New projects get the file here; without it the advisor is off. Say how to change it later: edit the file. Optional `model` and `effort` keys pick the Codex model and reasoning effort; without them Codex uses its own default model and effort.
```

In the Report step (`skills/st-init/SKILL.md:62-65`), the committed file list reads, as it is in
the file:

```markdown
   still needs to do. Commit only the created or changed project files (`.stratum/state.json`,
   `.stratum/constitution.md`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`),
```

Insert `.stratum/advisor.json`, with backticks, after `.stratum/constitution.md`, keeping the
line wrap of the file.

### 7.5 `README.md`

The Built in **Advisor.** bullet becomes:

```markdown
- **Advisor.** Codex (OpenAI's `codex` CLI), a model from another vendor, runs at two points in the Full lane. At the end of the Plan phase, before its gate, it only advises on a simpler or better approach and does not validate the plan (`st-inspect` does that). It also reviews a test still red after two tries. The full diff before the build is called done and the whole Fast lane use `/advisor` if you set one. The Quick lane has no advisor.
  The orchestrator runs `scripts/st-advisor.sh` in the foreground and waits for the answer. Codex runs in the read-only sandbox and only reviews: it never builds or fixes.
  It answers `APPROVED`, `REVISE` (findings, checked against the source like any finding, then one more run, two rounds at most), or `BLOCKED` (the orchestrator stops and asks you).
  A failed, empty, malformed or late answer (540 seconds) is `BLOCKED`, never approval.
  Each run appends the point, a SHA256 of the input, the verdict and the findings to `specs/<feature>/advisor.md`. An approval of a plan that changed since then is stale.
  What leaves the machine: each call sends the prompt and the files Codex reads to OpenAI, on your Codex login and quota (about 37,000 tokens per plan review). At the plan point the prompt names the plan files and Codex reads them; at the test point it holds the task text, the test path and both failure outputs.
  The prompt tells Codex to stay inside the named inputs, never open env or secret files, and never quote a secret value. The sandbox does not block reads.
  Whether Codex's own shell sees your environment variables is not checked.
  `.stratum/advisor.json` sets the mode: `{"mode": "codex"}`, `{"mode": "both"}` (Codex, then `/advisor` if you set one), or `{"mode": "off"}`. `"mode": "off"` is the off switch: nothing goes to OpenAI.
  With no file the advisor is off and prints `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".` `st-init` writes the file for new projects. A project set up before this feature has no file, so the advisor stays off until you write it.
  With no `codex` on PATH you get one line, `no advisor: codex not found`, and the flow runs as before, with `/advisor` if you set one.
  Optional `model` and `effort` keys in the same file pick the Codex model and reasoning effort, for example `{"mode": "codex", "model": "gpt-6-astra", "effort": "high"}`. Without them Codex uses its own default.
  The call runs with `--ignore-user-config`: neither `~/.codex/config.toml` nor a project `.codex/config.toml` is read, so no MCP server, hook or notify command from them runs during a review, and the model and effort come only from this file. Your Codex login works as before.
```

The last line of the bullet (D23) replaces the D15 line: with `--ignore-user-config` a project
`.codex/config.toml` is not read. Its phrase row, in `tests/test_on_demand.sh`:
`#18 D23 readme<TAB>README.md<TAB>The call runs with `--ignore-user-config`: neither `~/.codex/config.toml` nor a project `.codex/config.toml` is read`

Project files tree: after the `state.json` line add

```text
├── advisor.json         advisor mode (codex, both, off), optional Codex model and effort (committed)
```

Requirements table: after the `gh` row add

```markdown
| `codex` 0.163.0 or later, logged in, and GNU `timeout` | optional, the Codex advisor |
```

Line 32: `asks for the git guard modes and any model overrides, grills you` becomes
`asks for the git guard modes and any model overrides, asks for the advisor mode, grills you`.

Project files tree, `specs/NNN-feature/` line: `checklists/, changes/` becomes
`checklists/, changes/, advisor.md`.

Tests list (T001 adds it, so `tests/test_inspect.sh` "README tests" stays green): add
`bash tests/test_advisor.sh` before `bash tests/test_model_files.sh`.

### 7.6 `skills/st-plan/SKILL.md`

After step 3 (Verify), a new step 4; the commit step becomes step 5 (D26):

```markdown
4. **Advisor.** Run `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>` from the project root in the foreground, with a Bash timeout of 600000 ms, and wait for it.
   Codex reads spec, plan and tasks in the read-only sandbox and only advises: a simpler or better approach, tasks to cut or merge. It does not validate; st-inspect does.
   Handle its answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md`; big ones go to the user before the gate.
   Fixes go to the same `st-plan` subagent and cost a round.
5. Have `st-git` commit the plan files with exact paths, and `<feature dir>/advisor.md` if it changed.
```

## 8. Phrase table (`tests/test_on_demand.sh`, `#18` rows)

`name<TAB>target<TAB>phrase`. The phrase is the cell text inside its outer backticks.

| Name | Target | Phrase |
|------|--------|--------|
| #18 FR-001 build test point | skills/st-build/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>` |
| #18 FR-001 build quick | skills/st-build/SKILL.md | `The Quick lane has no advisor.` |
| #18 FR-001 build worktree | skills/st-build/SKILL.md | `with the working directory at that worktree's root and `<feature dir>` as the main checkout's absolute path, so the record lands in the main checkout.` |
| #18 FR-001 inspect plan point | skills/st-plan/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>` |
| #18 FR-002 wait build | skills/st-build/SKILL.md | `in the foreground, with a Bash timeout of 600000 ms, and wait for it. No background run, no polling.` |
| #18 FR-002 wait inspect | skills/st-plan/SKILL.md | `in the foreground, with a Bash timeout of 600000 ms, and wait for it.` |
| #18 FR-005 revise | skills/st-build/SKILL.md | `Two rounds at most per point per gate pass, then the user decides.` |
| #18 FR-005 revise | skills/st-build/SKILL.md | `Then run the same point once more on the changed input.` |
| #18 FR-006 blocked | skills/st-build/SKILL.md | `stop and show the user the reason. Nothing passes the gate.` |
| #18 FR-006 blocked | skills/st-build/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh continued <point> <feature dir>` |
| #18 FR-007 record | skills/st-build/SKILL.md | `Each run appends a record to `<feature dir>/advisor.md`` |
| #18 FR-008 stale build | skills/st-build/SKILL.md | ``advisor approval is stale` or `no record` counts as no approval` |
| #18 FR-008 stale inspect | skills/st-inspect/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh check plan <feature dir>` |
| #18 FR-010 modes | skills/st-build/SKILL.md | `The mode comes from `.stratum/advisor.json` (`codex`, `both` or `off`).` |
| #18 FR-010 modes | skills/st-build/SKILL.md | `First line `mode both: also consult /advisor if one is set`` |
| #18 FR-010 no file | skills/st-build/SKILL.md | `No file means off, with the `mode not set` line.` |
| #18 FR-010 no file | README.md | `With no file the advisor is off and prints `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".`` |
| #18 FR-010 no file | README.md | `A project set up before this feature has no file, so the advisor stays off until you write it.` |
| #18 FR-011 no codex | skills/st-build/SKILL.md | ``no advisor: mode not set` (show the user its line) or `no advisor: mode off`: go on as before` |
| #18 FR-011 no codex | skills/st-build/SKILL.md | ``no advisor: codex not found`, `no advisor: mode not set`` |
| #18 FR-012 review only | skills/st-build/SKILL.md | `Never run `codex` to build or fix.` |
| #18 FR-016 inspect rules | skills/st-plan/SKILL.md | `Handle its answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md`` |
| #18 FR-015 init | skills/st-init/SKILL.md | `If `.stratum/advisor.json` is missing, ask the user in one question: advisor mode `codex` (recommended` |
| #18 FR-015 init | skills/st-init/SKILL.md | `Write `.stratum/advisor.json` as `{"mode": "<answer>"}`.` |
| #18 FR-016 readme | README.md | `The orchestrator runs `scripts/st-advisor.sh` in the foreground and waits for the answer.` |
| #18 FR-016 readme | README.md | `Codex runs in the read-only sandbox and only reviews: it never builds or fixes.` |
| #18 FR-016 readme | README.md | `What leaves the machine: each call sends the prompt and the files Codex reads to OpenAI` |
| #18 FR-016 readme | README.md | ``"mode": "off"` is the off switch: nothing goes to OpenAI.` |
| #18 FR-016 readme | README.md | `With no `codex` on PATH you get one line, `no advisor: codex not found`` |
| #18 FR-016 readme | README.md | `A failed, empty, malformed or late answer (540 seconds) is `BLOCKED`, never approval.` |
| #18 FR-016 readme | README.md | `An approval of a plan that changed since then is stale.` |
| #18 D13 readme | README.md | `Whether Codex's own shell sees your environment variables is not checked.` |
| #18 inspect keep | skills/st-plan/SKILL.md | `; big ones go to the user before the gate.` |
| #18 FR-014 readme | README.md | `Optional `model` and `effort` keys in the same file pick the Codex model and reasoning effort` |
| #18 D23 readme | README.md | `The call runs with `--ignore-user-config`: neither `~/.codex/config.toml` nor a project `.codex/config.toml` is read` |
| #18 FR-014 init | skills/st-init/SKILL.md | `Optional `model` and `effort` keys pick the Codex model and reasoning effort` |
| #18 FR-001 build worktree stop | skills/st-build/SKILL.md | `a subagent whose test is still red after 2 tries stops and reports both failures` |
| #18 L18 commit build | skills/st-build/SKILL.md | `with tasks.md, and `<feature dir>/advisor.md` if it changed.` |
| #18 L18 commit plan | skills/st-plan/SKILL.md | `and `<feature dir>/advisor.md` if it changed.` |
| #18 D27 plan advice only | skills/st-plan/SKILL.md | `It does not validate; st-inspect does.` |
| #18 L18 commit inspect | skills/st-inspect/SKILL.md | `Have `st-git` commit `<feature dir>/advisor.md` if it changed.` |
| #18 L19 debug worktree | skills/st-build/SKILL.md | `Start `st-debug` from the main session too, with the worktree path; it diagnoses, fixes and verifies in that worktree.` |
| #18 exit 2 | skills/st-build/SKILL.md | `Exit 2 with a `usage:` line or `cannot hash inputs`: the script could not read or hash its inputs.` |
| #18 exit 2 | skills/st-build/SKILL.md | `Nothing was recorded and nothing was sent. Fix the input or the tool and run the point again.` |
| #18 plan-only st-fast pointer | skills/st-fast/SKILL.md | `consult the advisor if one is set` |

Plus checks that are not phrases:

- `#18 plan-only st-inspect no plan run`: `skills/st-inspect/SKILL.md` has no
  `st-advisor.sh plan <feature dir>` and still has `st-advisor.sh check plan <feature dir>`.
- `#18 D27 st-plan no validation risk text`: `skills/st-plan/SKILL.md` has no `missed auth invariants`.
- `#18 plan-only st-fast no script`: `skills/st-fast/SKILL.md` has no `st-advisor.sh`.
- `#18 plan-only st-build no diff point`: `skills/st-build/SKILL.md` has no `st-advisor.sh diff`
  and no `check diff`.
- `#18 FR-001 quick lane`: `! grep -qF st-advisor "$root/skills/st-quick/SKILL.md"`.
- `#18 FR-016 st-inspect old advisor text gone`: ``If an advisor is set (`/advisor`)`` is not in
  `skills/st-inspect/SKILL.md` (a `grep -qF` that must find nothing).
