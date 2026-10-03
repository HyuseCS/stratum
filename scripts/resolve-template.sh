#!/usr/bin/env bash
set -e
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

name="${1:?Usage: resolve-template.sh <name>}"
[[ "$name" =~ ^[a-z0-9-]+$ ]] || { echo "ERROR: Invalid template name '$name'" >&2; exit 1; }

for candidate in "$(project_root)/.stratum/templates/$name.md" "$PLUGIN_ROOT/templates/$name.md"; do
    [[ -f "$candidate" ]] && { echo "$candidate"; exit 0; }
done
echo "ERROR: Template '$name' not found in .stratum/templates/ or $PLUGIN_ROOT/templates/" >&2
exit 1
