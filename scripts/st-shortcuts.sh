#!/usr/bin/env bash
set -o pipefail
base=${1:-main}
mb=$(git merge-base "$base" HEAD) || exit 1
if [ "$mb" = "$(git rev-parse HEAD)" ]; then echo "No commits after $base."; exit 0; fi
rows=$(git -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/ -U0 "$base...HEAD" -- . ':!*.md' | awk '
/^diff --git /{h=1; next}
h && /^\+\+\+ /{f=substr($0,7); sub(/\t$/,"",f); next}
/^@@ /{h=0; split($3,a,","); n=substr(a[1],2); next}
!h && /^\+/{if (/(#|\/\/|\/[*]) ?ponytail:/) print f ":" n ": " substr($0,2); n++}') || exit 1
if [ -n "$rows" ]; then printf '%s\n' "$rows"; else echo "No new ponytail: markers."; fi
