#!/usr/bin/env bash
project="${CLAUDE_PROJECT_DIR:-$(pwd)}"
plugin="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
sr="$plugin/sr-opus-5.md"

if [ -f "$sr" ] && ! cmp -s "$sr" "$HOME/.claude/sr-opus-5.md"; then
  cat "$sr"
  echo
fi

if [ -f "$project/.stratum/handoff.md" ]; then
  echo "# Session handoff"
  echo
  cat "$project/.stratum/handoff.md"
fi
if [ -d "$project/.stratum" ]; then
  echo "Stratum rule: begin every reply with the label [Orchestrator]. A Stratum hook line on a prompt can name a different label for that reply; use that one instead. Set each Agent call's description to only the task, like \"US1 review\" or \"T004 test\". The panel already shows the agent's name and the reply label shows the lane. When you relay a subagent's report, keep its [tag]. Background: when the user asks to run st-impeccable (an audit), st-review, st-ponytail-audit or st-ponytail-debt in the background, note git rev-parse HEAD and git status --porcelain --untracked-files=all, then start the agent of the same name (stratum:<name>). Pass it the plugin root ($plugin), the project root and, for st-impeccable, the target. For st-review, pass the feature dir and the range, found as /stratum:st-review steps 1 and 2 say (stop where they stop), and check each finding against the source before you show it. When its report arrives, run both again: any difference is a finding to check, since the main session may also have changed files. Any other skill asked for in the background, except st-handoff: say in one line that it runs only in the main session. When the user ends the session or says they will continue later, run /stratum:st-handoff in the main session before the last reply. Do not use auto-memory in place of it."
fi
exit 0
