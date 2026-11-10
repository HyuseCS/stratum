#!/usr/bin/env bash
# ponytail: the port override is a test seam, the plugin.json attach port stays 7979
port=${ST_FIGCRAFT_PORT:-7979}
link=https://github.com/storytold/figcraft/releases
rec=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/st-figcraft-$port

resolve_cli() {
  if command -v figcraft-cli >/dev/null 2>&1; then cli=(figcraft-cli)
  elif [[ $(figcraft cli --version 2>/dev/null) == figcraft-cli* ]]; then cli=(figcraft cli)
  else cli=()
  fi
}

run_cli() {
  resolve_cli
  [ ${#cli[@]} -gt 0 ] || { echo "missing: figcraft-cli. Install: $link" >&2; exit 127; }
  exec "${cli[@]}" "$@"
}

probe() {
  python3 -I -c '
import json, socket, sys
try:
    s = socket.create_connection(("127.0.0.1", int(sys.argv[1])), 1)
except ConnectionRefusedError:
    print("free"); sys.exit()
except OSError:
    print("other"); sys.exit()
try:
    s.settimeout(2)
    s.sendall(b"{\"id\":1,\"method\":\"window.list\"}\n")
    r = json.loads(s.makefile("rb").readline(65536))
    print("figcraft" if isinstance(r, dict) and r.get("id") == 1 and "ok" in r else "other")
except Exception:
    print("other")
' "$port"
}

case ${1:-} in
  check)
    n=0
    command -v figcraft >/dev/null 2>&1 || { echo "missing: FigCraft. Install: $link"; n=1; }
    resolve_cli
    if [ ${#cli[@]} = 0 ]; then
      echo "missing: figcraft-cli. Install: $link"; n=1
    else
      v=unknown
      if [[ $("${cli[@]}" --version 2>/dev/null) =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        v=${BASH_REMATCH[0]}
        a=$((10#${BASH_REMATCH[1]})) b=$((10#${BASH_REMATCH[2]}))
        (( a > 0 || b >= 16 )) && v=
      fi
      [ -n "$v" ] && { echo "too old: figcraft-cli $v, needs 0.16.0 or later. Install: $link"; n=1; }
    fi
    exit "$n" ;;
  cli) shift; run_cli "$@" ;;
  mcp) run_cli mcp --attach "$port" ;;
  start)
    [ -n "${2:-}" ] || { echo "usage: st-figcraft.sh check|start <project>|cli <args>|mcp" >&2; exit 2; }
    command -v figcraft >/dev/null 2>&1 || { echo "missing: FigCraft. Install: $link"; exit 1; }
    proj=$(cd "$2" && pwd -P) || exit 1
    mkdir -p "$proj/design" || exit 1
    case $(probe) in
      figcraft)
        # ponytail: a dead FigCraft's pid reused by another process passes the record check, add a start-time check if that shows up
        read -r pid rp < "$rec" 2>/dev/null
        if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null && [ "$rp" = "$proj" ]; then
          echo "FigCraft: running on port $port"; exit 0
        fi
        echo "FigCraft on port $port was not started for this project. Close it, then say go."; exit 1 ;;
      free)
        pre=()
        command -v setsid >/dev/null 2>&1 && pre=(setsid)
        "${pre[@]}" nohup figcraft --control "$port" --automation-read-root "$proj" --automation-write-root "$proj/design" >/dev/null 2>"$rec.log" &
        pid=$!
        echo "$pid $proj" > "$rec"
        SECONDS=0
        while (( SECONDS < 20 )); do
          r=$(probe)
          kill -0 "$pid" 2>/dev/null || { rm -f "$rec"; echo "FigCraft did not start: $(tail -n 1 "$rec.log")"; exit 1; }
          [ "$r" = figcraft ] && { echo "FigCraft: started on port $port"; exit 0; }
          sleep 0.5
        done
        echo "FigCraft did not answer on port $port in 20 s."; exit 1 ;;
      *) echo "Port $port is in use by another program. Free it, then say go."; exit 1 ;;
    esac ;;
  *) echo "usage: st-figcraft.sh check|start <project>|cli <args>|mcp" >&2; exit 2 ;;
esac
