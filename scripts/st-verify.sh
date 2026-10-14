#!/usr/bin/env bash
[ $# -eq 1 ] || { echo "usage: st-verify.sh '<test command>'"; exit 2; }
out=$(bash -c "$1" 2>&1); rc=$?
if [ $rc -ne 0 ]; then
  printf '%s\n' "$out" | tail -n 20
  echo "FAIL test exited $rc: $1"
  exit 1
fi
hits=$(git diff -U0 -- . ':!*.md' | grep -E '^\+\s*(//|#|/\*|\*)' | grep -v -e ponytail: -e '^+++' -e '#!')
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "FAIL added comment lines"
  exit 1
fi
echo "ok test green, no added comments: $1"
