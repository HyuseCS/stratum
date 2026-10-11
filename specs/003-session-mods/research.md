# Research: Mods That Talk To and Start Other Sessions

Two parts. Phase 0 notes (written by the plan) say what the docs and the CLI already show and what
the tests must still prove. The `## Spike report` (D7) is filled by the build. Its line format is
in [data-model.md](data-model.md), and `spikes/check.sh` stays red until it is complete.

Sources read for Phase 0, all for Claude Code 2.1.296:

- `plugin-authoring/reference.md` (the skill's long form, copied to the session scratchpad).
- `plugin-authoring/types/claude-code.d.ts` (the engine's own declaration, 21,461 lines). Line
  numbers below are in that file.
- `plugin-authoring/examples/pane.tsx`, `pane-state.d.ts`.
- `git show st-tree:mods/st-tree/hooks/register.tsx` (an existing pane mod).
- `claude --help`, `claude agents --help`, `claude plugin test --help`, `claude agents --json`.

The scratchpad copy is not in the repo. Report evidence cites the d.ts by line and, where a test
needs it, the command that shows the same fact on this machine. After test 1 or 2 loads a mod, the
same declaration of the same build is at
`specs/003-session-mods/spikes/<mod>/.claude-plugin/types/claude-code/index.d.ts` (ignored by git),
where the cited lines can be checked.

## Phase 0 notes

### R1. A mod can send a message to another session

- Decision: test 1 approach A1 uses `$.session.send({ to, text })`.
- Rationale: d.ts 2883-2897 documents `$.session.send`: "Sends a plain-text message to another
  agent or session ... the model's SendMessage tool's own call and delivery". `to` is a name, an
  agent id, a received `from` address, or `{ sessionId }` (`SessionSendAddress`, 11521-11540). It
  resolves `{ isDelivered, reason }` once queued, not once read (`SessionSendResult`, 11629-11649).
  A session that is not running "is not delivered to: the result says so" (11526).
- Alternatives: `$.tool.call({ tool: 'SendMessage' })` (3030, and 11607 says a plugin's
  `$.tool.call` of SendMessage is a plugin send). Kept as A2. The model's own SendMessage is A3,
  the partial pass of D9.

### R2. A mod can see the reply

- Decision: hook `session.receive` and keep deliveries whose `e.origin.kind` is `peer` or
  `peer-send-message`.
- Rationale: `session.receive` "fires when a delivery reaches the session (... a peer's message
  ...) before it is queued" (4344-4354). `SessionReceiveOrigin` (11385-11445) has `peer`
  ("another session's or agent's model") and `peer-send-message`. `PromptOrigin` (8909-8917)
  describes both. Which of the two a SendMessage reply arrives as is not stated, so the mod keeps
  both and the test records which one came.
- Alternatives: read the transcript with `$.session.messages()`. Rejected: a hook is the event
  itself, and the docs name it.

### R3. A mod can list sessions only through a tool call

- Decision: Q1 evidence for listing is `$.tool.call({ tool: 'ListAgents' })` (3030) and the
  ListAgents input (16337-16342) and output (20661). `$.agent.list()` (3186-3194) lists only this
  session's subagents and teammates.
- Rationale: no `$` noun lists other sessions. The CLI does: `claude agents --json` prints active
  sessions, interactive and background, with `pid`, `cwd`, `kind`, `sessionId`, `name`, `status`
  (run on this machine, 2026-10-11).
- Alternatives: none in the API.

### R4. A mod can start a session only as a host process

- Decision: test 2 uses `$.process.spawn` (B1, B3) and `$.process.run` with `claude --bg` (B2).
- Rationale: `$.process.run` runs argv with no shell, 30 s default and 10 min maximum timeout,
  `{ cwd, env, stdin, timeoutMs }` (3506-3522, `ProcessRunInit` 8007-8026). `$.process.spawn`
  streams `{ stream, text }` then `{ code, signal }`, and "leaving [the loop], `return()` on the
  stream, `next.signal` aborting or the module unloading kills the child" (3523-3560,
  8073-8135). So a mod-started `-p` child cannot outlive its module. `$.agent.spawn` (3175-3185)
  starts a subagent of this session, not a session: not an approach for tests 2 and 3.
- Alternatives: none. No `$` noun starts a session.

### R5. CLI features for starting and stopping sessions

- Decision: `claude -p` (C1, B1), `claude --bg` (C2, B2), `claude -w` (B3, C3).
- Rationale: `claude --help` on 2.1.296 shows `--bg`: "Start the session in the background and
  return immediately. Prints the id that `claude attach`, `logs`, `stop` and `rm` take; `claude
  agents` lists them". `claude rm`: "Delete a background session, and its worktree when that is
  safe". `--max-turns` is not in the help, but `claude --max-turns abc ...` answers "option
  '--max-turns <turns>' argument 'abc' is invalid. must be a number", so the flag exists.
  `-n, --name`, `--tools ""`, `--strict-mcp-config`, `--no-session-persistence` and
  `--output-format json` are listed.
- Not yet known (the tests record them): whether `-n` and `--max-turns` apply with `--bg`; the
  JSON field names of `--output-format json`; whether a `-p` session shows in `claude agents
  --json` or ListAgents; whether `--bg` makes a worktree.

### R6. Started sessions run with no tools and normal auth

- Decision: `--tools ""` and `--strict-mcp-config` on every started session. No `--bare`, no
  `--dangerously-skip-permissions`.
- Rationale: the prompt needs no tool, so no permission prompt can stop the session unseen (spec
  edge case). `--strict-mcp-config` with no config starts no MCP server child, so the marker
  finds every process. `--bare` reads only `ANTHROPIC_API_KEY` or an `apiKeyHelper` (`claude
  --help`), so it would likely fail on this machine's login.
- Alternatives: an allow list with `--allowedTools`. Not needed for a reply with no tool.

### R7. Whether the engine gates a mod's `$.process` and `$.session.send` calls

- Decision: unknown from the docs. `claude plugin validate --json <mod dir>` lists `gatingHooks`
  and what the module calls (reference.md, "The types are the reference"). Its output for each mod
  is Q2 evidence.

### R8. Test kit

- Decision: each mod has `hooks/register.test.tsx`, run by `claude plugin test <mod dir>`.
- Rationale: `claude plugin test --help`: "Runs every *.test.ts and *.test.tsx under dir ... Exits
  1 when a test fails". The kit's `$` has every event call (`Engine`, d.ts 14882 onward, built
  from `EventCalls`, 4711-4760), so a test raises `$.command.run`, `$.session.receive` and mounts
  the pane with `$.ui.mount`. A test's own `on('session.send')` and `on('process.spawn')` hooks
  sit beneath the plugin and stand for the engine (reference.md, "Developing one").
- To confirm on the first test run: that a test hook on `process.spawn` can answer as an async
  generator for the plugin's `$.process.spawn`.

### R9. Cloud limit source

- Decision: the report quotes the ListAgents tool description as the model sees it in the running
  session, plus the issue #9 lead ("A cloud session cannot message back yet"). The d.ts says only
  that a cloud id (`session_...`) is a valid `{ sessionId }` (11524) and that the Agent tool's
  `isolation: "remote"` "launches the agent in a remote cloud environment" (16013). It has no line
  on replies. If the tool description has none either, the report says the issue lead is the only
  source.

### R10. Nested start and the environment

- Decision: record, do not assume. This session sets `CLAUDECODE`, `CLAUDE_CODE_CHILD_SESSION`,
  `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDE_CODE_MESSAGING_TOKEN`,
  `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_EXECPATH`, `CLAUDE_CODE_SESSION_ATTENDED`, `CLAUDE_EFFORT`
  and `CLAUDE_PID` (names from `env | cut -d= -f1 | grep -i claude`, T005). A Bash child and a mod's
  `$.process` child inherit them. If a nested `claude -p` refuses, the retry unsets the names the
  error points to. The token is a secret: names only, never values (plan.md S4).

## Spike report

Filled by the build. Format and rules: [data-model.md](data-model.md).

### Q1. Which mod hooks or APIs can reach other sessions? Can a mod call ListAgents / SendMessage, or only the model can?

- Answer:
- Evidence:

### Q2. Can a mod start a session (claude CLI subprocess, worktree session, cloud session)? What does it get back (id, transcript path, status)?

- Answer:
- Evidence:

### Q3. Can a mod get events from a session it did not start (tool calls, stop, errors)?

- Answer:
- Evidence:

### Q4. How do sessions share state? Options: messages only, .stratum/ files, git worktrees.

- Answer:
- Evidence:

### Q5. What is the cost and risk? Token use, two sessions editing the same files, sessions that keep running after the parent stops.

- Answer:
- Evidence:

### Test 1. A mod sends a message to a second session and shows the reply

- Outcome: full pass
- Approaches tried: A1: full pass; A2: not run, A1 passed; A3: not run, A1 passed
- Evidence: A1. The user opened `claude -n spike-peer --model haiku` and `claude --plugin-dir specs/003-session-mods/spikes/spike-send -n spike-main --model haiku --debug`, then typed `/spike-send spike-peer`. The peer transcript got, at 14:56:50Z, `<cross-session-message ... from-name="spike-main" from-mode="prompting" from-plugin="spike-send">spk003 ping: reply to this message with SendMessage, text exactly spk003-pong</cross-session-message>`, so the mod sent it with `$.session.send` and the engine tagged the sending plugin. The peer model answered with SendMessage `spk003-pong` at 14:56:54Z. The pane in spike-main showed `sent: delivered`, `reply: <cross-session-message ... from-name="spike-peer" from-mode="prompting"> spk003-pong </cross-session-message>` and `origin: peer`. The `session.receive` hook gets the delivery with its `<cross-session-message>` frame in `e.text`, not the bare text. The delivery also went on to the spike-main model (`next(e)`). No session was started by the test. The user closed both sessions with `/exit`.
- Limit: none

### Test 2. A mod starts a session and shows its status

- Outcome: pass
- Approaches tried: B1: pass; B2: not run, B1 passed; B3: not run, B1 passed
- Evidence: B1. The user started `claude --plugin-dir specs/003-session-mods/spikes/spike-start -n spike-main --model haiku --debug` and typed `/spike-start` (the trigger). The transcript shows `spike-start: running spk003-t2a`. `pgrep -af spk003` while it ran: `timeout 300 claude -p --model haiku --max-turns 3 --tools  --strict-mcp-config --no-session-persistence -n spk003-t2a spk003-t2a: reply with exactly the text spk003-t2a-ok and nothing else.` and its child `/opt/claude-code/bin/claude -p ...` with the same argv. The pane then showed `status: done`, `name: spk003-t2a`, `reply: spk003-t2a-ok`, `detail:` (empty). The session ended so fast that the user ran `/spike-start` 3 times (15:03:02Z, 15:03:23Z, 15:03:42Z) to catch it running with pgrep. No prompt or question came after `/spike-start`. After the test, `cleanup.sh` printed `nothing to clean` and `check.sh` showed no `FAIL R5`.
- Limit: none
- Result back: yes
- Stops: yes
- Human step: none

### Test 3. The model starts a session

- Outcome: pass
- Approaches tried: C1: pass; C2: pass; C3: not run, C1 passed
- Evidence: C1: `timeout 300 claude -p --output-format json --model haiku --max-turns 3 --tools "" --strict-mcp-config --no-session-persistence -n spk003-t3a "spk003-t3a: reply with exactly the text spk003-t3a-ok and nothing else."` exit 0 in 3 s, no `env -u` needed, `-n` and `--max-turns` accepted. JSON keys: `type`, `subtype` (`success`), `is_error` (`false`), `result`, `session_id`, `num_turns` (`1`), `stop_reason` (`end_turn`), `terminal_reason` (`completed`), `permission_denials` (`[]`), `total_cost_usd` (`0.00265685`), `usage` (`input_tokens` 2, `output_tokens` 12, `cache_creation_input_tokens` 13181, `cache_read_input_tokens` 1445), `modelUsage` (`claude-haiku-5-5`, `costUSD` 0.00265685), `duration_ms` 1772, `duration_api_ms` 988, plus timing and `subagent_stats` fields. `"result": "spk003-t3a-ok"`, equal to `spk003-t3a-ok` after trimming. C2: `claude --bg --model haiku --max-turns 3 --tools "" --strict-mcp-config -n spk003-t3b "spk003-t3b: reply with exactly the text spk003-t3b-ok and nothing else."` printed `backgrounded · 8ee8368d · spk003-t3b` and exit 0; `--bg` accepted `-n` and `--max-turns`. `claude agents --json` row: `{"id":"8ee8368d","name":"spk003-t3b","kind":"background","status":"busy","state":"working"}` (other keys dropped), later `"status":"idle","state":"done"`. `claude logs 8ee8368d` showed the reply `spk003-t3b-ok`. The log also showed the started session loads the user's plugins and runs in `auto mode`. `claude stop 8ee8368d` printed `stopped 8ee8368d`, `claude rm 8ee8368d` printed `removed 8ee8368d`, both exit 0. `claude stop` takes the short `id` (`8ee8368d`), a key that `claude agents --json` shows for background sessions. C3: not run, C1 passed.
- Limit: none
- Result back: yes
- Stops: yes
- Human step: none
- ListAgents: seen. This session listed `spk003-t3b [90f38e] · bg · idle · started 6s ago` under Peer sessions.
- SendMessage: delivered. The tool returned `"success":true` with "in that session's inbox". The started session's log shows the ping and its answer `spk003-t3b-ping-ok`. The answer stayed in that session's own transcript: no message came back to this session, because the started session has `--tools ""` and so no SendMessage tool.
- Over the Agent tool: a started session is its own process with its own model, and it loads the user's plugins. Other sessions can see it in ListAgents and `claude agents`, and can message it by name. A human can open it with `claude attach`, and it is stopped and removed by id. An Agent tool subagent runs inside this session and returns its answer straight to the caller. Not tested: whether a started session outlives the session that started it.

### Started sessions

| Name | Test | Approach | Argv | Turn limit | Started | Stopped | Stopped by | Process check |
|------|------|----------|------|------------|---------|---------|------------|---------------|
| spk003-t3a | 3 | C1 | `timeout 300 claude -p --output-format json --model haiku --max-turns 3 --tools "" --strict-mcp-config --no-session-persistence -n spk003-t3a "spk003-t3a: reply with exactly the text spk003-t3a-ok and nothing else."` | --max-turns 3 | 22:02:13 | 22:02:16 | exit | check.sh: no FAIL R5 |
| spk003-t3b | 3 | C2 | `claude --bg --model haiku --max-turns 3 --tools "" --strict-mcp-config -n spk003-t3b "spk003-t3b: reply with exactly the text spk003-t3b-ok and nothing else."` | --max-turns 3 | 22:04:23 | 22:04:44 | claude stop, claude rm | check.sh: no FAIL R5 |
| spk003-t2a | 2 | B1 | `timeout 300 claude -p --model haiku --max-turns 3 --tools "" --strict-mcp-config --no-session-persistence -n spk003-t2a "spk003-t2a: reply with exactly the text spk003-t2a-ok and nothing else."` | --max-turns 3 | 23:03:02 | 23:03:23 | exit (pane showed done before the next run) | check.sh: no FAIL R5 |
| spk003-t2a | 2 | B1 | `timeout 300 claude -p --model haiku --max-turns 3 --tools "" --strict-mcp-config --no-session-persistence -n spk003-t2a "spk003-t2a: reply with exactly the text spk003-t2a-ok and nothing else."` | --max-turns 3 | 23:03:23 | 23:03:42 | exit (pane showed done before the next run) | check.sh: no FAIL R5 |
| spk003-t2a | 2 | B1 | `timeout 300 claude -p --model haiku --max-turns 3 --tools "" --strict-mcp-config --no-session-persistence -n spk003-t2a "spk003-t2a: reply with exactly the text spk003-t2a-ok and nothing else."` | --max-turns 3 | 23:03:42 | 23:05:30 | exit (pane showed done before the next run) | check.sh: no FAIL R5 |

### Mod vs model

- Compare:

### Cloud limit

- Limit:
- Source:

### Claude Code version

- Version: 2.1.296

### Verdict

- Starts:
- Result back:
- Stops:
- Verdict:
- Failed part:
- Follow-up issue:
