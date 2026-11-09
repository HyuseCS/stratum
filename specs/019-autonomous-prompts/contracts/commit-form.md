# Contract: the commit form deny (US2, FR-004 to FR-007, D4, D6, D9)

## 1. The shared test

One function in `hooks/st-approve.py`, next to `SUBSTITUTION` (`:41`):

```text
unjudgeable(command) is true when "<<" is in command, or SUBSTITUTION.search(command) matches.
```

`SUBSTITUTION` stays as it is: `` ` ``, `$(`, `${` followed by a space or `|`, `<(`, `>(`. It matches inside quotes too. `<<` also covers `<<-` and `<<<`.

As FR-004 says, `${` counts only when a whitespace character or `|` follows it (`${ cmd; }`, `${| cmd; }`, the forms that run a command), which is what `SUBSTITUTION` matches. A plain `${VAR}` is not refused by either hook.

The guard loads the function from the file next to it, by real path:

```text
importlib.util.spec_from_file_location("st_approve", <dirname(realpath(__file__))>/st-approve.py)
```

It runs `exec_module` once at import. `st-approve.py` runs `main()` only under `__name__ == "__main__"`, so loading it has no side effect.

Fail closed: the load sits in `try`/`except Exception`. On a failure (file missing, syntax error, any exception) the guard keeps the error text, still exits 0, and still runs every rule it has today. In addition, when the command's unquoted text has a git word (`GIT_WORD`, `:13`), it notes `ask` with the reason `The git guard could not load hooks/st-approve.py (<ExceptionType>: <message>). Every git command asks until it loads.` A stronger decision of today's rules (`deny`) still wins through `RANK`. The form deny of §2 is skipped, since `unjudgeable` is not there; the commit then asks, so the user decides. A command with no git word gets no decision, as today.

Negative test (`tests/test_git_guard.py`): copy `hooks/st-git-guard.py` into a temp folder and put next to it (1) an `st-approve.py` with a syntax error, (2) no `st-approve.py`. For each: the guard exits 0; `git status` and `git commit -m "$(x)"` give `ask` with a reason that starts `The git guard could not load hooks/st-approve.py (`; `git push --delete origin b` still gives `deny`; `echo hi` gives no decision.

D13: `commit_check` (`:194-195`) uses `unjudgeable(command)` in place of `SUBSTITUTION.search(HEREDOC_MESSAGE.sub("", command))`, and `HEREDOC_MESSAGE` (`:40`) is deleted. `COMMIT_NEVER` and every other check in `commit_check` stay. Then the guard denies exactly the commits the channel refuses for their form, and the channel only gets stricter.

## 2. Guard rule (`hooks/st-git-guard.py`)

Deny when both are true (research P3):

(a) The command has a `git commit` part:
- `check()` parsed a segment to sub `commit` (normal path `:305-306`, or fallback path `:341`). This covers `git`, a path to git (`/usr/bin/git`, basename rule of `parse_git`), the prefixes `command`, `builtin`, `exec`, env assignments (`FOO=1 git ...`), and options before the subcommand (`-C <dir>`, `-c k=v`, `--git-dir=...`) (CHK006).
- Or, on the fallback path, a line that the guard notes as unparseable (`:339`) or unreadable (`:343`) holds the word `commit`.

(b) `unjudgeable(command)` on the whole raw command.

Then the output is `permissionDecision: "deny"` with `permissionDecisionReason` exactly the deny text in §3, alone. Other reasons found for the same command are dropped from the output (the agent fixes the form first, and the next run shows any other reason). This holds for every commit mode (`auto`, `ask`, `deny`) and every session, worker or not (D6).

No deny under this rule when (a) or (b) is false. Then the guard decides as today.

## 3. Deny text (CHK009)

Exactly, on one line:

```text
Commit form denied: a commit with a heredoc, a backtick or $( cannot be judged by the approve channel. Run it again as git commit -m 'subject' -m 'body': single quotes, no heredoc, no backticks, no $(. Write an apostrophe as '\''.
```

`agents/st-git.md` keys its retry on the prefix `Commit form denied:`.

## 4. Commit request (unchanged, FR-006)

For a plain `-m` commit in a worker in autonomous mode, `request()` (`hooks/st-approve.py:248-301`) writes `{"tool_name": "Bash", "tool_input": {"command": <full command>}, "time": ..., "branch": ..., "staged": [...]}`. `st-worker.sh wait` prints the `input`, `branch` and `staged` lines (`scripts/st-worker.sh:214-223`). No change. The other refusals stay and still send the dialog to the user (CHK007): `COMMIT_NEVER` (`cd`, `pushd`, `eval`, `sh -c`, `GIT_*=`), an option not in `COMMIT_VALUE_OPTS`/`COMMIT_FLAGS`/`ADD_FLAGS`, `-F -`, no owns file, a staged path outside owns, a branch that is not the guard file's branch, and the `NEVER` list (which holds `push`).

## 5. Test table

One table, `COMMIT_FORMS`, in `tests/test_approve_hook.py`. Each row runs through both hooks: the guard as a subprocess with the fixture root as `cwd` (as `tests/test_git_guard.py:33-46` does), and the channel as a `PermissionRequest` with the commit setup of `test_own_commit_is_sent_with_branch_and_staged`. `src/a.py` is staged and owned in every row.

| Row | Command | Guard | Channel |
|-----|---------|-------|---------|
| F1 | `git commit -m "$(cat <<'EOF'\nfeat: x\n\nbody\nEOF\n)"` | deny, §3 text | refused (D13; sent today) |
| F2 | same as F1 with body `feat: say "hi` (one `"`: the guard cannot parse the command or its first line; today it gives `ask` with `The git guard could not parse the command.`) | deny, §3 text | refused (today too) |
| F3 | `git commit -F - <<'EOF'\nfix it\nEOF` | deny | refused |
| F4 | `git commit -m "$(echo m)"` | deny | refused |
| F5 | ``git commit -m 'use `x` here'`` | deny | refused |
| F6 | `git commit -m "${ echo m; }"` | deny | refused |
| F7 | `git commit -F <(echo m)` | deny | refused |
| F8 | `git commit -m 'a' -m 'b' > >(cat)` | deny | refused |
| F9 | `git add src/a.py && git -C . commit -m "$(echo m)"` | deny | refused |
| F10 | `cat > n.txt <<'EOF'\nnote\nEOF\ngit commit -m x` | deny | refused (D13; sent today) |
| P1 | `git commit -m 'feat(a): b' -m 'why it changed'` | not denied by this rule | sent: `tool_input.command` equals the row, `branch` `worker-t1`, `staged` `["src/a.py"]` |
| P2 | `git commit -m 'subject' -m 'line one\nline two'` (a real newline inside the quotes) | not denied | sent, full command |
| P3 | `git commit -m 'it'\''s fine'` | not denied | sent |
| P4 | `git add src/a.py && git commit -m "fix: b"` | not denied | sent |
| N1 | `cat > a.txt <<'EOF'\nhello\nEOF` | no decision | not a commit |
| N2 | `python3 - <<'PY'\nprint(1)\nPY` | no decision | not a commit |
| N3 | `echo "git commit -m x <<EOF"` | no decision | not a commit |
| N4 | `git push` | `ask`, reason `git push sends commits to the remote.` | refused (`NEVER`) (FR-007) |

D13: for every F and P row the test asserts both ways: the guard denies with the §3 text if and only if the channel sends no request. One more assertion ties the two hooks to one check: `unjudgeable(row)` from the loaded `hooks/st-approve.py` is true exactly for the F rows. N rows check their own lines only (no commit, or `push`).

Existing approve cases that change with D13: `OWN_COMMITS` row `:87` (the `$(cat <<'EOF'` message) moves to `REFUSED_COMMITS`; `test_source_edit_and_unsplittable_commit_are_sent` (`:420-433`), subtest "heredoc with it's and a git commit last", now expects silent. Keep every other assertion.

Guard-only cases in `tests/test_git_guard.py` (the guard needs no worker setup):
- F1-F9 deny with the §3 text exactly, in commit modes `auto`, `ask` and `deny`, and with no `.stratum` folder at all (any session).
- `/usr/bin/git commit -m "$(x)"`, `command git commit -m "$(x)"`, `FOO=1 git commit -m "$(x)"`, `git -c a.b=c commit -m "$(x)"`: deny.
- P1-P4: the decision is the one of today (`None` in `auto`, `ask` in `ask`).
- N1-N3: no decision. N4: `ask`.
- Existing cases that flip to the §3 deny: `test_stray_quote_commit_asks` (`:313`, `cat > t.txt <<EOF ... git commit -m x`) and `test_quoted_heredoc_commit_opener_judged` (`:395-397`, `git commit -F - <<'EOF'`). Change only their expected decision and reason.
