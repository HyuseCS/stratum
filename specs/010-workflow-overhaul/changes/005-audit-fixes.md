# 005 audit-fixes

What: Fix the 20 findings of `.stratum/advisor/ponytail-audit-2026-11-24.md` (user approved all 20 and the gate). Eight build units with disjoint files, so they can run in parallel. Each unit names the finding numbers it closes.
FRs: FR-008 (git guard, U1). FR-020 and FR-021 (workers, U2). FR-005 to FR-007 and FR-031 (tests, U7). No FR covers the other findings. They are audit fixes in the harness this feature hosts.
Impact area: core runtime

Rules for every unit: change a file only with the Write or Edit tool, never with a shell write in Bash. Add no comment lines except `ponytail:` markers. A prose fix gets no new grep pin (finding 17).

HOLD: the U7 prune step (finding 17) waits for the user's pick between R1 option A and option B. The rest of U7 (`test_prereq.sh` and its README line) can run now.

## Units

### U1 git guard (findings 1, 2, 3, 5)
Owns: `hooks/st-git-guard.py`, `tests/test_git_guard.py`.
Test: `python3 tests/test_git_guard.py`

- F1: add a new tuple for `check()` only. Do not touch `PREFIX`, because `heredocs()` uses it at `:302`. In `check()` (`:354`), skip these words at the start of a segment:
  - The compound words `if then elif else do while until { !`.
  - The wrappers `env nice nohup time`, matched by basename so `/usr/bin/env` counts. After a wrapper, skip `-x` and `--x=y` words. Also skip the value of `env -u/--unset/-C/--chdir`, `nice -n/--adjustment` and `time -f/-o`.
  - `env -C`/`--chdir` sets `env` (elsewhere), the same as `GIT_DIR=`.
  - `env -S '<cmd>'` is not split. Add a `ponytail:` line that names this limit.
- F2: there are four changes.
  - In `parse_git`, `-c` joined to its value (`-ccore.hooksPath=x`) adds that key to `conf`.
  - For `commit` only, a short group `-[aeiopqsvz]*n` before `--` means no-verify. A group with `n` after a value letter (`-mnote`) does not count. Never read a message value.
  - At `:357`, `GIT_CONFIG*=` words also set `env`. This gives "ask" for commit, not "deny".
  - A unique prefix of `--no-verify` counts as `--no-verify` (see the long-option prefix item below). This was probed: `git commit --no-veri` skips a failing pre-commit hook. It is the same "hooks must run" rule, added beyond the audit text.
- F3: send `checkout`/`switch` with `-f`, `--force` or `--discard-changes` to `destructive("discard", ...)`. In a short group, `f` counts only when no `b`, `B`, `c` or `C` comes before it, because those letters take a value (`-bfix`, `-cfeature`).
- F5: in `push`, an argument that does not start with `-` and starts with `+` goes to `force_push`. `--mirror` and `--prune` give the remote-delete deny.
- Long-option prefixes: git takes a unique prefix of a long option. One small helper treats `--xy...` (4 or more characters, before any `=`) as a guarded flag when the flag name starts with it. It covers the flags U1 touches: `--no-verify` (every subcommand), `--force`, `--delete`, `--mirror` and `--prune` (push), and `--force` and `--discard-changes` (checkout and switch). Example: `git switch --discard main`. A prefix that is not unique makes git refuse the command, so a decision on it does no harm. `reset --hard`, `clean --force` and `branch --delete` keep exact matching (R2).
- Cases (new methods). Each guard rule has a negative control:
  - Wrappers deny. Run `push --delete origin x` behind each of: `env`, `/usr/bin/env`, `env -u FOO`, `env -i`, `nice`, `nice -n 5`, `nohup`, `time`, `if true; then ...; fi`, `while false; do ...; done`, `{ ...; }`, `! ...`. Each gives `deny`. With commit mode `auto`, `env -C <other repo> git commit -m 'fix: x'` gives `ask`. Negative control: `env FOO=1 ls`, `nice make`, `time true` and `if true; then echo git; fi` give `(None, "")`.
  - Hooks with commit mode `auto`. `git -ccore.hooksPath=/dev/null commit -m 'fix: x'`, `git commit -n -m 'fix: x'`, `git commit -nm 'fix: x'`, `git commit -anm 'fix: x'` and `git commit --no-veri -m 'fix: x'` each give `deny`. `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null git commit -m 'fix: x'` gives `ask`. Negative control: `git commit -m 'fix: no n here'`, `git commit -m'fix: note'` and `git commit -m '-n'` give `None`. `git log -n 3` and `git clean -n` give `None`, and `git push -n origin main` gives a plain `ask` with no deny.
  - Discard. `git checkout -f main`, `git checkout --force main`, `git switch --discard-changes main`, `git switch --discard main` and `git switch -f main` each give `ask` with `DESTRUCTIVE (discard`. With `discard: deny` they give `deny`, and with `auto` they give `None`. Negative control: `git checkout main`, `git switch -c fix-f`, `git switch -cfeature` and `git checkout -bfix` give `None`, also with `discard: deny`.
  - Push. `git push origin +main` and `git push origin +refs/heads/a:refs/heads/a` give `ask` with `DESTRUCTIVE`, and `deny` with `force_push: deny`. `git push --mirror origin`, `git push --mir origin`, `git push --prune origin` and `git push --del origin x` give `deny`. Negative control: `git push origin main` and `git push --progress origin main` stay a plain `ask`.
- Docs for the new forms are in other units: README lines go to U7 and DESIGN.md lines go to U6.

### U2 worker script (findings 4, 6, 9)
Owns: `scripts/st-worker.sh`, `tests/test_st_worker.sh`, `specs/020-worker-workspaces/contracts/cli.md` (line 86), `specs/020-worker-workspaces/data-model.md` (line 65), `specs/008-herdr-workers/contracts/script.md` (lines 377, 575), `skills/st-worker/SKILL.md` (the `watch` lines 26 and 38; no test pins them).
Test: `bash tests/test_st_worker.sh`

- F4: at `:840`, use `git status --porcelain -- . ':(exclude).stratum/state.json'`. Then update contract 008 lines 377 and 575 to say "except `.stratum/state.json`".
- F6: at `:666`, a failed `agent get` goes to the `gone` path only when `[ "$(code)" = agent_not_found ]`. Any other error gives `stop "$(head -1 "$e")"` (exit 1). An answer with no status gives `stop "no .result.agent.agent_status in the herdr answer"`. In `skills/st-worker/SKILL.md`, the watch line gets: another herdr error prints `stopped: <error line>` (exit 1) and says nothing about the worker, so run `watch` again.
- F9: do not take the audit's "before the tab" option. It breaks D37: after a failed `workspace close`, the guard file would be gone and the retry would refuse. Instead, move the two `rx` removals (guard file and approve folder, then the marker) up to just after the `workspace close`/`tab close` call, before the `for k in agent:name tab:label` check loop. Keep their messages. A failed close call still stops before the removals, so the retry works. A leftover agent after the close no longer leaves the files behind. Update cli.md:86 and data-model.md:65 to this order.
- Cases:
  - H12: the `tracked` case changes `src/keep`, not state.json. A new row H12b: only `.stratum/state.json` changed, and headless runs (the claude stub is called and the line `Working tree is not clean.` is not printed). Negative control: H12 tracked and untracked still exit 1.
  - WC7 and WC12 get `STUB_FAIL_CODE=agent_not_found`, with the same outcomes as now. A new row WC13: `STUB_FAIL="agent get" STUB_FAIL_CODE=timeout` exits 1, gives one `stopped: ` line, prints no `state\tgone` line and writes no `gone` in `.seen`. A new row WC14: `STUB_NO_STATUS=1` gives exit 1 and the `stopped: no .result.agent.agent_status` line.
  - C3b: after the `STUB_KEEP_AGENT=1` close (exit 1, `close left agent`), `.stratum/git-guard.json` and `.stratum/worker` are gone. This is red with the old order. C3c: with `STUB_FAIL="workspace close"`, close exits 1 and both files stay. A second `close` with no stub failure exits 0 with `closed` (this keeps D37).

### U3 small scripts (findings 7, 8)
Owns: `scripts/st-verify.sh`, `scripts/st-shortcuts.sh`, `tests/test_verify.sh`, `tests/test_shortcuts.sh`.
Test: `bash tests/test_verify.sh && bash tests/test_shortcuts.sh`

- F7: at `:12`, use `git diff HEAD -U0 -- "$f"`.
- F8: at `:10`, use the regex `/(#|\/\/|[*]|--|<!--) ?ponytail:/`.
- Cases:
  - verify: a staged `# explains x` in `a.py` (`git add`) gives FAIL and names the line. A staged new file `n.py` with `# c` gives FAIL. Negative control: a staged `# ponytail: x` passes. Restore the index after each row.
  - shortcuts: `-- ponytail: sql` in `q.sql`, `<!-- ponytail: html -->` in `p.html` and ` * ponytail: block` in `c.js` each give one row. Negative control: `s = "ponytail: text"` in `d.py` gives no row.

### U4 statusline (findings 11, 18)
Owns: `statusline/st-statusline.sh`, `tests/test_statusline.sh`.
Test: `bash tests/test_statusline.sh`

- F11: the `bunx` run (`:96`) and the git run (`:48`) get `timeout=2`. Catch `subprocess.TimeoutExpired` (keep `line = ""` and `common = ""`). Add a `ponytail:` line: a cold `bunx` download that needs more than 2 s is killed on each refresh, so run `bunx @owloops/claude-powerline@1.30.3 --help` once by hand.
- F18: wrap `:68-69` in `try ... except (OSError, ValueError)`.
- Cases:
  - Slow tools: put stubs `bunx` and `git` first on PATH. Each runs `sleep 10` as a child, not with `exec`. The output has `Stratum` and the path, and the elapsed time is under 6 s. Negative control: without the timeouts the row waits 10 s or more and fails the time check.
  - Broken theme file: `.stratum/powerline.json` = `{"theme":"nord",}` (a trailing comma). The output still has `Stratum` and `commit:`.

### U5 deletions (findings 12, 13)
Owns: deletes `skills/st-ui-ux/data/{phosphor-icons-upstream,google-font-licenses,data-provenance,catalog-summary}.json`, `skills/st-ui-ux/scripts/validate_data.py`, `skills/st-ui-ux/scripts/tests/`, and `skills/st-hallmark/scripts/{install,install-hook,lint-hook}.mjs`. Edits `skills/st-hallmark/references/flow.md` (`:95-97`: remove the "Edit-time linting" section; `:110`: remove the table row), `skills/st-design/engine.md:20-21`, `tests/test_design_lane.sh:87`, `specs/009-design-lane/contracts/design-lane.md:149` and `THIRD_PARTY_NOTICES.md` (the one owner).
Test: `bash tests/test_design_lane.sh && bash tests/test_inspect.sh && bash tests/test_harness_model.sh`

- engine.md: "Do not run its Step 1 questions, its hero review or its finish review." The pin at test_design_lane.sh:87 and the contract line follow the new text.
- Grep done before planning. Nothing in README, tests, `vendor.lock`, `st-sync` or `docs/harness` names the deleted files. Only the files themselves and old `specs/` research name them, and specs stay as history.
- THIRD_PARTY_NOTICES.md, Changes section:
  - ui-ux-pro-max: "the upstream catalog manifests (`data/*.json`), `validate_data.py` and `scripts/tests/` are not shipped."
  - hallmark: replace "Nothing else changed." with "`scripts/install.mjs`, `install-hook.mjs` and `lint-hook.mjs` are not shipped."
  - These lines tell `st-sync` not to port the files back.
- THIRD_PARTY_NOTICES.md, for U8:
  - In the graphify table row, `graphify/skill.md` maps to `skills/st-graphify/SKILL.md` and `skills/st-graphify/references/build.md` (Steps 0 to 9).
  - Changes section: "graphify skill: Steps 0 to 9 moved from SKILL.md to `references/build.md`, unchanged."
- Cases: no new test, because this unit only deletes files. Check: `git ls-files skills/st-ui-ux/data skills/st-ui-ux/scripts skills/st-hallmark/scripts` lists none of the deleted paths, and `search.py` still runs (`python3 skills/st-ui-ux/scripts/search.py "dashboard" --domain style -n 1` exits 0).

### U6 docs and agent text (findings 10, 14, 16)
Owns: `agents/st-git.md`, `DESIGN.md`, `docs/harness/**` (model, views, `.likec4/`, generated `README.md`, atlas), `vendor.lock`.
Test: `bash tests/test_harness_model.sh` (every check prints `ok`, none prints `SKIP`) `&& bash tests/test_no_frontend_design.sh` (the `vendor.lock` JSON check, read only).

- F10: `agents/st-git.md:29` becomes "3. A listed file is clean, or missing and not a tracked deletion: stop and report." Step 4 `git add <path>` stages the deletion.
- F14:
  - `DESIGN.md:145`: change "merges it into `main`" to "merges it into the feature branch". Reword it, do not delete it.
  - Remove the `codex-home` model:
    - `data.c4:423-428`: the element `local-state-stratum-codex-home`.
    - `data.c4:497`: the link to it.
    - `data.c4:454`: fix the `codex-auth-json` summary.
    - `scripts.c4:124,125,127` ("Codex home"), `:134`, `:136`, `:137`.
    - `skills-tools.c4:224`.
    - Each view or `.likec4` snapshot that names the element.
    - `atlas/data.mjs:162` `how`.
  - Delete the `codex-auth-json` element only when no link is left on it.
  - Rebuild `docs/harness/README.md` with `npx -y likec4@1.60.0 export markdown` (the `rebuild` check). Rebuild `atlas.html` and `SYSTEM.md` with the command in README.md:216.
- U1 docs in DESIGN.md:
  - `:242-243`: the `discard` list adds `checkout -f` and `switch --discard-changes`.
  - `:248`: the always-blocked list adds `-n` on commit and `--mirror`/`--prune` on push.
- F16: `vendor.lock` gets two entries with `repo`, `ref`, `commit`, `path` and `license`, because `st-sync` step 1 reads `path`.
  - `claude-powerline`: `Owloops/claude-powerline`, ref `v1.30.3`, commit `5f6449bd35f3ceffca872b2391db5f92462cd206` (from `git ls-remote`), `version` `1.30.3`, MIT. Take `path` from the upstream themes source after a check.
  - `system-atlas`: `NousResearch/hermes-agent`, path `optional-skills/creative/system-atlas`, MIT. For the commit, clone into the scratchpad and take the commit whose `assets/template.html` blob equals `git hash-object ~/.claude/skills/system-atlas/assets/template.html`. The local skill folder is in the user's dotfiles repo, so its own git hash is not upstream. If no commit matches, stop and report. Do not guess.
  - Other readers of `vendor.lock`: `skills/st-status/SKILL.md`, `skills/st-sync/SKILL.md` and `skills/st-design/engine.md`, plus the tests `test_design_lane.sh` and `test_no_frontend_design.sh`. Read each and confirm that two new keys break none of them.
- Cases: no new pin (prose and docs). The test command above is the check.

### U7 tests (findings 15, 17)
Owns: new `tests/test_prereq.sh`. Edits `tests/test_risk_rules.sh`, `tests/test_test_scope.sh` and `tests/test_no_frontend_design.sh`. Under option A it also deletes `tests/test_screen_rules.sh` and `tests/test_triage_rules.sh`. Owns `README.md`, the one owner.
Test: `bash tests/test_prereq.sh && bash tests/test_risk_rules.sh && bash tests/test_test_scope.sh && bash tests/test_no_frontend_design.sh && bash tests/test_inspect.sh`

- F15: `tests/test_prereq.sh` runs in a temp project with `.stratum/state.json`. It calls `scripts/check-prerequisites.sh` and `scripts/resolve-template.sh`. Cases:
  - P1: no state.json gives exit 1 and `Run st-define first`.
  - P2: `--require-plan` with no plan.md gives exit 1 and `plan.md not found`.
  - P3: an empty plan.md gives exit 1 and `plan.md is empty`.
  - P4: `--require-tasks` with no tasks.md gives exit 1 and `tasks.md not found`.
  - P5: with all files present, plus `research.md`, `contracts/x.md` and `--include-tasks`, it exits 0. The JSON parses (`python3 -c json.load`), `FEATURE_DIR` is absolute, and `AVAILABLE_DOCS` is `["research.md","contracts/","tasks.md"]`.
  - P6: `--paths-only` with a missing feature folder exits 0 with JSON.
  - P7: `--template plan` with `.stratum/templates/plan.md` present gives the override path. Without it, it gives `<plugin>/templates/plan.md`.
  - P8: `resolve-template.sh Bad_Name` exits 1 with `Invalid template name`. `resolve-template.sh nope` exits 1 with `not found`.
  - P9: an unknown option exits 1.
  - Negative control: in a scratch copy of the scripts with the empty-plan line removed, P3 goes red.
- F17 (HOLD until the user picks, see R1):
  - Option A, the audit as written. Keep the checks that guard parsed text or repo structure, and delete the rest:
    - test_risk_rules: keep R1 and R3 (the `Lane:` line that `hooks/st-phase.py:17` parses). Delete R2, R4-R22, K1 and all G rows.
    - test_test_scope: keep the `suite_bad` repo rule and the S1, S3, S4 and S5 strings it uses. Keep the S5 check, because it pins the `Test:` task format that `owns()` at `scripts/st-worker.sh:250` parses. Delete the other S checks and G1-G3.
    - test_screen_rules and test_triage_rules: delete the whole files, because every check in them is a prose pin or a gone check. Remove both README lines (`README.md:448-449`). No script, skill or `.github/` file outside `specs/` names them.
    - test_no_frontend_design: delete only "vendor.lock has no frontend-design key". The repo-wide `git grep` covers it. Keep the rest.
  - Option B, narrower. Delete only the gone rows and the rows that repeat another test (for example R4 and K1 repeat `test_on_demand.sh` #18 FR-010). Point the kept st-build Advisor rows in test_risk_rules.sh at `skills/st-build/advisor.md` (U8's new file).
  - "Stop adding new ones" has no file to live in, so it is not planned.
- README (the one owner):
  - `:438` area: add `bash tests/test_prereq.sh`.
  - Option A only: remove `:448-449`.
  - `:275`: `discard` adds `checkout -f` and `switch --discard-changes`.
  - `:280`: the always-blocked line adds `commit -n`. Remote branch delete adds `--mirror` and `--prune`, and a `+` refspec counts as a force push.
  - No other unit needs a README line.

### U8 skill structure (findings 19, 20)
Owns: new `skills/st-build/advisor.md`. Edits `skills/st-build/SKILL.md`, `skills/st-plan/SKILL.md:32,34`, `skills/st-advisor/SKILL.md:13`, `skills/st-fast/SKILL.md:16`, `skills/st/SKILL.md:73`, `tests/test_advisor_rules.sh`, `tests/test_on_demand.sh`, `tests/test_lane_steps.sh`, `tests/test_worker_rules.sh` and `tests/test_lock_rules.sh` (only if a row moved). New `skills/st-graphify/references/build.md`. Edits `skills/st-graphify/SKILL.md`.
Test: `bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh && bash tests/test_lane_steps.sh && bash tests/test_worker_rules.sh && bash tests/test_lock_rules.sh && bash tests/test_state.sh`

- F19: move st-build `SKILL.md:83-126` (the Advisor body) word for word to `skills/st-build/advisor.md`. The file stays in the st-build folder, so the model edges `skills-core.c4:104,142` (`reads skills.st-build 'Advisor rules'`) stay true and no `.c4` edit is needed. Keep the `## Advisor` heading with one line: "Read `<plugin root>/skills/st-build/advisor.md` before each advisor point." `:30` "(see Advisor)" and `:132` "under Advisor" stay true. Point st-plan, st-advisor, st-fast and `skills/st/SKILL.md:73` at the new file. `procedures/` and `templates/` do not name the Advisor section (grep done).
- Tests: check every row in `tests/` that names `skills/st-build/SKILL.md`, except in test_risk_rules.sh, which U7 owns. When its phrase moved, point the row at `skills/st-build/advisor.md`. A `gone` row on a moved phrase moves too, or it would pass with no check. This covers:
  - `test_advisor_rules.sh`: the A rows and G1-G5.
  - `test_on_demand.sh`: the #18 rows, #79 FR-014 and the line-310 check.
  - `test_lane_steps.sh`: rows 5-9 and 33.
  - `test_worker_rules.sh`: W23.
  - A row whose sentence changed (st-plan `:32,34`, st-advisor `:13`) gets the new sentence.
- F20: move `skills/st-graphify/SKILL.md:61-736` (Steps 0 to 9) word for word to `references/build.md`. Keep `:1-59` (usage, help, fast path, defaults) and `:737-793` (subcommands, query, honesty). In their place put: "Follow `references/build.md` in order. Do not skip steps." In the moved text, "beside this SKILL.md" (`:231`) becomes "beside SKILL.md". Step names in `references/*.md` stay valid because the step numbers do not change.
- Cases: no new test, because both are moves with no behavior change. The repointed rows go red if a phrase is lost in the move. Negative control: drop one moved line from advisor.md and its row goes FAIL.

## Advisor amendments

- A1 (U2, finding 9): keep the guard file and the worker marker until the close is verified. A retried `close` whose tab is gone finds the worker by its worktree marker and only does the cleanup. Tests: a close whose file removal fails, then a retry; a close whose tab survives, then a retry.
- A2 (U1): every new flag check reads options only: stop at `--`, and skip the value of an option that takes one (`-m`, `-F`, `-C`, `-c` and the like). Negative controls: `git commit -m 'fix: x' -m '--no-veri'` is not denied, and `git checkout -- --force` is not a forced checkout.
- A3 (U8): `skills/st-graphify/references/update.md` (`:41`, `:75`, `:77`, `:179`) points at the steps in `references/build.md` by name, for the code-only and the semantic route, with no restart of Steps 0-2 and no full-build cleanup.
- A4 (U7, U8): option B is chosen. Moving the `test_risk_rules.sh` rows to `skills/st-build/advisor.md` is required, not optional. U7 runs after U8.

## Files
See each unit's `Owns:` line. Shared files have one owner each: README.md (U7), DESIGN.md (U6), THIRD_PARTY_NOTICES.md (U5, with U8's lines), `docs/harness/**` (U6), test_risk_rules.sh (U7). `.claude-plugin/plugin.json` needs no change (its `discard` text is general).

## Tests (written first, must fail before the build)
- U1-U4: the new rows above go red on the current code (the audit probes reproduced findings 1-3 and 5). Each guard rule has a negative control.
- U7 `test_prereq.sh` covers code that already exists, so it is green at once. Its proof is the scratch-copy negative control.
- Seven findings get no new test of their own: 10, 12, 13, 14, 16, 19 and 20. They are deletions, moves, prose or docs. Their checks are the existing suites named per unit.
- At the end, run each unit's test command once. Do not run the full suite unless the user asks (FR-005).

## Risks
- R1: finding 17 deletes the only tests of several FRs (FR-011 to FR-016, FR-023 to FR-025, FR-028, FR-029 and part of FR-005 to FR-007). That goes against FR-031 and SC-006 of this spec. Option A is the audit as written. Option B is the narrower prune. Both are in U7, and the U7 prune step waits for the pick.
- R2: these gaps stay open in U1:
  - `env -S '...'` (it gets a `ponytail:` line).
  - Other wrappers (`timeout`, `sudo`, `xargs`, `stdbuf`).
  - An `export GIT_CONFIG_*` in an earlier segment.
  - Long-option prefixes of `reset --hard`, `clean --force` and `branch --delete`.
- R3: U2 F9 still has two manual cases:
  - A removal `rx` that fails after a good close (for example an ssh drop) leaves the files. The message names them.
  - A `close left tab` result can no longer be retried, because `pick` (`st-worker.sh:236-240`) needs the marker, which is now gone. The user closes the tab by hand. Before this change, a retry worked in this case.
- R4: U4's 2 s limit is not measured. On a fresh machine on a slow link, a cold `bunx` download may never finish. The `ponytail:` line says what to do.
- R5: U3 `git diff HEAD` fails in a repo with no commit, and the check then passes with no hits. Today it behaves the same way for staged files.
- R6: the U6 `system-atlas` commit may not be traceable. In that case U6 stops and reports.
- R7: under option B, U7 points the kept Advisor rows at U8's new file. Run U7's test after U8 lands.
