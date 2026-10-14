---
name: st-git
description: Commit on demand through the st-git agent. With no file list, show the changed files and commit only the ones the user picks; then show the commit's file list.
---

# /stratum:st-git [files...]

Plugin root is two levels up from this skill's base directory.

1. Files: the paths the user gave. None given: run `git status --porcelain --untracked-files=all`. No output: say "Nothing to commit." and stop. Else show the changed files and ask the user which to commit. They pick none: stop.
2. Start the `st-git` subagent (`stratum:st-git`) with absolute paths: plugin root, project root. Pass the change (the user's words, else "on-demand commit") and the file list.
3. Line 1 of its report does not start with `Committed`: show its text and stop.
4. **Check.** Run `git log -1 --name-only --format=` and show it. It must list exactly the files given. If not, name the ones that differ.
5. Push only when the user says "push".
