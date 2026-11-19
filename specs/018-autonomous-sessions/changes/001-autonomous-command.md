# 001 autonomous-command

What: A new skill, `/stratum:st-autonomous on|off`, turns autonomous build mode on and off. It replaces the plain words: "autonomous mode", "build with workers, autonomous" and "stop autonomous" no longer turn the mode on or off, and the orchestrator tells the user in one line which command to run. The automatic ends stay: the end of the Build or worker run, and before the handoff. GitHub #116, user decision 2026-11-20.
FRs: FR-009 (amended by D23), FR-010 (unchanged). Feature 010 FR-018 (superseded in part by D23).
Impact area: core runtime

Line numbers below are those of the files before the edit.

## Say-line readers
- No hook, script or statusline reads `Autonomous build mode: on for this run` or `Autonomous build mode: off`.
- On line today: `skills/st/SKILL.md:92` and row W8. After the build it is only in `skills/st-autonomous/SKILL.md` (row AU1).
- Off line: `skills/st/SKILL.md:93`, `skills/st-handoff/SKILL.md:10`, rows W9 and W35. After the build it is also in the new skill (row AU2).
- Spec history only: 010 `decisions.md:30`, 010 `contracts/phrases.md:116-117`, 018 `tasks.md:34,58`. The quickstart steps 1, 2 and 5 (lines 27, 28, 31) named the plain words; review fix F7 changed them.

## Files
- `skills/st-autonomous/SKILL.md` - new. The plugin finds skills by folder scan (`.claude-plugin/plugin.json` has no skill list). Exact text, each step on one physical line:
  ```
  ---
  name: st-autonomous
  description: Turn autonomous build mode on or off for this session.
  disable-model-invocation: true
  ---

  # /stratum:st-autonomous <on|off>

  Plugin root is two levels up from this skill's base directory.

  1. Accept only `on` or `off`. Anything else, or no value: run nothing and reply in one line: `Usage: /stratum:st-autonomous on|off`.
  2. `on`: run `bash <plugin root>/scripts/st-worker.sh autonomous-on`. Show its lines word for word (the `autonomous on` line and, when printed, the `hint` line). On exit 0, say `Autonomous build mode: on for this run`. Run this step only for the user's own `/stratum:st-autonomous on`. After the mode ends, never turn it on again yourself: say `Run /stratum:st-autonomous on to turn on autonomous build mode.` It makes only this session's entry in the main checkout, also from a linked worktree, and leaves the entries of other sessions alone. It ends when the Build or worker run ends, or when the user says they are done or will continue some other time (before the handoff): run step 3.
  3. `off`: run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` if workers ran in this session, else `bash <plugin root>/scripts/st-worker.sh autonomous-off`. Show its lines word for word. On exit 0, say `Autonomous build mode: off`. It removes only this session's entry.
  ```
  The end sentence in step 2 carries the automatic end for a session that never ran `/stratum:st`: the rules of `skills/st/SKILL.md` reach a session only through `/stratum:st`, `skills/st-worker/SKILL.md:43` covers only workers on a saved machine, and `skills/st-build/SKILL.md` does not end the mode.
- `skills/st/SKILL.md:92` - the whole line becomes:
  ```
  - Autonomous build mode turns on only when the user runs `/stratum:st-autonomous on`. Never run `st-worker.sh autonomous-on` yourself, and never ask a subagent or worker to. When the user asks in plain words to turn it on ("autonomous mode", "build with workers, autonomous"), turn nothing on, start no worker for that request, and say `Run /stratum:st-autonomous on to turn on autonomous build mode.` When the user asks in plain words to turn it off ("stop autonomous"), turn nothing off and say `Run /stratum:st-autonomous off to turn off autonomous build mode.`
  ```
  The line keeps its opening words. Line 95 of the old file ("Turn on autonomous build mode only as the line above that starts "Autonomous build mode turns on only when" says.") is deleted (review fix F5): it repeated line 92 and read as if the orchestrator turns the mode on.
- `skills/st/SKILL.md:93` - remove `when the user says "stop autonomous", ` and add `or ` before the handoff clause. Result:
  ```
    It ends when the Build or worker run ends, or when the user says they will continue some other time (before the handoff): run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` if workers ran, else `bash <plugin root>/scripts/st-worker.sh autonomous-off`. It removes only this session's entry. Show its lines word for word, and say `Autonomous build mode: off`. A new session never starts in it.
  ```
  The automatic ends call the script directly, not the skill, because `disable-model-invocation: true` stops the model from starting the skill. The skill's step 2 says the same end in the session where the user ran `/stratum:st-autonomous on`, where the skill text is already loaded.
- `skills/st/SKILL.md:94` - the whole line becomes:
  ```
  - When the user asks to open workspaces for agents to work in by themselves, use `/stratum:st-worker` (in autonomous build mode only when the user turned it on with `/stratum:st-autonomous on`), and a worker on a whole issue opens its own PR. `/stratum:st-herdr-workspace` stays a tool the user runs by hand.
  ```
- `skills/st-worker/SKILL.md:43` - `at the end of the run or on "stop autonomous", run` becomes `at the end of the run, run`. Nothing new takes its place: step 3 of the new skill runs `autonomous-off --roster` when the user turns the mode off. At the end of a saved-machine run, this line and the skill's step 2 can both run `autonomous-off`. The second run prints `autonomous off skipped` lines and exits 0, so it is harmless. The rest of the line does not change. The never list (line 34) does not change.
- `skills/st-worker/SKILL.md:59` - the line that starts "`/stratum:st-build` sends a phase's" gets one more sentence at its end (review fix F2):
  ```
  Never run `st-worker.sh autonomous-on` yourself: only the user's `/stratum:st-autonomous on` turns the mode on.
  ```
  The rest of the line does not change. AU11 pins the sentence.
- `README.md:116` - the line becomes:
  ```
  **Autonomous mode:** run `/stratum:st-autonomous on` to turn on autonomous build mode for this run only, and `/stratum:st-autonomous off` to turn it off. Only you turn it on: the orchestrator, a worker or a subagent never does. It also ends by itself when the Build or worker run ends, and before the handoff. The statusline shows `autonomous` while it is on.
  ```
- `README.md` - one new row after line 135 (the `st-worker` row):
  ```
  | `st-autonomous on\|off` | Turn autonomous build mode on or off for this session. Only you start it. |
  ```
  `tests/test_no_frontend_design.sh:13-15` and `tests/test_inspect.sh:112-114` compare the README skill rows with the `skills/` folders, so both go red without this row.
- `DESIGN.md:80` - `Twenty-seven entry skills:` becomes `Twenty-eight entry skills:` (the table has 27 skill rows today). One new row after line 101 (the `st-worker` row):
  ```
  | `st-autonomous on\|off` | Turn autonomous build mode on or off for this session. Only the user starts it (`disable-model-invocation: true`). |
  ```
  No test reads the count.
- `docs/harness/model/skills-tools.c4` - a new element after the `st-theme` element (after line 122), the twin of `st-shape`:
  ```
      st-autonomous = skill '/st-autonomous' {
        summary 'Turns autonomous build mode on or off for this session with st-worker.sh. Only the user starts it.'
        metadata {
          path 'skills/st-autonomous'
        }
      }
  ```
  Two edges at the end of the model block, after line 265:
  ```
    skills.st-autonomous -[runs]-> scripts.st-worker-sh 'autonomous-on, or autonomous-off with the roster file'
    skills.st-autonomous -[passes]-> user 'script lines and the mode line'
  ```
  No edge to `stratum.autonomous`: the script makes and removes the entry (`scripts.c4:178-179`). The `coverage-skills` check of `tests/test_harness_model.sh` goes red without the element.
- `docs/harness/model/skills-core.c4:90` - the edge `skills.st -[writes]-> stratum.autonomous 'session id for autonomous build mode'` is deleted, not relabeled (review fix F3). The script owns the entry: `docs/harness/model/scripts.c4:178-179`, see D9. `st` no longer turns the mode on.
- `docs/harness/atlas/data.mjs:84` - after `<code>scripts/st-worktree.sh</code>` insert `, <code>st-autonomous</code> to turn autonomous build mode on and off`, and after `<code>skills.st-worker</code>, ` insert `<code>skills.st-autonomous</code>, `. The `atlas` check needs every `skills/` folder in exactly one structure. Then rebuild `atlas.html` and `SYSTEM.md` with the build line in README.md (`t=$(mktemp -d) && cp ~/.claude/skills/system-atlas/assets/build.mjs ...`).
- `docs/harness/README.md` - regenerate with `npx -y likec4@1.60.0 export markdown docs/harness`. The `rebuild` check needs this. The regenerated file loses one line, the edge deleted at `skills-core.c4:90`.
- `specs/018-autonomous-sessions/decisions.md` - one line after D22:
  ```
  - D23 (change 001, GitHub #116, user 2026-11-20): `/stratum:st-autonomous on|off` replaces the plain words. Only the user's own `/stratum:st-autonomous on` turns autonomous build mode on, and the user turns it off with `/stratum:st-autonomous off`. The skill has `disable-model-invocation: true`, so the model cannot start it, and the orchestrator never runs `st-worker.sh autonomous-on` itself. Plain words ("autonomous mode", "build with workers, autonomous", "stop autonomous") turn nothing on or off: the orchestrator says in one line which command to run, and starts no worker for a plain-words turn-on request. The automatic ends stay: the end of the Build or worker run, and before the handoff (FR-010). Both `skills/st/SKILL.md` and the `on` step of the new skill teach them, so a session that never ran `/stratum:st` also ends the mode. This supersedes in this feature: US1 "The user says "autonomous mode"" (spec.md:16), US2 "the user says "stop autonomous"" (spec.md:42), the turn-on and "stop autonomous" parts of FR-009 (spec.md:104), the "stop autonomous" end of D20. In feature 010: FR-018 (spec.md:311), the "stop autonomous" end at spec.md:328, D9 (the orchestrator puts workers in autonomous mode), D21, D27 and D28. quickstart.md steps 1, 2 and 5 (lines 27, 28, 31) named the plain words; they now name the command. Rejected: the command beside the plain words.
  ```
- `tests/test_worker_rules.sh` - the tests below.

Not in scope:
- `scripts/st-worker.sh`: no change. Its `fail` lines say "cannot turn on autonomous mode" and "Autonomous mode needs them." (lines 254, 768-775). These name the mode, they do not teach a trigger. `tests/test_st_worker.sh` pins them (B5, ON6, ON9, `onbad`) and stays green.
- `hooks/st-approve.py` (worker block list, `RISKY`), `hooks/st-phase.py`, `scripts/st-update.sh`, `.claude-plugin/plugin.json`, `skills/st-handoff/SKILL.md`: no change. `st-phase.py:84-85` accepts `/stratum:st-autonomous` because the folder exists. The name is not in `PHASES` or `HELD`, so it changes no `state.json` field and only adds the reply label `[st-autonomous]`, as for `st-shape`. `st-update.sh` reads `skills/` by folder.
- `skills/st/SKILL.md:85`, `agents/st-build.md:46`, `agents/st-debug.md:44`, `skills/st-sync/SKILL.md:26` ("in their own words" for issues and tests): other rules, not this trigger.
- `skills/st-design/SKILL.md:144` "The autonomous mode's report": the Design lane mode, not this one.
- `specs/010-workflow-overhaul/contracts/phrases.md` W8/W9 and the 018 spec and tasks text: feature history. Quickstart steps 1, 2 and 5 now name the command (review fix F7). No test reads `phrases.md`. D23 records what they no longer mean.
- No new script, hook or plugin option.

## Tests (written first, must fail before the build)
All in `tests/test_worker_rules.sh`. Command: `bash tests/test_worker_rules.sh`.

- Row changes in the first `TABLE` (whole-file `grep -qF`). Each is red today because the new text is not there:
  - `W8` - its phrase becomes the whole new `skills/st/SKILL.md:92` line above, without the leading `- `. Break: a plain-words trigger put back, or the never sentence dropped.
  - `W9` - its phrase becomes the new line 93 above, without the leading spaces. Break: the handoff end or the `Autonomous build mode: off` line removed.
  - `W12` - its phrase becomes the new line 94 above, without the leading `- `. Break: the `/stratum:st-autonomous on` condition removed, so the orchestrator may use the mode on a plain-words request again.
  - `W17` - its phrase becomes the new `skills/st-worker/SKILL.md:43` text, with `at the end of the run, run`. Break: a plain-words end put back in the line.
- New rows in the same `TABLE`:
  ```
  AU1|skills/st-autonomous/SKILL.md|`on`: run `bash <plugin root>/scripts/st-worker.sh autonomous-on`. Show its lines word for word (the `autonomous on` line and, when printed, the `hint` line). On exit 0, say `Autonomous build mode: on for this run`.
  AU2|skills/st-autonomous/SKILL.md|`off`: run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` if workers ran in this session, else `bash <plugin root>/scripts/st-worker.sh autonomous-off`. Show its lines word for word. On exit 0, say `Autonomous build mode: off`.
  AU3|README.md|**Autonomous mode:** run `/stratum:st-autonomous on` to turn on autonomous build mode for this run only, and `/stratum:st-autonomous off` to turn it off. Only you turn it on: the orchestrator, a worker or a subagent never does.
  AU11|skills/st-worker/SKILL.md|Pass `--autonomous` to `start` only while autonomous build mode is on. Never run `st-worker.sh autonomous-on` yourself: only the user's `/stratum:st-autonomous on` turns the mode on.
  ```
  Red today: the file and the text do not exist. Break: AU1 or AU2 goes red when a say-line changes by one byte. AU3 goes red when the README line goes back to plain words. AU2 still matches step 3 byte for byte: the end sentence goes into step 2, and step 3 does not change. AU11 breaks when the line 59 sentence goes (review fix F2).
- Gone rows in the second `TABLE`: G24 and G26. Each is red today because the old text is there:
  ```
  G24|README.md|`stop autonomous` to turn it off
  G26|skills/st/SKILL.md|use `/stratum:st-worker` with autonomous build mode on
  ```
  Break: each goes red when its old sentence comes back. G21, G22, G23 and G25 are not added: AU7 already goes red on each of their old phrases (checked with `grep -E`).
- New `if` lines after the gone `TABLE`, in the file's `ok`/`FAIL` style:
  - `AU4 frontmatter`: both `head -n 5 "$root/skills/st-autonomous/SKILL.md" | grep -qx "name: st-autonomous"` and `head -n 5 "$root/skills/st-autonomous/SKILL.md" | grep -qx "disable-model-invocation: true"`. Red today (no file). Break: drop the key and the model can start the skill by itself. Twin of `tests/test_design_lane.sh:59`.
  - `AU5 usage line in step 1`. Scoped to step 1 with the `2. ` line left out, so a usage rule moved onto that line or after a script step goes red. Red today:
    ```
    sed -n '/^1\. /,/^2\. /{/^2\. /!p}' "$root/skills/st-autonomous/SKILL.md" | grep -qF -- 'Anything else, or no value: run nothing and reply in one line: `Usage: /stratum:st-autonomous on|off`.'
    ```
  - `AU6 only autonomous-on and autonomous-off`. Red today (empty output). Break: any other `st-worker.sh` command in the skill, for example `start`, goes red. A missing file also goes red. The end sentence of step 2 names no `st-worker.sh` command, so AU6 stays true:
    ```
    [ "$(grep -oE 'st-worker\.sh [a-z-]+' "$root/skills/st-autonomous/SKILL.md" | sort -u | tr '\n' ' ')" = "st-worker.sh autonomous-off st-worker.sh autonomous-on " ]
    ```
  - `AU7 no plain-words trigger`:
    ```
    (cd "$root" && grep -rqE '(say|says) ["`](autonomous mode|stop autonomous)|own words for this run|on "stop autonomous"' README.md DESIGN.md skills agents hooks scripts procedures templates statusline); [ $? = 1 ]
    ```
    Checked today: the pattern finds `README.md:116`, `skills/st/SKILL.md:92`, `:93` and `skills/st-worker/SKILL.md:43`, so it is red. `[ $? = 1 ]` makes a grep error (exit 2) red too. Break: "say `autonomous mode`" style text added back in any of these folders. The new line 92 quotes the old words as `turn it on ("autonomous mode"` and `turn it off ("stop autonomous")`, which the pattern does not match.
  - `AU8 st does not turn the mode on`. Red today (line 92 has it). Break: the orchestrator's run command for `autonomous-on` put back:
    ```
    [ -f "$root/skills/st/SKILL.md" ] && ! grep -qF -- 'bash <plugin root>/scripts/st-worker.sh autonomous-on' "$root/skills/st/SKILL.md"
    ```
  - `AU9 the on step ends the mode by itself`. The range is step 2 only: from the `2. ` line up to, and not including, the `3. ` line. Red today (no file). Break: the sentence removed, or moved into step 3 (the `off` step) or after it, where a session that only ran `on` would not read it as its own duty:
    ```
    sed -n '/^2\. /,/^3\. /{/^3\. /!p}' "$root/skills/st-autonomous/SKILL.md" | grep -qF -- 'It ends when the Build or worker run ends, or when the user says they are done or will continue some other time (before the handoff): run step 3.'
    ```
  - `AU10 the on step runs only for the user's command` (review fix F1). The range is step 2 only, as AU9. Red today (no file). Break: the sentence removed, or moved out of step 2.
    ```
    sed -n '/^2\. /,/^3\. /{/^3\. /!p}' "$root/skills/st-autonomous/SKILL.md" | grep -qF -- 'Run this step only for the user'\''s own `/stratum:st-autonomous on`. After the mode ends, never turn it on again yourself: say `Run /stratum:st-autonomous on to turn on autonomous build mode.`'
    ```
- Existing checks that stay green with no edit: `W5` (never list), `W11`, `W35` and `O2` (the handoff ends the mode first), the ON and OFF cases of `tests/test_st_worker.sh`, `tests/test_approve_hook.py:139-140`, TP2 of `tests/test_triage_rules.sh` (line 85). These go red after the build only when the README row, the c4 element or the atlas id is missing, and the plan adds each: `tests/test_no_frontend_design.sh` and `tests/test_inspect.sh` ("README skills"), `tests/test_harness_model.sh` (`coverage-skills`, `atlas`, `rebuild`, `summaries` with the 200 character limit).
- Commands: `bash tests/test_worker_rules.sh`, `bash tests/test_harness_model.sh`, `bash tests/test_no_frontend_design.sh`, `bash tests/test_inspect.sh`, `python3 -m unittest tests.test_phase_hook`.
- Full run: `for t in tests/test_*.sh; do bash "$t" >/dev/null 2>&1 || { echo "FAIL $t"; exit 1; }; done; python3 -m unittest discover -s tests -p "test_*.py"`.

## Live check (orchestrator, after the build)
In a new session started with `claude --plugin-dir /home/hyuse/Desktop/stratum` in this checkout. The folder `.stratum/autonomous/` already holds entries of other sessions, so check the entry by name, never for an empty folder. Step 2 is the first proof in this repo that a user can type a skill that has `disable-model-invocation: true` (`st-hallmark` is only read as a file).
1. Run `echo "$CLAUDE_CODE_SESSION_ID"; ls -A .stratum/autonomous/` in the session. Note the id and the list.
   Result: Not run as written. The scratch repo started with no entries, so the one new entry seen later was the session's own.
2. `/stratum:st-autonomous on`: expect `autonomous on	local`, the `hint` line when git instructions are on, and `Autonomous build mode: on for this run`. Then `test -f .stratum/autonomous/<id>` exits 0, and the statusline shows `autonomous`.
   Result: Passed. `autonomous on	local`, `Autonomous build mode: on for this run`, the entry `.stratum/autonomous/<session id>` was made, and the statusline showed `autonomous`. No hint line was printed. This is also the first proof that a user can type a skill that has `disable-model-invocation: true`.
3. `/stratum:st-autonomous off`: expect `autonomous off	local` and `Autonomous build mode: off`. Then `test -f .stratum/autonomous/<id>` exits 1, and `ls -A .stratum/autonomous/` equals the list from step 1.
   Result: Passed. `autonomous off	local`, `Autonomous build mode: off`, the entry was gone, and the statusline tag was gone. Not in the record: the folder listing compared with step 1, because step 1 was not run as written.
4. `/stratum:st-autonomous` with no value, and `/stratum:st-autonomous maybe`: one usage line each, no Bash call, no entry.
   Result: Passed. No value and `maybe` each gave `Usage: /stratum:st-autonomous on|off`, with no entry. Not in the record: whether a Bash call was made.
5. Type `/stratum:st autonomous mode`. The rules of `skills/st/SKILL.md` reach a session only through `/stratum:st` (the session start hook does not load them). Expect `Run /stratum:st-autonomous on to turn on autonomous build mode.`, no worker, and no entry.
   Result: Passed. `/stratum:st autonomous mode` gave `Run /stratum:st-autonomous on to turn on autonomous build mode.`, with no worker and no entry.
6. Ask in plain words: "start the st-autonomous skill with on". Expect that the model cannot start it, and no entry.
   Result: Passed. "start the st-autonomous skill with on" gave `Run /stratum:st-autonomous on to turn on autonomous build mode.` and no entry. Not in the record: a direct check that the model could not start the skill.
7. In a second new session that never runs `/stratum:st`: note its id, run `/stratum:st-autonomous on`, then run one small local worker with `/stratum:st-worker` on a one-line task and let it finish. When the run ends, expect `autonomous off	local` and `Autonomous build mode: off`, and `test -f .stratum/autonomous/<id>` exits 1. This step uses the end of the worker run, not "I am done for today". The session start hook already tells the session to run `/stratum:st-handoff` when the user is done, and `skills/st-handoff/SKILL.md:10` turns the mode off. So that end passes with or without this fix, and only the worker-run end proves the step 2 sentence.
   Result: Passed, with the final skill text, in a new session that never ran `/stratum:st`: `on`, then `/stratum:st-worker headless` on a one-line task (make `note.txt`, test `test -f note.txt`). The headless worker finished, the test exited 0, and the st-git agent committed the file. Then the session said "The worker run ended, so I turned the mode off", printed `autonomous off	local` and `Autonomous build mode: off`, and the entry was gone. Two limits: the worker was a headless one, not a worker in its own workspace, and the scratch repo had `.stratum/` in `.git/info/exclude`, because the headless clean-tree check (`scripts/st-worker.sh:840`) stops on the untracked entry `.stratum/autonomous/<id>`. A first run of this step, before the review fixes, stopped early with `Run headless inside a git repo with a commit.` and the session also turned the mode off by itself. After the end, the session also printed the line `Run /stratum:st-autonomous on to turn on autonomous build mode.`: it read the "say" of the step 2 sentence as a line to print when the mode ends.

Result after the review fixes, with the final skill text, in a new session that never ran `/stratum:st`: `on` and `off` passed again. The plain words "autonomous mode on" turned nothing on and gave the fixed line. Before it refused, that session searched the plugin files for "autonomous" and read the rule in `skills/st/SKILL.md:92`, so this run does not show that the step 2 sentence alone stopped it. These results are the orchestrator's record of 2026-11-20. Close did not run the steps again.

## Small decisions
- D1: The Skill tool guard is `disable-model-invocation: true` in the frontmatter. The repo already uses it for the same purpose (`skills/st-hallmark/SKILL.md`, 009 D22, `docs/lessons.md:314`). Reason: the model cannot start the skill at all. It does not stop a direct Bash run of the script (R4).
- D2: Plain words turn nothing on or off. The orchestrator says `Run /stratum:st-autonomous on to turn on autonomous build mode.` or `Run /stratum:st-autonomous off to turn off autonomous build mode.` Reason: the user's pick, and fixed lines can be pinned by a test.
- D3: For a plain-words turn-on request such as "build with workers, autonomous", the orchestrator starts no worker for it. Reason: a worker started without `--autonomous` stays in normal mode after the user runs the command, so it would not be the run the user asked for.
- D4: "stop autonomous" does not turn the mode off either. Reason: the user said the plain words no longer turn it on or off. The run's own end and the handoff still turn it off.
- D5: The say-lines come only on exit 0. Reason: after `cannot turn on autonomous mode: ...` or `autonomous off failed`, the line `Autonomous build mode: on for this run` or `Autonomous build mode: off` would be false.
- D6: Usage line `Usage: /stratum:st-autonomous on|off`, nothing more. Reason: the twin `st-shape` also only names its values and stops.
- D7: Line 94 of `skills/st/SKILL.md` and its pin W12 change. Reason: "with autonomous build mode on" told the orchestrator to use the mode on a plain-words request.
- D8: The new tests go in `tests/test_worker_rules.sh` with the prefix `AU` and gone ids `G24` and `G26` (`G21`, `G22`, `G23` and `G25` are dropped, see Tests). Reason: W8, W9 and W17 already live there, and the file reuses W30-W33, so a new prefix avoids a clash.
- D9: The c4 skill element gets a `runs` edge to the script, not a `writes` edge to `stratum.autonomous`. Reason: the script owns the entry, as `scripts.c4:178-179` shows.
- D10: The automatic end goes into step 2 of the skill as one sentence that ends with "run step 3", not as a step 4 and not with the two commands repeated. Reason: it is the smallest text, step 3 already holds the exact commands and the off line, and AU2 and AU6 stay true with no change.
- D11 (review F1): Step 2 says it runs only for the user's own `/stratum:st-autonomous on`, and that after the mode ends the model never turns it on again. Reason: in a session that never ran `/stratum:st`, nothing stopped the model from running step 2 again on plain words. Pinned by AU10.
- D12 (review F2): `skills/st-worker/SKILL.md:59` gets the sentence "Never run `st-worker.sh autonomous-on` yourself". Reason: the worker skill is one more place that could start the mode. Pinned by AU11.
- D13 (review F3): The c4 write edge is deleted, not relabeled. Reason: the script owns the entry (D9).
- D14 (review F5): `skills/st/SKILL.md` line 95 ("Turn on autonomous build mode only as the line above ...") is deleted. Reason: it repeated line 92 and read as if the orchestrator turns the mode on.
- D15 (review F7): The quickstart steps 1, 2 and 5 name `/stratum:st-autonomous on|off`, not the plain words. Reason: a later re-check of feature 018 that runs the quickstart would fail on the plain words.

## Risks
- R1: The change sets who may turn on a mode in which the orchestrator approves worker permissions. It makes the rule stricter and does not change what is approved, but it supersedes FR-009 and 010 FR-018 by a decision line, not by a spec edit.
- R2: The model also cannot start the skill for the user. A user who asks in plain words must type the command. D2 tells them how.
- R3: `docs/harness/README.md` must be regenerated with likec4 1.60.0 on node 22.22.3 or later (here node v24.14.1). The atlas rebuild needs `~/.claude/skills/system-atlas/assets/` (present here).
- R4: `disable-model-invocation` stops only the Skill tool. `st-worker.sh` refuses a worker worktree (`scripts/st-worker.sh:71-73`) and `hooks/st-approve.py` blocks a worker session, but the orchestrator or one of its subagents can still run `autonomous-on` in Bash. Three sentences tell the model not to do that: `skills/st/SKILL.md:92`, step 2 of the new skill ("Run this step only for the user's own ..."), and `skills/st-worker/SKILL.md:59` ("Never run `st-worker.sh autonomous-on` yourself"). They are instructions to the model, not a check. A hook would close it, and constraint 1 rules out a new hook.
