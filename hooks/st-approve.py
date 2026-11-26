#!/usr/bin/env python3
import fnmatch
import json
import os
import posixpath
import re
import shlex
import signal
import stat
import subprocess
import sys
import time

REASON = ".stratum/approve/, .stratum/autonomous and .stratum/worker are written only by the orchestrator."
ALLOW = '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
EDIT_TOOLS = ("Edit", "Write", "MultiEdit", "NotebookEdit")
RISKY = {"approve", "pass", "autonomous-on", "autonomous-off", "wait", "start", "resend", "followup", "watch"}
SECRET_NAMES = (".env*", "*.pem", "*.key", "id_rsa*", "id_ed25519*", ".npmrc", ".netrc")
DEPENDENCY_NAMES = ("package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb",
                    "pyproject.toml", "requirements*.txt", "uv.lock", "Cargo.toml", "Cargo.lock",
                    "go.mod", "go.sum", "Gemfile", "Gemfile.lock")
COMMIT_VALUE_OPTS = {"-m", "--message", "-F", "--file", "--author", "--date", "-t", "--template",
                     "--cleanup"}
COMMIT_FLAGS = {"-s", "--signoff", "-q", "--quiet", "-v", "--verbose", "-e", "--edit", "--no-edit"}
ADD_FLAGS = {"-v", "--verbose"}
G = r"\bgit\b[^;&|\n]*"
# ponytail: the never list matches text, the orchestrator's approve rule is the main check; move to a full shell parser if a bypass shows up in use
NEVER = re.compile("|".join([
    G + r"\bpush\b", G + r"\bbranch\b[^;&|\n]*\s(?:-[a-zA-Z]*[dD]|--delete)", G + r"\bworktree\b[^;&|\n]*\b(?:remove|prune)\b",
    G + r"\bprune\b", G + r"\b(?:clean|update-ref)\b", r"\breset\b[^;&|\n]*--hard\b",
    r"\.env", r"\.pem\b", r"\.key\b", r"\bid_rsa", r"\bid_ed25519", r"\.npmrc\b", r"\.netrc\b", r"(?i:secret|credential)",
    r"\b(?:npm|pnpm|yarn|bun)\b[^;&|\n]*\s(?:i|install|add|ci|update|upgrade)\b", r"\bpip3?\s+install\b",
    r"\buv\s+(?:add|pip|tool|sync)\b", r"\bpoetry\s+add\b", r"\bcargo\s+(?:add|install)\b", r"\bgo\s+(?:get|install)\b",
    r"\bgem\s+install\b", r"\bbrew\s+install\b", r"\b(?:apt|apt-get|dnf|yum|pacman|apk)\b",
    r"\b(?:curl|wget|ssh|scp|sftp|rsync|nc|ncat|telnet|ftp|gh)\b", r"[A-Za-z][A-Za-z0-9+.-]*://",
    G + r"\b(?:clone|fetch|pull|ls-remote)\b", r"\bremote\s+add\b",
    r"\.stratum", r"\.claude\b", r"\.mcp\.json", r"CLAUDE\.md", r"AGENTS\.md", r"\.githooks", r"\.husky",
    r"\bsudo\b", r"\beval\b",
]))
COMMIT_NEVER = re.compile(r"\b(?:sh|bash|zsh)\s+-c\b|\beval\b|\bGIT_[A-Z0-9_]*=|\b(?:cd|pushd)\b")
SUBSTITUTION = re.compile(r"`|\$\(|\$\{[\s|]|[<>]\(")
CONTROL = re.compile(r"[\x00-\x1f\x7f]")
JOIN = re.compile(r"(?<!\\)((?:\\\\)*)\\\n")


def unjudgeable(command):
    return "\\\n" in command or "<<" in command or bool(SUBSTITUTION.search(command))


PLUGIN = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
LOCK = os.path.join(PLUGIN, "scripts", "st-lock.sh")
MONITOR = "stratum:st-monitor"
MONITOR_REASON = ("st-monitor runs only st-worker.sh wait, answer, approve, pass and resend, and HERDR_ENV=0 "
                  "st-advisor.sh round decisions <folder> 1 <file>. It acts only in the monitor folder that its own "
                  "agent id owns, writes only spec.md and views-<n>.md there, and reads no result file.")
MONITOR_OWNER_REASON = MONITOR_REASON + " Another agent id owns this monitor folder."
MONITOR_SUBS = {"wait": ("--beat",), "answer": ("--screen", "--record"), "approve": ("--record",),
                "pass": ("--record",), "resend": ("--record",)}
MONITOR_ONCE = ("--record", "--beat", "--screen", "--machine", "--request")
MONITOR_CHARS = re.compile(r"[A-Za-z0-9 _./:=@%+,'\"-]*")


def git(args, cwd):
    try:
        r = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=5)
    except Exception:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def first_line(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.readline().strip()
    except OSError:
        return ""


def find_root(cwd):
    d = cwd
    while not os.path.exists(os.path.join(d, ".stratum")) and not os.path.exists(os.path.join(d, ".git")) \
            and os.path.dirname(d) != d:
        d = os.path.dirname(d)
    return d


def strip_quotes(text):
    return text.replace("\\", "").replace("'", "").replace('"', "")


def up(folder):
    while True:
        yield folder
        if os.path.dirname(folder) == folder:
            return
        folder = os.path.dirname(folder)


def worker_session(cwd):
    folders = [cwd] + ([os.environ["CLAUDE_PROJECT_DIR"]] if os.environ.get("CLAUDE_PROJECT_DIR") else [])
    chain = list(dict.fromkeys(d for f in folders for d in up(os.path.realpath(f))))
    if any(os.path.lexists(os.path.join(d, ".stratum", "approve")) for d in chain):
        return True
    if any(os.path.isfile(m) and not os.path.islink(m) for m in (os.path.join(d, ".stratum", "worker") for d in chain)):
        return True
    return any((git(["symbolic-ref", "--short", "HEAD"], d) or "").startswith("worker-")
               for d in chain if os.path.exists(os.path.join(d, ".git")))


def locked_path(p):
    return "/.stratum/approve/" in p + "/" or "/.stratum/autonomous/" in p + "/" or "/.stratum/worker/" in p + "/"


# ponytail: lock 2 is a text match, not a wall (workers run as the same OS user); run-time paths, brace and glob forms and a Grep over the whole root get past it, move to OS-level isolation if workers turn hostile
def lock2(data, cwd):
    tool = data.get("tool_name")
    ti = data.get("tool_input") or {}
    if tool == "Bash":
        command = str(ti.get("command") or "")
        words = [posixpath.normpath(w) for w in re.split(r"[\s;&|()<>`]+",
                                                          strip_quotes(command + "\n" + JOIN.sub(r"\1", command))) if w]
        if any(".stratum/approve" in w or ".stratum/autonomous" in w
               or re.search(r"\.stratum/worker(?![\w.-])", w) for w in words):
            return True
        return any((w == "st-worker.sh" or w.endswith("/st-worker.sh")) and nxt.replace("$", "") in RISKY
                   for w, nxt in zip(words, words[1:]))
    if tool not in EDIT_TOOLS + ("Read", "Grep", "Glob"):
        return False
    keys = {"Grep": ("path", "glob"), "Glob": ("path", "pattern")}.get(tool, ("file_path", "notebook_path"))
    for key in keys:
        value = ti.get(key)
        if isinstance(value, str) and value:
            joined = os.path.join(cwd, value)
            if locked_path(os.path.normpath(joined)) or locked_path(os.path.realpath(joined)):
                return True
    return False


def inside(root, p):
    return p.startswith(root + os.sep)


def edit_ok(root, cwd, path):
    if not isinstance(path, str) or not path:
        return False
    joined = os.path.join(cwd, path)
    for p in (os.path.normpath(joined), os.path.realpath(joined)):
        if not inside(root, p):
            return False
        parts = p[len(root) + 1:].split(os.sep)
        name = parts[-1]
        if any(part in (".git", ".stratum", ".claude", ".githooks", ".husky") for part in parts):
            return False
        if any(fnmatch.fnmatchcase(part, pat) for part in parts for pat in SECRET_NAMES) \
                or any(w in part.lower() for part in parts for w in ("secret", "credential")):
            return False
        if parts == [".mcp.json"] or name in ("CLAUDE.md", "AGENTS.md") \
                or any(fnmatch.fnmatchcase(name, pat) for pat in DEPENDENCY_NAMES):
            return False
    return True


def bash_ok(root, cwd, command):
    lead = re.match(r"\s*(?:bash\s+)?(\S+)\s", command)
    if lead and os.path.realpath(os.path.join(cwd, os.path.expanduser(lead.group(1).strip("'\"")))) == LOCK:
        command = command[lead.end():]
    if NEVER.search(command) or NEVER.search(strip_quotes(command)):
        return False
    for word in re.findall(r"\S+", command):
        for piece in re.split(r"[=<>]", word.lstrip("<>|&;()'\"").rstrip("'\";)")):
            piece = piece.lstrip("<>|&;()'\"").rstrip("'\";)")
            if piece == "/dev/null" or not (piece.startswith(("/", "~")) or ".." in piece.split("/")):
                continue
            if not inside(root, os.path.realpath(os.path.join(cwd, os.path.expanduser(piece)))):
                return False
    return True


def split_commands(command):
    lex = shlex.shlex(JOIN.sub(r"\1", command).replace("\n", " ; "), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    tokens = list(lex)
    commands, cur, heredoc, i = [], [], False, 0
    while i < len(tokens):
        tok = tokens[i]
        if tok and set(tok) <= set("&|;()<>") and ("<" in tok or ">" in tok):
            if cur and cur[-1].isdigit():
                cur.pop()
            heredoc = heredoc or tok in ("<<", "<<<")
            i += 2
            continue
        if tok and set(tok) <= set("&|;()"):
            if cur:
                commands.append((cur, heredoc))
            cur, heredoc = [], False
        else:
            cur.append(tok)
        i += 1
    if cur:
        commands.append((cur, heredoc))
    return commands


def commit_words(command):
    try:
        return split_commands(command)
    except ValueError:
        return split_commands(strip_quotes(JOIN.sub(r"\1", command)))


def is_git(word):
    return word == "git" or word.endswith("/git")


def drop(root, rule, detail, command):
    path = os.path.join(root, ".stratum", "approve", "dropped")
    tmp = f"{path}.{os.getpid()}.tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write("\t".join((rule, CONTROL.sub("?", detail), CONTROL.sub("?", command)[:300])) + "\n")
        os.rename(tmp, path)
    except (OSError, ValueError):
        try:
            os.remove(tmp)
        except OSError:
            pass


def commit_check(root, cwd, command, commands):
    if any(COMMIT_NEVER.search(t) or COMMIT_NEVER.search(strip_quotes(t)) for t in (command, JOIN.sub(r"\1", command))):
        return drop(root, "commit-never", "", command)
    if unjudgeable(command):
        return drop(root, "unjudgeable", "", command)
    paths = []
    for words, heredoc in commands:
        for i, w in enumerate(words):
            if is_git(w) and (i + 1 >= len(words) or words[i + 1] not in ("add", "commit")):
                return drop(root, "git-word", words[i + 1] if i + 1 < len(words) else "", command)
        if not any(is_git(w) for w in words):
            continue
        i = next(i for i, w in enumerate(words) if is_git(w))
        sub, args = words[i + 1], words[i + 2:]
        if sub == "commit" and heredoc:
            return drop(root, "unjudgeable", "", command)
        rest, j = False, 0
        while j < len(args):
            a = args[j]
            if rest or not a.startswith("-"):
                paths.append(a)
            elif a == "--":
                rest = True
            elif sub == "add":
                if a not in ADD_FLAGS:
                    return drop(root, "flag", a, command)
            elif a in COMMIT_VALUE_OPTS:
                if j + 1 >= len(args) or (a in ("-F", "--file") and args[j + 1] == "-"):
                    return drop(root, "flag", a, command)
                j += 1
            elif a.split("=", 1)[0] in COMMIT_VALUE_OPTS and "=" in a:
                if a in ("-F=-", "--file=-"):
                    return drop(root, "flag", a, command)
            elif a not in COMMIT_FLAGS:
                return drop(root, "flag", a, command)
            j += 1
    branch = git(["symbolic-ref", "--short", "HEAD"], root)
    try:
        with open(os.path.join(root, ".stratum", "git-guard.json"), encoding="utf-8") as f:
            guard = json.load(f)
    except (OSError, ValueError):
        guard = None
    want = guard.get("branch") if isinstance(guard, dict) else None
    if not branch or want != branch:
        return drop(root, "branch", f"{branch or ''} vs {want if isinstance(want, str) else ''}", command)
    try:
        with open(os.path.join(root, ".stratum", "approve", "owns"), encoding="utf-8") as f:
            owns = {line.strip() for line in f if line.strip()}
    except (OSError, ValueError):
        owns = set()
    if not owns:
        return drop(root, "owns-missing", "", command)
    cached = git(["-c", "core.fsmonitor=false", "diff", "--cached", "--name-only"], root)
    if cached is None:
        return drop(root, "git-error", "", command)
    staged = set(cached.splitlines())
    staged |= {os.path.relpath(os.path.normpath(os.path.join(cwd, p)), root) for p in paths}
    if not staged <= owns:
        return drop(root, "outside-owns", sorted(staged - owns)[0], command)
    return {"branch": branch, "staged": sorted(staged)}


def request(data, cwd):
    root = find_root(cwd)
    approve = os.path.join(root, ".stratum", "approve")
    if not os.path.isdir(approve) or os.path.islink(approve):
        return
    common = git(["rev-parse", "--path-format=absolute", "--git-common-dir"], root)
    if not common:
        return
    sid = first_line(os.path.join(approve, "session"))
    if not re.fullmatch(r"[A-Za-z0-9-]+", sid):
        return
    folder = os.path.join(os.path.dirname(common), ".stratum", "autonomous")
    entry = os.path.join(folder, sid)
    if not os.path.isdir(folder) or os.path.islink(folder) or not os.path.isfile(entry) or os.path.islink(entry):
        return
    tool = data.get("tool_name")
    ti = data.get("tool_input")
    if tool not in ("Bash",) + EDIT_TOOLS or not isinstance(ti, dict):
        return
    req = {"tool_name": tool, "tool_input": ti, "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    if tool == "Bash":
        command = ti.get("command")
        if not isinstance(command, str):
            return
        commands = commit_words(command)
        commit = any(is_git(w) and "commit" in words[i + 1:] for words, _ in commands for i, w in enumerate(words))
        if not (bash_ok(root, cwd, command) and bash_ok(root, cwd, JOIN.sub(r"\1", command))):
            if commit:
                drop(root, "never-list", "", command)
            return
        if commit:
            extra = commit_check(root, cwd, command, commands)
            if extra is None:
                return
            req.update(extra)
    elif not edit_ok(root, cwd, ti.get("file_path") or ti.get("notebook_path")):
        return
    wait = os.environ.get("ST_APPROVE_WAIT", "")
    limit = int(wait) if wait.isdigit() else 300
    base = os.path.join(approve, f"{time.time_ns()}-{os.getpid()}")
    files = [base + ".req.tmp", base + ".req", base + ".ok", base + ".user"]
    try:
        with open(files[0], "w", encoding="utf-8") as f:
            json.dump(req, f)
        os.rename(files[0], files[1])
        try:
            os.remove(os.path.join(approve, "dropped"))
        except OSError:
            pass
        start = time.monotonic()
        while True:
            if os.path.exists(files[2]):
                sys.stdout.write(ALLOW + "\n")
                return
            if os.path.exists(files[3]) or time.monotonic() - start >= limit:
                return
            time.sleep(1)
    finally:
        for path in files:
            try:
                os.remove(path)
            except OSError:
                pass


def lexists(path):
    try:
        os.lstat(path)
    except FileNotFoundError:
        return False
    return True


# ponytail: the guard judges monitor paths by rules; on one more hole let the main session record one base folder and compare exact paths (plan.md Shortcuts)
def monitor_folder(folder, wid):
    ident = re.escape(wid.lower()) if wid else "[a-z0-9][a-z0-9-]{0,24}"
    if not re.fullmatch(f"monitor-{ident}-[A-Za-z0-9]{{16}}", posixpath.basename(folder)):
        return False
    if not stat.S_ISDIR(os.lstat(folder).st_mode) or lexists(os.path.join(folder, "revoked")):
        return False
    if not stat.S_ISREG(os.lstat(os.path.join(folder, "beat")).st_mode):
        return False
    return not any(lexists(os.path.join(d, ".git")) for d in up(os.path.realpath(folder)))


def monitor_path(path, name, wid=None):
    if not isinstance(path, str) or not path.startswith("/") or posixpath.normpath(path) != path:
        return None
    folder, base = posixpath.split(path)
    if not re.fullmatch(name, base) or os.path.islink(path) or not monitor_folder(folder, wid):
        return None
    return folder


# ponytail: the first call owns the folder, a tricked monitor can race it (research.md R11); switch to an owner the main session writes if the takeover fires in real runs
def monitor_owner(folder, agent_id):
    path = os.path.join(folder, "owner")
    tmp = f"{path}.{os.getpid()}"
    want = agent_id.encode("utf-8")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(want)
        os.link(tmp, path)
        return True
    except FileExistsError:
        pass
    finally:
        os.remove(tmp)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as f:
        return stat.S_ISREG(os.fstat(f.fileno()).st_mode) and f.read() == want


def monitor_folder_of(ti, cwd):
    command = ti.get("command")
    if not isinstance(command, str) or not MONITOR_CHARS.fullmatch(command):
        return None
    words = shlex.split(command)
    if len(words) == 8 and words[:2] == ["HERDR_ENV=0", "bash"] \
            and os.path.realpath(os.path.join(cwd, words[2])) == os.path.join(PLUGIN, "scripts", "st-advisor.sh") \
            and words[3:5] == ["round", "decisions"] and words[6] == "1":
        folder = monitor_path(words[7], r"views-[0-9]+\.md")
        return folder if folder is not None and folder == words[5] else None
    if len(words) < 4 or words[0] != "bash" or words[2] not in MONITOR_SUBS \
            or os.path.realpath(os.path.join(cwd, words[1])) != os.path.join(PLUGIN, "scripts", "st-worker.sh"):
        return None
    wid, args = words[3], words[4:]
    pairs = {}
    for i in range(0, len(args) - 1, 2):
        if args[i] == "--keys":
            break
        pairs[args[i]] = args[i + 1]
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,24}", wid) or any(args.count(f) > 1 for f in MONITOR_ONCE) \
            or not all(f in pairs for f in MONITOR_SUBS[words[2]]):
        return None
    folders = set()
    for flag, name in (("--record", r"record\.tsv"), ("--beat", "beat")):
        if flag in args:
            folders.add(monitor_path(pairs.get(flag), name, wid))
    return folders.pop() if len(folders) == 1 else None


def monitor_ok(data, cwd):
    agent_id = data.get("agent_id")
    tool = data.get("tool_name")
    ti = data.get("tool_input")
    if not isinstance(agent_id, str) or not agent_id or CONTROL.search(agent_id) or not isinstance(ti, dict):
        return False
    if tool == "Read":
        path = ti.get("file_path")
        return isinstance(path, str) and not re.fullmatch(r"result(?:-round[0-9]+)?\.md",
                                                         posixpath.basename(posixpath.normpath(path.strip())), re.I)
    if tool == "Write":
        folder = monitor_path(ti.get("file_path"), r"spec\.md|views-[0-9]+\.md")
    elif tool == "Bash":
        folder = monitor_folder_of(ti, cwd)
    else:
        return False
    return folder is not None and (monitor_owner(folder, agent_id) or "owner")


def deny(reason):
    sys.stdout.write(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}) + "\n")


def render(path):
    try:
        with open(path, "rb") as f:
            req = json.loads(f.read())
        line = req["tool_name"] + ": " + json.dumps(req["tool_input"], sort_keys=True, ensure_ascii=True,
                                                    separators=(",", ":"))
    except Exception:
        sys.exit(1)
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def main():
    for name in ("SIGTERM", "SIGHUP"):
        if hasattr(signal, name):
            signal.signal(getattr(signal, name), lambda *_: sys.exit(1))
    if sys.argv[1:2] == ["--render"]:
        render(sys.argv[2] if len(sys.argv) > 2 else "")
        return
    if sys.argv[1:2] == ["--worker"]:
        sys.exit(0 if worker_session(os.getcwd()) else 3)
    if sys.argv[1:2] == ["--never"]:
        text = sys.stdin.buffer.read().decode("utf-8", "replace").replace(LOCK, "")
        flat = re.sub(r"\\\n[ \t│]*", "", text)
        joined, glued = (re.sub(r"[ \t│]*\n[ \t│]*", s, flat) for s in (" ", ""))
        sys.exit(0 if any(NEVER.search(t) or NEVER.search(strip_quotes(t)) for t in (text, joined, glued)) else 4)
    monitor = False
    try:
        data = json.loads(sys.stdin.buffer.read())
        if not isinstance(data, dict):
            return
        event = data.get("hook_event_name")
        monitor = event == "PreToolUse" and data.get("agent_type") == MONITOR
        cwd = os.path.realpath(data.get("cwd") if isinstance(data.get("cwd"), str) else os.getcwd())
        if event == "PreToolUse":
            if worker_session(cwd) and lock2(data, cwd):
                deny(REASON)
            elif monitor:
                ok = monitor_ok(data, cwd)
                if ok is not True:
                    deny(MONITOR_OWNER_REASON if ok == "owner" else MONITOR_REASON)
        elif event == "PermissionRequest":
            request(data, cwd)
    except Exception:
        if monitor:
            try:
                deny(MONITOR_REASON)
            except Exception:
                sys.exit(2)
        return


if __name__ == "__main__":
    main()
