---
name: st-grill
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask **one question per message**, picked from the frontier. Ask the questions that change the most first.

Format every question like so:

```
## Q12: <question>

<the facts the user needs to decide, from the code or research; short, with file names where useful>

**O9 (recommended):** <what it means and why>
**O10:** <what it means and the cost>

Do you agree with O9?
```

Codes `Q`, `O` and `D` are stable for the whole session: never reuse or renumber one.

After each answer:

- Record it as a decision in the decisions file before asking the next question: `- D13 (Q12): <chosen option and what it means>. Rejected: <the other option>.` The file is `<feature dir>/decisions.md` when `.stratum/state.json` names a feature directory, else `.stratum/decisions.md`. Create it if missing.
- If the answer is a question back, answer it first, then ask again.
- If the answer shows your recommendation was wrong, say so, correct it, and ask again.

Each answer reshapes the tree: a settled decision pushes the frontier outward and unblocks the questions that depended on it. Recompute the frontier and ask the next question.

Finding _facts_ is your job, never the user's. When a question needs a fact from the environment (filesystem, tools, etc.), look it up or dispatch a sub-agent; don't ask the user for anything you could find yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait; ask the rest of the frontier meanwhile. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. End with the list of decisions by code. Do not act on it until the user confirms you have reached a shared understanding.
