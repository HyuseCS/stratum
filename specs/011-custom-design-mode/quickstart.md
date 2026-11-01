# Quickstart: Custom Design Mode

Run from the repo root `/home/hyuse/Desktop/stratum` unless a step says otherwise. Scratch work goes
in the session scratchpad, never in the repo (lessons L8). Texts and cases are in
[contracts/custom-mode.md](contracts/custom-mode.md).

## 0. Install FigCraft (the user does this)

Agents cannot install it: `hooks/st-approve.py` refuses `sudo`, `pacman`, `curl` and URLs, and an
install is the user's step. On each machine, run the line for its package manager (`<arch>` from
`uname -m`):

```sh
# pacman (this laptop, CachyOS)
sudo pacman -U https://github.com/storytold/figcraft/releases/download/v0.13.1/figcraft-0.13.1-linux-x86_64.pkg.tar.zst
# apt
curl -LO https://github.com/storytold/figcraft/releases/download/v0.13.1/figcraft-0.13.1-linux-<arch>.deb && sudo apt install ./figcraft-0.13.1-linux-<arch>.deb
# dnf
sudo dnf install https://github.com/storytold/figcraft/releases/download/v0.13.1/figcraft-0.13.1-linux-<arch>.rpm
```

Then: `command -v figcraft figcraft-cli` prints two paths, and `figcraft-cli --version` prints a
version.

## 1. Spikes (Phase 1)

Each spike writes its entry in research.md R15: the command, the deciding output line, pass or
fail, the fallback taken. A spike that cannot run writes `Not run, <reason>` (lessons L24).

- **S3, MCP entry with no CLI (no install needed).** Copy the plugin to a scratch folder
  `<s3>/stratum-spike`, set its `plugin.json` `name` to `stratum-spike`, and add the section 6
  entry, pointing at a scratch `fail.sh` that prints `missing: figcraft-cli` on stderr and exits
  127 (what `st-figcraft.sh mcp` does with no CLI). Run
  `claude --plugin-dir <s3>/stratum-spike -p "Say ok."` and keep stdout, stderr and the exit code.
  Then the user starts `claude --plugin-dir <s3>/stratum-spike` in a terminal and says what the
  start screen shows. Pass: `-p` exits 0 and prints `ok` with no MCP line; the start screen shows
  no MCP warning (a failed status in `/mcp` alone is a pass). Fail: contract section 6 fallback.
  Second check, same copy with `fail.sh`: add a scratch agent `agents/spike-read.md` with
  `tools: Read, mcp__plugin_stratum-spike_figcraft__ping` and run
  `claude --plugin-dir <s3>/stratum-spike -p "Start the stratum-spike:spike-read agent. It reads README.md and reports its first line."`.
  Pass: the agent starts and reports the line (an agent whose `tools:` names an absent server's
  tool still runs, so new-look and autonomous runs work without FigCraft, SC-004). Fail: drop the
  `tools:` line from `agents/st-design.md` (the agent then inherits every tool, MCP included), and
  change the `FR-001 agent frontmatter` and `FR-015 agent tools` checks and plan S6 to match.
- **S2, plugin subagent calls a plugin MCP tool (no install needed).** In the S3 copy, swap
  `fail.sh` for a scratch stdio MCP server (`python3 -I`, about 30 lines: `initialize`,
  `tools/list` with one `ping` tool, `tools/call` answering `pong`), add a scratch agent
  `agents/spike.md` with `tools: Read, mcp__plugin_stratum-spike_figcraft__ping`, and run
  `claude --plugin-dir <s3>/stratum-spike -p "Start the stratum-spike:spike agent. It calls its ping tool and reports the reply." --allowedTools mcp__plugin_stratum-spike_figcraft__ping`.
  Record: the reply, the exact tool name from `claude --plugin-dir <s3>/stratum-spike mcp list`
  or the agent's tool list, and whether the run without `--allowedTools` asked for permission.
  Pass: the agent's report holds `pong`. Fail: Build stops and asks the user (tasks T002).
- **S0, install.** After section 0: `command -v figcraft figcraft-cli; figcraft-cli --version`.
  Record the version line format (the `check` parser takes the first `N.N.N`).
- **S1, live attach.** In a scratch project `<p>` with `<p>/design`:
  1. Start a scratch stdio JSON-RPC client (`python3 -I`) on `figcraft-cli mcp --attach 7979`
     before FigCraft runs. Call `inspect_ui`: record the error.
  2. From a Bash tool call: `nohup figcraft --control 7979 --automation-read-root <p> --automation-write-root <p>/design >/dev/null 2>&1 &`.
     The Bash call returns. Call `inspect_ui` again on the same client: pass if it answers (lazy
     attach).
  3. `create_node` a frame and a rectangle. The user drags the rectangle by hand, selects it, and
     does not save. `inspect_document`: pass if `dirty` is true, the rectangle's `x` is the moved
     one and `selection` holds its id.
  4. `save_file {path: "<p>/design/s1.figcraft"}`: written. `save_file {path: "<p>/s1.figcraft"}`:
     pass if refused with `automation path rejected`.
  5. End the Claude session that ran step 2: pass if the FigCraft window stays open.
  Fail of 3: Build stops and asks the user (tasks T004). Fail of 2: the lane runs Start before the
  session's first FigCraft call and the user restarts the session once (a note in
  `design-tool.md`). Fail of 5: `setsid` before `nohup` where present.
- **S5, read-back.** On `<p>/design/s1.figcraft`: the three Read commands of contract section 2.
  Pass: `design.json` holds, for each layer, name, type, x, y, width, height, auto layout,
  fills, text and bound variables; `design.png` shows the frame; the `run` line's `result.text`
  holds `--` CSS properties. Fail: research R6 fallback, then contract section 2 Read changes.
- No Flatpak spike: research R2 shows from the manifest that the Flatpak has no CLI and no
  project access.

## 2. Red states and suites

Before each build task, its new rows or cases are red; after it, green:

```sh
bash tests/test_figcraft.sh
bash tests/test_design_check.sh
bash tests/test_design_lane.sh
bash tests/test_plan_rules.sh
bash tests/test_inspect.sh
bash tests/test_model_files.sh
claude plugin validate .claude-plugin/plugin.json
```

## 3. Negative controls (lessons L2, L20, L25)

Run each right after a green baseline, on a scratch copy (`ST_ROOT=<copy>`), one break per copy:

- N1 `st-figcraft.sh` drops `--automation-write-root`: F1 red.
- N2 `start` skips the record check: F3 red.
- N3 `st-design-check.sh` runs the FigCraft check without `--custom`: K18 red.
- N4 the version compare treats 0.12.1 as new enough: K17 red.
- N5 `plugin.json` without `mcpServers`: `FR-015 mcp entry` red.
- N6 `skills/st-design/SKILL.md` gets the word FigCraft: `FR-014 one place` red.
- N7 the agent `tools:` line gains `mcp__plugin_stratum_figcraft__pointer`: `FR-015 agent tools` red.
- N8 `design-tool.md` names the engine by name: `FR-010 one place` red.

## 4. Live runs (by hand, lessons L32)

Each run starts the lane by typing the slash command (lessons L12) in a scratch project the user
picks, with its dev server started by the user. Record each in research.md R16.

- **L1 (US1, SC-001, SC-002, SC-003, SC-005).** A project with a design file:
  `/stratum:st-design a settings screen, custom design`. Answer the grill. FigCraft opens by
  itself and the design appears. By hand: move one block, resize one, recolor one. Say "looks
  good". Pass: no stop between "looks good" and the gate; the gate's screenshots show all three
  changes; the gate shows `DESIGN.md`; on yes the commit holds the screen, `DESIGN.md`,
  `.impeccable/design.json`, the token file and `design/settings.figcraft`; after the commit
  `git status` shows only `design/.read/` untracked.
- **L2 (US2).** A project with a built screen: `/stratum:st make the dashboard better, custom design`.
  Pass: `Lane: Design`; FigCraft shows the current dashboard in the existing look; after one change
  and "good", the rebuilt screen has that change and the rest as before.
- **L3 (US3).** At an L1 gate: "more space between the cards" (no way named): the lane stops in
  FigCraft again. Then "fix the title text, in code": fixed in code, no FigCraft stop.
- **L4 (US4).** `/stratum:st-init` in a project without FigCraft on the PATH (run it with a PATH
  that hides it): the offer and the pacman line, and on yes `.claude/settings.json` gains the
  FigCraft allow rule with every other key kept (D22). A custom task: stops with the install link before
  any question. A new-look task: goes on (SC-004). `/stratum:st-status`: the FigCraft lines under
  `FigCraft (optional, for the custom mode):`.
- **L5 (SC-006).** L1 again on the PC, after `git pull` and section 0 there.
- **Edge runs.** During L1's stop, close the FigCraft window, then say "good": the lane says the
  changes are lost, FigCraft opens on the last saved design, and the lane stops again. Run a custom
  task while another program holds port 7979 (`python3 -m http.server 7979`): the port line.
