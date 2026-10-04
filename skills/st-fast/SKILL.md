---
name: st-fast
description: Run a change through Stratum's Fast lane: short change plan, one gate, test-first build, ponytail review, commit, drift fix.
---

# /stratum:st-fast <change>

Plugin root is two levels up from this skill's base directory. Set `lane` to `fast` in
`<project>/.stratum/state.json`. The change must sit inside an existing feature in `specs/`; if it
needs a new user story or touches privacy and access, move up to `/stratum:st-full`.

1. Start the `stratum:st-fast` subagent with: plugin root, project root, the feature dir, and the change.
   It writes `specs/<feature>/changes/NNN-<name>.md` and stops.
2. **Gate:** show the user the change plan in short form. Continue only on their OK.
3. For each test in the change plan: `stratum:st-test` writes it and shows it fails; `stratum:st-build` makes it
   pass. A test still red after 2 tries goes to `stratum:st-debug`.
4. Verify: re-run the tests and grep the diff for added comment lines (see `/stratum:st`).
5. Run `/stratum:st-ponytail-review` on the change's diff. Check each finding against the source
   (see `/stratum:st`). Send the real, small ones to `stratum:st-build`; big ones go to the user.
6. `stratum:st-git` commits exact paths.
7. Start `stratum:st-close` for the drift fix only (no gap report, no lessons unless something went wrong).
8. List the small decisions and findings (fixed and dropped). Push only on the user's "push".

If any agent reports the change needs a higher lane, stop and move up.
