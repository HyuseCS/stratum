---
name: st-quick
description: Run a one-file, low-risk edit (text, typo, one-file visual fix) through Stratum's Quick lane with no gate.
---

# /stratum:st-quick <edit>

Plugin root is two levels up from this skill's base directory. Set `lane` and `phase` to `quick` in
`<project>/.stratum/state.json`.

1. Start the `stratum:st-quick` subagent with: plugin root, project root, and the edit.
2. If it reports "move up a lane", tell the user in one line and run `/stratum:st-fast`.
3. Otherwise verify with `bash <plugin root>/scripts/st-verify.sh '<the tests it ran, or true if none>' <the file>` (see `/stratum:st`).
4. The `stratum:st-git` agent commits the one file.
5. Tell the user what changed in one line. Push only on their "push".
   Set `phase` to `done` in state.json.
