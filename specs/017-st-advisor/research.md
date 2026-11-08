# Research: st-advisor

R1. New point in the existing script
- Decision: `st-advisor.sh review <base> [<plan file>]` inside `scripts/st-advisor.sh` (D11, D12).
- Rationale: snapshot, tab runner, lock, schema, answer check and mode file already live there. The point adds an arity line, an input check, a prompt branch, a limit and a record path.
- Alternatives: a separate script (O26, rejected in D11); a `<head>` argument with a pinned worktree (O27, rejected in D12).

R2. Record path
- Decision: `rec=$main/.stratum/advisor/<slug>.md`, `main` from `git rev-parse --path-format=absolute --git-common-dir` (line 120 already computes it). Slug: `git symbolic-ref -q --short HEAD` with `/` as `-`; detached HEAD: `git rev-parse --short HEAD`.
- Rationale: one variable replaces `$f/advisor.md` in `block()` and in the python. Lane points keep `rec=$f/advisor.md`, so their output text is the same.
- Alternatives: the worktree's own `.stratum/advisor/` (O30, rejected in D13).

R3. Mode and risk for `review`
- Decision: `auto` maps `review-*` to `codex` before the risk rows. `codex` and `both` reach Codex with no change. The `mode both` line prints for `review` too, and the skill handles it like the lanes (consult `/advisor` if one is set).
- Rationale: FR-003 needs Codex at any risk. Keeping the `mode both` line costs no code.
- Alternatives: suppress the line for `review` (one more condition, no spec need).

R4. Headless limit
- Decision: 1800 s for `review`, 540 s for the rest (D15). The tab has no limit already (`st-codex-agent.sh` waits with no timeout).
- Alternatives: a limit that grows with the diff (O32, rejected).

R5. FR-006 during a headless run
- Decision: no new check. The tab run has the before/after snapshot in `st-codex-agent.sh`. The headless run uses the read-only sandbox, the same as the other points.
- Rationale: FR-006 says "the same as the other points". A user who changes files during a headless run is not caught today either. Stated as a finding in the report.

R6. Base for each form
- No argument: `git merge-base main HEAD`. No `main` (`git rev-parse --verify -q main` fails): stop and ask for the base.
- Base ref: passed as given; the script checks it is a commit.
- PR `#<n>`: `gh pr view <n> --json headRefName,headRefOid,baseRefOid`. Base = `git -C <worktree> merge-base <baseRefOid> HEAD`, the start of the PR's three-dot range. `baseRefOid` alone is wrong: a two-dot diff against the base tip shows base commits the branch lacks as reversed changes. When `baseRefOid` is not a local commit, stop and say to run `git fetch`.
- Form rule: an argument `#` plus digits is a PR number; any other first argument is a base ref. A second argument is the plan file.

R7. Worktree lookup for the PR form
- Decision: `git worktree list --porcelain`; match the line `branch refs/heads/<headRefName>`; then `git -C <worktree> rev-parse HEAD` must equal `headRefOid`.
- A detached worktree prints `detached`, not `branch`, so it never matches and gives the "no local worktree" stop.

R8. Codex tab for the PR form
- Fact: the tab name is per herdr workspace (`st-codex-<label>`). `st-codex-agent.sh` line 75 exits 5 when the tab's cwd is not the run folder. A PR review from the orchestrator runs in the worker's worktree, so when the workspace's tab already serves the main checkout the review falls back to headless (`Codex tab name ... in use elsewhere`). With no tab, the point makes one with the worktree as cwd; a later lane point in the main checkout then falls back the same way until the user closes it.
- Decision: no change. FR-004 lists this fallback. The skill runs the watch from the same folder as the point, since `watch` compares the tab's cwd with its own folder.

R9. CodeRabbit
- Installed: `coderabbit` 0.9.2. `review` flags used: `--agent` (structured findings), `--committed`, `--base-commit <commit>`. It keeps its state in `~/.coderabbit/` (`reviews/`, `logs/`), not in the repo, so it does not trip the tab snapshot.
- Help text: `--fresh` reviews "without reusing the previous local checkpoint". Decision D2 = A: add it, so each run covers the same whole range (FR-013). Command: `coderabbit review --agent --fresh --committed --base-commit <base>`.
- Decision D1 = B: the skill checks the mode file and `command -v codex` before it starts either reviewer. Mode `off`, mode not set or no `codex` stop the PR form with the script's own line, and CodeRabbit does not run. This matches the edge case "no review runs", and it does not use CodeRabbit quota before the mode question.
- The output format of `--agent` was not run (a live run sends code out). The record keeps the output as text.
- Who writes the section: the skill, with the Edit tool, after the Codex point ends. No script change. The point writes its own entry first, so the two never write at the same time.
- Which errors: any non-zero exit (not installed, not signed in, network, usage limit). The skill shows the first error line and says CodeRabbit did not run.

R10. Prompt handling in the tab
- Decision: the skill points to the Advisor section of `skills/st-build/SKILL.md` for the watch lines, the allow list and the output lines. No copy (`tests/test_advisor_rules.sh` pins the text there).

R11. Harness model
- `tests/test_harness_model.sh` finds `skills/st-advisor` and needs an element with that path, a place in one atlas structure, a datafile for the name `.stratum/advisor` (its regex stops at `/`), a valid model and a rebuilt `docs/harness/README.md`. `docs/harness/README.md` is generated and not on the caller's file list; the `rebuild` check needs it.
- CodeRabbit is not added as an actor: the test's actor list (`ACTORS`) is fixed. The skill summary names it.
