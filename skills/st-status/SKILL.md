---
name: st-status
description: Show where Stratum work stands: feature, phase, lane, tasks done, commit mode, next gate, missing tools, duplicate installs, and days since the last upstream sync.
---

# /stratum:st-status

Plugin root is two levels up from this skill's base directory. Gather, then report in one short
block. Change nothing.

1. **Work:** from `<project>/.stratum/state.json`: feature dir, phase, lane. Tasks done and total
   from `<feature dir>/tasks.md` (lines `- [x]`/`- [X]` against all `- [ ]`/`- [x]` task lines).
2. **Next gate:** Define → "you agree the spec"; Plan → "make GitHub issues?"; Check → "you OK the
   build"; Build → "none unless blocked"; Close → "push on your word"; Fast lane → "you OK the
   change plan".
3. **Commit mode:** `<project>/.stratum/commit-mode` (missing means `ask`).
4. **Tools:** check each and name any missing or too old: `git`, `python3`, `node`, `bunx`
   (statusline), `graphify --version` (needs 0.9.74 or later for Dart), and whether the graphify
   post-commit hook is installed (`graphify hook status`).
5. **Duplicates:** list Stratum skills that also exist outside the plugin and could run twice or
   clash: `~/.claude/skills/{grill-me,grilling,impeccable,graphify,ui-ux-pro-max}`, the ponytail
   plugin in `~/.claude/settings.json` `enabledPlugins`, a token-weather plugin. Name them and say
   which to turn off for this project. For each global `ponytail@ponytail` or token-weather plugin
   that is on and not set to `false` in the project's `.claude/settings.json` `enabledPlugins`,
   give the line to add: `"<key>": false`. Never change global files.
6. **Upstream sync:** days since `synced` in `<plugin root>/vendor.lock`. Over 30 days: say so.
