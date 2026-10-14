---
name: st-review
description: Run the st-review agent on demand on the current feature's diff (default main..HEAD), then check each finding against the source before showing it.
---

# /stratum:st-review [range] [story]

Plugin root is two levels up from this skill's base directory.

1. Read `<project>/.stratum/state.json`. No `feature_directory`: say "No current feature. Run `/stratum:st-define`." and stop.
2. Range: the one the user gave, else `main..HEAD`. No range given and `git rev-parse --verify main` fails: say "No `main` branch. Give the range." and stop.
3. Start the `st-review` subagent (`stratum:st-review`) with absolute paths: plugin root, project root, feature dir. Pass the story the user named (else every story in the range) and the range.
4. **Check.** Check each finding against the source before you show it: the defect is at that `file:line`, and the stated cause is the real one. Drop the false ones.
5. Show the real findings, then the dropped ones with why, in short form. Fixes go through a lane.
