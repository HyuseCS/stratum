#!/usr/bin/env bash
set -u
usage() { echo "usage: st-lock.sh [--name <name>] [--timeout <seconds>] -- <command> [args...]" >&2; exit 2; }
name=test timeout=600 sep=0
while [ $# -gt 0 ] && [ "$sep" = 0 ]; do
  case $1 in
    --name) [ $# -ge 2 ] || usage; name=$2; shift 2 ;;
    --timeout) [ $# -ge 2 ] || usage; timeout=$2; shift 2 ;;
    --) sep=1; shift ;;
    *) usage ;;
  esac
done
[ "$sep" = 1 ] && [ $# -gt 0 ] || usage
[[ $timeout =~ ^[0-9]+$ ]] || usage
[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,40}$ ]] || usage
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "lock: not in a git repo" >&2; exit 2; }
lock="$common/stratum-$name.lock"
waited=0 told=0
until mkdir "$lock" 2>/dev/null; do
  pid=$(cat "$lock/pid" 2>/dev/null)
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
    # ponytail: two waiters that see a dead owner in the same second can both remove the folder and both run, use a real lock tool if that bites
    rm -rf "$lock"
    continue
  fi
  [ "$told" = 1 ] || [ -z "$pid" ] || { echo "lock: waiting for $name (pid $pid)" >&2; told=1; }
  if [ "$waited" -ge "$timeout" ]; then
    echo "lock: waited $waited s for $name; held by pid $pid since $(cat "$lock/since" 2>/dev/null); ran nothing" >&2
    exit 75
  fi
  sleep 1
  waited=$((waited + 1))
done
trap 'rm -rf "$lock"' EXIT
trap 'exit 1' HUP INT TERM
echo $$ > "$lock/pid"
date -u +%Y-%m-%dT%H:%M:%SZ > "$lock/since"
"$@"
