---
name: st-handoff
description: Write the session handoff to .stratum/handoff.md so the next session starts where this one stopped. Run at the end of a session or when the user says they are done.
---

# /stratum:st-handoff

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

Then make sure `<project>/.gitignore` has `.stratum/handoff.md`. Reply with the next step in one
line.
