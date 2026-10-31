---
name: st-herdr-workspace
description: Open a project folder as a new herdr workspace with the full or basic layout, on this machine or a saved machine. Use for "open a workspace for issue 32 in ~/Desktop/stratum-003", "open a parasat-staging workspace on the laptop", "template 1 with the three tabs".
---

# /stratum:st-herdr-workspace <folder> [machine] [full|basic] [claude|claude2]

Plugin root is two levels up from this skill's base directory.

Make no herdr call yourself.

This is a manual tool. For agents that work by themselves, the orchestrator uses `/stratum:st-worker`.

1. Read from the request: the folder, the machine (label or id, as the user says it), the template (`full` by default; "template 1" or "the three tabs" means `full`), the agent (`claude` by default, `claude2` when asked).
2. Pick the label: the issue or task the workspace is for, `<number>-<short-name>` when an issue number is known; when the request names none, one first name, like a person (`ada`).
3. Run the script with each value as one quoted argument, and `--machine` only when the request names a machine:
   `bash <plugin root>/scripts/st-herdr-workspace.sh "<folder>" --label "<label>" [--machine "<machine>"] --template "<template>" --agent "<agent>"`
4. Show its output as it is. On a one-line failure, show the line and stop.
5. After a failure, do not run it again: the report shows what exists, and a failed remote call may still have made something (herdr skill: inspect before retry).

The layouts live in `scripts/st-herdr-workspace.sh`. The user's `~/.config/herdr/templates.sh` can drift from them.
