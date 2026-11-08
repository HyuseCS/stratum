# Stratum harness — System Definition

_**This file is generated from `docs/harness/atlas/data.mjs`.** The interactive atlas is built from the same data. The facts come from the LikeC4 model in `docs/harness/model/` and `docs/harness/views/`._

_Question status: **13 open · 0 resolved**._

## One paragraph

Stratum is a Claude Code plugin that runs a coding task through a lane. You give /st a task in plain words. It picks the Full, Fast, Quick or Design lane, runs skills that start agents, writes the work to files under `specs/` and `.stratum/`, and asks you at each gate. Codex and /advisor give a second opinion at set points, one agent makes every commit, and hooks guard git and track the phase. This atlas groups the 99 skill, agent, hook, statusline, script and procedure files of the LikeC4 model into 24 structures. Its 13 open questions are gaps between harness files.

## Decisions locked

| Axis | Decision | ADR |
|---|---|---|
| Diagram tool | LikeC4: one text model gives many views, keeps the dragged layout and has an MCP server the LLM can query. | decisions.md D1 |
| Page on GitHub | `likec4 export markdown` writes `docs/harness/README.md` with one Mermaid block per view. | decisions.md D2 |
| Detail | Complete: every skill, agent, hook, script and data file, with every link. | decisions.md D3 |
| Test | `tests/test_harness_model.sh` checks coverage, `likec4 validate` and a rebuild with no diff. | decisions.md D4 |
| Gaps in the model | The model shows only what exists. Gaps go in the side note `gaps.md`. | decisions.md D5 |
| MCP server | No `.mcp.json` in the repo. Add the LikeC4 MCP server once per machine with `claude mcp add`. | decisions.md D6 |
| Steps | One element per file. Steps inside a skill stay in its summary. Lane views list their steps by hand. | decisions.md D7 |
| Step numbers | Each lane-view step label starts with `(n)`. A gate has `gate:` after the number. | decisions.md D8 |
| Node version | Keep `likec4@1.60.0` with Node 22.22.3 or later. The checks print SKIP below it. | decisions.md D9 |
| Extra files | A file outside the coverage list that a link needs gets one element. | decisions.md D10 |
| Pinning | Pin only the top package `likec4@1.60.0`. | decisions.md D11 |
| Lane tags | Links carry no lane tags. The lane views are the one source for lane steps. | decisions.md D12 |
| Big lane views | Full and Design lanes have an overview view that clicks through to one view per phase or mode. | decisions.md D13 |
| Atlas | Add this atlas as a fifth user story, to compare with the LikeC4 views. | decisions.md D14 |
| Atlas home | In-tree at `docs/harness/atlas/` and published at one private URL. D19 added its drift check. | decisions.md D15 |
| Atlas questions | The 13 gaps of `gaps.md` are the open questions, each on the structure it touches, not drawn on the map. | decisions.md D16 |
| Atlas files | Only `data.mjs` and the built `atlas.html` and `SYSTEM.md` are committed. `build.mjs` and `template.html` come from the installed skill. | decisions.md D17 |
| Atlas URL | The private URL stays out of the repo, in the session handoff and project memory. | decisions.md D18 |
| Atlas role | Keep both: the atlas is the picture for people and gets a drift check against the model, and the LikeC4 model stays the checked source for the LLM. | decisions.md D19 |
| Atlas license | The atlas template is MIT (NousResearch/hermes-agent system-atlas skill); its notice is in THIRD_PARTY_NOTICES.md and licenses/system-atlas.MIT.txt. | decisions.md D20 |

## Cost model

## Reading order (the atlas chapters)

1. **You and /st** — Strip everything away and this is Stratum: you say a task in plain words, and /st runs it. _(adds U, O)_
2. **The four lanes** — The lane sets how much process a task gets. _(adds L, P, T)_
3. **The spec on disk** — Every step writes to files, so the next step and the next session can read them. _(adds F, S, R)_
4. **The agents that do the work** — Skills plan the work, and agents do it in a fresh context. _(adds A, B, C)_
5. **Gates: asking you first** — Some steps stop and wait for your words. _(adds G, V)_
6. **Second opinion: Codex and /advisor** — At set points, a second model reviews the work before it moves on. _(adds X, K, D)_
7. **Guard rails: hooks** — Claude Code fires events, and hook files act on them before a tool runs. _(adds E, W, H)_
8. **Memory across sessions** — When a session ends, the next one starts where it stopped. _(adds M, N)_
9. **Shipping** — Work leaves the session as commits and a pull request. _(adds Z, I, GH)_
10. **The whole system** — Everything at once, with a flow picker.

## Structures

### You and the lanes

#### U · You

**In one line.** The person who gives the task and agrees at each gate.

**What it does.** You type a task in plain words, answer questions one at a time, and say yes or no at each gate. Nothing is pushed until you say push.

**How it's built.** You start `/st` in Claude Code. The lane views show every step that passes data to you, and each gate step names what you must say. LikeC4 id: `user`.

#### O · Orchestrator /st

**In one line.** The main entry: it picks the lane and risk level, runs the lane and checks what comes back.

**What it does.** You tell /st what you want. It reads where the work stands, picks how much process the task needs, tells you in one line, and then runs that lane. It routes and checks. Other parts do the work.

**How it's built.** `skills/st/SKILL.md`. It reads `.stratum/state.json`, `.stratum/handoff.md` and `graphify-out/GRAPH_REPORT.md`, says the risk level in its Lane line for the phase hook to save, and starts the phase and lane skills, the st-build and st-git agents, /st-worker, /st-pr and /st-handoff. It re-runs tests with `scripts/st-verify.sh`. LikeC4 id: `skills.st`.

**Steps in execution.**

1. **Read** — Feature, phase and lane from .stratum/state.json, and the last handoff.
2. **Pick** — Lane and risk level from the impact areas of the task.
3. **Say** — One line to you: the lane and the risk.
4. **Run** — Start the phase skills or the lane skill.
5. **Check** — Re-run what the agents report with st-verify.sh.
6. **Commit** — Hand the exact files to the st-git agent.

#### L · Lane skills

**In one line.** The four ways a task can run: Full, Fast, Quick and Design.

**What it does.** Full is for a feature: five phases and four gates. Fast is for a small change: one short plan and one gate. Quick is for a one-file edit with no gate. Design builds a screen in one of three modes.

**How it's built.** `skills/st-full` runs Define, Plan, Inspect, Build and Close without lane selection. `skills/st-fast` writes a change plan under `specs/<feature>/changes/` and asks at one gate. `skills/st-quick` has no gate. `skills/st-design` has the new look, autonomous and custom modes, reads `DESIGN.md`, `.impeccable` and `package.json`, checks its tools with `scripts/st-design-check.sh` and drives FigCraft with `scripts/st-figcraft.sh`. LikeC4 ids: `skills.st-full`, `skills.st-fast`, `skills.st-quick`, `skills.st-design`, `scripts.st-design-check-sh`, `scripts.st-figcraft-sh`, and the data `project.design-md`, `project.impeccable`, `project.design`, `project.package-json`.

**Steps in execution.**

1. **Full** — Define, Plan, Inspect, Build, Close, with four gates.
2. **Fast** — Change plan, gate, test first, review, commit, drift fix.
3. **Quick** — One file, no gate, verify, commit.
4. **Design** — Tool check, mode line, then new look, autonomous or custom.

#### P · Phase skills

**In one line.** The five steps of the Full lane: Define, Plan, Inspect, Build and Close.

**What it does.** Define turns your idea into a spec you agree. Plan writes the plan and the tasks. Inspect checks they fit. Build runs each task test first. Close fixes drift between the docs and the code, and asks before a push.

**How it's built.** `skills/st-define`, `skills/st-plan`, `skills/st-inspect`, `skills/st-build`, `skills/st-close`. Each phase starts its agent, and the Full-lane view opens one phase view per phase (`full-define` to `full-close`). LikeC4 ids: `skills.st-define`, `skills.st-plan`, `skills.st-inspect`, `skills.st-build`, `skills.st-close`.

**Steps in execution.**

1. **Define** — Grill, write the spec, clarify, checklist. Gate: you agree the spec.
2. **Plan** — st-plan agent writes plan and tasks. Gate: you answer each open decision.
3. **Inspect** — st-inspect agent checks spec, plan and tasks. Gate: OK to build.
4. **Build** — Per task: failing test, build, verify, commit. Review each story.
5. **Close** — Drift fixes, gaps, lessons, shortcuts. Gate: push.

#### T · Tool skills

**In one line.** Slash commands any lane, or you, can call for one job.

**What it does.** Some check work (review, test, debug, triage). Some set up or tune the project (init, update, status, theme). Some run parallel workers. Eleven come from outside projects: the grill, design helpers, a code graph and the ponytail family that keeps changes small.

**How it's built.** Checks: `skills/st-review`, `st-test`, `st-debug`, `st-triage`. Workers: `skills/st-worker` with `scripts/st-worker.sh` and `scripts/st-worktree.sh`, and `skills/st-herdr-workspace` with its script. Setup: `st-init`, `st-update` with `scripts/st-update.sh`, `st-status`, `st-sync`, `st-template`, `st-constitution`, `st-model`, `st-shape`, `st-theme`. Vendored: `st-grill`, `st-ui-ux`, `st-impeccable`, `st-graphify`, `st-hallmark` and six `st-ponytail` skills. LikeC4 ids: `skills.st-review`, `skills.st-test`, `skills.st-debug`, `skills.st-triage`, `skills.st-worker`, `skills.st-herdr-workspace`, `skills.st-init`, `skills.st-update`, `skills.st-status`, `skills.st-sync`, `skills.st-template`, `skills.st-constitution`, `skills.st-model`, `skills.st-shape`, `skills.st-theme`, `skills.st-grill`, `skills.st-ui-ux`, `skills.st-impeccable`, `skills.st-graphify`, `skills.st-hallmark`, `skills.st-ponytail`, `skills.st-ponytail-review`, `skills.st-ponytail-audit`, `skills.st-ponytail-debt`, `skills.st-ponytail-gain`, `skills.st-ponytail-help`, `scripts.st-worker-sh`, `scripts.st-worktree-sh`, `scripts.st-herdr-workspace-sh`, `scripts.st-update-sh`, and the data `project.graphify-out`, `project.graphify-out-graph-report-md`, `project.design-system`, `project.product-md`, `project.hallmark`.

**Questions.**

- **Q-T1** **Q-T1** /st-model lists st-worker as an agent (`skills/st-model/SKILL.md:11`), but `agents/st-worker.md` does not exist and /st-status says it has no agents file (`skills/st-status/SKILL.md:36`). Should /st-model drop it?
- **Q-T2** **Q-T2** /st-hallmark calls its command /hallmark (`skills/st-hallmark/SKILL.md:3,57`), but the skill name is st-hallmark (`:2`). Should the text say /st-hallmark?
- **Q-T3** **Q-T3** /st-impeccable names `.claude/skills/st-impeccable/scripts` (`skills/st-impeccable/SKILL.md:19,82`), which is not this plugin's layout, and calls /impeccable, not /st-impeccable (`:84,86`). Should the paths and the command name change?
- **Q-T4** **Q-T4** /st-ponytail-help tells you to update and read the upstream ponytail plugin, not Stratum (`skills/st-ponytail-help/SKILL.md:64,70`). Should it point at Stratum?

#### G · Gates

**In one line.** The steps where a lane stops and waits for your words.

**What it does.** A gate names what you must say before the work moves on, like "you agree the spec" or "push". The Full lane has four, Fast has one, Quick has none, and the Design lane has one in its new look and custom modes.

**How it's built.** Not one file: a gate is a lane-view step whose label has `gate:` after the step number (D8). View `full`: (6) you agree the spec, (8) you answer each open decision, (10) OK to build, (13) push. View `fast`: (9) OK on the change plan. View `design`: (6) commit the reference screen, (10) commit the screen and the saved design. Each gate step is between `user` and the lane skill: `skills/st-define`, `st-plan`, `st-inspect`, `st-close` and `st-fast` pass the gate to you, and in the Design lane you pass your answer to `skills/st-design`. LikeC4 views: `full`, `full-define`, `full-plan`, `full-inspect`, `full-close`, `fast`, `design`, `design-new-look`, `design-custom`.

**Steps in execution.**

1. **Agree the spec** — Full lane, end of Define.
2. **Answer each open decision** — Full lane, Plan.
3. **OK to build** — Full lane, end of Inspect.
4. **OK on the change plan** — Fast lane, after the advisor verdict.
5. **Commit the screen** — Design lane, new look and custom modes.
6. **Push** — Full lane, end of Close.

**Questions.**

- **Q-G1** **Q-G1** /st-full names a Plan gate where you answer the open decisions (`skills/st-full/SKILL.md:11`), but the Gate section of /st-plan names no user gate, only the next phase (`skills/st-plan/SKILL.md:36-38`). Is Plan a gate or not?

### Files on disk

#### F · Feature files

**In one line.** The folder of one feature: spec, plan, tasks and the other design files.

**What it does.** Each feature gets its own folder. The spec says what to build, the plan says how, and the tasks list the work with a test for each. The next phase, and the next session, read these files instead of remembering.

**How it's built.** `specs/NNN-feature/`: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `tasks.md`, `checklists/`, `changes/` (Fast-lane plans), `decisions.md` (grill answers), `advisor.md` (advisor records) and `gaps.md`. LikeC4 ids: `project.specs`, `feature.spec-md`, `feature.plan-md`, `feature.research-md`, `feature.data-model-md`, `feature.contracts`, `feature.quickstart-md`, `feature.tasks-md`, `feature.checklists`, `feature.changes`, `feature.decisions-md`, `feature.advisor-md`, `feature.gaps-md`.

**Questions.**

- **Q-F1** **Q-F1** The model declares `specs/NNN-feature/gaps.md` (`docs/harness/model/data.c4:168`), but no skill, agent, procedure, script, hook or template names it. The gap report comes back as findings instead (`procedures/converge.md:29`, `agents/st-close.md:47`). Should a harness file write gaps.md?

#### S · State files

**In one line.** The .stratum folder: where the work stands, the project rules and the local settings.

**What it does.** One small file says which feature, phase, lane and risk level this checkout is on. Beside it sit the project rules, the model choice per agent, and the flags a parallel worker run needs.

**How it's built.** `.stratum/state.json` holds feature, phase, lane and risk. The phase hook `hooks/st-phase.py` writes it and replaces the file in one atomic step. Also `constitution.md`, `APP-constitution.md`, `decisions.md`, `models.json`, `approve/`, `autonomous/`, `commit-mode` and `worker-setup.sh`. LikeC4 ids: `stratum.state-json`, `stratum.constitution-md`, `stratum.app-constitution-md`, `stratum.decisions-md`, `stratum.models-json`, `stratum.approve`, `stratum.autonomous`, `stratum.commit-mode`, `stratum.worker-setup-sh`.

**Questions.**

- **Q-S1** **Q-S1** The st-quick agent sets phase in state.json with no script (`agents/st-quick.md:48`, its tools include Edit, `:4`). Other skills say a `Phase: done` line and the phase hook writes it (`skills/st-close/SKILL.md:58`, `skills/st-fast/SKILL.md:41`). Should it say that line too?

#### R · Procedures and templates

**In one line.** The step files and templates that skills and agents follow to write the feature files.

**What it does.** A procedure is a recipe: how to write a spec, a plan, the tasks, a checklist or a gap report. Templates give each file its shape. A project can keep its own copy of a template, and that copy wins.

**How it's built.** `procedures/`: `specify.md`, `clarify.md`, `checklist.md`, `plan.md`, `tasks.md`, `analyze.md`, `converge.md`, `constitution.md`, `issues.md`. `templates/` with project overrides in `.stratum/templates`, found by `scripts/resolve-template.sh`. `scripts/check-prerequisites.sh` finds the feature folder. `scripts/common.sh` holds shared shell functions. LikeC4 ids: `procedures.specify-md`, `procedures.clarify-md`, `procedures.checklist-md`, `procedures.plan-md`, `procedures.tasks-md`, `procedures.analyze-md`, `procedures.converge-md`, `procedures.constitution-md`, `procedures.issues-md`, `scripts.resolve-template-sh`, `scripts.check-prerequisites-sh`, `scripts.common-sh`, and the data `plugin.templates`, `plugin.templates-spec-md`, `plugin.templates-plan-md`, `plugin.templates-tasks-md`, `plugin.templates-checklist-md`, `plugin.templates-constitution-md`, `plugin.templates-models-json`, `stratum.templates`.

**Questions.**

- **Q-R1** **Q-R1** The tasks steps say tests are optional (`procedures/tasks.md:67`), but every task ends with `Test:` (`procedures/tasks.md:92`) and the st-build agent needs a red test before each build (`agents/st-build.md:40`). Which rule wins?
- **Q-R2** **Q-R2** The specify steps use "the checklist template structure" with no path and no resolve-template.sh call (`procedures/specify.md:80`). Only the spec template is resolved (`procedures/specify.md:38`), though `templates/checklist.md` exists. Should it resolve the checklist template too?

#### M · Handoff

**In one line.** The note that lets the next session start where this one stopped.

**What it does.** At the end of a session, and before Claude Code shrinks its memory, a hook saves the facts: phase, lane, tasks done, branch and recent commits. /st-handoff adds the goal, the decisions and the next step. The next session prints it back at start.

**How it's built.** `skills/st-handoff` and `hooks/st-handoff-facts.sh` (SessionEnd, PreCompact) write `.stratum/handoff.md`. `hooks/st-session-start.sh` prints it with the rules of `sr-opus-5.md`, and in a worktree links the shared .stratum files. Close lessons wait in `.stratum/lessons.md`. LikeC4 ids: `skills.st-handoff`, `hooks.st-handoff-facts-sh`, `hooks.st-session-start-sh`, `stratum.handoff-md`, `stratum.lessons-md`, `plugin.sr-opus-5-md`.

**Steps in execution.**

1. **Save facts** — SessionEnd or PreCompact: phase, lane, tasks, branch, commits.
2. **Write** — /st-handoff: goal, where we are, decisions, next step.
3. **Print back** — SessionStart: rules and the last handoff.

### Agents

#### A · Plan and check agents

**In one line.** Agents that write the plan, check it, or check an issue, and report back.

**What it does.** The plan agent writes the plan and the tasks, and stops with the decisions it cannot settle. The inspect agent checks that spec, plan and tasks agree. The triage agent checks a GitHub issue against the code.

**How it's built.** `agents/st-plan.md` follows `procedures/plan.md` and `procedures/tasks.md`. `agents/st-inspect.md` follows `procedures/analyze.md` and writes only the Validate section of `plan.md`. `agents/st-triage.md` reads the issue with `gh issue view`. LikeC4 ids: `agents.st-plan`, `agents.st-inspect`, `agents.st-triage`.

#### B · Build agents

**In one line.** Agents that write the failing test, make it pass, fix it, review it, or build a screen.

**What it does.** One agent writes a test that fails first. Another writes the code until it passes and never commits. A third finds the root cause when a test stays red after two tries. A reviewer reads the diff. The design agent builds a screen from the design file.

**How it's built.** `agents/st-test.md`, `agents/st-build.md`, `agents/st-debug.md`, `agents/st-review.md`, `agents/st-design.md`. LikeC4 ids: `agents.st-test`, `agents.st-build`, `agents.st-debug`, `agents.st-review`, `agents.st-design`.

**Steps in execution.**

1. **Test** — st-test writes the task test and shows it fails.
2. **Build** — st-build writes code until the test passes and ticks the task.
3. **Debug** — st-debug finds the root cause after 2 red tries.
4. **Review** — st-review reads the story diff and lists findings.

**Questions.**

- **Q-B1** **Q-B1** The st-build agent gives the Fast-lane path as `changes/NNN-name.md` with no feature folder (`agents/st-build.md:20`), but /st-fast and the st-fast agent put it under `specs/<feature>/changes/` (`skills/st-fast/SKILL.md:14`, `agents/st-fast.md:40`). Which path is right?

#### C · Lane and close agents

**In one line.** Agents that write a Fast-lane plan, make a Quick edit, close a feature, or audit in the background.

**What it does.** The fast agent writes one short change plan. The quick agent makes one small edit. The close agent makes the docs match the code, gives the gap report when asked, and proposes lessons. Three more run audits in the background and change no file.

**How it's built.** `agents/st-fast.md`, `agents/st-quick.md`, `agents/st-close.md` (which runs `scripts/st-shortcuts.sh` for the shortcut list), `agents/st-impeccable.md`, `agents/st-ponytail-audit.md`, `agents/st-ponytail-debt.md`. LikeC4 ids: `agents.st-fast`, `agents.st-quick`, `agents.st-close`, `agents.st-impeccable`, `agents.st-ponytail-audit`, `agents.st-ponytail-debt`, `scripts.st-shortcuts-sh`.

**Questions.**

- **Q-C1** **Q-C1** /st-close says it records defer and drop in spec.md (`skills/st-close/SKILL.md:32`), but the st-close agent only returns the list and has no record step (`agents/st-close.md:47-48`). Who writes the record?

### Checks and second opinions

#### V · Verify and lock

**In one line.** Re-runs a test after an agent says it passed, and keeps shared runs to one at a time.

**What it does.** An agent can say "green" and be wrong. The verify script runs the test again and also fails when new code has explanation comments. The lock makes a second test run wait while the first one uses the shared test or Codex tab.

**How it's built.** `scripts/st-verify.sh` prints one PASS or FAIL line. `scripts/st-lock.sh` makes a lock folder `.git/stratum-NAME.lock` in the git common folder. LikeC4 ids: `scripts.st-verify-sh`, `scripts.st-lock-sh`, and the data `project.git-stratum-name-lock`.

#### X · Advisor script

**In one line.** Runs one advisor point: picks the reviewers, sends the review and records the verdict.

**What it does.** At set points (the plan, a Fast-lane change, a test still red after two tries, the small decisions, the final diff) the work goes out for review. The advisor mode decides who reviews: auto, Codex, both or off.

**How it's built.** `scripts/st-advisor.sh` reads the mode in `.stratum/advisor.json` and the risk level, sends the prompt to Codex headless with `codex exec` read-only, or through `scripts/st-codex-agent.sh` in a herdr Codex tab under the lock, and appends each verdict to `specs/NNN-feature/advisor.md`. LikeC4 ids: `scripts.st-advisor-sh`, `scripts.st-codex-agent-sh`, `stratum.advisor-json`.

**Steps in execution.**

1. **Pick** — Advisors from the mode and the risk level.
2. **Send** — Review prompt and answer schema to Codex, read-only.
3. **Read** — Answer JSON: verdict, summary and findings.
4. **Record** — Point, time, input hash and verdict in advisor.md.

#### K · Codex

**In one line.** A second model from OpenAI that reviews the work and never changes it.

**What it does.** Codex reads what it is sent and answers with a verdict and findings. It runs in a read-only sandbox, so it cannot build or fix anything.

**How it's built.** The `codex` CLI, run with its own home `~/.local/state/stratum/codex-home` that links your Codex login and marks each project untrusted. LikeC4 ids: `codex`, `outside.local-state-stratum-codex-home`, `outside.codex-auth-json`.

#### D · /advisor

**In one line.** The reviewer model you set in Claude Code, asked at the same points as Codex.

**What it does.** If you set a reviewer with /advisor, the Build phase and the Fast lane give it the same input they give Codex: a red test, the diff, the list of small decisions.

**How it's built.** Set by you with `/advisor` in Claude Code, not a plugin file. `skills/st-build` and `skills/st-fast` pass it the same input as Codex at each advisor point. LikeC4 id: `advisor`.

### Hooks and status line

#### E · Hook events

**In one line.** The moments Claude Code announces, and the list of which hook runs at each.

**What it does.** Claude Code calls out moments like "a tool is about to run", "a session starts" or "you sent a prompt". Stratum lists which hook file runs at each one. Claude Code also runs the status line command named in its settings, with no hook event.

**How it's built.** `hooks/commands.json` binds each event and tool matcher to its hook commands. `hooks/hooks.json` lists the hook module `token-weather.mjs`. Events: PreToolUse, PermissionRequest, SessionStart, SubagentStart, UserPromptSubmit, SessionEnd, PreCompact. LikeC4 ids: `claude`, `events.pre-tool-use`, `events.permission-request`, `events.session-start`, `events.subagent-start`, `events.user-prompt-submit`, `events.session-end`, `events.pre-compact`, `hooks.commands-json`, `hooks.hooks-json`.

**Steps in execution.**

1. **SessionStart** — Handoff, communication rules and ponytail rules.
2. **UserPromptSubmit** — Ponytail mode and the reply label for the phase.
3. **PreToolUse** — Git guard on Bash, model on Agent, phase on Skill, approve lock on file tools.
4. **PermissionRequest** — The approve hook answers for a worker.
5. **SubagentStart** — Ponytail rules for the subagent.
6. **SessionEnd and PreCompact** — Save the handoff facts.

#### W · Git guard

**In one line.** Reads each shell command and asks or denies commits, pushes and destructive git.

**What it does.** Before any shell command runs, the guard looks for git words. Depending on the project setting it asks you, or refuses, so a commit or a push never happens by surprise.

**How it's built.** `hooks/st-git-guard.py` runs on PreToolUse with matcher Bash and reads the commit mode, destructive git modes and guarded branch from `.stratum/git-guard.json`. LikeC4 ids: `hooks.st-git-guard-py`, `stratum.git-guard-json`.

#### H · Approve, phase and model hooks

**In one line.** Hooks that track the phase, set each agent's model, and answer permissions for workers.

**What it does.** When a phase skill starts, one hook writes the phase down and warns if it is out of order. Another sets the model and effort of each agent from the project settings. A third stops workers from touching files they do not own and, in an autonomous run, lets the orchestrator answer their permission requests.

**How it's built.** `hooks/st-phase.py` (PreToolUse matcher Skill|Agent, PostToolUse matcher Bash|Write|Edit|MultiEdit|Agent, Stop, and every prompt) writes `.stratum/state.json`: phase, lane and skill, risk, the new feature folder, phase done and the label clear. `hooks/st-models.py` (matcher Agent) reads `.stratum/models.json`. `hooks/st-approve.py` (file tools and every PermissionRequest) reads `.stratum/approve` and `.stratum/autonomous`. LikeC4 ids: `hooks.st-phase-py`, `hooks.st-models-py`, `hooks.st-approve-py`.

#### N · Statusline and ponytail

**In one line.** The status bar under the prompt, and the ponytail rules that keep changes small.

**What it does.** The status line shows the model, git, commit mode, ponytail level, the autonomous flag and the Token Weather line about how full the context is. Ponytail hooks give every session and subagent the "smallest change that works" rules and track the level you set.

**How it's built.** `statusline/st-statusline.sh` merges `statusline/powerline.json`, `statusline/themes.json` and `.stratum/powerline.json`. `hooks/token-weather.mjs` writes `.stratum/weather.json`. `hooks/ponytail/` holds eight files that set, track and pass on the live mode. LikeC4 ids: `statusline.st-statusline-sh`, `statusline.powerline-json`, `statusline.themes-json`, `hooks.token-weather-mjs`, `hooks.ponytail-activate-js`, `hooks.ponytail-config-js`, `hooks.ponytail-instructions-js`, `hooks.ponytail-map-js`, `hooks.ponytail-mode-tracker-js`, `hooks.ponytail-runtime-js`, `hooks.ponytail-statusline-sh`, `hooks.ponytail-subagent-js`, and the data `stratum.powerline-json`, `stratum.weather-json`, `outside.claude-ponytail-active`, `outside.claude-ponytail-modes`, `outside.config-ponytail-config-json`.

**Questions.**

- **Q-N1** **Q-N1** ponytail-activate.js copies `ponytail-statusline.ps1` on Windows (`hooks/ponytail/ponytail-activate.js:106`), but `hooks/ponytail/` has no such file, and the catch at `:165` swallows the copy error. Add the file or drop the copy?
- **Q-N2** **Q-N2** `ponytail-statusline.sh` is only copied (`hooks/ponytail/ponytail-activate.js:125`). Nothing in the repo runs it, and `statusline/st-statusline.sh:43` reads `.ponytail-active` itself. Keep it or remove it?

### Shipping

#### Z · st-git agent

**In one line.** The only agent that commits, and only the exact files it is given.

**What it does.** Every phase and lane hands its finished files to this one agent. It stages exactly those paths, writes a plain commit message and never pushes. /st-git lets you commit on demand and pick the files.

**How it's built.** `agents/st-git.md`, started by /st, the phase and lane skills, /st-worker and `skills/st-git`. It returns the commit hash and files. LikeC4 ids: `agents.st-git`, `skills.st-git`.

#### I · git repository

**In one line.** The project's branches, worktrees and commits.

**What it does.** Commits land here. Reviewers and the close agent read its diff and log, and parallel workers each get their own worktree.

**How it's built.** The local git repository. Writers: the st-git agent (commits), /st-build (merges of worker branches), /st-pr (push of the branch). LikeC4 id: `git`.

#### GH · GitHub PR

**In one line.** Issues and pull requests on GitHub, reached through the gh CLI.

**What it does.** /st-pr opens a draft pull request from the git facts and the spec after one gate, and marks it ready when the checks pass. /st-issues turns the tasks into issues and skips ones that already exist.

**How it's built.** `skills/st-pr` runs `workflows/pr.js` with the body from `templates/pr.md` or the project copy. `skills/st-issues` follows `procedures/issues.md`. LikeC4 ids: `github`, `skills.st-pr`, `skills.st-issues`, `plugin.workflows-pr-js`, `plugin.templates-pr-md`.

## Flows (representative packets)

Payload shapes are what the design implies, not measured traffic.

### Full lane

| # | From → To | Packet | Representative payload |
|---|---|---|---|
| 1 | U → O | task in plain words | `{"task":"add a dark mode switch to settings"}` |
| 2 | O → S | risk level | `{"risk":"medium"}` |
| 3 | O → P | Define: feature description | `{"skill":"/st-define"}` |
| 4 | P → F | spec and checklists | `{"files":["spec.md","checklists/requirements.md"]}` |
| 5 | G → U | gate: you agree the spec | `{"gate":"you agree the spec"}` |
| 6 | P → A | Plan: feature dir | `{"agent":"st-plan"}` |
| 7 | A → F | plan, research, data model, tasks | `{"files":["plan.md","tasks.md"]}` |
| 8 | G → U | gate: you answer each open decision | `{"gate":"you answer each open decision"}` |
| 9 | P → X | plan point | `{"point":"plan"}` |
| 10 | X → K | spec, plan and tasks, read-only | `{"sandbox":"read-only"}` |
| 11 | P → A | Inspect: plan files to check | `{"agent":"st-inspect"}` |
| 12 | G → U | gate: OK to build | `{"gate":"OK to build"}` |
| 13 | P → B | test and build task ids | `{"tasks":["T001"]}` |
| 14 | B → F | ticked task | `{"task":"T001","done":true}` |
| 15 | P → Z | task paths and tasks.md | `{"paths":["src/settings.tsx","tasks.md"]}` |
| 16 | Z → I | task commit | `{"commit":"feat: dark mode switch"}` |
| 17 | P → C | Close: feature dir | `{"agent":"st-close"}` |
| 18 | G → U | gate: push | `{"gate":"push"}` |

### Fast lane

| # | From → To | Packet | Representative payload |
|---|---|---|---|
| 1 | U → L | change in plain words | `{"skill":"/st-fast","change":"rename the export button"}` |
| 2 | L → C | change | `{"agent":"st-fast"}` |
| 3 | C → F | change plan NNN-name.md | `{"file":"changes/004-rename-export.md"}` |
| 4 | L → X | change point | `{"point":"change"}` |
| 5 | X → K | change plan to review | `{"sandbox":"read-only"}` |
| 6 | G → U | gate: OK on the change plan | `{"gate":"OK on the change plan"}` |
| 7 | L → B | test, then build | `{"agents":["st-test","st-build"]}` |
| 8 | L → V | test command and files touched | `{"result":"PASS"}` |
| 9 | L → Z | exact paths of the change | `{"paths":["src/export.tsx"]}` |
| 10 | Z → I | change commit | `{"commit":"fix: rename export button"}` |
| 11 | L → S | phase done | `{"phase":"done"}` |

### Quick lane

| # | From → To | Packet | Representative payload |
|---|---|---|---|
| 1 | U → O | task in plain words | `{"task":"fix a typo in the footer"}` |
| 2 | O → L | one file: the edit | `{"skill":"/st-quick"}` |
| 3 | L → C | the edit | `{"agent":"st-quick"}` |
| 4 | C → S | phase done | `{"phase":"done"}` |
| 5 | L → V | tests and the one file | `{"result":"PASS"}` |
| 6 | L → Z | the one file | `{"paths":["src/footer.tsx"]}` |
| 7 | Z → I | commit | `{"commit":"fix: footer typo"}` |
| 8 | L → U | what changed in one line | `{"summary":"footer typo fixed"}` |

### Design lane

| # | From → To | Packet | Representative payload |
|---|---|---|---|
| 1 | U → L | task in plain words | `{"skill":"/st-design","task":"a landing page"}` |
| 2 | L → U | mode line and grill questions, after the tool check | `{"script":"st-design-check.sh","mode":"new look"}` |
| 3 | L → T | deal: genre and brief | `{"skill":"/st-hallmark"}` |
| 4 | L → B | task, mode, answers | `{"agent":"st-design"}` |
| 5 | B → L | report: files and screenshots | `{"screenshots":2}` |
| 6 | L → T | audit and critique | `{"skill":"/st-impeccable"}` |
| 7 | G → U | gate: commit the reference screen | `{"gate":"yes, commit the reference screen"}` |
| 8 | L → Z | paths and DESIGN.md | `{"paths":["DESIGN.md",".impeccable/design.json"]}` |
| 9 | Z → I | commit | `{"commit":"feat: landing page"}` |

### A commit

| # | From → To | Packet | Representative payload |
|---|---|---|---|
| 1 | P → Z | task paths | `{"paths":["src/settings.tsx","tasks.md"]}` |
| 2 | Z → E | Bash: git commit | `{"tool":"Bash","command":"git commit"}` |
| 3 | E → W | PreToolUse, matcher Bash | `{"event":"PreToolUse"}` |
| 4 | W → E | ask or deny with the reason | `{"decision":"ask"}` |
| 5 | Z → I | staged paths and commit message | `{"commit":"feat: dark mode switch"}` |
| 6 | Z → P | commit hash and files | `{"hash":"a1b2c3d"}` |

## Questions — index

Reference by ID. ✓ resolved (with date) · otherwise open.

- **Q-T1** (T) **Q-T1** /st-model lists st-worker as an agent (`skills/st-model/SKILL.md:11`), but `agents/st-worker.md` does not exist and /st-status says it has no agents file (`skills/st-status/SKILL.md:36`). Should /st-model drop it?
- **Q-T2** (T) **Q-T2** /st-hallmark calls its command /hallmark (`skills/st-hallmark/SKILL.md:3,57`), but the skill name is st-hallmark (`:2`). Should the text say /st-hallmark?
- **Q-T3** (T) **Q-T3** /st-impeccable names `.claude/skills/st-impeccable/scripts` (`skills/st-impeccable/SKILL.md:19,82`), which is not this plugin's layout, and calls /impeccable, not /st-impeccable (`:84,86`). Should the paths and the command name change?
- **Q-T4** (T) **Q-T4** /st-ponytail-help tells you to update and read the upstream ponytail plugin, not Stratum (`skills/st-ponytail-help/SKILL.md:64,70`). Should it point at Stratum?
- **Q-G1** (G) **Q-G1** /st-full names a Plan gate where you answer the open decisions (`skills/st-full/SKILL.md:11`), but the Gate section of /st-plan names no user gate, only the next phase (`skills/st-plan/SKILL.md:36-38`). Is Plan a gate or not?
- **Q-F1** (F) **Q-F1** The model declares `specs/NNN-feature/gaps.md` (`docs/harness/model/data.c4:168`), but no skill, agent, procedure, script, hook or template names it. The gap report comes back as findings instead (`procedures/converge.md:29`, `agents/st-close.md:47`). Should a harness file write gaps.md?
- **Q-S1** (S) **Q-S1** The st-quick agent sets phase in state.json with no script (`agents/st-quick.md:48`, its tools include Edit, `:4`). Other skills say a `Phase: done` line and the phase hook writes it (`skills/st-close/SKILL.md:58`, `skills/st-fast/SKILL.md:41`). Should it say that line too?
- **Q-R1** (R) **Q-R1** The tasks steps say tests are optional (`procedures/tasks.md:67`), but every task ends with `Test:` (`procedures/tasks.md:92`) and the st-build agent needs a red test before each build (`agents/st-build.md:40`). Which rule wins?
- **Q-R2** (R) **Q-R2** The specify steps use "the checklist template structure" with no path and no resolve-template.sh call (`procedures/specify.md:80`). Only the spec template is resolved (`procedures/specify.md:38`), though `templates/checklist.md` exists. Should it resolve the checklist template too?
- **Q-B1** (B) **Q-B1** The st-build agent gives the Fast-lane path as `changes/NNN-name.md` with no feature folder (`agents/st-build.md:20`), but /st-fast and the st-fast agent put it under `specs/<feature>/changes/` (`skills/st-fast/SKILL.md:14`, `agents/st-fast.md:40`). Which path is right?
- **Q-C1** (C) **Q-C1** /st-close says it records defer and drop in spec.md (`skills/st-close/SKILL.md:32`), but the st-close agent only returns the list and has no record step (`agents/st-close.md:47-48`). Who writes the record?
- **Q-N1** (N) **Q-N1** ponytail-activate.js copies `ponytail-statusline.ps1` on Windows (`hooks/ponytail/ponytail-activate.js:106`), but `hooks/ponytail/` has no such file, and the catch at `:165` swallows the copy error. Add the file or drop the copy?
- **Q-N2** (N) **Q-N2** `ponytail-statusline.sh` is only copied (`hooks/ponytail/ponytail-activate.js:125`). Nothing in the repo runs it, and `statusline/st-statusline.sh:43` reads `.ponytail-active` itself. Keep it or remove it?

## What the platform gives vs what we own

**Platform gives:** Claude Code loads the plugin and gives skills (slash commands), subagents, hook events, the status line command and /advisor.

**We own:** The 40 skills, 15 agents, 17 hook files, 3 statusline files, 15 scripts, 9 procedures and the templates. The lanes, gates and advisor points live in those files.

## Planned filesystem

```
skills/           40 skill folders, one SKILL.md each
agents/           15 agent files
hooks/            commands.json, hooks.json and 7 hook files
hooks/ponytail/   8 ponytail hook files
statusline/       st-statusline.sh, powerline.json, themes.json
scripts/          15 shell scripts
procedures/       9 step files
templates/        spec, plan, tasks, checklist, constitution, pr, models.json
docs/harness/     the LikeC4 model and views, and this atlas
```

## How this file is maintained

Generated from `docs/harness/atlas/data.mjs` by `t=$(mktemp -d) && cp ~/.claude/skills/system-atlas/assets/build.mjs ~/.claude/skills/system-atlas/assets/template.html docs/harness/atlas/data.mjs "$t" && node "$t/build.mjs" && cp "$t/atlas.html" "$t/SYSTEM.md" docs/harness/atlas/ && rm -rf "$t"`, which also builds the interactive atlas (`atlas.html`). Edit the data file, rebuild, republish — never edit this file by hand.
