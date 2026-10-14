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
  echo "Stratum rule: begin every reply with the label [Orchestrator]. A Stratum hook line on a prompt can name a different label for that reply; use that one instead."
fi
exit 0
