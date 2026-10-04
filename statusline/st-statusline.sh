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
    data = json.loads(raw)
except ValueError:
    data = {}
cwd = data.get("workspace", {}).get("current_dir", "")
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
shape = cfg.pop("shape", "arrow")
reserve = cfg.pop("reserve", 8)
logo = cfg.pop("logo", "\U000f0328")
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
segs["stratum"] = {"bg": rgb(label["bg"]), "fg": rgb(label["fg"]), "text": f"{logo} Stratum".strip(), "short": logo or "Stratum"}
if folder:
    home = os.path.expanduser("~")
    path = "~" + cwd[len(home):] if cwd == home or cwd.startswith(home + "/") else cwd
    segs["dir"] = {"bg": rgb(palette["directory"]["bg"]), "fg": rgb(palette["directory"]["fg"]), "text": path, "short": folder}
segs["ponytail"] = {"bg": rgb(pt["bg"]), "fg": rgb(pt["fg"]), "text": "Ponytail" if level == "full" else f"Ponytail {level}",
                    "short": "PT" if level == "full" else f"PT {level}"}
effort = (data.get("effort") or {}).get("level")
enabled = (data.get("thinking") or {}).get("enabled")
think = "off" if enabled is False else effort or ("on" if enabled else None)
if think and "model" in segs:
    segs["model"]["text"] = segs["model"]["short"] = f"{segs['model']['text']} {think}"
segs["commit"] = {"bg": rgb(commit_bg), "fg": rgb(commit_fg), "text": f"commit: {mode}", "short": mode}


SEPS = {"arrow": ("\ue0b0", "\ue0b2"), "slanted": ("\ue0bc", "\ue0ba")}
CAPS = {"rounded": ("\ue0b6", "\ue0b4"), "blocks": ("", "")}
if shape not in SEPS and shape not in CAPS and shape != "flat":
    shape = "arrow"


def fg(c):
    return f"\x1b[38;2;{c}m"


def bg(c):
    return f"\x1b[48;2;{c}m"


def render(row, right):
    if not row:
        return ""
    if shape == "flat":
        return " \x1b[2m│\x1b[22m ".join(f"{fg(segs[k]['fg'])}{segs[k]['text']}\x1b[0m" for k in row)
    if shape in CAPS:
        lcap, rcap = CAPS[shape]
        return " ".join(f"{fg(segs[k]['bg'])}{lcap}{bg(segs[k]['bg'])}{fg(segs[k]['fg'])} {segs[k]['text']} \x1b[0m"
                        f"{fg(segs[k]['bg'])}{rcap}\x1b[0m" for k in row)
    sep = SEPS[shape][1 if right else 0]
    out, prev = "", None
    if right:
        out += f"{fg(segs[row[0]]['bg'])}{sep}"
    for k in row:
        s = segs[k]
        if prev:
            out += f"{bg(prev)}{fg(s['bg'])}{sep}" if right else f"{bg(s['bg'])}{fg(prev)}{sep}"
        out += f"{bg(s['bg'])}{fg(s['fg'])} {s['text']} "
        prev = s["bg"]
    return out + "\x1b[0m" + ("" if right else f"{fg(prev)}{sep}\x1b[0m")


def cells(s):
    s = re.sub(r"\x1b\[[\d;]*m", "", s)
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


try:
    limit = int(os.environ["ST_WIDTH"]) - int(reserve)
except ValueError:
    limit = 0
steps = [("dir", "short"), ("commit", "short"), ("ponytail", "short"), ("time", "drop"), ("model", "drop"),
         ("stratum", "short"), ("stratum", "drop"), ("dir", "drop"), ("ponytail", "drop")]
for lkinds, rkinds in ((["stratum", "dir", "time"], ["git"]), (["model", "ponytail"], ["commit"])):
    left = [k for k in lkinds if k in segs]
    right = [k for k in rkinds if k in segs]
    for kind, action in steps:
        if limit <= 0 or cells(render(left, False)) + 1 + cells(render(right, True)) <= limit:
            break
        if kind in segs:
            segs[kind]["text"] = segs[kind]["short"]
            if action == "drop":
                left = [k for k in left if k != kind]
    lr, rr = render(left, False), render(right, True)
    if not lr and not rr:
        continue
    gap = limit - cells(lr) - cells(rr) if limit > 0 else 2
    print(lr + " " * max(gap, 1) + rr)
PY
