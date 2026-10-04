---
name: st-init
description: Set up Stratum in a project: .stratum data files, specs folder, AGENTS.md and CLAUDE.md pointers, the constitution (grilled), statusline, graphify hook, and a tool check.
---

# /stratum:st-init

Plugin root is two levels up from this skill's base directory. Run in the project root. Never
overwrite an existing file; report it and move on.

1. **Data files.** Create `.stratum/` and `specs/`. Write `.stratum/state.json` as
   `{"feature_directory": null, "phase": null, "lane": null}`. Write `.stratum/commit-mode` as
   `ask`.
2. **Git ignore.** Ensure `.gitignore` has these lines: `.stratum/commit-mode`,
   `.stratum/handoff.md`, `graphify-out/`.
3. **Constitution.** If `.stratum/constitution.md` is missing, run `/stratum:st-constitution`: it
   starts from the plugin's constitution template and grills the user for the rules, one question
   at a time.
4. **Pointers.** If `AGENTS.md` is missing, create it:
   ```markdown
   # <project name>

   Before any work, read and follow `.stratum/constitution.md`. It holds the project rules and
   overrides tool defaults. Specs live in `specs/`.
   ```
   If `CLAUDE.md` is missing, create it with two lines: `@AGENTS.md` and
   `@.stratum/constitution.md`. If either exists, show the user the lines to add and ask.
5. **Statusline.** The statusline needs this machine's plugin path, so it goes in
   `.claude/settings.local.json` (not committed). Merge in
   `"statusLine": {"type": "command", "command": "bash <plugin root>/statusline/st-statusline.sh"}`
   with the absolute plugin root. Keep every other key.
6. **Duplicate plugins.** Stratum ships its own ponytail and Token Weather hooks. For each plugin
   in `~/.claude/settings.json` `enabledPlugins` that is `ponytail@ponytail` or has `token-weather`
   in its name and is `true`, merge `"<key>": false` into `enabledPlugins` in the project's
   `.claude/settings.json`. Keep every other key. Never change global files.
7. **Graphify.** If `graphify --version` is older than 0.9.74 or missing, ask the user, then run
   `uv tool install --force graphifyy` (or `pip install -U graphifyy` if `uv` is missing) and check
   the version again. When it is 0.9.74 or later, run `graphify hook install` and confirm with
   `graphify hook status`. If the user says no, list it under what they still need to do.
8. **Tool check.** Run the checks from `/stratum:st-status` steps 4 and 5 and report missing tools
   and duplicate installs.
9. **Report** in one block: files created, files skipped because they existed, what the user
   still needs to do. Commit only the created or changed project files (`.stratum/state.json`,
   `.stratum/constitution.md`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`),
   through the commit guard.
