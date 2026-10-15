---
name: st-handoff
description: Write the session handoff to .stratum/handoff.md so the next session starts where this one stopped. Run at the end of a session or when the user says they are done. Mid-session it runs in a background fork; when the user says they are done or is ending the session it runs in the main session.
---

# /stratum:st-handoff

## Where it runs

- A `Handoff` fork is already running: do not start another and do not write here. Wait for its report. If the user said they are done, wait for it before the reply ends.
- The user said they are done or is ending the session: write it here, in the main session, so it finishes before they leave.
- Else start the Agent tool with `subagent_type: "fork"` and the description `Handoff`. A fork has this whole conversation and runs in the background. Prompt: "You are the fork. Write `.stratum/handoff.md` now as `/stratum:st-handoff` says after its Where it runs section. Do not start another agent." Tell the user in one line that a fork is writing it, and keep answering. When it reports, relay its next step in one line. If its report shows no file was written, write it here.
- The fork cannot start: write it here and say so in one line.

## Write it

Write `<project>/.stratum/handoff.md`. Keep the facts block between `<!-- st-facts:start -->` and
`<!-- st-facts:end -->` if one exists (a hook maintains it); replace everything above it.

Write, in plain short sentences, from this session's work:

```markdown
# Handoff — <YYYY-MM-DD HH:MM>

## Goal
<what this stretch of work is for>

## Where we are
Feature <dir>, lane <lane>, phase <phase>, task <ID or "none">.

## Decisions made
- D1. <decision> (<why>)

## Open questions
- Q1. <question> (<who decides>)

## Blockers
- <blocker or "none">

## Next step
<the exact next action, with the command or file>
```

In `## Next step`, never suggest deleting a local branch. For cleanup, name only a worktree folder
whose work is done and a merged remote branch (the user deletes the remote branch).

Then make sure `<project>/.gitignore` has `.stratum/handoff.md`. Reply with the next step in one
line.
