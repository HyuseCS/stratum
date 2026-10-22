---
name: st-triage
description: Check GitHub issues against the current code and git history, read-only. Use for "/stratum:st-triage 15", "is issue 100 still valid", "triage issues 100 and 102". Starts one st-triage agent per issue, checks every cite against the source, and reports the verdict, what is built, the blocker and the next step.
---

# /stratum:st-triage <issue#>...

Plugin root is two levels up from this skill's base directory.

Change no file, and do not edit, comment on, label or close any issue.

1. Each argument is an issue number, with or without a leading `#`. No argument, or one that is not digits only: say "Give one or more issue numbers." and stop.
2. For each number run `gh issue view <n> --json number,state,updatedAt` and note its `updatedAt`. If one fails (no `gh`, not signed in, no such issue): say why in one line, from its error, and stop.
3. Note `git rev-parse HEAD` and `git status --porcelain --untracked-files=all`.
4. Start one `st-triage` subagent (`stratum:st-triage`) per issue, all in the same message so they run side by side. Pass each the plugin root, the project root and its issue number.
5. **Check.** When every report is in, run step 2's `gh` command and both git commands again. Any difference is a finding to check, since the main session or another person may also have changed things. Show it to the user.
6. Check each cited `file:line` and commit against the source before you show it: the line says what the report claims, `git cat-file -t <sha>` prints `commit`, and `git show --stat <sha>` shows the change the report names. Correct or drop each false cite and name the drop.
7. Show one report per issue, in the order given, headed by `#<n>`. Then the dropped and corrected cites, with why.
