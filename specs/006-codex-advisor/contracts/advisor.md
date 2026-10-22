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
st-advisor.sh diff <feature dir> <base>
st-advisor.sh check plan <feature dir>
st-advisor.sh check diff <feature dir> <base>
st-advisor.sh continued <plan|test|diff> <feature dir>
```

- `<task file>` holds the task text. The two failure files hold the two failure outputs. The
  orchestrator writes all three to its scratchpad.
- `<base>` is any commit name. The script resolves it with
  `git rev-parse --verify --quiet "<base>^{commit}"` and uses only the full SHA it prints.
- Bad arguments (wrong count, unknown form, no `<feature dir>/spec.md`, for `plan` no
  `<feature dir>/plan.md` or `<feature dir>/tasks.md`, a base that is not a commit, a missing task
  or failure file; every input file must be a readable regular file, so a directory or an
  unreadable file is bad too, D20; a `<feature dir>/advisor.md` that is a symlink): `usage: st-advisor.sh plan|test|diff|check|continued ...` on one line, exit 2,
  no record, no Codex call.
- `check` reads the records first. No record for the point: `no record: <point>`, exit 1, even
  when `plan.md` or `tasks.md` does not exist yet. With a record, it hashes the current input; a
  missing plan file is then the usage line, exit 2.
- `continued` with no record for that point: `no record: <point>`, exit 2.
- Arguments go to commands as quoted argv. No `eval`, no `bash -c`.

## 2. Order of a `plan`, `test` or `diff` run

1. Check the arguments (section 1).
2. Compute the input hash (data-model.md, Advisor record): `plan` hashes the bytes of
   `<f>/spec.md`, `<f>/plan.md` and `<f>/tasks.md` joined in that order (D10). `test` hashes the
   two failure files joined in order. `diff` hashes
   `git diff <sha> -- . ':(exclude)<f>/advisor.md'` followed by
   `git diff --no-index -- /dev/null <path>` for each untracked path (same exclusion, D9). Every
   untracked path is in the hash, secret-looking ones too (D12). Both hash diffs run with
   `--no-ext-diff --no-color --no-renames --default-prefix`, so the user's git config cannot change
   the digest. An untracked entry ending in `/` (a nested repository or worktree) is skipped in the
   hash and in the prompt's untracked list.
   A hash that cannot be built stops the run (D20, D21): `git ls-files`, `git diff` and each
   `git diff --no-index` (which may exit 1, by design) must succeed, and the digest must be 64
   lowercase hex characters. Else print `cannot hash inputs`, exit 2, no record, no Codex call.
   A failing `cat` or `sha256sum` also stops the run with `cannot hash inputs` (`pipefail`).
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
timeout -k 10 540 codex exec -s read-only [-m <model>] [-c model_reasoning_effort="<effort>"] --ephemeral --output-schema <tmp>/schema.json -o <tmp>/answer.json -
```

- Codex runs only when `.stratum/advisor.json` exists and is valid with mode `codex` or `both`
  (D11).
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

Then, per point (`<f>` is the feature dir, `<sha>` the full base SHA):

Plan point (names paths, pastes nothing):

```text
Point: plan. Review the plan before the build. Risks: missed access rules, schema or contract breaks, hidden breaking changes. Improvements: a simpler approach, tasks to cut or merge.
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

Diff point:

```text
Point: diff. Review the full diff before the build is called done: hidden regressions, broken project rules, missed requirements.
Inputs: run git diff <sha> -- . ':(exclude)<f>/advisor.md' ':(exclude,icase).env*' ':(exclude,icase)*/.env*' ':(exclude,icase)*.env' ':(exclude,icase)*.pem' ':(exclude,icase)*.key' ':(exclude,icase)*.p12' ':(exclude,icase)*.pfx' ':(exclude,icase)*.jks' ':(exclude,icase)*.keystore' ':(exclude,icase)id_rsa*' ':(exclude,icase)*/id_rsa*' ':(exclude,icase)id_ed25519*' ':(exclude,icase)*/id_ed25519*' ':(exclude,icase)id_ecdsa*' ':(exclude,icase)*/id_ecdsa*' ':(exclude,icase).npmrc' ':(exclude,icase)*/.npmrc' ':(exclude,icase).netrc' ':(exclude,icase)*/.netrc' ':(exclude,icase).pypirc' ':(exclude,icase)*/.pypirc' ':(exclude,icase)credentials*' ':(exclude,icase)*/credentials*' and read each untracked file listed below. Env and secret files are left out of that diff. The feature dir is <f>.<rules>
Untracked files:
<one path per line, or the line: none>
```

`<rules>` is ` Read the project rules in .stratum/constitution.md.` when `.stratum/constitution.md`
exists, and empty when it does not.

The `Untracked files:` list leaves out each path whose basename matches, case-insensitive,
`.env*`, `*.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`, `id_rsa*`,
`id_ed25519*`, `id_ecdsa*`, `.npmrc`, `.netrc`, `.pypirc` or `credentials*` (shell `case` on
`${path##*/}` under `nocasematch`, any directory). The `git diff` command in the prompt excludes
the same names with `icase` pathspecs. Those paths stay in the hash (section 2, D12). If every
untracked path is left out, the list is `none`.

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
| the input hash cannot be built (D20, D21) | `cannot hash inputs` | 2 |

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
- `<point>` is `plan`, `test` or `diff`. `<VERDICT>` is `APPROVED`, `REVISE`, `BLOCKED` or
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

The end-of-build paragraph (lines 56-59) becomes:

```markdown
When all tasks are ticked, run the advisor on the feature's full diff (see Advisor):
`bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <base>`: hidden regressions, broken rules from the constitution.
The base: on a branch, `git merge-base main HEAD`. On `main`, `git rev-parse "$(git log --diff-filter=A --format=%H -- <feature dir>/spec.md | tail -1)^"`.
Before you say the build is done, run `bash <plugin root>/scripts/st-advisor.sh check diff <feature dir> <base>`, then have `st-git` commit `<feature dir>/advisor.md` if it changed.
Then say so, list the small decisions and findings (fixed and dropped), and name the
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

The advisor is Codex (the `codex` CLI), a model from another vendor. It runs at three points: the plan before the build gate (`st-inspect` step 4), a test still red after 2 tries, and the full diff before the build is called done. The Quick lane has no advisor.

- Run `bash <plugin root>/scripts/st-advisor.sh <point> ...` from the project root in the foreground, with a Bash timeout of 600000 ms, and wait for it. No background run, no polling.
- Codex only reviews, in the read-only sandbox. Never run `codex` to build or fix.
- `no advisor: codex not found`, `no advisor: mode not set` (show the user its line) or `no advisor: mode off`: go on as before; consult `/advisor` only if the user set one.
- First line `mode both: also consult /advisor if one is set`: after Codex, consult `/advisor` on the same input if one is set.
- `APPROVED`: go on.
- `REVISE`: handle each finding like a review finding: check it against the source, fix the real small ones, bring big ones to the user, drop the false ones. Then run the same point once more on the changed input. Two rounds at most per point per gate pass, then the user decides. A later gate pass starts a new count.
- `BLOCKED: <reason>`: stop and show the user the reason. Nothing passes the gate. If the user says to continue, run `bash <plugin root>/scripts/st-advisor.sh continued <point> <feature dir>` and skip the point. Do not retry it in this gate pass.
- Each run appends a record to `<feature dir>/advisor.md`: the point, the time, the SHA256 of the input, the verdict and the findings. The mode comes from `.stratum/advisor.json` (`codex`, `both` or `off`). No file means off, with the `mode not set` line.
- At a gate, `check` compares the latest record with the current input. `advisor approval is stale` or `no record` counts as no approval: run the point once more, as a round. Skip the check after a `no advisor` line.
- Exit 2 with a `usage:` line or `cannot hash inputs`: the script could not read or hash its inputs. Nothing was recorded and nothing was sent. Fix the input or the tool and run the point again.
```

### 7.2 `skills/st-inspect/SKILL.md`

Step 4 (lines 29-33) becomes:

```markdown
4. **Advisor.** Run `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>` from the project root in the foreground, with a Bash timeout of 600000 ms, and wait for it.
   Codex reviews spec, plan and tasks in the read-only sandbox. Risks: missed auth invariants, schema or contract breaks, hidden breaking changes.
   Improvements: a simpler or better approach, tasks to cut or merge.
   Handle its answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md`; big ones go to the user before the gate.
   A later re-run of `st-inspect` (step 5) changes `plan.md` and costs a round.
```

The gate's first line (line 38) gains a sentence before it:

```markdown
Run `bash <plugin root>/scripts/st-advisor.sh check plan <feature dir>` and show its line; `advisor approval is stale` counts as no approval. Have `st-git` commit `<feature dir>/advisor.md` if it changed.
```

### 7.3 `skills/st-fast/SKILL.md`

Step 3 (lines 16-18) becomes:

```markdown
3. For each test in the change plan: the `stratum:st-test` agent writes it and shows it fails; the `stratum:st-build` agent makes it
   pass. A test still red after 2 tries goes to the `stratum:st-debug` agent, with the advisor's answer
   first: save the task text and both failure outputs to files in your scratchpad, then run
   `bash <plugin root>/scripts/st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>`: root cause or rabbit hole?
   Run it in the foreground, with a Bash timeout of 600000 ms, and wait; handle the answer as in step 4.
```

Step 4 (lines 19-20) becomes:

```markdown
4. Verify with `bash <plugin root>/scripts/st-verify.sh '<test command>' <files touched>` (see `/stratum:st`). Then run
   `bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <base from step 1>` in the foreground, with a Bash timeout of 600000 ms, and wait: hidden regressions?
   Handle each advisor answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md` (verdicts, rounds, modes, record, no Codex).
```

Step 6 (line 25) becomes:

```markdown
6. Before the commit, run `bash <plugin root>/scripts/st-advisor.sh check diff <feature dir> <base from step 1>`. If review fixes made it stale, run the diff point once more if a round is left; else tell the user.
   The `stratum:st-git` agent commits exact paths, with `<feature dir>/advisor.md` if it changed.
```

### 7.4 `skills/st-init/SKILL.md`

New step after step 10 (Tool check); step 11 (Report) becomes 12:

```markdown
11. **Advisor.** If `.stratum/advisor.json` is missing, ask the user in one question: advisor mode `codex` (recommended: Codex reviews the plan, a test red after 2 tries, and the full diff; needs `codex` logged in), `both` (Codex, then `/advisor` if set), or `off` (no Codex, nothing sent to OpenAI)?
   Write `.stratum/advisor.json` as `{"mode": "<answer>"}`. It is committed. New projects get the file here; without it the advisor is off. Say how to change it later: edit the file. Optional `model` and `effort` keys pick the Codex model and reasoning effort; without them Codex uses the user's own config.
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

The Built in **Advisor.** bullet (lines 159-162) becomes:

```markdown
- **Advisor.** Codex (OpenAI's `codex` CLI), a model from another vendor, reviews the work at three points in the Full and Fast lanes: the plan before the build gate, a test still red after two tries, and the full diff before the build is called done. The Quick lane has no advisor.
  The orchestrator runs `scripts/st-advisor.sh` in the foreground and waits for the answer. Codex runs in the read-only sandbox and only reviews: it never builds or fixes.
  It answers `APPROVED`, `REVISE` (findings, checked against the source like any finding, then one more run, two rounds at most), or `BLOCKED` (the orchestrator stops and asks you).
  A failed, empty, malformed or late answer (540 seconds) is `BLOCKED`, never approval.
  Each run appends the point, a SHA256 of the input, the verdict and the findings to `specs/<feature>/advisor.md`. An approval of a plan or diff that changed since then is stale.
  What leaves the machine: each call sends the prompt and the files Codex reads to OpenAI, on your Codex login and quota (about 37,000 tokens per plan or diff review). The prompt names paths and a base commit; at the test point it holds the task text, the test path and both failure outputs.
  The prompt tells Codex to stay inside the named inputs, never open env or secret files, and never quote a secret value. The sandbox does not block reads.
  At the diff point, untracked `.env*`, `*.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `.npmrc`, `.netrc`, `.pypirc` and `credentials*` files (any case) are left out of the list Codex is given. Whether Codex's own shell sees your environment variables is not checked.
  `.stratum/advisor.json` sets the mode: `{"mode": "codex"}`, `{"mode": "both"}` (Codex, then `/advisor` if you set one), or `{"mode": "off"}`. `"mode": "off"` is the off switch: nothing goes to OpenAI.
  With no file the advisor is off and prints `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".` `st-init` writes the file for new projects. A project set up before this feature has no file, so the advisor stays off until you write it.
  With no `codex` on PATH you get one line, `no advisor: codex not found`, and the flow runs as before, with `/advisor` if you set one.
  Optional `model` and `effort` keys in the same file pick the Codex model and reasoning effort, for example `{"mode": "codex", "model": "gpt-6-astra", "effort": "high"}`. Without them Codex uses your own Codex config.
```

Last line of the bullet (D15). T011's probe showed that a trusted project loads a committed
`.codex/config.toml` (D17), so the line is in the README and has its phrase row:

```markdown
  A committed .codex/config.toml in the project can change the Codex model, provider or host, like any committed code.
```

Its phrase row, in `tests/test_on_demand.sh`:
`#18 D15 readme<TAB>README.md<TAB>A committed .codex/config.toml in the project can change the Codex model, provider or host, like any committed code.`

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

## 8. Phrase table (`tests/test_on_demand.sh`, `#18` rows)

`name<TAB>target<TAB>phrase`. The phrase is the cell text inside its outer backticks.

| Name | Target | Phrase |
|------|--------|--------|
| #18 FR-001 build test point | skills/st-build/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>` |
| #18 FR-001 build diff point | skills/st-build/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <base>` |
| #18 FR-001 build base | skills/st-build/SKILL.md | `The base: on a branch, `git merge-base main HEAD`.` |
| #18 FR-001 build quick | skills/st-build/SKILL.md | `The Quick lane has no advisor.` |
| #18 FR-001 build worktree | skills/st-build/SKILL.md | `with the working directory at that worktree's root and `<feature dir>` as the main checkout's absolute path, so the record lands in the main checkout.` |
| #18 FR-001 build worktree stop | skills/st-build/SKILL.md | `a subagent whose test is still red after 2 tries stops and reports both failures` |
| #18 FR-001 inspect plan point | skills/st-inspect/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>` |
| #18 FR-001 fast test point | skills/st-fast/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>` |
| #18 FR-001 fast diff point | skills/st-fast/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <base from step 1>` |
| #18 FR-002 wait build | skills/st-build/SKILL.md | `in the foreground, with a Bash timeout of 600000 ms, and wait for it. No background run, no polling.` |
| #18 FR-002 wait inspect | skills/st-inspect/SKILL.md | `in the foreground, with a Bash timeout of 600000 ms, and wait for it.` |
| #18 FR-002 wait fast | skills/st-fast/SKILL.md | `in the foreground, with a Bash timeout of 600000 ms, and wait: hidden regressions?` |
| #18 FR-005 revise | skills/st-build/SKILL.md | `Two rounds at most per point per gate pass, then the user decides.` |
| #18 FR-005 revise | skills/st-build/SKILL.md | `Then run the same point once more on the changed input.` |
| #18 FR-006 blocked | skills/st-build/SKILL.md | `stop and show the user the reason. Nothing passes the gate.` |
| #18 FR-006 blocked | skills/st-build/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh continued <point> <feature dir>` |
| #18 FR-007 record | skills/st-build/SKILL.md | `Each run appends a record to `<feature dir>/advisor.md`` |
| #18 FR-008 stale build | skills/st-build/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh check diff <feature dir> <base>` |
| #18 FR-008 stale build | skills/st-build/SKILL.md | ``advisor approval is stale` or `no record` counts as no approval` |
| #18 FR-008 stale inspect | skills/st-inspect/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh check plan <feature dir>` |
| #18 FR-008 stale fast | skills/st-fast/SKILL.md | `bash <plugin root>/scripts/st-advisor.sh check diff <feature dir> <base from step 1>` |
| #18 FR-010 modes | skills/st-build/SKILL.md | `The mode comes from `.stratum/advisor.json` (`codex`, `both` or `off`).` |
| #18 FR-010 modes | skills/st-build/SKILL.md | `First line `mode both: also consult /advisor if one is set`` |
| #18 FR-010 no file | skills/st-build/SKILL.md | `No file means off, with the `mode not set` line.` |
| #18 FR-010 no file | README.md | `With no file the advisor is off and prints `no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".`` |
| #18 FR-010 no file | README.md | `A project set up before this feature has no file, so the advisor stays off until you write it.` |
| #18 FR-011 no codex | skills/st-build/SKILL.md | ``no advisor: mode not set` (show the user its line) or `no advisor: mode off`: go on as before` |
| #18 FR-011 no codex | skills/st-build/SKILL.md | ``no advisor: codex not found`, `no advisor: mode not set`` |
| #18 FR-012 review only | skills/st-build/SKILL.md | `Never run `codex` to build or fix.` |
| #18 FR-016 inspect rules | skills/st-inspect/SKILL.md | `Handle its answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md`` |
| #18 FR-016 fast rules | skills/st-fast/SKILL.md | `Handle each advisor answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md` (verdicts, rounds, modes, record, no Codex)` |
| #18 FR-015 init | skills/st-init/SKILL.md | `If `.stratum/advisor.json` is missing, ask the user in one question: advisor mode `codex` (recommended` |
| #18 FR-015 init | skills/st-init/SKILL.md | `Write `.stratum/advisor.json` as `{"mode": "<answer>"}`.` |
| #18 FR-016 readme | README.md | `The orchestrator runs `scripts/st-advisor.sh` in the foreground and waits for the answer.` |
| #18 FR-016 readme | README.md | `Codex runs in the read-only sandbox and only reviews: it never builds or fixes.` |
| #18 FR-016 readme | README.md | `What leaves the machine: each call sends the prompt and the files Codex reads to OpenAI` |
| #18 FR-016 readme | README.md | ``"mode": "off"` is the off switch: nothing goes to OpenAI.` |
| #18 FR-016 readme | README.md | `With no `codex` on PATH you get one line, `no advisor: codex not found`` |
| #18 FR-016 readme | README.md | `A failed, empty, malformed or late answer (540 seconds) is `BLOCKED`, never approval.` |
| #18 FR-016 readme | README.md | `An approval of a plan or diff that changed since then is stale.` |
| #18 FR-013 readme | README.md | `untracked `.env*`, `*.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `.npmrc`, `.netrc`, `.pypirc` and `credentials*` files (any case) are left out of the list Codex is given` |
| #18 D13 readme | README.md | `Whether Codex's own shell sees your environment variables is not checked.` |
| #18 inspect keep | skills/st-inspect/SKILL.md | `; big ones go to the user before the gate.` |
| #18 FR-014 readme | README.md | `Optional `model` and `effort` keys in the same file pick the Codex model and reasoning effort` |
| #18 FR-014 init | skills/st-init/SKILL.md | `Optional `model` and `effort` keys pick the Codex model and reasoning effort` |
| #18 FR-001 build worktree stop | skills/st-build/SKILL.md | `a subagent whose test is still red after 2 tries stops and reports both failures` |
| #18 L16 commit build | skills/st-build/SKILL.md | `with tasks.md, and `<feature dir>/advisor.md` if it changed.` |
| #18 L16 commit build | skills/st-build/SKILL.md | `then have `st-git` commit `<feature dir>/advisor.md` if it changed.` |
| #18 L16 commit inspect | skills/st-inspect/SKILL.md | `Have `st-git` commit `<feature dir>/advisor.md` if it changed.` |
| #18 L16 commit fast | skills/st-fast/SKILL.md | `with `<feature dir>/advisor.md` if it changed.` |
| #18 L17 debug worktree | skills/st-build/SKILL.md | `Start `st-debug` from the main session too, with the worktree path; it diagnoses, fixes and verifies in that worktree.` |
| #18 exit 2 | skills/st-build/SKILL.md | `Exit 2 with a `usage:` line or `cannot hash inputs`: the script could not read or hash its inputs.` |
| #18 exit 2 | skills/st-build/SKILL.md | `Nothing was recorded and nothing was sent. Fix the input or the tool and run the point again.` |

Plus two checks that are not phrases:

- `#18 FR-001 quick lane`: `! grep -qF st-advisor "$root/skills/st-quick/SKILL.md"`.
- `#18 FR-016 old advisor text gone`: none of these old phrases is left:
  `consult the advisor if one is set` in `skills/st-build/SKILL.md`,
  ``first if one is set (`/advisor`)`` and `advisor is set, consult it on the diff` in
  `skills/st-fast/SKILL.md`, ``If an advisor is set (`/advisor`)`` in `skills/st-inspect/SKILL.md`.
  Each is a `grep -qF` that must find nothing.
