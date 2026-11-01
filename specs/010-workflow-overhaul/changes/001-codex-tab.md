# 001 codex-tab

What: Build the herdr Codex tab path that spec 010 skipped (T050 failed). T050 re-run (2026-11-01) passes with a `config.toml` that sets `trust_level = "untrusted"` for the project root, plus one `enter` on Codex's "Folder access" screen. Outside herdr, or when the tab path fails to start, Codex stays in the background (`codex exec --ignore-user-config`).
FRs: FR-013 (also FR-012, FR-014 to FR-016 touched by T023 and T018)
Impact area: core runtime

Lane note: the change adds a Stratum-owned `CODEX_HOME` and links the user's login (`auth.json`) into it. Spec 010 already covers this (D25, R-J, security notes S1 and S2, contracts/scripts.md sections 1.5 and 2), so no new spec is needed. If the orchestrator counts the login link as "sign-in", move to Full. No change to `~/.codex/config.toml` or `~/.codex/auth.json`; the auth target is never deleted.

## Changes to the 010 text (from the re-run)

- C1. `codex-home` makes `<dir>` (mode 700) with `auth.json` (symlink) and `config.toml`. `config.toml` holds `[projects."<abs project root>"]` and `trust_level = "untrusted"`. A `-c` override does not work, so it must be the file. Codex adds `[tui]` keys later; the `projects` entry stays.
- C2. One home serves many projects. `codex-home` runs from the project root, so each run appends that root's entry when `grep -qxF '[projects."<root>"]'` fails (with a leading newline if the file does not end in one). It never rewrites other lines. Only `codex-home` writes `config.toml`: a review run never writes it. A run whose root has no entry takes the `codex exec` path, as with a missing `auth.json` link. A root path holding `"`, `\` or a control character skips the entry with one printed line (no escaping code), so that project uses `codex exec`.
- C6. R19 and R20 come back (the "T050 passes" state of T022): st-init step 11 and st-build run `codex-home` on opt-in. Old R7 and R17 rows (git show d0b3aaa:specs/010-workflow-overhaul/contracts/phrases.md) are used verbatim; R17's "holds only a link to your Codex login" also names `config.toml`.
- C7. Fallback is not silent: before `codex exec` runs after a failed tab path, `st-advisor.sh` prints the tab path's last `ERROR:` line.
- C3. `<dir>` holds `auth.json` and `config.toml` (plus what Codex writes). The "only `auth.json`" wording in contracts/scripts.md 1.2 and R-J changes to "`auth.json` and `config.toml`".
- C4. Folder access screen (see "Detection" below). Tab path sends one `enter`, then the prompt.
- C5. The "trust dialog, pick do-not-trust" error text for `agent_not_ready` is replaced (see "Detection").

## Detection and answer of the Folder access screen

Where: `scripts/st-codex-agent.sh`, step 3, right after `agent start` returns (success, or error `agent_not_ready`).

1. Read the pane: `herdr agent read <name> --source recent-unwrapped --lines 60`, strip ANSI, test for both `Folder access` and `Open restricted`.
2. If it shows: `herdr agent send-keys <name> enter` (one key, option 1 is the default). Then poll `agent read` (up to 20 tries, 1 s apart) until the screen no longer holds `Folder access`. Send `enter` at most once per start.
3. If it does not show (a later start with the same `CODEX_HOME` may skip it): send nothing, go to the prompt step.
4. `agent_not_ready` from `agent start` is not fatal by itself. Do step 1 on it too, since the screen can keep the agent "not ready". After the `enter` and the poll, go to the prompt: if the agent is still not ready, the prompt call errors (`ERROR: <first line>`, exit 1). No `agent get` re-check. `agent_not_ready` with no Folder access screen, or the screen shows something else (for example the old `Trust this folder?`, or a login screen): `ERROR: Codex waits for an answer at start in its Codex tab. It did not show the Folder access screen. Check the tab, then run the point again.`, exit 1. The caller (`st-advisor.sh`) then falls back to `codex exec` (see T023 below).
5. The old "Trust this folder? ... Trust and continue" text is treated as unknown: the script never sends a key for it (option 1 there trusts the folder and loads project config).

## Files (each owned by exactly one step)

- S1 Test first, owns `tests/test_codex_agent.sh` (new) - see Tests.
- S2 Test first, owns `tests/test_advisor_matrix.sh` - add (k), keep (k2), add (n) updates. Also `tests/test_advisor.sh` is not changed (it already runs the matrix test).
- S3 Build, owns `scripts/st-codex-agent.sh` (new) - contracts/scripts.md section 2 with C4, C5. Depends on S1.
- S4 Build, owns `scripts/st-advisor.sh` - mode `codex-home` (C1, C2, C3 file write, 700, idempotent, exit 1 `no codex login: run codex login, then run this again` when the login file is missing); the herdr path in the run step (contracts 1.5: `timeout -k 10 540 bash st-lock.sh --name codex-<ws> --timeout 50 -- bash st-codex-agent.sh <feature dir> <prompt> <answer> <dir> [-m ..] [-c ..]`) used only when `HERDR_ENV=1`, `HERDR_WORKSPACE_ID` set, `herdr` on PATH, `<dir>/auth.json` is a symlink, and `config.toml` has the root entry (C2). Exit 75 from the lock gives `BLOCKED: Codex agent busy with another review`. Any other non-zero exit from `st-codex-agent.sh` falls back to `codex exec --ignore-user-config` for that run (new: the 010 text blocked; this plan falls back, as the brief says "if the tab path fails"). Exit 75 does not fall back. Exit 124 or 137 from the tab path prints `ERROR: Codex tab timed out` before the fallback. The fallback gets only the time left of the 540 s (`540 - SECONDS`); under 60 s left it blocks with `timed out` and runs no `codex exec`. Without the tab path, `codex exec` keeps the full 540 s. The usage line and the Python validator stay. Depends on S2, S3.
- S5 Docs and rule text, owns `specs/010-workflow-overhaul/contracts/phrases.md`, `tests/test_risk_rules.sh`, `skills/st-build/SKILL.md`, `README.md` - R7, R17, R19, R20, R21 and the "T050 failed" paragraph. Depends on S4. C6 applies:
  - R7, R17, R19 and R20: the old rows from `git show d0b3aaa:specs/010-workflow-overhaul/contracts/phrases.md`, verbatim, in phrases.md and `tests/test_risk_rules.sh` together. R17's "holds only a link to your Codex login" also names `config.toml`.
  - R21 (`README.md`): starts `The background call runs with`.
  - Also fix the README stale-link text if `codex-home` is mentioned in the setup table (add a `codex-home` step to the optional-Codex row only if the README already names how to set Codex up).
- S6 Record, owns `specs/010-workflow-overhaul/research.md` (R-J and line 295), `contracts/scripts.md`, `quickstart.md`. R-J: under the old T050 result, add `T050 re-run: PASS with config.toml trust_level untrusted and one enter` with the facts from the brief (config.toml content, Folder access screen, canaries did not fire, footer model not the global one, `auth.json` still a link, `[tui]` keys added, `-c` override fails, later-start screen not tested). Replace "not built, T050 failed" in contracts/scripts.md lines 21, 39, 47, 106, 121 and quickstart 20, 74, 81 to 93 with the real state. Depends on S4. Step T024 result goes to R-H (S7).
- S7 Live run (T024), owns `specs/010-workflow-overhaul/research.md` R-H entry, run after S3 to S6: quickstart section 0 step 2, then 3L steps 0 to 6 once in this herdr workspace. Record time, answer lines read, JSON parse, tab and agent names, whether Folder access showed on the second run (answers the open question in R-J), `test -L <dir>/auth.json`. A failure goes back to S3 or S4 with the first error line.
- Not touched: `tasks.md`, `.stratum/state.json` (the orchestrator ticks T018/T019/T021/T023/T024 and edits the "Not run, T050 failed" text there, as the brief says to leave them), `~/.codex/*`.

S6 and S5 touch different files from S1 to S4. S5 and S6 can run in parallel after S4. S1 and S2 can run in parallel.

## Tests (written first, must fail before the build)

### `tests/test_codex_agent.sh` (T019, new) - `bash tests/test_codex_agent.sh`

Stub `herdr` (script on PATH, logs one TAB-split argv line per call, ids with a random part per run, `agent read` prints plain text), temp project with `specs/010-demo/`, temp `<codex home>` with `auth.json` as a symlink and a `config.toml` holding the project root entry.

- (a0) `<codex home>` without an `auth.json` link: `ERROR: no Stratum Codex home`, exit 2, no herdr call.
- (a0b) NEW: `<codex home>/config.toml` without `[projects."<pwd>"]` and `trust_level = "untrusted"`: `ERROR: no Stratum Codex home`, exit 2, no herdr call. (A tab with no trust entry would show the trust dialog.)
- (a) no agent: `tab create --workspace <ws> --cwd <pwd> --label Codex --env CODEX_HOME=<codex home> --no-focus`, then `agent start st-codex-010 --kind codex --pane <stub pane> --timeout 120000 -- -s read-only -a never --no-alt-screen`; `-m m1 -c model_reasoning_effort="high"` come after `--no-alt-screen`.
- (b) `st-codex-010` already in this workspace: no `tab create`, no `agent start`.
- (c) `st-codex-009` in this workspace: `tab close <its tab_id>` before the new start.
- (d) `st-codex-010` in another workspace: ignored, new start here.
- (e) `agent_pane_busy` twice then ok: 3 start calls; busy always: exactly 10 start calls, then `ERROR:` and exit 1.
- (f) NEW, replaces the old trust text: stub `agent read` after start prints `Folder access` and `1. Open restricted` and `2. Back to Agent Command Center`: the log has exactly one `agent send-keys st-codex-010 enter`, and it comes after `agent start` and before `agent prompt`. The stub's `agent read` changes to the chat box screen after the key, so the script goes on to the prompt.
- (f1) NEW: start answers ok and the read text has no `Folder access` (a later start with the same home): no `send-keys` call, the prompt call runs.
- (f2) NEW: start gives `agent_not_ready` and the read text shows Folder access: one `enter`, then the prompt runs (the script recovers).
- (f3) NEW: start gives `agent_not_ready` and the read text shows `Trust this folder?` (or any other text): no `send-keys` call, `ERROR: Codex waits for an answer at start in its Codex tab. It did not show the Folder access screen. Check the tab, then run the point again.`, exit 1, no prompt call.
- (f4) NEW: Folder access still shows after the `enter` (stub never changes the screen): one `send-keys` only, then the same `ERROR:` as (f3), exit 1, no prompt call.
- (f5) the stub `agent prompt` replaces `<codex home>/auth.json` with a file: `ERROR: Codex replaced the login link in <codex home>; ...`, exit 1, no answer file.
- (g) the prompt file ends with the three lines of step 4 and a 12-hex nonce; the prompt argv ends `--wait --until done --until idle --until blocked --timeout <ms>` with `<ms>` at most 480000, smaller when the stub `agent start` takes 2 s.
- (h) prompt state `blocked`: `ERROR: Codex waits for an answer in its Codex tab.`, exit 1.
- (i) answer extraction: marker text inside other text, an earlier full pair around junk, and a last pair around JSON wrapped over 3 lines that start with `• ` or two spaces: the answer file is the JSON joined with single spaces and `python3 -c 'import json,sys; json.load(open(sys.argv[1]))'` reads it.
- (j) no pair: `ERROR: no answer between the markers`, exit 1.
- (k) feature dir `specs/demo`: `ERROR: feature dir must start with three digits`, exit 2.
- Red now: `scripts/st-codex-agent.sh` does not exist, so every case fails.

### `tests/test_advisor_matrix.sh` (T018 cases) - `bash tests/test_advisor_matrix.sh`

- (k) herdr path: `HERDR_ENV=1`, `HERDR_WORKSPACE_ID=ws<random>`, `XDG_STATE_HOME=<tmp>/state`, home made by `codex-home` run in the temp project, stub `herdr` (agent list empty, tab create, agent start, `agent read` with the Folder access text once then the answer text with markers and the nonce read from the prompt file, `agent prompt` done). `plan` prints `APPROVED sha256 <h>`, the stub `codex` saw no `exec`, the herdr log has `tab create ... --env CODEX_HOME=<tmp>/state/stratum/codex-home` and `agent start st-codex-001 --kind codex` and one `agent send-keys st-codex-001 enter`.
- (k1) NEW: the same, with the stub `agent read` never showing Folder access: no `send-keys`, still APPROVED.
- (k2) kept: herdr env, no Stratum Codex home: stub `codex` saw `exec`, stub `herdr` not called.
- (k3) NEW: herdr env, home present, stub `herdr agent start` gives `agent_not_ready` with an unknown screen: the stub `codex` saw `exec` (fallback), the output is a normal verdict, no `BLOCKED`.
- (k4) NEW: home present but `config.toml` lacks the project entry: stub `codex` saw `exec`, stub `herdr` not called, `config.toml` bytes unchanged.
- (k6) NEW: tab path fails with an `ERROR:` line (stub `agent read` never shows the markers): the output holds that `ERROR: no answer between the markers` line, then the stub `codex` saw `exec` and the verdict is APPROVED.
- (k5) NEW: lock held (exit 75): `BLOCKED: Codex agent busy with another review`, stub `codex` not called.
- (n) `codex-home` with `CODEX_HOME=<tmp>/user` holding `auth.json`, run from the temp project: prints `codex home: <tmp>/state/stratum/codex-home`; folder mode 700; entries are `auth.json` (symlink to `<tmp>/user/auth.json`) and `config.toml`, no others; `config.toml` has `[projects."<abs project root>"]` and `trust_level = "untrusted"`; a second run changes nothing (same `config.toml` bytes, no duplicate header); a run from a second project root adds a second entry and keeps the first; a `config.toml` that Codex extended with `[tui]` keys keeps those keys; with no `<tmp>/user/auth.json`: `no codex login: run codex login, then run this again`, exit 1, no folder; no other command makes the folder (after (a) to (m) it exists only if (n) made it).
- Existing cases (a) to (m) stay green (HERDR vars are unset there; `tests/test_advisor.sh` already unsets them).
- Red now: the `codex-home` mode and the herdr path do not exist (`usage:` line), so (k), (k1), (k3) to (k5), (n) fail.

### `tests/test_risk_rules.sh` (S5) - `bash tests/test_risk_rules.sh`
- R7, R17, R21 rows change to the new phrases (listed in S5), written in the same step as the doc edits. Red first: change the rows, run (fails against the old docs), then edit the docs.

### Full check
`bash tests/test_codex_agent.sh && bash tests/test_advisor.sh && bash tests/test_advisor_matrix.sh`, then `bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh && bash tests/test_advisor_rules.sh` for the doc rows.

## Risks

- Codex 0.166.0 screen text may change; the match is two plain strings (`Folder access`, `Open restricted`). A change makes the tab fail closed (ERROR, then `codex exec` fallback), never a blind key.
- Later start with the same home: the screen may or may not show; both cases are tested (f, f1). Not verified live until S7.
- `config.toml` is written by Stratum and rewritten by Codex (`[tui]` keys). The append edits only by adding a missing `[projects."<root>"]` block; it keeps all other lines. A project root with `"`, `\` or a control character in its path gets no entry, so that project uses `codex exec`.
- Fallback on any tab failure (S4) is new compared with the 010 text, which blocked. This follows the brief ("if the tab path fails, Codex stays background"). A hung `agent prompt` still ends under the 540 s `timeout`.
- The home links the user's login. Codex may replace the symlink with a copy on token refresh; the (f5) check and the 010 error line handle that. `auth.json` and `~/.codex` are never written.
- `herdr agent send-keys <name> enter` is the key command assumed from `herdr agent send-keys --help` (`<TARGET> <KEY>...`); the key name `enter` is confirmed by the brief's re-run.
