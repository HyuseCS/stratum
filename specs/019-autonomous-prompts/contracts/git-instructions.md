# Contract: built-in git instructions off, and the `-m` commit form in Stratum text (US3, FR-008 to FR-010, FR-016, D8, D8a, D16)

## 1. "Set at any level", "off at some level" and the marker (research P5, CHK016)

For a checkout `<c>`, the setting is set at some level when any of these holds:
- the env var `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` is set (Claude Code reads it first);
- `<c>/.claude/settings.json`, `<c>/.claude/settings.local.json` or `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json` has the key `includeGitInstructions`, with any value.

Check: `jq -e 'has("includeGitInstructions")' <file>` on each file that exists.

"Not at all" marker (D16): the empty file `<c>/.stratum/git-instructions-kept`. It records the user's "not at all" answer. It is committed, so every checkout and machine of the project sees it. `st-init` and `st-update` do not ask when the setting is set at some level or the marker exists.

Off at some level (used only by the FR-016 hint, §5): the env var is set, or one of the three files has `includeGitInstructions` equal to `false` (`jq -e '.includeGitInstructions == false'`).

## 2. Scopes and files (CHK014)

| Answer | File written | Committed |
|--------|--------------|-----------|
| project (recommended, all machines) | `<c>/.claude/settings.json` | yes |
| user (all projects on this machine) | `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json` | no (global file) |
| local (this repo on this machine) | `<c>/.claude/settings.local.json` | no (git-ignored) |
| not at all | the empty marker `<c>/.stratum/git-instructions-kept`, no settings file | yes |

Write: merge `"includeGitInstructions": false` with jq into the one file, keep every other key and its value (CHK015). A missing file is made as `{"includeGitInstructions": false}`. A file that is not valid JSON: write nothing, and name the file in the report.

## 3. `skills/st-init/SKILL.md`

New step 12 after step 11 (Advisor). The Report step becomes 13. Steps 1-11 keep their numbers (`tests/test_update_rules.sh` R7 and `skills/st-update/SKILL.md` step 6 name steps 3, 4, 7 and 11). Exact text:

```markdown
12. **Git instructions.** Claude Code's built-in git instructions teach commit messages in a heredoc, which the git guard denies. If `.stratum/git-instructions-kept` exists, or the setting is already set at any level (`CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` is set, or `includeGitInstructions` is in `.claude/settings.json`, `.claude/settings.local.json` or `<config folder>/settings.json`, where the config folder is `$CLAUDE_CONFIG_DIR`, else `~/.claude`), skip this step. Else ask one question: turn them off in the project (`.claude/settings.json`, recommended: all machines), for the user (`<config folder>/settings.json`: all projects on this machine), only locally (`.claude/settings.local.json`: this repo on this machine), or not at all? Merge `"includeGitInstructions": false` with jq into only that file. Keep every other key. Not at all: write no settings file, and write the empty file `.stratum/git-instructions-kept` so the question is not asked again. The user answer is the only time st-init writes a global file.
```

Step 13 (Report): in the commit list, change `` `.stratum/advisor.json`, `` to `` `.stratum/advisor.json`, `.stratum/git-instructions-kept`, ``. `.claude/settings.json` is already in it.

## 4. `skills/st-update/SKILL.md`

At the end of step 6, one paragraph. Exact text:

```markdown
   Built-in git instructions, once per run: list the folders left after the gate that have no `.stratum/git-instructions-kept` and where the setting is at no level (the tests of st-init step 12, run per folder). None: skip. Else ask the question of st-init step 12 once, naming those folders, with a `skip` answer. Write it as st-init step 12 does: the project or local file of each listed folder, the user file once, or for "not at all" the marker in each listed folder. Skip: write nothing.
   <!-- ponytail: one-time step for checkouts set up before 019, remove it when every Stratum checkout on the PC and the laptop has run this update (check: no checkout prints a folder in this list) -->
```

Step 7 (Commit): the line at `skills/st-update/SKILL.md:52` reads ``   and `.stratum/advisor.json` when step 6 wrote it, minus each file that `git check-ignore` ignores.`` Insert after ``when step 6 wrote it,`` the text `` and `.claude/settings.json` or `.stratum/git-instructions-kept` when the git instructions paragraph wrote it,`` so the line reads ``   and `.stratum/advisor.json` when step 6 wrote it, and `.claude/settings.json` or `.stratum/git-instructions-kept` when the git instructions paragraph wrote it, minus each file that `git check-ignore` ignores.``

A later run finds the key at some level, or the marker, and does not ask again (US3 scenario 3, FR-009).

## 5. Turn-on hint (FR-016, D16)

`scripts/st-worker.sh autonomous-on` (`:695-705`): after the line `autonomous on<TAB>local`, when the git instructions are not off at some level (§1, with `<c>` = `git rev-parse --show-toplevel` of the current folder), print one more line, exactly:

```text
hint	Autonomous build mode works better with Claude Code's built-in git instructions off: add "includeGitInstructions": false to .claude/settings.json (this project) or ~/.claude/settings.json (all projects), then start new sessions.
```

`skills/st/SKILL.md:89`: replace `show its line word for word` with `show its lines word for word (the `autonomous on` line and, when printed, the `hint` line)`. Row W8 of `tests/test_worker_rules.sh` holds the whole sentence and changes the same way.

A hint only: exit 0 either way, and the entry is made either way. A settings file that is not valid JSON counts as "not off". A turn-on that fails prints no hint. The marker does not stop the hint (FR-016 names only the setting).

## 6. Commit form text (FR-010)

`agents/st-git.md` step 6, a new first bullet. Exact text:

```markdown
   - Run it as `git commit -m 'subject' -m 'body'`: single quotes, no heredoc, no backticks, no `$(`, no `-F`. Write an apostrophe as `'\''`.
```

`agents/st-git.md` Rules, after the line "A commit hook fails or the commit guard denies: stop and report its exact text. Do not retry around it." Exact text:

```markdown
- Exception: a deny that starts with `Commit form denied:`. Write the same message as `git commit -m 'subject' -m 'body'` and run it once more. A second deny: stop and report.
```

`hooks/st-session-start.sh:25`, the `Stratum rule:` line: add after `The git guard reads Bash text and stops on git words it cannot parse.` this printed text (escape `$` in the double-quoted echo):

```text
Commit with git commit -m 'subject' -m 'body': single quotes, no heredoc, no backticks and no $(. The git guard denies other forms.
```

`scripts/st-worker.sh:253`, brief rule 5: replace `` `git add <path> <path> && git commit -m "<subject>" -m "<body>"` `` with `` `git add <path> <path> && git commit -m '<subject>' -m '<body>'` ``. The rest of the rule stays. The rule is a single-quoted bash string, so each `'` inside it is written `'"'"'` (as rule 4 does for `teammate's`). `tests/test_st_worker.sh:237` holds the same text and changes with it.

## 7. Test rows

`tests/test_update_rules.sh` (format `ID|file|phrase`, `grep -qF`):

| Id | File | Phrase |
|----|------|--------|
| GI1 | `skills/st-init/SKILL.md` | `12. **Git instructions.**` |
| GI2 | `skills/st-init/SKILL.md` | `with jq into only that file. Keep every other key.` |
| GI3 | `skills/st-init/SKILL.md` | `` `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` is set `` |
| GI4 | `skills/st-init/SKILL.md` | `13. **Report**` |
| GI4b | `skills/st-init/SKILL.md` | `Not at all: write no settings file, and write the empty file `.stratum/git-instructions-kept` so the question is not asked again.` |
| GI4c | `skills/st-init/SKILL.md` | `` `.stratum/advisor.json`, `.stratum/git-instructions-kept`, `` |
| GI5 | `skills/st-update/SKILL.md` | `Built-in git instructions, once per run:` |
| GI5b | `skills/st-update/SKILL.md` | `or for "not at all" the marker in each listed folder` |
| GI6 | `skills/st-update/SKILL.md` | `ponytail: one-time step for checkouts set up before 019, remove it when every Stratum checkout on the PC and the laptop has run this update` |
| GI7 | `skills/st-update/SKILL.md` | ``and `.claude/settings.json` or `.stratum/git-instructions-kept` when the git instructions paragraph wrote it,`` |
| GI8 | `agents/st-git.md` | ``Run it as `git commit -m 'subject' -m 'body'`: single quotes, no heredoc, no backticks, no `$(`, no `-F`.`` |
| GI9 | `agents/st-git.md` | ``Exception: a deny that starts with `Commit form denied:`.`` |

`tests/test_session_hooks.sh`: one check that the hook output holds `Commit with git commit -m 'subject' -m 'body': single quotes, no heredoc, no backticks and no $(. The git guard denies other forms.`

`tests/test_st_worker.sh`:
- `:237`: rule 5 with the single-quoted form (the brief test compares the whole rules block).
- At the top of the file: export `CLAUDE_CONFIG_DIR="$tmp/cfg"` and `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1`, so ON1-ON9 keep their exact one-line output and no case reads the real `~/.claude`.
- Hint cases, each `autonomous-on` from `$repo` with `env -u CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` unless the row says so:

| Id | Setup | Expect |
|----|-------|--------|
| HI1 | no setting anywhere | exit 0, two lines: `autonomous on<TAB>local` and the exact §5 hint line; the entry exists |
| HI2 | `$repo/.claude/settings.json` = `{"a": 1, "includeGitInstructions": false}` | exit 0, only the on line |
| HI3 | `$repo/.claude/settings.local.json` with `false` | only the on line |
| HI4 | `$CLAUDE_CONFIG_DIR/settings.json` with `false` | only the on line |
| HI5 | `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1` | only the on line |
| HI6 | `$repo/.claude/settings.json` with `true` | the hint line |
| HI7 | `$repo/.claude/settings.json` = `{not json` | exit 0, the hint line |
| HI8 | an id that fails (`../x`) | exit 1, the existing fail line, no hint line |
