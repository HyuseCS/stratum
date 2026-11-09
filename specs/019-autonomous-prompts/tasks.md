---
description: "Tasks for 019-autonomous-prompts"
---

# Tasks: The orchestrator sees and answers every worker prompt in autonomous mode

**Input**: `specs/019-autonomous-prompts/` (plan.md, spec.md, decisions.md D2-D9, D13, D14, research.md, data-model.md, contracts/, quickstart.md)

**Tests**: required (FR-014). Each FR gets a test task in the phase before the task that builds it. A test task's new cases must fail before its build task and pass after.

**Organization**: each user story has a test phase and a build phase, so the tasks inside one phase can run at the same time.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

## Rules for every task

- Work only in temp folders in tests (`mktemp -d`, `tempfile.TemporaryDirectory`). Every Codex test sets `CODEX_HOME` to a temp folder before its first call, so no test reads `~/.codex`.
- This build runs in worker worktrees. Lock 2 and the approve `NEVER` list act on Bash text: no Bash command may name `.stratum/approve`, `.stratum/autonomous`, `.claude` or `.env`, or run `st-worker.sh` with `approve`, `pass`, `wait`, `watch`, `start`, `resend`, `followup`, `autonomous-on` or `autonomous-off`. Run the test files only.
- Commit with `git commit -m 'subject' -m 'body'`: no heredoc, no backticks, no `$(`.
- Change an existing test only where this feature changes its expected result (each task names those cases). Keep every other assertion.
- No new file under `hooks/` or `scripts/` (plan.md, Structure Decision). No comments that narrate the change. Keep existing `ponytail:` notes unless the task says to remove one.

---

## Phase 1: User Story 1 tests (answer a dialog on a busy screen)

**Goal**: failing tests for the dialog block (FR-001, FR-002, FR-003, FR-014) and for the hash-based approve call (FR-017, D17). D17 sits in US1 because US1 owns `scripts/st-worker.sh` and merges first (D18: it stands on its own).

**Independent Test**: a dialog in a stub worker pane while lines above it change gets its one-time answer with the hash from `wait`; a change inside the dialog is refused.

- [ ] T001 [P] [US1] In `tests/test_st_worker.sh`, add cases DB1-DB11 of `contracts/dialog-block.md` §4, with the `REAL` pane of that section as a fixture (its top rule is 40 `─`, U+2500; its box lines are 40 `╌`, U+254C). DB1: the `screen` hash is the first 12 hex of `sha256sum` of the 12 block lines, the `─` rule through ` 4. No`. DB2 and DB6: answer sent (exit 0, `agent	send-keys	worker-t004	1`). DB3, DB4, DB5: exit 1, `The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt.`, nothing sent. DB7 and DB8 (mode `cut`, D15): `wait` exits 4 with one `screen` line whose hash is the first 12 hex of `sha256sum` of the printed 40-line pane text; `answer --screen <hash> --keys 1` exits 1 with exactly `The top of the dialog is not on the screen, so only its No can be sent. Nothing sent. Tell the user the workspace, the tab and the prompt.`, nothing sent; DB7b and DB8 `--keys 4` (`No`) exit 0, key 4 sent; DB7c, a changed transcript line inside the 40 lines, refuses the No with the another-prompt line. DB9: `wait` prints no `screen` line, and `answer --screen 0123456789ab --keys 4` gives the another-prompt line, nothing sent. DB10: `watch --roster` prints the same `screen` hash as DB1. DB11: keys 2 and 3 refused with `Option <k> is not a one-time yes. ...`, key 4 sent. Existing cases (`:1433-1557`): add one 40-character `─` line as the first dialog line of every AN fixture (above `Bash command`, `Read file` or the HEAD line). AN6f (two HEAD lines): expect no `screen` line from `wait`, then `answer --screen 0123456789ab --keys 2` gives exit 1, the another-prompt line, nothing sent. AN9b: expect the hash of the block lines, keep its `line 5` check. AN11b: expect exit 0 and key 1 sent (the changed line is outside the block). NO1-NO3 (`:1509-1519`): do not change their fixtures or expectations; they must still pass (mode `cut`). D17 (FR-017), per `contracts/commit-form.md` §4b: change every `approve ... --input-stdin` call to `--input-hash <hash>`: the helper `apv` at `:1172` and its nine calls (eight `apv <<'ST_INPUT_END'` at `:1336`, `:1343`, `:1371`, `:1381`, `:1386`, `:1395`, `:1415`, `:1420`, and AP6 `apv < <(printf ...)` at `:1392`, which keeps its too-long line), and the direct calls at `:1220`, `:1283`, `:1296`, `:1361`, `:1376`, where `<hash>` is the 64-hex `sha256sum` of the text the old heredoc held, so each case keeps its meaning (a text mismatch becomes a hash mismatch); add IH1-IH5 (IH1 `wait` prints `inputhash` right after `input` with the `sha256sum` of the printed `input` text; IH2 `approve` with it writes `.ok` and today's record line; IH3 another hash gives `The input does not match request <rid>. Approve nothing.`, exit 1, no `.ok`; IH4 a 12-hex or upper-case hash and IH5 `--input-stdin` give the usage line, exit 2). In `tests/test_worker_rules.sh` row W3, replace the old call and the heredoc sentence with the §4b text of `skills/st-worker/SKILL.md:31`. Owns: `tests/test_st_worker.sh`, `tests/test_worker_rules.sh`. Test: bash tests/test_st_worker.sh && bash tests/test_worker_rules.sh.

**Checkpoint**: DB1-DB11 and the changed AN6f, AN9b and AN11b fail on the current code. NO1-NO3 pass before and after.

---

## Phase 2: User Story 1 build

- [X] T002 [P] [US1] In `scripts/st-worker.sh`, add one function that computes the mode and the hash `SH` from `SC` per `contracts/dialog-block.md` §1: window = the last 15 lines; exactly one `HEAD` line in it (`:168`), else mode none; end = the last line after HEAD matching `^([[:space:]]|│)*(❯[[:space:]]*)?[0-9]+\.[[:space:]]`, extended over the following non-blank lines, else mode none; top rule = the last line above HEAD matching `^[[:space:]]*(─)+[[:space:]]*$`: found gives mode `block` with `SH` = first 12 hex of `sha256sum <<<"$DB"` (lines rule to end); not found gives mode `cut` with `SH` = first 12 hex of `sha256sum <<<"$SC"` (today's whole-screen hash, D15). `screen()` (`:170`) keeps the 40-line read and stops setting `SH`. `st blocked` (`:161`) prints `screen\t<SH>` when the read worked, `perm` is true and the mode is `block` or `cut`. In `answer` (`:452-467`), per §3: mode none or `SH` not equal to `--screen` gives the existing another-prompt line (remove the `ponytail:` comment on that line, this change is its upgrade); the key and allow-list checks stay unchanged; then, in mode `cut`, an option that passed the yes part of the allow list (not the No part) gives `The top of the dialog is not on the screen, so only its No can be sent. Nothing sent. Tell the user the workspace, the tab and the prompt.` and exit 1. D17 (FR-017), per `contracts/commit-form.md` §4b: replace the `approve --input-stdin` flag (`:13`, `:17`, the usage line `:3`, the check at `:52`, the stdin read at `:75-78`) with `approve --input-hash <hash>`, `<hash>` matching `^[0-9a-f]{64}$`, else usage and exit 2; in `approval()` (`:219`) print `inputhash\t<64-hex sha256sum <<<"$in">` right after the `input` line; in `approve` (`:678-680`) keep the render and the 4000-character check, and refuse with today's mismatch line when the 64-hex `sha256sum <<<"$want"` differs from `--input-hash`; the record line stays. In `skills/st-worker/SKILL.md:31`, change the call to `bash <plugin root>/scripts/st-worker.sh approve <id> --request <rid> --input-hash <hash> --record <approvals file> [--machine <m>]`, with the hash from the `inputhash` line that `wait` or `watch` printed under that `input` line; drop the heredoc sentence; add `Name the approved action in short in the Bash description of that call: the tool and the command or path.` Owns: `scripts/st-worker.sh`, `skills/st-worker/SKILL.md`. Test: bash tests/test_st_worker.sh && bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_on_demand.sh && bash tests/test_state.sh.

**Checkpoint**: US1 works. MVP.

---

## Phase 3: User Story 2 tests (every worker commit reaches the orchestrator)

**Goal**: failing tests for the guard deny and the shared check (FR-004 to FR-007, FR-014), and for the `dropped` line the hook writes (FR-018, D20).

**Independent Test**: heredoc and `$(` commits are denied with the fixed reason in any session; plain `-m` commits are not denied by this rule and reach the approve channel with the full command, the branch and the staged files.

- [ ] T003 [P] [US2] In `tests/test_git_guard.py`, add the guard-only cases of `contracts/commit-form.md` §5: rows F1-F9 give `deny` with the reason exactly `Commit form denied: a commit with a heredoc, a backtick or $( cannot be judged by the approve channel. Run it again as git commit -m 'subject' -m 'body': single quotes, no heredoc, no backticks, no $(. Write an apostrophe as '\''.`, in commit modes `auto`, `ask` and `deny`, and in a repo with no `.stratum` folder; `/usr/bin/git commit -m "$(x)"`, `command git commit -m "$(x)"`, `FOO=1 git commit -m "$(x)"`, `git -c a.b=c commit -m "$(x)"` give that deny; row H2 (`cat > a.md <<'EOF'` with a `git commit -m x` body line, an accepted over-match) gives that deny; rows P1-P4 keep today's decision (`None` in `auto`, `ask` in `ask`); N1-N3 give no decision; N4 (`git push`) gives `ask` with `git push sends commits to the remote.`. Change `test_stray_quote_commit_asks` (`:313`) and `test_quoted_heredoc_commit_opener_judged` (`:395-397`) to expect that deny and reason. Add the fail-closed negative test of `contracts/commit-form.md` §1: copy `hooks/st-git-guard.py` into a temp folder, next to it (1) an `st-approve.py` with a syntax error, (2) no `st-approve.py`; for each, the guard exits 0, `git status` and `git commit -m "$(x)"` give `ask` with a reason that contains `The git guard could not load hooks/st-approve.py (` and contains `SyntaxError` for (1) and `FileNotFoundError` for (2) (contains, not starts with: other reasons of today's rules may come first in the joined reason), `git push --delete origin b` gives `deny`, and `echo hi` gives no decision. Owns: `tests/test_git_guard.py`. Test: python3 tests/test_git_guard.py.
- [ ] T004 [P] [US2] In `tests/test_approve_hook.py`, add the table `COMMIT_FORMS` with rows F1-F10, H2, P1-P4 and N1-N4 of `contracts/commit-form.md` §5 and one test that runs each row through both hooks: the guard (`hooks/st-git-guard.py`) as a subprocess with the commit-setup root as `cwd` and payload `{"tool_name": "Bash", "cwd": <root>, "tool_input": {"command": <row>}}`, and the channel as a `PermissionRequest` after `commit_setup()` with `src/a.py` staged. For every F, H2 and P row assert both ways: the guard denies with the exact §3 reason if and only if the channel sends no request (D13). For P1-P4 also assert the request's `tool_input.command` equals the row, `branch` is `worker-t1` and `staged` is `["src/a.py"]` (FR-006). N4: guard `ask`, channel silent (FR-007). Load `hooks/st-approve.py` with `importlib.util.spec_from_file_location` and assert `unjudgeable(row)` is true for every F and H2 row and false for every P row. Move the `OWN_COMMITS` row at `:87` (the `$(cat <<'EOF'` message) to `REFUSED_COMMITS`. In `test_source_edit_and_unsplittable_commit_are_sent` (`:420-433`), the subtest "heredoc with it's and a git commit last" now expects silent. D20 (FR-018), per `contracts/commit-form.md` §4c: for each rule row there (`never-list`, `commit-never`, `unjudgeable`, `git-word`, `flag`, `branch`, `owns-missing`, `outside-owns`, `git-error`), one commit command in the commit setup that hits it gives no request and a `dropped` file in the worker's approve folder whose first tab field is that rule (and for `git-word`, `flag`, `outside-owns` the detail); a sent plain `-m` commit leaves no `dropped` file and removes an old one; every existing approve and refuse result stays. Owns: `tests/test_approve_hook.py`. Test: python3 tests/test_approve_hook.py.

**Checkpoint**: T003 and T004 new cases fail on the current code.

---

## Phase 4: User Story 2 build

- [ ] T005 [P] [US2] In `hooks/st-approve.py`, add next to `SUBSTITUTION` (`:41`) the function `unjudgeable(command)`: true when `"<<" in command` or `SUBSTITUTION.search(command)` matches. In `commit_check` (`:194-195`) replace `SUBSTITUTION.search(HEREDOC_MESSAGE.sub("", command))` with `unjudgeable(command)` and delete `HEREDOC_MESSAGE` (`:40`) (D13). Leave every other check. In `hooks/st-git-guard.py`, load that function once at import with `importlib.util.spec_from_file_location("st_approve", os.path.join(os.path.dirname(os.path.realpath(__file__)), "st-approve.py"))` and `exec_module`, inside `try`/`except Exception`. On a load error, keep `<ExceptionType>: <message>`, never crash or exit non-zero, run today's rules, skip the form deny, and when the command's unquoted text matches `GIT_WORD` note `ask` with the reason `The git guard could not load hooks/st-approve.py (<ExceptionType>: <message>). Every git command asks until it loads.` (a `deny` of today's rules still wins; the reason is added with `note()`, so it may follow other reasons, and T003 checks that the joined reason contains it). Track whether the command has a `git commit` part (`contracts/commit-form.md` §2 (a)): `check()` parsed sub `commit` (`:295-302`), or on the fallback path a line noted at `:339` or `:343` holds the word `commit`. After the scan, when that is true and `unjudgeable(command)` is true, output `permissionDecision: "deny"` with `permissionDecisionReason` exactly the §3 text, alone, in every commit mode and session. Else decide as today. D20 (FR-018), per `contracts/commit-form.md` §4c, in `hooks/st-approve.py`: at each place that drops a commit today (`bash_ok` refusal at `:270` for a command with a `git commit` part, and every `return None` in `commit_check`, `:193-245`), write `<rule><TAB><detail><TAB><command>` to the worker's `.stratum/approve/dropped` (temp file plus `os.rename`; command control characters as `?`, cut to 300 characters; a failed write ignored), and remove `dropped` when a `.req` is written. What is sent or dropped does not change. Owns: `hooks/st-approve.py`, `hooks/st-git-guard.py`. Test: python3 tests/test_git_guard.py && python3 tests/test_approve_hook.py.

**Checkpoint**: US2 works. A heredoc or `$(` commit is denied with the `-m` hint everywhere; a plain `-m` commit reaches the orchestrator in full.

---

## Phase 5: User Story 3 tests (Stratum stops teaching heredoc commits)

Starts after Phase 2 (shares `tests/test_st_worker.sh` and `scripts/st-worker.sh` with US1).

**Goal**: failing tests for the setting step, the "not at all" marker, the turn-on hint, the commit form text (FR-008, FR-009, FR-010, FR-016) and the `dropped` line in `wait` (FR-018, D20; US3 holds it because it edits `scripts/st-worker.sh` after US1).

**Independent Test**: the skill and agent text rows of `contracts/git-instructions.md` §7 are present; the session text and the worker brief name `git commit -m 'subject' -m 'body'`; `autonomous-on` prints the hint only when the git instructions are not off at any level.

- [ ] T006 [P] [US3] In `tests/test_update_rules.sh`, add rows GI1-GI9 with GI4b, GI4c and GI5b of `contracts/git-instructions.md` §7 to the `ROWS` block, each phrase exactly as written there (`grep -qF`). Owns: `tests/test_update_rules.sh`. Test: bash tests/test_update_rules.sh.
- [ ] T007 [P] [US3] In `tests/test_session_hooks.sh`, add one check that the output of `hooks/st-session-start.sh` holds exactly `Commit with git commit -m 'subject' -m 'body': single quotes, no heredoc, no backticks and no $(. The git guard denies other forms.` In `tests/test_worker_rules.sh` row W8, replace `show its line word for word` with `show its lines word for word (the `autonomous on` line and, when printed, the `hint` line)`; the rest of the row stays (FR-016). Owns: `tests/test_session_hooks.sh`, `tests/test_worker_rules.sh`. Test: bash tests/test_session_hooks.sh && bash tests/test_worker_rules.sh.
- [ ] T008 [P] [US3] In `tests/test_st_worker.sh`: (1) `:237`, change brief rule 5 to the single-quoted form of `contracts/git-instructions.md` §6: `` `git add <path> <path> && git commit -m '<subject>' -m '<body>'` ``, the rest of the rule unchanged; write each `'` inside the single-quoted bash string as `'"'"'`. (2) At the top of the file, export `CLAUDE_CONFIG_DIR="$tmp/cfg"` and `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1`, so ON1-ON9 keep their exact one-line output and no case reads the real user settings. (3) Add hint cases HI1-HI8 of `contracts/git-instructions.md` §7 (FR-016), each run with `env -u CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` unless the row sets it: HI1 no setting gives exit 0 and exactly two lines, `autonomous on<TAB>local` and `hint<TAB>Autonomous build mode works better with Claude Code's built-in git instructions off: add "includeGitInstructions": false to .claude/settings.json (this project) or ~/.claude/settings.json (all projects), then start new sessions.`, and the entry exists; HI2-HI5 (`false` in the project, local or user file, or the env var set) give only the on line; HI6 (`true`) and HI7 (`{not json`) give the hint and exit 0; HI8 (id `../x`) gives the existing fail line, exit 1, no hint. (4) D20 (FR-018), cases DR1-DR4 of `contracts/commit-form.md` §4c: a blocked worker with a `dropped` file in its approve folder makes `wait` print `dropped<TAB><the file's first line>` after the `state` line and before `pane text:`; no file, no line; an ESC byte is removed; a remote worker (`rmk`, `--machine laptop`) prints the line read from the saved machine. Owns: `tests/test_st_worker.sh`. Test: bash tests/test_st_worker.sh.

**Checkpoint**: T006-T008 fail on the current code (HI2-HI5 and HI8 may pass before; HI1, HI6 and HI7 fail).

---

## Phase 6: User Story 3 build

Each build task runs only its own narrow check. T014 runs the shared suites once, after T009-T013.

- [ ] T009 [P] [US3] In `skills/st-init/SKILL.md`, add step 12 **Git instructions** with the exact text of `contracts/git-instructions.md` §3 after step 11, renumber the Report step to 13, and in its commit list change `` `.stratum/advisor.json`, `` to `` `.stratum/advisor.json`, `.stratum/git-instructions-kept`, ``. Steps 1-11 keep their numbers and text. Owns: `skills/st-init/SKILL.md`. Test: bash tests/test_model_files.sh && bash tests/test_risk_rules.sh && bash tests/test_design_lane.sh && bash tests/test_lane_steps.sh.
- [ ] T010 [P] [US3] In `skills/st-update/SKILL.md`, add at the end of step 6 the paragraph and the `ponytail:` HTML comment of `contracts/git-instructions.md` §4, exactly, and in step 7 (`:52`) insert after ``and `.stratum/advisor.json` when step 6 wrote it,`` the text `` and `.claude/settings.json` or `.stratum/git-instructions-kept` when the git instructions paragraph wrote it,`` (exact result line in `contracts/git-instructions.md` §4). Owns: `skills/st-update/SKILL.md`. Test: grep -qF 'Built-in git instructions, once per run:' skills/st-update/SKILL.md && grep -qF 'ponytail: one-time step for checkouts set up before 019' skills/st-update/SKILL.md.
- [ ] T011 [P] [US3] In `agents/st-git.md`, add as the first bullet of step 6 the line of `contracts/git-instructions.md` §6 (`Run it as `git commit -m 'subject' -m 'body'`: ...`), and in Rules, after the line that ends `Do not retry around it.` (`:49-50`), the exception line `- Exception: a deny that starts with `Commit form denied:`. Write the same message as `git commit -m 'subject' -m 'body'` and run it once more. A second deny: stop and report.` Owns: `agents/st-git.md`. Test: bash tests/test_test_scope.sh && grep -qF 'Commit form denied:' agents/st-git.md.
- [ ] T012 [P] [US3] In `hooks/st-session-start.sh:25`, in the `Stratum rule:` echo, after `The git guard reads Bash text and stops on git words it cannot parse.`, add the sentence that prints as `Commit with git commit -m 'subject' -m 'body': single quotes, no heredoc, no backticks and no $(. The git guard denies other forms.` Escape the `$` (`\$(`) inside the double-quoted echo. Owns: `hooks/st-session-start.sh`. Test: bash tests/test_session_hooks.sh.
- [ ] T013 [P] [US3] In `scripts/st-worker.sh`: (1) `:253`, brief rule 5: replace `-m "<subject>" -m "<body>"` with `-m '<subject>' -m '<body>'`, written as `'"'"'` inside the single-quoted bash string; the rest of the rule stays. (2) `autonomous-on` (`:695-705`), after `printf 'autonomous on\t%s\n' local`: when `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` is unset and none of `<top>/.claude/settings.json`, `<top>/.claude/settings.local.json`, `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` passes `jq -e '.includeGitInstructions == false'` (`<top>` = `git rev-parse --show-toplevel`), print the exact hint line of `contracts/git-instructions.md` §5. A file that is missing or not JSON counts as not off. Exit 0 either way (FR-016, a hint only). (3) D20 (FR-018): in `st()` (`:157-166`), branch `blocked`, right after the `state` line, print `dropped\t<line>` when `$WT/.stratum/approve/dropped` exists (on a saved machine, read `$Q/.stratum/approve/dropped` with `rsh`): its first line, with every byte that is not printable or TAB removed, cut to 400 characters; no file, no line; never write or remove the file. (4) `skills/st/SKILL.md:89`: replace `show its line word for word` with `show its lines word for word (the `autonomous on` line and, when printed, the `hint` line)`. Owns: `scripts/st-worker.sh`, `skills/st/SKILL.md`. Test: bash tests/test_st_worker.sh && bash tests/test_worker_rules.sh.
- [ ] T014 [US3] Integration check for Phase 6, after T009-T013, no file change: run the shared suites once. Test: bash tests/test_update_rules.sh && bash tests/test_inspect.sh && bash tests/test_on_demand.sh && bash tests/test_session_hooks.sh && bash tests/test_st_update.sh && bash tests/test_update_items.sh && bash tests/test_worker_rules.sh && bash tests/test_design_lane.sh && bash tests/test_verify.sh && bash tests/test_risk_rules.sh && bash tests/test_state.sh && bash tests/test_lane_steps.sh && bash tests/test_triage_rules.sh && bash tests/test_test_scope.sh.

**Checkpoint**: US3 works.

---

## Phase 7: User Story 4 tests (the Codex answer arrives exact)

**Goal**: failing tests for the session log reader, the headless fallback and the Esc stop (FR-011, FR-012, FR-013, FR-014, D14).

**Independent Test**: a tab answer with backticks, `"` and `\` is recorded byte for byte from a fake log; no log gives `codex: headless (no session log)`; an aborted turn gives `BLOCKED: the review was stopped in the Codex tab`.

- [ ] T015 [P] [US4] In `tests/test_codex_agent.sh`, export `CODEX_HOME="$tmp/codex"` at the top. Make the fake `herdr agent prompt` write a rollout file `"$CODEX_HOME/sessions/2026/11/09/rollout-<x>.jsonl"` from a template with the nonce read from `$PF` (as `screen_prompt` does today), so the existing cases keep reaching exit 0. Make the fake `sleep` count its calls in a file. Add cases L1-L10 of `contracts/codex-log.md` §4 with their exact expectations: L1 answer file equals `{"verdict":"APPROVED","summary":"use `x` and \"y\" and \\z","findings":[]}` byte for byte; L4 exit 6, `codex: no session log`, no answer file, 15 `sleep` calls; L8 no `agent read` call in the log; L9 exit 4, `BLOCKED: the review was stopped in the Codex tab`, no `sleep` call; L10 exit 6. Remove C19b; turn C23 into L4, the two `i` cases into L3, and C24 into "no `agent read` call at all". Owns: `tests/test_codex_agent.sh`. Test: bash tests/test_codex_agent.sh.
- [ ] T016 [P] [US4] In `tests/test_advisor_matrix.sh`, export `CODEX_HOME` to a temp folder for the whole file (keep M1's own `CODEX_HOME`). Make the fake `agent prompt` of `hbin2` write the log record with the answer from `$d/answer` and the nonce from the prompt file, unless `$d/nolog` exists; remove the `agent read ... 400` branch. M1-M24 exist, so the new cases are M25 (no log: the fake `codex exec` runs, its verdict is recorded, last line `codex: headless (no session log)`), M26 (no log and the fake `codex exec` exits 1: `BLOCKED: codex exited 1`, exit 1), M27 (no log, a copied `scripts/` with `lim=540` changed to `lim=59`: `BLOCKED: timed out`, no `codex exec`), and M28 (the fake writes the prompt line and a `turn_aborted`: `BLOCKED: the review was stopped in the Codex tab`, no `codex exec`). Change M19 (`:501-502`, mode `nomarkers`): the fake writes a log record with no marker pair, so `st-codex-agent.sh` exits 6 and the review runs headless; expect exit 0, `$tmp/argv` exists (the fake `codex exec` ran), and the last line `codex: headless (no session log)`, in place of `BLOCKED: no answer between the markers` (`contracts/codex-log.md` §4). Keep k8 (`BLOCKED: malformed answer`, no `codex exec`). Owns: `tests/test_advisor_matrix.sh`. Test: bash tests/test_advisor_matrix.sh.

**Checkpoint**: the new cases fail on the current code.

---

## Phase 8: User Story 4 build

Each build task runs only its own narrow check. T019 runs the shared advisor suites once, after T017 and T018.

- [ ] T017 [P] [US4] In `scripts/st-codex-agent.sh`, replace the pane read and scrape (`:128-138`) with the log reader of `contracts/codex-log.md` §1-§2: an inline `python3 -I` that reads `${CODEX_HOME:-$HOME/.codex}/sessions/**/rollout-*.jsonl` files whose mtime is not older than `$pf`, read-only, skips non-JSON lines, takes the `task_complete.last_agent_message` that holds the line `ST-ADVISOR-END-<nonce>` and before it `ST-ADVISOR-BEGIN-<nonce>`, and writes the lines between them joined with `\n` to `$af` unchanged (exit 0); exits 2 when a user `message` holding `Read the review request in $pf and follow it.` is followed in the same file by a `turn_aborted` and no answer (D14); else exits 1. The shell loop runs it up to 15 times with `sleep 1` between, with the note `# ponytail: fixed 15 tries for the log to show the answer, raise it if quickstart L3 measures a longer lag`. Results: 0 prints `codex: tab $name`; 2 dies `BLOCKED: the review was stopped in the Codex tab` with exit 4; after 15 tries die `codex: no session log` with exit 6. No `herdr agent read` call remains. Owns: `scripts/st-codex-agent.sh`. Test: bash tests/test_codex_agent.sh.
- [ ] T018 [P] [US4] In `scripts/st-advisor.sh`, in the tab result case (`:253-258`), add `6) via="codex: headless (no session log)" ;;`. Remove the `ponytail:` note at `:263` ("the 60 s floor has no test"): M27 now tests the floor. Nothing else changes. Owns: `scripts/st-advisor.sh`. Test: bash tests/test_advisor.sh && grep -qF 'codex: headless (no session log)' scripts/st-advisor.sh.
- [ ] T019 [US4] Integration check for Phase 8, after T017 and T018, no file change: run the shared advisor suites once. Test: bash tests/test_advisor_matrix.sh && bash tests/test_advisor_waive.sh && bash tests/test_advisor_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_on_demand.sh.

**Checkpoint**: US4 works.

---

## Phase 9: Polish

- [ ] T020 Run the live check of `quickstart.md` §2 (L1-L4) with the user before merge, and write each step's result, and the L3 lag in seconds, in the PR body. The user drives it; no file changes. Test: bash tests/test_st_worker.sh && python3 tests/test_git_guard.py && python3 tests/test_approve_hook.py && bash tests/test_update_rules.sh && bash tests/test_session_hooks.sh && bash tests/test_codex_agent.sh && bash tests/test_advisor_matrix.sh.

---

## Dependencies & Execution Order

- Inside a story: test phase, then build phase.
- US1 (Phases 1-2), US2 (Phases 3-4) and US4 (Phases 7-8) share no file. They can run at the same time. D2 sets the merge order: US1, then US2, then US4. Keep T002 (D17) merged before T005 as order hygiene: both change how commits reach the orchestrator, and the live check L1 tests them together.
- US3 (Phases 5-6) shares `tests/test_st_worker.sh` (T001, T008) and `scripts/st-worker.sh` (T002, T013) with US1. Start it after Phase 2. It does not need US2 or US4.
- T014 runs after T009-T013. T019 runs after T017 and T018.
- T020 runs after every story is merged.

### FR coverage

| FR | Test task | Build task |
|----|-----------|------------|
| FR-001 | T001 (DB1-DB6, AN11b) | T002 |
| FR-002 | T001 (DB1, DB10) | T002 |
| FR-003 | T001 (DB7-DB9, DB11, AN6f, NO1-NO3 kept) | T002 |
| FR-004 | T003 (and the fail-closed load), T004 | T005 |
| FR-005 | T003, T004 (P1-P4) | T005 |
| FR-006 | T004 (P1-P4) | T005 (no change to the request; kept) |
| FR-007 | T003, T004 (N4) | T005 (no change; kept) |
| FR-008 | T006 (GI1-GI4c) | T009, T014 |
| FR-009 | T006 (GI4b, GI5-GI7) | T010, T014 |
| FR-010 | T006 (GI8-GI9), T007, T008 (rule 5) | T011, T012, T013, T014 |
| FR-011 | T015 (L1-L3, L5-L8) | T017, T019 |
| FR-012 | T015 (L4), T016 (M19, M25, M27) | T017, T018, T019 |
| FR-013 | T016 (M26) | T018 (today's path, kept), T019 |
| FR-014 | T001, T003, T004, T015, T016 (negative cases) | |
| FR-015 | | T020 |
| FR-016 | T008 (HI1-HI8), T007 (W8) | T013, T014 |
| FR-017 | T001 (IH1-IH5, the converted approve cases, W3) | T002 |
| FR-018 | T004 (one case per drop rule, the removal on send), T008 (DR1-DR4) | T005 (the hook writes `dropped`), T013 (`wait` and `watch` print it) |
| D14 | T015 (L9, L10), T016 (M28) | T017 |
| D15 | T001 (DB7-DB8, NO1-NO3) | T002 |

### Parallel Opportunities

- Phase 1: T001. Phase 2: T002. Phase 3: T003, T004. Phase 4: T005. Phase 5: T006, T007, T008. Phase 6: T009-T013, then T014. Phase 7: T015, T016. Phase 8: T017, T018, then T019.
- Phases 1-2, 3-4 and 7-8 can run beside each other.

---

## Parallel Example: User Story 2 and User Story 4 tests

```bash
Task: "T003 guard deny cases in tests/test_git_guard.py"
Task: "T004 shared table for both hooks in tests/test_approve_hook.py"
Task: "T015 log reader cases in tests/test_codex_agent.sh"
Task: "T016 headless fallback cases in tests/test_advisor_matrix.sh"
```

---

## Implementation Strategy

1. MVP: Phases 1-2 (US1). The orchestrator answers dialogs on a busy worker screen.
2. Phases 3-4 (US2): no commit question stays in a worker pane for the user.
3. Phases 5-6 (US3): fewer denied first tries.
4. Phases 7-8 (US4): exact Codex answers.
5. Phase 9: the live check. The orchestrator runs the full suite.

## Notes

- `[P]` tasks share no file in their phase. Each names its files under `Owns:`. In Phases 6 and 8 each build task runs a narrow check, and one integration task (T014, T019) runs the shared suites once.
- No `[lock]` task: every test uses its own temp folder. No `[screen]` task: no new page or view.
- `docs/harness/` and `README.md` do not change (plan.md, Structure Decision). `skills/st-worker/SKILL.md` changes only at `:31` for D17 (T002); its step 6 cut-off No flow stays (D15).
