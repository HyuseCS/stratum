#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
fail=0
script="$root/scripts/st-figcraft.sh"
link=https://github.com/storytold/figcraft/releases
git_before=$(git -C "$root" status --porcelain)
started() { for f in "$tmp"/*/run/st-figcraft-*[0-9] "$tmp/pids"; do [ -f "$f" ] && while read -r p _; do echo "$p"; done < "$f"; done; }
alive() { started | while read -r p; do kill -0 "$p" 2>/dev/null && echo "$p"; done; }
stop_all() { started | while read -r p; do kill "$p" 2>/dev/null && timeout 5 tail --pid="$p" -f /dev/null; done; }
trap 'stop_all; rm -rf "$tmp"' EXIT
check() { if eval "$2" 2>/dev/null; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
want() {
  if [ "$rc" = "$2" ] && [ "$out" = "$3" ]; then echo "ok   $1"; return; fi
  echo "FAIL $1: exit $rc, want exit $2"
  printf '     got:  %s\n     want: %s\n' "$out" "$3"
  fail=1
}
mk() {
  c="$tmp/$1"; bin="$c/bin"; sys="$c/sys"; proj="$c/proj"
  mkdir -p "$bin" "$sys" "$c/run" "$proj"
  for t in python3 mkdir nohup tail sleep; do ln -s "$(command -v "$t")" "$sys/$t"; done
  proj=$(cd "$proj" && pwd -P)
  port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
}
fake() { cat > "$bin/$1"; chmod +x "$bin/$1"; }
app_ok() {
  fake figcraft <<SH
#!/bin/sh
echo "\$*" >> "$c/args"
exec python3 -I "$tmp/answer.py" $port
SH
}
cli_fake() {
  fake figcraft-cli <<'SH'
#!/bin/sh
echo "cli: $*"
SH
}
st() { PATH="$c/bin:$c/sys" XDG_RUNTIME_DIR="$c/run" ST_FIGCRAFT_PORT="$port" "$BASH" "$script" "$@" 2>&1; }

cat > "$tmp/answer.py" <<'PY'
import socket, sys
s = socket.create_server(("127.0.0.1", int(sys.argv[1])))
reply = (sys.argv[2] if len(sys.argv) > 2 else '{"id": 1, "ok": true, "result": []}').encode() + b"\n"
print("ready", flush=True)
while True:
    c, _ = s.accept()
    with c:
        for _ in c.makefile("rb"):
            c.sendall(reply)
PY

mk F1; app_ok
out=$(st start "$proj"); rc=$?
want "F1 free port" 0 "FigCraft: started on port $port"
check "F1 args" '[ "$(cat "$c/args")" = "--control $port --automation-read-root $proj --automation-write-root $proj/design" ]'
check "F1 design dir" '[ -d "$proj/design" ]'
check "F1 record: live pid and project" 'read -r p rp < "$c/run/st-figcraft-$port" && [ "$rp" = "$proj" ] && kill -0 "$p" 2>/dev/null'

out=$(st start "$proj"); rc=$?
want "F2 same project" 0 "FigCraft: running on port $port"
check "F2 one launch" '[ "$(grep -c . "$c/args")" = 1 ]'

proj2=$(mkdir -p "$c/proj2" && cd "$c/proj2" && pwd -P)
out=$(st start "$proj2"); rc=$?
want "F3 another project" 1 "FigCraft on port $port was not started for this project. Close it, then say go."

mk F4; app_ok
coproc RESP { exec python3 -I "$tmp/answer.py" "$port" hello; }
read -r _ <&"${RESP[0]}"
echo "$RESP_PID" >> "$tmp/pids"
out=$(st start "$proj"); rc=$?
want "F4 other program" 1 "Port $port is in use by another program. Free it, then say go."
check "F4 no launch" '[ ! -e "$c/args" ]'

mk F5; fake figcraft <<'SH'
#!/bin/sh
echo "error: unknown option --automation-read-root" >&2
exit 1
SH
out=$(st start "$proj"); rc=$?
want "F5 app exits at once" 1 "FigCraft did not start: error: unknown option --automation-read-root"

mk F6
out=$(st start "$proj"); rc=$?
want "F6 no figcraft" 1 "missing: FigCraft. Install: $link"

mk F7; cli_fake
out=$(st cli info x); rc=$?
want "F7 cli on PATH" 0 "cli: info x"

mk F8; fake figcraft <<'SH'
#!/bin/sh
case "$*" in "cli --version") echo "figcraft-cli 0.13.1" ;; *) echo "app: $*" ;; esac
SH
out=$(st cli info x); rc=$?
want "F8 cli through AppImage" 0 "app: cli info x"

mk F9; cli_fake
out=$(st mcp); rc=$?
want "F9 mcp" 0 "cli: mcp --attach $port"

stop_all
check "F10 no writes, no live pids" '[ "$git_before" = "$(git -C "$root" status --porcelain)" ] && [ -z "$(alive)" ]'
exit $fail
