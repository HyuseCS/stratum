---
name: st-autonomous
description: Turn autonomous build mode on or off for this session.
disable-model-invocation: true
---

# /stratum:st-autonomous <on|off>

Plugin root is two levels up from this skill's base directory.

1. Accept only `on` or `off`. Anything else, or no value: run nothing and reply in one line: `Usage: /stratum:st-autonomous on|off`.
2. `on`: run `bash <plugin root>/scripts/st-worker.sh autonomous-on`. Show its lines word for word (the `autonomous on` line and, when printed, the `hint` line). On exit 0, say `Autonomous build mode: on for this run`. Run this step only for the user's own `/stratum:st-autonomous on`. After the mode ends, never turn it on again yourself: say `Run /stratum:st-autonomous on to turn on autonomous build mode.` It makes only this session's entry in the main checkout, also from a linked worktree, and leaves the entries of other sessions alone. It ends when the Build or worker run ends, or when the user says they are done or will continue some other time (before the handoff): run step 3.
3. `off`: run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` if workers ran in this session, else `bash <plugin root>/scripts/st-worker.sh autonomous-off`. Show its lines word for word. On exit 0, say `Autonomous build mode: off`. It removes only this session's entry.
