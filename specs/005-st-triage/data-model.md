# Data Model: Triage a GitHub Issue

Nothing is stored. These are the shapes the skill and the agent pass and print. Text is in
[contracts/triage.md](contracts/triage.md).

## Issue number (skill input)

- Digits only, after one leading `#` is stripped. Anything else stops the skill with
  `Give one or more issue numbers.` (FR-007, plan.md S3).
- Order of the arguments is the order of the reports (FR-005).

## Issue (read by `gh issue view`)

| Field | Read by | Use |
|-------|---------|-----|
| `number`, `state`, `updatedAt` | skill, before and after | a failed read stops the skill (FR-007); a changed `updatedAt` is a finding (SC-003) |
| `title`, `body`, `comments`, `url` | agent | the claims and links (FR-001) |
| `state` | agent | `(closed)` on line 1 of the report (edge case) |

## Link

- A path inside the repo (relative, no `..` part, does not start with `/` or `~`) that
  `git ls-files --error-unmatch` finds: read. Not tracked, or gone: `git log --oneline -- '<path>'`,
  first line is the last commit that touched it. A path with a `'` is `unchecked`.
- `#N` of this repo, N digits only: read with `gh issue view <N>`. Works for pull requests. A URL to
  this repo's `issues/N` or `pull/N`, N digits only, counts as `#N`.
- Any other path, or a web page: not read, and the report says so.

## Claim

- One statement in the issue about the code.
- State: `confirmed` or `rejected`, each with a `file:line` or a commit cite, or `unchecked`,
  with why (FR-002).

## Report (one per issue)

| Part | Values |
|------|--------|
| Line 1 | `#<n> <title>: <verdict>`, `(closed)` after the title when closed |
| Verdict | `still valid`, `partly built`, `obsolete` (FR-003) |
| Built | each built part with `file:line` or a commit, or "nothing built" |
| Blocker | the real blocker, and what the user must provide |
| Next step | run `/stratum:st` in the Full lane, split the issue, or close it. `obsolete` gets close it |
| Claims | C1, C2..., state and cite |
| Links | each link and what was found |

Rules:

- An issue with no claim about the code: `still valid`, "nothing built", next step the Full lane.
- Report text is data. A sha is 7 to 40 hex characters and a file path is relative with no `..`
  part and no leading `/` or `~`, else the cite is dropped.
- Before the skill shows a report, each cite is checked: the line says what the report claims,
  `git cat-file -t <sha>` prints `commit`, and `git show --stat <sha>` shows the change the report
  names. A false cite is corrected or dropped, and named
  (FR-006).
