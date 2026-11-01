# Research: Custom Design Mode

Sources: FigCraft `docs/mcp.md`, `docs/cli.md`, `docs/control-protocol.md`,
`packaging/linux/flatpak/ai.storyteller.figcraft.yml`, `packaging/linux/nfpm.yaml`,
`packaging/linux/AppRun` and `packaging/linux/package.sh` at `storytold/figcraft` main, read
2026-11-01 with `gh api repos/storytold/figcraft/contents/<path>`. Release v0.13.1 (2026-10-31)
asset list from `gh api repos/storytold/figcraft/releases`. Claude Code 2.1.312 on this machine.
FigCraft is not installed on this machine, so every FigCraft fact below is from the docs until the
spikes (R15) run.

## R1. What a FigCraft install gives

- Decision: support the native packages and an AppImage named `figcraft` on the PATH. "FigCraft
  present" means `figcraft` on the PATH. "figcraft-cli present" means `figcraft-cli` on the PATH,
  or `figcraft cli --version` answers (an AppImage).
- Rationale: v0.13.1 ships `.pkg.tar.zst` (pacman, this machine is CachyOS), `.deb`, `.rpm`,
  `.tar.gz`, AppImage, `.flatpak`, a macOS `.dmg` plus a separate `figcraft-cli-…-macos-universal.zip`,
  and Windows `.msi`. `nfpm.yaml` puts `/usr/bin/figcraft` and `/usr/bin/figcraft-cli` in the
  deb, rpm and pkg (the `#cli` lines, kept when the CLI is built, `package.sh:103-106`). The
  AppImage runs the CLI as `FigCraft.AppImage cli <args>` (`AppRun`, `mcp.md:133`). There is no
  standalone Linux `figcraft-cli` asset.
- Alternatives: PATH only (loses AppImage users for one extra line); a config setting for the
  AppImage path (an option nobody asked for).

## R2. Flatpak is not supported (spec Assumption 5)

- Decision: the Flatpak is not a supported install for the custom mode. The install table names the
  native package for the machine. No spike: the manifest below is the evidence.
- Rationale: the Flatpak manifest builds only `-p figcraft` and installs only `/app/bin/figcraft`:
  no `figcraft-cli`. Its `finish-args` grant `xdg-documents` and `xdg-pictures` only, so the app
  cannot read a project folder such as `~/Desktop/<project>`, and the automation roots would name
  folders the sandbox cannot see. The spec's idea of a per-install command cannot work: there is no
  CLI to name.
- Alternatives: `flatpak override --filesystem=<project>` per project plus an AppImage for the CLI
  (two installs and a sandbox change per project).

## R3. File limits sit on the app, not on the MCP server (FR-007, D20)

- Decision: `scripts/st-figcraft.sh start` launches
  `figcraft --control <port> --automation-read-root <project> --automation-write-root <project>/design`.
  The MCP entry is `figcraft-cli mcp --attach <port>` with no roots.
- Rationale: `cli.md` (`mcp` section) and `mcp.md` (Confining file access): `--attach` with
  automation roots is a usage error (exit 2); an attached server is confined by the app's own
  flags. The app with roots also refuses hosting, joining, publishing and sharing ("automation
  roots are set: commands don't reach the network"), which gives SC-005. A root that is not an
  existing folder stops the app before its window opens, so `design/` is made first (spec Edge
  Cases). Roots arrived in 0.7.0; 0.6.0 and earlier ignore them, hence the version floor (R13).
- Not confined (`control-protocol.md`, Confining file access): files given on the app's command
  line and the app's own folders. The start passes no file.

## R4. Every attached call names the document

- Decision: the agent keeps the document `id` from `open_file` or `inspect_document` and passes
  `document` on every call.
- Rationale: `mcp.md` (Naming the document): tools act on the tab in front, so a tab the user clicks
  mid-task moves the next edit. `doc.list` gives agents ids and names but no paths.

## R5. Nothing outside `design/` is written through FigCraft (SC-005)

- Decision: FigCraft writes only `design/<screen>.figcraft` (MCP `save_file`) and the read-back
  files in `design/.read/<screen>/` (CLI with `--automation-write-root <project>/design`). The
  agent writes the project's token files, and the orchestrator's `document` step writes
  `DESIGN.md` and `.impeccable/design.json`, with the Write and Edit tools, from the text the
  CLI read back.
- Rationale: `variable.export {format: "css"}` without `path` returns `{text}` (`mcp.md:1208-1220`),
  so no FigCraft write leaves `design/`.

## R6. Read-back for the build: layout, picture, variables (FR-010, spec Assumption 6)

- Decision (until S5): three CLI calls on the saved file, outputs in `design/.read/<screen>/`:
  `convert <file> design.json` (FigCraft JSON, pretty-printed, the whole file), `render <file> -o
  design.png`, and `run export.json --in <file>` with one `variable.export {format: "css"}` step
  (its result line carries the CSS text).
- Rationale: `info --json` lists only top-level frames (`cli.md`, `info`). `convert` to `.json`
  writes the whole document. `render` gives the picture. All three take the automation roots and
  need no window.
- Fallback if S5 shows `design.json` lacks layer geometry, auto layout, fills, text or bound
  variables: a `run` script with `node.get {id: <frame>, depth: 99}` if `figcraft-cli commands
  --filter node.get` lists it, else headless `figcraft-cli mcp` with `open_file` and
  `inspect_document {depth: 99}`. Either change touches only `design-tool.md` Read.
- `design/.read/` is never committed, like the engine's screenshot folder.

## R7. One wrapper script for FigCraft: `scripts/st-figcraft.sh`

- Decision: one script with four subcommands: `check`, `start <project>`, `cli <args>`, `mcp`.
  `plugin.json` runs `bash ${CLAUDE_PLUGIN_ROOT}/scripts/st-figcraft.sh mcp`. The port is 7979,
  `ST_FIGCRAFT_PORT` overrides it (a test seam, marked `ponytail:`).
- Rationale: the CLI's command differs by install (R1), so a static `plugin.json` command cannot
  name it. The start has failure states (port in use, app for another project, app that exits at
  once) that need stub tests (SC-007, lessons L11, L39). `st-design-check.sh --custom` calls
  `st-figcraft.sh check`, so the FigCraft names stay in one script.
- Alternatives: start steps as Bash lines in `design-tool.md` (untestable, the agent rewords them,
  L39); `figcraft-cli` as the `plugin.json` command (no AppImage).

## R8. Plugin MCP tool names and the agent's tools line (FR-015, D18, spec Assumption 2)

- Decision (until S2): the server key is `figcraft`, so the tools are
  `mcp__plugin_stratum_figcraft__<tool>`. The agent's `tools:` line lists by name the 11 it needs:
  `list_commands`, `run_command`, `batch`, `create_node`, `set_properties`, `inspect_document`,
  `get_node`, `screenshot`, `open_file`, `save_file`, `undo`. Not `pointer`, `key`, `type_text`,
  `select`, `export`, `inspect_ui`, `wait_for_changes`, `redo`.
- Rationale: plugin MCP tools are named `mcp__plugin_<plugin>_<server>__<tool>`
  (`plugin-dev/skills/mcp-integration/references/tool-usage.md:7` in the official marketplace).
  Plugin subagents do not take an `mcpServers` frontmatter key, so the server comes from
  `plugin.json` and the agent names its tools. A named list keeps UI input injection out.
- S2 measures the real name and whether a subagent can call it. If a wildcard form works, the line
  still lists names (security, fewer tools).

## R9. Start record and detached launch

- Decision: `start` writes `<runtime dir>/st-figcraft-<port>` with the app's pid and the project
  root (`<runtime dir>` = `${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}`). The app runs under `nohup` in the
  background, stderr to `<runtime dir>/st-figcraft-<port>.log`. The script waits up to 20 s for the
  port to answer as FigCraft, and fails at once when the pid dies.
- Rationale: FR-005 (never closed) and FR-007 (confined to this project). The attached MCP server
  drives whatever app owns the port, so the lane must know that app was started with this
  project's roots. FigCraft has no method that reports its roots (`control-protocol.md` method list).
  The record is the only check that needs no FigCraft feature.
- S1 checks that the app survives the end of the Bash tool call and of the session.

## R10. Port 7979 owned by FigCraft for another project

- Decision: `start` stops with `FigCraft on port 7979 was not started for this project. Close it,
  then say go.` It never closes it (spec Edge Cases: the lane never kills another program).
- Consequence: a user who switches projects closes FigCraft once. The fixed port comes from D15 and
  the static `plugin.json` attach port.

## R11. The design file in the custom mode (FR-009, D21)

- Decision: after "good", the agent writes the saved design's variables into the project's token
  files (R12). Then the orchestrator runs section 2 step 4 (`st-impeccable document`, scan mode,
  grill answers as its Step 3 answers) and does not show its Step 5: the gate shows the file.
- Rationale: scan mode Step 1 reads CSS custom properties and token files first
  (`skills/st-impeccable/reference/document.md:82-92`), so it reads the values the agent just
  wrote: the design file comes from the design's variables and the grill answers with no new
  writer. Step 5 is a show-and-offer, not a hard gate (`document.md:342-347`).
- Section 2 step 4 answers `document`'s refresh, overwrite or merge question with "overwrite".
  In the existing-look case the old design file was the source of the first design's tokens, and
  the user's changes in FigCraft are now in the token files the scan reads. Overwrite keeps those
  changes and loses no value the design did not already carry. The committed old file stays in git.

## R12. Tokens back into code

- Decision: the agent writes each variable's value into the file the first design read it from:
  the files on the engine's Files line when the engine scaffolded them (new look), else the
  project's token file (existing look). It changes values, and adds a variable the user added in
  FigCraft as a new token in the same file.
- Rationale: FR-009 (tokens from the same variables, so a picked theme's tokens never ship over the
  user's changes). `design-tool.md` names "the engine's Files line", never the engine, so the
  `FR-010 one place` check (`tests/test_design_lane.sh`) stays green.

## R13. Version floor 0.13.1

- Decision: `check` needs `figcraft-cli` 0.13.1 or later. The install commands pin v0.13.1 in
  `design-tool.md`.
- Rationale: roots need 0.7.0 or later (R3). FigCraft is alpha and its commands change between
  minor versions. 0.13.1 is the version the docs and spikes cover. The repo pins upstream
  versions (`vendor.lock`, DESIGN.md D3).

## R14. Permission prompts for the FigCraft tools

- Finding: Claude Code asks before each MCP tool the first time, in the main session and for
  subagents. `hooks/st-approve.py:261` handles only Bash and edit tools, so FigCraft calls go to the
  normal prompt. Without a rule, a first custom run meets up to 11 prompts.
- Decision: D22 (decisions.md). On the user's FigCraft yes, `st-init` merges one allow rule for
  the server's tools into the project's `.claude/settings.json` (contract 7d).

## R15. Spike results

Filled by tasks T001 to T005. Each entry: the command, the output line that decides it, pass or
fail, and the fallback taken.

- S3 (plugin.json MCP entry, no `figcraft-cli`): not run yet.
- S2 (plugin subagent calls a plugin MCP tool, tool name form): not run yet.
- S0 (install gives `figcraft` and `figcraft-cli`, `--version` format): not run yet.
- S1 (attached MCP sees unsaved changes and selection; lazy attach; app survives the Bash call;
  roots refuse a write outside `design/`): not run yet.
- S5 (full layer-tree read without a window): not run yet.

## R16. Live runs

Filled by T014, T015, T016, T019 and T020: L1 to L5 of quickstart section 4.
