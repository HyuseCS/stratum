# 003 init-commit-standard

What: `/stratum:st-init` asks one question in step 1: turn on the commit subject check? On yes it writes the empty, committed file `.stratum/commit-standard` (the opt-in marker of change 002). Step 13 commits the marker and, when the marker exists, gives its own commit a fixed subject that passes the check. The README tells a user about the switch.
FRs: none in spec.md fit. Extends D21 (change 002, GitHub #97). Recorded as D22 in decisions.md.
Impact area: core runtime

Line numbers below are those of the files before the edit. Step 1 adds two lines, so step 13 moves down by two.

## Where the question goes, and why step 1
- Step 1 (Data files) is named by number in no other file, and it has no question of its own.
- Step 3, 4, 7 and 11 are named by `skills/st-update/SKILL.md:47` ("ask the question of st-init step 3, 4, 7 or 11"). A second question there would make `/stratum:st-update` ask it too.
- Step 12 is named by `skills/st-update/SKILL.md:51` ("the question of st-init step 12"), and its first sentence skips the whole step.
- Step 2 is read by `tests/test_update_items.sh:12`: every backticked name in it must be an st-update item.
- Step 13 starts with the pinned `13. **Report**` (GI4), and the question must come before the step 13 commit.

## Files
- `skills/st-init/SKILL.md` step 1 - add two lines after line 12. Line 11 and 12 stay as they are. No step gets a new number. Exact text (default no, see Q1):
  ```
     If `.stratum/commit-standard` is missing, ask one question: "Turn on the commit subject check (optional, default no)? The git guard then denies a commit subject that is not `type(scope): what`, like `fix(019): handle empty list`."
     Yes: write the empty file `.stratum/commit-standard`. It is committed. No: write nothing. Say how to change it later: add or delete the file.
  ```
- `skills/st-init/SKILL.md` step 13 (lines 89-90) - in the commit list, insert `` `.stratum/commit-standard`, `` after `` `.stratum/git-instructions-kept`, ``. Change line 90 to one physical line. Result:
  ```
     `.stratum/constitution.md`, `.stratum/advisor.json`, `.stratum/git-instructions-kept`, `.stratum/commit-standard`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`),
     through the commit guard. When `.stratum/commit-standard` exists, the commit subject is `chore(stratum): set up Stratum`.
  ```
  The subject matches `SUBJECT` in `hooks/st-git-guard.py:27` (checked), is 30 characters, and has no final period. A project with no marker keeps its own subject form (D21, `agents/st-git.md` step 6).
- `README.md` - one new line in the **Git guard** bullet, after the line that ends `is not checked.` (line 287) and before `- **Worker guard.**`:
  ```
    A project with the empty, committed file `.stratum/commit-standard` also gets its commit subjects checked: the guard denies a `git commit -m` subject that is not `type(scope): what` (`agents/st-git.md` step 6). `st-init` asks whether to write it (default no). Delete the file to turn the check off.
  ```
  The st-init paragraph (lines 31-35) does not change. `tests/test_inspect.sh:143-144` pins it.
- `DESIGN.md:204` - the row becomes: `` | `.stratum/commit-standard` | own | Committed. `st-init` writes the empty marker on a yes to its commit subject question. The marker turns on the commit subject checks of `st-git-guard.py` and the subject sentence of the session text. | ``. This is the twin of the row at line 203.
- `docs/harness/model/skills-tools.c4` - after line 220, add two edges, the twins of the `git-instructions-kept` edges:
  `skills.st-init -[reads]-> stratum.commit-standard 'exists check'` and
  `skills.st-init -[writes]-> stratum.commit-standard 'empty marker on yes'`. No st-update edge.
- `docs/harness/model/data.c4:70` - the summary becomes `A committed empty marker that turns on the commit subject checks. st-init writes it on a yes, and st-git-guard.py and the session start hook read it.` (2 sentences, 149 characters, `c_summaries` allows 200).
- `docs/harness/README.md` - regenerate with `npx -y likec4@1.60.0 export markdown docs/harness`. The `rebuild` check of `tests/test_harness_model.sh` needs this.
- `specs/019-autonomous-prompts/decisions.md` - one line after D21: `- D22 (change 003): st-init step 1 asks once, when `.stratum/commit-standard` is missing, whether to write it (default no). st-update does not ask it. When the marker exists, the st-init commit subject is `chore(stratum): set up Stratum`. Rejected: the question in st-update, a "kept" marker for a no answer.`
- `tests/test_update_rules.sh` and `tests/test_git_guard.py` - the tests below.

Not in scope:
- `/stratum:st-update` does not ask this question in existing projects. R7 (`skills/st-update/SKILL.md:47`) and GI5 (`:51`) do not change. The `st-update -[reads]-> st-init 'questions of steps 3, 4, 7 and 11'` edge stays.
- No "kept" marker for a no answer. A second run of st-init asks again.
- `agents/st-git.md`, `hooks/st-git-guard.py`, `hooks/st-session-start.sh`, `skills/st-constitution/SKILL.md`: no change.
- No new script, hook or plugin option.

## Tests (written first, must fail before the build)
- `tests/test_update_rules.sh` - new rows in the `ROWS` block, after GI9b. Each is red today because the text is not there. A deleted or reworded phrase turns it red again:
  ```
  CS1|skills/st-init/SKILL.md|If `.stratum/commit-standard` is missing, ask one question: "Turn on the commit subject check (optional, default no)?
  CS1b|skills/st-init/SKILL.md|The git guard then denies a commit subject that is not `type(scope): what`, like `fix(019): handle empty list`."
  CS1c|skills/st-init/SKILL.md|Yes: write the empty file `.stratum/commit-standard`. It is committed. No: write nothing.
  CS2|skills/st-init/SKILL.md|`.stratum/git-instructions-kept`, `.stratum/commit-standard`, `.gitignore`,
  CS3|skills/st-init/SKILL.md|When `.stratum/commit-standard` exists, the commit subject is `chore(stratum): set up Stratum`.
  CS4|README.md|A project with the empty, committed file `.stratum/commit-standard` also gets its commit subjects checked
  CS4b|README.md|`st-init` asks whether to write it (default no). Delete the file to turn the check off.
  ```
  Breaks: CS1 and CS1b go red when the question is removed or reworded. CS1c goes red when the yes branch does not write the file. CS2 goes red when the marker is left out of the commit list. CS3 goes red when the subject sentence is removed. CS4 and CS4b go red when the README line is removed.
- `tests/test_update_rules.sh` - two `check` lines after the `ROWS` block:
  - `check "CS5 st-init step 1 asks the commit standard question" 'sed -n "/^1\. /,/^2\. /p" "$root/skills/st-init/SKILL.md" | grep -qF "If \`.stratum/commit-standard\` is missing, ask one question"'`. Red today. Red again if the question moves into step 12, where the skip rule skips it, or into any other step.
  - `check "CS6 st-update does not ask the commit standard question" '[ -f "$root/skills/st-update/SKILL.md" ] && ! grep -qF -- commit-standard "$root/skills/st-update/SKILL.md"'`. This is a guard, so it is green before and after the build. It goes red if `.stratum/commit-standard` is added to st-update.
- Existing rows stay green with no edit: GI1 `12. **Git instructions.**`, GI4 `13. **Report**`, GI4c `` `.stratum/advisor.json`, `.stratum/git-instructions-kept`, ``, R7, and the step-range checks of `tests/test_model_files.sh:23-26`.
- `tests/test_git_guard.py` - new method `test_st_init_commit_subject_passes_the_standard` in `GitGuardTest`. It calls `self.opt_in()` and `self.set_mode("auto")`, and reads `skills/st-init/SKILL.md` from `os.path.dirname(os.path.abspath(__file__))/..`. It finds the subject with `re.search(r"the commit subject is `([^`]+)`", text)` (add `import re`). The step 1 question says "commit subject that is not", so it does not match. Then it asserts the match is not `None` and `self.run_guard("git commit -m " + shlex.quote(m[1])) == (None, "")`. Red today: no match. Break: a subject such as `Set up Stratum` gets `deny` and turns it red. This links the skill text to the guard regex.
- Commands: `bash tests/test_update_rules.sh`, `python3 -m unittest tests.test_git_guard` (from the repo root), `bash tests/test_harness_model.sh`.
- Full run: `for t in tests/test_*.sh; do bash "$t" >/dev/null 2>&1 || { echo "FAIL $t"; exit 1; }; done; python3 -m unittest discover -s tests -p "test_*.py"`.

## Risks
- R1: On yes, the marker exists from step 1, so the step 5 constitution commit (st-constitution has `st-git` commit `.stratum/constitution.md`) also gets the subject check. `agents/st-git.md` step 6 tells st-git to use `type(scope): what` when the marker exists. Its `Commit message denied:` exception (GI9b) rewrites the subject and runs the commit once more. The session text still has no subject sentence, because `hooks/st-session-start.sh:26` reads the marker only at session start.
- R3: A no answer writes nothing, so a second run of st-init asks again. This is accepted: st-init runs once per project, and st-update does not ask.
- R4: With default yes (Q1, other option), a user who presses Enter in a project with its own subject form gets every commit with that form denied, in every session, until the file is deleted.
- R5: `docs/harness/README.md` must be regenerated with likec4 1.60.0 on node 22.22.3 or later. When node is older, the `rebuild` check prints SKIP and does not catch a stale page.

## Open decisions
- Q1: Default answer of the new question. My pick is no. A wrong default yes denies every commit of a project that uses another subject form. A wrong no is fixed by adding one file. Also, D21 made the check opt-in.
  - Default no (in this plan): `Turn on the commit subject check (optional, default no)? The git guard then denies a commit subject that is not `type(scope): what`, like `fix(019): handle empty list`.`
  - Default yes: `Turn on the commit subject check (recommended, default yes)? The git guard then denies a commit subject that is not `type(scope): what`, like `fix(019): handle empty list`.` With yes, these change to match: the CS1 pin, the README line and its CS4b pin (`(default yes)`), and the D22 line.
