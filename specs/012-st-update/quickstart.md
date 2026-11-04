# Quickstart: st-update

Run from `/home/hyuse/Desktop/stratum`. Needs `git`, `python3`, `bash`. The fixture tests need no
`claude`: they put a stub on `PATH`.

## 1. Tests

```bash
bash tests/test_st_update.sh
bash tests/test_update_rules.sh
bash tests/test_update_items.sh
bash tests/test_inspect.sh
bash tests/test_no_frontend_design.sh
bash tests/test_local_files.sh
claude plugin validate .claude-plugin/plugin.json
```

Expected: every check line `ok`, exit 0. Cases are in [contracts/st-update.md](contracts/st-update.md)
section 3.

## 2. Negative controls

Each must go red, then green again after the undo. Undo with the Edit tool, not `git checkout`.

| # | Break | Expected |
|---|-------|----------|
| N1 | Add `` `.stratum/zz-drift.json` `` to step 2 of `skills/st-init/SKILL.md` | Covered by the built-in control of `tests/test_update_items.sh` (T013, contract section 4 step 4), which runs on every green run. Not run by hand |
| N2 | Remove the line `graphify-out/` from the `items` list in `scripts/st-update.sh` | `bash tests/test_update_items.sh` exits 1 and names `graphify-out/` |
| N3 | In `scripts/st-update.sh` `fix statusline`, drop the check that the record is updated | U11 in `bash tests/test_st_update.sh` fails |
| N4 | In `audit`, drop the `git status` check | U15 fails |
| N5 | In `plugin`, drop the check of other records | U10 fails |
| N6 | Delete the README row for `st-update` | `bash tests/test_inspect.sh` fails "README skills" |
| N7 | In `audit`, drop the `marketplace-branch` row | U20 fails |
| N8 | In `audit`, check `.gitignore` text instead of `git check-ignore` | U7 fails on the `.git/info/exclude` case |

## 3. Live run on this machine (after the build, at the user's word)

Only the user runs this section. Build and tests never call the real `claude plugin update`.

Order first: merge the PR, bump to 0.7.0 on `main` (T016), then run
`claude plugin update stratum@stratum -s local` in the project, restart, then `/stratum:st-update`.
Without the bump, `claude plugin update` sees 0.6.0 as the latest and changes nothing.

State on 2026-11-04: marketplace `/home/hyuse/Desktop/stratum` (directory source, on branch
`012-st-update` until merge, so the gate warns until then). v2-veent's record is 0.6.0, most
others are 0.1.22 to 0.2.1. v2-veent's `statusLine` points at the source folder. After the 0.7.0
bump and the merge to `main`, every record is outdated.

1. First time, in the project folder, as the README says:
   `claude plugin update stratum@stratum -s local`. Restart the session.
2. Snapshot: `sha256sum ~/.claude/plugins/installed_plugins.json`, and
   `git -C <checkout> status --porcelain` plus `sha256sum <checkout>/.claude/settings.local.json`
   for each checkout of `git -C /home/hyuse/Desktop/VeentApps/v2-veent worktree list`.
3. `/stratum:st-update /home/hyuse/Desktop/VeentApps/v2-veent`. Check the table: one block per
   checkout, `install` and `statusLine` outdated, worker worktrees marked. Answer no.
4. Snapshot again: all the same (FR-010, acceptance US1-5).
5. Run it again and answer OK (or `skip` a worker worktree). Check: each record at 0.7.0, each
   `statusLine` at `.../cache/stratum/stratum/0.7.0/statusline/st-statusline.sh`, no file in
   `apps/` subfolders created, one commit per changed branch at most, the restart line at the end.
6. Run `/stratum:st-update /home/hyuse/Desktop/VeentApps/v2-veent` a third time: "all items are
   current" (SC-001).
7. Restart a session in `v2-veent-crm` (was 0.1.22) and start an autonomous build: the statusline
   shows `autonomous` (SC-004).
8. On the laptop, repeat steps 1 to 6 there (cross-machine).
