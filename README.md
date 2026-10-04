# Stratum

An agent harness for Claude Code. Stratum runs every change through a lane sized by its impact:
a main session (the orchestrator) plans with you, hands the work to `st-*` subagents, checks
what they return, and stops at a few clear gates for your decision.

Stratum merges two workflows and adds its own layer:

- **GitHub Spec Kit:** the spec, plan, and tasks files, and their templates.
- **vibecode-pro-max (RIPER-5):** role agents for validate, build, test, review, debug, and git.
- **Stratum's own layer:** lane selection, the build loop, a commit guard, a session handoff, a
  statusline, and forked design and navigation tools, all shipped as one plugin.

The full design and the reason for each choice are in [DESIGN.md](DESIGN.md).

## Install

Stratum is a Claude Code plugin and its own marketplace.

```bash
claude plugin marketplace add HyuseCS/stratum
claude plugin install stratum@stratum --scope project
```

Then, in a new session in your project:

```text
/stratum:st-init
```

`st-init` creates the project's `.stratum/` files and `specs/`, grills you for the project's
rules (the constitution), sets the statusline, turns off a global ponytail or Token Weather plugin
for this project, offers to upgrade graphify, installs its post-commit hook, and checks your tools.

### Requirements

| Tool | Used for |
|------|----------|
| Claude Code 2.1.287 or later | plugin mods (Token Weather) |
| `git`, `python3` | commit guard, scripts |
| `node` | ponytail hooks |
| `bunx` (Bun) | statusline bar (falls back to markers only) |
| `graphify` 0.9.74 or later (`uv tool install graphifyy`) | code navigation graph, Dart support |
| `gh` | optional, for `st-issues` |

## Use

Describe the work. Stratum picks the lane:

```text
/stratum:st add a parent notice when the bus is 10 minutes away
```

It answers with one line, for example `Lane: full (privacy and access: new notice to parents).`
Say `full`, `fast`, or `quick` to override.

### Lanes

The lane follows the highest impact area the change touches.

| Impact area | Examples | Lane |
|-------------|----------|------|
| Privacy and access | access rules, data model, contracts, sign-in, personal data | Full |
| New user story or feature | anything not in a current spec | Full |
| Core runtime | background services, offline queue, workers, notices | Fast |
| Screens | layout, components, navigation | Fast (Quick for a one-file visual fix) |
| Text and docs | labels, typos, wording | Quick |

**Full lane:** five phases and three gates.

| # | Phase | What happens | Gate |
|---|-------|--------------|------|
| 1 | Define | Grilling, then the spec, then clarify (if needed) and checklist | You agree the spec |
| 2 | Plan | `st-plan` writes the plan and tasks. Open decisions come to you one at a time. | Asked: make GitHub issues? |
| 3 | Check | `st-check` checks the files agree, `st-validate` checks the plan can be built | You OK the build |
| 4 | Build | Per task: failing test, build, check, commit. Per story: review, ponytail review, design review. | None unless blocked |
| 5 | Close | Fix spec drift, optional gap report, proposed lessons | Push only when you say "push" |

**Fast lane:** a short change plan in `specs/<feature>/changes/`, your OK, test-first build,
ponytail review, commit, drift fix.

**Quick lane:** one file, no gate, related tests, commit. It moves up a lane if it needs more.

### Skills

| Skill | What it does |
|-------|--------------|
| `st <task>` | Main entry. Picks the lane and runs it. |
| `st-full`, `st-fast`, `st-quick` | Force a lane. |
| `st-define`, `st-plan`, `st-check`, `st-build`, `st-close` | Run or resume one Full-lane phase. |
| `st-status` | Feature, phase, lane, tasks done, commit mode, next gate, missing tools. |
| `st-commit-mode auto\|ask\|deny` | Set the commit guard mode. |
| `st-shape arrow\|rounded\|slanted\|blocks\|flat` | Set the statusline shape. |
| `st-theme <name>` | Set the statusline color theme. |
| `st-handoff` | Write the session handoff. |
| `st-init` | Set up a project. |
| `st-template <name>` | Copy a template into the project to edit it. |
| `st-constitution` | Amend the project rules. |
| `st-issues` | Turn tasks into GitHub issues. |
| `st-sync` | Maintainers: port upstream changes into Stratum's forks. |
| `st-grill` | Grilling interview, one question at a time. |
| `st-ui-ux`, `st-impeccable`, `st-frontend-design` | Design build rules, design review, visual direction. |
| `st-graphify` | Build or query the code graph. |
| `st-ponytail`, `st-ponytail-review`, `-audit`, `-debt`, `-gain`, `-help` | Minimal-code mode and its reviews. |

All skills are called as `/stratum:<name>`.

### Agents

| Agent | Model | Job |
|-------|-------|-----|
| `st-plan` | Opus | Plan, research, data model, contracts, quickstart, tasks |
| `st-check` | Sonnet | Spec, plan, and tasks agree (read-only) |
| `st-validate` | Opus | Setup, test coverage, breaking changes, security |
| `st-build` | Opus | Builds tasks; loads design rules for screens |
| `st-test` | Sonnet | Writes each test and shows it fails first |
| `st-review` | Opus | Reviews each finished story |
| `st-debug` | Opus | Takes over after 2 failed tries |
| `st-fast` | Sonnet | Fast-lane change plans |
| `st-quick` | Sonnet | Quick-lane edits |
| `st-close` | Sonnet | Drift fixes, gap report, lessons |
| `st-git` | Sonnet | Commits each finished task, exact paths only |

Every agent reads the SR-OPUS-5 communication contract first and finds files graph first, then
search, then read. Code-writing agents carry the ponytail rule and add no explanatory comments.

## Project files

```text
.stratum/
├── constitution.md      project rules (committed)
├── state.json           current feature, phase, lane (committed)
├── templates/           optional overrides of plugin templates (committed)
├── handoff.md           session handoff (git-ignored)
└── commit-mode          auto | ask | deny (git-ignored, per machine)
specs/NNN-feature/       spec, plan, research, data model, contracts, quickstart, tasks, changes/
AGENTS.md, CLAUDE.md     point every tool at the constitution
```

Templates and scripts stay in the plugin. A file in `.stratum/templates/` overrides the plugin's
copy for that project only.

## Built in

- **Commit guard.** Commits follow `.stratum/commit-mode`: `auto` runs, `ask` asks with a
  staged-file summary, `deny` blocks. The default is `ask`. Push always asks. `git config` writes,
  `git add -A`, `git add .`, and `--no-verify` are always blocked. `reset --hard`, `clean -f`,
  `rebase`, `branch -D`, `commit --amend`, and force push always ask.
- **Session handoff.** `st-handoff` writes the goal, decisions, open questions, and next step. A
  hook adds a facts block (branch, phase, tasks done, last commits, uncommitted files) at session
  end and before compaction. The next session starts by reading it.
- **Statusline.** A powerline in two lines. Line 1: `Stratum`, project path, and session length on
  the left, git branch on the right. Line 2: model and ponytail level on the left, commit mode on
  the right. Each line fits the terminal width: the path becomes the folder name, other segments
  get shorter, then drop. The branch and commit mode always stay. See
  [Statusline colors](#statusline-colors).
- **Token Weather.** A context forecast above the prompt, from ☀ Clear to ↯ Compact soon.
- **Parallel sessions.** `scripts/st-worktree.sh <branch> <name>` makes a sibling worktree that
  shares this project's local settings, commit mode, and Claude memory.

## Statusline colors

The defaults are in `statusline/powerline.json` (rose-pine). To change them for one project,
create `.stratum/powerline.json`. Its keys merge over the defaults.

Pick a theme: `rose-pine`, `nord`, `tokyo-night`, `gruvbox`, `dark`, or `light`. All segments
follow it. Pick a shape: `arrow` (default), `rounded`, `slanted`, `blocks`, or `flat` (colored
text, no backgrounds). `arrow`, `rounded`, and `slanted` need a Nerd Font.
`/stratum:st-shape <shape>` and `/stratum:st-theme <theme>` set them for you.

```json
{ "theme": "nord", "shape": "rounded" }
```

Or set your own colors. Keys you leave out keep the rose-pine color.

```json
{
  "theme": "custom",
  "colors": {
    "custom": {
      "git": { "bg": "#1f1d2e", "fg": "#9ccfd8" },
      "ponytail": { "bg": "#2a273f", "fg": "#eb6f92" },
      "stratum": { "bg": "#191724", "fg": "#ebbcba" },
      "commit": { "bg": "#1f1d2e", "auto": "#9ccfd8", "ask": "#f6c177", "deny": "#eb6f92" }
    }
  }
}
```

Other keys: `directory` (project folder), `model`, and `metrics` (session length). The `stratum`
label uses the `model` colors unless you set it. Other color options from the
[claude-powerline docs](https://github.com/Owloops/claude-powerline) also work here.

## Duplicate installs

If ponytail, impeccable, ui-ux-pro-max, graphify's skill, or grilling are also installed globally,
their hooks or skills can run twice. `st-init` turns off a global ponytail or Token Weather plugin
in the project's `.claude/settings.json`. `st-status` lists the rest. Turn the global ones off for
projects that use Stratum.

## Maintaining the forks

Stratum owns modified copies of its sources. `vendor.lock` pins each upstream commit. Once a
month, run `/stratum:st-sync` in this repo: it lists upstream changes since the pin, drafts the
ports, and waits for review before updating `vendor.lock`.

## Tests

```bash
python3 tests/test_git_guard.py
bash tests/test_session_hooks.sh
bash tests/test_statusline.sh
claude plugin validate .claude-plugin/plugin.json
```

## Credits and license

Stratum is MIT licensed. It contains modified copies of GitHub Spec Kit, vibecode-pro-max-kit,
ponytail, mattpocock/skills, ui-ux-pro-max, impeccable, frontend-design, graphify's skill, Token
Weather, and the theme colors of claude-powerline, each under its own MIT or Apache-2.0 license.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and `licenses/`.
