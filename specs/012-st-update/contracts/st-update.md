# Contract: st-update

Two parts. `scripts/st-update.sh` reads and fixes, one item at a time, and never runs a git
command that changes the repo. `skills/st-update/SKILL.md` shows the table, holds the gate, asks
the questions, runs the commits and writes the report.

## 1. `scripts/st-update.sh`

Usage: `st-update.sh items | audit [<folder>] | plugin <folder> | fix <folder> <kind> <name> [--force]`.
Bad usage: the usage line on stderr, exit 2.

Environment: `CLAUDE_CONFIG_DIR` (else `~/.claude`), `HOME`, `PATH` (finds `git`, `python3`,
`claude`). `ST_ROOT` is not read: the plugin root is two levels up from the script.

### 1a. `items`

Prints the harness item list (data-model.md), one line per item: `<kind>\t<name>\t<where>`.
The list is static text inside the script. It reads no other file, so the FR-020 negative control
can run on a copy of the script alone. The static names are the `install`, `statusline`,
`ignore`, `pointer`, `file` and `gone-file` names, plus one line for each settings key
(`statusLine`, `enabledPlugins`, `permissions.allow`). The dynamic kinds print their source as
the name: `plugins-off` `<config>/settings.json`, `figcraft` `skills/st-design/design-tool.md`,
`models-key` `agents/`, `allow` `skills/`. Exit 0. The FR-020 test compares st-init with this
output.

### 1b. `audit [<folder>]`

- `<folder>` defaults to the current directory. It resolves to the main checkout of its repo.
- No `<main>/.stratum/`: prints `Not a Stratum project: <folder>. Run /stratum:st-init there.` on
  stderr, exit 1. No change.
- No marketplace `stratum`, or no readable `plugin.json`: one line on stderr, exit 1.
- Else prints rows, one per line, tab-separated: `<folder>\t<kind>\t<name>\t<state>\t<detail>`.
  The first row is `-\tmarketplace\tstratum\tcurrent\t<version> <installLocation>`. When the
  source is `directory` and that folder is a git checkout not on `main`, the second row is
  `-\tmarketplace-branch\t<branch or detached>\twarn\t<installLocation>` (research R16). Then the rows
  of each checkout (main first), its record subfolders, and the `gone` and `listed` records.
  Current rows are printed too: the skill counts them.
- A `gone` row is a record whose folder does not exist and whose path is under a checkout, or is a
  sibling of the main checkout named `<main checkout name>-*` (research R7). Other missing
  folders get no row.
- A discontinued name gets its row only when it matches `^[A-Za-z0-9_.:@/*()-]+$`. Any other
  name gets an `invalid` row with no fix (research R9). A `Skill(stratum:<name>)` name with `/`
  in `<name>` is `invalid`: listed, never fixed.
- A worktree on a `worker-*` branch has `worker` in the detail of its `install` row, or of its
  first row when it has no record.
- Committed files (`.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`): when
  `git -C <folder> status --porcelain -- <file>` is not empty, every row that would change that
  file gets the state `skip` with the detail `<file> has uncommitted changes`. On a detached HEAD,
  every committed-file row of that checkout gets `skip` with the detail
  `detached HEAD, no branch to commit on` (FR-017, D8).
- Exit 0. Writes nothing (FR-010). `claude` is not called.
- Never prints the value of a key it does not check (settings files can hold `env` secrets).

### 1c. `plugin <folder>`

- The folder must have a record with exactly that `projectPath` and scope `local` or `project`.
  Else exit 1 with the reason. `claude` is not called.
- `claude` not on `PATH`: prints `claude not found. Run: cd <folder> && claude plugin update stratum@stratum -s <scope>`,
  exit 1.
- Runs, in `<folder>`: `claude plugin update --json -s <scope> stratum@stratum`.
- Success: exit 0 of the CLI, `outcome` `ok`, the folder's record now has `version` equal to
  `newVersion`, and no other `stratum@stratum` record changed `lastUpdated` (research R4). Prints
  `ok <newVersion> <installPath>`, exit 0.
- Else prints the CLI's `message` (or its stderr), then
  `Run: cd <folder> && claude plugin update stratum@stratum -s <scope>`, exit 1.

### 1d. `fix <folder> <kind> <name> [--force]`

Each call changes one item in one folder, or nothing. Prints one line `changed <file>` or
`same <file>`, exit 0. Refusals print the reason, exit 3, and write nothing.

`fix` does not check for uncommitted changes or a detached HEAD: `audit` does (1b), before any
change, so a second fix to the same file in one run is not refused by the first fix's change.
`ponytail: the dirty and detached check runs at audit time; a file the user edits between the
audit and the fix is not caught; upgrade if that is seen.`

JSON files: not valid JSON or not an object: `skip: <file> is not valid JSON`, exit 3. Writes keep
every other key and value, `indent=2`, key order kept (research R12).

| Kind | Name | Change |
|------|------|--------|
| `ignore` | the line | Append the line to `<folder>/.gitignore` (create the file if missing). |
| `pointer` | `@AGENTS.md` or `@.stratum/constitution.md` | Append the line to `<folder>/CLAUDE.md` (create the file if missing). `@AGENTS.md` only when `<folder>/AGENTS.md` exists. The fix never creates `AGENTS.md`. |
| `statusline` | `statusLine` | Set `statusLine` in `<folder>/.claude/settings.local.json` to `{"type": "command", "command": "bash <installPath>/statusline/st-statusline.sh"}` from the target record (research R8). Create the file with only that key if missing (not in a record subfolder). Refuse, exit 3: the target record's version is not the marketplace version (`skip: install not updated`); the current command is not a Stratum statusline and no `--force` (`skip: not a Stratum statusline`). |
| `plugins-off` | the plugin key | Set `enabledPlugins.<key>` to `false` in `<folder>/.claude/settings.json`. |
| `figcraft` | the tool name | Append the name to `permissions.allow` in `<folder>/.claude/settings.json` when it is not there. |
| `file` | `.stratum/state.json` | Write `{"feature_directory": null, "phase": null, "lane": null}` when missing. Other `file` names are refused, exit 3: the skill writes them after st-init's question. |
| `models-key` | the key | Remove that key from `<folder>/.stratum/models.json` when it is discontinued (research R9). Refuse any other key. |
| `allow` | `<settings file>:<entry>` | Remove that entry from `permissions.allow` in that settings file when it is discontinued (research R9). Refuse any other entry. |
| `gone-file` | the path | Delete it when it is on the discontinued file list. Refuse any other path. |

The script refuses a `fix` whose item is current (`same <file>`, exit 0), so a second run changes
nothing.

## 2. `skills/st-update/SKILL.md`

Plugin root is two levels up from the skill's base directory. `<script>` is
`<plugin root>/scripts/st-update.sh`. The skill puts single quotes around every argument it passes
to the script and to git (folder, kind, name, paths, message).

1. **Audit.** Run `bash <script> audit <folder>` (the argument, else the project root). Exit 1:
   show the line and stop. No row other than `current`, `gone` and `listed`: say every item is
   current and stop. No gate.
2. **Table.** One table: the header (marketplace version and folder, config folder), then per
   folder only the rows that are not `current`, then one line per folder with the count of its
   current items. `worker` folders say so.
3. **Gate.** A `marketplace-branch` row: above the question, warn `The marketplace folder
   <installLocation> is on branch <branch>, not main. The update installs that branch.` One
   question: OK to update all, or `skip <worktree>` (one or more), or no. No: stop, nothing
   changed (FR-010).
4. **Plugin.** For each folder with an `install` row that is `outdated` (skipped worktrees left
   out): `bash <script> plugin <folder>`. Exit 1: keep its message and command for the report,
   go on with the next folder. Then run the step 1 audit once more, with the same argument.
   Steps 5 to 7 take their rows from this second audit.
5. **Ask.** For each `ask` row: show the old and the new `statusLine` command and ask. Yes:
   `fix ... --force`. No: leave it.
6. **Fix.** Every `outdated`, `new` and `discontinued` row, `statusline` rows included and
   `install` rows left out (they have no fix): `bash <script> fix <folder> <kind> <name>`. An
   `allow` row: the name is `<detail>:<name>`, the settings file in its detail, a colon, then the
   entry in its name. `fix statusline` exits 3 when the folder's install is not at the marketplace
   version. Never run `fix` on a `skip` row. Report each `skip` row with its detail. For a `file` row of `git-guard.json`, `models.json`, `powerline.json` or
   `advisor.json`: ask the question of st-init step 3, 4, 7 or 11, one at a time, each with a
   `skip` answer. Skip: leave the file missing. Else write it as that st-init step does. A
   `constitution.md` row: tell the user to run `/stratum:st-constitution`. Exit 3: keep the reason.
   A Bash call a hook or the classifier blocks: keep the exact command for the user (FR-018).
7. **Commit.** `<paths>` are the files of this list that st-update changed in the checkout:
   `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, and `.stratum/state.json` and
   `.stratum/advisor.json` when `git check-ignore` does not ignore them. Never
   `.claude/settings.local.json`, never `.stratum/models.json`. Per checkout with such a file, one
   Bash call:
   `git -C <checkout> add -- <paths> && git -C <checkout> commit -m 'chore(stratum): update harness files to <version>' -m '<one line per item>' -- <paths>`.
   The commit ends with `-- <paths>`, so files the user staged before stay out of it. No `-A`, no
   `--amend`, no `--no-verify`, no push. A denied commit: quote the deny reason and
   give the exact command (D11). Name no personal script. Never work around it.
8. **Report.** Per folder: what changed, what was skipped and why, the commands the user must run.
   Last line: `Restart running Claude Code sessions in these folders to load Stratum <version>.`

Never: change a user data file (FR-013), write before the gate, stage a path it did not change,
run `claude plugin update` in a folder without its own record, edit `installed_plugins.json`.

## 3. Test cases

`tests/test_st_update.sh` (fixture, research R15):

| Case | Checks | FR |
|------|--------|----|
| U1 | `audit` on a folder with no `.stratum/`: exit 1, the st-init line, no change | FR-001 |
| U2 | rows for main, the linked worktree and a record subfolder; a second linked worktree with no record: its `install` row is `listed` with `no install`; a gone record under a checkout and a gone sibling `<main>-worker-w1a` are `gone`; a gone folder of another project gets no row; a `user` record is `listed` | FR-002, FR-011 |
| U3 | record 0.1.22, marketplace 0.7.0: `install` `outdated`; equal: `current` | FR-005 |
| U4 | `statusLine` at an old cache path, at a missing path, at the source folder: `outdated`; at the record's path: `current`; none: `new`; a custom command: `ask`; bad JSON: `invalid` | FR-006 |
| U5 | `models.json` with `st-gone` and `st-build`: only `st-gone` `discontinued`; `Skill(stratum:st-gone)` and a FigCraft name not on the Tools line: `discontinued`; `Skill(stratum:x$(touch pwned))`: `invalid`, and no file `pwned` exists after `audit`; a user `Bash(...)` rule: no row. The fixture uses no name that `tests/test_inspect.sh:86` matches (`st-check`, `st-validate`) | FR-007 |
| U6 | `.stratum/commit-mode` present: `discontinued` | FR-008 |
| U7 | D10: a path ignored only by `.git/info/exclude` is `current`, one ignored nowhere is `new`; the constitution named only in `CLAUDE.local.md` is `current`, named nowhere is `new`; `ponytail@ponytail` `true` in the fake `<config>/settings.json` and `false` only in `.claude/settings.local.json` is `current`, in neither is `new`; a `figcraft` row only when one FigCraft name is allowed | FR-003, FR-004 |
| U8 | `audit` changes no file: tree hash, `git status` and the records file the same before and after | FR-010 |
| U9 | `plugin`: the stub is called in the folder with the record's scope; record moves; prints `ok`; a stub that fails: exit 1, message and command; the gone record under a checkout, the gone sibling `<main>-worker-w1a` and a folder with no record: `claude` not called | FR-011 |
| U10 | stub that updates another record (the fallback in research R4): exit 1 | FR-011 |
| U11 | `fix statusline` after `plugin`: the record's new path, every other key kept; before `plugin`: exit 3; in a checkout with no `.claude/settings.local.json`: the file is created with only `statusLine` | FR-012 |
| U12 | `fix` of each kind keeps other lines and keys; user data files byte-equal | FR-013, SC-003 |
| U13 | `fix file .stratum/state.json` writes st-init's value; `fix file .stratum/advisor.json` exit 3 | FR-014 |
| U14 | `fix models-key st-gone` leaves `st-build`; `fix gone-file .stratum/commit-mode` deletes it; `fix gone-file .stratum/lessons.md` exit 3 | FR-015 |
| U15 | `audit` with a dirty `CLAUDE.md` in the worktree: each row that would change `CLAUDE.md` there is `skip` with the detail `CLAUDE.md has uncommitted changes`, rows of its other files are not; a detached HEAD in a second worktree: every committed-file row there is `skip` with the detail `detached HEAD, no branch to commit on`; `CLAUDE.md` byte-equal | FR-017 |
| U16 | `fix statusline` with a custom command: exit 3; with `--force`: changed | FR-006, US3 |
| U17 | full run (stub plugin, every fix), then `audit`: only `current`, `gone`, `listed` | SC-001 |
| U18 | `claude` not on `PATH`: `plugin` prints the command, exit 1; `fix` still works | Edge case |
| U19 | script runs no `git add`, `git commit`, `git push` (grep of the script) | FR-016 |
| U20 | fake marketplace folder is a git repo on branch `feat-x`: `marketplace-branch` row `warn` naming `feat-x`; on `main`: no row; not a git repo: no row | Edge case (branch) |
| U21 | `pointer` fix on a folder with no `AGENTS.md`: `CLAUDE.md` gets only `@.stratum/constitution.md` | FR-013 |

`tests/test_update_rules.sh`: phrase rows on `skills/st-update/SKILL.md` for steps 1 to 8 above,
like `tests/test_plan_rules.sh`:

| Row | Phrase checked | FR |
|-----|----------------|----|
| R1 | `audit` call and the stop line for exit 1 | FR-001 |
| R2 | one table, only rows not `current`, one count line per folder | FR-009 |
| R3 | one gate, `skip <worktree>`, no change before the OK | FR-009, FR-010, D8 |
| R4 | the branch warning text | Edge case (branch) |
| R5 | `plugin` per folder, go on after a failure, a second `audit` whose rows steps 5 to 7 use | FR-011, FR-012 |
| R6 | `ask` rows: show the old and new command, `--force` only on yes | FR-006 |
| R7 | st-init steps 3, 4, 7, 11 questions, one at a time, `skip` leaves the file missing; `/stratum:st-constitution` | FR-014 |
| R8 | the commit command with `git -C` that ends with `-- <paths>`, the fixed path list, no `-A`, `--amend`, `--no-verify`, push | FR-016 |
| R9 | denied commit: quote the reason, give the command, name no personal script; gone: no `veent-commit-ask` text | D11 |
| R10 | blocked Bash call: give the exact `fix` command | FR-018 |
| R11 | report per folder and the restart line | FR-019 |
| R12 | Never list: user data files, `installed_plugins.json` | FR-013 |
| R13 | `README.md` has `claude plugin update stratum@stratum -s local`, `claude plugin update stratum@stratum -s project`, and the three test lines | FR-021 |

`tests/test_update_items.sh`: FR-020 (section 4).

## 4. FR-020 drift test

`tests/test_update_items.sh`, `root="${ST_ROOT:-<repo>}"`:

1. From `$root/skills/st-init/SKILL.md` collect: the backticked names in step 2 (`.gitignore`
   lines), the `@` lines in step 6 (pointer lines), each backticked `.stratum/<name>.json` or
   `.stratum/<name>.md` without `<` (files), and the settings keys from steps 7, 8 and 10: the
   first `"<key>":` in a backticked span right after `Merge in` or `merge`, when the key has no
   `<`, and each backticked name right after the word `into`. Today that gives `statusLine`,
   `enabledPlugins` and `permissions.allow`. The test has no fixed list of keys.
2. Run `bash $root/scripts/st-update.sh items`.
3. Each collected name missing from the items: `FAIL st-init names <name>, st-update items lack it`.
4. Negative control, only when `ST_ROOT` is not set: copy `skills/st-init/SKILL.md` and
   `scripts/st-update.sh` into a temp root, add `` `.stratum/zz-drift.json` `` to step 2 of the
   copy, run `ST_ROOT=<temp> bash tests/test_update_items.sh`, and check exit 1 and the name
   `.stratum/zz-drift.json` in its output.
