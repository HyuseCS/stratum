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
  `CLAUDE_CODE_SESSION_ID` and others (names from `env | cut -d= -f1`). A Bash child and a mod's
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

- Outcome:
- Approaches tried:
- Evidence:
- Limit:

### Test 2. A mod starts a session and shows its status

- Outcome:
- Approaches tried:
- Evidence:
- Limit:
- Result back:
- Stops:

### Test 3. The model starts a session

- Outcome:
- Approaches tried:
- Evidence:
- Limit:
- Result back:
- Stops:
- ListAgents:
- SendMessage:
- Over the Agent tool:

### Started sessions

| Name | Test | Approach | Argv | Started | Stopped | Stopped by | Process check |
|------|------|----------|------|---------|---------|------------|---------------|

### Mod vs model

- Compare:

### Cloud limit

- Limit:
- Source:

### Claude Code version

- Version:

### Verdict

- Starts:
- Result back:
- Stops:
- Verdict:
- Failed part:
- Follow-up issue:
