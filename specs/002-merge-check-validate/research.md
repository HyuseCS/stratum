# Research: Merge Check and Validate into Inspect

## R1. Search for the old names

- Decision: `git grep -nwE 'st-(check|validate)' -- . ':!specs'` must print nothing.
- Rationale: The plain search `git grep -nE 'st-check|st-validate'` can never be empty.
  `skills/st-ui-ux/data/phosphor-icons-upstream.json:18338` holds `"list-checks"`, which contains
  `st-check`. Today the plain search finds 37 lines and the `-w` search finds 36. `-w` needs a
  non-word character on both sides. `stratum:st-check`, `` `st-check` `` and `st-check findings`
  still match. The pattern is written `st-(check|validate)` so that the test file, which is
  tracked outside `specs/`, does not match its own text.
- Alternatives considered: exclude `skills/st-ui-ux/` (hides a real match in a skill folder);
  the plain pattern (always fails).

## R2. Release notes

- Decision: The full release note is the body of the version bump commit (T012). README and the
  other tracked files outside `specs/` do not name the old agents.
- Rationale: FR-011 needs a note that names `/stratum:st-check`, `st-check` and `st-validate`.
  FR-007 and SC-002 forbid those names in any tracked file outside `specs/`. A commit message is
  not a tracked file. The spec's assumption "release notes are the version bump commit message and
  the README" cannot hold for the README part. Earlier bump commits (`312a78b`, `47d7a38`) have no
  body. This one needs one.
- Alternatives considered: a README upgrade note (breaks FR-007); a CHANGELOG file (Stratum has
  none, and it would break FR-007 too).

## R3. Version

- Decision: `0.1.26` to `0.1.27` in `.claude-plugin/plugin.json` only.
- Rationale: Every release so far is a patch bump (`git log --oneline | grep Bump`).
  `.claude-plugin/marketplace.json` has no version field.
- Alternatives considered: `0.2.0` for the removed skill (no precedent in this repo).
- Check: none automated. A test pinned to `0.1.27` goes red at the next bump (lessons L4).
  FR-011 loses its automated check. Quickstart section 7 checks the version and the commit
  message by hand.

## R4. Test for FR-010 (old name in a model file)

- Decision: No new hook test names the old agents. Two existing tests cover FR-010, because the
  hook has no special case (G1): `test_module_constants` pins `AGENTS` to the 10 names, and
  `test_deny_unknown_agent` checks that a name outside the list is denied and that the message
  lists every name in `agents/*.md`. The hands-on check with an old name is quickstart section 4,
  which is under `specs/`.
- Rationale: A test that writes `st-check` or `st-validate` in `tests/` breaks FR-007.
  `test_module_constants` fails today (11 names) and between T002 and T009 (12 names), so it can
  fail.
- Alternatives considered: build the name by string joining in a test (hides the name from the
  search but still tests a special case the spec says does not exist).

## R5. Severity scale

- Decision: critical, high, medium, low on every finding, analysis and validate alike.
- Rationale: C8 and `procedures/analyze.md` step 5 use this scale. The old `st-check` used
  critical, major, minor, and the old `st-validate` had no severity. The gate (S6) shows findings
  by severity, so every finding needs one.
- Alternatives considered: keep critical, major, minor (conflicts with C8 and analyze.md).

## R6. Content of the `## Validate` section

- Decision: The section keeps the old format: date, net verdict, the 4-row check table, and the
  validate findings. Analysis findings and the coverage line go in the report only.
- Rationale: V6 keeps the section as it was. The spec does not ask to store analysis findings in
  `plan.md`. One finding list F1, F2... runs through the report, so a validate finding keeps its
  number in the section.
- Alternatives considered: a fifth table row for the analysis (changes the verdict rule V5).

## R7. Net verdict

- Decision: The net verdict comes from the 4 validate checks only (V5). Analysis findings carry
  severity and show at the gate. A CRITICAL analysis finding is fixed and the agent runs once
  more (S4).
- Rationale: V5 defines the verdict on the checks. C8 and S4 handle analysis severity.
- Alternatives considered: any CRITICAL analysis finding makes the verdict BLOCKED (not in the
  spec).

## R8. Capability check

- Decision: `tests/test_inspect.sh` greps the new files for one or more exact phrases per kept
  capability. The phrases are fixed in `contracts/st-inspect.md`. File paths come from
  `ST_INSPECT_AGENT` and `ST_INSPECT_SKILL`, else the repo files, in the way
  `tests/test_model_hook.py` reads `ST_MODELS_HOOK`.
- Rationale: FR-012 asks for a check that each capability is named. Lesson L1: a phrase check
  must assert text the file has to contain, and no word that every file already holds (such as
  `plan.md` or `CRITICAL`). The env override gives a negative control per item: a scratch copy
  without one item's line turns exactly that check red (quickstart section 2). A missing file
  turns every check red at once, which proves nothing about a single item.
- Alternatives considered: a Python test (the existing grep tests are Bash); greps for single
  words (L1).

## R9. Mid-feature update

- Decision: No migration of `phase: check`. The order checks of `st-inspect` (`plan` or
  `inspect`) and `st-build` (`inspect` or `build`) warn once and run, as for any out-of-order
  phase.
- Rationale: Spec edge case. Calling a phase out of order already gets one warning
  (`DESIGN.md` D9).

## R10. Tools on this machine

- Decision: No setup task.
- Rationale: bash 5.3.20, python3 3.14.7, git 2.56.0, Claude Code 2.1.294. On the current tree
  `python3 -m unittest tests/test_model_hook.py` gives 32 OK and `bash tests/test_model_files.sh`
  passes every check.

## R11. README matches the repo (FR-013)

- Decision: Six rule checks read the repo side from the repo (skill folders, agent files and
  their `model:` lines, named paths, `tests/test_*`, `statusline/themes.json` keys,
  `.claude-plugin/plugin.json` `userConfig` keys) and the README side from `README.md`. Three
  phrase checks hold the fixed descriptions. Contract section 5.
- Rationale: Rules that read both sides fail when either side drifts, so they keep working after
  this feature. Lesson L1: each rule asserts a backticked name or a full table row, not a word
  that a path already holds. Each rule was run on today's README with a scratch script, and each
  negative control turned only its own check red (quickstart section 9).
- Drift found in today's `README.md` (besides the renames in T009):
  - Line 91: the `st-status` row lacks duplicate installs, days since the last upstream sync and
    model overrides (`skills/st-status/SKILL.md:3`).
  - Lines 31-34: the `st-init` paragraph lacks the git guard question, the model question and the
    `AGENTS.md` / `CLAUDE.md` pointers (`skills/st-init/SKILL.md` steps 3, 4, 6).
  - Line 40: `python3` is listed for "git guard, scripts" only. It also runs `hooks/st-models.py`
    and the Python in `statusline/st-statusline.sh` and `hooks/st-handoff-facts.sh`.
- Checked and current: install commands match `.claude-plugin/marketplace.json` (name
  `stratum`); every skill folder, agent and default model, theme, shape, git guard option, hook
  event of the handoff (SessionEnd, PreCompact), path, link and test file named in the README.
  `mods/` is not tracked, so the README does not name it.
- Alternatives considered: a fixed list of paths in the test (misses new README paths and new
  repo files).
