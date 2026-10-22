---
name: st-test
description: Run the st-test agent on demand for task IDs of the current feature, then re-run each test and confirm it fails for the right reason.
---

# /stratum:st-test <task IDs>

Plugin root is two levels up from this skill's base directory.

1. Read `<project>/.stratum/state.json`. No `feature_directory`: say "No current feature. Run `/stratum:st-define`." and stop.
2. No task ID given: say "Give the task IDs, for example `/stratum:st-test T004`." and stop.
3. Start the `st-test` subagent (`stratum:st-test`) with absolute paths: plugin root, project root, feature dir. Pass the task IDs.
4. **Check.** Run each test command it reports again from the project root. It must exit non-zero and fail for the right reason: the line it quoted, from missing behavior, not a typo, an import error or broken setup. A test that passes is wrong: say so.
5. Show per task: test file, command, failing line. Commit nothing.
