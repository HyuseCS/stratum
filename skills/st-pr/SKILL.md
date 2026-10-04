---
name: st-pr
description: Open a pull request for the current branch. Facts from git and the feature's spec, one gate, then a draft PR that becomes ready when CI passes.
---

# /stratum:st-pr [base]

Plugin root (`<plugin root>`) is two levels up from this skill's base directory.
Nothing is posted to GitHub before the gate in step 5. `gh pr create` cannot be undone.

## 1. Scope

1. Base: `[base]`, or the repo default (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).
2. `git fetch origin <base> && git rev-parse --verify origin/<base>`. If it fails, ask the user
   which base they meant, offering the closest names from `git branch -r`.
3. Stop and tell the user when the current branch is the base, or
   `git log origin/<base>..HEAD` is empty.
4. `gh pr list --head <branch> --state all --json number,state,url,baseRefName`. If a PR exists,
   ask the user:
   - open PR: update it in place (recommended) or close it and open a new one;
   - closed PR: reopen it and rewrite its body (keeps review threads) or open a new one.

## 2. Facts

Derive every fact with a command or a file. Never from memory.

- Commits: `git log origin/<base>..HEAD --format='%h %s'`.
- Files: `git diff origin/<base>...HEAD --name-status`. Trust the `A`/`M`/`D` letter; a deleted
  file is a deletion, not a big change.
- Feature: if `<project>/.stratum/state.json` has a `feature_directory`, read its `spec.md`
  (FRs), `tasks.md` (ticked tasks) and `quickstart.md` (test steps). An FR counts as delivered
  only when its tasks are ticked and their files are in the diff.
- Commit subjects that do not describe their diff: note them for the body.

## 3. Draft

Template, first found: `.github/PULL_REQUEST_TEMPLATE.md` (any case, or under `.github/` or
`docs/`), `<project>/.stratum/templates/pr.md`, `<plugin root>/templates/pr.md`.

Fill every section into `<scratchpad>/pr-body.md`. Title under 70 characters, from the feature or
the change, never from a commit subject flagged in step 2. No AI attribution in title or body.

## 4. Verify the draft

Read the file back. Check each named path exists at HEAD with the letter the body implies, each
FR claim against step 2, and each command against the project's scripts. Cut a claim you cannot
confirm, or mark it unverified under Notes.

## 5. Gate

Show: the body in full, the title, the base, what happens to an existing PR, and the warnings
(flagged subjects, unverified claims). Then ask one question: **Approve**, **Revise**, or
**Abort**. Revise goes back to the step the objection points to. On no answer, leave the file,
say where it is, and stop.

## 6. Create

1. Push: `git push -u origin <branch>`. Then `git fetch origin <branch>` and
   `git rev-parse HEAD origin/<branch>`. If the two hashes differ, stop and report. Never force.
2. Create, by the step 1 answer:
   - new: `gh pr create --draft --base <base> --title "<title>" --body-file <scratchpad>/pr-body.md`
   - update: `gh pr edit <n> --title "<title>" --body-file <scratchpad>/pr-body.md`
   - reopen: `gh pr reopen <n>`, then the update command.
   No CI workflow on pull requests in `.github/workflows/`: create without `--draft` and skip 3.
   Update and reopen keep the PR's current draft state; report the checks without changing it.
3. Wait for CI in one background Bash call:
   ```bash
   for i in $(seq 45); do
     out=$(gh pr checks <n> --json name,bucket,link 2>/dev/null)
     case "$out" in ''|'[]'|*'"pending"'*) sleep 20 ;; *) break ;; esac
   done
   echo "$out"
   ```
   Every check `pass` or `skipping`: `gh pr ready <n>`. Any `fail` or `cancel`, or no checks after
   the wait: keep the draft. Do not fix code here.

## 7. Report

PR URL, base, draft or ready, each failed check with its link, what the PR includes in two
lines, and the warnings from the gate.

## Always

- Never skip the commit guard. If a push is blocked, tell the user; do not work around it.
