# Data Model: st-update

No stored data of its own. st-update reads the files below and writes only Stratum's own lines and
keys in them.

## Checkout

One git working tree of the project: the main checkout or a linked worktree that exists.

| Field | Source |
|-------|--------|
| path | `git worktree list --porcelain` |
| branch | the `branch` line, or none (detached HEAD) |
| worker | branch starts with `worker-` |
| main | first entry of the list |

## Record subfolder

A folder under a checkout that has its own install record, for example
`v2-veent-parasat/apps/parasat`. Only the install item, and `statusLine` when its own
`.claude/settings.local.json` already has a Stratum `statusLine` (research R7).

## Install record

One entry of `<config>/plugins/installed_plugins.json` `plugins["stratum@stratum"]`. `<config>` is
`$CLAUDE_CONFIG_DIR`, else `~/.claude`. Read only. Only `claude plugin update` changes it.

| Field | Use |
|-------|-----|
| `scope` | `local` or `project`: passed to `-s`. `user`, `managed`: listed, not touched |
| `projectPath` | the folder. Missing folder: the record is `gone` |
| `installPath` | the `statusLine` target: `<installPath>/statusline/st-statusline.sh` |
| `version` | compared with the marketplace version |
| `lastUpdated` | compared before and after an update (research R4) |

## Marketplace

`<config>/plugins/known_marketplaces.json` key `stratum`, field `installLocation`. Version:
`<installLocation>/.claude-plugin/plugin.json` `version`. The names check reads `agents/`,
`skills/`, `plugin.json` `mcpServers` and the Tools line of `skills/st-design/design-tool.md`
under the same folder.

## Harness item

One thing Stratum puts in a project. `st-update.sh items` prints the list. Each item has:

| Field | Values |
|-------|--------|
| kind | `install`, `statusline`, `ignore`, `pointer`, `plugins-off`, `figcraft`, `file`, `models-key`, `allow`, `gone-file` |
| name | the line, key, file or record it is about |
| where | the file it lives in |
| committed | true for `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json` |

The list, from st-init:

| Kind | Names | Where | Rule |
|------|-------|-------|------|
| `install` | `stratum@stratum` | install record | FR-005 |
| `statusline` | `statusLine` | `.claude/settings.local.json` | research R8 |
| `ignore` | `.stratum/handoff.md`, `.stratum/lessons.md`, `.stratum/weather.json`, `.stratum/powerline.json`, `.stratum/git-guard.json`, `.stratum/models.json`, `graphify-out/` | `.gitignore` (checked with `git check-ignore`, any source) | D10, research R1 |
| `pointer` | `@AGENTS.md`, `@.stratum/constitution.md` | `CLAUDE.md` (checked in `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`) | D10, research R2 |
| `plugins-off` | each `ponytail@ponytail` or `*token-weather*` key that is `true` in `<config>/settings.json` `enabledPlugins` | `.claude/settings.json` (checked in it and `.claude/settings.local.json`) | D10, research R3 |
| `figcraft` | each Tools-line name of `skills/st-design/design-tool.md` | `.claude/settings.json` `permissions.allow` | research R10 |
| `file` | `.stratum/state.json`, `.stratum/git-guard.json`, `.stratum/models.json`, `.stratum/powerline.json`, `.stratum/advisor.json`, `.stratum/constitution.md` | main checkout | research R7 |
| `models-key` | each key of `.stratum/models.json` | `.stratum/models.json` | research R9 |
| `allow` | each Stratum name in `permissions.allow` | `.claude/settings.json`, `.claude/settings.local.json` | research R9 |
| `gone-file` | `.stratum/commit-mode` | each checkout | research R11 |

## Row

One audit output line: one item in one folder.

| Field | Values |
|-------|--------|
| folder | absolute path, or `-` for the header rows |
| kind | as above, or `marketplace` and `marketplace-branch` (header) |
| name | as above |
| state | `current`, `outdated`, `discontinued`, `new`, `ask`, `invalid`, `gone`, `listed`, `warn` |
| detail | one line: the version, the old and new value, or the reason |

States:

- `current`: nothing to do.
- `outdated`: Stratum's value is old. The fix sets the current value.
- `discontinued`: a Stratum name or file the current version does not have. The fix removes it.
- `new`: missing. The fix adds it, or the skill asks st-init's question first (FR-014).
- `ask`: a value Stratum did not write (a non-Stratum `statusLine`). The skill shows the diff and
  asks. Only a yes runs the fix, with `--force`.
- `invalid`: the file is not valid JSON or not an object. Never touched. Reported.
- `gone`: an install record whose folder does not exist. Never touched. Listed.
- `listed`: a `user` or `managed` record, or a folder with no install. Never touched. Listed.
- `warn`: header only. The marketplace folder is a git checkout not on `main` (research R16).
  Shown at the gate. Nothing to fix.

Transitions: `outdated`, `discontinued` and `new` become `current` after a fix. A fix that exits 3
(uncommitted changes, detached HEAD) leaves the row as it was and the report gives the reason. A
second audit after a full run shows only `current`, `ask` rows the user said no to, `new` rows the
user answered "skip", skipped rows, and `invalid`, `gone`, `listed` rows (SC-001).

## Discontinued file list

In `scripts/st-update.sh`. Starts with `.stratum/commit-mode`. A change that removes a feature
which wrote a project file adds the file here (DESIGN.md D13a).
