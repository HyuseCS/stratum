#!/usr/bin/env bash
input=$(cat)
plugin="$(cd "$(dirname "$0")/.." && pwd)"

level=$(cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.ponytail-active" 2>/dev/null)
line=""
if command -v bunx >/dev/null 2>&1; then
  line=$(printf '%s' "$input" | bunx @owloops/claude-powerline@1.30.3 --style=powerline --theme=rose-pine --config="$plugin/statusline/powerline.json" 2>/dev/null)
fi
width=${COLUMNS:-}
pid=$PPID
while [ -z "$width" ] && [ "${pid:-1}" -gt 1 ]; do
  tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  case "$tty" in ''|'?') ;; *) width=$(stty size <"/dev/$tty" 2>/dev/null | cut -d' ' -f2); break ;; esac
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done

ST_INPUT="$input" ST_LINE="$line" ST_LEVEL="${level:-off}" ST_WIDTH="$width" exec python3 - <<'PY'
import json, os, re, unicodedata

ARROW = ""
try:
    cwd = json.loads(os.environ["ST_INPUT"]).get("workspace", {}).get("current_dir", "")
except ValueError:
    cwd = ""
try:
    mode = open(f"{cwd}/.stratum/commit-mode").read().strip()
except OSError:
    mode = ""
if mode not in ("auto", "ask", "deny"):
    mode = "ask"

segs = []
for bg, fg, text in re.findall(r"\x1b\[48;2;([\d;]+)m\x1b\[38;2;([\d;]+)m([^\x1b]+)", os.environ["ST_LINE"]):
    text = text.strip()
    if not text or text == ARROW:
        continue
    kind = {"✱": "model", "⎇": "git", "⧖": "time"}.get(text[0], "dir")
    short = text.rstrip("/").rsplit("/", 1)[-1] if kind == "dir" else text
    segs.append({"kind": kind, "bg": bg, "fg": fg, "text": text, "short": short})

level = os.environ["ST_LEVEL"]
mode_fg = {"auto": "156;207;216", "ask": "246;193;119", "deny": "235;111;146"}[mode]
segs += [
    {"kind": "ponytail", "bg": "42;39;63", "fg": "235;111;146", "text": f"ponytail {level}", "short": f"pt {level}"},
    {"kind": "sr", "bg": "38;35;58", "fg": "196;167;231", "text": "SR-OPUS-5", "short": "SR5"},
    {"kind": "commit", "bg": "31;29;46", "fg": mode_fg, "text": f"commit {mode}", "short": mode},
]


def cells(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def fits(limit):
    return sum(cells(s["text"]) + 3 for s in segs) <= limit


try:
    limit = int(os.environ["ST_WIDTH"]) - 1
except ValueError:
    limit = 0
steps = [("dir", "short"), ("sr", "short"), ("commit", "short"), ("ponytail", "short"),
         ("time", "drop"), ("sr", "drop"), ("model", "drop"), ("ponytail", "drop"), ("git", "drop"), ("dir", "drop")]
for kind, action in steps:
    if limit <= 0 or fits(limit):
        break
    for s in segs:
        if s["kind"] == kind:
            s["text"] = s["short"]
    if action == "drop":
        segs = [s for s in segs if s["kind"] != kind]

out, prev = "", None
for s in segs:
    if prev:
        out += f"\x1b[48;2;{s['bg']}m\x1b[38;2;{prev}m{ARROW}"
    out += f"\x1b[48;2;{s['bg']}m\x1b[38;2;{s['fg']}m {s['text']} "
    prev = s["bg"]
print(f"{out}\x1b[0m\x1b[38;2;{prev}m{ARROW}\x1b[0m")
PY
