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
5. Path. Count commits with `git rev-list --count origin/<base>..HEAD` and files with
   `git diff --name-only origin/<base>...HEAD | wc -l`. Ultracode is on when the latest system-reminder about Ultracode says so.
   Take the workflow path only when Ultracode is on and the branch has more than 30 commits or more than 40 changed files.
   Else take the current path: steps 2 to 4.
   Say the path in one line, with both counts and the Ultracode state, for example
   `Path: workflow. Ultracode on, 45 commits (more than 30), 12 files (not more than 40).` or
   `Path: current. Ultracode off, 100 commits, 3 files.`

## Workflow path

Only when step 1 chose it. It replaces steps 2 to 4. Steps 5 and 6 run as written.

1. Note the output of `git rev-parse HEAD` and `git status --porcelain --untracked-files=all`.
2. Call `Workflow({scriptPath: "<plugin root>/workflows/pr.js", args})`. Pass `args` as a JSON object, not a string:
   `projectRoot`, `pluginRoot` and `scratchpad` (absolute paths), `base`, `branch`, `featureDir`
   (the project root joined with the `feature_directory` from `.stratum/state.json`, or `""`), and `commits` (the lines
   of `git log origin/<base>..HEAD --format='%h %s'`, as an array of strings).
   If the tool refuses the `scriptPath` ("a file you can already read"), read `<plugin root>/workflows/pr.js` and call `Workflow` again: pass the file's text through the tool's `script` input, with the same `args`.
3. The workflow runs in the background: wait for its task notification. If the tool result already holds the result object, use it. Never start a second run while one runs.
4. Run the two commands from 1 again. If an output differs, show the difference and stop before the gate.
5. `blocked` is true: show the warnings and stop before the gate. Nothing is pushed.
6. A refused `scriptPath` goes to the `script` call of 2 first. If the call cannot start, the run fails, or it returns no `bodyPath`: say so in one line, then run steps 2 to 4 on the current path.
7. Else read the body at `bodyPath` and go to step 5 with the returned `title` and `warnings`.
   Revise at the gate edits the body in this session and never runs the workflow again.

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
