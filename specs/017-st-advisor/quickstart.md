# Quickstart: st-advisor

## Automated (fakes only)

```bash
bash tests/test_advisor.sh          # review point headless: usage, no change, modes, 1800 s, record path, prompt, plan file
bash tests/test_advisor_matrix.sh   # review point in a fake Codex tab: tab first, three fallbacks, BLOCKED on change
bash tests/test_advisor_waive.sh    # lane points unchanged
bash tests/test_on_demand.sh        # skill text: forms, stops, watch, CodeRabbit, check of findings
bash tests/test_harness_model.sh    # model lists the skill and the record folder
```

Each passes with no `codex`, `coderabbit` or `herdr` call leaving the machine.

## Manual (live; sends code to OpenAI and CodeRabbit)

Prerequisites: `codex` logged in, `.stratum/advisor.json` with mode `codex`, herdr session, `gh` signed in, `coderabbit` signed in.

M1. Plain form, no spec folder (Story 1)
1. In a scratch repo with no `specs/`: `git switch -c try/one`, make two commits.
2. Run `/stratum:st-advisor`.
3. Expect: the Codex tab opens and runs the review; last line `codex: tab st-codex-<label>`; record at `<repo>/.stratum/advisor/try-one.md` with one `## review |` entry; `git status --porcelain` the same as before.
4. Run it again: the file has two entries.

M2. Headless fallback
1. Same repo, outside herdr (plain terminal `claude`).
2. Run `/stratum:st-advisor main`.
3. Expect last line `codex: headless (not in herdr)`.

M3. Big diff (SC-001)
1. On a branch with about 5,800 changed lines, run `/stratum:st-advisor` in herdr.
2. Expect a verdict, not `timed out`.

M4. PR form with CodeRabbit (Story 2)
1. Have a worker worktree with its branch pushed and a PR open, HEAD at the PR head.
2. From the main checkout run `/stratum:st-advisor #<n>`.
3. Expect: CodeRabbit runs as `coderabbit review --agent --fresh --committed --base-commit <base>` in the worktree, the review runs in the worktree (tab or `headless (Codex tab name ... in use elsewhere)`), the record `<main>/.stratum/advisor/<branch>.md` has a `## review |` entry and a `## coderabbit |` section, and the skill shows checked findings from both.
4. Check `git -C <worktree> status --porcelain` is the same as before (CodeRabbit wrote nothing in the worktree).

M5. PR stops
1. `/stratum:st-advisor #<n>` for a PR with no local worktree: "No local worktree has branch ...".
2. Commit once more in the worktree without pushing, run again: the worktree and PR head do not match.

3. Set `.stratum/advisor.json` to `{"mode": "off"}` in the main checkout and run `/stratum:st-advisor #<n>`: the skill says `no advisor: mode off`, and no CodeRabbit run starts (no new log in `~/.coderabbit/logs/`). Put the mode back.

M6. Plan file (Story 3)
1. Write a plan file that names one change the diff does not make.
2. `/stratum:st-advisor main /abs/path/plan.md`.
3. Expect a finding about the missing change.
