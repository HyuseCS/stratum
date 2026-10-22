# 006 handoff-trigger

What: The `Stratum rule:` line in `hooks/st-session-start.sh:17` names `st-handoff` only as the
exception to the background rule. It never says when to run it. With no skill list in context the
model writes to auto-memory at session end and `.stratum/handoff.md` goes stale (GitHub issue #29,
seen in v2-veent). Add two sentences at the end of the same echo string that say when to run it.
FRs: FR-009 (the main session writes the handoff when the user is done or ends the session)
Impact area: core runtime (hook output + test)

## Files
- `hooks/st-session-start.sh:17` - append to the end of the echo string, after
  `...runs only in the main session.` and before the closing quote (plain text, no backticks):
  ` When the user ends the session or says they will continue later, run /stratum:st-handoff in the main session before the last reply. Do not use auto-memory in place of it.`
  The existing `Any other skill asked for in the background, except st-handoff: ...` clause is not
  moved or reworded (tests grep it verbatim).
- `tests/test_on_demand.sh:105` - two rows added to the `phrases` heredoc after the
  `FR-008 rule	hook	check each finding ...` row (tab-separated, label `#29 handoff rule`, no space after `#`):
  - `#29 handoff rule	hook	run /stratum:st-handoff in the main session before the last reply`
  - `#29 handoff rule	hook	Do not use auto-memory in place of it`
- `specs/004-on-demand-steps/contracts/background.md` section 5 - append the same sentences to the
  exact echo text block (line 143) and add the two phrases to the phrase list (line 146-153) with
  check name `#29 handoff rule`.
- `specs/004-on-demand-steps/data-model.md:44-45` - add one sentence to "Background rule": the same
  text also says to run `st-handoff` in the main session when the user ends the session or says they
  will continue later, and not to use auto-memory instead.

No change, judgment calls:
- `DESIGN.md` D24 (line 254) is about background agents. The handoff trigger is a different rule, and
  D24 already says other skills run only in the main session. Not edited.
- `README.md` "Session handoff" bullet (line 187) already says "When you say you are done, it runs in
  the main session". The hook text restates that for the model. Not edited.

## Tests (written first, must fail before the build)
- `tests/test_on_demand.sh` - the two new rows check that the hook output with `.stratum/` holds both
  phrases. Red before the hook edit (the phrases are absent), green after.
  Command: `bash /home/hyuse/Desktop/stratum-29/tests/test_on_demand.sh`
- `tests/test_session_hooks.sh` - runs the same hook, must stay green.
  Command: `bash /home/hyuse/Desktop/stratum-29/tests/test_session_hooks.sh`
- Negative control: after the build, remove the new sentence from the hook once, run
  `test_on_demand.sh`, see the two `#29 handoff rule` checks go red, restore it.

## Risks
- Done-when 3 of the issue (a real session reacts to "we'll continue next session") cannot run in a
  test. Manual check for the user after merge:
  1. Start a fresh Claude Code session in a project that has `.stratum/`, with the plugin loaded from
     `/home/hyuse/Desktop/stratum` (the merged code).
  2. Do one small task, then type: `we'll continue next session`.
  3. Before the last reply, the model must run `/stratum:st-handoff`.
  4. Run `ls -l <project>/.stratum/handoff.md`: the time must be new, and the file must hold this
     session's goal and next step. No auto-memory write should replace it.
- A rule in a prompt is a nudge, not a guard. The model may still skip it. Step 4 is the only proof.
- The hook line grows by about 190 characters on every session start.
