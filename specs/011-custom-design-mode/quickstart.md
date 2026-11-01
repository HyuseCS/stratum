# Quickstart: Custom Design Mode

Run from the repo root `/home/hyuse/Desktop/stratum` unless a step says otherwise. Scratch work goes
in the session scratchpad, never in the repo (lessons L8). Texts and cases are in
[contracts/custom-mode.md](contracts/custom-mode.md).

## 0. Install FigCraft (the user does this)

Agents cannot install it: `hooks/st-approve.py` refuses `sudo`, `pacman`, `curl` and URLs, and an
install is the user's step. On each machine (Linux only), run the line for its package manager
(`<arch>` from `uname -m`). Each line checks the package against the release's `SHA256SUMS.txt`
before it installs it (contract section 2, Install):

```sh
# pacman (this laptop, CachyOS)
cd "$(mktemp -d)" && curl -LO https://github.com/storytold/figcraft/releases/download/v0.13.1/figcraft-0.13.1-linux-x86_64.pkg.tar.zst -LO https://github.com/storytold/figcraft/releases/download/v0.13.1/SHA256SUMS.txt && sha256sum -c --ignore-missing SHA256SUMS.txt && sudo pacman -U ./figcraft-0.13.1-linux-x86_64.pkg.tar.zst
# apt
cd "$(mktemp -d)" && curl -LO https://github.com/storytold/figcraft/releases/download/v0.13.1/figcraft-0.13.1-linux-<arch>.deb -LO https://github.com/storytold/figcraft/releases/download/v0.13.1/SHA256SUMS.txt && sha256sum -c --ignore-missing SHA256SUMS.txt && sudo apt install ./figcraft-0.13.1-linux-<arch>.deb
# dnf
cd "$(mktemp -d)" && curl -LO https://github.com/storytold/figcraft/releases/download/v0.13.1/figcraft-0.13.1-linux-<arch>.rpm -LO https://github.com/storytold/figcraft/releases/download/v0.13.1/SHA256SUMS.txt && sha256sum -c --ignore-missing SHA256SUMS.txt && sudo dnf install ./figcraft-0.13.1-linux-<arch>.rpm
```

Then: `sha256sum` printed `OK` for the package, `command -v figcraft figcraft-cli` prints two
paths, and `figcraft-cli --version` prints a version. A `sha256sum` failure stops the line before
the install: do not install, tell the coordinator.

## 1. Spikes (Phase 1)

Each spike writes its entry in research.md R15: the command, the deciding output line, pass or
fail, the fallback taken. A spike that cannot run writes `Not run, <reason>` (lessons L24).

- **S3, MCP entry with no CLI (no install needed).** Copy the plugin to a scratch folder
  `<s3>/stratum-spike`, set its `plugin.json` `name` to `stratum-spike`, and add the section 6
  entry in the same form, through `${CLAUDE_PLUGIN_ROOT}`:
  `"mcpServers": {"figcraft": {"command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/fail.sh"]}}`,
  with `<s3>/stratum-spike/fail.sh` printing `missing: figcraft-cli` on stderr and exiting 127
  (what `st-figcraft.sh mcp` does with no CLI). Run
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
  change the `FR-001 agent frontmatter` check and plan S6 to match.
- **S2, plugin subagent calls a plugin MCP tool (no install needed).** In its own scratch folder
  `<s2>`, separate from S3's, make the same `stratum-spike` copy as S3 and point its entry at a
  scratch stdio MCP server instead of `fail.sh`, still through `${CLAUDE_PLUGIN_ROOT}`:
  `"args": ["${CLAUDE_PLUGIN_ROOT}/ping.py"]` with `"command": "python3"` (`ping.py`, about 30
  lines: `initialize`, `tools/list` with one `ping` tool, `tools/call` answering `pong`). Add a
  scratch agent
  `agents/spike.md` with `tools: Read, mcp__plugin_stratum-spike_figcraft__ping`, and run
  `claude --plugin-dir <s2>/stratum-spike -p "Start the stratum-spike:spike agent. It calls its ping tool and reports the reply." --allowedTools mcp__plugin_stratum-spike_figcraft__ping`.
  Record: the reply, the exact tool name from `claude --plugin-dir <s2>/stratum-spike mcp list`
  or the agent's tool list, and whether the run without `--allowedTools` asked for permission.
  Then the D22/D23 rule, which names tools one by one: give `ping.py` a second tool, `echo`, and
  give the scratch agent both tools. In a scratch project folder `<s2p>`, write
  `<s2p>/.claude/settings.json` as
  `{"permissions": {"allow": ["mcp__plugin_stratum-spike_figcraft__ping"]}}` (the exact name the
  first run recorded) and run the same prompt from `<s2p>` with no `--allowedTools`. Pass: the
  report holds `pong` and no permission was asked. Then ask the agent to call `echo` from `<s2p>`:
  pass if the call is not allowed (the `-p` run cannot answer a prompt, so the tool is denied).
  Fail of either: Build stops and asks the user, since the D23 rule's form must change (tasks
  T002).
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
  5. `run_command {command: "collab.host"}`: pass if refused with the `automation roots are set`
     error (sharing is off, FR-007, SC-005). Fail: Build stops and asks the user (tasks T004).
  6. End the Claude session that ran step 2: pass if the FigCraft window stays open.
  Fail of 3: Build stops and asks the user (tasks T004). Fail of 2 (taken): the lane runs Start
  before the session's first FigCraft call. When Start prints `FigCraft: started on port`, the user
  reconnects plugin:stratum:figcraft with /mcp (or restarts the session) once, then says go
  (contract section 2, Start). Fail of 6: `setsid` before `nohup` where present.
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
- N5 `plugin.json` without `mcpServers`: `C-FR-015 mcp entry` red.
- N6 `skills/st-design/SKILL.md` gets the word FigCraft: `C-FR-014 one place` red.
- N7 the agent `tools:` line gains `mcp__plugin_stratum_figcraft__pointer`: `FR-001 agent frontmatter` red.
- N8 `design-tool.md` names the engine by name: 009's `FR-010 one place` check red.
- N9 `skills/st-design/SKILL.md` section 1 step 1 loses `[screen: custom]`: `C-FR-002 SKILL.md` red.
- N10 the `design-tool.md` Tools line gains `mcp__plugin_stratum_figcraft__pointer`: `C-FR-015 tool list` red.

## 4. Live runs (by hand, lessons L32)

Each run starts the lane by typing the slash command (lessons L12) in a scratch project the user
picks, with its dev server started by the user. Record each in research.md R16.

- **L1 (US1, SC-001, SC-002, SC-003, SC-005).** A project with a design file, whose
  `.claude/settings.json` holds the D22/D23 allow rule: the 11 names of the `design-tool.md`
  Tools line (US4 is built later, so the user adds them by hand as contract 7d writes them): `/stratum:st-design a settings screen, custom design`. Answer the grill. FigCraft opens by
  itself. At the setup stop, reconnect plugin:stratum:figcraft with /mcp and say go. Record (T014,
  research R16) whether the `st-design` subagent started after the reconnect sees the FigCraft
  tools: the design appears. By hand: move one block, resize one, recolor one. Say "looks
  good". Pass: one design stop between the grill and the gate (the reconnect is a setup stop and
  does not count); no stop between "looks good" and the gate; the gate's screenshots show all three
  changes; the gate shows `DESIGN.md`; on yes the commit holds the screen, `DESIGN.md`,
  `.impeccable/design.json`, the token file and `design/settings.figcraft`; after the commit
  `git status` shows only `design/.read/` untracked; the run asked 0 permission prompts for
  FigCraft tools (record the count).
- **L2 (US2).** A project with a built screen: `/stratum:st make the dashboard better, custom design`.
  Pass: `Lane: Design`; FigCraft shows the current dashboard in the existing look; after one change
  and "good", the rebuilt screen has that change and the rest as before.
- **L3 (US3).** At an L1 gate: "more space between the cards" (no way named): the lane stops in
  FigCraft again. Then "fix the title text, in code": fixed in code, no FigCraft stop.
- **L4 (US4).** `/stratum:st-init` in a project without FigCraft on the PATH (run it with a PATH
  that hides it): the offer and the pacman line, and on yes `permissions.allow` in
  `.claude/settings.json` gains exactly the 11 names of the `design-tool.md` Tools line, with no
  `mcp__plugin_stratum_figcraft` server-wide entry and no `pointer`, `key` or `type_text`, and
  every other key kept (D22, D23). A custom task: stops with the install link before
  any question. A new-look task: goes on (SC-004). `/stratum:st-status`: the FigCraft lines under
  `FigCraft (optional, for the custom mode):`.
- **L5 (SC-006).** L1 again on the PC, after `git pull` and section 0 there.
- **Edge runs.** During L1's stop, close the FigCraft window, then say "good": the lane says the
  changes are lost, FigCraft opens on the last saved design, and the lane stops again. Record (T014,
  research R16, spike finding F3) whether that second Start asks for a /mcp reconnect again. Run a custom
  task while another program holds port 7979 (`python3 -m http.server 7979`): the port line.
