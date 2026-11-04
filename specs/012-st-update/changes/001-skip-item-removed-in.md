# 001 skip-item-removed-in

What: The st-update gate takes `skip <folder> <kind> <name>` (one or more) besides
`skip <worktree>`. A skipped item is left out of every step after the gate and the report names
it. `audit` gives a `new` `ignore` or `pointer` row whose line a past commit of the fix's file
added or removed, and which is not in that file now, the detail `removed in <sha>`. The state stays
`new`. No stored baseline.
FRs: FR-009 (gate and skip), FR-004 (row detail), FR-019 (report names what was skipped).
Impact area: core runtime

## Decisions (defaults planned below)
- D1. Item syntax at the gate: `skip <folder> <kind> <name>`, the three values as the table shows
  them. A skipped `install` item also takes that folder out of step 4 (no `plugin` call).
  An `allow` row takes the form `fix` takes (skills/st-update/SKILL.md:38):
  `skip <folder> allow <settings file>:<entry>`. The same entry can be in both settings files,
  so folder, kind and name name two rows (scripts/st-update.sh:297-304).
- D2. The detail is replaced by `removed in <sha>` (today it is `.gitignore` or `CLAUDE.md`).
  Nothing reads that detail: `fix` matches `r[:3]` (scripts/st-update.sh:362), `mark` uses `FN`
  (scripts/st-update.sh:326).
- D3. Lookup: `git log -1 --no-show-signature --first-parent --format=%h -G^<line>$ -- <file>`,
  the `-G` value passed as one list argument. The sha goes through `clean()`. Every
  POSIX ERE special character in the line is escaped with a backslash:
  `. [ ] ( ) * + ? { } | ^ $ \`. `-G` with anchors matches the whole line. `-S` would also
  match `.stratum/models.json.bak`. The names are the static `IGNORE` and pointer constants,
  never user input. Short sha (`%h`).
- D4. spec.md FR-009 and spec.md:62 name only `skip <worktree>`. The Close step of this change
  updates both to also name `skip <item>`. No spec edit now.

## Files
- `scripts/st-update.sh:324-334` - in the audit `mark()`, after the detached and dirty checks: when
  `kind in ("ignore", "pointer")` (the state can only be `new` there), `f in paths`, and the name is not a
  stripped line of `<f>/<FN[kind]>` (`read()`), run `git("-C", f, "log", "-1", "--no-show-signature", "--first-parent", "--format=%h",
  "-G^" + re.sub(r"([.\[\]()*+?{}|^$\\])", r"\\\1", name) + "$", "--", FN[kind])`. Exit 0 with a sha: detail
  `removed in <sha>`. Else keep the row. Non-git folders already return early
  (`wt.returncode`). Do not put the words add, commit or push on that source line (U19 grep).
- `skills/st-update/SKILL.md:23` - the question becomes: OK to update all, or `skip <worktree>`
  or `skip <folder> <kind> <name>` (one or more each), or no. Keep the substring
  "OK to update all, or `skip <worktree>`" (R3).
- `skills/st-update/SKILL.md:26` - "A skipped worktree is left out ..." becomes
  "A skipped worktree or item is left out of every step after the gate, and the report names it."
  Add: "An item is named by its folder, kind and name, as the table shows them."
  Add: "An `allow` item is named as `fix` names it: `skip <folder> allow <settings file>:<entry>`."
  Add: "A skip that names no row: say so and ask again."
- `skills/st-update/SKILL.md:27` - step 4: "skipped worktrees and skipped `install` items left out".
- `skills/st-update/SKILL.md:32` - after "Steps 5 to 7 take their rows from this second audit."
  (keep that sentence for R5c) add "Leave the skipped worktrees and items out of these rows."
- `skills/st-update/SKILL.md:56` - step 8: add "Name each worktree and item skipped at the gate."
- `specs/012-st-update/contracts/st-update.md` section 1b - one bullet for the `removed in <sha>`
  detail (D2, D3): only `new` `ignore` and `pointer` rows of a git checkout, the file is
  `.gitignore` or `CLAUDE.md` (where the fix appends, not `AGENTS.md` or `CLAUDE.local.md`), state
  stays `new`, read only. Section 2 steps 3, 4 and 8 - the same text as SKILL.md. Section 3 - row
  U25, U26, rows R3c, R3d, R3e, R3f, R5d, R11c.

## Tests (written first, must fail before the build)
- `tests/test_update_rules.sh` - new phrase rows on `skills/st-update/SKILL.md`:
  R3c "or `skip <folder> <kind> <name>`", R3d "An item is named by its folder, kind and name, as
  the table shows them.", R3e "A skipped worktree or item is left out of every step after the
  gate", R3f "`skip <folder> allow <settings file>:<entry>`", R5d "Leave the skipped worktrees and items out of these rows.", R11c "Name each worktree
  and item skipped at the gate.", R3g "A skip that names no row: say so and ask again." -
  `bash tests/test_update_rules.sh`
- `tests/test_st_update.sh` - new fixture `$tmp/u25` (label U25, folders u22 to u24 already
  exist): git repo with `.stratum/`, `AGENTS.md`; commit 1 has `.gitignore` with
  `.stratum/models.json` and `.stratum/weather.json.bak`, and `CLAUDE.md` with `@AGENTS.md` and
  `@.stratum/constitution.md`; commit 2 drops `.stratum/models.json`,
  `.stratum/weather.json.bak` and `@.stratum/constitution.md`; `sha` = `git log -1 --format=%h`
  of commit 2. Checks after `audit "$tmp/u25"`:
  - U25 `ignore .stratum/models.json` `cut -f4,5` is `new<TAB>removed in $sha`.
  - U25 `pointer @.stratum/constitution.md` `cut -f4,5` is `new<TAB>removed in $sha`.
  - U25 `ignore .stratum/handoff.md` (never committed) `cut -f4,5` is `new<TAB>.gitignore`.
  - U25 `ignore .stratum/weather.json` (only `.bak` was removed) detail is `.gitignore` (fails with
    `-S`, D3).
  - U25 non-git folder `$tmp/u23` pointer `@.stratum/constitution.md` detail is `CLAUDE.md`.
  - U25 after `printf 'x\n' >> "$tmp/u25/.gitignore"` and a second audit:
    `ignore .stratum/models.json` is `skip<TAB>.gitignore has uncommitted changes` (the dirty
    check wins over the lookup).
  - U25 `.stratum/lessons.md` and `!.stratum/lessons.md` in both commits of `.gitignore`:
    `ignore .stratum/lessons.md` stays `new<TAB>.gitignore` (the line is in the file now, so no
    lookup).
  - U25 `x/.stratum/powerline.json` in commit 1 only: `ignore .stratum/powerline.json` stays
    `new<TAB>.gitignore` (the `^` anchor).
  - U25 `xstratum/handoff_md` in commit 1 only: the `.stratum/handoff.md` check above fails when
    the escape is removed.
  - U25 escape: no name in the item list holds an ERE special character other than `.`
    (`IGNORE` at scripts/st-update.sh:22-23, the two pointer names). No audit check can reach the
    other characters. The escape is planned so a future name stays a literal match.
- `tests/test_st_update.sh` - new fixture `$tmp/u26` (label U26), a non-git folder with
  `.stratum/` and `.claude/`. Both `.claude/settings.json` and `.claude/settings.local.json` hold
  `{"permissions": {"allow": ["Skill(stratum:st-gone)"]}}`. Checks:
  - U26 `audit` gives two `allow` rows named `Skill(stratum:st-gone)`, both `discontinued`, with
    details `.claude/settings.json` and `.claude/settings.local.json`.
  - U26 the user skips the `.claude/settings.json` row. Only
    `fix "$tmp/u26" allow ".claude/settings.local.json:Skill(stratum:st-gone)"` runs: exit 0,
    `changed .claude/settings.local.json`.
  - U26 `.claude/settings.json` is byte-equal (the skipped row is untouched).
  - U26 a second `audit`: the `.claude/settings.json` row is still `discontinued`, and the
    `.claude/settings.local.json` row is gone.
  - These checks pass before the build (the script already keys `allow` by file). They guard the
    script side of D1. The gate parsing is skill text: R3f checks it.
  - `bash tests/test_st_update.sh`
- Unchanged, run after: `bash tests/test_update_items.sh`.

## Risks
- R1. `git log -G` scans the history of two files per checkout, up to 9 calls per checkout. Cheap
  in v2-veent's 7 worktrees. Not measured.
- R2. Without `--first-parent`, `git log` does not diff merges, so a removal done only in a
  merge commit's conflict fix does not show and the row names the commit that added the line.
  `--first-parent` diffs each merge against its first parent: such a removal shows as the merge
  sha, and a removal on a merged branch also shows as the merge sha.
- R3. `git log` is read only. U8 (no file change) and U19 (no add, commit, push) stay green if the
  source line has none of those words.
- R4. The word "skip" now means a gate answer and a row state. The report keeps them apart by
  "skipped at the gate" versus each `skip` row with its detail.
