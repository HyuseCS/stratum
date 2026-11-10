# Contract: the commit form deny (US2, FR-004 to FR-007, D4, D6, D9)

## 1. The shared test

One function in `hooks/st-approve.py`, next to `SUBSTITUTION` (`:41`):

```text
unjudgeable(command) is true when a backslash followed by a newline is anywhere in the command (also inside quotes), or "<<" is in it, or SUBSTITUTION.search(command) matches.
```

The backslash-newline rule is D9 (stricter only): inside single quotes bash keeps both characters, so a joined form can name another file than the one bash stages. The other checks still also read the joined form (`JOIN` in `hooks/st-approve.py`: a backslash at a line end, not itself escaped, is removed with the line break), and the stricter result wins.

`SUBSTITUTION` stays as it is: `` ` ``, `$(`, `${` followed by whitespace or `|`, `<(`, `>(`. It matches inside quotes too. `<<` also covers `<<-` and `<<<`.

As FR-004 says, `${` counts only when a whitespace character or `|` follows it (`${ cmd; }`, `${| cmd; }`, the forms that run a command), which is what `SUBSTITUTION` matches. A plain `${VAR}` is not refused by either hook.

The guard loads the function from the file next to it, by real path:

```text
importlib.util.spec_from_file_location("st_approve", <dirname(realpath(__file__))>/st-approve.py)
```

It runs `exec_module` once at import. `st-approve.py` runs `main()` only under `__name__ == "__main__"`, so loading it has no side effect.

Fail closed: the load sits in `try`/`except Exception`. On a failure (file missing, syntax error, any exception) the guard keeps the error text, still exits 0, and still runs every rule it has today. In addition, when the command's unquoted text has a git word (`GIT_WORD`, `:13`), it notes `ask` with the reason `The git guard could not load hooks/st-approve.py (<ExceptionType>: <message>). Every git command asks until it loads.` A stronger decision of today's rules (`deny`) still wins through `RANK`. The form deny of §2 is skipped, since `unjudgeable` is not there; the commit then asks, so the user decides. A command with no git word gets no decision, as today.

Negative test (`tests/test_git_guard.py`): copy `hooks/st-git-guard.py` into a temp folder and put next to it (1) an `st-approve.py` with a syntax error, (2) no `st-approve.py`. For each: the guard exits 0; `git status` and `git commit -m "$(x)"` give `ask` with a reason that contains `The git guard could not load hooks/st-approve.py (` (contains, not starts with: today's rules may add their reasons first) and contains the error type: `SyntaxError` for (1), `FileNotFoundError` for (2); `git push --delete origin b` still gives `deny`; `echo hi` gives no decision.

D13: `commit_check` (`:194-195`) uses `unjudgeable(command)` in place of `SUBSTITUTION.search(HEREDOC_MESSAGE.sub("", command))`, and `HEREDOC_MESSAGE` (`:40`) is deleted. `COMMIT_NEVER` and every other check in `commit_check` stay. Then the guard denies exactly the commits the channel refuses for their form, and the channel only gets stricter.

## 2. Guard rule (`hooks/st-git-guard.py`)

Deny when both are true (research P3):

(a) The command has a `git commit` part:
- `check()` parsed a segment to sub `commit` (normal path `:305-306`, or fallback path `:341`). This covers `git`, a path to git (`/usr/bin/git`, basename rule of `parse_git`), the prefixes `command`, `builtin`, `exec`, env assignments (`FOO=1 git ...`), and options before the subcommand (`-C <dir>`, `-c k=v`, `--git-dir=...`) (CHK006).
- Or, on the fallback path, a line that the guard notes as unparseable (`:339`) or unreadable (`:343`) holds the word `commit`.

The scan of (a) runs on the raw command and on its joined form (§1), and the stricter decision wins.

(b) `unjudgeable(command)` on the whole raw command (§1).

Then the output is `permissionDecision: "deny"` with `permissionDecisionReason` exactly the deny text in §3, alone. Other reasons found for the same command are dropped from the output (the agent fixes the form first, and the next run shows any other reason). This holds for every commit mode (`auto`, `ask`, `deny`) and every session, worker or not (D6).

No deny under this rule when (a) or (b) is false. Then the guard decides as today.

## 3. Deny text (CHK009)

Exactly, on one line:

```text
Commit form denied: a commit with a heredoc, <<, a backtick, $( or a backslash line break cannot be judged by the approve channel. Run it again as git commit -m 'subject' -m 'body': single quotes, and no <<, backticks, $( or backslash line breaks anywhere, not even in the message. Write an apostrophe as '\''.
```

`agents/st-git.md` keys its retry on the prefix `Commit form denied:`.

## 4. Commit request (unchanged, FR-006)

For a plain `-m` commit in a worker in autonomous mode, `request()` (`hooks/st-approve.py:248-301`) writes `{"tool_name": "Bash", "tool_input": {"command": <full command>}, "time": ..., "branch": ..., "staged": [...]}`. `st-worker.sh wait` prints the `input`, `branch` and `staged` lines (`scripts/st-worker.sh:214-223`). No change. The other refusals stay and still send the dialog to the user (CHK007): `COMMIT_NEVER` (`cd`, `pushd`, `eval`, `sh -c`, `GIT_*=`), an option not in `COMMIT_VALUE_OPTS`/`COMMIT_FLAGS`/`ADD_FLAGS`, `-F -`, no owns file, a staged path outside owns, a branch that is not the guard file's branch, and the `NEVER` list (which holds `push`).

## 4b. The approve call (D17, FR-017)

D18: this change stands on its own. The orchestrator's approve call no longer carries the request text in a heredoc; it names the request by a hash, and the Bash description names the action. (The first reason given for D17, that the guard would deny the old heredoc call, was wrong: the rendered body `Bash: {"command":"..."}` is one quoted token to the guard and gives no decision. No test row covers the old call; IH5 shows `--input-stdin` is gone.)

- `scripts/st-worker.sh`: `approve <id> --request <rid> --input-hash <hash> --record <file> [--machine <m>]` replaces `--input-stdin`. `<hash>` must match `^[0-9a-f]{64}$`, else the usage line and exit 2. Nothing is read from stdin.
- `approval()` (`:214-223`, used by `wait` and `watch`): right after the `input` line, print `inputhash\t<hash>`, where `<hash>` is the full `sha256sum <<<"$in"` (64 hex) of the rendered request `in`.
- `approve` (`:675-680`): render the request again (`want`), keep the 4000-character check, and refuse with today's line `The input does not match request <rid>. Approve nothing.` when the 64-hex `sha256sum <<<"$want"` differs from `--input-hash`. The record line stays the same (it writes `want`).
- The full 64 hex is used, not 12: the worker writes the request text, so a short hash would let a worker search for a second request with the same hash.
- `skills/st-worker/SKILL.md:31`: the call becomes `bash <plugin root>/scripts/st-worker.sh approve <id> --request <rid> --input-hash <hash> --record <approvals file> [--machine <m>]`, with the hash from the `inputhash` line that `wait` or `watch` printed under that `input` line. The heredoc sentence goes. New sentence: `Name the approved action in short in the Bash description of that call: the tool and the command or path.` Row W3 of `tests/test_worker_rules.sh` follows.

Test cases (`tests/test_st_worker.sh`): every existing `approve ... --input-stdin <<'ST_INPUT_END'` call (the helper `apv` at `:1172` and its nine calls: eight `apv <<'ST_INPUT_END'` at `:1336`, `:1343`, `:1371`, `:1381`, `:1386`, `:1395`, `:1415`, `:1420`, and AP6 `apv < <(printf ...)` at `:1392`, which keeps its too-long line because the length check runs before the hash compare; plus the direct calls at `:1220`, `:1283`, `:1296`, `:1361`, `:1376`) becomes `--input-hash <the 64-hex sha256 of the expected rendered text>`, each case keeping its meaning (a text mismatch becomes a hash mismatch). New: IH1 `wait` on a request prints `inputhash` right after `input`, and its value equals `sha256sum` of the printed `input` text; IH2 `approve` with that hash writes `.ok` and the same record line as today; IH3 a hash of other text gives the mismatch line, exit 1, no `.ok`; IH4 a 12-hex or upper-case hash gives the usage line, exit 2; IH5 `--input-stdin` gives the usage line, exit 2.

## 4c. Why a commit was dropped (D20, FR-018)

Diagnostic only: nothing about what is approved or refused changes.

Hook (`hooks/st-approve.py`, `request()` and `commit_check()`), only in an autonomous worker session (where `request()` gets past its first checks today):
- When a Bash command that has a `git commit` part (the test at `:273`) gets no request, write one line to `<worker root>/.stratum/approve/dropped`, replacing the file: `<rule><TAB><detail><TAB><command>`. `<command>` is the command with every control character (newline included) replaced by `?`, cut to 300 characters. Write it with a temp file and `os.rename`, as the `.req` file is written.
- When the hook writes a `.req` file, it removes `dropped`, so a stale reason never sits next to a sent request.
- Rules and details, one per place that drops a commit today:

| Rule | Detail | Where today |
|------|--------|-------------|
| `never-list` | empty | `bash_ok` refuses the raw or the joined command (`request()` in `hooks/st-approve.py`), for a command with a `git commit` part |
| `commit-never` | empty | `COMMIT_NEVER` matches (`cd`, `pushd`, `eval`, `sh -c`, `GIT_*=`) (`:194`) |
| `unjudgeable` | empty | `unjudgeable(command)` (heredoc or substitution) (`:195`, after D13) |
| `git-word` | the word after `git` | a git part that is not `add` or `commit` (`:200-201`) |
| `flag` | the option | an option not in the lists, or `-F -` (`:206-226`) |
| `branch` | `<HEAD branch> vs <git-guard.json branch>` | no branch, no or bad guard file, or a mismatch (`:228-237`) |
| `owns-missing` | empty | the owns file is missing or empty (`:232-237`) |
| `outside-owns` | the first staged path not in owns | `staged <= owns` fails (`:243-244`) |
| `git-error` | empty | `git diff --cached` failed (`:239-240`) |

The write itself never raises: a failed write removes its temp file and is ignored, as `main()` already ignores errors.

Orchestrator (`scripts/st-worker.sh`, `st blocked`): when `wait` or `watch` reports a worker as `blocked` with no request (`approval()` found none), and `<worktree>/.stratum/approve/dropped` exists (on a saved machine, read with the existing `rsh` path), print right after the `state` line: `dropped<TAB><the file's first line>`, with every byte that is not printable or TAB removed, cut to 400 characters. No file: no line. Only a regular file is read: a symlink, a FIFO or a failed remote read gives no line. The script never writes or removes `dropped`. `skills/st-worker/SKILL.md` step 6 tells the orchestrator to include the `dropped` line when it brings to the user a dialog that shows the same command.

Test cases:
- `tests/test_approve_hook.py`: for each rule row above, one command in the commit setup that hits it gives no request and a `dropped` file whose first field is that rule (and, for `git-word`, `flag`, `outside-owns`, the detail). A plain `-m` commit that is sent leaves no `dropped` file, and removes one that was there. The approve and refuse results of every existing test stay as they are.
- `tests/test_st_worker.sh`: DR1 a blocked worker with a `dropped` file prints `dropped<TAB><line>` after the `state` line and before `pane text:`; DR2 no file, no `dropped` line; DR3 a line with an ESC byte prints without it; DR4 a remote worker (`rmk`, `--machine laptop`) prints the line from the saved machine; DR5 and DR6 a symlink and a FIFO as the file, DR7 and DR8 the same two on a saved machine, DR9 ssh fails at the read: each of DR5-DR9 gives exit 4 and no `dropped` line.

## 5. Test table

One table, `COMMIT_FORMS`, in `tests/test_approve_hook.py`. Each row runs through both hooks: the guard as a subprocess with the fixture root as `cwd` (as `tests/test_git_guard.py:33-46` does), and the channel as a `PermissionRequest` with the commit setup of `test_own_commit_is_sent_with_branch_and_staged`. `src/a.py` is staged and owned in every row.

| Row | Command | Guard | Channel |
|-----|---------|-------|---------|
| F1 | `git commit -m "$(cat <<'EOF'\nfeat: x\n\nbody\nEOF\n)"` | deny, §3 text | refused (D13; sent today) |
| F2 | same as F1 with body `feat: say "hi` (one `"`: the guard cannot parse the command or its first line; today it gives `ask` with `The git guard could not parse the command.`) | deny, §3 text | refused (D13; sent today) |
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
| H2 | `cat > a.md <<'EOF'\ngit commit -m x\nEOF` | deny, §3 text. Accepted over-match (research P3): a heredoc body line that reads `git commit` counts as a commit; files are written with Write or Edit. | refused |
| N1 | `cat > a.txt <<'EOF'\nhello\nEOF` | no decision | not a commit |
| N2 | `python3 - <<'PY'\nprint(1)\nPY` | no decision | not a commit |
| N3 | `echo "git commit -m x <<EOF"` | no decision | not a commit |
| N4 | `git push` | `ask`, reason `git push sends commits to the remote.` | refused (`NEVER`) (FR-007) |

D13: for every F, H2 and P row the test asserts both ways: the guard denies with the §3 text if and only if the channel sends no request. One more assertion ties the two hooks to one check: `unjudgeable(row)` from the loaded `hooks/st-approve.py` is true exactly for the F and H2 rows. N rows check their own lines only (no commit, or `push`).

Existing approve cases that change with D13: `OWN_COMMITS` row `:87` (the `$(cat <<'EOF'` message) moves to `REFUSED_COMMITS`; `test_source_edit_and_unsplittable_commit_are_sent` (`:420-433`), subtest "heredoc with it's and a git commit last", now expects silent. Keep every other assertion.

Guard-only cases in `tests/test_git_guard.py` (the guard needs no worker setup):
- F1-F9 deny with the §3 text exactly, in commit modes `auto`, `ask` and `deny`, and with no `.stratum` folder at all (any session).
- `/usr/bin/git commit -m "$(x)"`, `command git commit -m "$(x)"`, `FOO=1 git commit -m "$(x)"`, `git -c a.b=c commit -m "$(x)"`: deny.
- P1-P4: the decision is the one of today (`None` in `auto`, `ask` in `ask`).
- N1-N3: no decision. N4: `ask`.
- Existing cases that flip to the §3 deny: `test_stray_quote_commit_asks` (`:313`, `cat > t.txt <<EOF ... git commit -m x`) and `test_quoted_heredoc_commit_opener_judged` (`:395-397`, `git commit -F - <<'EOF'`) and `test_stray_quote_python_heredoc_git_line_asks` (`:362-367`, `python3 - <<'PY'` with a `subprocess.run(["git", "commit", ...])` body line, a hidden commit). Change only their expected decision and reason.
