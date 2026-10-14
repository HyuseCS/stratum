#!/usr/bin/env bash
[ $# -ge 2 ] || { echo "usage: st-verify.sh '<test command>' <file>..."; exit 2; }
cmd=$1; shift
out=$(bash -c "$cmd" 2>&1); rc=$?
if [ $rc -ne 0 ]; then
  printf '%s\n' "$out" | tail -n 20
  echo "FAIL test exited $rc: $cmd"
  exit 1
fi
hits=$(for f in "$@"; do
  case $f in *.md) continue ;; esac
  if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then git diff -U0 -- "$f"; elif [ -e "$f" ]; then git diff --no-index -U0 /dev/null "$f"; fi
done | awk '/^\+\+\+ /{f=substr($0,7); next} /^\+[ \t]*(\/\/|#|\/\*|\*)/ && !/ponytail:/ && !/#!/ {print f ": " $0}')
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "FAIL added comment lines"
  exit 1
fi
echo "ok test green, no added comments in $# files: $cmd"
