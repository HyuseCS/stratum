#!/usr/bin/env bash
set -u
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
found=0

if command pgrep -af 'spk00[3]'; then
  found=1
  command pkill -f 'spk00[3]'
  for _ in 1 2 3 4 5; do
    command pgrep -f 'spk00[3]' >/dev/null || break
    sleep 1
  done
  echo "killed marked processes"
  command pkill -9 -f 'spk00[3]' && echo "killed -9 marked processes"
fi

while IFS=$'\t' read -r sid name; do
  [ -n "$sid" ] || continue
  found=1
  id="$sid"
  claude stop "$id" || { id="$name"; claude stop "$id"; }
  claude rm "$id" && echo "removed session $name $sid"
done < <(claude agents --json --all | jq -r '.[] | select((.name // "") | test("spk00[3]")) | [.sessionId, .name] | @tsv')

while read -r path; do
  [ -n "$path" ] || continue
  found=1
  git -C "$root" worktree remove --force "$path" && echo "removed worktree $path"
done < <(git -C "$root" worktree list --porcelain | sed -n 's/^worktree //p' | grep 'spk00[3]')
[ "$found" = 1 ] && git -C "$root" worktree prune

while read -r branch; do
  [ -n "$branch" ] || continue
  found=1
  git -C "$root" branch -D "$branch" && echo "removed branch $branch"
done < <(git -C "$root" branch --list '*spk00[3]*' --format='%(refname:short)')

[ "$found" = 0 ] && echo "nothing to clean"
exit 0
