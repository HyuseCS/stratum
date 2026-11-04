#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: st-update.sh items | audit [<folder>] | plugin <folder> | fix <folder> <kind> <name> [--force]" >&2; exit 2; }
[ $# -gt 0 ] || usage
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
case $1 in
  items) [ $# = 1 ] || usage ;;
  audit) [ $# -le 2 ] || usage ;;
  plugin) [ $# = 2 ] || usage ;;
  fix) [ $# = 4 ] || { [ $# = 5 ] && [ "$5" = --force ]; } || usage ;;
  *) usage ;;
esac
main=
if [ "$1" = audit ] || [ "$1" = fix ]; then
  folder=${2:-$PWD}
  main=$(git -C "$folder" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p') || true
  [ -d "${main:=$folder}/.stratum" ] || { echo "Not a Stratum project: $folder. Run /stratum:st-init there." >&2; exit 1; }
fi
exec python3 -I - "$cfg" "$main" "$@" <<'PY'
import functools, json, os, re, shlex, shutil, subprocess, sys, tempfile
cfg, main, cmd, *args = sys.argv[1:]
IGNORE = [".stratum/handoff.md", ".stratum/lessons.md", ".stratum/weather.json", ".stratum/powerline.json",
          ".stratum/git-guard.json", ".stratum/models.json", "graphify-out/"]
FILES = [".stratum/state.json", ".stratum/git-guard.json", ".stratum/models.json", ".stratum/powerline.json",
         ".stratum/advisor.json", ".stratum/constitution.md"]
GONE = [".stratum/commit-mode"]
FN = {"ignore": ".gitignore", "pointer": "CLAUDE.md", "statusline": ".claude/settings.local.json",
      "plugins-off": ".claude/settings.json", "figcraft": ".claude/settings.json", "models-key": ".stratum/models.json"}
COMMITTED = (".gitignore", "AGENTS.md", "CLAUDE.md", ".claude/settings.json", ".stratum/state.json", ".stratum/advisor.json")
if cmd == "items":
    for r in [("install", "stratum@stratum", "install record"), ("statusline", "statusLine", FN["statusline"]),
              *[("ignore", n, ".gitignore") for n in IGNORE],
              ("pointer", "@AGENTS.md", "CLAUDE.md"), ("pointer", "@.stratum/constitution.md", "CLAUDE.md"),
              ("plugins-off", "enabledPlugins", ".claude/settings.json"),
              ("plugins-off", "<config>/settings.json", ".claude/settings.json"),
              ("figcraft", "skills/st-design/design-tool.md", ".claude/settings.json"),
              *[("file", n, "main checkout") for n in FILES],
              ("models-key", "agents/", ".stratum/models.json"), ("allow", "permissions.allow", ".claude/settings.json"),
              ("allow", "skills/", ".claude/settings.json"), *[("gone-file", n, "each checkout") for n in GONE]]:
        print("\t".join(r))
    sys.exit()
SAFE = re.compile(r"[A-Za-z0-9_.:@/*()-]+")
STRATUM_SL = re.compile(r"bash +(\S*/statusline/st-statusline\.sh|'[^']*/statusline/st-statusline\.sh')")
SKILL = re.compile(r"Skill\(stratum:(.+?)(?::\*)?\)")
MCP = re.compile(r"mcp__plugin_stratum_(.+?)(?:__(.+))?")


def clean(s):
    return re.sub(r"[\x00-\x1f\x7f]", "?", str(s))


ROWS, TARGET = [], {}


def row(f, kind, name, state, detail=""):
    ROWS.append(tuple(clean(x) for x in (f, kind, name, state, detail)))


def load(p, missing={}):
    try:
        with open(p, "rb") as fh:
            v = json.load(fh)
    except FileNotFoundError:
        return missing
    except (OSError, ValueError, RecursionError):
        return None
    return v if isinstance(v, dict) else None


def read(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None


def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True)


def allowed(x):
    p = x.get("permissions")
    a = p.get("allow") if isinstance(p, dict) else None
    return [s for s in a if isinstance(s, str)] if isinstance(a, list) else []


def records():
    ip = load(f"{cfg}/plugins/installed_plugins.json")
    try:
        return [r for r in ip["plugins"]["stratum@stratum"] if isinstance(r, dict)]
    except (KeyError, TypeError):
        return []


if cmd == "plugin":
    f = os.path.abspath(args[0])
    mine = [r for r in records() if r.get("scope") in ("local", "project")
            and isinstance(r.get("projectPath"), str) and os.path.normpath(r["projectPath"]) == f]
    if not mine:
        sys.exit(f"No local or project Stratum install record with the path {f}.")
    if not os.path.isdir(f):
        sys.exit(f"Folder missing: {f}.")
    me = (mine[0]["projectPath"], mine[0]["scope"])
    again = f"Run: cd {shlex.quote(f)} && claude plugin update stratum@stratum -s {me[1]}"
    if not shutil.which("claude"):
        sys.exit(f"claude not found. {again}")

    def others():
        return sorted(str(((r.get("projectPath"), r.get("scope")), r.get("lastUpdated")))
                      for r in records() if (r.get("projectPath"), r.get("scope")) != me)

    before = others()
    p = subprocess.run(["claude", "plugin", "update", "--json", "-s", me[1], "stratum@stratum"],
                       cwd=f, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    out = {}
    for s in [p.stdout, *reversed(p.stdout.splitlines())]:
        try:
            v = json.loads(s)
        except ValueError:
            continue
        if isinstance(v, dict):
            out = v
            break
    nv = out.get("newVersion")
    now = [r for r in records() if (r.get("projectPath"), r.get("scope")) == me]
    if p.returncode == 0 and out.get("outcome") == "ok" and now and now[0].get("version") == nv and others() == before:
        print(f"ok {nv} {now[0].get('installPath')}")
        sys.exit()
    print(out.get("message") or p.stderr.strip() or "claude plugin update failed", file=sys.stderr)
    sys.exit(again)

mk = load(f"{cfg}/plugins/known_marketplaces.json", None)
mk = mk.get("stratum") if mk else None
loc = mk.get("installLocation") if isinstance(mk, dict) else None
pj = load(f"{loc}/.claude-plugin/plugin.json", None) if isinstance(loc, str) else None
if not pj or not isinstance(pj.get("version"), str):
    sys.exit(f"No Stratum marketplace with a readable plugin.json in {cfg}/plugins/known_marketplaces.json.")
ver = pj["version"]
row("-", "marketplace", "stratum", "current", f"{ver} {loc}")
src = mk.get("source")
if isinstance(src, dict) and src.get("source") == "directory":
    top = git("-C", loc, "rev-parse", "--show-toplevel")
    if top.returncode == 0 and os.path.realpath(top.stdout.strip()) == os.path.realpath(loc):
        branch = git("-C", loc, "branch", "--show-current").stdout.strip() or "detached"
        if branch != "main":
            row("-", "marketplace-branch", branch, "warn", loc)

try:
    agents = {f[:-3] for f in os.listdir(f"{loc}/agents") if f.endswith(".md")}
    os.listdir(f"{loc}/skills")
except OSError as e:
    sys.exit(f"Cannot read {e.filename} in the Stratum marketplace.")
servers = pj.get("mcpServers") if isinstance(pj.get("mcpServers"), dict) else {}
tools = []
for line in (read(f"{loc}/skills/st-design/design-tool.md") or "").splitlines():
    if "**Tools.**" in line:
        tools += re.findall(r"mcp__plugin_stratum_figcraft__\w+", line)

ip = load(f"{cfg}/plugins/installed_plugins.json")
if ip is None:
    sys.exit(f"Not a JSON object: {cfg}/plugins/installed_plugins.json")
recs = records()

cos, det = [], set()
wt = git("-C", main, "worktree", "list", "--porcelain")
for block in wt.stdout.split("\n\n"):
    kv = dict((l.split(" ", 1) + [""])[:2] for l in block.splitlines())
    if kv.get("worktree") and "bare" not in kv and os.path.isdir(kv["worktree"]):
        cos.append((kv["worktree"], kv.get("branch", "").removeprefix("refs/heads/")))
        if "detached" in kv:
            det.add(kv["worktree"])
cos = cos or [(main, "")]
main = cos[0][0]
paths = [c for c, _ in cos]

own, subs, tail, users = {}, {}, [], []
for r in recs:
    p, scope = r.get("projectPath"), r.get("scope")
    if scope in ("user", "managed"):
        users.append(r)
        tail.append((p if isinstance(p, str) else cfg, "listed", f"{scope} scope {r.get('version')}"))
        continue
    if scope not in ("local", "project") or not isinstance(p, str):
        continue
    p = os.path.normpath(p)
    if p in paths:
        own.setdefault(p, []).append(r)
        continue
    under = [c for c in paths if p.startswith(c + "/")]
    if os.path.isdir(p):
        if under:
            subs.setdefault(max(under, key=len), []).append((p, r))
    elif under or (os.path.dirname(p) == os.path.dirname(main)
                   and os.path.basename(p).startswith(os.path.basename(main) + "-")):
        tail.append((p, "gone", f"folder missing, {scope} {r.get('version')}"))


def install(f, r, extra=""):
    v = r.get("version")
    row(f, "install", "stratum@stratum", "current" if v == ver else "outdated",
        f"{r.get('scope')} {v}" + ("" if v == ver else f" -> {ver}") + extra)


def slcmd(target):
    return "bash " + shlex.quote(f"{target['installPath']}/statusline/st-statusline.sh")


def statusline(f, target, only_stratum=False):
    TARGET[f] = target
    s = load(f"{f}/.claude/settings.local.json")
    if s is None:
        if not only_stratum:
            row(f, "statusline", "statusLine", "invalid", ".claude/settings.local.json is not a JSON object")
        return
    sl = s.get("statusLine")
    cmd = sl.get("command") if isinstance(sl, dict) else None
    stratum = isinstance(cmd, str) and STRATUM_SL.fullmatch(cmd)
    if only_stratum and not stratum:
        return
    if not target or not isinstance(target.get("installPath"), str):
        return row(f, "statusline", "statusLine", "listed", "no install")
    want = slcmd(target)
    if "statusLine" not in s:
        row(f, "statusline", "statusLine", "new", want)
    elif cmd == want:
        row(f, "statusline", "statusLine", "current", want)
    else:
        row(f, "statusline", "statusLine", "outdated" if stratum else "ask",
            f"{cmd if isinstance(cmd, str) else 'not a command'} -> {want}")


def dead(s):
    m = SKILL.fullmatch(s)
    if m:
        return "invalid" if "/" in m[1] else not os.path.isfile(f"{loc}/skills/{m[1]}/SKILL.md")
    m = MCP.fullmatch(s)
    if m:
        return m[1] not in servers or (m[1] == "figcraft" and m[2] not in (None, "*") and s not in tools)
    return None


def judged(f, kind, name, is_dead, detail):
    row(f, kind, name, "current" if not is_dead else
        "discontinued" if is_dead is True and SAFE.fullmatch(name) else "invalid", detail)


g = load(f"{cfg}/settings.json") or {}
ep = g.get("enabledPlugins") if isinstance(g.get("enabledPlugins"), dict) else {}
offkeys = [k for k, v in ep.items() if v is True and (k == "ponytail@ponytail" or "token-weather" in k)]
main_rec = (own.get(main) or [None])[0] or (users or [None])[0]

for c, branch in cos:
    worker = " worker" if branch.startswith("worker-") else ""
    for r in own.get(c, []):
        install(c, r, worker)
    if c not in own:
        row(c, "install", "stratum@stratum", "listed", "no install" + worker)
    statusline(c, (own.get(c) or [None])[0] or main_rec)

    probe = [n + "x" if n.endswith("/") else n for n in IGNORE]
    hit = set(git("-C", c, "check-ignore", "--no-index", "--", *probe).stdout.splitlines())
    for n, q in zip(IGNORE, probe):
        row(c, "ignore", n, "current" if q in hit else "new", ".gitignore")

    txt = {n: read(f"{c}/{n}") for n in ("AGENTS.md", "CLAUDE.md", "CLAUDE.local.md")}
    has_agents = txt["AGENTS.md"] is None or "@AGENTS.md" in [l.strip() for l in (txt["CLAUDE.md"] or "").splitlines()]
    row(c, "pointer", "@AGENTS.md", "current" if has_agents else "new", "CLAUDE.md")
    has_const = any(".stratum/constitution.md" in (t or "") for t in txt.values())
    row(c, "pointer", "@.stratum/constitution.md", "current" if has_const else "new", "CLAUDE.md")

    ps, pl = load(f"{c}/.claude/settings.json"), load(f"{c}/.claude/settings.local.json")
    for k in offkeys:
        if not SAFE.fullmatch(k):
            row(c, "plugins-off", k, "invalid", f"plugin key in {cfg}/settings.json has unsafe characters")
            continue
        if ps is None:
            row(c, "plugins-off", k, "invalid", ".claude/settings.json is not a JSON object")
            continue
        off = any(isinstance(x.get("enabledPlugins"), dict) and x["enabledPlugins"].get(k) is False for x in (ps, pl or {}))
        row(c, "plugins-off", k, "current" if off else "new", ".claude/settings.json")

    allow = allowed(ps) if ps is not None else []
    if any(s.startswith("mcp__plugin_stratum_figcraft__") for s in allow):
        for t in tools:
            row(c, "figcraft", t, "current" if t in allow else "new", ".claude/settings.json")

    if c == main:
        for n in FILES:
            there = os.path.exists(f"{c}/{n}")
            row(c, "file", n, "current" if there else "new",
                "present" if there else "missing, run /stratum:st-constitution" if n.endswith("constitution.md") else "missing")

    models = load(f"{c}/.stratum/models.json")
    if models is None:
        row(c, "models-key", ".stratum/models.json", "invalid", "not a JSON object")
    else:
        for k in models:
            judged(c, "models-key", k, k not in agents and k != "st-worker", ".stratum/models.json")

    for fn, x in ((".claude/settings.json", ps), (".claude/settings.local.json", pl or {})):
        if x is None:
            row(c, "allow", fn, "invalid", f"{fn} is not a JSON object")
            continue
        for s in allowed(x):
            d = dead(s)
            if d is not None:
                judged(c, "allow", s, d, fn)

    for n in GONE:
        row(c, "gone-file", n, "discontinued" if os.path.lexists(f"{c}/{n}") else "current", "each checkout")

    for p, r in subs.get(c, []):
        install(p, r)
        statusline(p, r, only_stratum=True)

for p, state, detail in tail:
    row(p, "install", "stratum@stratum", state, detail)

if cmd == "audit":
    @functools.cache
    def dirty(c, n):
        p = git("-C", c, "status", "--porcelain", "--", n)
        if p.returncode:
            return f"git status failed for {n}"
        return f"{n} has uncommitted changes" if p.stdout.strip() else None

    def mark(r):
        f, kind, name, state, detail = r
        n = detail if kind == "allow" else name if kind == "file" else FN.get(kind)
        if wt.returncode or f not in paths or n not in COMMITTED or state in ("invalid", "current"):
            return r
        if kind == "file" and git("-C", f, "check-ignore", "--no-index", "--", n).returncode == 0:
            return r
        if f in det:
            return (f, kind, name, "skip", "detached HEAD, no branch to commit on")
        rp = os.path.relpath(os.path.realpath(f"{f}/{n}"), os.path.realpath(f))
        d = dirty(f, n if rp.split(os.sep)[0] == ".." else rp)
        if d:
            return (f, kind, name, "skip", d)
        if kind in ("ignore", "pointer") and name not in [l.strip() for l in (read(f"{f}/{n}") or "").splitlines()]:
            p = git("-C", f, "log", "-1", "--no-show-signature", "--first-parent", "--format=%h", "-G^" + re.sub(r"([.\[\]()*+?{}|^$\\])", r"\\\1", name) + "$", "--", n)
            if p.returncode == 0 and p.stdout.strip():
                return (f, kind, name, state, f"removed in {clean(p.stdout.strip())}")
        return r

    print("\n".join("\t".join(mark(r)) for r in ROWS))
    sys.exit()


def refuse(msg):
    print(msg, file=sys.stderr)
    sys.exit(3)


folder, kind, name = os.path.abspath(args[0]), args[1], args[2]
entry = name
if kind == "allow":
    fn, _, entry = name.partition(":")
    if fn not in (".claude/settings.json", ".claude/settings.local.json"):
        refuse(f"skip: {fn} is not a settings file")
else:
    fn = FN.get(kind, name)
path = os.path.join(folder, fn)
data = None
if kind in ("statusline", "plugins-off", "figcraft", "models-key", "allow"):
    data = load(path, {})
    if data is None:
        refuse(f"skip: {fn} is not valid JSON")
if kind == "file" and name != ".stratum/state.json":
    refuse(f"skip: {name} is written after the st-init question")
t = TARGET.get(folder)
if kind == "statusline" and (not t or t.get("version") != ver):
    refuse("skip: install not updated" if t else "skip: no install record")
hit = [r[3] for r in ROWS if r[:3] == (folder, kind, clean(entry)) and (kind != "allow" or r[4] == fn)]
state = hit[0] if hit else None
if state == "current":
    print(f"same {fn}")
    sys.exit()
if state == "ask" and len(args) < 4:
    refuse("skip: not a Stratum statusline")
if state not in ("outdated", "new", "discontinued", "ask"):
    refuse(f"skip: {kind} {name} is not an item to fix in {folder}")
top = os.path.realpath(folder)
real = os.path.join(os.path.realpath(os.path.dirname(path)), os.path.basename(path)) if kind == "gone-file" else os.path.realpath(path)
if os.path.commonpath([real, top]) != top:
    refuse(f"skip: {fn} points outside {folder}")

if kind in ("ignore", "pointer"):
    old = read(path) or ""
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(("\n" if old and not old.endswith("\n") else "") + name + "\n")
elif kind == "gone-file":
    try:
        os.remove(path)
    except OSError as e:
        refuse(f"skip: cannot remove {fn}: {e.strerror}")
elif kind == "file":
    data = {"feature_directory": None, "phase": None, "lane": None}
elif kind == "statusline":
    data["statusLine"] = {"type": "command", "command": slcmd(t)}
elif kind == "plugins-off":
    if not isinstance(data.setdefault("enabledPlugins", {}), dict):
        refuse("skip: enabledPlugins in .claude/settings.json is not an object")
    data["enabledPlugins"][name] = False
elif kind == "figcraft":
    data["permissions"]["allow"].append(name)
elif kind == "models-key":
    del data[name]
elif kind == "allow":
    data["permissions"]["allow"] = [e for e in data["permissions"]["allow"] if e != entry]
else:
    refuse(f"skip: {kind} has no fix")
if data is not None:
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    tmp = None
    try:
        os.makedirs(os.path.dirname(real), exist_ok=True)
        fd, tmp = tempfile.mkstemp(suffix=".tmp", dir=os.path.dirname(real))
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        if os.path.exists(real):
            shutil.copymode(real, tmp)
        else:
            os.chmod(tmp, 0o644)
        os.replace(tmp, real)
    except (OSError, ValueError) as e:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)
        refuse(f"skip: cannot write {fn}: {getattr(e, 'strerror', None) or e}")
print(f"changed {os.path.relpath(real, top)}")
PY
