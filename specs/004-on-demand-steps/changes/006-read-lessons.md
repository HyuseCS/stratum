# 006 read-lessons

What: `st-close` appends lessons to `docs/lessons.md`, but no agent reads them (issue #28). Plan and
Inspect now read the file. Plan cites the lessons that apply in the plan.md gates and in the task
lines they govern. Inspect checks that the plan does so. Close tells the writer that the lessons
are read there, so each Rule is one testable sentence.
FRs: none. spec.md has no FR for lessons (same precedent as changes 003 to 005). The source is
issue #28, option O2 in a narrow form.
Impact area: core runtime (agent and skill text, docs, one test file)

## Files
- `agents/st-plan.md:15-17` ("Read first" list) - add a bullet after the constitution line:
  `- \`<project>/docs/lessons.md\` (if present)`.
- `agents/st-plan.md:45` ("Rules" list) - add this rule after "Respect the constitution...":
  `- Read the lessons in \`docs/lessons.md\`. In the Constitution Check of plan.md, add one gate row for each lesson that applies, and name it by number in the row (for example "lessons L1"). In tasks.md, a task that a lesson governs ends with its number (for example "lessons L6"). A lesson that does not apply gets no row.`
- `agents/st-inspect.md:19-21` ("Read" list) - add a bullet after the constitution line:
  `- \`<project>/docs/lessons.md\` (if present)`.
- `agents/st-inspect.md:41` (end of the "Look for at least" list in Analysis) - add this item:
  `- Lessons: a lesson in \`docs/lessons.md\` that applies to this feature but that no plan.md gate or tasks.md task cites by number. Offer the fix (a gate row or a task note) and send it to st-plan.`
- `agents/st-close.md:50-53` (step 3) - keep the append. Add after "...from this feature.":
  `st-plan and st-inspect read this file at the next feature's Plan and Inspect, so write each lesson's Rule line as one sentence that a test or a check can fail.`
- `skills/st-close/SKILL.md:33` (step 5) - after "...to \`docs/lessons.md\`." add:
  `st-plan and st-inspect read that file at the next feature's Plan and Inspect, so each lesson's Rule line is one testable sentence.`
- `DESIGN.md:143` (Close step 3) - after "append to `docs/lessons.md`." add: `The Plan and Inspect agents read the file at the next feature.`
- `README.md:75` (Plan row) - add to the description: `It reads \`docs/lessons.md\` and cites the lessons that apply.`
- `README.md:78` (Close row) - add to the description: `Plan and Inspect read the lessons.` Both rows are text only, so the README two-way checks in `tests/test_inspect.sh` do not change.
- `tests/test_inspect.sh:146` - 7 new checks before `exit $fail` (see Tests).

## Tests (written first, must fail before the build)
All in `tests/test_inspect.sh` (it already checks `agents/st-inspect.md`, README, and other
files by path through `phrases()`). Add one `phrases` block with rows `name<TAB>target<TAB>phrase`
(target is `agent` for st-inspect, a repo path for the rest). Each phrase is text the edit builds.
`grep -qF`, per lessons L1. None of them is in the path `docs/lessons.md`.
- T1 `lessons st-plan read`: `agents/st-plan.md` has `one gate row for each lesson that applies`.
- T2 `lessons st-plan cite`: `agents/st-plan.md` has `ends with its number`. The Read bullet has no own check, because the path alone would match.
- T3 `lessons st-inspect read`: `agent` has `that no plan.md gate or tasks.md task cites by number`.
- T4 `lessons st-close agent`: `agents/st-close.md` has `read this file at the next feature's Plan and Inspect`.
- T5 `lessons st-close skill`: `skills/st-close/SKILL.md` has `each lesson's Rule line is one testable sentence`.
- T6 `lessons design`: `DESIGN.md` has `The Plan and Inspect agents read the file at the next feature.`
- T7 `lessons readme`: `readme` has `cites the lessons that apply`.
Command: `PYTHONDONTWRITEBYTECODE=1 bash tests/test_inspect.sh`. Today: 7 FAIL lines, all other lines `ok`. After the build: all `ok`.
- Negative control: after the build, remove the new sentence from `agents/st-inspect.md` once, run the command, see T3 go red, restore it.
- Live check (quickstart style, by hand, not automated): in a scratch clone, make a project with
  `specs/001-x/spec.md` and a `docs/lessons.md` holding one lesson ("L1 ... Rule: a text check asserts a
  phrase the code builds"). Run `/stratum:st-plan` on `001-x`. Pass: `plan.md` Constitution Check has a
  row that names `L1`. Then run `/stratum:st-inspect`. Pass: no finding says the lesson is uncited. Control:
  delete the L1 row from plan.md and re-run st-inspect: it reports the lesson as uncited.

## Chosen trade-off
Only Plan and Inspect read the file. The Build agent, the test agent, the session-start hook and the
Fast lane do not. Lessons reach them through the plan.md gates and the tasks.md task lines. The cost
is once per feature, not every session. A Fast-lane change gets no lessons unless its change plan
copies one.

## Out of scope
- O3, a config setting for the lessons path: not added. The path stays `<project>/docs/lessons.md`.
- Moving the file, or the monorepo side effect in issue #28 (the file goes up with every app PR).
- Reading lessons in the hook, Build, test agents or the Fast lane.

## Risks
- A lesson-heavy file grows the Plan context. The Rule says cite only the lessons that apply. No size cap now.
- The new Plan rule depends on the agent following text. T1 to T7 check the text, not the behavior. The live check covers the behavior once.
- `tests/test_inspect.sh` counts agent and skill totals elsewhere. These edits add no file, so the counts do not move.
