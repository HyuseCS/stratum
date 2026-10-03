#!/usr/bin/env bash
input=$(cat)
plugin="$(cd "$(dirname "$0")/.." && pwd)"

level=$(cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.ponytail-active" 2>/dev/null)
dir=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("workspace",{}).get("current_dir",""))' 2>/dev/null)
mode=$(cat "$dir/.stratum/commit-mode" 2>/dev/null | tr -d '[:space:]')
case "$mode" in auto|ask|deny) ;; *) mode=ask ;; esac
markers="[PONYTAIL ${level:-off}] [SR-OPUS-5] commit:${mode}"

if command -v bunx >/dev/null 2>&1; then
  line=$(printf '%s' "$input" | bunx @owloops/claude-powerline@1.30.3 --style=powerline --theme=rose-pine --config="$plugin/statusline/powerline.json" 2>/dev/null)
  printf '%s %s\n' "$line" "$markers"
else
  printf '%s\n' "$markers"
fi
