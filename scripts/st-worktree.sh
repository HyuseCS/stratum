#!/usr/bin/env bash
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: st-worktree.sh <branch> <name>" >&2; exit 2; }
branch="$1"
main="$(git rev-parse --show-toplevel)"
wt="$(dirname "$main")/$(basename "$main")-$2"

cd "$main"
if [ ! -d "$wt" ]; then
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$wt" "$branch"
  else
    git worktree add -b "$branch" "$wt"
  fi
fi

link() { [ -e "$main/$1" ] && [ ! -e "$wt/$1" ] && mkdir -p "$(dirname "$wt/$1")" && ln -s "$main/$1" "$wt/$1" && echo "linked $1" || true; }
link .claude/settings.local.json

mem="$HOME/.claude/projects/$(printf %s "$main" | tr -c 'A-Za-z0-9' '-')/memory"
wtmem="$HOME/.claude/projects/$(printf %s "$wt" | tr -c 'A-Za-z0-9' '-')/memory"
if [ ! -e "$wtmem" ]; then
  mkdir -p "$mem" "$(dirname "$wtmem")" && ln -s "$mem" "$wtmem" && echo "linked Claude memory"
fi

echo "$wt"
