---
name: st-fast
description: Run a change through Stratum's Fast lane: short change plan, one gate, test-first build, st-review, commit, drift fix and shortcut list.
---

# /stratum:st-fast <change>

Plugin root is two levels up from this skill's base directory. The change must sit inside an
existing feature in `specs/`; if it needs a new user story or touches privacy and access, move up
to `/stratum:st-full`.

1. Note `git rev-parse HEAD` as the base. Then start the `stratum:st-fast` subagent with: plugin
   root, project root, the feature dir, and the change.
   It writes `specs/<feature>/changes/NNN-<name>.md` and stops.
2. **Gate:** show the user the change plan in short form. Continue only on their OK.
3. For each test in the change plan: the `stratum:st-test` agent writes it and shows it fails; the `stratum:st-build` agent makes it
   pass. A test still red after 2 tries goes to the `stratum:st-debug` agent, with the advisor's answer
   first if one is set (`/advisor`): root cause or rabbit hole?
4. Verify with `bash <plugin root>/scripts/st-verify.sh '<test command>' <files touched>` (see `/stratum:st`). If an
   advisor is set, consult it on the diff: hidden regressions? Handle its notes like findings.
   At the end of the change, send the small-decision list to `/advisor` if one is set. A decision it sends to the user is undone if the user says no.
5. Start the `stratum:st-review` agent with the change plan path and the change's uncommitted diff
   (`git diff HEAD` plus new files, since step 6 commits after the review). Check each finding
   against the source (see `/stratum:st`). Send the real, small ones to `stratum:st-build`; big
   ones go to the user.
6. The `stratum:st-git` agent commits exact paths.
7. Start the `stratum:st-close` agent with the base from step 1, for the drift fix and the shortcut
   list (no gap report, no lessons unless something went wrong). Do this only after the step 6
   commit landed: the shortcut list sees only committed work. If the commit did not land, stop
   and tell the user.
8. Handle the shortcut rows as in `<plugin root>/skills/st-close/SKILL.md` ("Shortcuts" step).
   List the small decisions and findings (fixed and dropped).
9. Check each drift change against the code it names (as in
   `<plugin root>/skills/st-close/SKILL.md` step 3). Then the `stratum:st-git` agent
   commits the docs `st-close` changed, with exact paths: the doc files in its drift list, and
   `docs/lessons.md` if it wrote a lesson. If it changed no docs, skip this step. If the commit
   did not land, stop and tell the user.
10. After the last commit lands (step 9, or step 6 when step 9 is skipped), set `phase` to `done` in `<project>/.stratum/state.json`. Keep the other keys.
    Push only on the user's "push".

If any agent reports the change needs a higher lane, stop and move up.
