#!/usr/bin/env bash
input=$(cat)
plugin="$(cd "$(dirname "$0")/.." && pwd)"

level=$(cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.ponytail-active" 2>/dev/null)
dir=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("workspace",{}).get("current_dir",""))' 2>/dev/null)
mode=$(cat "$dir/.stratum/commit-mode" 2>/dev/null | tr -d '[:space:]')
case "$mode" in auto|ask|deny) ;; *) mode=ask ;; esac
case "$mode" in auto) mode_fg="156;207;216" ;; ask) mode_fg="246;193;119" ;; deny) mode_fg="235;111;146" ;; esac

line=""
prev=""
if command -v bunx >/dev/null 2>&1; then
  line=$(printf '%s' "$input" | bunx @owloops/claude-powerline@1.30.3 --style=powerline --theme=rose-pine --config="$plugin/statusline/powerline.json" 2>/dev/null)
  prev=$(grep -o $'\e\\[48;2;[0-9;]*m' <<<"$line" | tail -1 | sed $'s/\e\\[48;2;\\(.*\\)m/\\1/')
  [ -n "$prev" ] && line="${line%$'\e[0m\e[38;2;'"$prev"$'m\ue0b0\e[0m'}"
fi

seg() {
  if [ -n "$prev" ]; then
    printf '\e[48;2;%sm\e[38;2;%sm' "$1" "$prev"
  fi
  printf '\e[48;2;%sm\e[38;2;%sm %s ' "$1" "$2" "$3"
  prev=$1
}

printf '%s' "$line"
seg "42;39;63" "235;111;146" "ponytail ${level:-off}"
seg "38;35;58" "196;167;231" "SR-OPUS-5"
seg "31;29;46" "$mode_fg" "commit ${mode}"
printf '\e[0m\e[38;2;%sm\e[0m\n' "$prev"
