#!/usr/bin/env bash
set -u
if [ $# -lt 3 ] || [ $(( $# % 2 )) = 0 ]; then
  echo "usage: st-state.sh <state file> <key> <value> [<key> <value>]..." >&2; exit 1
fi
exec python3 - "$@" <<'PY'
import json, os, sys, tempfile
path = sys.argv[1]
try:
    with open(path, "rb") as f:
        state = json.load(f)
    if not isinstance(state, dict):
        raise ValueError("not a JSON object")
except Exception as e:
    sys.exit(f"st-state: {path}: {e}")
pairs = sys.argv[2:]
state.update(zip(pairs[::2], pairs[1::2]))
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(path)), prefix=".state-")
with os.fdopen(fd, "w") as f:
    f.write(json.dumps(state, indent=2) + "\n")
os.replace(tmp, path)
PY
