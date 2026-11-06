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
