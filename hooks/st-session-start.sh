#!/usr/bin/env bash
project="${CLAUDE_PROJECT_DIR:-$(pwd)}"
sr="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/sr-opus-5.md"

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
  echo "Stratum rule: begin every reply with the label [Orchestrator]. A Stratum hook line on a prompt can name a different label for that reply; use that one instead. Set each Agent call's description to only the task, like \"US1 review\" or \"T004 test\". The panel already shows the agent's name and the reply label shows the lane. When you relay a subagent's report, keep its [tag]."
fi
exit 0
