# Implementation Plan: Custom Design Mode

**Branch**: `011-custom-design-mode` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/011-custom-design-mode/spec.md`, decisions D9 to D21
in [decisions.md](decisions.md), GitHub issue #57.

**Status**: No open decisions. D22 (decisions.md, 2026-11-01) settles the FigCraft allow rule
(contract 7d, tasks T017 and T018). Five spikes (S0, S1, S2, S3, S5) run first. Some of their results can change named
parts of the contract (contract header).

## Summary

A third Design-lane mode, "custom", in `skills/st-design/SKILL.md` section 6. After the new-look
grill (with the theme branch only for a new look or an overhaul, D16), the lane runs
`scripts/st-figcraft.sh start`. That makes `design/` and starts FigCraft on port 7979 with the
project as its read root and `design/` as its write root, unless this project's FigCraft already
answers. The `st-design` agent draws the screen live through FigCraft's MCP server, which the
plugin declares in `.claude-plugin/plugin.json` and which attaches to that app. The lane stops
once. Change requests go to the agent and the lane stays stopped. On "good", the agent saves
`design/<screen>.figcraft`, reads it back with the CLI (JSON layout, PNG, variables as CSS) and
writes the variables into the project's token files. `st-impeccable document` (scan mode, no Step 5
show) then writes `DESIGN.md` from those tokens and the grill answers. Then come the usual build,
checks, fix rounds (each re-reads the saved file), gate and commit, plus the saved design. All
FigCraft steps live in `skills/st-design/design-tool.md`. `st-design-check.sh --custom` checks
FigCraft only for this mode. `st-status` shows it as optional, and `st-init` offers the install
command.

## Technical Context

**Language/Version**: Markdown (skills, agent), Bash 5 (script, tests), Python 3 (`python3 -I`
for the port probe in the script and the plugin.json check in the test). JSON (`plugin.json`).

**Primary Dependencies**: Claude Code 2.1.312 plugin layout: `plugin.json` `mcpServers`, plugin MCP
tools named `mcp__plugin_<plugin>_<server>__<tool>` (research R8, S2 confirms). FigCraft 0.13.1 or
later, an external native app the user installs (research R1, R13): `figcraft --control <port>`
with automation roots, `figcraft-cli mcp --attach <port>`, `figcraft-cli convert|render|run`. No
new package in Stratum.

**Storage**: Project files: `design/<screen>.figcraft` (committed), `design/.read/<screen>/` (never
committed), `DESIGN.md`, `.impeccable/design.json`, token files. Machine file: the start record
`${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/st-figcraft-7979` (data-model.md).

**Testing**: `bash tests/test_figcraft.sh` (new, cases F1 to F10), `bash tests/test_design_check.sh`
(K14 to K20 added), `bash tests/test_design_lane.sh` (rows and checks added),
`bash tests/test_plan_rules.sh` (DL1 changed), `bash tests/test_inspect.sh` (README two-way checks),
`bash tests/test_model_files.sh`, `claude plugin validate .claude-plugin/plugin.json`. Spikes and live
runs by hand (quickstart sections 1 and 4).

**Target Platform**: Claude Code on Linux (laptop: CachyOS, pacman; PC: the same steps with its
package manager) and macOS. FigCraft is a desktop window on the same machine.

**Project Type**: Claude Code plugin (skills, agent, scripts, plugin manifest).

**Performance Goals**: N/A. Start waits at most 20 s for the app. Fix rounds stay at most 2.

**Constraints**: No comments except `ponytail:` markers. Minimal diff. `st-build`, `st-fast`,
`st-full`, the engine and vendored files unchanged. The agent count stays 15. The lane never closes
FigCraft (FR-005), never kills a program on the port, and never runs an install. `skills/st-design/`
names FigCraft only in `design-tool.md` (FR-014), and the engine only in `engine.md` (009 FR-010).

**Scale/Scope**: New: `skills/st-design/design-tool.md`, `scripts/st-figcraft.sh`,
`tests/test_figcraft.sh`. Edits: `skills/st-design/SKILL.md`, `agents/st-design.md`,
`scripts/st-design-check.sh`, `.claude-plugin/plugin.json`, `skills/st/SKILL.md`,
`agents/st-plan.md`, `skills/st-status/SKILL.md`, `skills/st-init/SKILL.md`, `README.md`,
`DESIGN.md`, `tests/test_design_check.sh`, `tests/test_design_lane.sh`, `tests/test_plan_rules.sh`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md`, on purpose (base repo). The gates come from the Plan
agent rules.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that can fail, before its build task | Pass. FR-001 to FR-016 lane texts: T010 before T011, T012 before T013. FR-003: DL1 in T012 before T013. FR-013: T012 before T013. FR-015: T010 and T012 before T011 and T013. FR-016: T007 before T009. FR-005 and FR-007 (start behavior): T006 before T008. FR-017: T017 before T018 |
| G2. Every task names its files and its exact test command, and none runs the full suite | Pass (tasks.md) |
| G3. `[P]` only for tasks that share no file in their phase and need no other task's result, each with `Owns:` | Pass. Only T006, T007 and T010 (Phase 2) |
| G4. `[screen]` tasks | None. This feature changes Stratum and adds no app screen |
| G5. Security notes for access rules, data model, contracts, secrets, external services | Pass. S1 to S7 below |
| G6. No speculative work | Pass. No other design tool (D14), no Plan marks for existing screens (D17), no FigCraft code export, no Flatpak support (research R2), no port setting beyond a test seam |
| G7. Ground in the installed code and versions | Pass, with one limit: FigCraft is not installed here, so its facts come from the v0.13.1-era docs until spikes S0, S1 and S5 run (F1) |
| G8. Each new check has a negative control | Pass. Quickstart section 3, N1 to N8 |
| G9. Tests leave no files or processes | Pass. F10 and the existing K11 compare `git status`; F10 checks pids |

Post-design re-check: all gates pass. Complexity Tracking stays empty.

## Security Notes

- **S1. External app on the user's machine (T008, T011, T018).** FigCraft is an alpha native app from
  GitHub releases. The user installs it with a pinned v0.13.1 command (`design-tool.md`). Stratum
  prints the command and never runs it (`hooks/st-approve.py` refuses `sudo`, package managers and
  URLs anyway). `check` refuses a CLI below 0.13.1, since 0.6.0 and earlier ignore the roots.
- **S2. File and network limits (T008, FR-007, SC-005).** `start` launches the app with
  `--automation-read-root <project> --automation-write-root <project>/design`. The attached MCP
  server has no limits of its own: `--attach` refuses roots, and the app enforces them for every
  request and for the user's own clicks (research R3). With roots set, hosting, joining, publishing
  and sharing are refused, so no design reaches a server. The CLI read-back runs with the same
  roots. Not confined: the app's own folders (preferences, recovery copies). A root on a network
  share would send files to that share; project folders are local.
- **S3. Local control socket (T008).** The app listens on `127.0.0.1:7979` only. Any local
  process can drive it while it runs: FigCraft's design, and a local-user boundary. The probe
  sends one `window.list` line and reads one reply. `start` accepts a running FigCraft only when its
  start record names this project and a live pid (research R9), so the agent never drives an
  unconfined app that Stratum did not start. A stale pid reused by another process is a known gap,
  marked `ponytail:` in the script.
- **S4. MCP server in every session (T011).** The `plugin.json` entry runs
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/st-figcraft.sh mcp` in every session of every project with
  the plugin on. It execs the user's installed `figcraft-cli mcp --attach 7979`, which talks only to
  127.0.0.1. With no CLI it exits 127 and touches nothing. S3 checks that this does not warn or
  break a session.
- **S5. Untrusted input (T013).** Layer names and text in a saved design, `DESIGN.md` and the
  user's material are data. The agent's Never list and `design-tool.md` Never say so.
- **S6. Agent tool scope (T013, T018).** The agent gets 11 named FigCraft tools (research R8). It gets no
  UI input injection (`pointer`, `key`, `type_text`) and no wildcard. Its FigCraft calls get
  no prompt once `st-init` has added the D22 allow rule to the project's `.claude/settings.json`
  on the user's yes. The rule covers only this server's tools, and the app's roots (S2) limit
  what they reach. `hooks/st-approve.py` refuses `.claude` paths only in autonomous mode with
  `.stratum/approve/` present. `st-init` runs interactively, so its write is not blocked.
- **S7. No access rules, sign-in, data model, contracts, secrets or personal data.** The custom mode
  builds the same front end as the other modes. The start record holds a pid and a path only.

## Breaking Changes

- None for stored data.
- `tests/test_plan_rules.sh` DL1 and the agent `tools:` row in `tests/test_design_lane.sh` change
  with their texts (T012).
- Every session with the plugin starts one extra MCP server process (S4).
- Rollback: revert the feature's commits.

## Decisions

- D22 (decisions.md, Q20, O31): on the user's FigCraft yes, `st-init` step 10 merges one allow
  rule for the FigCraft MCP tools (`mcp__plugin_stratum_figcraft`, or the prefix S2 records) into
  `permissions.allow` of the project's `.claude/settings.json`, keeping every other key. Step 12
  already commits that file, so both machines get it. Contract 7d, tasks T017 and T018.
- No open decisions.

## Project Structure

### Documentation (this feature)

```text
specs/011-custom-design-mode/
├── spec.md
├── decisions.md
├── plan.md
├── research.md          # R1 to R14 decisions, R15 spike results, R16 live runs
├── data-model.md
├── quickstart.md        # install, spikes, suites, negative controls, live runs
├── contracts/
│   └── custom-mode.md   # texts, script behavior, plugin.json entry, phrase table, cases
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
skills/
├── st-design/
│   ├── SKILL.md          # section 1 steps 1 and 4, section 4 step 1, section 5, Report, Never, new section 6
│   └── design-tool.md    # new: the only lane file that names FigCraft (FR-014)
├── st/SKILL.md           # Custom design row (FR-002)
├── st-status/SKILL.md    # FigCraft optional line (FR-017)
└── st-init/SKILL.md      # FigCraft install offer and allow rule (FR-017, D22)
agents/
├── st-design.md          # tools line, custom steps, Never, Report
└── st-plan.md            # [screen: custom] (FR-003)
scripts/
├── st-figcraft.sh        # new: check, start, cli, mcp
└── st-design-check.sh    # --custom
.claude-plugin/plugin.json  # mcpServers.figcraft (FR-015)
tests/
├── test_figcraft.sh      # new: F1 to F10
├── test_design_check.sh  # K14 to K20
├── test_design_lane.sh   # rows and checks
└── test_plan_rules.sh    # DL1
README.md                 # requirement row, tests block, Design lane lines
DESIGN.md                 # st-design skill row
```

**Structure Decision**: Plugin layout as it is. `design-tool.md` copies the frame of
`skills/st-design/engine.md`. `scripts/st-figcraft.sh` follows `scripts/st-design-check.sh` (stub-PATH
safe). `tests/test_figcraft.sh` copies the frame of `tests/test_design_check.sh`.

## Complexity Tracking

Empty: no gate violations.
