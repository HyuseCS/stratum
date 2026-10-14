---
name: st-debug
description: Run the st-debug agent on demand for one task of the current feature, then verify with st-verify.sh (test green, no added comment lines).
---

# /stratum:st-debug <task ID> [test command]

Plugin root is two levels up from this skill's base directory.

1. Read `<project>/.stratum/state.json`. No `feature_directory`: say "No current feature. Run `/stratum:st-define`." and stop.
2. No task ID given: say "Give the task ID, for example `/stratum:st-debug T004`." and stop.
3. Test command: the one the user gave, else the one in the task's line in `<feature>/tasks.md`. None: say "Give the test command." and stop.
4. Start the `st-debug` subagent (`stratum:st-debug`) with absolute paths: plugin root, project root, feature dir. Pass the task ID, the test command, and what was tried (the user's words, else "nothing yet, run on demand").
5. **Check.** From the project root run `bash <plugin root>/scripts/st-verify.sh '<test command>' <files it changed>`. It re-runs the test and checks the files for added comment lines. Show its line. On `FAIL`, show the output and stop.
6. Commit nothing. The user commits with `/stratum:st-git`.
