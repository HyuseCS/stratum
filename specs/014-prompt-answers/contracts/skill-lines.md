# Contract: skill lines and their text-rule rows

Every row lives in `tests/test_worker_rules.sh`. A `has` row goes in the first table (`grep -qF`), a `gone` row in the second table. Each phrase below is the exact row text and the exact text in the file. A phrase is one physical line in the file, or a part of one.

## 1. st-worker, normal-mode dialogs (US1)

`skills/st-worker/SKILL.md` lines 26 and 27 are replaced by these three lines, in this order, each with the 5-space indent of today's lines 26 and 27.

| Row | Phrase |
|-----|--------|
| W1 | the whole text block below |
| W28 | `The dialog must show the whole command or path. Else send no key and tell the user.` (inside W1, inspect F7) |
| W29 | `Name the dialog's action in short in the Bash description of that call: the tool and the command or path, so the permission check sees what you approve.` (inside W1, inspect F12) |
| W2 | ``A normal-mode dialog has no `branch` or `staged` line: check the commit rule against the command the dialog shows, take the staged paths from its `git add`, and send the dialog to the user when it does not show a part of the rule.`` |
| W18 | ``If `answer` refuses the key, or a permission check or the classifier blocks the `answer` call, try no other way: tell the user the workspace, the tab and the exact dialog text.`` |

The W1 phrase, written out as it goes in the file:

```text
A permission dialog in normal mode (the pane asks "Do you want to proceed?" or to allow a tool): judge it with the `approval` lists below, which hold in both modes. The dialog must show the whole command or path. Else send no key and tell the user. An action on the allow list: send the key of the one-time yes only, `bash <plugin root>/scripts/st-worker.sh answer <id> --keys <key> [--machine <m>]`, with the key from the dialog text. Name the dialog's action in short in the Bash description of that call: the tool and the command or path, so the permission check sees what you approve. Never pick an option that says "don't ask again", "this session" or "in the future". No one-time yes, an action on the never list, one the worker's own classifier blocked, or one you do not recognise: send no key, and tell the user the worker's workspace, the tab and the exact dialog text.
```

Lines 28 to 32 before any task runs (the `approval` lists, rows W3, W4, W5, W6, W16) do not change (FR-003, FR-004).

One more check line after the first table, for FR-003 (the never list is written once), in the house form of the F2 line:

```bash
if [ "$(grep -cF 'Never approve a push' "$root/skills/st-worker/SKILL.md")" = 1 ]; then echo "ok   O1 never list once"; else echo "FAIL O1 never list once"; fail=1; fi
```

## 2. README (US1)

`README.md:117` is replaced by:

| Row | Phrase |
|-----|--------|
| W19 | `In normal mode the orchestrator answers a worker's permission prompt only for an action on the worker allow list, with the one-time yes. Every other prompt goes to you with the worker's workspace, tab and the exact prompt text.` |

## 3. The shared rule (US2)

Rule sentence R (FR-005): `Watch each agent you summon. Answer its permission prompt when the answer keeps it in its brief. Bring every other prompt to the user with the exact text.`

| Row | File | Where | Phrase |
|-----|------|-------|--------|
| W20 | `skills/st/SKILL.md` | a new bullet in `## Always`, right after the bullet that ends "and why." (line 68) | R |
| W21 | `skills/st-build/SKILL.md` | a new bullet at the end of `## Always` | R |
| W22 | `skills/st-worker/SKILL.md` | a new line after line 10, with a blank line before it | R |
| W23 | `skills/st/SKILL.md` | the line after R, 2-space indent | ``The lists: the Codex tab in `/stratum:st-build` (Advisor), herdr workers in `/stratum:st-worker` (step 6), in-session subagents in the next lines.`` |
| W26 | `skills/st-build/SKILL.md` | the line after R, 2-space indent | ``The Codex tab lists are under Advisor. The worker lists are in `/stratum:st-worker`.`` |
| W27 | `skills/st-worker/SKILL.md` | the same line as R, after it | ``The worker lists are in step 6, under `approval`.`` |

R is one physical line in each file. Lines 98 to 100 of `skills/st-build/SKILL.md` do not change (FR-009, rows A18 to A28).

## 4. The in-session subagent note (US3)

In `skills/st/SKILL.md`, right after the W23 line, 2-space indent, one line each:

| Row | Phrase |
|-----|--------|
| W24 | `An in-session subagent (the Agent tool) asks the user, not you: you cannot answer, approve or deny its permission prompt. Never run an action a subagent was denied in its place: bring the denial to the user.` |
| W25 | `An Agent call denied because a hook changed its input after auto mode reviewed it: send it once more with exactly the input the denial quotes. Denied again: tell the user.` |

Each claim maps to `research.md` R4: W24 to facts 1, 2 and 8. W25 to facts 5 and 6. Neither line points to `research.md`.

Source rows for FR-008, in the first table, word for word:

```text
S1|specs/014-prompt-answers/research.md|https://code.claude.com/docs/en/sub-agents.md
S2|specs/014-prompt-answers/research.md|https://code.claude.com/docs/en/permission-modes.md
S3|specs/014-prompt-answers/research.md|https://code.claude.com/docs/en/hooks.md
S4|specs/014-prompt-answers/research.md|7. Not documented: any way for the parent model to answer, approve or deny a subagent's permission prompt.
S5|specs/014-prompt-answers/research.md|`hooks/st-models.py:76` prints `updatedInput` with no `permissionDecision`
```

## 5. Gone rows

Second table of `tests/test_worker_rules.sh`:

| Row | Change | File | Phrase |
|-----|--------|------|--------|
| G1 | removed (013 D7 reverses 010 FR-017) | `skills/st-worker/SKILL.md` | `pick the one-time yes` |
| G5 | new | `skills/st-worker/SKILL.md` | `is never yours to answer in normal mode` |
| G6 | new | `skills/st-worker/SKILL.md` | ``Use `answer --keys` only for a worker's question, never for a permission dialog.`` |
| G7 | new | `README.md` | `In normal mode the orchestrator never approves a worker's permission prompt` |

`tests/test_lane_steps.sh:24` (row 1, `pick the one-time yes`) is removed for the same reason as G1. Rows 2 and 3 there stay, so `row 2` and `row 3` keep their names.

These rows stay green and their phrases stay in the files: `tests/test_on_demand.sh:215-223`, `tests/test_lane_steps.sh:25` (row 2), `tests/test_advisor_rules.sh:47` (G5, st-build never holds `st-advisor.sh answer --keys`).
