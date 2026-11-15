#!/usr/bin/env bash

PLUGIN_ROOT="$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

project_root() {
    local dir
    dir="$(pwd)"
    while [[ "$dir" != "/" ]]; do
        [[ -d "$dir/.stratum" ]] && { echo "$dir"; return; }
        dir="$(dirname "$dir")"
    done
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# ponytail: a path with a newline breaks the snapshot lines, use -z through to the compare if one shows up
snap() {
  local - c e f l m p x=(-- . ':(exclude).stratum/state.json' ':(exclude,glob)**/.syncthing.*.tmp' ':(exclude,glob)**/~syncthing~*.tmp')
  set -o pipefail
  c=$(git rev-parse --show-cdup 2>/dev/null)
  echo "HEAD $(git rev-parse -q --verify HEAD 2>/dev/null)"
  git --no-optional-locks diff --cached --raw --no-abbrev --no-renames -z "${x[@]}" 2>/dev/null |
    while IFS= read -r -d '' m && IFS= read -r -d '' e; do
      printf '%s\tindex\t%s\n' "$e" "$m"
    done || return 1
  git --no-optional-locks status --porcelain=v1 -z --untracked-files=all --no-renames "${x[@]}" 2>/dev/null |
    while IFS= read -r -d '' e; do
      f=$c${e:3}
      printf '%s\t%s\t%s %s\n' "${e:3}" "${e:0:2}" "$(stat -c %f -- "$f" 2>/dev/null)" "$(if [ -L "$f" ]; then readlink -- "$f" | sha256sum | cut -d' ' -f1; elif [ -f "$f" ]; then sha256sum < "$f" | cut -d' ' -f1; fi)"
      [ ! -L "${f%/}" ] && [ -e "$f/.git" ] || continue
      p=${e:3}
      (cd -- "$f" && snap) | while IFS= read -r l; do printf '%s/%s\n' "${p%/}" "${l/#HEAD /HEAD$'\t'}"; done || exit 1
    done
}

snapdiff() {
  comm -3 <(sort <<<"$1") <(sort <<<"$2") | sed 's/^\t//; s/^HEAD .*/HEAD/; s/\t.*//' | LC_ALL=C sort -u | awk 'NR > 1 { printf ", " } { printf "%s", $0 }'
}
