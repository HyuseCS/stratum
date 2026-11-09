# Implementation Plan: The orchestrator sees and answers every worker prompt in autonomous mode

**Branch**: `093-autonomous-prompts` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: `specs/019-autonomous-prompts/spec.md`, decisions D2-D9 in `decisions.md`, research in `research.md` (Round 1 by st-research, `## Decisions` P1-P7 by st-plan).

**Status**: no open decision. User decisions D13 (one shared commit check, `HEREDOC_MESSAGE` deleted), D14 (Esc in the Codex tab stays "stop"), D15 (keep the cut-off-dialog No flow), D16 ("not at all" marker, turn-on hint, FR-016), D17 (`approve --input-hash`, FR-017) and D18 (keep D17 for its own sake) are in `decisions.md`.

## Summary

Four changes, built in the order of D2 (US1, US2, then US4; US3 after US1).

1. US1: `scripts/st-worker.sh` hashes only the dialog block: from the dialog's top rule line (a line of only `─`) through the last option line. `wait`, `watch` and `answer` use one helper. Lines outside the block may change. A dialog whose top rule is not in the 40-line read, but with exactly one HEAD line and an option line, keeps today's whole-screen hash, and `answer` sends only an allowed No for it, never a yes (the cut-off No flow of 837282c, D15). Two HEAD lines or no option line: no `screen` line, and `answer` refuses (research P1, live capture of 2.1.319). The block starts at the top rule line; "title line" means the HEAD line only. The same story also carries D17 (FR-017), because it owns `scripts/st-worker.sh` and lands first: `approve` takes `--input-hash <64 hex>` of the rendered request in place of `--input-stdin` and a heredoc, and `wait`/`watch` print `inputhash` after `input`. D18 keeps it for its own sake: the approve call no longer carries the request text in a heredoc, and the Bash description names the action (`contracts/commit-form.md` §4b).
2. US2: `hooks/st-git-guard.py` denies, in every session and every commit mode, a command that has a `git commit` part and holds `<<` or a match of the approve hook's `SUBSTITUTION` regex. The reason is one fixed line that names `git commit -m 'subject' -m 'body'`. The check is one function, `unjudgeable`, in `hooks/st-approve.py`. The guard loads it by path, and the approve hook's `commit_check` uses it in place of its `HEREDOC_MESSAGE` whitelist, which is deleted (D13). A plain `-m` commit goes on to the approve channel as today, with the full command, the branch and the staged files (research P2, P3).
3. US3: `st-init` asks once where to set `includeGitInstructions: false` (project, user, local, not at all). `st-update` asks the same once for a checkout that has it at no level and no "not at all" marker (`.stratum/git-instructions-kept`, written on that answer), as a one-time step with a `ponytail:` note. `st-worker.sh autonomous-on` prints a one-line hint when the instructions are not off at any level, and never blocks (FR-016, D16). `agents/st-git.md`, the session text and worker brief rule 5 say `git commit -m 'subject' -m 'body'` (research P5, P6, P7).
4. US4: `scripts/st-codex-agent.sh` reads the answer from Codex's session log (`task_complete.last_agent_message`, found by the nonce), never from the screen. No log within 15 tries: exit 6, and `scripts/st-advisor.sh` runs the review headless with `codex: headless (no session log)`. A review the user stopped with Esc (`turn_aborted` after this review's prompt line) ends `BLOCKED: the review was stopped in the Codex tab`, with no headless run (research P4, D14).

## Technical Context

**Language/Version**: Bash 5 (`scripts/st-worker.sh`, `scripts/st-codex-agent.sh`, `scripts/st-advisor.sh`, `hooks/st-session-start.sh`), Python 3 stdlib (`hooks/st-git-guard.py`, `hooks/st-approve.py`, the inline readers in the scripts), Markdown (skills, agent).

**Primary Dependencies**: herdr (worker and Codex tabs, through the existing test stubs), git, jq (already used), `sha256sum`. Claude Code 2.1.319 and codex-cli 0.167.0 as installed (research Round 1). No new dependency.

**Storage**: none new. Reads `${CODEX_HOME:-~/.codex}/sessions/**/rollout-*.jsonl` (read-only). US3 writes one key in one Claude Code settings file chosen by the user.

**Testing**: `bash tests/<file>.sh`, `python3 tests/<file>.py` (unittest). Every fixture lives in `mktemp -d` or `tempfile.TemporaryDirectory`. `CODEX_HOME` points into the temp folder in every Codex test.

**Target Platform**: Linux and macOS shells where Claude Code, herdr and Codex run (PC and laptop, cross-machine rule).

**Project Type**: Claude Code plugin (skills, agents, hooks, scripts).

**Performance Goals**: the git guard runs on every Bash call. Loading `hooks/st-approve.py` adds one module load (stdlib imports and a few regex compiles) per call. No other new cost.

**Constraints**:
- The build runs in worker worktrees. Lock 2 (`hooks/st-approve.py:95-113`) denies a Bash call whose text names `.stratum/approve`, `.stratum/autonomous`, or `st-worker.sh` followed by a word in `RISKY`. The approve `NEVER` list (`:27-38`) keeps a call with `.claude`, `.stratum` or `.env` in its text from the approve channel. So no `Test:` line and no task command may contain those strings. Run the test files only.
- `hooks/st-approve.py` keeps every refusal it has today (`COMMIT_NEVER`, the option lists, owns, branch, `NEVER`, lock 2). The only change is that `HEREDOC_MESSAGE` goes and the shared check replaces it (stricter, never looser; D9, D13).
- `st-advisor.sh answer` (the Codex tab's own screen hash) does not change (decisions.md small decision).
- The screen is never a source for the Codex answer, also not as a last fallback (FR-011, CHK010).

**Scale/Scope**: a few workers and one Codex tab per workspace.

## Constitution Check

No `.stratum/constitution.md` exists in this repo and no app has an `ORDINANCE.md` (memory: base repo has no constitution). No gate applies. Re-checked after Phase 1: still none. Decisions D2-D9, D13 and D14 act as the rules for this feature. The plan follows them. D13 replaces the "stays as it is" part of D9 for `HEREDOC_MESSAGE` only.

## Security notes

Tasks that touch access rules, the approve channel, settings files, personal data or an external service:

| Area | Story | What changes | Note |
|------|-------|--------------|------|
| Dialog answers (access) | US1 | The hash that binds the judged dialog to the answered dialog covers the block, not the screen. | Fails closed: two HEAD lines, no option line, or a changed block line gives no answer. A dialog with no visible top rule keeps the whole-screen hash and may get only a No, never a yes (D15). The option allow list (one-time yes, plain No with no lasting or host words) does not change. Command lines carry the `│ ` prefix, so a command cannot draw a fake top rule (P1). The orchestrator still reads the whole 40-line pane text. |
| Approve call (access) | US1 (D17) | `approve` binds the judged request to the approved one by a hash of the rendered text, not by the text on stdin. | Full 64-hex sha256: the worker writes the request text, so a 12-hex hash would let it search for a colliding second request. Mismatch refuses with today's line; the 4000-character limit and the record line stay. |
| Commit approval (access) | US2 | The guard denies the forms the approve channel cannot judge, in every session. | The deny is stricter only. The approve channel's other refusals stay (CHK007). `git push` stays `ask` in the guard and on the `NEVER` list (FR-007, CHK008). The guard loads code from `hooks/st-approve.py` by its real path next to the guard, not from `sys.path`. The load fails closed: on any load error the guard does not crash, and every git command gets `ask` with a reason that names the error (`contracts/commit-form.md` §1). The approve hook drops its heredoc-message whitelist (D13), so it refuses more, never less. |
| Settings files | US3 | `st-init` and `st-update` write `includeGitInstructions: false` into one file the user picks. | The user scope writes the global `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`, only on the user's answer. Every write merges one key with jq and keeps every other key (CHK015). "Not at all" writes no settings file, only the empty marker `.stratum/git-instructions-kept` (CHK014, D16). The `autonomous-on` hint only reads the three settings files and the env var. No secret is read or written. |
| Personal data | US4 | The advisor reads the user's own Codex session logs. | Read-only, local, only files changed since this review's prompt file, only `task_complete` and `turn_aborted` records and the user prompt line that holds this review's prompt file path (D14). Nothing is written, moved or copied out of the log folder except the answer text between this review's markers, into the review's own temp answer file (CHK013). The log content is never printed. |
| External service | US4 | A tab review with no log runs again headless (`codex exec`), which sends the review prompt to OpenAI a second time. | Accepted cost in D5. The headless path is today's path: read-only sandbox, `--ignore-user-config`, `--ephemeral`, the same 60 s floor. |

## Project Structure

### Documentation (this feature)

```text
specs/019-autonomous-prompts/
├── spec.md
├── decisions.md
├── research.md                  # Round 1 (st-research) + ## Decisions P1-P7 (st-plan)
├── plan.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── dialog-block.md          # US1
│   ├── commit-form.md           # US2
│   ├── git-instructions.md      # US3
│   └── codex-log.md             # US4
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
scripts/st-worker.sh             # US1: HEAD :168, screen() :170, st blocked :161, answer :445-484; D17: approval() :214-223, approve :675-680, option parse :17. US3: brief rule 5 :253, autonomous-on hint :695-705
hooks/st-git-guard.py            # US2: commit seen in check() :279-302 and the fallback :336-343, deny before the output :344-349
hooks/st-approve.py              # US2: new unjudgeable() next to SUBSTITUTION :41; HEREDOC_MESSAGE :40 deleted; commit_check :194-195 (D13)
skills/st-init/SKILL.md          # US3: new step 12, Report becomes step 13
skills/st-update/SKILL.md        # US3: one-time paragraph at the end of step 6, path in step 7
agents/st-git.md                 # US3: step 6 form, Rules exception for the form deny
skills/st-worker/SKILL.md        # US1 (D17): :31 approve call with --input-hash, no heredoc
skills/st/SKILL.md               # US3: :89 show the autonomous-on lines, hint included (FR-016)
tests/test_worker_rules.sh       # US1 (D17): row W3; US3: row W8 follows :89
hooks/st-session-start.sh        # US3: one sentence in the Stratum rule line :25
scripts/st-codex-agent.sh        # US4: log reader replaces the pane scrape :128-138
scripts/st-advisor.sh            # US4: exit 6 maps to codex: headless (no session log) :253-258
tests/test_st_worker.sh          # US1 cases; US3 rule 5 text :237
tests/test_git_guard.py          # US2 guard cases
tests/test_approve_hook.py       # US2 shared-table test (both hooks)
tests/test_update_rules.sh       # US3 text rows
tests/test_session_hooks.sh      # US3 session sentence
tests/test_codex_agent.sh        # US4 reader cases
tests/test_advisor_matrix.sh     # US4 fake herdr writes a log; no-log case
```

**Structure Decision**: no new file in `hooks/` or `scripts/`. The shared commit test lives in `hooks/st-approve.py` and the guard loads that file by path (`importlib.util.spec_from_file_location`, name `st_approve`). A new module would need a new harness model element (`tests/test_harness_model.sh` coverage lists every file under `hooks/`). `docs/harness/` does not change.

## Story dependencies

- US1, US2 and US4 share no file. They can be built at the same time. D2 sets the merge order: US1, US2, US4. Keep US1's T002 (D17) merged before US2's T005 as order hygiene: both change how commits reach the orchestrator, and live check L1 tests them together.
- US3 shares `scripts/st-worker.sh` (brief rule 5, the `autonomous-on` hint) and `tests/test_st_worker.sh` with US1. Build it after US1.
- Phases 6 and 8 end with one integration task that runs the shared suites once; each build task in them runs only its own narrow check.
- US3 does not need US2 to pass its own tests. Its text names the deny reason prefix `Commit form denied:` from `contracts/commit-form.md`.

## Complexity Tracking

None. No constitution rule is broken.

## Validate

Date: 2026-11-09. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | none. Installed: Claude Code 2.1.319, codex-cli 0.167.0, herdr 0.9.4, jq 1.8.2, Python 3.14.9, bash 5.3.20, sha256sum 9.12 (already used at `scripts/st-worker.sh:170`), git 2.56.0. Every test file the tasks name exists. Baseline on this checkout: `test_st_worker.sh`, `test_worker_rules.sh`, `test_git_guard.py`, `test_approve_hook.py`, `test_update_rules.sh`, `test_session_hooks.sh`, `test_codex_agent.sh`, `test_advisor_matrix.sh` exit 0. No new dependency. |
| 2. Test coverage per requirement | CONCERN | F13, F14, F6, F8, F10 |
| 3. Breaking changes | CONCERN | F11. F1 and F2 of the first pass are closed. Callers of the removed `approve --input-stdin`: `skills/st-worker/SKILL.md:31` (T002), the approve cases of `tests/test_st_worker.sh` (T001), row W3 `tests/test_worker_rules.sh:12` (T001); `tests/test_approve_hook.py:116`, `:644` hold the old flag only as lock 2 text and still pass. `HEREDOC_MESSAGE` removal refuses the `$(cat <<'EOF'` commit by design (D13); `agents/st-git.md` follows (T011). New exit 6 of `st-codex-agent.sh`: its one caller `scripts/st-advisor.sh` (T018). No stored data migrates; rollback is a revert, plus removing the `includeGitInstructions` key or the `.stratum/git-instructions-kept` marker by hand. |
| 4. Security and privacy | PASS | none. Each access change (block hash, input hash, commit deny), the settings writes, the Codex log reads and the second OpenAI call has a Security notes row and a test or a live step. Note: the hash-only `approve` call shows the orchestrator's permission layer no request text; the D17 Bash description sentence follows the dialog pattern of `skills/st-worker/SKILL.md:28`. No secret is read or written. |

F1 (first pass) is closed. `--input-stdin` and `ST_INPUT_END` remain only at `skills/st-worker/SKILL.md:31`, which T002 replaces. The new call (`approve <id> --request <rid> --input-hash <64 hex> --record <f>`) has no `<<`, no `SUBSTITUTION` match and no `git commit` part. No other orchestrator call path in `skills/` or `agents/` uses a heredoc (`st-pr` uses `--body-file`).

F13. contracts/commit-form.md:89 (row H1), tasks.md:51 (T003), tasks.md:52 (T004) — High. H1 expects the §3 deny, but rule §2 (a) is false for it. The heredoc body is the rendered `input` line, `Bash: {"command":"git add src/a.py && git commit -m x"}`. `segments()` reads the JSON string as one double-quoted token, so `parse_git` finds no `commit` and no `ValueError` sends it to the fallback (run on this checkout for P1-P4 bodies too: no git sub; `hooks/st-git-guard.py` run on H1 in a temp repo prints no decision). Only a raw body (`git add src/a.py && git commit -m x`) parses as a commit; that was the first-pass F1 run. After a correct T005, the H1 assertions of T003 and T004 fail. The same wrong cause is in decisions.md:17 (D17), plan.md:13, plan.md:108 and tasks.md:131 (the T005-after-T002 merge rule). -> st-plan: H1 expects no decision from the guard (keep `unjudgeable(H1)` true), or drop H1, since IH5 already proves `--input-stdin` is gone; fix the cause text. User decision: confirm D17 stays. It still removes `<<` from the orchestrator's Bash text and is tested by IH1-IH5, but it was not needed to unblock US2.
F14. tests/test_st_worker.sh:1392 (AP6), tasks.md:31 (T001) — Low. T001 lists the `apv` helper and five direct heredoc calls. AP6 feeds `apv < <(printf ...)`, not a heredoc, and the nine `apv <<'ST_INPUT_END'` call sites (`:1336`-`:1420`) are not listed. AP6 keeps its meaning with any 64-hex hash, since the 4000-character check runs before the compare. -> st-plan: name AP6 and the `apv` call sites in T001.
F6. tasks.md:51 (T003), tasks.md:60 (T005) — Low, not fixed. T003 checks the reason starts with `The git guard could not load`. T005 does not say when the load-error `ask` is noted. In commit mode `ask` the scan notes `git commit (commit: ask)` first, and `main()` joins reasons in that order. -> st-plan: note it before the scan, or check that the reason contains the text.
F8. tasks.md:147-148 (FR-008, FR-009) — Low. Only `grep -qF` text rows; the jq merge, the scope pick, the marker and "ask once" are checked only in live step L4. -> No action: skill text an agent runs, live step L4 covers it.
F10. tasks.md:154 (FR-015) — Low. FR-015 is live only (T020). -> No action: accepted by D7.
F11. scripts/st-advisor.sh:253-258, scripts/st-worker.sh — Medium. Merge order with #94, built in another worktree. #94 changes the Codex tab name in `st-advisor.sh` (the tab result case T018 edits) and `st-worker.sh` start, close and list; T002 and T013 edit `st-worker.sh`. -> User decision on merge order. Rebase the second one, then run `bash tests/test_advisor_matrix.sh`, `bash tests/test_codex_agent.sh` and `bash tests/test_st_worker.sh` again.
