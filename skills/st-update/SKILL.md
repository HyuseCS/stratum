---
name: st-update
description: Audit the project's Stratum files in every checkout, then update the install, statusline and harness lines after one OK.
---

# /stratum:st-update [folder]

Plugin root is two levels up from this skill's base directory. `<script>` is
`<plugin root>/scripts/st-update.sh`. Put single quotes around every argument you pass to the
script and to git (folder, kind, name, paths, message).

1. **Audit.** Run `bash <script> audit <folder>`, with the argument as `<folder>`, else the project root.
   Exit 1: show the line and stop.
   No row other than `current`, `gone` and `listed`: say every item is current and stop. No gate.
2. **Table.** Show one table. The header: the marketplace version and folder, and the config folder.
   Then, per folder, only the rows that are not `current`: folder, kind, name, state, detail.
   Then one line per folder with the count of its `current` items.
   A folder with `worker` in a detail is a worker worktree: say so on its rows and its count line.
3. **Gate.** A `marketplace-branch` row: above the question, warn
   `The marketplace folder <installLocation> is on branch <branch>, not main. The update installs that branch.`
   Then ask one question: OK to update all, or `skip <worktree>` (one or more), or no.
   No: stop, nothing changed.
   Change nothing before the OK.
