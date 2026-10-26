# 001 live-run-gaps

What: Fix 5 wording gaps that the live runs in `research.md` R15 found. Q2: the Quick route of
`/stratum:st` prints no `Lane:` line. G1: `st-status` rewords the design check lines. G2: the
autonomous report has a Picks line. G3: fix round 2 ran no full critique. G4: the agent kept
before screenshots in `/tmp`.
FRs: FR-002, FR-015, FR-009, FR-006, FR-008, FR-014
Impact area: core runtime

## Causes

- Q2 (R15 routing runs). The transcripts are in
  `~/.claude/projects/-home-hyuse-Desktop-design-runs-route/`, sessions `91e8b4ce...` and
  `f76b3634...`. For `fix the header spacing on the home page`, the orchestrator first diagnoses
  the bug (reads `index.html`, measures the header with Playwright) to choose Quick or Fast. Then
  it calls the `stratum:st-quick` skill or agent directly. In `f76b3634` it wrote "I will send the
  fix to the Quick agent" before the Agent call, so it knew the lane and skipped only the line.
  `skills/st/SKILL.md:30` says "Say it in one line ... Then run the lane." It does not say the
  line comes before the first lane call. Quick is only a note in the Screens row. The Full and
  Design runs print the line because the lane is clear from the request.
- G1 (R15 L2). `skills/st-status/SKILL.md:25` says "show its lines: node 18 or later,
  `puppeteer-core`, and Chrome or Chromium, each missing one with its install command". "Show"
  plus a summary of what the lines say lets the agent write them in its own words.
- G2 (R15 L5). Both report lists name the picks with no mode:
  `skills/st-design/SKILL.md:99` ("Screenshots, the picks, ...") and `agents/st-design.md:49`
  ("- The picks."). The agent builds with the engine's Flow, which has a Picks block in every
  mode. FR-006 puts the picks at the new-look gate only.
- G3 (R15 `old` run). `skills/st-design/SKILL.md:85-86` says "then run audit and critique
  again". Step 3 (line 74) says "run `critique` on the screen in full", but the fix round does
  not say "in full" or point back to step 3, so round 2 ran the cheap part only (detector, tests,
  screenshots). FR-008 says a fix round runs all four checks again.
- G4 (R15 L4). Transcript `~/.claude/projects/-home-hyuse-Desktop-design-runs-old/130e2d66-...`,
  subagent `agent-a37e6126bf45fd69c.jsonl`: the `st-design` agent ran
  `mkdir -p /tmp/sched-before && cp .hallmark/shots/schedule-* /tmp/sched-before/` before the
  "denser" rebuild, because a new build writes over the same screenshot names. No text says where
  screenshots go. `agents/st-design.md` has no rule on it. The engine already has the step:
  `sloplint.mjs --before` writes the screenshots to `.hallmark/before/` and the page record to
  `.hallmark/before.json`, and the `.gitignore` it writes in `.hallmark/` lists both.

## Files
- skills/st/SKILL.md:30 (Q2) - replace `Say it in one line:` with
  `Before the first lane skill or agent starts, Quick too, say it in one line:`. Keep the rest of
  the line unchanged.
- skills/st-status/SKILL.md:25 (G1) - replace `from the project root and show its lines:` with
  `from the project root and print its lines word for word:`. Keep the rest of the line.
- skills/st-design/SKILL.md:101 (G2) - after `work behind the screen for Fast or Full.` add
  ` The autonomous mode's report has no picks.` on the same line. Line 99 stays
  as it is (the FR-009 test row checks it).
- agents/st-design.md:49 (G2) - replace `- The picks.` with `- The picks, in the new-look mode only.`
- skills/st-design/SKILL.md:85-86 (G3) - replace `then run audit and critique again.` with
  `then run step 3 again: audit, and `critique` in full, not only its detector.` (the inner
  backticks around `critique` stay, as in step 3). Rewrap lines 85-86, but keep the new
  sentence on one line, and keep `Run at most 2 fix rounds.` on one line too: the tests grep one
  line at a time, and `tests/test_design_lane.sh:104` already checks the second one.
- skills/st-design/engine.md (G4) - after the **Check.** bullet add a **Before.** bullet: for a
  change to a built screen, run the Check command once before the rebuild, with `--before`. Keep
  `with `--before`. It keeps the old screenshots in `.hallmark/before/`, which is never committed.`
  on one line.
- agents/st-design.md `## Never` (G4) - add the last bullet
  `- Save a screenshot outside the screenshot folders `engine.md` names.`
- agents/st-design.md `## Steps` (G4) - add, on one line before step 1, the sentence
  `For a change to a built screen, first run the engine's Before step, before any edit.`
  Both agent texts leave out the engine name and its `.hallmark/` folder, so the FR-010
  one-place test stays green.

## Tests (written first, must fail before the build)
All rows go in the second `phrases` block of `tests/test_design_lane.sh`, tab separated, each
directly after the last existing row of the same name. A row away from its group adds a report
line and changes the count. Command for all: `bash tests/test_design_lane.sh`.

- Q2 - after line 79 (`FR-002 st ... Say "full", ...`):
  `FR-002 st	skills/st/SKILL.md	Before the first lane skill or agent starts, Quick too, say it in one line:`
  - the say line is stated as coming before every lane, Quick included.
- G1 - after line 117 (`FR-015 st-status ...`):
  `FR-015 st-status	skills/st-status/SKILL.md	from the project root and print its lines word for word:`
  - st-status prints the check lines as the script prints them.
- G2 - after line 106 (`FR-009 SKILL.md ...`):
  `FR-009 SKILL.md	skills/st-design/SKILL.md	The autonomous mode's report has no picks.`
  and after line 107 (`FR-009 agent ...`):
  `FR-009 agent	agents/st-design.md	- The picks, in the new-look mode only.`
  - the picks are only in the new-look report.
- G3 - after line 105 (`FR-008 SKILL.md ... goes in the report as an unmapped`):
  `FR-008 SKILL.md	skills/st-design/SKILL.md	then run step 3 again: audit, and `critique` in full, not only its detector.`
  - each fix round runs the full critique.
- G4 - a new group after the `FR-013 agent` rows (before `FR-014 SKILL.md`):
  `FR-014 agent shots	agents/st-design.md	Save a screenshot outside the screenshot folders `engine.md` names.`
  `FR-014 agent shots	agents/st-design.md	For a change to a built screen, first run the engine's Before step, before any edit.`
  and a new group after the `FR-016 engine.md` rows:
  `FR-014 engine.md	skills/st-design/engine.md	with `--before`. It keeps the old screenshots in `.hallmark/before/`, which is never committed.`
  - no screenshot goes outside the project, and the before screenshots use the engine's own step.

Before the build: 7 `FAIL` lines (`FR-002 st`, `FR-008 SKILL.md`, `FR-009 SKILL.md`,
`FR-009 agent`, `FR-014 engine.md`, `FR-014 agent shots`, `FR-015 st-status`), exit 1. After:
33 lines, all `ok`, exit 0 (31 today plus the new `FR-014 engine.md` and `FR-014 agent shots`
groups). Every `tests/test_*.sh` stays exit 0.

## Risks
- The grep tests prove the wording only, not the behavior. The behavior checks are live re-runs,
  each with its R15 setup:
  - Q2: in `~/Desktop/design-runs/route`,
    `claude -p "/stratum:st fix the header spacing on the home page" --max-turns 12`. The
    transcript must have a `Lane: Quick` text before the first `stratum:st-quick` Skill or Agent
    call. Reset the repo after.
  - G1: `/stratum:st-status` with `puppeteer-core` missing must print
    `missing: puppeteer-core. Install: npm i -g puppeteer-core` as is.
  - G2, G3, G4: an autonomous run in `~/Desktop/design-runs/old` with a change request, then 2 fix
    rounds. Check no Picks line, a full critique in round 2, and no file under `/tmp`.
- D1 (G4): the engine's `--before` step keeps the before screenshots in `.hallmark/before/`.
  That folder is never committed (the `.gitignore` the engine writes, and the **Files.** bullet in
  `skills/st-design/engine.md`) but is not deleted, so they stay in the project. The other option
  is to also delete them after the report. The plan does not, because `.hallmark/` already keeps
  every build's screenshots.
