# Research: Agent model overrides

No item in Technical Context was marked NEEDS CLARIFICATION. The items below settle the
mechanism (the spec's blocking assumption, CHK014) and the gaps the config checklist found.

## Verified facts

The orchestrator ran these on Claude Code 2.1.294 with `claude -p --settings` and a temporary hook.

- **V1.** A PreToolUse hook with matcher `"Agent"` gets stdin JSON with `cwd`, `tool_name: "Agent"`
  and `tool_input` = `{description, prompt, subagent_type, model?, run_in_background?, ...}`.
  Plugin agents show as `subagent_type: "stratum:st-close"` and so on.
- **V2.** Output `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": {...}}}`
  changes the started subagent's model and effort. In the subagent transcript, a call that asked
  for `model: "sonnet"` ran on `claude-haiku-5-5` with `effort: "low"`. It works with and without
  `permissionDecision: "allow"`.
- **V3.** `updatedInput` replaces the whole input object. The hook must copy every field.
- **V4.** Docs (code.claude.com/docs/en/hooks, /sub-agents): plugin PreToolUse hooks also fire for
  tool calls inside subagents. Block with exit 2 and a stderr message, or with
  `permissionDecision: "deny"` and `permissionDecisionReason`.
- **V5.** Model order: per-call `model` > agent frontmatter > `CLAUDE_CODE_SUBAGENT_MODEL` > main
  model. Effort: per-call `effort` > frontmatter `effort`. `CLAUDE_CODE_EFFORT_LEVEL` beats both.
- **V6.** The Agent tool accepts models `sonnet`, `opus`, `haiku`, `fable` and efforts `low`,
  `medium`, `high`, `xhigh`, `max`.
- **V7.** `claude -p --settings <file>` with a PreToolUse `Agent` hook in that file runs the hook
  for the session. The quickstart end-to-end run uses it with the real `hooks/st-models.py`, so it
  does not depend on which plugin copy is installed.
- **V8.** `tool_input.subagent_type` is optional on 2.1.294. The hook reads it as
  `tool_input.get("subagent_type") or ""`.

## Decisions

### R1. Mechanism: PreToolUse hook on `Agent` with `updatedInput`

- Decision: `hooks/st-models.py`, registered in `hooks/commands.json` under `PreToolUse` with
  matcher `"Agent"`, command `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-models.py"`, timeout 10.
- Rationale: D10. V1 to V3 confirm the hook can change model and effort per call, and the file is
  read on each call, so edits apply at once (FR-002, SC-003).
- Alternatives: each skill tells the model to read the file (O3, rejected in D10); agent
  frontmatter edits (O7, rejected in D12).

### R2. Rewrite without `permissionDecision`

- Decision: the rewrite output has `hookEventName` and `updatedInput` only.
- Rationale: V2 shows it works without `allow`. Leaving it out keeps the user's permission rules
  in force (plan Security Notes S1).
- Alternatives: `permissionDecision: "allow"` would skip the user's rules for agent starts.

### R3. Block with `permissionDecision: "deny"`

- Decision: a bad file gives `permissionDecision: "deny"` and a `permissionDecisionReason` that
  names the file, the bad item and the allowed values.
- Rationale: same output shape as `hooks/st-git-guard.py`, so the test style carries over. The
  reason reaches the model, which tells the user.
- Alternatives: exit 2 with stderr. Works too, but differs from the existing hook and test.

### R4. What counts as a Stratum agent (CHK006, FR-006)

- Decision: `subagent_type` starts with `stratum:`. For anything else the hook exits with no
  output and does not read the file. The name after the prefix is the key in the file.
- Rationale: V1 shows plugin agents carry the `stratum:` prefix. A bare `st-close` is not ours.
- Alternatives: match bare names too. Rejected: another plugin or user agent could share a name.

### R5. Allowed values live in the hook (CHK002, FR-005)

- Decision: the hook holds `MODELS` and `EFFORTS`. It builds the agent list from the file names in
  `<plugin root>/agents/*.md` (the hook finds the folder from its own path). A test checks that
  this list is exactly the 11 names in FR-005, and that the `st-model` skill and README name every
  agent, model and effort.
- Rationale: one place to change. Agent names cannot drift from the agent files.
- Alternatives: a shared JSON list file. Rejected: one more file for three short lists.

### R6. Validate the whole file on every Stratum start

- Decision: on every `stratum:` start, check every entry, not only the started agent's entry.
  Report all problems in one message. Each bad key or value is quoted with `json.dumps` and cut
  to 80 characters.
- Rationale: spec edge case "a bad entry for one agent blocks the start of every Stratum agent".
- Alternatives: check only the started agent. Rejected by the spec.

### R7. Hook failure (CHK003)

- Decision: any exception while reading or checking the file becomes a deny with the error text.
  A missing file (`FileNotFoundError`) means no override. Bad stdin means no output, as in the git
  guard. If `python3` is missing, Claude Code shows a non-blocking hook error and the agent starts
  on its defaults.
- Rationale: no silent fallback for any file state (FR-004). The `python3` case cannot be caught
  by the hook itself. `st-status` already checks for `python3`.
- Alternatives: none cheaper.

### R8. Project folder

- Decision: walk up from `cwd` to the first folder with `.stratum/` or `.git`, as `guard_file` in
  `hooks/st-git-guard.py` does. Copy those lines; the hooks stay separate scripts.
- Rationale: same lookup as the git guard, so a subfolder finds the project's file.
- Limit: a linked worktree has its own `.stratum/` (because `state.json` is tracked), so the walk
  stops there. The git-ignored `models.json` is not in the worktree (`scripts/st-worktree.sh` links
  only `.claude/settings.local.json`), so the override does not apply there. `git-guard.json`
  behaves the same. The README says so (T016).
- Alternatives: `CLAUDE_PROJECT_DIR`. Rejected: differs from the git guard.

### R9. `st-model` arguments (D18, refines D14)

- Decision: `/stratum:st-model <agent> <value>...`. Each value is a model, an effort, `default`
  (remove the whole entry), `model default` or `effort default` (remove one key). An entry left
  as `{}` is removed. Model and effort names do not overlap, so each value's kind is clear.
- Rationale: D14's form `<agent> <model|default> [effort]` cannot set an effort alone ("put
  st-test on high effort", US4) or reset one key (US4 scenario 2, CHK007). D14 left the form to
  the agent.
- Alternatives: D14's literal form. Rejected for the two gaps above. The user accepted this form as D18.

### R10. `st-model` on a repo with no file

- Decision (D17, user choice O16): copy `<plugin root>/templates/models.json` to
  `.stratum/models.json` first, then apply the change.
- Rationale: a repo that never ran `st-init` gets the same starting setup as a new repo, and the
  asked change goes on top. The reply lists the template entries so the user sees them.
- Alternatives: start from `{}` with only the asked entry, as `st-shape` creates
  `powerline.json`. Rejected by the user in D17.

### R11. Skill step numbers

- Decision: `st-status` gets the overrides as a new last step 7. `st-init` gets a new step 4
  (Models) after the git guard; steps 4 to 10 become 5 to 11.
- Rationale: `skills/st-init/SKILL.md:50` points at `st-status` "steps 4 and 5". A step added
  before them would break that pointer. Nothing points at `st-init` step numbers.

### R12. Default table at run time

- Decision: `st-init` and `st-status` read each agent's default from the `model:` line in
  `<plugin root>/agents/*.md`.
- Rationale: no second copy of the 11 defaults.

## Known limits

- **L1.** `CLAUDE_CODE_EFFORT_LEVEL`, when set, beats the file's effort (V5). The README says so.
- **L1b.** The per-call `effort` parameter needs Claude Code 2.1.292 or later. On an older client,
  remove `effort` keys from the file. The README says so (T016).
- **L2.** Haiku was checked with effort `low` (V2) and `xhigh` (the template, D15: a Haiku 5.5
  subagent started with effort `xhigh` and no error). `max` on Haiku is not verified.
- **L3.** `haiku` started `claude-haiku-5-5` in V2, which answers CHK015.
- **L4.** Subagents that start Stratum agents (CHK013) are covered by V4: the hook fires there too.
