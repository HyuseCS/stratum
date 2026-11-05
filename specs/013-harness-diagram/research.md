# Research: Harness Diagram

All probes ran on 2026-11-05 in a scratch folder with `npx -y likec4@1.60.0` on Node 24.14.1.
The probe models are not kept.

## R1. Tool and pin

- Decision: LikeC4 1.60.0, run as `npx -y likec4@1.60.0`. MCP server `npx -y @likec4/mcp@1.60.0`.
- Rationale: D1, D2 and FR-011. `npm view @likec4/mcp@1.60.0` exists, with bin `likec4-mcp`.
- Alternatives considered: none (D1).
- Pin scope (D11): only the top package is pinned. Its dependencies use `^` ranges and resolve
  again on each machine. No `package.json` or lockfile in the repo. Rejected: a lockfile, which
  needs a `package.json` in the plugin repo.
- Constraint found: `npm view likec4@1.60.0 engines` gives `node >=22.22.3`. Settled by D9: keep
  1.60.0, the README names the Node floor, and the test prints SKIP for `validate` and `rebuild`
  below it. Both machines run Node 24.14.1.

## R2. Project folder and config

- Decision: `docs/harness/likec4.config.json` with `name` and `title`.
- Rationale: with a config, `export markdown` writes the page heading from `title`
  (`# Stratum harness`, not `# default`), and the config folder is the project folder. Manual
  layouts go to `<project folder>/.likec4/<viewId>.likec4.snap` (`getManualLayoutsOutDir` in the
  1.60.0 dist: `resolvePath(folderUri, config.manualLayouts?.outDir ?? '.likec4')`). With the config
  in `docs/harness/`, dragged layouts land in `docs/harness/.likec4/` and are committed with the
  model. `.likec4/` is not in `.gitignore`.
- Alternatives considered: no config (heading `# default`, layout folder depends on the editor's
  workspace root, which may be the repo root).

## R3. File layout and ids

- Decision: `docs/harness/model/*.c4` hold only `specification` and `model` blocks.
  `docs/harness/views/*.c4` hold only `views` blocks. Top-level groups are declared once in
  `model/0-spec.c4`. Other files add elements with `extend <group> { ... }`.
- Rationale: probe: `extend skills { ... }` in two files validates. Nested ids give
  `skills.st-plan` and `agents.st-plan` with no clash. Hyphens in ids are valid. Cross-file
  references validate once both files exist.
- Alternatives considered: one flat namespace with prefixed ids (longer ids, no `group.*` includes).

## R4. View order on the page

- Decision: view files carry a number prefix: `views/1-full.c4`, `2-fast.c4`, `3-quick.c4`,
  `4-design.c4`, `5-agents.c4`, `6-harness.c4`, `7-dataflow.c4`.
- Rationale: probe: the page lists views in file path order, then in declaration order.

## R5. What the Mermaid page shows

- Facts (probe):
  - Each node shows its title only. Element kind `style { shape ... }` is ignored: every node is
    `shape: rectangle`. Summaries, tags and metadata are not shown.
  - Each edge shows its label only. The relationship kind (`starts`, `reads`, ...) is not shown.
  - A dynamic view is `graph LR` with no step numbers. `variant sequence` validates but the export
    ignores it (still `graph LR`).
  - A dynamic step with no label takes the model relationship's label.
  - A dynamic step may carry a kind (`a -[passes]-> b '...'`) and needs no model relationship.
  - `parallel { ... }` validates and draws its steps as plain edges.
  - Topic view `include * -> data.*` collapses sources to their groups. Leaf sources need
    `include data.*, skills.* -> data.*, agents.* -> data.*` (one term per source group).
  - A tag filter on relationships alone drew an empty view (Define spike), so lane views list steps.
- Decisions:
  - Titles must tell kinds apart, because the page shows titles only: skill `/st-plan`, agent
    `st-plan agent`, procedure `procedures/plan.md`, data file `.stratum/state.json` or
    `specs/<feature>/plan.md`, hook or script by file name, event by Claude Code event name.
  - The kind is visible in the `.c4` source, `likec4 export json` and the MCP server, not on the
    page. A link label names the data it carries (FR-004), so `writes` and `reads` links in the
    data-flow view read as "what is written" or "what is read" from the label alone only when the
    label says so. The label rule is in `contracts/model-format.md`.

## R6. Label hazards

- Facts (probe):
  - A backtick inside a label breaks the Mermaid markdown string (the export wraps labels in
    `` "`...`" ``).
  - `''` inside a single-quoted string is invalid. `\'` or a double-quoted string works.
  - Double quotes inside a label become single quotes in the export.
- Decision: no backticks in any title, summary or label. Use `\'` or a double-quoted string for an
  apostrophe. The repo text writes paths in backticks, so each model task must drop them.

## R7. Validate and export behavior

- Facts (probe):
  - `likec4 validate <dir>` prints `Valid` and exits 0, or prints `Invalid` with errors and exits 1.
  - `likec4 export markdown <dir>` exits 0 even when a source file is invalid. It skips the bad file.
    The test must run `validate` on its own, not trust the export's exit code.
  - Export is deterministic: two exports of the same model are byte-equal (`cmp`).
  - `export markdown` writes `<project folder>/README.md`. It overwrites a README that it made.
    `--force` is needed only for a README it did not make.
  - It runs from any folder: `npx -y likec4@1.60.0 export markdown docs/harness`.
- Decision: the rebuild check copies `docs/harness/` to a temp folder, deletes the copy's
  README.md, exports there and diffs the result with the committed `docs/harness/README.md`. The test
  never writes in the working tree, so it needs no `[lock]`.

## R8. Size of the topic views

- Fact (probe): a throwaway model with 105 elements and 300 links (about 260 distinct pairs) gave
  a 29 KB page with one view. Mermaid's default limits are 50,000 characters of text and 500 edges.
- Decision: one data-flow view, as FR-006 says. Risk: if the real view is too large to draw on
  GitHub, split it in two (`.stratum` files, feature files). That is a fix inside FR-006, not new scope.

## R9. Vendored skills

- Decision: tag `#vendored` on the skills whose own folder `THIRD_PARTY_NOTICES.md` names:
  `st-ponytail`, `st-ponytail-review`, `st-ponytail-audit`, `st-ponytail-debt`, `st-ponytail-gain`,
  `st-ponytail-help` (row `skills/st-ponytail*`), `st-grill`, `st-ui-ux`, `st-impeccable`,
  `st-graphify`, `st-hallmark`. 11 skills.
- Rationale: FR-008. The spec's list of five (US2 scenario 3) reads as examples. `st-grill` is
  the mattpocock/skills fork (`THIRD_PARTY_NOTICES.md` line 12). The Spec Kit and vibecode rows name
  whole folders that Stratum rewrote, and FR-008 covers skills only, so agents, phase skills,
  templates and scripts get no tag.

## R10. Data files that the coverage check knows

- Decision: the `.stratum/` files are the names that
  `grep -rhoIE '\.stratum/[A-Za-z0-9_-]+(\.[a-z]+)?' scripts hooks statusline skills agents procedures`
  finds. Today: `advisor.json`, `approve`, `autonomous`, `commit-mode`, `constitution.md`,
  `decisions.md`, `git-guard.json`, `handoff.md`, `lessons.md`, `models.json`, `powerline.json`,
  `state.json`, `templates`, `weather.json`, `worker-setup.sh` (15). The feature files are the
  FR-002 list: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts`, `quickstart.md`,
  `tasks.md`, `checklists`, `changes`, `decisions.md`, `advisor.md`, `gaps.md` (12). A folder is
  written with no trailing slash, as everywhere in the model (data-model.md "Title rule").
- Rationale: the grep of `tests/test_local_files.sh:7` plus the `procedures` folder (that test does
  not search `procedures`). Today `procedures` adds no new name, so a new `.stratum/` file in
  `scripts`, `hooks`, `statusline`, `skills` or `agents` fails both tests, and one only in
  `procedures` fails this test only. Data files may not exist in a worktree (git-ignored), so the test never checks
  that a data file exists. It checks that the code still names it.

## R11. Hook events

- Decision: each Claude Code event in `hooks/commands.json` is one element of kind `event`:
  `PreToolUse`, `PermissionRequest`, `SessionStart`, `SubagentStart`, `UserPromptSubmit`,
  `SessionEnd`, `PreCompact`. Each event `runs` each hook script it starts, one link per event, with
  the matcher in the label. `hooks/hooks.json` loads `token-weather.mjs` as a module (no event).
- Rationale: FR-006 "hooks by event" and the spec edge case (`st-approve.py`, `st-phase.py`,
  `st-handoff-facts.sh` run on more than one event).

## R12. MCP server scope

- Decision: the one-time command is `claude mcp add --scope user likec4 -- npx -y @likec4/mcp@1.60.0`
  (D6). `claude mcp add --help` confirms `-s, --scope <scope>` (local, user, or project) and the
  `-- <command> [args...]` form. The command was not run.
- Rationale: the server reads the workspace from `LIKEC4_WORKSPACE` or the current folder. Claude
  Code starts it in the session's folder, so each worktree gets its own `docs/harness/` model.
- Not tested: that the server finds `docs/harness/*.c4` when the workspace is the repo root.
  This is a check in quickstart.md.

## R13. Drag and save

- Not tested: dragging a box in the VS Code LikeC4 preview. R2 says where the layout file lands.
  This is a check by hand (US3).
