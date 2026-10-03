---
name: st-commit-mode
description: Set Stratum's commit guard mode for this machine and project to auto, ask, or deny.
---

# /stratum:st-commit-mode <auto|ask|deny>

1. Accept only `auto`, `ask` or `deny`. Anything else: show the three values and stop.
2. Write the value, alone, to `<project>/.stratum/commit-mode`.
3. Make sure `<project>/.gitignore` has a line `.stratum/commit-mode`; add it if missing.
4. Reply in one line: `Commit mode: <value>.` For `auto`, add: "Commits run without asking. Push
   still asks." For `ask` during a Build phase, add: "You will be asked once per task."
