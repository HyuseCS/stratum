# Stratum Design

Stratum is an agent harness for Claude Code: layered context and hierarchical sub-agent
delegation. It merges GitHub Spec Kit (spec-driven workflow) with the vc-pro-max (RIPER-5) agents,
and forks the tools it uses so it installs as one plugin.

Agreed with the owner in a grilling session on 2026-10-03. First project: Project Pool.

## 1. Repo, install, and sources

- **D1. Repo.** Private `HyuseCS/stratum`, MIT. It is a Claude Code plugin and a marketplace.
  It can go public later: every forked source allows it (see Licenses).
- **D2. Install.** `claude plugin marketplace add HyuseCS/stratum`, then
  `claude plugin install stratum`. Skills appear as `/stratum:<name>`.
- **D3. Forks.** Stratum forks all its sources and owns its copies. `vendor.lock` pins each
  upstream version. `THIRD_PARTY_NOTICES.md` keeps every copyright and license text, and the
  Apache-2.0 sources keep their NOTICE files and a note of what Stratum changed.
- **D4. Upstream sync.** `/stratum:st-sync` (maintainer only, in this repo, monthly) lists each
  upstream change since the pinned version, drafts the port into Stratum's copy, and waits for
  review. The graphify program stays a pip or uv install. Only its skill is forked, so st-sync
  also checks that the skill and program versions still match.
- **D5. Project files.** A project holds only its own data:
  - `.stratum/constitution.md`: project rules.
  - `.stratum/state.json`: current feature, phase, lane.
  - `.stratum/handoff.md`: session handoff (not in git, one per worktree).
  - `.stratum/templates/<name>.md`: optional overrides of plugin templates.
  - `specs/<NNN-feature>/`: spec, plan, research, data model, contracts, quickstart, tasks,
    and `changes/` for Fast-lane plans.
  - `AGENTS.md` and `CLAUDE.md`, pointing to the constitution.

  Templates and scripts live in the plugin. Skills find them through their own base directory,
  and hooks through `${CLAUDE_PLUGIN_ROOT}`. Template lookup: project override first, then plugin.

### Licenses

| Source | Upstream | License |
|--------|----------|---------|
| Spec Kit | github/spec-kit | MIT |
| vc-pro-max agents | withkynam/vibecode-pro-max-kit | MIT |
| ponytail | DietrichGebert/ponytail | MIT |
| grill-me, grilling | mattpocock/skills | MIT |
| ui-ux-pro-max | nextlevelbuilder/ui-ux-pro-max-skill | MIT |
| impeccable | pbakaus/impeccable | Apache-2.0 |
| frontend-design | anthropics/claude-plugins-official | Apache-2.0 |
| graphify skill | Graphify-Labs/graphify | Apache-2.0 |
| Token Weather | anthropics/claude-code-playground | Apache-2.0 |

## 2. Roles

- **D6. Orchestrator.** The main session. It runs Define itself (grilling needs the user), sends
  phases 2 to 5 to subagents, checks every result, brings big decisions to the user, makes small
  ones itself and lists them when the run ends, checks each finding against the source before
  acting on it, and owns merges. It routes and verifies. It does not implement.
- **D7. Agents.**

| Agent | From | Model | Writes code | Job |
|-------|------|-------|-------------|-----|
| `st-plan` | Spec Kit plan + tasks | Opus | No | Plan, research, data model, contracts, quickstart, tasks. Returns open decisions as a list. |
| `st-inspect` | Spec Kit analyze + vc validate | Opus | No | Spec, plan and tasks agree, and the plan is buildable: setup, test coverage, breaking changes, security. |
| `st-build` | vc execute | Opus | Yes | Builds tasks, or a brief with no plan. Loads the design skills for screen tasks. |
| `st-test` | vc tester | Sonnet | Yes | Writes each test and shows it fails before the build. |
| `st-review` | vc code-reviewer | Opus | No | Reviews each finished story. |
| `st-debug` | vc debugger | Opus | Yes | Takes over after 2 failed tries. |
| `st-design` | issue #49 | Opus | Yes | Design-lane build: one screen from the design file with hallmark, its component tests and hallmark's checks. |
| `st-fast` | vc fast-mode | Sonnet | No | Fast-lane change plans. |
| `st-quick` | vc quick-fix | Sonnet | Yes | Quick-lane edits. |
| `st-close` | vc update-process + Spec Kit converge | Sonnet | Docs only | Drift fixes, gap report, lessons, shortcut list. |
| `st-git` | vc git-manager | Sonnet | Git only | Commits each finished task, exact paths. |
| `st-impeccable` | impeccable audit | Opus | No | Background impeccable audit. Read-only. |
| `st-ponytail-audit` | ponytail audit | Opus | No | Background over-engineering audit. Read-only. |
| `st-ponytail-debt` | ponytail debt | Sonnet | No | Background `ponytail:` ledger. Read-only. |
| `st-triage` | issue #15 | Opus | No | Checks a GitHub issue against the code and git history. Read-only. |

- **D8. Rules every agent carries.** Read `sr-opus-5.md` first. Navigate graph, then search,
  then read. Agents that write code also carry the `[PONYTAIL]` directive and the no-comments
  rule in their own file, so the rules hold even if the orchestrator forgets to pass them.

## 3. Skills

- **D9.** Twenty-five entry skills:

| Skill | Job |
|-------|-----|
| `st <task>` | Main entry. Picks the lane by impact area, states it in one line, runs it. |
| `st-full`, `st-fast`, `st-quick` | Force a lane. |
| `st-design <task>` | Design lane: the design file with the user, a reference screen or a new page, checked before the user sees it. |
| `st-define`, `st-plan`, `st-inspect`, `st-build`, `st-close` | Run one Full-lane phase on the current feature, for resuming or redoing. |
| `st-status` | Feature, phase, lane, tasks done, git guard options, next gate, missing tools, duplicate installs, days since the last upstream sync, model overrides. |
| `st-shape arrow\|rounded\|slanted\|blocks\|flat` | Set the statusline shape. |
| `st-theme <name>` | Set the color theme of the statusline and Token Weather. |
| `st-model <agent> <value>...` | Set an agent's model or effort in `.stratum/models.json`. |
| `st-init` | Set up a project: data files, constitution (grilled), tool check. |
| `st-template <name>` | Copy a plugin template into `.stratum/templates/` to edit. |
| `st-handoff` | Write the session handoff. |
| `st-pr [base]` | Open a PR: facts from git and the spec, one gate, a draft that becomes ready when CI passes. |
| `st-review`, `st-test`, `st-debug`, `st-git` | Run one Build-loop agent on demand, then the check the orchestrator runs after it in a lane. |
| `st-triage <issue#>...` | Check GitHub issues against the code and git history: verdict, what is built, blocker, next step. Read-only. |
| `st-herdr-workspace <folder>` | Open a project folder as a new herdr workspace with the full or basic layout, here or on a saved machine. |
| `st-worker <task>...` | Run tasks in worker sessions (a `claude` in its own herdr pane and worktree, here or on a saved machine, or headless), then review and merge their branches. |

  The Spec Kit commands are folded into the phase skills. `st-constitution` (amend rules) and
  `st-issues` (tasks to GitHub issues) stay callable alone, as do the forked tools (`st-grill`,
  `st-impeccable`, `st-ui-ux`, `st-frontend-design`, `st-graphify`, `st-hallmark`, ponytail's skills).
  `st-sync` exists only in this repo.

  A skill called outside a lane skips that lane's gates but never the commit guard or the push
  rule. Calling a phase out of order gets one warning from the phase hook (D20), then runs.

## 4. Lanes

- **D10. Lane by impact area.** The highest area touched wins. The orchestrator picks; the user
  can override either way. Work that turns out to touch a higher area stops and moves up.

| Impact area | Examples | Lowest lane |
|-------------|----------|-------------|
| Privacy and access | access rules, data model, contracts, sign-in, personal or minors' data | Full |
| New user story or feature | anything not in a current spec | Full |
| Core runtime | background services, offline queue, workers, notices | Fast |
| Screens | layout, components, navigation | Fast (Quick for a small fix in a few files) |
| Text and docs | labels, typos, wording | Quick |

### Full lane

| # | Phase | Steps | Gate after |
|---|-------|-------|------------|
| 1 | Define (orchestrator) | grill → specify → clarify only if gaps remain → checklist | User agrees the spec |
| 2 | Plan (`st-plan`) | plan → tasks. Open decisions return to the orchestrator and are grilled one at a time, then `st-plan` resumes. | Orchestrator asks: make GitHub issues? |
| 3 | Inspect (`st-inspect`) | analyze and validate in one pass. Findings that need a decision go to the user. | User OKs the build |
| 4 | Build | See the build loop | None unless blocked or a decision falls outside the plan |
| 5 | Close (`st-close`) | Drift fixes, gap report, lessons, shortcuts, docs graph update | Push only on the user's "push" |

**Build loop**

1. Per task: `st-test` writes the test and shows it fails → `st-build` builds until it passes →
   the orchestrator re-runs the test and checks the diff has no added comments → `st-git` commits.
2. A test still red after 2 tries goes to `st-debug`.
3. Per story: `st-review` on the story's diff (correctness, security, plan fit,
   over-engineering), impeccable for screens,
   findings checked against the source, `st-build` fixes the real ones, then the story's quickstart steps run.
4. `[P]` tasks run in parallel, each subagent in its own built-in worktree. The orchestrator
   checks each branch and merges it into `main`.

**Close**

1. Fix drift: update spec, plan, data model and contracts to match what was built, listing each
   change.
2. Gap report (optional): unticked tasks or FRs without code and test. The user sends them back
   to Build, defers, or drops them. At most one send-back per feature.
3. Lessons: append to `docs/lessons.md`. The Plan and Inspect agents read the file at the next feature.
   Changes to the constitution or the harness are proposed, never applied by the agent.
4. Shortcuts: `scripts/st-shortcuts.sh` lists the `ponytail:` markers the feature's diff adds. The
   user picks fix now (st-build, st-verify, st-git commit) or keep (no record: st-ponytail-debt
   finds the marker).

### Fast lane

`st-fast` writes `specs/<feature>/changes/NNN-<name>.md` (what, which FRs, files, tests) → user OK →
test first, build, `st-review` → commit → drift fix and shortcut list → commit docs.

### Quick lane

`st-quick`: one file, no gate, run the tests that cover it, commit. A small bounded fix across a few
files goes to `st-build` in brief mode, then verify and commit. Moves up to Fast when it needs a
change plan or touches a schema, access rules, money, contracts, personal data, secrets or a new
dependency.

## 5. Tools

- **D11. Design.** ui-ux-pro-max for build rules (it covers Flutter), impeccable for review at each
  story's end, frontend-design for the visual direction once per project, written as a design
  brief before the first screen.
- **D12. Navigation.** Graphify is the first stop. Its post-commit hook rebuilds the code graph.
  `graphify-out/` stays out of git. The docs graph is updated once per feature in Close. The graph
  points to files; agents read a file before editing it.
- **D13. Worktrees.** Built-in worktrees for subagents inside a session. `st-worktree.sh` for the
  user's own parallel sessions (for example a big feature in one, ongoing work in another): it
  creates the worktree and branch and links shared settings and Claude memory. Worktrees and
  branches stay on the machine until the user says to delete them, even when merged, done, or
  unused. Agents never delete a remote branch: the user does.

## 6. Display, comms, and safety

- **D14. Statusline.** A powerline in two lines: `Stratum` label, project path (`~` for home) and
  session length, with git branch on the right; model with thinking level, ponytail, with commit mode on the
  right. Right-side segments are padded to the width less `reserve` columns (default 8), as Claude
  Code cuts the statusline short of `COLUMNS`. The label starts with a layers icon (`logo` key); when
  narrow, the label becomes the icon alone. The `shape` key picks `arrow`, `rounded`,
  `slanted`, `blocks`, or `flat`. Powerline gives branch, session length
  and model; the script draws the rest (also without bunx) and reads the ponytail level from its
  state file. Each line fits the terminal width by shortening, then dropping segments; branch and
  commit mode always stay. SR-OPUS-5 is not shown. Colors come from a theme or custom
  colors in `statusline/powerline.json`, with `.stratum/powerline.json` merged over it per project.
  Stratum's segments take theme colors from `statusline/themes.json`, copied from claude-powerline.
- **D15. Token Weather.** The context forecast, drawn as the statusline's third line. It replaces
  the powerline context and token segments. Left: forecast, fill bar, tokens used, from the
  statusline input (`context_window`). Right: turns left before auto-compaction, from the mean
  growth of the last 5 growing turns and `autoCompactThreshold` (the full window when it is off).
  The mod `hooks/token-weather.mjs` measures these two each turn into `.stratum/weather.json`,
  because the statusline cannot read the threshold or keep a history; the mod's session id differs
  from the statusline's, so the file is not keyed by session. When narrow, the bar drops first,
  then the turns.
- **D16. SR-OPUS-5.** Ships as `sr-opus-5.md`. A SessionStart hook prints it only if it differs
  from the user's global copy, so it never loads twice.
- **D17. Commit guard (`st-git-guard`).** A PreToolUse hook on Bash:
  - One plugin option (`userConfig` in `plugin.json`) per command: `commit`, `worktree_remove`,
    `worktree_prune`, `branch_delete`, `reset_hard`, `clean`, `discard` (`checkout .`,
    `restore .`), `force_push`. Each is `auto` (allow), `ask`, or `deny`; the default is `ask`.
    The user sets them in `/config` or `/plugin config`; those are global to the machine. A
    repo's `.stratum/git-guard.json` (git-ignored, written by `st-init`) overrides them key by
    key. The hook reads the file, then `CLAUDE_PLUGIN_OPTION_<KEY>`. `commit` `ask` and `deny` show a staged-file summary.
  - Push, `rebase`, and `commit --amend` always ask.
  - Always blocked: `git config`, `git add -A`, `git add .`, `--no-verify`, remote branch delete.
- **D18. Handoff.**
  - `st-handoff` writes `.stratum/handoff.md`: goal, decisions, lane, phase and task, open
    questions, blockers, exact next step.
  - A SessionEnd and PreCompact hook always appends a facts block: branch, phase, tasks done,
    last 5 commits, uncommitted files.
  - The SessionStart hook prints the handoff into each new session, and the orchestrator starts
    from it.
  - Mid-session st-handoff starts an Agent with subagent_type "fork" (it inherits the
    conversation and runs in the background). When the user says they are done or is ending the
    session, it runs in the main session so it finishes before exit. It starts no second fork
    while one runs. If the fork cannot start, or reports no file written, it runs in the main
    session.
- **D19. Model overrides (`st-models`).** A PreToolUse hook on `Agent`, `hooks/st-models.py`:
  - On every `stratum:` agent start it reads the repo's `.stratum/models.json` (git-ignored,
    written by `st-init` from `templates/models.json`). Each key is an agent name with an
    optional `model` and `effort`.
  - It sets only `model` and `effort` on the call. Other agents and other fields are untouched.
    No file or no entry keeps the plugin default.
  - A bad file (bad JSON, unknown agent, key, model, or effort) denies the start with a message.
  - `st-model` edits the file. `st-status` shows the overrides.
- **D20. Phase (`st-phase`).** A UserPromptSubmit hook and a PreToolUse hook on `Skill`,
  `hooks/st-phase.py`:
  - When `st-define`, `st-plan`, `st-inspect`, `st-build`, `st-close`, `st-fast`, `st-quick` or
    `st-full` starts (the user types `/stratum:st-<name>` or the model starts the skill), it
    writes `.stratum/state.json` and keeps the other keys. The skills make no tool call for it.
  - `st-fast` and `st-quick` set `lane` and `phase` to `fast` or `quick`. `st-full` sets `lane`
    to `full`. If `phase` is `fast` or `quick`, it sets `phase` to null. `st-define` sets `phase`
    and sets `lane` to `full`. `st-plan` to `st-close` set `phase`, and set `lane` to `full` only
    when `lane` is unset, so a Fast run that opens `st-close` keeps `lane: fast`.
  - If the last phase is not the one that comes before it (or the same phase), it adds one warning line to
    the context. It never blocks. Define, Fast, Quick and Full are never out of order.
  - No `state.json`: it does nothing. With no `feature_directory`, only `st-define`, `st-fast`,
    `st-quick` and `st-full` write. The other phases do nothing.
- **D21. Reply label.** On each prompt, `st-phase` reads `phase` and adds one line: start the
  reply with `[Full lane | <Phase>]`, `[Fast lane]` or `[Quick lane]`. The hook sets `phase` to
  `fast` or `quick` when st-fast or st-quick starts. The `st-close` agent (Full Close and the
  Fast-lane drift step) and the `st-quick` agent set `phase` to `done` at the end of their run.
  With no lane running the hook adds nothing, and the session-start line says to
  start with `[Orchestrator]`.
- **D22. Verify script (`scripts/st-verify.sh`).** The orchestrator's check after a build: run
  the test command, then check the listed files (tracked diff, or the whole file if new) for
  added comment lines. Prints the test's last
  20 lines on a red test, the comment lines on a hit, else one `ok` line. Exit 0 ok, 1 fail, 2
  no command or no files. St, st-build, st-fast and st-quick use it. The `[P]` branch check stays as it was.
- **D23. Agent names.** The session-start rule says to set each Agent call's description to the
  task only (`US1 review`, `T004 test`), since the panel shows the agent's name and the reply
  label shows the lane, and to keep
  a subagent's tag when relaying its report. Each agent file says to start its report with
  `[<agent name>]`.
- **D24. Background agents.** st-impeccable (audit only), st-review, st-ponytail-audit and st-ponytail-debt each have a read-only agent of the same name (no Edit or Write tool). The session-start rule starts it when the user asks for the skill in the background, compares git rev-parse HEAD and git status --porcelain --untracked-files=all before and after, and says any other skill runs only in the main session. The agents' tool lists are the real guard (the ponytail agents cannot write; st-impeccable and st-review only have Bash, since st-review runs tests), and the git check is their backup that cannot see edits to files that were already changed.

- **D25. Shortcut list (`scripts/st-shortcuts.sh`).** Close lists the `ponytail:` markers that the feature's diff adds, as `file:line: text`. The base is `main` on a branch, the parent of the first commit that added spec.md on `main`, or the HEAD noted at Fast step 1. The user picks fix now or keep. Kept markers need no record, because `st-ponytail-debt` finds them. When HEAD has no commits after the base, the script prints `No commits after <base>.`

## 7. Project Pool move

Once Stratum runs, Project Pool moves `.specify/memory/constitution.md` to
`.stratum/constitution.md` and removes `.specify/` and the `speckit-*` skills. `specs/` stays.
