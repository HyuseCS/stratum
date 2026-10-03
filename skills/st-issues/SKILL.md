---
name: st-issues
description: Turn the current feature's tasks.md into GitHub issues on the repo's own GitHub remote, skipping tasks that already have one.
---

# /stratum:st-issues

Plugin root (`<plugin root>`) is two levels up from this skill's base directory.

1. Read `<project>/.stratum/state.json`. If there is no `feature_directory`, stop and tell the
   user to run `/stratum:st-define`.
2. Follow `<plugin root>/procedures/issues.md` yourself (`<PLUGIN_ROOT>` is the plugin root).
   Create issues only on the repo's own GitHub remote.
3. Report: issues created, tasks skipped as duplicates, and any error.
