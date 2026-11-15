# 004 lane-rules-103

What: Fix issue #103 in three parts. (1) Lane briefs name Write and Edit as the only way to change a file, and before the orchestrator accepts a lane it runs a new script over the lane's transcript that lists shell file writes in its Bash commands; a match sends the lane back. (2) A quiet repo while an advisor point runs: rule lines, plus the same snapshot check the Codex tab path has, now also around the headless `codex exec` run in `st-advisor.sh`. (3) A task that names an operator check as a gate states the action it gates; tasks.md and quickstart.md carry the same gate; `st-inspect` flags a gate with no named action.
FRs: none in spec.md covers it (workflow rules from issue #103). Nearest: FR-001 (advisor points), FR-027 (rule rows in `tests/test_lane_steps.sh`).
Impact area: core runtime

## Files
- scripts/st-shell-writes.sh (new) - `st-shell-writes.sh <transcript.jsonl>...`. Reads each JSONL line of type `assistant`, takes the `command` of every `Bash` tool_use, and prints each command that matches a shell file write: a heredoc (`<<` not part of `<<<`), `cat >`, `tee`, `sed -i`, or an `echo` or `printf` redirect to a file (`>` or `>>` not followed by `&`). Exit 1 on a match, 0 on none, 2 on a missing or unreadable file. Only Bash commands are read, so a Write call or a brief that quotes `<<` does not match.
- skills/st/SKILL.md - at the brief rule (near line 46) add: every brief for a code or docs lane says "Change a file only with the Write or Edit tool, never with a shell write in Bash." After "Before accepting code from a subagent" (near line 73) add: "run `bash <plugin root>/scripts/st-shell-writes.sh <the lane's output file>`; a match sends the lane back." Next to the advisor rules add: "While an advisor point runs, run no `st-git`, start no lane and change no file in the review folder. The next lane starts after the point returns."
- agents/st-quick.md, agents/st-inspect.md, agents/st-research.md - the same Never line the other file-writing agents have (`agents/st-build.md:78`): "Write or change a file through Bash (a heredoc, or an echo or printf redirect). Use the Write or Edit tool." These three agents have Write or Edit and lack it.
- scripts/st-worker.sh - one new Facts line in `brief()` (not in the team rules, so #97's rule 5 edit does not conflict): "- Files: change a file only with the Write or Edit tool, never with a shell write in Bash (`<<`, `cat >`, `tee`, `sed -i`, an echo or printf redirect)."
- scripts/common.sh - move `snap()` here from `scripts/st-codex-agent.sh` unchanged (with its ponytail line), and add `snapdiff <before> <after>` with the path-list pipeline now inline at `st-codex-agent.sh:120`. One snapshot code for both paths, so the headless check keeps the index coverage (`git diff --cached --raw`).
- scripts/st-codex-agent.sh - source `common.sh`, delete its own `snap()`, and use `snapdiff` in the BLOCKED line. Behaviour unchanged.
- scripts/st-advisor.sh - source `common.sh`. Around the headless `codex exec` line only (the tab path already checks inside `st-codex-agent.sh`): when the cwd is in a git work tree, `before=$(snap)` right before the run (`block "cannot read git status"` on failure), `after=$(snap)` right after; a difference calls `block "files or HEAD changed during the review: $(snapdiff ...)"`. This runs before the record step, so the script's own advisor.md write is outside it. Covers every point that runs Codex (plan, test, diff, decisions, change, review, round).
- skills/st-build/SKILL.md - Advisor section: line 95 "Change no file in that folder until the point ends" gets "and run no `st-git`". The existing `BLOCKED: Codex changed files during the review: <paths>` handling line (line 120) also names `BLOCKED: files or HEAD changed during the review: <paths>`, so the same user-controlled recovery applies: show the paths, revert nothing, the user decides to run the point again or `continued`.
- agents/st-inspect.md - new check C11: "a task that names an operator check as a gate without naming the action it gates (the build or the first release), or a gate in tasks.md that quickstart.md words differently or lacks" is a finding.
- agents/st-plan.md - one line: a task that names an operator check as a gate states the action it gates (the build or the first release); tasks.md and quickstart.md carry the same gate.
- templates/tasks.md - one line in the marker legend: an operator check as a gate names its action.
- tests/test_shell_writes.sh (new) - see Tests.
- README.md - name `tests/test_shell_writes.sh` where the other tests are listed (`tests/test_inspect.sh:128-131` checks every test file is named there).
- tests/test_lane_steps.sh - new rows 30 to 33 (has): the three `skills/st/SKILL.md` lines and the st-build `files or HEAD changed` handling text. Rows 1 to 29 are taken.
- tests/test_advisor.sh - new checks G-fp1 to G-fp4 (see Tests).
- tests/test_inspect.sh - new phrase row C11.
- tests/test_plan_rules.sh - new rows DL19 (agents/st-plan.md) and DL20 (templates/tasks.md).
- tests/test_worker_rules.sh or tests/test_st_worker.sh (whichever checks brief lines) - the brief has the Files line; and the three agents have the Never line.

## Tests (written first, must fail before the build)
- tests/test_shell_writes.sh - JSONL fixtures in a temp folder. Exit 1 and the command printed for: a Bash heredoc write, `cat > f`, `tee f`, `sed -i`, `echo x > f`. Exit 0 for: a Write call whose content has `<<` and `cat >`, a Bash `cat f`, `echo x >&2`, a here-string `<<<`, the same heredoc text in a user message (not a Bash call). Exit 2 for a missing file. Negative control: the exit-1 cases prove it fails; the Write-call case proves the scope. Command: `bash tests/test_shell_writes.sh`.
- tests/test_advisor.sh G-fp - headless runs in a scratch `git init` repo with one commit and a staged change. Fake `codex`: G-fp1 commits; G-fp2 writes an untracked file; G-fp3 replaces the staged blob only (index-only change, worktree file the same); each exits 1 with `BLOCKED: files or HEAD changed during the review` and a BLOCKED record. G-fp4 (negative control): fake `codex` changes nothing, verdict `APPROVED`, exit 0. With the compare removed from the script, G-fp1 to G-fp3 go red. Command: `bash tests/test_advisor.sh`.
- tests/test_lane_steps.sh rows 30 to 33, tests/test_inspect.sh C11, tests/test_plan_rules.sh DL19 and DL20, the worker brief row - each phrase is in its file. Negative control: remove one phrase, that row goes FAIL.
- The existing tab tests (`tests/test_codex_agent.sh`, `tests/test_advisor*.sh`) stay green: they prove the `snap` move kept the tab check.
- Whole suite: the user's goal for this worker names `for t in tests/test_*.sh; do bash "$t" >/dev/null 2>&1 || { echo "FAIL $t"; exit 1; }; done; python3 -m unittest discover -s tests -p "test_*.py"`, so it runs once at the end (FR-005: the user asked).

## Risks
- Items 1 and 3 rule lines only state the rule. The transcript script and the snapshot check are the two checks that can fail.
- The transcript script can flag a harmless heredoc (an inline Python read). The rule says a match sends the lane back; the lane redoes that step with the Write or Edit tool or without a heredoc.
- Item 2 now blocks a headless point when anyone changes the review folder, the user included. That is the issue's wish, and the tab path already does it.
- Moving `snap()` touches `st-codex-agent.sh`. The tab tests guard it.
- Overlap with issue #97 (other worker): both may touch `skills/st/SKILL.md`, `scripts/st-worker.sh` and `tests/test_lane_steps.sh`. New lines sit away from the commit rules; rows 30 to 33 are told to worker-i97. This change does not touch `hooks/`, `tests/test_git_guard.py`, `agents/st-git.md` or the team rule 5 text.
