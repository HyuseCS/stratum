---
name: st-template
description: Copy one of Stratum's templates into the project so it can be edited; the project copy then overrides the plugin's.
---

# /stratum:st-template <name>

Plugin root is two levels up from this skill's base directory.

1. List `<plugin root>/templates/*.md`. If `<name>` is missing or unknown, show the list and stop.
2. If `<project>/.stratum/templates/<name>.md` already exists, say so and stop. Never overwrite.
3. Copy `<plugin root>/templates/<name>.md` to `<project>/.stratum/templates/<name>.md`.
4. Reply: the path, and that Stratum now uses this copy for this project. Deleting it restores
   the plugin's version.
