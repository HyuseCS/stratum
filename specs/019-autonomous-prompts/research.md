# Research: issue #93 worker prompts (PermissionRequest after a hook ask, Codex rollout files)
Written by: st-research

## Round 1

### Scope

GitHub issue #93 (autonomous mode: the orchestrator sees and answers every worker prompt). Two facts before design, facts only.
Q1. Does the PermissionRequest hook (`hooks/st-approve.py`, wired at `hooks/commands.json:44-47`) still fire for a tool call when a PreToolUse hook (`hooks/st-git-guard.py`) returned `permissionDecision: "ask"`?
Q2. Where does the Codex CLI store its session log (rollout) file, how to find the file of a running session or tab, its format, and which record holds the final assistant message text exactly as sent.

Installed versions (2026-11-09): `claude --version` = `2.1.319 (Claude Code)`, `codex --version` = `codex-cli 0.167.0`.

### Key facts

#### Q1. Does PermissionRequest fire after a PreToolUse `ask`?

Repo side:
- F1. `hooks/st-git-guard.py:164-172` returns `ask` for `git commit` unless the commit mode is `auto` with no `--amend` and no other folder (mode `deny` returns `deny`). `:179` returns `ask` for every plain `git push`. `:344-349` prints `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":<decision>,...}}`.
- F2. `hooks/commands.json:44-47` registers `st-approve.py` for `PermissionRequest` with no matcher and `timeout: 310`. `hooks/st-approve.py:14` is the allow output, `:335` the `PermissionRequest` branch.
- F3. Workers start in two ways. Interactive: `scripts/st-worker.sh:338` runs `herdr agent start ... --kind claude ... -- --permission-mode auto`. Headless: `scripts/st-worker.sh:767-769` runs `claude -p ... --permission-mode dontAsk --permission-prompts none`.

Official docs (https://code.claude.com/docs/en/hooks.md, read 2026-11-09):
- F4. PreToolUse `permissionDecision`: "`"ask"` prompts the user to confirm." `permissionDecisionReason`: "For `"ask"`, shown to the user in the permission prompt."
- F5. Auto mode: "In auto mode, a PreToolUse hook's `"ask"` normally sends the tool call to the permission prompt, and the classifier doesn't decide it. Some calls take a different path" (exceptions: calls Claude Code's own checks also flag, and `SubagentHandback` calls).
- F6. PermissionRequest: "Runs when Claude Code is about to ask you for permission to use a tool. In sessions that can't show a prompt, such as background subagents in non-interactive mode, Claude Code still runs these hooks, and if no hook returns a decision, it denies the tool call." And: "PermissionRequest hooks run only when Claude Code is about to ask you for permission, or when it would otherwise auto-deny a call that can't prompt."
- F7. The docs do not name the PreToolUse `ask` case in the PermissionRequest section. F4 + F6 together say: a hook `ask` shows a prompt, and a prompt runs PermissionRequest.

Live probe in this repo (earlier version):
- F8. `specs/010-workflow-overhaul/research.md:3` records `claude --version` = `2.1.312` on 2026-10-31. `:22-35` record a live probe in an interactive herdr worker with `--permission-mode auto`: a PreToolUse Bash hook answered `ask`, the PermissionRequest hook fired, waited 75 s while the dialog was on screen, printed `allow`, and the dialog closed and the command ran.
- F9. `specs/010-workflow-overhaul/research.md:21-22` cites the binary string `PermissionRequest hook failed before a hook's ask for` as proof. In the 2.1.319 binary that string sits in function `ieo`, which returns early unless the ask has `hooksMayRefuse === true`. That flag is set by `G8`, which is applied only when a `tool.check` plugin (a different extension point, "plugins can only tighten ... permission") returns `ask`. So the string is not proof for the PreToolUse case. The live probe (F8) is.

Installed binary 2.1.319 (`strings /opt/claude-code/bin/claude`, minified code, read 2026-11-09; reading minified code is inference):
- F10. PreToolUse `ask` path: function `Nds` calls `Sx(..., {hookAsked: true})`. If the pipeline also asks, it logs "Hook returned 'ask' for <tool>, but an ask rule, a safety check, a ToolHost's person-only ask or plan mode requires the full permission pipeline (hookAskFloor ...)" and calls `canUseTool` with `hookAskFloor: true`. Otherwise `Nds` ends with `return TNe(ke, {...})` for the hook's ask. `TNe` runs `ieo`, then `mSi`, and for a result that is still `ask` returns `canUseTool(..., y)`, the interactive dialog path.
- F11. In the dialog path, `uKt` runs only `if (e.personOnly !== true)`. `uKt` calls `q3e`, which logs `executePermissionRequestHooks called for tool` and builds `hook_event_name: "PermissionRequest"`. So the PermissionRequest hook is skipped when the ask is marked `personOnly`.
- F12. Sources seen that set `personOnly: true`: safety checks, plan mode ("Enter plan mode?"), auto-mode classifier fallbacks (`tengu_auto_mode_fallback_to_ask`, with `hooksMayAllow: false`), the "arbiter" path, the chrome block prompt, `tool.check` plugin asks (`G8`), and some access-change and question prompts. Whether a plain PreToolUse `ask` is ever marked `personOnly` cannot be read from the strings. The hookAskFloor flag (`ZZr(H.hookAskFloor===!0, Ae)`) changes how an auto-mode classifier allow is handled: it re-surfaces as the ask.
- F13. `seo` (another PermissionRequest caller) returns null for `personOnly` asks only when the ask carries an MCP skill or a session match (`s.personOnly===!0&&(s.metadata?.mcpSkill!==void 0||PAe(...))`).

Changelog (https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md, read 2026-11-09, first 100 000 chars, newest heading 2.1.319, headings 2.1.312 to 2.1.319 covered except 2.1.313 and 2.1.315, which do not appear):
- F14. No line in 2.1.312 to 2.1.319 says PermissionRequest stops firing after a PreToolUse `ask`.
- F15. 2.1.319 adds `permissions.denyInsteadOfPrompting`: a tool call that would wait for approval is denied and the turn continues (terminal sessions, subagents, teammates). No match for `denyInsteadOfPrompting` in this repo or in `~/.claude/settings.json`.
- F16. 2.1.314: "a hook's allow of an MCP tool call now counts as no answer, so the classifier or a permission prompt decides". 2.1.319: "under an ask rule an allow on Monitor, bypass mode or auto mode no longer skips the prompt".

Issues (GitHub, read 2026-11-09):
- F17. #88698 (https://github.com/anthropics/claude-code/issues/88698), open, reported on 2.1.238, +1 on 2.1.296. Table: `claude -p` with a PreToolUse `ask`: PermissionRequest "never fires", call auto-denied. `claude --bg` with a PreToolUse `ask`: PermissionRequest "fires", its decision is ignored, session stays blocked. The table has no interactive row. The `-p` case is tracked as #88328.
- F18. #15773 (https://github.com/anthropics/claude-code/issues/15773), closed 2025-12-30, version 2.0.76: "PermissionRequest fires 30ms after PreToolUse" when PreToolUse returns `ask`, before the user answers, and receives the original input, not PreToolUse's `updatedInput`.
- F19. Other reports from search results only, threads not opened (https://claudeissues.com, read 2026-11-09): #79177 (a subagent's prompt did not invoke PermissionRequest while PreToolUse fired), #82418 (PermissionRequest never dispatched for agent-team teammates), #79356 (2.1.234, auto mode: a PreToolUse `ask` ran with no prompt), #79449 (same, top-level session with `CLAUDE_CODE_CHILD_SESSION=1`), #36286 and #13339 (VS Code extension ignores hook decisions).

Summary of what is known: for an interactive top-level worker in auto mode, the PermissionRequest hook fired after a PreToolUse `ask` on 2.1.312 (F8), and the 2.1.319 code still runs PermissionRequest in the dialog path unless the ask is `personOnly` (F11). For `claude -p`, an open report says it never fires (F17). No live check on 2.1.319.

#### Q2. Codex CLI rollout file: path, how to find a tab's file, format, final answer record

Location:
- F20. Files are `~/.codex/sessions/YYYY/MM/DD/rollout-<local-time>-<thread-id>.jsonl`. Example: `~/.codex/sessions/2026/11/09/rollout-2026-11-09T17-44-45-01a1bfb2-2371-7600-ab28-d10792ea77cd.jsonl`. 47 files, from 2026-10-19 to 2026-11-09, versions 0.162.1 and 0.167.0. Third-party docs say the root is `$CODEX_HOME/sessions`, default `~/.codex` (https://pkg.go.dev/github.com/MoonCaves/rawclaw@v0.6.1/internal/source/codex via search, read 2026-11-09). No official OpenAI page was found that states the path.
- F21. `~/.codex/state_5.sqlite` table `threads` has `id, rollout_path, created_at, updated_at, source, cwd, title, ...`. The newest row maps thread `01a1bfb2-...` to the file in F20, cwd `/home/hyuse/Desktop/stratum`.
- F22. `~/.codex/session_index.jsonl` lines hold `{"id","thread_name","updated_at"}`.
- F23. `~/.codex/thread-writer-locks/<thread-id>.lock` exists for the thread being written. Only `01a1bfb2-...lock` was present, the thread of the open tab `st-codex-stratum`.

Finding a running tab's file:
- F24. The Codex TUI process (`codex --no-alt-screen -m ...`, pid 428943) holds no rollout file open. The shared app-server daemon (`codex app-server --listen unix:// ... --managed-daemon`, pid 429000) holds the rollout file and the thread lock open. One daemon serves every Codex tab, so `/proc/<tui-pid>/fd` does not name the file.
- F25. `herdr agent get st-codex-stratum` and `herdr agent list` give no `agent_session` field for the codex agent (Claude agents have one with the session id). herdr gives no Codex thread id.
- F26. The TUI process environment has `HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID` (values not copied). The rollout's `session_meta` has `cwd`, not the herdr ids.
- F27. Keys that exist to match a tab to its file: thread lock name (F23), `threads.cwd` and `created_at`/`updated_at` (F21), `session_meta.cwd` and `timestamp`, and the rollout content itself: the user message text (here it names the `prompt.tab` path) and the final answer text (here it holds `ST-ADVISOR-BEGIN-<nonce>`).

Format (observed on all 47 files):
- F28. One JSON object per line with keys `ordinal, payload, timestamp, type`.
- F29. `type` values in the 0.167.0 file: `session_meta` (first line, payload has `id, timestamp, cwd, originator: "codex-tui", cli_version, source: "vscode", git, base_instructions, ...`), `turn_context`, `world_state`, `token_usage_record`, `response_item` (payload types `message`, `reasoning`, `custom_tool_call`, `custom_tool_call_output`, `additional_tools`), and `event_msg` (payload types `task_started`, `thread_settings_applied`, `item_completed`, `token_count`, `task_complete`).
- F30. The final answer is in three records:
  - `response_item` with `payload.type == "message"`, `role == "assistant"`, `phase == "final_answer"`, text in `payload.content[].text` where `content[].type == "output_text"`.
  - `event_msg` with `payload.type == "item_completed"`, `payload.item.type == "AgentMessage"`, `payload.item.phase == "final_answer"`, text in `payload.item.content[].text`.
  - `event_msg` with `payload.type == "task_complete"`, text in `payload.last_agent_message`, with `turn_id`, `completed_at`, `duration_ms`.
  Commentary messages carry `phase == "commentary"`.
- F31. In all 47 files the last `final_answer` message text equals the last `task_complete.last_agent_message` exactly.
- F32. A file holds every turn of its thread. Files had 1 to 9 `final_answer` records. Each record has a `turn_id`, so the last one in the file is the answer of the last turn only.
- F33. The text keeps its newlines as sent. The pane scrape at `scripts/st-codex-agent.sh:128-138` reads 400 pane lines, strips `• `, and joins the lines between the markers with spaces.
- F33a. Live compare for nonce `675bdd6a2aa3` (tab `st-codex-stratum`, `herdr agent read ... --source recent-unwrapped --lines 400`, same strip and join as `scripts/st-codex-agent.sh:131-138`): the pane text between the markers is 880 chars on 6 pane lines, the rollout text is 886 chars on one line. Both parse as JSON. They differ: the pane drops every backtick that the rollout text holds (for example `` `git status --porcelain | cut -c4-` `` in the rollout is `git status --porcelain | cut -c4-` in the pane). The parsed objects are not equal.
- F34. `~/.codex/thread_history_1.sqlite` holds the same data: `thread_turns(thread_id, turn_id, status, final_agent_item_id, rollout_byte_offset, rollout_end_byte_offset, ...)` and `thread_items(item_json)`. For thread `01a1bfb2-...` the turn row has `status = completed` and `final_agent_item_id` = the `final_answer` message id, and that item's JSON has `text` and `phase: "final_answer"`.
- F35. `codex --help` (0.167.0) lists `migrate-rollouts`: "Inspect or migrate legacy local sessions to paginated thread history".
- F36. The headless path `scripts/st-advisor.sh:265` runs `codex exec ... --ephemeral --output-schema ... -o "$tmp/answer.json"`. `codex exec --help`: `--ephemeral` "Run without persisting session files to disk", `--json` "Print events to stdout as JSONL", `-o, --output-last-message <FILE>`. `scripts/st-advisor.sh:286-292` reads `answer.json`, not the pane.
- F37. A third-party reader notes the writer is append-only and runs in the background, so a crash can leave a partial last line (https://docs.rs/toolpath-codex/0.2.0/src/toolpath_codex/reader.rs.html via search, read 2026-11-09, page not opened).

### Open questions

- [planner] Q1 on 2.1.319 was not checked live. The brief allowed no probe. The last live proof is 2.1.312 (F8).
- [planner] Whether a plain PreToolUse `ask` is ever marked `personOnly` (which skips PermissionRequest, F11) is not readable from the minified binary.
- [planner] For `claude -p` workers (`scripts/st-worker.sh:767-769`), the open issue #88698 says PermissionRequest never fires after a PreToolUse `ask`. Not checked here.
- [planner] When the `task_complete` line is flushed to the rollout file, relative to the moment herdr reports the Codex tab idle, was not measured.
- [planner] Which key matches a herdr Codex tab to its thread (F23, F27) when more than one Codex tab runs in the same folder was not tested. Only one Codex thread was open.
- [planner] Reading the rollout (F30) in place of the pane scrape (F33) is a design choice and is left open.
- [planner] No official OpenAI page for the rollout path and format was found. The facts come from local files and third-party pages.

### Commands

Scratch file outside the project: the `strings` dump of the Claude binary was written to `/tmp/claude-1000/-home-hyuse-Desktop-stratum/2b6b06ef-f02b-4968-9c49-ba37f772fafe/scratchpad/sX.W0ob/str.txt` (session scratchpad).


- `cat sr-opus-5.md; cat procedures/research.md; claude --version; codex --version`
- `sed -n 155,180p hooks/st-git-guard.py; sed -n 335,355p hooks/st-git-guard.py; sed -n 30,60p hooks/commands.json; sed -n 120,145p scripts/st-codex-agent.sh; sed -n 280,300p scripts/st-advisor.sh`
- `ls -la ~/.codex; ls ~/.codex/sessions; find ~/.codex/sessions -name '*.jsonl'`
- `grep -n "herdr\|codex exec\|output-last-message\|-o \|rollout\|\.codex" scripts/st-advisor.sh; grep -n "herdr\|codex " scripts/st-codex-agent.sh`
- `python3 -I` read-only scripts over `~/.codex/sessions/**/rollout-*.jsonl` (record type counts, per-record structure with text cut to 60 chars, final_answer vs task_complete compare)
- `head -c 300 ~/.codex/session_index.jsonl; cat ~/.codex/version.json; ls ~/.codex/thread-writer-locks ~/.codex/tui-thread-reference-capabilities ~/.codex/app-server-control`
- `herdr agent --help; herdr agent list; herdr agent get st-codex-stratum; herdr agent explain st-codex-stratum; pgrep -af codex`
- `ls -l /proc/428943/fd /proc/429000/fd | grep ...; tr '\0' '\n' < /proc/428943/environ | grep -E '^(CODEX|HERDR)' | sed 's/=.*/=<set>/'`
- `python3 -I` read-only (`mode=ro`) reads of `~/.codex/state_5.sqlite` (schema, `threads` rows) and `~/.codex/thread_history_1.sqlite` (schema, `thread_turns`, `thread_items` for one thread)
- `codex --help | grep ...; codex exec --help | grep ...`
- `sed -n 1,40p hooks/st-approve.py; grep -rn PermissionRequest --include=... .; git log --oneline -S"PermissionRequest"`
- `sed -n 8,45p specs/010-workflow-overhaul/research.md; sed -n 236,244p specs/010-workflow-overhaul/plan.md`
- `readlink -f "$(command -v claude)"; file /usr/bin/claude; ls /opt/claude-code/bin`
- `strings -n 8 /opt/claude-code/bin/claude > <scratchpad>/sX.W0ob/str.txt` and `grep -E -o` on it for `hook failed before a hook`, `PermissionRequest hook`, `hooksMayAllow`, `personOnly`, `hookAskFloor`, `Hook returned`, `TNe`, `uKt`, `q3e`, `seo`, `G8`, `OZo`
- `grep -n "agent start\|permission-mode\|--bg\| -p " scripts/st-worker.sh`
- `grep -rn denyInsteadOfPrompting . ~/.claude/settings.json; realpath -m .stratum/research/issue-93-prompts.md; mkdir -p .stratum/research`
- `grep -n 'return "ask", "git push' hooks/st-git-guard.py; grep -n 'git commit (commit' hooks/st-git-guard.py` (cite check)
- `sed -i` on this research file to fix the F1 line cites
- `python3 -I` over `<scratchpad>/sX.W0ob/str.txt` to print the text after `Hook satisfied user interaction for`
- `herdr agent read st-codex-stratum --source recent-unwrapped --lines 400 | python3 -I ...` (pane vs rollout compare for nonce `675bdd6a2aa3`, read-only)
- WebFetch https://code.claude.com/docs/en/hooks (offset 0) and https://code.claude.com/docs/en/hooks.md (offset 100000)
- WebFetch https://github.com/anthropics/claude-code/issues/88698 and https://github.com/anthropics/claude-code/issues/15773
- WebFetch https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md (three prompts, first 100 000 chars)
- WebFetch https://developers.openai.com/codex/cli/features (308 redirect, not followed)
- WebSearch x5 (PreToolUse ask and PermissionRequest issues, changelog, Codex rollout format, Codex session path, Codex rollout source)

## Decisions

Added by st-plan on 2026-11-09. Facts in this section that are not in Round 1 have their source on the line.

### P1. Where the dialog block starts and ends (FR-001, FR-002, US1)

- Fact (live probe, 2026-11-09, `claude` 2.1.319, `--permission-mode default --model haiku`, in a temporary herdr tab, read with `herdr agent read --source recent-unwrapped --lines 40` and the ANSI strip of `scripts/st-worker.sh:170`): a Bash permission dialog is drawn as below. Line kinds were checked by code point.
  ```text
  ❯ Run this exact Bash command and nothing else: touch …/p.txt          (transcript)
    ⎿  $ touch …/p.txt                                                    (transcript)
                                                                          (blank)
  ─────────────────────────────────── (161 x U+2500, nothing else)      top rule
   Bash command                                                           title
   Tip: auto mode handles these prompts for you — choose "switch to auto mode" below
   Create empty file p.txt at the given scratchpad path                   description
  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ (161 x U+254C)
   │ touch …/p.txt                                                        command, prefixed "│ "
  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ (161 x U+254C)
   Do you want to proceed?                                                HEAD
   ❯ 1. Yes
     2. Yes, and always allow access to …/probe from this project
     3. Yes, and switch to auto mode · auto mode handles these prompts for you
     4. No
                                                                          (blank)
   Esc to cancel · Tab to amend
  ```
- Fact (`strings /opt/claude-code/bin/claude`, 2.1.319): dialog titles are built at run time (`"Bash command"`, `` `Bash command (${cr})` ``, `"Run command"`, `` `${...?"Read":"Edit"} file` ``, `"Edit file"`, `"Edit notebook"`, `"Tool use"` and more). A list of titles would go stale.
- Decision: the block starts at the nearest line above the HEAD line that starts at column 0 and holds only U+2500 characters (with optional trailing spaces): the dialog's top rule. It ends at the last option line after HEAD, plus the lines right after it up to the first blank line. The HEAD and option rules of `answer` stay as they are (last 15 lines, exactly one HEAD).
- Rationale: the rule line is the one line that marks the top of every dialog and is not text that the tool call controls. Command lines carry the `│ ` prefix, so a command cannot draw a line of only `─`. The title and description lines start with a space, so a description of only `─` does not start at column 0 and is not taken as the rule. The title, the description and the command are inside the block, so a changed command changes the hash (US1 scenario 2). No rule line in the 40-line read means the top of the dialog is cut off: per D15 the whole-screen hash of today is kept, and `answer` may send only an allowed No (the cut-off No flow of 837282c), never a yes (scenario 3).
- Fails closed: if a later Claude Code drops the rule line, every dialog falls to the cut-off mode: a yes goes to the user, a No still works with the whole-screen hash. The quickstart live check (step L2) shows it.
- Alternatives considered: a list of title words (stale, see the fact above); a fixed number of lines above HEAD (cuts a long command or takes in transcript lines that change).
- Probe side effects: one temporary herdr tab (`w4B:t5`, closed), one Haiku turn, the dialog cancelled with Esc, no file made. Claude Code saved the folder trust for the scratchpad folder `…/scratchpad/plan019/probe`.

### P2. The approve hook already accepts Claude's standard heredoc commit (US2)

- Fact (run on this checkout, `python3 -I` with `hooks/st-approve.py` loaded): for `git commit -m "$(cat <<'EOF'\nfeat: x\n\nbody line\nEOF\n)"`, `HEREDOC_MESSAGE.sub("", …)` gives `git commit -m ""` (`hooks/st-approve.py:40`), so `SUBSTITUTION` (`:41`) does not match at `:195`, and `split_commands` gives `heredoc=False` (the `<<` is inside the quoted word). `commit_check` sends this commit. `tests/test_approve_hook.py:87` (`OWN_COMMITS`) and `:424-433` assert it.
- So D4's cause is true only for the other heredoc forms (`-F - <<'EOF'`, an unquoted `<<EOF` inside `$(...)`, a body with a `$(`) and for every `$(` or backtick message. Which form kept the 2026-11-08 dialogs in the pane is not recorded. The guard deny of D4 and D6 covers all of them, so the fix does not depend on it.
- Consequence: with the guard deny, the `HEREDOC_MESSAGE` path in the approve hook is never reached in a Stratum session (the guard denies first, at PreToolUse). User decision D13 (`decisions.md`): delete `HEREDOC_MESSAGE`; both hooks call one shared check.

### P3. How the guard finds a commit (FR-004, US2)

- Decision: the guard denies when (a) at least one part of the command is a `git commit` and (b) the shared text test matches the whole command. (a) is true when `parse_git` returns `commit` for a segment, on the normal path or on the line-by-line fallback path. It is also true when the fallback path cannot parse a line (`"The git guard could not parse the command."`, `hooks/st-git-guard.py:339`) or cannot read a git command on it (`:343`) and that line holds the word `commit`.
- Fact (run on this checkout, 2026-11-09): `git commit -m "$(cat <<'EOF'\nfeat: say "hi\nEOF\n)"` (one `"` in the body) gives `ask` with `The git guard could not parse the command.` only: no part is read as a commit. With `it's` in the body the guard still reads line 1 as a commit (`ask`, `git commit (commit: ask)`), because the apostrophe sits inside double quotes.
- Rationale: without the second half of (a), a heredoc message with an odd `"` would get `ask`, not `deny`. A command with no `git commit` part (`cat > a.txt <<'EOF'`, `python3 - <<'PY'`, `echo "git commit <<EOF"`) is not denied (US2 scenario 6).
- Known over-match, accepted: an unquoted heredoc body line that reads `git commit …`, or an unreadable line with the word `commit`, in a command that also has `<<`, is denied. Agents write files with Write or Edit (session rule), so this is rare, and the deny reason says what to do.
- The deny reason is exactly the text in `contracts/commit-form.md`, alone (no staged list), so a test can compare it in full (CHK009).

### P4. Codex session log reader (FR-011 to FR-013, US4)

- Fact (`~/.codex/sessions`, 47 files, read-only): `event_msg` payload types seen are `item_completed`, `token_count`, `task_started`, `task_complete`, `thread_settings_applied` and `turn_aborted` (6 times). A `turn_aborted` payload has `turn_id`, `reason: "interrupted"`, `started_at`, `completed_at`, `duration_ms`.
- Fact: the review prompt that `scripts/st-codex-agent.sh:118` sends is stored word for word as a `response_item` user `message` (`content[].text`): `Read the review request in /tmp/tmp.zzKiqUtYtC/prompt.tab and follow it. Change no file.` (file `rollout-2026-11-06T06-38-45-01a1addd-…jsonl`). The prompt file path is in a fresh `mktemp -d` folder per review, so this line is unique per review.
- Decision: root `${CODEX_HOME:-$HOME/.codex}/sessions`. Read only files named `rollout-*.jsonl` whose mtime is not older than the prompt file (the prompt file gets its last write just before the prompt, `scripts/st-codex-agent.sh:115-117`). Skip a line that is not JSON (a partial last line, Round 1 F37). The answer is the text of a `task_complete.last_agent_message` that has the line `ST-ADVISOR-END-<nonce>` and, before it, the line `ST-ADVISOR-BEGIN-<nonce>`: the lines between the last such pair, joined with `\n`, written to the answer file byte for byte. The screen is not read.
- Poll: up to 15 tries, one `sleep 1` between tries (a count of tries, not `SECONDS`, so the test's no-op `sleep` keeps the test fast). Then exit 6, and `scripts/st-advisor.sh` prints `codex: headless (no session log)` and goes to its existing headless path, with its existing 60 s floor (`:264`).
- Rationale for a fixed 15 s and not the remaining budget: a review in the tab has no time limit (`README.md:268`), so the tab path has no budget of its own to pass down. When the tab review used up the 540 s, the 60 s floor makes the point `BLOCKED (timed out)` as the spec edge case says. The quickstart live check measures the real lag (step L3).
- The reader never writes, moves or locks a log file (CHK013). It opens each file read-only.
- Esc in the tab (a `turn_aborted` after this review's prompt line): user decision D14. The point ends `BLOCKED: the review was stopped in the Codex tab`, with no headless run.

### P5. Built-in git instructions setting (FR-008, FR-009, US3)

- Fact (`strings /opt/claude-code/bin/claude`, 2.1.319): the settings key is `includeGitInstructions` ("Include built-in commit and PR workflow instructions in Claude's system prompt (default: true)"). The reader is `function Odt(){let e=i.CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS;if(e!==void 0)return!e;return yt().includeGitInstructions??!0}`: the env var `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` wins over every settings file when it is set.
- Fact: on this machine none of `~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json` sets the key (jq, 2026-11-09).
- Decision: "set at any level" (FR-009, CHK016) means the env var is set, or one of `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`, `<checkout>/.claude/settings.json`, `<checkout>/.claude/settings.local.json` has the key `includeGitInstructions` (any value: the user already chose). The write merges the one key with jq and keeps every other key (CHK015).

### P6. Worker brief rule 5 (FR-010)

- Decision: brief rule 5 (`scripts/st-worker.sh:253`) changes `-m "<subject>" -m "<body>"` to `-m '<subject>' -m '<body>'`. The brief tells the worker to give this rule word for word to `st-git`, and `agents/st-git.md` will say single quotes. `tests/test_st_worker.sh:237` holds the rule word for word and changes with it.
- Alternative considered: leave rule 5. Rejected: two "word for word" forms that differ.

### P7. `agents/st-git.md` retry rule

- Fact: `agents/st-git.md:49-50` says "A commit hook fails or the commit guard denies: stop and report its exact text. Do not retry around it." US2 needs the agent to run the commit once more with `-m` after the form deny.
- Decision: one exception line: on the deny whose reason starts with `Commit form denied:`, write the same message with `-m 'subject' -m 'body'` and run it once more. Any other deny: stop and report, as today.
