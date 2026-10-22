# 006 build-brief

What: GitHub issue #16. The `stratum:st-build` agent takes a brief instead of a plan, for a small
bounded fix across a few files that needs no change plan. One agent, two input modes: the steps
and the report stay the same. The `st` skill routes an unplanned multi-file build to the agent in
brief mode and never to `general-purpose`.
FRs: none. spec.md has no FR for lane routing. The source is issue #16 (same precedent as
changes 003, 004 and 005).
Impact area: core runtime

## Decision for the user gate
Where brief mode sits in the lane table: the Quick lane owns it. Recommended, and planned below.
- `st-quick`: one text or docs file, or a one-file visual fix. Unchanged.
- `stratum:st-build` agent in brief mode: a small bounded fix across a few files that needs no
  change plan. Quick lane.
- Fast: a change plan is needed (core runtime work that is more than small, or a screens change that is
  more than a few files).
This changes `DESIGN.md:156`: Quick no longer moves up to Fast on a second file. It moves to brief
mode, and brief mode moves up to Fast. The other option is to keep the rule and make brief mode a
Fast sub-mode. It adds a gate-less path to Fast, which is the Quick lane in practice, so not chosen.

After the brief build, the `st` skill runs `st-verify`, then the `stratum:st-git` agent commits
the exact files. Same as the Quick lane. No `st-review` unless the user asks.

## Files
- `agents/st-build.md:3` - `description` also says it builds a brief with no plan.
- `agents/st-build.md:11` - "You build exactly what the plan says" becomes "exactly what the plan
  or the brief says". Same line.
- `agents/st-build.md:17-25` - Inputs: add a second mode below the plan mode.
  "Brief mode: the orchestrator passes plugin root, project root and the brief itself: what to
  build, the files, the tests to write, the negative controls, the gates. No feature dir, no task
  IDs. Read the constitution and the files the brief names. Read no plan.md or tasks.md."
- `agents/st-build.md:33-42` - Steps: add one line "In brief mode the brief's files and tests stand
  in for the task IDs. Step 6 does not apply: there is no tasks.md." Steps 1-5 stay.
- `agents/st-build.md:44-55` - Stop and report: keep the existing list. Add the brief lines: "In
  brief mode, also stop when the brief touches a schema or migration, auth or access rules, or
  money; when it needs a file the brief does not name; or when it grows beyond a small bounded
  change. Report "Needs the Fast lane: <reason>" and write no code."
- `agents/st-build.md:66` - report line 1 also allows "Needs the Fast lane: <reason>".
- `skills/st/SKILL.md:24` - table row Screens, and `:25` Text and docs: edit in place only.
  No line added above 32. Text and docs stay Quick.
- `skills/st/SKILL.md:35` - the Quick bullet grows below line 32: "run `/stratum:st-quick` for one
  file. For a small bounded fix across a few files with no plan, start the `stratum:st-build`
  agent with the brief, the plugin root and the project root, never `general-purpose`. Then
  verify, and the `stratum:st-git` agent commits the exact files. If the agent reports "Needs the
  Fast lane", run `/stratum:st-fast`."
- `skills/st/SKILL.md:27` - override text unchanged.
- `skills/st-quick/SKILL.md:12` - step 2 also names the route: a fix that needs a second file goes
  to the `stratum:st-build` agent in brief mode (the `st` skill), not straight to
  `/stratum:st-fast`. Keep it to one line.
- No change: `agents/st-quick.md`. Its report stays `Move up a lane: <reason>`; the st-quick skill
  routes it.

Line pin (decision): `tests/test_inspect.sh:91` pins `skills/st/SKILL.md` line 32 (the Full bullet).
The pin does not move. Lines 1-32 of `skills/st/SKILL.md` are edited in place only. All new text goes
below line 32 (the Quick bullet at :35, which may wrap to more lines).

Wording rule: `tests/test_on_demand.sh` fails on `st-x` (`stratum:st-x`) in a SKILL.md. New text says
"the `stratum:st-build` agent", never "`st-build` (`stratum:st-build`)".

Doc edits (drift st-close would pick up; done here so the docs match the code):
- `DESIGN.md:60` - `st-build` job: "Builds tasks, or a brief with no plan."
- `DESIGN.md:155-157` - Quick lane paragraph: one file, or a few files through `st-build` in brief
  mode; moves up to Fast when it needs a change plan or touches a schema, access, money.
- `README.md:117` - `st-build`: "Builds tasks or a brief; loads design rules for screens".
- `README.md:122` - `st-quick`: "Quick-lane edits (one file)".

No change: `state.json`. `st-build` never touches it, so nothing sets `phase: done` after a brief
build (see Risks). No new agent file, so the "13 agents" check in `tests/test_inspect.sh:88` stays.

## Tests (written first, must fail before the build)
All in `tests/test_on_demand.sh`, before `exit $fail`.
Command: `bash /home/hyuse/Desktop/stratum-16/tests/test_on_demand.sh`
- New `phrases` block "#16 brief mode" on `agents/st-build.md`: "Brief mode", "the brief itself",
  "schema or migration", "auth or access rules", "money", "Needs the Fast lane". Tab-separated
  lines, one phrase per line.
- Same block on `skills/st/SKILL.md`: "the `stratum:st-build` agent", "never `general-purpose`".
- New `check` "#16 general-purpose only as never": `grep -c general-purpose skills/st/SKILL.md` is
  at least 1, and no line holds `general-purpose` without "never" (`! grep general-purpose
  skills/st/SKILL.md | grep -qv never`).
- Red today: none of the phrases exist, and the count is 0.
- Also run `bash /home/hyuse/Desktop/stratum-16/tests/test_inspect.sh` after the build. It must stay
  green (line 91 pin, "13 agents").
- Negative controls, after the build: delete "Needs the Fast lane" from `agents/st-build.md`, run
  the command, see "#16 brief mode" go red, restore. Replace "never `general-purpose`" in
  `skills/st/SKILL.md` with "use `general-purpose`", see the check go red, restore.

## Risks
- Nothing sets `phase: done` after a brief build. The `st-phase` hook sets `lane` and `phase` for
  `st-quick`, and `st-quick` writes `done`. The brief build starts no skill, so `lane` and `phase`
  keep their old values (the hook sets both only from skill names, `hooks/st-phase.py:11`). Named,
  no change here. A later change can have the `st` skill or `st-git` write it.
- The scope guard is a text rule only. Nothing checks a brief's file count. The `st-verify` step
  catches comments and red tests, not scope.
- `DESIGN.md:156` changes the Quick-to-Fast rule. If the user prefers the old rule, the Files for
  `st` skill, `st-quick` skill, `DESIGN.md` and `README.md` change; the agent edits stay.
- `st-verify` needs the test command from the brief. A brief with no test command cannot be verified;
  the agent report must list the commands it ran.
