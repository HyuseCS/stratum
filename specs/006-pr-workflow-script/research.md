# Research: Ultracode Workflow Script for st-pr

Checked on 2026-10-23 against Claude Code 2.1.302 (`/opt/claude-code/bin/claude`), node v24.14.1,
GNU bash 5.3.20, git 2.56.0, gh 2.102.0. No package is added.

## R1. How the Workflow tool runs a script file

- Decision: `workflows/pr.js` starts with `export const meta = {...}` as a pure literal, then a
  plain JavaScript body that uses top-level `await` and ends with a top-level `return`. The body
  never reads `meta`.
- Rationale: the binary parses the script with `sourceType: "module"`,
  `allowAwaitOutsideFunction: true`, `allowReturnOutsideFunction: true`. The first statement must
  be `export const meta = { name, description, phases }`, else the error is
  "`export const meta = { name, description, phases }` must be the FIRST statement in the
  script". Meta may hold no variables, calls, spreads, computed keys or template interpolation.
  The body that runs is the text after the meta statement (`scriptBody: L(e, a.end)`), so `meta`
  is not in scope at run time.
- Alternatives considered: TypeScript (fails to parse), a `function main()` export (not how the
  runtime calls it).

## R2. The Workflow call returns at once; the result comes later

- Decision: st-pr calls `Workflow({scriptPath, args})`, then waits for the task notification of
  that run, and reads `{title, bodyPath, warnings, blocked}` from it. Any other shape, or no
  notification, is "no `bodyPath`": st-pr falls back to the current path.
- Rationale: the tool text in the binary says "Workflows run in the background. This tool
  returns immediately with a task ID, and a <task-notification> arrives when the workflow
  completes." The exact payload text of the notification was not seen here. The fallback covers
  a shape we did not expect. If the tool result already holds the result object, st-pr uses it.
- Alternatives considered: read the result from the tool result (it holds only the task ID).

## R3. "Ultracode is on"

- Decision: Ultracode is on when the latest system-reminder about Ultracode says it is on.
- Rationale: spec FR-002 and D5. The tool text says "Ultracode is on for the session (a
  system-reminder confirms it)" and "When a reminder says ultracode is off, revert". The latest
  reminder wins. The tool also counts the keyword "ultracode" in one prompt (a system message
  confirms it). The spec names only the session reminder, so the skill text does too.
- Alternatives considered: a setting in `.stratum/` (issue #22 says the rule is in the skill text).

## R4. A skill call counts as opt-in

- Decision: the skill text tells the session to call Workflow. No extra question to the user.
- Rationale: the tool text lists "The user invoked a skill or slash command whose instructions
  tell you to call Workflow" as explicit opt-in. Spec Assumptions and D2.

## R5. The script gets the commit list in `args`

- Decision: `args.commits` is the array of lines from
  `git log origin/<base>..HEAD --format='%h %s'`. The script cuts it in chunks of 25 with
  `slice`. One chunk agent per chunk.
- Rationale: the script has no file or git access. A first agent that lists commits would make
  the facts phase wait for it, and FR-005 wants the facts side by side. Step 2 already names
  this command, so the session runs it anyway. A chunk agent gets its exact commit lines, so two
  agents never check the same commit.
- Alternatives considered: pass only the count and let each chunk agent run
  `git log --skip=<n> -n 25` (works, but the session already has the list).

## R6. The Node test runs the script body, not `import()`

- Decision: `tests/test_pr_workflow.mjs` reads `workflows/pr.js` as text, replaces the leading
  `export const meta = ` with `globalThis.meta = `, and runs the text with
  `new (async () => {}).constructor(text)()`. The fakes are set on `globalThis` first.
- Rationale: `import()` of a file with a top-level `return` fails in node v24.14.1 with
  `Illegal return statement` (run in the scratchpad on 2026-10-23). The AsyncFunction run of the
  same file returned `{"r":["a",null],"n":3}` with `parallel` turning a rejected thunk into
  `null`. An AsyncFunction body allows `await` and `return` at its top, as the runtime does
  (R1). `globalThis.meta` lets the test compare `meta.phases` with the `phase()` calls.
- Alternatives considered: dynamic `import()` (fails, see above); a `vm` module (more code for
  the same result).

## R7. How the repo runs its tests

- Decision: two new test files, `tests/test_pr_workflow.mjs` (node) and `tests/test_pr_skill.sh`
  (bash), each listed in the README `## Tests` block.
- Rationale: there is no runner script and no `.github/workflows/`. README lines 281-293 list one
  command per test. `tests/test_inspect.sh` "README tests" (lines 66-73) fails when a
  `tests/test_*` file has no README line or a README line names a missing file. The node test
  copies the frame of `tests/test_token_weather.mjs` (`check(name, fn)`, `process.exit(fails)`).
  The bash test copies the `check` and phrase frame of `tests/test_on_demand.sh` and the
  path-override variable of `tests/test_inspect.sh` (`ST_INSPECT_SKILL`), so a negative control
  can point it at a scratch copy.
- Alternatives considered: add the skill rows to `tests/test_on_demand.sh` (that file guards the
  on-demand agent skills, not st-pr); one node file for both (then the script task and the skill
  task share one test, lessons L6).

## R8. Read-only facts, and what can see a write

- Decision: every facts prompt says "Read only: do not edit, stage, commit, push or install
  anything, and do not run gh." The tests agent runs suites with `PYTHONDONTWRITEBYTECODE=1`.
  st-pr notes `git rev-parse HEAD` and `git status --porcelain --untracked-files=all` before the
  call and compares them after.
- Rationale: workflow agents get the session's CLAUDE.md and the full tool set (tool text:
  "Subagents get the same CLAUDE.md files injected at start that you did"). No tool list stops a
  write. The compare sees a commit, a moved HEAD, and tracked or untracked edits. It does not see
  git-ignored paths, files outside the repo, a push, or a gh call (lessons L10). `.gitignore`
  holds `__pycache__/`, so a Python run does not trip the compare. The plugin's PreToolUse Bash
  hook `hooks/st-git-guard.py` (`hooks/commands.json`) may also fire for workflow agents. That
  was not verified.
- Alternatives considered: `agentType: 'Explore'` (drops the CLAUDE.md files and cannot run
  tests).

## R9. What the publish scan covers

- Decision: the `facts:scan` agent reads every commit's patch and message in
  `origin/<base>..HEAD` (`git log -p --format='%H%n%B' origin/<base>..HEAD`), the file names,
  and the branch name. A secret added and deleted in the range still counts, because the push
  publishes every commit. Each find has `commit`, `path`, `line`, `kind`, `blocking`. It never
  holds the secret or the personal value.
- Rationale: FR-005 "everything the push publishes". The PR body is written later and is shown
  at the gate before anything is posted. The result reaches the session transcript, so it names
  where, not what.
- Alternatives considered: scan only the final diff (misses a secret deleted in a later commit).

## R10. Three refuters, fixers one at a time

- Decision: the three `refute:<lens>` agents run in one `parallel` (read only). Then a plain
  `for` loop with `await` runs one `fix:<lens>` agent per lens that has problems, in lens order.
  A lens with no problems gets no fixer.
- Rationale: FR-008, FR-009, FR-011 (up to 3 fixers). Every fixer edits the same body file, so
  two at once could lose an edit. `parallel` and `pipeline` both start their items at once.

## R11. A dead agent

- Decision: a `null` facts, refuter or fixer result adds `unverified: <label>` to the warnings
  and the run goes on. A `null` draft returns `{title: null, bodyPath: null, warnings,
  blocked: false}`, and st-pr falls back to the current path. A `null` scan is
  `unverified: facts:scan`, not a block (spec edge case).
- Rationale: tool text: agent() "Returns null if the user skips the agent mid-run or the
  subagent dies"; `parallel` "never rejects". Spec Edge Cases.

## R12. Cost

- Decision: no `model` or `effort` option on any agent. Agents per run:
  `5 + ceil(commits / 25) + 1 + 3 + (0 to 3)`. 45 commits: 14 at most. 60 commits: 15 (spec FR-011).
- Rationale: FR-011, D2. The runtime caps concurrent agents at `min(16, CPUs - 2)` and queues the
  rest (10 on this 12-CPU machine). The cap on items per `parallel` call is a value not seen in
  the binary text, so a branch with a very large commit count is unchecked.

## R13. README

- Decision: README gets two lines in `## Tests`. The `st-pr` row in `### Skills` stays.
- Rationale: R7 forces the test lines. The row "Open a draft PR from git facts and the spec;
  ready when CI passes." stays true on both paths, and the spec asks for no README change.

## R14. Which range counts files

- Decision: commits are counted in `origin/<base>..HEAD` and files in `origin/<base>...HEAD`
  (three dots, from the merge base). Spec FR-002 says so since the inspect pass (orchestrator
  decision, inspect F8).
- Rationale: st-pr step 2 already lists files with `git diff origin/<base>...HEAD
  --name-status`, so the size rule and the body count the same files. Two dots would also count
  changes made on the base after the branch left it.

## R15. The `scriptPath` read rule, and the `script` fallback

- Decision (D6): st-pr calls `Workflow({scriptPath: "<plugin root>/workflows/pr.js", args})`
  first. If the tool refuses the `scriptPath`, st-pr reads the file and calls `Workflow` again
  with the same text in the `script` input and the same `args`. The file never changes (SC-005).
- Rationale: the 2.1.302 binary holds the error text verbatim:
  "scriptPath must be a script path this tool returned, or a file you can already read (the
  working directory or a directory you have added): <path>". Next to it: "A session that cannot
  call <tool> cannot load any scriptPath. Pass the whole script inline through <tool>'s `script`
  input instead." An installed plugin lives under `~/.claude/plugins/cache/...`, outside the
  user's project, so a real run can hit this rule (inspect F2). Whether a read of that folder
  is allowed without a prompt was not settled from the minified permission code. Quickstart M5
  runs from a folder outside the plugin and records which call worked.
- Alternatives considered: `scriptPath` only, with a later decision (rejected, D6 O8).
