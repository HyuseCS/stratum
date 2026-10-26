---
name: st-design
description: Design lane. Use for a new look, or a new page or screen the project does not have yet. New look: grills the user for the design file, builds one reference screen, checks it, and asks at one gate. Autonomous: builds a new page in the existing look with no gate in the middle, checks it, and reports.
---

# /stratum:st-design <task>

You are the orchestrator. You route and verify. You do not implement. Plugin root is two levels up
from this skill's base directory. Read `engine.md` beside this file first: it names the engine,
its commands, its grades and the detector map. `<impeccable>` is
`<plugin root>/skills/st-impeccable/scripts/impeccable`. Hold the design answers in the
conversation. Do not write them to a decisions file.

## 1. Start

1. Run `bash <plugin root>/scripts/st-design-check.sh` from the project root. Exit 1: print its
   lines and stop. Do no other work.
2. A framework project (`package.json` names `next`, `astro`, `@sveltejs/kit` or `vite`): take
   the port from its `dev` script, else Next 3000, Vite and SvelteKit 5173, Astro 4321. Run
   `curl -s -o /dev/null http://localhost:<port>/`. No answer: say "Start your dev server with
   `npm run dev`, then run /stratum:st-design again." and stop. Never start a dev server.
3. A design file is a root `DESIGN.md` with `.impeccable/design.json` beside it. A root
   `DESIGN.md` or `design.md` without it is not a design file: say "`DESIGN.md` is not a design
   file. Move or rename it, then run /stratum:st-design again." and stop.
4. Pick the mode and say it in one line. New look: the task asks for a new look or a change to the
   design file, or the project has no design file and no styled screens. Autonomous: the task asks
   for a new page or screen in the existing look. Else autonomous. Styled screens: a tracked file
   (`git ls-files`) sets a color or a font: a `color:`, `font-family:`, `--color-` or `--font-`
   declaration, or a Tailwind config.

## 2. New look

The user is stopped at two kinds of stop per direction: the design file confirm (step 4), once,
and the gate (step 6) after each build.

1. Grill with the `st-grill` method: one question per message, each with a recommended answer,
   until the frontier is empty. First branches: audience, use, tone, material, theme, North Star,
   overview voice, color character, elevation, components, UX (density, how a user moves through
   the screens).
2. Theme branch: run the engine's deal command, show the 3 themes with their pictures, and
   recommend one. "Another three" deals again.
3. When the grill ends, run the engine's scaffold command for the picked theme.
4. Load `st-impeccable` (Skill tool) and run `document` in scan mode with the grill answers as
   its Step 3 answers, so it asks nothing. If a design file exists, answer its refresh, overwrite
   or merge question with "overwrite". Its Step 5 confirm is the first stop: build nothing until
   the user confirms the file.
5. Build and check one reference screen (section 4).
6. The gate: show the screenshots, the picks and the report. Yes: commit (section 5). Changes:
   make them through section 4, then this gate again. A different direction: back to step 1 at
   the theme branch, then step 4 and this gate again. Gate rounds do not count as fix rounds.

## 3. Autonomous

1. No design file: read the look from the code (tokens, the global stylesheet, the main
   components) as a draft. Grill as in section 2 step 1, without audience, use, tone, material and
   theme, and start each recommended answer from the draft. Then run section 2 step 4. This
   happens once per project.
2. Find the page's job, its visitor and its main action in the task and `DESIGN.md`. If one is
   missing, ask once, with all missing items in one message. Then ask nothing more until the
   report.
3. Build and check (section 4), then report. On the user's OK, commit (section 5). Changes: make
   them through section 4 and report again before any commit.

## 4. Build and check

1. Start the `st-design` agent (`stratum:st-design`) with the plugin root, the project root, the
   task, the mode, the answers (job, visitor, main action, and in the new-look mode audience, use,
   tone, material and theme), every answer you assumed, the dev server URL if any, and in a fix
   round the findings to fix.
2. Before the first critique, run `<impeccable> ignores list`, then
   `<impeccable> ignores add-rule <id> --all-values --local` for each id on the engine's
   `ignore:` line that is not listed yet. Remember the ids you added.
3. Load `st-impeccable` and run `audit` on the screen, dimensions 1 (Accessibility) and 2
   (Performance) only. Then run `critique` on the screen in full. Answer its closing questions
   yourself: priority P0 and P1 first, scope blocking findings only. List both as assumed answers.
4. After each critique that printed the live server's connection JSON, run `<impeccable>
   live-server stop --keep-inject`. The overlay went in through the browser, so this form leaves
   the project's files as they were. Never a bare `stop`: it runs `live-inject --remove` on the
   project's entry file. No connection JSON: run no stop, and the report says the overlay did not
   run.
5. A check passes when it has no finding at its two highest levels: P0 and P1 for audit and
   critique, the engine's two highest grades for the agent's two checks. A detector id in the
   critique's output that is on neither map line of `engine.md` goes in the report as an unmapped
   rule.
6. One fix round: start the agent again with every finding that blocks a pass,
   then run step 3 again: audit, and `critique` in full, not only its detector.
   Run at most 2 fix rounds. Then report what still blocks a pass as open.
7. After the last round, run `<impeccable> ignores remove-rule <id> --local` for each id you
   added. The report says the ignores were in `.impeccable/config.local.json` and are removed.

## 5. Commit

Only after the user's yes at the gate (new look) or OK (autonomous), the `st-git` agent
(`stratum:st-git`) commits the exact paths the agent reported as written, and `DESIGN.md`,
`.impeccable/design.json` and the files on the engine's Files line if they changed. Never commit
the engine's screenshot folder or `.impeccable/critique/`.

## Report

Screenshots, the picks, each check's result, what was fixed, what is open, every assumed answer,
the component tests run, unmapped detector rules, the image key line, the ignores line, and the
work behind the screen for Fast or Full. The autonomous mode's report has no picks.
A check whose tool did not run is marked `not run` in the report and does not pass.

## Never

- Edit a vendored file under `skills/st-impeccable/` or the engine's skill folder.
- Ask for an image key or turn on image generation.
- Start a dev server.
