# 003 fast-docs-commit

What: Handoff Q2. In the Fast lane, step 6 commits before step 7 starts `st-close`, so the docs
`st-close` changes (drift fix, a lesson) stay uncommitted and the user commits them by hand. Add a
lane step after the shortcut handling: the `stratum:st-git` agent commits those docs with exact
paths, as `skills/st-close/SKILL.md` step 8 does in the Full lane. No docs changed: skip the step.
FRs: none. spec.md has no FR for the Fast-lane steps. The source is `.stratum/handoff.md` Q2 (user).
Impact area: core runtime

## Files
- `skills/st-fast/SKILL.md:30-32` - split step 8:
  - 8: "Handle the shortcut rows as in `/stratum:st-close` "Shortcuts". List the small decisions
    and findings (fixed and dropped)." (text unchanged)
  - 9 (new): "The `stratum:st-git` agent commits the docs `st-close` changed, with exact paths:
    the doc files in its drift list, and `docs/lessons.md` if it wrote a lesson. If it changed no
    docs, skip this step." Use the `The \`stratum:st-git\` agent` form of step 6. The form
    "`st-git` (`stratum:st-git`)" fails the "lane wording no bare agent name" check
    (`tests/test_on_demand.sh:53-54`).
  - 10: "Push only on the user's "push". Set `phase` to `done` in state.json." in that order.
  Steps 1-7 and the frontmatter stay as they are.
- `DESIGN.md:152` - "test first, build, `st-review` → commit → drift fix and shortcut list →
  commit docs." The line lists every Fast-lane step and names the first commit, so without the
  second commit it is wrong. No other DESIGN.md edits.
- Review fixes after the gate (not in the list above): `skills/st-fast/SKILL.md` step 9 checks
  each drift change first and stops if the commit did not land; `README.md:80-81` adds "commit docs".

## Tests (written first, must fail before the build)
- `tests/test_on_demand.sh` - new entries after the #14 checks, run `bash tests/test_on_demand.sh`:
  - `phrases` block, name `Q2 fast docs commit`:
    - `skills/st-fast/SKILL.md` "commits the docs `st-close` changed"
    - `DESIGN.md` "shortcut list → commit docs"
    Both absent today: `grep -cF "commits the docs" skills/st-fast/SKILL.md` gives 0, and
    `grep -cF "commit docs" DESIGN.md` gives 0. Short phrases, so a line wrap cannot split them.
  - The "Q2 fast order" check was dropped at the gate (O1): the steps are numbered.

## Risks
- `tests/test_shortcuts.sh:100` greps `skills/st-fast/SKILL.md` for "git rev-parse HEAD". Step 1
  stays untouched, so it still passes.
- `skills/st-fast/SKILL.md:3` description lists the lane steps and will not say "commit docs". Left
  as is (surgical change).
- If the user picks "fix now" for a shortcut, that fix is committed in step 8 by its own st-git
  run. Step 9 must take only the doc paths from `st-close`'s report, not every changed file.
- `tests/test_phase_hook.py:133` asserts the exact text "Set `phase` to `done` in state.json." in
  `skills/st-fast/SKILL.md`. Step 10 must keep that sentence word for word.
