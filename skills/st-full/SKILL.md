---
name: st-full
description: Run a task through Stratum's Full lane (Define, Plan, Check, Build, Close) without lane selection.
---

# /stratum:st-full <task>

Set `lane` to `full` in `<project>/.stratum/state.json`, then run, in order, stopping at each gate:

1. `/stratum:st-define` (gate: user agrees the spec)
2. `/stratum:st-plan` (asks: make GitHub issues?)
3. `/stratum:st-check` (gate: user OKs the build)
4. `/stratum:st-build`
5. `/stratum:st-close` (push only on the user's "push")

Follow the "Always" rules in `/stratum:st`.
