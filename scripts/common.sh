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
