# 008 route-lessons

What: Close stops writing `docs/lessons.md`. It reports each lesson with a target file and the
reason: the repo constitution, an app constitution, or the app ordinance. On the user's keep, the
main session writes the rule there. Plan and Inspect stop reading `docs/lessons.md` (undoes part of
change 007). st-constitution and st-init state the split. Source: issue #56, decisions D1 to D4.
FRs: none. spec.md has no FR for lessons (same precedent as change 007).
Impact area: core runtime (agent and skill text, docs, one test file)

## Files
Shared text, used where marked [TABLE] and [TEST]:

[TABLE]
```
| File | Holds | Loads |
| --- | --- | --- |
| `.stratum/constitution.md` | Rules for the whole repo | Every session |
| `.stratum/<app>-constitution.md` | How we work on one app: git, branches, staging, lanes, proof, PRs, releases | Every session in that app's worktrees |
| `apps/<app>/ORDINANCE.md` (loaded by a one-line `apps/<app>/CLAUDE.md` with `@ORDINANCE.md`) | Rules about the app's code and specs | Only when work touches `apps/<app>/` |
```
[TEST] `Must the rule apply before any file of the app is opened (a branch, merge or lane decision)? Then a constitution. Otherwise the ordinance. With no \`apps/\` folder, \`.stratum/constitution.md\` is the only target.`

- `agents/st-close.md:52-57` (step 3 body) - replace with:
  `Propose lessons in your report only. Write no lessons file and no target file. Only lessons with evidence from this feature. Each lesson: what happened, the rule in one sentence that a test or a check can fail, the target file, and the reason for that target.`
  then the three targets in one line (repo constitution `.stratum/constitution.md`, app constitution
  `.stratum/<app>-constitution.md`, app ordinance `apps/<app>/ORDINANCE.md`), then
  `The app is \`apps/<app>/\` when the feature's changed files are under it. If they are under more than one app, name the app the lesson is about. If no changed file is under \`apps/\`, the target is \`.stratum/constitution.md\`.` then [TEST].
  Keep line 59 ("Changes to the constitution or the harness are proposals..."). Do not touch
  line 20 or line 68 (H1, H2 checks).
- `agents/st-close.md:79` (Report) - add a line before it:
  `- Lessons as L1, L2... each: the rule, the target file, the reason.`
- `skills/st-close/SKILL.md:33-36` (step 5) - replace with:
  `**Lessons.** \`st-close\` reports each lesson with its target file and the reason. For each, the user picks keep, another target, or drop. On keep, write the rule to the target file yourself. For a constitution target, bump its \`**Version**\` (MINOR for a new rule, per \`<plugin root>/procedures/constitution.md\` step 2) and set \`**Last Amended**\` to today. If the app constitution is missing, create it with that one rule, \`**Version**\` 1.0.0 and today's \`**Last Amended**\`. Then show the user the line \`@.stratum/<app>-constitution.md\` for the CLAUDE.md that loads in that app's worktrees. If \`.stratum/constitution.md\` is the target and is missing, tell the user and do not write the rule. For an ordinance target, create \`apps/<app>/ORDINANCE.md\` if it is missing, and make sure \`apps/<app>/CLAUDE.md\` has the line \`@ORDINANCE.md\` (create the file with that one line if it is missing). Show the user any other proposed constitution or harness change. Never apply one without their OK.`
- `skills/st-close/SKILL.md:45` (step 8) - after "with exact paths" add `, and the files step 5 wrote`.
- `agents/st-plan.md:20` - delete the `docs/lessons.md` bullet. `:49-52` - delete the lesson gate rule.
- `agents/st-inspect.md:21` - delete the `docs/lessons.md` bullet. `:43` - delete the Lessons item.
- `skills/st-fast/SKILL.md:31` (step 8) - after `("Shortcuts" step)` add
  `, and a proposed lesson as in its "Lessons" step`.
- `skills/st-fast/SKILL.md:36` - replace `` `docs/lessons.md` if it wrote a lesson`` with
  `the files a kept lesson went to`. Also: `If it changed no docs, skip this step.` becomes
  `If it changed no docs and no lesson was kept, skip this step.`
- `skills/st-constitution/SKILL.md` - add a section `## Where rules go` before "Never skip": [TABLE], then [TEST].
- `skills/st-init/SKILL.md:31-33` (step 5) - add after it: `Rules live in three files. st-init makes only the first. Close proposes the target for each kept lesson.` then [TABLE] and [TEST], indented under step 5.
- `DESIGN.md:149` - replace with:
  `3. Lessons: proposed in the report, each with a target file and the reason: repo constitution, app constitution, or app ordinance. On the user's keep, the main session writes the rule there.`
- `README.md:81` - delete only the sentence `It reads \`docs/lessons.md\` and cites the lessons that apply.`
- `tests/test_inspect.sh:147-155` - replace the seven lessons rows (see Tests).
- Not changed: `docs/lessons.md` (D1). `hooks/`, `procedures/`, `templates/` name no `docs/lessons.md`.
  `skills/st-graphify/references/query.md:188` is graphify's own `LESSONS.md`.

## Tests (written first, must fail before the build)
All in `tests/test_inspect.sh`. Replace lines 147-155 with one `phrases` block and one `check`.
Phrases are short so a line wrap cannot split them.
- T1 `lessons st-close target` - `agents/st-close.md` has `the target file, and the reason for that target` and `before any file of the app is opened`.
- T2 `lessons st-close write` - `skills/st-close/SKILL.md` has `write the rule to the target file yourself` and `` `@ORDINANCE.md` ``.
- T3 `lessons st-fast` - `skills/st-fast/SKILL.md` has `the files a kept lesson went to`.
- T4 `split st-constitution` - `skills/st-constitution/SKILL.md` has `` | `apps/<app>/ORDINANCE.md` `` and `before any file of the app is opened`.
- T5 `split st-init` - `skills/st-init/SKILL.md` has the same two phrases as T4.
- T6 `lessons design` - `DESIGN.md` has `each with a target file and the reason`.
- T7 negative, modeled on line 164:
  `check "no docs/lessons.md" '! grep -rqF -- "docs/lessons.md" "$root/agents" "$root/skills" "$root/DESIGN.md" "$root/README.md"'`
Command: `PYTHONDONTWRITEBYTECODE=1 bash tests/test_inspect.sh`. Today: 7 FAIL lines (T1 to T7; T7 is red
through `agents/st-plan.md:20`), all other lines `ok`. After the build: all `ok`.
Negative control: after the build, add `docs/lessons.md` back to one line of `README.md`, see T7 go red,
restore. Remove the T2 phrase from the skill once, see T2 go red, restore.

## Risks
- T1 to T7 check text, not behavior. No live Close run is planned.
- The app rule is D2: changed files under `apps/<app>/`. With more than one app, Close names the app the lesson is about.
- An app constitution target may not exist yet. Step 5 then creates it with that one rule, Version 1.0.0 and today's Last Amended, without the template.
- The review fixes (the no-changed-file sentence in st-close step 3, the missing-target rules in st-close step 5, the no-lesson skip rule in st-fast step 9) got phrase rows after the review, not test-first.
