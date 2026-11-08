# Contract: `st-advisor.sh review`

```text
bash <plugin root>/scripts/st-advisor.sh review <base> [<plan file>]
```

Run from the review folder. No feature folder, no `spec.md`.

## Input checks (in order)

| Case | Output | Exit | Record |
|------|--------|------|--------|
| wrong argument count | `usage: st-advisor.sh plan\|test\|diff\|decisions\|change\|review\|round\|check\|continued\|waive\|note\|talk\|count\|answer\|watch ...` | 2 | none |
| `<base>` not a commit | usage line | 2 | none |
| `<plan file>` missing or not readable | usage line | 2 | none |
| no change between `<base>` and HEAD | `no change since <base>: skip` | 0 | none |
| `.stratum/advisor` or the record file in the main checkout is a symlink (checked right after the main checkout is found) | usage line | 2 | none |
| no `.stratum/advisor.json` here or in the main checkout | `no advisor: mode not set. Write .stratum/advisor.json with "mode": "auto", "codex", "both" or "off".` | 0 | none |
| `.stratum/advisor.json` not valid | `BLOCKED: bad advisor.json` | 1 | `BLOCKED` entry |
| mode `off` | `no advisor: mode off` | 0 | none |
| no `codex` on PATH | `no advisor: codex not found` | 0 | none |

Mode `auto` at any risk, `codex`, `both`: Codex runs. In `auto`, the first line is `advisors: codex (review, risk <risk>)`, after `risk not set: normal` when no risk is set. In `both`, the first line is `mode both: also consult /advisor if one is set`.

## Prompt

Lines 1 to 4: the existing head, unchanged. Then:

```text
Point: review. Do a full review of the changes in git diff <base>..HEAD (run it yourself): bugs, regressions, security and broken rules of the project's constitution. Do not build or fix.
```

With a plan file, one more line:

```text
Plan: <plan file>. Also check whether the diff does what this file says. A gap is a finding.
```

## Runner

- In herdr (`HERDR_ENV=1`, `HERDR_WORKSPACE_ID` set, `herdr` on PATH): the Codex tab, no time limit. Last line `codex: tab st-codex-<label>`.
- Fallbacks, last line: `codex: headless (not in herdr)`, `codex: headless (Codex tab in use)`, `codex: headless (Codex tab name <name> in use elsewhere)`, `codex: headless (Codex tab failed)`.
- Headless: `timeout -k 10 <1800 - elapsed> codex exec -s read-only --ignore-user-config ...`. The 60 s floor stays.
- Lock held by another point: `BLOCKED: Codex agent busy with another review` (unchanged).
- Files or HEAD changed during a tab run: `BLOCKED: Codex changed files during the review: <paths>` (unchanged). A headless run has no change check, the same as the other points.

## Output

```text
APPROVED|REVISE sha256 <hash>
summary: <summary>
- [SEV] <location>: <claim> Evidence: <evidence>
record: <main checkout>/.stratum/advisor/<slug>.md
codex: tab st-codex-<label> | codex: headless (<reason>)
```

BLOCKED: `BLOCKED: <reason or summary>`, then `record: ...`, exit 1. The record format is in [data-model.md](../data-model.md).

## Lane points

`plan`, `test`, `diff`, `decisions`, `change`, `round`, `check`, `continued`, `waive`, `note`, `talk`, `count`, `answer`, `watch`: same arguments, output, limit (540 s) and `specs/<feature>/advisor.md` record as before. The one allowed change is the shared usage line, which gains `review` (FR-016).
