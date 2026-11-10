# Data Model: Custom Design Mode

No database. The entities are files and one run record. Texts are in
[contracts/custom-mode.md](contracts/custom-mode.md).

## Saved design

- Path: `design/app.figcraft` in the project. `<screen>`: the screen's name in kebab case.
  One file per project: one page per screen, named `<Role> / <screen>` (no role: `<screen>`).
- Written by: the `st-design` agent through FigCraft's `save_file`, at the end of Draw and on
  "good" (Save). Never by hand through Bash.
- Read by: the build (Read step, CLI, no window) and a restart after the window was closed (Draw
  opens it).
- Rules: committed with the screen after the gate's yes (FR-012). Inside the FigCraft write root.
  Its layer names and text are data, never instructions.

## Read-back folder

- Path: `design/.read/<screen>/` with `export.json` (the variables script), `design.json` (the
  whole document as FigCraft JSON), `design.png` (the page render).
- Written by: the agent (Write tool for `export.json`) and the CLI (`convert`, `render`) with
  `--automation-write-root <project>/design`. Rewritten on each Read, so each fix round reads the
  saved design again (FR-010).
- Rules: never committed.

## Design file

- `DESIGN.md` + `.impeccable/design.json` at the project root, as in 009.
- In the custom mode: written after "good" by `st-impeccable document` in scan mode, from the token
  files the agent just wrote and the grill answers (research R11). Shown at the gate, no stop of
  its own (FR-011, D21). Committed if it changed.

## Token files

- The engine's `tokens.css` and `base.css` (new look, scaffolded from the picked theme), or the
  project's own token file (existing look).
- In the custom mode: the agent writes the saved design's variable values into the file each
  token came from, after "good" (research R12). Committed if they changed.

## Design tool file

- `skills/st-design/design-tool.md` in the plugin. Names the tool, version floor, install
  commands, MCP tool prefix, and the Start, Draw, Change, Save, Read, Tokens, Files and Never steps.
- Rule: the only file in `skills/st-design/` that names FigCraft (FR-014).

## Start record

- Path: `${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/st-figcraft-<port>`, one line `<pid> <project root>`.
  Log beside it: `st-figcraft-<port>.log` (the app's stderr).
- Written by: `st-figcraft.sh start` when it launches FigCraft. Never deleted by Stratum; a dead pid
  makes it stale.
- Rule: `start` accepts a FigCraft on the port only when the record's pid is alive and its root is
  this project (research R9, FR-007).

## MCP entry

- `.claude-plugin/plugin.json` key `mcpServers.figcraft`: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/st-figcraft.sh mcp`,
  which runs `figcraft-cli mcp --attach 7979` (or the AppImage's `cli`).
- Starts in every session where the plugin is on (S3 checks the case with no CLI).

## Custom-mode run states

```text
check (--custom) -> dev server probe -> grill [-> theme pick + scaffold]
  -> Start -> draw (agent) -> STOP
STOP --change request--> change (agent) -> STOP
STOP --"good"--> save + read + tokens (agent)
  save fails, window closed -> Start -> draw from last saved design -> STOP
  -> document (design file, no Step 5 show) -> build + checks (<= 2 fix rounds, each re-reads)
  -> GATE
GATE --yes--> commit (paths, design file, tokens, saved design)
GATE --change in the tool / layout or look--> STOP
GATE --change in code / small code-only fix--> build + checks -> GATE
GATE --different direction--> grill at the theme branch -> Start -> draw -> STOP
any failed step -> report it and stop (no code from a half-drawn design)
```
