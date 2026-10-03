---
name: st-constitution
description: Create or amend the project rules in .stratum/constitution.md from the user's words, with a version bump and sync report.
---

# /stratum:st-constitution <rules or changes>

Plugin root (`<plugin root>`) is two levels up from this skill's base directory.

1. If `<project>/.stratum/` does not exist, create it.
2. Follow `<plugin root>/procedures/constitution.md` yourself (`<PLUGIN_ROOT>` is the plugin root),
   with the user's words as input. It reads and writes only `<project>/.stratum/constitution.md`.
3. When a value is unclear, ask the user one question at a time, with your recommendation.
4. Show the version change and the summary. Have `st-git` commit `.stratum/constitution.md` only.

Never skip the commit guard. Push only when the user says "push".
