# Research: Codex Advisor

Facts checked on 2026-10-23 against codex-cli 0.163.0 (`/usr/bin/codex`, logged in with ChatGPT,
model `gpt-6-astra`, reasoning `medium` from `~/.codex/config.toml`), Claude Code 2.1.302,
Bash 5.3.20, Python 3.14.8, git 2.56.0, GNU coreutils `timeout` 9.12, and the repo at `f0ac746`
(branch `18-codex-advisor`). Raw outputs of every call are in the session scratchpad
(`.../scratchpad/r/`), not in the repo. Five Codex calls used quota (calls 1, 1b, 3, 4, 5).
Calls 2 and 6 ran logged out and used none.

Facts passed in by the orchestrator and used here: `printf '<prompt>' | codex exec -s read-only
--ephemeral -o <file> -` runs from this worktree with no trust prompt (trivial prompt 5.7 s,
5,871 tokens). Plugin options reach hooks but not the Bash tool (so the mode comes from a file,
D3). A foreground Bash call is capped at 600000 ms.

## R1. `--output-schema` enforces the answer shape

- Decision: pass a JSON Schema with `--output-schema`. The script still checks the answer
  (presence, JSON parse, verdict enum, findings list, REVISE with findings), because FR-004 needs
  a BLOCKED for any answer that is not the agreed shape, whatever Codex does.
- Rationale: two calls with the schema below
  (`{verdict: enum APPROVED|REVISE|BLOCKED, summary: string, findings: [{claim, evidence,
  location, severity: enum CRITICAL|HIGH|MEDIUM|LOW}]}`, every property required,
  `additionalProperties: false`).
  - Call 1: `printf 'Review only. Do not run any command. Is `x = 1 / 0` safe Python? ...' |
    codex exec -s read-only --ephemeral --output-schema schema.json -o out1.json -`. Exit 0. The
    `-o` file is
    `{"verdict":"REVISE","summary":"`x = 1 / 0` raises ZeroDivisionError when executed.","findings":[{"claim":"Division by zero prevents assignment to x.","evidence":"...","location":"x = 1 / 0","severity":"MEDIUM"}]}`.
    `json.load` parses it; keys `findings, summary, verdict`. `tokens used 323`. Wall time not
    captured (`bc` missing).
  - Call 1b, a prompt that asks for the wrong shape: `Reply in plain English prose only, no
    JSON, no braces: name one prime number.` Exit 0, 8,150 ms, 18,191 tokens. The `-o` file is
    still `{"verdict":"APPROVED","summary":"Seven is a prime number.","findings":[]}`. The schema
    wins over the prompt, so the shape is enforced on the server side.
- Alternatives considered: `--json` (JSONL events). Not needed: the `-o` file holds the final
  message alone.

## R2. Failure: exit code, `-o` file, reason line

- Decision: a non-zero exit is `BLOCKED: <reason>`. The reason is the last stderr line that
  starts with `ERROR:`, else the last non-empty stderr line, else `codex exited <rc>`. A missing
  or empty `-o` file is `BLOCKED: empty answer`. The script writes `-o` to a fresh temp path, so
  an old file cannot pass as an answer.
- Rationale: call 2 (no quota used):
  `printf 'hi' | CODEX_HOME=<empty dir> codex exec --ignore-user-config -s read-only --ephemeral
  --output-schema schema.json -o out2.json -`. Exit 1 after 15,983 ms (five websocket retries,
  then five HTTPS retries). No `out2.json` file. Stdout empty. The last stderr line:
  `ERROR: unexpected status 401 Unauthorized: Missing bearer or basic authentication in header, url: https://api.openai.com/v1/responses, cf-ray: ..., request id: req_...`.
  Codex wrote its state databases into the empty `CODEX_HOME`, so a logged-out run is not free of
  side effects in `CODEX_HOME` (the test uses a fake `codex` and never runs the real one).
- Correction to the fact passed in: stdout carries only the final message. The header (model,
  sandbox, session id), the prompt, the commands Codex ran, the reply and `tokens used` go to
  stderr (calls 1, 3, 4).

## R3. Time and tokens per point, and the time limit

| Call | Input | Exit | Wall | Tokens | Files Codex read |
|------|-------|------|------|--------|------------------|
| 3, plan point | prompt naming `specs/006-codex-advisor/spec.md` and `decisions.md` (no plan or tasks exist yet), schema | 0 | 38,396 ms | 36,208 | the two named files, then `skills/st-fast`, `st-init`, `st-build`, `st-inspect` SKILL.md and `README.md` (7 `exec` lines) |
| 4, diff point | prompt naming base `5222692` (`git merge-base main HEAD`), feature dir, schema; diff 25,429 bytes, 5 files | 0 | 38,154 ms | 37,813 | `git diff 5222692...`, the skill files and README, `.stratum/constitution.md` (absent) |
| 5, `codex exec review --base` | see R4 | 0 | 31,146 ms | not printed | parent dirs for `AGENTS.md`, `skills/st-plan/SKILL.md`, `.gitignore` |

- Call 3 answer: `REVISE`, 5 HIGH findings, each a real gap in the spec (see plan.md F1 to F4).
  Call 4 answer: `REVISE`, 3 HIGH findings (feature not built yet, plan hash scope, untracked
  files).
- Test point: not measured. Its input is the task text, a test path and two pasted failure
  outputs, smaller than the plan point's files. Expect the same order (about 40 s).
- Decision: the script runs Codex under `timeout -k 10 540`. A run that hits the limit (exit 124,
  or 137 after the kill) is `BLOCKED: timed out`. The skill text gives the Bash call
  `timeout: 600000`.
- Rationale: the hard cap is 600 s (fact passed in). The Bash tool's default of 120 s is above the
  measured 38 s but below the 540 s limit, so the skill must set 600000. 540 s leaves
  60 s under the cap for the hash, the git commands and the record write (each under a second).
  The measured runs (31 to 38 s on a 25 KB diff) are a floor, not a ceiling: a real feature diff
  is larger and Codex reads more files. 540 s is 14 times the largest measured run.
- Cost: about 36,000 to 38,000 tokens per plan or diff call, on the user's ChatGPT quota. A
  feature with one round at each point uses about 110,000 tokens; two rounds at each point about
  220,000.
- `timeout` is GNU coreutils. Stock macOS lacks it. The repo already relies on GNU tools in the
  same way (`sha256sum` and `xargs -0 -r` in `skills/st-triage/SKILL.md:14`). Without `timeout`
  the call fails with exit 127 and the script prints `BLOCKED: <the shell's error line>`: visible,
  never approval.

## R4. Diff point: plain `codex exec`, not `codex exec review` (issue Q6)

- Decision: plain `codex exec` with the diff prompt and the schema, at every point.
- Rationale: call 5:
  `codex exec -s read-only review --ephemeral --base 5222692dc69b79c6c3110419e46969ff63ace6c6 -o out5.txt < /dev/null`.
  It runs with no human step, exit 0, 31,146 ms. `-s` is accepted before `review` and stderr shows
  `sandbox: read-only`. The prompt it sends is fixed (`changes against '<sha>'`). The `-o` file is
  one line of prose: `The changes add the Codex advisor specification and review checklists, and
  move workflow state to its planning phase. No executable behavior changes or actionable
  regressions were identified.` No verdict, no findings list. Plain `codex exec` on the same
  diff (call 4) returned a verdict and three findings in the schema. With review, the review-only
  and no-secrets rules could ride only as an added prompt, and the verdict would need a second
  parse. `review` also has `--output-schema`, but it gives nothing exec does not.
- Alternatives considered: `codex exec review --base` (above, rejected). `--uncommitted` and
  `--commit` not tried: the diff point needs a base, and the Fast lane diff is uncommitted plus
  committed.

## R5. Codex reads more than the named inputs

- Decision: the prompt tells Codex to read only the named inputs and the files they cite and
  never to open env or secret files (FR-013). The README says each call sends the prompt and
  "the files Codex reads", not "the named files".
- Rationale: in calls 3 to 5 Codex read files the prompt did not name: skill files, README,
  `.gitignore`, and in call 5 `find .. -name AGENTS.md` and a read of `/AGENTS.md`, `/home/AGENTS.md`,
  `/home/hyuse/AGENTS.md` and `/home/hyuse/Desktop/AGENTS.md`, all above the repo. The read-only sandbox blocks writes, not reads (spec Assumptions, D6). The
  prompt is the only guard on reads.

## R6. Hash input per point (FR-007) and two gaps in the spec wording

- Plan point: SHA256 of the bytes of `<feature>/spec.md`, `<feature>/plan.md` and
  `<feature>/tasks.md` joined in that order (D10, FR-007 as amended). Codex call 3 flagged that
  the plan point reviews all three while the first FR-007 hashed plan.md alone, so an edit to
  spec or tasks kept the approval (plan.md F1, resolved).
- Test point: SHA256 of the bytes of the first failure output followed by the bytes of the
  second, no separator.
- Diff point, secret-looking untracked files (D12, FR-013): the `Untracked files:` list in the
  prompt leaves out each path whose basename matches `.env*`, `*.pem`, `*.key`, `*.p12` or
  `*.pfx`. They stay in the hash, so adding one still makes an approval stale. The prompt also
  says `Never quote a secret value in a finding.` Codex can still run `git status` and read such a
  file (the sandbox blocks writes, not reads, R5); the list and the prompt line lower the chance,
  they do not block it.
- Diff point (D9, FR-007 as amended), gap 1 (the record changes the diff): `git diff <base>` includes
  `specs/<feature>/advisor.md` once it is tracked, so appending the record would make every diff
  approval stale. The diff input excludes it:
  `git diff <base> -- . ':(exclude)<feature>/advisor.md'`.
- Diff point, gap 2 (untracked files): the Fast lane runs the diff point before its commit, and
  `git diff <base>` omits new files. The diff input adds, for each path from
  `git ls-files -z --others --exclude-standard -- . ':(exclude)<feature>/advisor.md'`, the output of
  `git diff --no-index -- /dev/null <path>` (the pattern of `scripts/st-verify.sh:12`). The prompt
  lists those paths so Codex reads them.
- Proof in a scratch repo (no Codex): the hash of the empty input (`e3b0c44298fc...`) stayed the
  same after a line was appended to the tracked `specs/f/advisor.md`, changed when an untracked
  `new file.txt` (with a space) appeared, and changed again when a tracked file was edited.
- Second proof, `advisor.md` never committed (the Fast lane's first run): the hash stayed
  `e3b0c44298fc...` after an untracked `specs/f/advisor.md` was created and after a line was
  appended to it, while `git ls-files --others --exclude-standard` (no pathspec) listed it. The
  `:(exclude)` pathspec works on `ls-files --others` too.
- Hashing uses `sha256sum`, like `skills/st-triage/SKILL.md:14`.

## R7. Full lane base commit for the diff point

- Decision: the same rule as `skills/st-close/SKILL.md:21-23`. On a branch, the base is
  `git merge-base main HEAD`. On `main`, it is
  `git rev-parse "$(git log --diff-filter=A --format=%H -- <feature dir>/spec.md | tail -1)^"`.
  The Fast lane keeps its step 1 base (`git rev-parse HEAD`).
- Rationale: `skills/st-build/SKILL.md` notes no base today. st-close already defines the
  feature's base, and the end of build is right before Close. `merge-base` instead of st-close's
  bare `main`, so commits that land on main after the branch point are not counted.
- The script resolves the base with `git rev-parse --verify --quiet "<base>^{commit}"` and puts
  the full SHA it gets back into the prompt and the record.

## R8. JSON and mode parsing with no new dependency

- Decision: inline `python3 - <<'PY'` heredocs inside `scripts/st-advisor.sh` read the `-o` file,
  check the verdict and findings, format the finding lines, and read `.stratum/advisor.json`
  (`mode`, `model`, `effort`). No separate Python file.
- Rationale: `jq` is installed here but no Stratum script uses it and `skills/st-status/SKILL.md`
  step 4 does not list it, so it would be a new dependency. `python3` is already required
  (`hooks/st-handoff-facts.sh:8`, `statusline/st-statusline.sh:10`, the Python hooks). Files are
  read as bytes and decoded by `json.loads` (lessons L3).

## R9. How st-init asks a one-question step

- D11: a missing file means off (`no advisor: mode not set. Write .stratum/advisor.json with
  "mode": "codex", "both" or "off".`, exit 0). So st-init's step is how new projects get the
  file; projects set up before this feature have none and keep the old flow until the owner
  writes it.
- Decision: the new step copies step 3 (git guard): "If `<file>` is missing, ask the user in one
  question: ... (recommended) or ...", then write the file. It goes after step 10 (tool check) as
  step 11. The Report step becomes 12 and lists `.stratum/advisor.json` among the committed files.
- Rationale: `skills/st-init/SKILL.md:15-20` (git guard) and `:21-28` (models) both open with a
  missing-file test, then one question with the recommended answer named, then the write. Step 2's
  ignore list holds per-machine files (`git-guard.json`, `models.json`). `advisor.json` is a
  project privacy switch set by the project owner (US4), so it is committed, not ignored. The only
  test that reads st-init step numbers reads step 2 (`tests/test_model_files.sh:23`), so adding
  step 11 breaks no test.

## R10. Mode file is committed: threat check (lessons L5)

- A committed `.stratum/advisor.json` is input anyone with push access controls. It sets the
  mode (`codex`, `both` or `off`; no file means off, D11) and, since D8, an optional `model` and
  `effort` that reach Codex as `-m <model>` and `-c model_reasoning_effort="<effort>"`. No path
  and no other flag comes from it. A committed `model` can choose which OpenAI model gets the
  project's files and how much quota a call costs. The `fullmatch` patterns in R11 keep a value
  from becoming another flag or adding TOML. Anything else is `BLOCKED: bad advisor.json`.
- `specs/<feature>/advisor.md` is committed too. A forged record with the right hash would pass
  the stale check: the hash ties a verdict to an input, it does not prove who wrote the record.
  Accepted; named in plan.md S4.

## R11. Model and effort from `.stratum/advisor.json` (FR-014, D8)

- Decision: when the file sets `model`, the call adds `-m <model>`. When it sets `effort`, the
  call adds `-c model_reasoning_effort="<effort>"` (one argv element). Without the keys neither
  flag is passed and Codex uses the user's `~/.codex/config.toml`. `model` must pass Python
  `re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}", v)` and `effort`
  `re.fullmatch(r"[a-z]{1,16}", v)`. Anything else, a non-string value, a file with no `mode`,
  or a key other than `mode`, `model`, `effort` is `BLOCKED: bad advisor.json`.
- `fullmatch`, not `re.match` with `^...$` (inspect F2): in Python `$` also matches before a
  final newline, so `"high\n"` would pass `re.match(r"^[a-z]{1,16}$", v)` and put a newline
  into the `-c` value. The T007 bad list holds `"high\n"` and `"x\n"` for that reason.
- Rationale: call 6 (logged out, no quota):
  `printf 'hi' | CODEX_HOME=<empty dir> timeout 60 codex exec --ignore-user-config -m gpt-6-astra -c model_reasoning_effort="bogus" -s read-only --ephemeral -o o6.json -`.
  Exit 1 after 17,001 ms (401, as in R2). The stderr header shows `model: gpt-6-astra` and
  `reasoning effort: bogus`: both flags are applied, and Codex does not check the effort value on
  the machine. So a wrong `model` or `effort` reaches OpenAI and comes back as a Codex error, which
  the script prints as `BLOCKED: <codex error line>`. Stratum checks the shape only: the set of
  efforts and models that 0.163.0 accepts is not listed in `codex exec --help`, and a fixed list
  would go stale.
- Threat (lessons L5): the file is committed. A value that starts with `-` could be read as a
  flag (for example a `model` of `--dangerously-bypass-approvals-and-sandbox`), and an `effort`
  with `"` or a newline could add TOML to the `-c` value. The shape rules stop both: `model`
  starts with a letter or digit and holds no space or quote, `effort` is lowercase letters only.
  The values reach `codex` as quoted argv, never through a shell string.
- Alternatives considered: `-c model="<model>"` in place of `-m`. Not used: `-m` is the
  documented flag and needs no TOML quoting.
