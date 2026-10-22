# 004 hook-lane

What: GitHub issue #24. The `st-phase` hook also sets `lane`, and sets `phase` for the Fast and
Quick lanes, so `st-fast`, `st-quick`, `st-full` and `st-close` make no main-session write to
state.json. The `done` write moves to the last agent of each flow: `st-close` (Full lane and the
Fast-lane drift step) and `st-quick` (Quick lane).
FRs: none. spec.md has no FR for phase or lane tracking. The source is issue #24 and DESIGN.md
D20/D21 (same precedent as change 003).
Impact area: core runtime

## Files
- `hooks/st-phase.py:11` - `NAME` also matches `fast`, `quick`, `full`.
- `hooks/st-phase.py:35-44` - the write:
  - Gate: write when the name is `define`, `fast`, `quick` or `full`, or `feature_directory` is
    set. `st-quick` has no feature, and a fresh project has `feature_directory: null`.
  - `full`: set `lane` to `full`. If `phase` is `fast` or `quick`, set it to None, so a Full run
    started mid-Fast or mid-Quick gets no stale lane label. Otherwise `phase` stays. No
    out-of-order check.
  - `fast`, `quick`: set `lane` and `phase` to the name. Not in `BEFORE`, so no warning.
  - `define`: set `phase` as today and always set `lane` to `full` (a Full run starts here).
  - `plan` to `close`: set `phase` as today. Set `lane` to `full` only when
    `not state.get("lane")` (null, missing and `""`). This rule keeps `lane: fast` if a Fast run
    starts `/stratum:st-close`. Do not change it to "always".
  - Keep the other keys and the `mkstemp` + `os.replace` write. The label at line 45 reads the new
    `phase`, so a `/stratum:st-fast` prompt gets `[Fast lane]` with no extra code.
- `skills/st/SKILL.md:34-35` - "follow `/stratum:st-fast`" and "follow `/stratum:st-quick`" become
  "run". Same line count (`tests/test_inspect.sh:91` pins line 32).
- `skills/st/SKILL.md:28` - delete "Write `lane` to state.json." Edit in place so line 32 stays
  line 32 (`tests/test_inspect.sh:91`). The skills the router starts set `lane` through the hook.
- `skills/st-fast/SKILL.md:8-9` - delete "Set `lane` and `phase` to `fast` in
  `<project>/.stratum/state.json`." Keep the rest of the paragraph.
- `skills/st-fast/SKILL.md:30-36` - steps 8 and 9 name the file
  `<plugin root>/skills/st-close/SKILL.md` ("Shortcuts" step, step 3), not `/stratum:st-close`. The
  orchestrator reads the file and does not start the skill. Keep "commits the docs `st-close`
  changed" on one line (`tests/test_on_demand.sh:135`).
- `skills/st-fast/SKILL.md:36` - step 10 becomes "Push only on the user's "push"."
- `skills/st-quick/SKILL.md:8-9` - delete the "Set `lane` and `phase` to `quick` ..." sentence.
- `skills/st-quick/SKILL.md:16` - delete the line "Set `phase` to `done` in state.json."
- `skills/st-full/SKILL.md:8` - becomes "Run, in order, stopping at each gate:". Edit in place so
  line 12 stays line 12 (`tests/test_inspect.sh:92`).
- `skills/st-close/SKILL.md:44` - delete step 9.
- `skills/st-close/SKILL.md:30-31` - on send back, after `/stratum:st-build`, run step 2 again
  without a gap report (not "return here"), so the `st-close` agent's step 5 writes `done` last.
- `agents/st-close.md:57-60` - new last step "### 5. Done": "As the last step, set `phase` to `done`
  in `<project>/.stratum/state.json`. Keep the other keys." It runs at the end of every st-close run.
- `agents/st-close.md:64` - the `.stratum/` ban gets the exception: "apart from `phase` in
  `.stratum/state.json` (step 5)".
- `agents/st-quick.md:42-48` - new step 4: "If the edit is done and the file exists, set `phase`
  to `done` in `<project>/.stratum/state.json`. Keep the other keys." It never creates the file.
  Not on "Move up a lane".
- `agents/st-quick.md:51` - "Touch a second file" gets "(state.json in step 4 does not count)".
- `DESIGN.md:225-237` - D20: the hook also handles `st-fast`, `st-quick`, `st-full` and sets
  `lane` (rules above). D21: the hook sets `fast` and `quick`. The `st-close` and `st-quick`
  agents set `done`.
- `README.md:195-200` - "Phase tracking" names lane and the Fast and Quick skills. "each lane's
  last step sets `phase` to `done`" becomes "the lane's last agent (`st-close` or `st-quick`) sets
  `phase` to `done`".

Timing of `done` (decision): the `st-close` agent writes it at the end of its run. That is Full
Close step 2 (before verify, gaps, shortcuts, the docs commit and push) and Fast step 7 (before
steps 8-10). The `st-quick` agent writes it at Quick step 1 (before verify, commit, push). Today
the main session writes it as the last step.

No change: `hooks/commands.json:16-21` (PreToolUse matcher `Skill`, no name filter) and `:58`
(UserPromptSubmit, no matcher) already send every skill and prompt to the hook. `hooks/hooks.json`
holds only `{ "modules": [...] }`.

## Tests (written first, must fail before the build)
All in `tests/test_phase_hook.py`. Command: `python3 /home/hyuse/Desktop/stratum/tests/test_phase_hook.py`
- New `test_lane_skills_set_lane_and_phase` - for both events (prompt `/stratum:st-<x> do it` and
  Skill `stratum:st-<x>`), from `{feature_directory: None, phase: "done", lane: "full", keep: 1}`:
  `st-fast` gives lane `fast` + phase `fast`, `st-quick` gives `quick` + `quick`, `st-full` gives
  lane `full` with phase still `done`. `keep` stays. From phase `fast` or `quick`, `st-full` gives
  lane `full`, phase None, and the prompt event gives no lane label. The prompt event for
  `st-fast` and `st-quick` returns `Start your reply with [Fast lane].` / `[Quick lane].`. Red
  today: the regex has no `fast|quick|full`.
- New `test_phase_sets_lane_only_when_unset` - feature set, `lane` None: `st-plan` gives lane
  `full`. Missing `lane` key: same. `lane: "fast"`: `st-close` gives phase `close`, lane still
  `fast`. `st-define` from `lane: "fast"` gives lane `full` + phase `define`. Red today: lane
  stays None.
- Changed `test_non_phase_changes_nothing:102-106` - remove `stratum:st-fast` from the no-write
  list. Add negatives: skills `stratum:st-fastx`, `other:st-quick`; prompts `/stratum:st-quick-x`,
  `please run /stratum:st-fast`, `/stratum:st-fuller`. File bytes unchanged.
- Rewritten `test_lanes_end_with_done:128-135` as `test_agents_write_done` - the five SKILL.md
  files (`st`, `st-fast`, `st-quick`, `st-full`, `st-close`) contain neither "Write `lane`" nor "Set `lane`" nor
  "Set `phase`". `agents/st-close.md` and `agents/st-quick.md` each contain
  "set `phase` to `done` in `<project>/.stratum/state.json`". Red
  today: the skills still carry the sentences.
- Negative control: the test-first red run against today's hook is the "mapping removed" control
  from the issue. After the build, remove `|fast|quick|full` from `NAME` once, run the command,
  see `test_lane_skills_set_lane_and_phase` go red, restore the line. The lane-unset rule has its
  own control: remove `or not state.get("lane")`, see `test_phase_sets_lane_only_when_unset` go
  red, restore. The `full` reset has its own: remove the `elif old in ("fast", "quick")` branch,
  see `test_lane_skills_set_lane_and_phase` go red, restore.

## Risks
- After `done` is written early, prompts in the rest of Close (and Fast steps 8-10, Quick steps
  2-5) get no lane label, so replies start with `[Orchestrator]`. `st-status` shows `done` early.
- Full send back: the agent already wrote `done`, then `/stratum:st-build` warns "out of order
  (was done)". Today it warns "(was close)". Same warning, other word.
- Quick lane "move up": the agent writes nothing, and `/stratum:st-fast` then sets `fast`.
- Fast step 8 used to open `/stratum:st-close` to read "Shortcuts". The Skill call fired the hook
  after the agent wrote `done`, so `phase` ended at `close` and later prompts got the
  `[Full lane | Close]` label in a Fast run. Fixed: steps 8 and 9 read the file instead.
- `README.md:141` says state.json is committed. `done` stays uncommitted, as today.
- The `test_agents_write_done` phrase is long. In both agent files keep it on one line, or the
  grep goes red on a line wrap.
