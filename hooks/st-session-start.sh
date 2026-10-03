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
exit 0
