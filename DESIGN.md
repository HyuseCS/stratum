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
  - `.stratum/commit-mode`: commit guard mode (not in git, one per machine).
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
| `st-check` | Spec Kit analyze | Sonnet | No | Spec, plan and tasks agree. Read-only. |
| `st-validate` | vc validate | Opus | No | Plan is buildable: setup, test coverage, breaking changes, security. |
| `st-build` | vc execute | Opus | Yes | Builds tasks. Loads the design skills for screen tasks. |
| `st-test` | vc tester | Sonnet | Yes | Writes each test and shows it fails before the build. |
| `st-review` | vc code-reviewer | Opus | No | Reviews each finished story. |
| `st-debug` | vc debugger | Opus | Yes | Takes over after 2 failed tries. |
| `st-fast` | vc fast-mode | Sonnet | No | Fast-lane change plans. |
| `st-quick` | vc quick-fix | Sonnet | Yes | Quick-lane edits. |
| `st-close` | vc update-process + Spec Kit converge | Sonnet | Docs only | Drift fixes, gap report, lessons. |
| `st-git` | vc git-manager | Sonnet | Git only | Commits each finished task, exact paths. |

- **D8. Rules every agent carries.** Read `sr-opus-5.md` first. Navigate graph, then search,
  then read. Agents that write code also carry the `[PONYTAIL]` directive and the no-comments
  rule in their own file, so the rules hold even if the orchestrator forgets to pass them.

## 3. Skills

- **D9.** Fourteen entry skills:

| Skill | Job |
|-------|-----|
| `st <task>` | Main entry. Picks the lane by impact area, states it in one line, runs it. |
| `st-full`, `st-fast`, `st-quick` | Force a lane. |
| `st-define`, `st-plan`, `st-check`, `st-build`, `st-close` | Run one Full-lane phase on the current feature, for resuming or redoing. |
| `st-status` | Feature, phase, lane, tasks done, commit mode, next gate, missing tools, days since last sync. |
| `st-commit-mode auto\|ask\|deny` | Set the commit mode. |
| `st-shape arrow\|rounded\|slanted\|blocks\|flat` | Set the statusline shape. |
| `st-theme <name>` | Set the color theme of the statusline and Token Weather. |
| `st-init` | Set up a project: data files, constitution (grilled), tool check. |
| `st-template <name>` | Copy a plugin template into `.stratum/templates/` to edit. |
| `st-handoff` | Write the session handoff. |
| `st-pr [base]` | Open a PR: facts from git and the spec, one gate, a draft that becomes ready when CI passes. |

  The Spec Kit commands are folded into the phase skills. `st-constitution` (amend rules) and
  `st-issues` (tasks to GitHub issues) stay callable alone, as do the forked tools (`st-grill`,
  `st-impeccable`, `st-ui-ux`, `st-frontend-design`, `st-graphify`, ponytail's skills).
  `st-sync` exists only in this repo.

  A skill called outside a lane skips that lane's gates but never the commit guard or the push
  rule. Calling a phase out of order gets one warning, then runs.

## 4. Lanes

- **D10. Lane by impact area.** The highest area touched wins. The orchestrator picks; the user
  can override either way. Work that turns out to touch a higher area stops and moves up.

| Impact area | Examples | Lowest lane |
|-------------|----------|-------------|
| Privacy and access | access rules, data model, contracts, sign-in, personal or minors' data | Full |
| New user story or feature | anything not in a current spec | Full |
| Core runtime | background services, offline queue, workers, notices | Fast |
| Screens | layout, components, navigation | Fast (Quick for a one-file visual fix) |
| Text and docs | labels, typos, wording | Quick |

### Full lane

| # | Phase | Steps | Gate after |
|---|-------|-------|------------|
| 1 | Define (orchestrator) | grill → specify → clarify only if gaps remain → checklist | User agrees the spec |
| 2 | Plan (`st-plan`) | plan → tasks. Open decisions return to the orchestrator and are grilled one at a time, then `st-plan` resumes. | Orchestrator asks: make GitHub issues? |
| 3 | Check (`st-check`, `st-validate`) | analyze → validate. Findings that need a decision go to the user. | User OKs the build |
| 4 | Build | See the build loop | None unless blocked or a decision falls outside the plan |
| 5 | Close (`st-close`) | Drift fixes, gap report, lessons, docs graph update | Push only on the user's "push" |

**Build loop**

1. Per task: `st-test` writes the test and shows it fails → `st-build` builds until it passes →
   the orchestrator re-runs the test and checks the diff has no added comments → `st-git` commits.
2. A test still red after 2 tries goes to `st-debug`.
3. Per story: `st-review` and ponytail-review on the story's diff, impeccable for screens,
   findings checked against the source, `st-build` fixes the real ones, then the story's quickstart steps run.
4. `[P]` tasks run in parallel, each subagent in its own built-in worktree. The orchestrator
   checks each branch and merges it into `main`.

**Close**

1. Fix drift: update spec, plan, data model and contracts to match what was built, listing each
   change.
2. Gap report (optional): unticked tasks or FRs without code and test. The user sends them back
   to Build, defers, or drops them. At most one send-back per feature.
3. Lessons: append to `docs/lessons.md`. Changes to the constitution or the harness are proposed,
   never applied by the agent.

### Fast lane

`st-fast` writes `specs/<feature>/changes/NNN-<name>.md` (what, which FRs, files, tests) → user OK →
test first, build, ponytail-review → commit → drift fix.

### Quick lane

`st-quick`: one file, no gate, run the tests that cover it, commit. Moves up to Fast if it needs a
second file or touches any area above text and docs.

## 5. Tools

- **D11. Design.** ui-ux-pro-max for build rules (it covers Flutter), impeccable for review at each
  story's end, frontend-design for the visual direction once per project, written as a design
  brief before the first screen.
- **D12. Navigation.** Graphify is the first stop. Its post-commit hook rebuilds the code graph.
  `graphify-out/` stays out of git. The docs graph is updated once per feature in Close. The graph
  points to files; agents read a file before editing it.
- **D13. Worktrees.** Built-in worktrees for subagents inside a session. `st-worktree.sh` for the
  user's own parallel sessions (for example a big feature in one, ongoing work in another): it
  creates the worktree and branch and links shared settings and Claude memory.

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
  - Commit mode from `.stratum/commit-mode`: `auto` allows, `ask` asks with a staged-file
    summary, `deny` blocks with the summary. Missing file means `ask`.
  - Push always asks.
  - Always blocked: `git config`, `git add -A`, `git add .`, `--no-verify`.
  - Always asks: destructive commands (`push --force`, `reset --hard`, and similar).
- **D18. Handoff.**
  - `st-handoff` writes `.stratum/handoff.md`: goal, decisions, lane, phase and task, open
    questions, blockers, exact next step.
  - A SessionEnd and PreCompact hook always appends a facts block: branch, phase, tasks done,
    last 5 commits, uncommitted files.
  - The SessionStart hook prints the handoff into each new session, and the orchestrator starts
    from it.

## 7. Project Pool move

Once Stratum runs, Project Pool moves `.specify/memory/constitution.md` to
`.stratum/constitution.md` and removes `.specify/` and the `speckit-*` skills. `specs/` stays.
