# 002 one-review

What: Issue #14. The `st-review` agent loads the `st-ponytail-review` skill (Skill tool) and gives
one ranked list, each finding tagged `correctness`, `security`, `plan` or `simplify`. `st-build`
"Per story" and `st-fast` step 5 start only this agent. `st-review` can also run in the background
when the user asks. `/stratum:st-ponytail-review` stays as its own command (D2).
FRs: FR-001 (the `/stratum:st-review` command, built). FR-008 (extended: `st-review` joins the
background list). The merge itself has no FR in spec.md (spec lists #14 as out of scope).
Impact area: core runtime

## Files
- `agents/st-review.md` - frontmatter `tools: Read, Grep, Glob, Bash, Skill`. Description: per
  story in Build, per change in Fast. Inputs: the story, or in the Fast lane the change plan path
  (plan fit is checked against it). Diff input: a range, or in the Fast lane the working tree
  against HEAD, read with `git diff HEAD` and `git status --porcelain --untracked-files=all` for
  new files. New step: load the `st-ponytail-review` skill (Skill tool) and
  run it on the same diff. Its Boundaries apply only to `simplify` findings, and `Lean already.
  Ship.` means no `simplify` findings, not the end of the review. No ponytail rules copied in.
  Report: one list F1..Fn ranked by severity, each with its tag. `simplify` findings keep the
  skill's own sub-tag (name no sub-tags in the agent text). The skill's `net:` line ends the report.
- `skills/st-build/SKILL.md:43-44` - one step: "The `stratum:st-review` agent on the story's diff."
  Renumber steps 3-5 to 2-4.
- `skills/st-fast/SKILL.md:20-21` (step 5 only) - start the `stratum:st-review` agent with the
  change plan path and the change's uncommitted diff (`git diff HEAD` plus new files, since step 6
  commits after the review). Keep "Check each finding against the source" and the routing text.
- `hooks/st-session-start.sh:17` - the background list becomes "st-impeccable (an audit), st-review,
  st-ponytail-audit or st-ponytail-debt in the background". New sentence after the "Pass it ..."
  sentence: "For st-review, pass the feature dir and the range, found as /stratum:st-review steps 1
  and 2 say (stop where they stop), and check each finding against the source before you show it."
  All other phrases stay.
- `specs/004-on-demand-steps/contracts/background.md:143-151` - the same rule text and phrase list.
- `DESIGN.md:131` - "Per story: `st-review` on the story's diff (correctness, security, plan fit,
  over-engineering), impeccable for screens, ...".
- `DESIGN.md:148` - "test first, build, `st-review` → commit → drift fix."
- `specs/004-on-demand-steps/quickstart.md` - new live row L13 (seeded diff, see Tests), and a note
  that L13 needs a clone of a branch with #14.
- Review fixes after the gate, built in 1df5c83 (not in the list above):
  - `DESIGN.md` D24 - adds st-review to the background list. Says st-impeccable and st-review only
    have Bash, since st-review runs tests.
  - `agents/st-review.md` Report - when the skill gives a `net:` line, it ends the report.
  - `agents/st-review.md` steps 2 and 3 - "(or the change plan's)", so a Fast-lane change checks the
    change plan's FRs and tests.

## Tests (written first, must fail before the build)
- `tests/test_on_demand.sh` - new checks, run `bash tests/test_on_demand.sh`:
  - `#14 review tools`: `grep -qx "tools: Read, Grep, Glob, Bash, Skill" agents/st-review.md`.
  - `#14 review body` phrases in `agents/st-review.md`: "Load the `st-ponytail-review` skill (Skill
    tool)"; "`correctness`, `security`, `plan`, `simplify`"; "one ranked list"; "the change plan".
  - `#14 no copied rules`: `! grep -qF "yagni:" agents/st-review.md` (D1).
  - `#14 lanes`: `! grep -qF st-ponytail-review` on `skills/st-build/SKILL.md` and
    `skills/st-fast/SKILL.md`; `grep -qF "stratum:st-review"` on `skills/st-fast/SKILL.md`.
  - `#14 ponytail-review kept`: `[ -f skills/st-ponytail-review/SKILL.md ]` (D2, passes now, guards
    against a deletion).
  - `FR-008 rule` line 96: change the phrase to "st-impeccable (an audit), st-review,
    st-ponytail-audit or st-ponytail-debt in the background". Add "For st-review, pass the feature
    dir and the range" and "check each finding against the source before you show it" with target
    `hook`.
  - `#14 design`: `! grep -qF ponytail-review DESIGN.md`.
- `specs/004-on-demand-steps/quickstart.md` L13 (manual, live session in the scratch clone): write
  `lib.py` with `def last(xs): return xs[len(xs)]` and a `class Summer` whose `total` method loops
  to add a list, commit it, run `/stratum:st-review HEAD~1..HEAD`. Expected: one list holding a
  `correctness` finding at the `xs[len(xs)]` line and a `simplify` finding (`stdlib:` `sum`) at
  `Summer`. Manual because it calls a model (cost, varying output), so it cannot sit in the shell
  tests. Headless `claude -p --plugin-dir "$s/p" "/stratum:st-review HEAD~1..HEAD"` can also work
  (no prompts, no commit), but T010 left L6 for the user, so manual is the default.
  Result: 2 of 2 headless runs on isolated clones gave one list with a `correctness` finding at
  `xs[len(xs)]` and a `simplify` finding at `Summer`. Both runs left
  `__pycache__/lib.cpython-314.pyc`, because the review ran lib.py. So the `No file changed`
  expectation did not hold.

## Risks
- `st-ponytail-review` says "and stop" on a clean diff and puts correctness out of scope. The agent
  text must limit both to the `simplify` part, or the pass can end early. L13 shows it.
- `st-review` runs tests with Bash in the background. The HEAD and status check before and after
  catches any file it leaves.
- `skills/st-fast/SKILL.md:3` description still says "ponytail review". Left as is to keep the
  merge with I5 clean.
- Spec drift for Close: spec.md Assumptions (#14 out of scope), FR-006/FR-008 list of three,
  plan.md:40 "the 4 existing agent files unchanged".
