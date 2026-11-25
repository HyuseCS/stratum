The advisor is Codex (the `codex` CLI), a model from another vendor. In mode `auto` the risk level picks the advisors at each point:

| Point | high | normal | low | none |
|-------|------|--------|-----|------|
| plan before the Plan gate (`st-plan` step 4, stale-checked at the build gate by `st-inspect`) | both | Codex | none | none |
| test red after 2 tries | Codex, then both if still red | Codex | `/advisor` | none |
| story small decisions | both | Codex | `/advisor` | none |
| diff at the end of Build | both | Codex | `/advisor` | none |
| Fast-lane change plan before its gate (`st-fast` step 2) | both | Codex | none | none |

The other Fast-lane points use `/advisor`. The Quick lane has no advisor.

- Start `bash <plugin root>/scripts/st-advisor.sh watch` with the Monitor tool, then run `bash <plugin root>/scripts/st-advisor.sh <point> ...` with Bash `run_in_background`, both from the project root (a worktree's root for the test point of a `[P]` task). Change no file in that folder and run no `st-git` until the point ends. When it ends, stop the watch and handle the point's output. If the Monitor expires before the point ends, start the watch again.
- Codex only reviews: it never creates, changes or deletes a file, and never builds or fixes anything. The user may use the Codex tab for their own work.
- Never run `codex` to build or fix. In herdr, Codex runs as the `st-codex-<workspace label>` agent (in a worker, `st-codex-worker-<id>`, in the worker's own workspace) in the `Codex` tab of this workspace, with the user's own Codex setup, and the user can watch it there. Otherwise it runs in the background in the read-only sandbox. The last line says which: `codex: tab st-codex-<workspace label>` (`st-codex-worker-<id>` in a worker) or `codex: headless (<reason>)`. Show it to the user.
- On a `codex tab waits:` line, read the screen lines after it. A prompt on the allow list: answer it with `bash <plugin root>/scripts/st-advisor.sh answer --screen <hash> --keys <key>`. Pass the hash from that `codex tab waits:` line, and the key of the one-time yes only ("Yes, proceed", "Yes, just this once"). Never pick an option that says "don't ask again", "allow ... for this session", "in the future" or "for these files", or one that names a host. Every other prompt: show the user the exact screen lines and leave the tab open. On `the Codex tab shows another prompt`, send nothing more: the watch prints the new screen in its own block.
  Allow list: read a file or list a folder anywhere, except a `.env` file or a key, credential, token or other secret file; run one command only, with no `;`, `&&`, `||`, `|`, `$(` or backticks: `git log`, `git diff`, `git show`, `git status`, `git blame`, `ls`, `cat`, `head`, `tail`, `wc`, `grep`, `rg` or `find`, with no `>`, `>>`, `tee`, `--output`, `--pre`, `-fprint`, `-fprint0`, `-fprintf`, `-fls`, `-delete`, `-exec`, `-execdir`, `-ok` or `-okdir`; or the project's test or lint command with no `--fix`, `--write`, `-w`, `-u` or `--update-snapshots`. Also no `VAR=` before the command, no option between `git` and its subcommand (`-c`, `--config-env`, `--exec-path`), no `--ext-diff`. Allow the test or lint command only when the project has no changed or new file since the point started. Else the prompt goes to the user.
  Never approve a file write, move or delete, a git change (`commit`, `checkout`, `switch`, `reset`, `restore`, `stash`, `add`, `rm`, `mv`, `merge`, `rebase`, `pull`, `fetch`, `push`, `tag`, `branch`, `clean`, `apply`, `am`), an install, network use, a `.env` file or secret, or a change to Codex settings or folder trust.
- `no advisor: codex not found` or `no advisor: mode off`: go on as before; consult `/advisor` only if the user set one.
- `no advisor: mode not set`: stop. Ask the user the advisor question of `/stratum:st-init` step 11, write the answer to `"$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/advisor.json"`, then run the point again.
- First line `mode both: also consult /advisor if one is set`: after Codex, consult `/advisor` on the same input if one is set.
- `advisors: codex`: Codex runs. `advisors: both`: Codex runs, then consult `/advisor` on the same input, then hold the talk. `advisors: /advisor`: consult `/advisor` only. `advisors: none`: no advisor at this point, and skip `check plan`.
- At a High point both advisors first answer alone. Then hold the talk: at most 3 rounds of `bash <plugin root>/scripts/st-advisor.sh round <point> <feature dir> <n> <views file>`, each with `/advisor`'s answer to the same views.
  In round 3 each advisor proposes a compromise for every open point. A compromise both accept is a combined finding. A point with no compromise both accept goes to the user with both views, in short, simple words.
  If one advisor has no answer (`no advisor`, mode off), the point runs with the one left, and the talk record says so.
  After the talk, record it: `bash <plugin root>/scripts/st-advisor.sh talk <point> <feature dir> <file>` with the rounds, the agreed points, the compromises, the points sent to the user and the calls.
  A BLOCKED round ends the talk: send the open points to the user, do not run `continued`.
- `APPROVED`: go on.
- `WAIVED sha256 <hash>`: the plan changed only by fixes, and `check plan` passes until the input changes again.
- `codex: the Codex tab runs with ...`: show the line to the user word for word. The tab keeps its old values until the user closes it.
- `REVISE`: handle each finding like a review finding: check it against the source, fix the real small ones, bring big ones to the user, drop the false ones.
  A `REVISE` with only MEDIUM and LOW findings counts as passed: handle each finding and do not run the point again.
  Run the point again only when a CRITICAL or HIGH fix changed the plan, or the plan's approach changed.
  The approach changed when a user story or task was added or removed, a file outside the plan's file list is now touched, or a design choice in `plan.md` was replaced. A fix inside a task's own text and files is not an approach change.
  Two rounds at most per point per gate pass, then the user decides. A later gate pass starts a new count.
- `no change since <base>: skip`: nothing changed after the last review, so the pass is skipped.
- After each `/advisor` call, run `bash <plugin root>/scripts/st-advisor.sh note <point> <feature dir> "<one-line summary>"`.
- `BLOCKED: Codex changed files during the review: <paths>` or `BLOCKED: files or HEAD changed during the review: <paths>`: show the paths. Revert nothing. The user checks them with `git diff` and keeps or reverts them, then says run the point again or continue (`continued`).
- `BLOCKED: the Codex tab ended during the review` or `BLOCKED: the Codex tab failed during the review: ...`: show the line. A review in the tab has no time limit; it ends early only this way. Run the point again on the user's word, or `continued`. To stop a hung review, the user presses Esc in the tab or tells you to stop the point.
- `BLOCKED: <reason>`: stop and show the user the reason. Nothing passes the gate. If the user says to continue, run `bash <plugin root>/scripts/st-advisor.sh continued <point> <feature dir>` and skip the point. Do not retry it in this gate pass.
- Each run appends a record to `<feature dir>/advisor.md`: the point, the time, the SHA256 of the input, the verdict and the findings. The mode comes from `.stratum/advisor.json`: `auto` (the default when the file has no `mode`), `codex`, `both` or `off`. A worktree with no file reads the main checkout's file. No file in either gives the `mode not set` line.
- At the build gate, `check plan` compares the latest plan record with the current input. `advisor approval is stale` or `no record` counts as no approval: run the plan point once more, as a round. Skip the check after a `no advisor` line.
- Exit 2 with a `usage:` line or `cannot hash inputs`: the script could not read or hash its inputs. Nothing was recorded and nothing was sent. Fix the input or the tool and run the point again.
