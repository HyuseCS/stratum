# Stratum

An agent harness for Claude Code. Stratum runs every change through a lane sized by its impact:
a main session (the orchestrator) plans with you, hands the work to `st-*` subagents, checks
what they return, and stops at a few clear gates for your decision.

Stratum merges two workflows and adds its own layer:

- **GitHub Spec Kit:** the spec, plan, and tasks files, and their templates.
- **vibecode-pro-max (RIPER-5):** role agents for validate, build, test, review, debug, and git.
- **Stratum's own layer:** lane selection, the build loop, a git guard, a session handoff, a
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

`st-init` creates the project's `.stratum/` files and `specs/`,
asks for the git guard modes and any model overrides, grills you for the project's rules (the
constitution), writes the `AGENTS.md` and `CLAUDE.md` pointers, sets the statusline and asks for its
theme, shape and Token Weather line, turns off a global ponytail or Token Weather plugin for this
project, offers to upgrade graphify, installs its post-commit hook, and checks your tools.

### Requirements

| Tool | Used for |
|------|----------|
| `git`, `python3` | git guard, model overrides hook, statusline, handoff facts, scripts |
| `node` | ponytail hooks |
| `bunx` (Bun) | statusline bar (falls back to markers only) |
| `graphify` 0.9.74 or later (`uv tool install graphifyy`) | code navigation graph, Dart support |
| `gh` | optional, for `st-issues` and `st-pr` |

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
| 3 | Inspect | `st-inspect` checks the files agree and the plan can be built | You OK the build |
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
| `st-define`, `st-plan`, `st-inspect`, `st-build`, `st-close` | Run or resume one Full-lane phase. |
| `st-status` | Feature, phase, lane, tasks done, git guard options, next gate, missing tools, duplicate installs, days since the last upstream sync, model overrides. |
| `st-shape arrow\|rounded\|slanted\|blocks\|flat` | Set the statusline shape. |
| `st-theme <name>` | Set the color theme of the statusline and Token Weather. |
| `st-model <agent> <value>...` | Set an agent's model or effort for this project. Plain words work too: "make st-close use opus". |
| `st-handoff` | Write the session handoff. |
| `st-init` | Set up a project. |
| `st-template <name>` | Copy a template into the project to edit it. |
| `st-constitution` | Amend the project rules. |
| `st-issues` | Turn tasks into GitHub issues. |
| `st-pr [base]` | Open a draft PR from git facts and the spec; ready when CI passes. |
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
| `st-inspect` | Opus | Spec, plan, and tasks agree; setup, test coverage, breaking changes, security |
| `st-build` | Opus | Builds tasks; loads design rules for screens |
| `st-test` | Sonnet | Writes each test and shows it fails first |
| `st-review` | Opus | Reviews each finished story |
| `st-debug` | Opus | Takes over after 2 failed tries |
| `st-fast` | Sonnet | Fast-lane change plans |
| `st-quick` | Sonnet | Quick-lane edits |
| `st-close` | Sonnet | Drift fixes, gap report, lessons |
| `st-git` | Sonnet | Commits each finished task, exact paths only |

The Model column is the plugin default. `st-init`'s template runs `st-build`, `st-debug`,
`st-quick`, `st-plan`, and `st-fast` on Opus with effort high, and `st-close`, `st-git`, and
`st-test` on Haiku with effort xhigh. See **Model overrides** under [Built in](#built-in).

Every agent reads the SR-OPUS-5 communication contract first and finds files graph first, then
search, then read. Code-writing agents carry the ponytail rule and add no explanatory comments.

## Project files

```text
.stratum/
├── constitution.md      project rules (committed)
├── state.json           current feature, phase, lane (committed)
├── templates/           optional overrides of plugin templates (committed)
├── handoff.md           session handoff (git-ignored)
├── powerline.json       statusline theme, shape, colors (git-ignored, per machine)
├── git-guard.json       git guard modes for this repo (git-ignored, per machine)
├── models.json         agent model and effort overrides (git-ignored, per machine)
└── weather.json         Token Weather growth and compact point (git-ignored)
specs/NNN-feature/       spec, plan, research, data model, contracts, quickstart, tasks, changes/
AGENTS.md, CLAUDE.md     point every tool at the constitution
```

Templates and scripts stay in the plugin. A file in `.stratum/templates/` overrides the plugin's
copy for that project only.

## Built in

- **Advisor.** If you set one with `/advisor`, the orchestrator consults it at three points: on
  the plan before the build gate, when a test fails twice, and on the full diff before calling
  the build done. Its notes are checked against the source like any finding. No advisor, no
  change.
- **Git guard.** One mode per command: `commit`, `worktree_remove`, `worktree_prune`,
  `branch_delete`, `reset_hard`, `clean` (`clean -f`), `discard` (`checkout .`, `restore .`), and
  `force_push`. Each is `auto` (runs), `ask`, or `deny` (blocked). The guard reads the repo's
  `.stratum/git-guard.json` first (`st-init` writes it), then the plugin option of the same name
  from `/config` or `/plugin config`, which is global to the machine. The default is `ask`. A commit that asks or is blocked shows a
  staged-file summary. Push, `rebase`, and `commit --amend` always ask. `git config` writes,
  `git add -A`, `git add .`, and `--no-verify` are always blocked. Remote branch delete is
  blocked: you delete remote branches yourself.
- **Model overrides.** `.stratum/models.json` maps an agent name to an optional `model` and
  `effort`, for example `{ "st-close": { "model": "haiku", "effort": "xhigh" } }`. Agents:
  `st-build`, `st-close`, `st-debug`, `st-fast`, `st-git`, `st-inspect`, `st-plan`, `st-quick`,
  `st-review`, `st-test`. Models: `sonnet`, `opus`, `haiku`, `fable`. Efforts:
  `low`, `medium`, `high`, `xhigh`, `max`. `st-init` writes it from `templates/models.json`:
  `st-build`, `st-debug`, `st-quick`, `st-plan`, `st-fast` on opus with effort high, and
  `st-close`, `st-git`, `st-test` on haiku with effort xhigh.
  `st-inspect` and `st-review` have no entry and keep the plugin default. A hook applies the file
  each time a Stratum agent starts, so the next start picks up an edit. A bad file blocks every
  Stratum agent start with a message that names the problem. Only Stratum agents are affected.
  `CLAUDE_CODE_EFFORT_LEVEL` beats the file's effort.
  The per-call `effort` needs Claude Code 2.1.292 or later. On an older client, remove the
  `effort` keys from the file.
  A linked worktree has no `models.json`: it is git-ignored and `scripts/st-worktree.sh` does not
  link it, so agents there use the plugin defaults, as with `git-guard.json`.
  To change an entry, run `/stratum:st-model st-close opus`, say it in plain words ("make
  st-close use opus"), or edit the file.
- **Session handoff.** `st-handoff` writes the goal, decisions, open questions, and next step. A
  hook adds a facts block (branch, phase, tasks done, last commits, uncommitted files) at session
  end and before compaction. The next session starts by reading it.
- **Statusline.** A powerline in two lines. Line 1: `Stratum`, project path, and session length on
  the left, git branch on the right. Line 2: model with its thinking level, and ponytail on the left,
  the `commit` option on the right. Each line fits the terminal width: the path becomes the folder name, other segments
  get shorter, then drop. The branch and the `commit` option always stay. See
  [Statusline colors](#statusline-colors).
- **Token Weather.** A context forecast as the statusline's third line, from ☀ Clear to ↯ Compact
  soon, with a fill bar and tokens used on the left and the turns left before auto-compaction on
  the right: `☂ Showers ━━━━━━━━━━━━──────── 600k/1M            about 4 turns left`.
- **Parallel sessions.** `scripts/st-worktree.sh <branch> <name>` makes a sibling worktree that
  shares this project's local settings and Claude memory. Worktrees and branches stay
  until you delete them.

## Statusline colors

The defaults are in `statusline/powerline.json` (rose-pine). To change them for one project,
create `.stratum/powerline.json`. Its keys merge over the defaults. Git ignores it, so each person
keeps their own look.

Pick a theme: `rose-pine`, `nord`, `tokyo-night`, `gruvbox`, `dark`, or `light`. All segments
and the Token Weather line follow it. Pick a shape: `arrow` (default), `rounded`, `slanted`, `blocks`, or `flat` (colored
text, no backgrounds). `arrow`, `rounded`, and `slanted` need a Nerd Font.
`/stratum:st-shape <shape>` and `/stratum:st-theme <theme>` set them for you.

Claude Code draws the statusline a few columns narrower than the terminal and cuts what does not
fit with `…`. Each line leaves `reserve` columns free (default 8). If the right side is still cut,
raise it: `{ "reserve": 10 }`.

To hide the Token Weather line, set `{ "weather": false }`.

The `Stratum` label starts with a Nerd Font layers icon (󰌨). Set `"logo"` to another character, or
to `""` for none. The font itself comes from your terminal settings.

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
python3 tests/test_model_hook.py
bash tests/test_model_files.sh
bash tests/test_inspect.sh
bash tests/test_session_hooks.sh
bash tests/test_statusline.sh
node tests/test_token_weather.mjs
claude plugin validate .claude-plugin/plugin.json
```

## Credits and license

Stratum is MIT licensed. It contains modified copies of GitHub Spec Kit, vibecode-pro-max-kit,
ponytail, mattpocock/skills, ui-ux-pro-max, impeccable, frontend-design, graphify's skill, Token
Weather, and the theme colors of claude-powerline, each under its own MIT or Apache-2.0 license.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and `licenses/`.
