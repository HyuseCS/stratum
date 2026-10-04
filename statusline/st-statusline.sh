#!/usr/bin/env bash
width=${COLUMNS:-}
pid=$PPID
while [ -z "$width" ] && [ "${pid:-1}" -gt 1 ]; do
  tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  case "$tty" in ''|'?') ;; *) width=$(stty size <"/dev/$tty" 2>/dev/null | cut -d' ' -f2); break ;; esac
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done

ST_INPUT="$(cat)" ST_PLUGIN="$(cd "$(dirname "$0")/.." && pwd)" ST_WIDTH="$width" exec python3 - <<'PY'
import json, os, re, shutil, subprocess, tempfile, unicodedata

ARROW = ""
plugin = os.environ["ST_PLUGIN"]
raw = os.environ["ST_INPUT"]
try:
    cwd = json.loads(raw).get("workspace", {}).get("current_dir", "")
except ValueError:
    cwd = ""
try:
    mode = open(f"{cwd}/.stratum/commit-mode").read().strip()
except OSError:
    mode = ""
if mode not in ("auto", "ask", "deny"):
    mode = "ask"
try:
    level = open(os.path.join(os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude"), ".ponytail-active")).read().strip()
except OSError:
    level = ""
level = level or "off"



def merge(base, over):
    for k, v in over.items():
        base[k] = merge(base[k], v) if isinstance(v, dict) and isinstance(base.get(k), dict) else v
    return base


cfg = json.load(open(f"{plugin}/statusline/powerline.json"))
if os.path.isfile(f"{cwd}/.stratum/powerline.json"):
    merge(cfg, json.load(open(f"{cwd}/.stratum/powerline.json")))
themes = json.load(open(f"{plugin}/statusline/themes.json"))
theme = cfg.get("theme", "rose-pine")
custom = cfg.get("colors", {}).get("custom", {})
if theme == "custom":
    palette = {**themes["rose-pine"], **custom}
    cfg.setdefault("colors", {})["custom"] = palette
else:
    palette = {**themes.get(theme, themes["rose-pine"]), **custom}
cfg.setdefault("display", {}).update({"autoWrap": False, "colorCompatibility": "truecolor"})
cfg["style"] = "powerline"


def rgb(hex_color):
    h = hex_color.lstrip("#")
    return ";".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


line = ""
if shutil.which("bunx"):
    with tempfile.NamedTemporaryFile("w", suffix=".json") as f:
        json.dump(cfg, f)
        f.flush()
        line = subprocess.run(["bunx", "@owloops/claude-powerline@1.30.3", f"--config={f.name}"],
                              input=raw, capture_output=True, text=True).stdout

segs = {}
for bg, fg, text in re.findall(r"\x1b\[48;2;([\d;]+)m\x1b\[38;2;([\d;]+)m([^\x1b]+)", line):
    text = text.strip()
    kind = {"✱": "model", "⎇": "git", "⧖": "time"}.get(text[:1])
    if kind:
        segs[kind] = {"bg": bg, "fg": fg, "text": text, "short": text}

label = palette.get("stratum", palette["model"])
folder = os.path.basename(cwd.rstrip("/")) or cwd
pt = palette.get("ponytail", palette["block"])
commit = palette.get("commit", {})
commit_bg = commit.get("bg", palette["git"]["bg"])
commit_fg = commit.get(mode, {"auto": palette["git"]["fg"], "ask": palette["contextWarning"]["bg"],
                              "deny": palette["contextCritical"]["bg"]}[mode])
segs["stratum"] = {"bg": rgb(label["bg"]), "fg": rgb(label["fg"]), "text": "Stratum", "short": "Stratum"}
if folder:
    segs["dir"] = {"bg": rgb(palette["directory"]["bg"]), "fg": rgb(palette["directory"]["fg"]), "text": folder, "short": folder}
segs["ponytail"] = {"bg": rgb(pt["bg"]), "fg": rgb(pt["fg"]), "text": f"ponytail {level}", "short": f"pt {level}"}
segs["commit"] = {"bg": rgb(commit_bg), "fg": rgb(commit_fg), "text": f"commit {mode}", "short": mode}


def cells(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


try:
    limit = int(os.environ["ST_WIDTH"]) - 1
except ValueError:
    limit = 0
steps = [("commit", "short"), ("ponytail", "short"), ("time", "drop"), ("stratum", "drop"), ("dir", "drop"),
         ("ponytail", "drop"), ("git", "drop")]
for kinds in (["stratum", "dir", "git", "time"], ["ponytail", "commit"], ["model"]):
    row = [k for k in kinds if k in segs]
    for kind, action in steps:
        if limit <= 0 or sum(cells(segs[k]["text"]) + 3 for k in row) <= limit:
            break
        if kind in row:
            segs[kind]["text"] = segs[kind]["short"]
            if action == "drop":
                row.remove(kind)
    if not row:
        continue
    out, prev = "", None
    for k in row:
        s = segs[k]
        if prev:
            out += f"\x1b[48;2;{s['bg']}m\x1b[38;2;{prev}m{ARROW}"
        out += f"\x1b[48;2;{s['bg']}m\x1b[38;2;{s['fg']}m {s['text']} "
        prev = s["bg"]
    print(f"{out}\x1b[0m\x1b[38;2;{prev}m{ARROW}\x1b[0m")
PY
