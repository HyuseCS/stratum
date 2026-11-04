# Research: st-update

Sources: Claude Code 2.1.316 on this machine (`claude plugin update --help`, two `--json` runs on
2026-11-04, strings in `/opt/claude-code/bin/claude`), `~/.claude/plugins/installed_plugins.json`,
`~/.claude/plugins/known_marketplaces.json`, the projects `v2-veent`, `v2-veent-crm`, the
`v2-veent-worker-*` worktrees, `Project_Pool` and `st-l1-scratch` on this machine, and the Stratum
files named below at commit 51eda0f.

All items are settled. R1 to R3 follow D10, R13 follows D11, R16 follows the spec edge case on
the marketplace branch.

## R1. When a `.gitignore` item is current (D10)

- Decision: current when `git -C <checkout> check-ignore -q -- <path>` says the path is ignored,
  from any source (`.gitignore`, `.git/info/exclude`, the global excludes file). For a line that
  ends in `/` the check uses `<path>x` (a file inside it). A new item appends the st-init line to
  `<checkout>/.gitignore`.
- Rationale: v2-veent ignores Stratum's files with `.stratum/` and `graphify-out/` in
  `.git/info/exclude` (lines 18 and 20, "Stratum (local install, personal)"). Its `.gitignore` has
  none of st-init's seven lines. A literal rule would commit seven lines to 8 branches (the main checkout and 7 linked worktrees today) of a team
  repo (rejected O22).

## R2. When a pointer item is current (D10)

- Decision: `@.stratum/constitution.md` is current when `AGENTS.md`, `CLAUDE.md` or
  `CLAUDE.local.md` names `.stratum/constitution.md`. `@AGENTS.md` is current when `CLAUDE.md` has
  the line `@AGENTS.md`, or when there is no `AGENTS.md`. A new pointer appends the st-init line to
  `CLAUDE.md`.
- Rationale: v2-veent loads the constitution from `CLAUDE.local.md` (ignored by
  `.git/info/exclude` line 19). Project_Pool has both st-init lines in `CLAUDE.md`.

## R3. When an `enabledPlugins` item is current (D10)

- Decision: the items are the keys `ponytail@ponytail` and each key with `token-weather` in its
  name that is `true` in `<config>/settings.json` `enabledPlugins` (st-init step 8). One is current
  when it is `false` in `.claude/settings.json` or `.claude/settings.local.json`. A new one goes to
  `.claude/settings.json`.
- Rationale: v2-veent and v2-veent-crm keep `ponytail@ponytail: false` in
  `.claude/settings.local.json`, and `~/.claude/settings.json` has it `true`.

## R4. `claude plugin update` picks a record by folder, with a fallback (FR-011)

- Decision: the script runs `claude plugin update --json -s <scope> stratum@stratum` with the
  folder as the working directory, only for a folder that has a record with exactly that
  `projectPath`. After the run it reads the records again. The run counts as done only when the
  folder's record has the `newVersion` from the JSON line and no other `stratum@stratum` record
  changed its `lastUpdated`. Else it reports a failure with the CLI's message and the command.
- Rationale: a probe from a folder with no record (the scratch folder, `-s local`) updated
  v2-veent's record from 0.5.2 to 0.6.0. The CLI fell back to another folder's record. The CLI
  code matches `scope` and `projectPath` first (`j()`), then the same path under another spelling
  (`tdr()`, gh-74612). The fallback for a folder with no match is not known. The check after the
  run catches a wrong pick.
- `--json` output, seen on this machine:
  `{"command":"update","outcome":"ok","scope":"local","message":"...","updateOutcome":"updated","oldVersion":"0.5.2","newVersion":"0.6.0"}`,
  `updateOutcome` `up_to_date` when current, and
  `{"outcome":"failed","message":"...","failureCode":"not_found"}` with exit 1. A human line also
  goes to stderr.
- Alternatives: parse the folder from `message` (text, can change); edit
  `installed_plugins.json` directly (the CLI owns that file and the cache).

## R5. Config folder and the work wrapper (CHK018)

- Decision: read `$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json`, else
  `~/.claude/plugins/installed_plugins.json`. Build the `statusLine` path from the record's own
  `installPath`, never from the config folder.
- Rationale: on this machine `~/.claude/plugins/installed_plugins.json` and
  `~/.claude-work/plugins/installed_plugins.json` are the same file (same inode 28582553). One
  record (`veent_wifiportal`) has an `installPath` under `~/.claude-work/plugins/cache/`. The
  `claude` the script calls inherits the session's `CLAUDE_CONFIG_DIR`, so both read the same
  records. On a machine where the two folders differ, st-update updates the records of the
  session's config folder only, and the report names that folder.

## R6. Marketplace version (FR-005, CHK007)

- Decision: `known_marketplaces.json` key `stratum` gives `installLocation`. The version is
  `version` in `<installLocation>/.claude-plugin/plugin.json`. The table header prints this
  version and the folder.
- Rationale: spec Assumption 2. For a `directory` source the folder is the source repo. For a git
  source it is the local clone, which can be behind GitHub. st-update does not refresh it before
  the gate (FR-010). The laptop's source is not known here; the header shows what it compared.
- The names check (R9) reads skills, agents and MCP servers from the same `installLocation`, so it
  compares against the version the update installs.

## R7. Which folders and which items per folder (FR-002)

- Decision:
  - Checkouts: the main checkout and each linked worktree from
    `git worktree list --porcelain` whose folder exists. A worktree on a `worker-*` branch is
    marked `worker` in the table, so the user can skip it at the gate (CHK013).
  - Record subfolders: each `stratum@stratum` record whose `projectPath` is under a checkout.
    They get the install item, and the `statusLine` item only when their own
    `.claude/settings.local.json` has a Stratum `statusLine`. st-update creates no file in a
    subfolder.
  - Gone records: a record whose folder does not exist and whose path is under a checkout, or is
    a sibling of the main checkout named `<main checkout name>-*` (the worktree and worker naming,
    for example `v2-veent-worker-w1a`). Listed, not touched. Other missing folders belong to other
    projects and get no row.
  - `user` and `managed` scope records: listed, not touched (they are not per folder).
  - Committed files (`.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`), the
    install, `statusLine` and the discontinued checks: every checkout.
  - The `.stratum/` files st-init writes (`state.json`, `git-guard.json`, `models.json`,
    `powerline.json`, `advisor.json`, `constitution.md`): the main checkout only. DESIGN.md D13a
    makes worktrees read the main file (`advisor.json`, `constitution.md`) or run on defaults
    (`models.json`, `powerline.json`, `git-guard.json`, `state.json`). Asking in 8 folders (the main checkout and 7 linked worktrees today) would
    break SC-002.
- `.stratum/constitution.md` missing: the row is new and the report says to run
  `/stratum:st-constitution`. D6 names only four question files, and the constitution grill does
  not fit an update run.
- `.stratum/state.json` missing: new, written as st-init step 1 writes it. No question.

## R8. `statusLine` rule (FR-006, FR-012, CHK005)

- Decision: a command is a Stratum statusline when it matches
  `^bash +\S*/statusline/st-statusline\.sh$` (the st-init form). It is current when it equals
  `bash <installPath>/statusline/st-statusline.sh` for the folder's record. Other Stratum commands
  are outdated. Any other command gets the state `ask`. A missing key is new.
- The target record is the folder's own. A folder with none uses the main checkout's record, then
  a `user` scope record. With none, the row is `listed` (no install) and nothing changes.
- `fix statusline` refuses when the target record's version is not the marketplace version. So a
  failed plugin update never leads to a path that does not exist (CHK009, CHK010).
- The committed `bunx @owloops/claude-powerline` `statusLine` in v2-veent's `.claude/settings.json`
  is the user's (spec Assumption 3). Only `.claude/settings.local.json` is checked.

## R9. Discontinued names (FR-007, CHK006)

- Decision: a Stratum name is one of these exact forms. It is discontinued when the target is not
  in the marketplace tree (R6):
  - `.stratum/models.json` key: not a file `agents/<key>.md` and not `st-worker` (the rule of
    `hooks/st-models.py`, which refuses every agent while a dead key is there).
  - `permissions.allow` in `.claude/settings.json` or `.claude/settings.local.json`:
    `Skill(stratum:<name>)` or `Skill(stratum:<name>:*)` with no `skills/<name>/SKILL.md`;
    `mcp__plugin_stratum_<server>` or `mcp__plugin_stratum_<server>__<tool>` with `<server>` not in
    `plugin.json` `mcpServers`, or `<server>` `figcraft` and `<tool>` not on the Tools line of
    `skills/st-design/design-tool.md`.
- Anything else, for example a `Bash(...)` rule that names a Stratum path, is the user's.
- A discontinued name gets its row only when it matches `^[A-Za-z0-9_.:@/*()-]+$`. Any other
  name gets an `invalid` row and no fix, since it would go into a command line. The skill puts
  single quotes around every argument it passes to the script and to git. A
  `Skill(stratum:<name>)` name with `/` in `<name>` is `invalid`: listed, never fixed.
- Only FigCraft names are in allow lists on this machine today (`st-l1-scratch`).

## R10. FigCraft allow entries (FR-003)

- Decision: checked only when `.claude/settings.json` `permissions.allow` already has one
  `mcp__plugin_stratum_figcraft__<tool>` name (the user said yes at st-init step 10). Then each
  Tools-line name it lacks is new. No name means the user said no: nothing to check.

## R11. Discontinued files (FR-008, CHK016)

- Decision: the list lives in `scripts/st-update.sh` and starts with `.stratum/commit-mode`
  (removed in b18f590). Checked in every checkout. Removed after the gate even if the user edited
  it: the feature that read it is gone. DESIGN.md D13a gets a row for it and the rule that a
  change which removes a feature that wrote a project file adds the file to this list.

## R12. Edits keep the user's content (FR-013, SC-003)

- Decision: `.gitignore`, `AGENTS.md`, `CLAUDE.md`: append one line, with a newline before it when
  the file does not end in one. JSON files: load, change one key, write with `indent=2`, key order
  kept. "Not rewrite a whole file" means content: every other key and value stays. The format of
  the file can change (spacing). A file that is not valid JSON, or not an object, is not touched:
  the row is `invalid`.
- The user data files (`constitution.md`, `state.json` once it exists, `lessons.md`,
  `handoff.md`, and the values in `git-guard.json`, `models.json`, `powerline.json`,
  `advisor.json`) are never written. The one write into `models.json` removes a dead key.

## R13. Commits (FR-016, FR-017, CHK004, CHK011)

- Decision: the script never runs git commands that change the repo. The skill runs, per checkout,
  one Bash call: `git -C <checkout> add -- <paths> && git -C <checkout> commit -m '<message>' -- <paths>`,
  so `hooks/st-git-guard.py` and the project's own hooks see it. The commit ends with
  `-- <paths>`, so files the user staged before the run stay staged and stay out of Stratum's
  commit (found at Inspect). `<paths>` are the files from this
  fixed list that st-update changed in that checkout: `.gitignore`, `AGENTS.md`, `CLAUDE.md`,
  `.claude/settings.json`, and `.stratum/state.json` and `.stratum/advisor.json` when
  `git check-ignore` does not ignore them (st-init step 12). Never `.claude/settings.local.json`
  (it holds this machine's path, st-init step 7) and never `.stratum/models.json`.
- Message: `chore(stratum): update harness files to <version>`, then one body line per changed
  item, each in single quotes:
  `-m 'chore(stratum): update harness files to <version>' -m '<one line per item>'`.
- Before any change, `audit` checks `git status --porcelain -- <file>` for each committed file and
  the branch. Uncommitted changes or a detached HEAD: the rows for that file get `skip` with the
  reason, and the skill never runs `fix` on them.
- A commit a hook denies (D11): the skill quotes the deny reason and gives the exact command
  `git -C <checkout> add -- <paths> && git -C <checkout> commit -m '<message>' -- <paths>`. It names no
  personal script and never retries another way.
- Halfway stop (CHK012): every step reads the files again, so a second run audits and does only
  what is left.

## R14. Blocked edits (FR-018)

- Decision: every change outside git is one script call, `bash <plugin root>/scripts/st-update.sh
  fix <folder> <kind> <name>`. When a hook or the classifier blocks that Bash call, the report
  gives that exact line, which the user can run with `!` in the prompt.

## R15. Script language and pattern

- Decision: `scripts/st-update.sh`, bash subcommands like `scripts/st-worker.sh`, with the JSON
  work in `python3 -I` blocks like `statusline/st-statusline.sh`. No `jq` (optional in Stratum,
  only for herdr).
- Tests: `tests/test_st_update.sh` builds a fixture in a temp folder (git repo, one linked
  worktree, fake config folder, fake marketplace and cache, a `claude` stub on `PATH`), like
  `tests/test_st_worker.sh`. Everything is under the temp folder, so no test needs `[lock]`.

## R16. Marketplace on a branch other than `main` (spec edge case)

- Decision: when the marketplace source is `directory` and `git -C <installLocation> branch
  --show-current` is not `main`, `audit` prints a header row `-\tmarketplace-branch\t<branch>\twarn\t<installLocation>`.
  A detached HEAD prints `detached` as the branch. Not a git repo, or a non-directory source: no
  row. The skill shows the warning above the table and names the branch in the gate question. It
  changes nothing for the warning: the user decides at the gate.
- Rationale: `claude plugin update` installs what the folder holds. The source repo is on
  `012-st-update` today, so an update now would install a feature branch.
- Alternatives: refuse to update off `main` (blocks a maintainer who wants to test a branch).
