---
name: st-status
description: Show where Stratum work stands: feature, phase, lane, tasks done, git guard options, next gate, missing tools, duplicate installs, days since the last upstream sync, and model overrides.
---

# /stratum:st-status

Plugin root is two levels up from this skill's base directory. Gather, then report in one short
block. Change nothing.

1. **Work:** from `<project>/.stratum/state.json`: feature dir, phase, lane. Tasks done and total
   from `<feature dir>/tasks.md` (lines `- [x]`/`- [X]` against all `- [ ]`/`- [x]` task lines).
2. **Next gate:** Define → "you agree the spec"; Plan → "make GitHub issues?"; Inspect → "you OK the
   build"; Build → "none unless blocked"; Close → "push on your word"; Fast lane → "you OK the
   change plan".
3. **Git guard:** for each of `commit`, `worktree_remove`, `worktree_prune`, `branch_delete`,
   `reset_hard`, `clean`, `discard`, `force_push`: the value in `<project>/.stratum/git-guard.json`,
   else the option under the `stratum@...` key of `pluginConfigs` in `~/.claude/settings.json`,
   else `ask`. Show each mode and where it comes from (repo file, global option, default).
   Change the repo file by hand, the global ones in `/config` or `/plugin config`.
4. **Tools:** check each and name any missing or too old: `git`, `python3`, `node`, `bunx`
   (statusline), `graphify --version` (needs 0.9.74 or later for Dart), and whether the graphify
   post-commit hook is installed (`graphify hook status`). For graphify too old or missing, give
   `uv tool install --force graphifyy`; for no hook, give `graphify hook install`.
5. **Duplicates:** list Stratum skills that also exist outside the plugin and could run twice or
   clash: `~/.claude/skills/{grill-me,grilling,impeccable,graphify,ui-ux-pro-max}`, the ponytail
   plugin in `~/.claude/settings.json` `enabledPlugins`, a token-weather plugin. Name them and say
   which to turn off for this project. For each global `ponytail@ponytail` or token-weather plugin
   that is on and not set to `false` in the project's `.claude/settings.json` `enabledPlugins`,
   give the line to add: `"<key>": false`. Never change global files.
6. **Upstream sync:** days since `synced` in `<plugin root>/vendor.lock`. Over 30 days: say so.
7. **Model overrides:** from `<project>/.stratum/models.json`, list each agent in the file with its
   model and effort. For a key the entry does not set, show the default: the model from the
   `model:` line in `<plugin root>/agents/<agent>.md`, effort `default`. Say the values come from
   `.stratum/models.json` and change with `/stratum:st-model` or by editing the file. No file or no
   entries: say every agent uses the plugin defaults. A bad file: say so and quote the problem.
   To find the problem, run from the project root `echo '{"tool_input":{"subagent_type":"stratum:st-inspect"}}' | python3 <plugin root>/hooks/st-models.py`
   (read-only) and quote the reason it prints. Stratum agents will not start until it is fixed.
