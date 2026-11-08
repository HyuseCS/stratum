# Research: st-research, a research step that runs alone

Facts checked on 2026-11-08 against Claude Code 2.1.319, node v24.14.1, and the repo at
`80cc118` (branch `worker-f80`). Decisions D1 to D10 are in [decisions.md](decisions.md).

## R1. One skill, one agent, one procedure

- Decision: add `skills/st-research/SKILL.md`, `agents/st-research.md` and
  `procedures/research.md`. The agent follows the procedure. The skill builds the brief, checks
  the path and the git state, and starts the agent.
- Rationale: D1 names all three. The pair works like `skills/st-triage/SKILL.md` and
  `agents/st-triage.md`. `tests/test_on_demand.sh:50-51` already fails when an agent has no skill
  of the same name.
- Alternatives considered: change `st-plan` Phase 0 to follow the new procedure (D1, rejected).

## R2. Agent tools and model

- Decision: `tools: Read, Grep, Glob, Bash, Write, Edit, WebSearch, WebFetch`, `model: opus`.
- Rationale: Write and Edit write the one research file and add a round. Bash runs `git log` and
  `git show`, and a build or a test only when the brief allows it (FR-008). `WebSearch` and
  `WebFetch` are Claude Code's built-in web tools (D10, FR-010). Installed agents name them the
  same way (`tools: Read, Write, WebFetch, WebSearch` in the plugin cache under
  `~/.claude/plugins/cache/`). Opus is the spec's assumption, the same as `agents/st-triage.md:5`.
- Alternatives considered: no Bash. Rejected: commits are code facts (FR-003) and need `git log`.
  With Bash and Write the tool list cannot stop a second write. The skill's before-and-after git
  check finds it (R6).

## R3. Autonomous flag format on main

- Decision: autonomous build mode is on for this session when the main checkout's
  `.stratum/autonomous` exists and its first line equals `$CLAUDE_CODE_SESSION_ID`.
- Rationale: `skills/st/SKILL.md:89` writes the session id to
  `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/autonomous`.
  `scripts/st-worker.sh:67-68` reads it the same way. Issue #77 ("Autonomous build mode: let more
  than one worktree session be on at the same time") is OPEN on 2026-11-08, so this is the format
  on main. Quickstart Q8 checks main again before the PR (FR-002).
- Alternatives considered: read `.stratum/state.json`. Rejected: state.json holds no autonomous
  key.

## R4. Output path and the project root

- Decision: the skill picks the path in the FR-004 order, then runs
  `p=$(realpath -m -- '<path>') && case "$p" in "$(realpath .)"/*) true ;; *) false ;; esac`
  from the project root. Exit 1: stop with one line. A path with a `'` in it: stop.
  The agent writes only the path in the brief and checks it again.
- Rationale: `realpath -m` resolves `..` and symlinks, also for a path that does not exist yet,
  so `../x.md` and a link to outside the project both fail (FR-005). The skill computes the path
  so it can show it with the questions before the OK.
- Alternatives considered: the agent picks the path. Rejected: the user would not see the path
  before the OK.

## R5. Telling a st-research file from a Plan file

- Decision: a new research file starts with `# Research: <topic>`, then the line
  `Written by: st-research`, then `## Round 1`. `procedures/plan.md` Phase 0 checks for that
  line.
- Rationale: Plan's own `research.md` also starts with `# Research:`
  (`specs/005-st-triage/research.md:1`). One fixed line is a check that a grep can make.
- Alternatives considered: detect `## Round` headings. Rejected: weaker, a Plan file could hold
  the word.

## R6. Proof that only the research file changed

- Decision: the skill notes `git rev-parse HEAD`, `git status --porcelain --untracked-files=all`
  and `git ls-files -z --modified --others --exclude-standard | xargs -0 -r sha256sum` before and
  after the agent. Any change except the output path is a finding to show.
- Rationale: the same three commands as `skills/st-triage/SKILL.md:12,15` (SC-003). The
  `sha256sum` line sees an edit to a file that was already changed.
- Alternatives considered: trust the agent's report. Rejected: an agent's own summary is not
  evidence.

## R7. Feature folder made during the grill

- Decision: `skills/st-define/SKILL.md` step 1 makes `specs/<NNN>-<short-name>` when the grill
  needs research, and passes `<folder>/research.md`. `procedures/specify.md` step 2 uses a folder
  that Define made in this run and makes no second one.
- Rationale: `hooks/st-phase.py:137-141` sets `feature_directory` only for a new folder (not in
  `define_before`) that holds `spec.md`. The early folder has no `spec.md` until Specify writes it,
  then the hook records it. No hook change is needed. `tests/test_state.sh` S4 pins the
  `.stratum/state.json` sentence of specify step 2, and S9 pins
  `The Stratum hook records the new folder as` in st-define step 2. Both stay whole.
- Alternatives considered: write to `.stratum/research/` and move it in Specify (D7 O15,
  rejected).

## R8. Files the existing tests force outside the worker's file list

A new `agents/*.md` file and a new `.stratum/research` name trip these checks (all green on
`80cc118`):

| File | Check that fails without the edit |
|------|-----------------------------------|
| `tests/test_inspect.sh:89` | `check "15 agents"`: the count becomes 16 |
| `tests/test_model_hook.py:219-221` | `test_module_constants` pins the agent list; `hooks/st-models.py:8` reads `agents/` |
| `skills/st-model/SKILL.md:10-11` | `tests/test_model_files.sh:42`: every agent name in the file |
| `DESIGN.md` D13a table (line 190) | `tests/test_local_files.sh:5-10`: `.stratum/research` needs a row |
| `docs/harness/model/data.c4` | `tests/test_harness_model.sh` `coverage-data`: `.stratum/research` needs a `data` element |
| `docs/harness/README.md` | `tests/test_harness_model.sh` `rebuild`: diff against `likec4 export markdown`; the `agents` view (`docs/harness/views/5-agents.c4:4`) includes `agents.*` |

Consistency edits that no test forces: `skills/st-init/SKILL.md:26` ("15 agents"),
`tests/test_inspect.sh:97` (pins that phrase), `DESIGN.md` D7 agent table and D9 skill table
("Twenty-six entry skills").

## R9. Harness model and atlas

- Decision: `agents.st-research` in `docs/harness/model/agents.c4`, `skills.st-research` in
  `docs/harness/model/skills-core.c4`, `procedures.research-md` in
  `docs/harness/model/procedures.c4`, each with one summary and its links. In
  `docs/harness/atlas/data.mjs`: the skill in structure T, the agent in A, the procedure in R.
  Then rebuild `atlas.html` and `SYSTEM.md` with the README build line and regenerate
  `docs/harness/README.md` with `npx -y likec4@1.60.0 export markdown docs/harness`.
- Rationale: `tests/test_harness_model.sh` `coverage-*` needs an element per skill, agent and
  procedure path; `atlas` needs each harness file in exactly one structure's `how`; `summaries`
  needs one summary of 1 to 200 characters and at most 2 sentences; `views-common` forbids
  backticks in `.c4`. No `web` actor: actors live in `0-spec.c4`. `5-agents.c4` includes
  `agents.*` and needs no edit. `~/.claude/skills/system-atlas/assets/build.mjs` exists.
- Alternatives considered: a research step in the `full-define` view of `1-full.c4`. Not done:
  FR-017 asks only that the agent and skill are listed, and a new step renumbers every later
  `(n)` label.

## R10. Test file

- Decision: new `tests/test_research.sh` in the style of `tests/test_on_demand.sh`: frontmatter
  checks, a phrase table (contracts/st-research.md section 6), and two behavior checks that run
  the skill's own autonomous command and path command in a temp git repo.
- Rationale: the house tests for skill and agent text are phrase checks. The two shell commands
  can be run, so they get a real check with a negative control.
  `tests/test_test_scope.sh:16` fails on the words `full suite` or `full test suite` in a skill,
  agent or procedure; the new text avoids them. `tests/test_on_demand.sh:53` fails on a bare
  `` `st-research` (`stratum: `` pair; the skill writes "Start one `st-research` subagent
  (`stratum:st-research`)". `tests/test_session_hooks.sh:40-43` needs
  "Start your report with `[st-research]` on its own line." in the agent.
- Alternatives considered: add `st-research` to the agent loop at `tests/test_on_demand.sh:56`.
  Rejected: its `FR-007 no edit tools` check fails for an agent that has Write.
