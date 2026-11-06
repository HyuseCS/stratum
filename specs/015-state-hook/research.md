# Research: State writes from the hook only

## R1. When does the reply text reach the transcript?

Question: when a PreToolUse hook fires, is the reply text before that tool call already in `transcript_path`?

Method: two headless runs on this machine (Claude Code 2.1.316, `claude -p --settings`) with a test hook on PreToolUse `Bash|Skill|Agent` and on Stop. The hook searched the transcript for an assistant `text` block with `Lane: full, risk high`.

| Run | Transcript | Event | Line in transcript? |
|-----|------------|-------|---------------------|
| 1: line, then Skill, Bash, Agent in one model message | `~/.claude/projects/-tmp-claude-1000--home-hyuse-Desktop-stratum-086-74296346-b3b5-4bf5-958d-b822ea3ce188-scratchpad-probe/2b24085f-d957-460a-9bc1-28234cf486f7.jsonl` | PreToolUse Skill (+24 ms), Bash (+390 ms), Agent (+930 ms) | no |
| | | Stop | yes |
| 2: line + Skill in one message, Bash + Agent in the next | `.../636a6ba5-afe6-406a-9fd9-97a6f33a88be.jsonl` | PreToolUse Skill | no |
| | | PreToolUse Bash (+1.25 s), Agent | yes |
| | | Stop | yes |

Findings:

- The transcript gets reply text late, up to about 1 second after the block. A hook on the tool call right after the `Lane:` line does not see it.
- Stop input has `transcript_path`, `cwd`, `session_id`, `prompt_id` and `last_assistant_message`. PreToolUse input has `transcript_path`, `cwd`, `session_id`, `prompt_id`, `tool_name`, `tool_input`.
- Transcript lines: `type` `assistant` with `message.content` blocks (`text`, `tool_use`, `thinking`); `type` `user` with `tool_result` blocks, `isMeta` injected text, or a real prompt (string content or `text` blocks, not `isMeta`).

Decision (orchestrator, O1): keep the `Lane:` line as the risk signal. Read it at PreToolUse `Skill|Agent`, PostToolUse `Agent` and Stop, current turn only. In the Fast lane, the PostToolUse of the `st-fast` planner agent fires before `st-advisor.sh change` (step 2), many seconds after the line.

Rejected (O2): `risk <level>` in the lane skill's args. No timing risk, but it changes the args of every lane skill and the Quick agent prompt.

Not checked: interactive mode. Both runs were headless.

## R2. Hook input inside a subagent, after an Agent call, and at Stop

Question: which transcript does a hook get when a subagent runs a tool, and what does PostToolUse `Agent` and Stop carry?

Method: one headless run (Claude Code 2.1.316, `claude -p --settings`, probe in the scratchpad `probe2/`) with a logging hook on PreToolUse and PostToolUse `Bash|Agent` and on Stop. The main session started one general-purpose subagent that ran `echo sub`.

| Event | `agent_id` | `transcript_path` |
|-------|------------|-------------------|
| PreToolUse Agent (main) | none | main session file |
| PreToolUse Bash (subagent) | set, with `agent_type` | main session file |
| PostToolUse Bash (subagent) | set | main session file |
| PostToolUse Agent (main) | none | main session file |
| Stop (main) | none | main session file |

- Decision: the hook reads markers only when the input has no `agent_id`. A subagent's own reply text is in `<session>/subagents/agent-*.jsonl`, never in the main file, so a subagent event has nothing new to add. The main session's next event reads it.
- Stop input also has `last_assistant_message`. In R1 run 2 it was the plain string `Done.` (the text of the last reply message, not an object). PostToolUse input has `tool_response` and `duration_ms`.
- Rationale: one rule ("main session only") with no lost signal, and no transcript read on the many subagent tool calls.
- Alternatives considered: read on subagent events too. Rejected: same file, more reads, no new text.

## R3. How much transcript one turn holds

Question: how far back must the hook read to find the last real user prompt?

Method: parsed the 300 largest main transcripts in `~/.claude/projects/*/*.jsonl` and measured, per file, the largest byte span between two real user prompts.

- Median of the per-file largest turn: about 0.8 MB. Largest seen: 8.3 MB.
- Decision: read the file backward in 64 KiB blocks and stop at the first real user prompt, or after 16 MiB (`# ponytail:` marker names the cap). Everything read before the stop is in the current turn, so the cap can drop an old part of a very long turn but can never let an earlier turn in.
- Rationale: the hook has a 10 s timeout and Stop runs every turn. A median turn costs one or two dozen block reads.
- Alternatives considered: read the whole file (48 MB transcripts exist); read a fixed tail (could cut a turn in half and still be fine, but gives no turn boundary on short turns without parsing anyway).

## R4. Transcript line kinds the reader must tell apart

Source: `636a6ba5-...jsonl` from R1 and the R3 scan.

| `type` | Counts as | Note |
|--------|-----------|------|
| `user`, `message.content` a string, no `isMeta` | real prompt (turn start) | typed text and `/command` prompts |
| `user`, content list with a block that is not `tool_result`, no `isMeta` | real prompt (turn start) | |
| `user`, all blocks `tool_result` | not a prompt, not reply text | |
| `user`, `isMeta: true` | not a prompt, not reply text | injected skill text |
| `assistant`, `text` blocks, `isSidechain` not true | reply text | the only source of markers |
| `api-request-blob`, `attachment`, `system`, other | ignored | `api-request-blob` holds copies of earlier messages, old `Lane:` lines too |

- Decision: filter on `type` first, then parse blocks.

## R5. How the marker lines look in real replies

Method: grep of assistant `text` blocks in `~/.claude/projects/*/*.jsonl` for `Lane:` and for `Phase: done`.

- 25 `Lane:` samples. The lane word is often capitalized (`Lane: Full`, `Lane: Fast`). In 5 of 25 the reply label sits on the same line in front: `[Orchestrator] Lane: Quick (...)`. The rest start a line (often after `[Orchestrator]\n\n`).
- `Phase: done` shows up over 400 times as `- Phase: done | Lane: full` inside handoff and status text.
- Decision: the lane word is any letters and the risk level matches without case (`risk High` is `high`). `Phase: done` and `Build done.` must be the whole line (trailing spaces only), so `- Phase: done | Lane: full` never counts. D1 (orchestrator, resolved: A, extended): a marker also counts with an optional `[label] ` and then an optional `- ` bullet in front on the same line, with backticks or `**` around it, and with a final `.` on `Phase: done` / `Build done`. Each allowed form has its own positive test row. A marker that is not the whole line after the prefix stays excluded. The exact patterns are in data-model.md "Marker lines".
- Last line wins: the reader collects all `Lane:` matches of the turn in order, plus `last_assistant_message` at Stop, and uses the last one.

## R6. Fate of `tests/test_state.sh`

- Decision: keep the file as a phrase table only. Drop lines 1-37 (the `st-state.sh` unit tests) and keep the S-rows, one row per FR-009 line (S1-S6), plus S7 (the script is gone) and S8 (no file under `skills/`, `procedures/`, `agents/`, `hooks/` or `scripts/` names `st-state.sh`).
- Rationale: no other test checks the st-build, st-worker or specify.md lines, and the README test list stays right with no edit.
- Alternatives considered: move the rows into `tests/test_inspect.sh` and delete the file. Rejected: needs a README edit and mixes unrelated rows into the Inspect table.

## R7. Where the risk goes

- Decision: the risk path is `dirname(git -C <cwd> rev-parse --path-format=absolute --git-common-dir)/.stratum/state.json`, the same file `scripts/st-advisor.sh:124` reads. `git` runs with a list of arguments (no shell) and a 3 s timeout. If `git` fails (no repo), the hook uses the state file it found from `cwd`. If that path is the same file as the cwd-walked one, the hook changes one copy of the data and writes once.
- Rationale: parity with the deleted skill line and the advisor reader.
- `git` runs only when a risk value is found, so a turn with no `Lane:` line and no `risk` prompt costs no `git` call.

## R8. Timing check against FR-003 (Fast lane)

- `/stratum:st` says the `Lane:` line, then starts `st-fast` (PreToolUse Skill: the line may not be in the file yet, R1), then the `st-fast` planner agent (PreToolUse Agent, then PostToolUse Agent many seconds later), then `st-advisor.sh change`. PostToolUse Agent is the latest safe read and it comes before the advisor. Stop is the fallback for the Quick lane and for lanes that ask the user first.

## R9. Writes happen only on change

- Decision: each of the four writes compares first and writes only when the value differs. Stop runs every turn, and a rewrite of an unchanged `state.json` would show as a git change and bump the file time for nothing.

## R10. Turn boundary by promptId

Question: what happens when the current turn's prompt line is not in the transcript yet?

Method: live headless probe (Claude Code 2.1.316, session `e519b62f-10e2-4e50-9b37-3b52a1c5cd3e`).

- Every hook input has `prompt_id`. Every transcript `user` line (prompts and `tool_result` lines) has `promptId` with the same value for the same turn. Assistant lines have no `promptId`.
- Without a guard, a lagging prompt line lets the backward read run into the previous turn and apply its markers again.
- Decision: the reader also stops at a `user` line whose `promptId` differs from the input's `prompt_id`, when both are present. With either one missing, the real-prompt rule (R4) alone sets the boundary.
