#!/usr/bin/env python3
import json
import os
import re
import shlex
import subprocess
import sys

SEPARATORS = {"&&", "||", ";", "|", "&", "\n"}
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
                       "--config-env"}
RANK = {None: 0, "ask": 1, "deny": 2}
GIT_WORD = re.compile(r"(?<![^\s;&|()\[\],`/])git(?![^\s;&|()\[\],`])")
UNQUOTE = str.maketrans("", "", "\\'\"")


def segments(command):
    lex = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    seg = []
    for tok in lex:
        if tok in SEPARATORS or set(tok) <= set("&|;()"):
            if seg:
                yield seg
            seg = []
        else:
            seg.append(tok)
    if seg:
        yield seg


def parse_git(seg):
    if os.path.basename(seg[0]) != "git":
        return None
    i = 1
    elsewhere = False
    cdir, conf = [], []
    while i < len(seg) and seg[i].startswith("-"):
        if seg[i].startswith(("--git-dir", "--work-tree")):
            elsewhere = True
        if seg[i] in GIT_OPTS_WITH_VALUE and i + 1 < len(seg):
            if seg[i] == "-C":
                cdir.append(seg[i + 1])
            if seg[i] in ("-c", "--config-env"):
                conf.append(seg[i + 1].split("=", 1)[0].lower())
            i += 2
        else:
            if seg[i].startswith("-C") and len(seg[i]) > 2:
                cdir.append(seg[i][2:])
            if seg[i].startswith("--config-env="):
                conf.append(seg[i][13:].split("=", 1)[0].lower())
            i += 1
    if i >= len(seg):
        return None
    return seg[i], seg[i + 1:], os.path.join(*cdir) if cdir else "", elsewhere, conf


def short_has(args, letter):
    return any(a.startswith("-") and not a.startswith("--") and letter in a[1:] for a in args)


def config_writes(args):
    write_flags = {"--unset", "--unset-all", "--add", "--replace-all", "--rename-section",
                   "--remove-section", "--edit", "-e"}
    if any(a in write_flags for a in args):
        return True
    pos, skip = [], False
    for a in args:
        if skip:
            skip = False
        elif a in ("-f", "--file", "--blob", "--type", "--default", "--comment"):
            skip = True
        elif not a.startswith("-"):
            pos.append(a)
    if pos and pos[0] in ("set", "unset", "rename-section", "remove-section", "edit"):
        return True
    if pos and pos[0] in ("get", "list"):
        return False
    return len(pos) >= 2


def git(args, cwd):
    try:
        return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True,
                              timeout=5).stdout.strip()
    except Exception:
        return ""


def staged_summary(cwd):
    ns = git(["-c", "core.fsmonitor=false", "diff", "--cached", "--name-status"], cwd)
    if not ns:
        return "No files are staged."
    groups = {}
    for line in ns.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        path = parts[-1]
        top = path.split("/", 1)[0] + "/" if "/" in path else "(root)"
        groups.setdefault(top, []).append(f"  {parts[0][0]} {path}")
    out = ["Staged files:"]
    for top in sorted(groups):
        out.append(f" {top}")
        out.extend(groups[top])
    stat = git(["-c", "core.fsmonitor=false", "diff", "--cached", "--stat"], cwd).splitlines()
    if stat:
        out.append(stat[-1].strip())
    return "\n".join(out)


def resolve(base, target, fix=os.path.realpath):
    if base is None or not target or target.startswith("-") or any(c in target for c in "$`*?["):
        return None
    return fix(os.path.join(base, os.path.expanduser(target)))


def guard_file(cwd):
    d = cwd
    while not os.path.isdir(os.path.join(d, ".stratum")) and not os.path.exists(os.path.join(d, ".git")) \
            and os.path.dirname(d) != d:
        d = os.path.dirname(d)
    try:
        value = json.load(open(os.path.join(d, ".stratum", "git-guard.json")))
    except (OSError, ValueError):
        value = {}
    return value if isinstance(value, dict) else {}


GUARD = {}


def mode(key):
    value = GUARD.get(key)
    if value not in ("auto", "ask", "deny"):
        value = os.environ.get(f"CLAUDE_PLUGIN_OPTION_{key.upper()}", "").strip()
    return value if value in ("auto", "ask", "deny") else "ask"


def destructive(key, reason):
    m = mode(key)
    if m == "auto":
        return None, ""
    return m, f"DESTRUCTIVE ({key}: {m}): {reason}"


def judge(sub, args, gitdir, elsewhere=False, conf=()):
    if "--no-verify" in args or "core.hookspath" in conf:
        return "deny", "--no-verify and -c core.hooksPath are blocked: hooks must run."
    if sub == "config":
        return ("deny", "git config writes are blocked: change git config yourself.") \
            if config_writes(args) else (None, "")
    if sub == "add":
        if "--all" in args or "." in args or short_has(args, "A"):
            return "deny", "git add -A / --all / . is blocked: stage exact paths."
        return None, ""
    if sub == "commit":
        m = mode("commit")
        amend = "--amend" in args
        if m == "auto" and not amend and not elsewhere:
            return None, ""
        decision = "deny" if m == "deny" else "ask"
        head = f"git commit (commit: {m})" + (" with --amend rewrites the last commit" if amend else "") \
            + (" may target another folder or branch" if elsewhere else "")
        return decision, head + "\n" + staged_summary(gitdir)
    if sub == "push":
        if "--delete" in args or short_has(args, "d") or any(a.startswith(":") for a in args):
            return "deny", "Deleting a remote branch is blocked: the user deletes remote branches."
        if any(a in ("--force", "-f") or a.startswith("--force-with-lease") for a in args) \
                or short_has(args, "f"):
            return destructive("force_push", "force push can overwrite remote history.")
        return "ask", "git push sends commits to the remote."
    if sub == "reset" and "--hard" in args:
        return destructive("reset_hard", "git reset --hard discards uncommitted changes.")
    if sub == "clean" and ("--force" in args or short_has(args, "f")):
        return destructive("clean", "git clean -f deletes untracked files.")
    if sub in ("checkout", "restore") and "." in args:
        return destructive("discard", f"git {sub} . discards working tree changes.")
    if sub == "branch" and (short_has(args, "D") or short_has(args, "d") or "--delete" in args):
        return destructive("branch_delete", "deleting a local branch needs the user's OK.")
    if sub == "update-ref" or sub == "branch" and ("--force" in args or any(short_has(args, c) for c in "fMC")) \
            or sub in ("fetch", "pull") and any(":" in a for a in [a for a in args if not a.startswith("-")][1:]):
        return "ask", f"git {sub} moves a local branch without a commit."
    if sub == "worktree" and args[:1] in (["remove"], ["prune"]):
        return destructive(f"worktree_{args[0]}", f"git worktree {args[0]} deletes a worktree; it needs the user's OK.")
    if sub in ("merge", "pull", "cherry-pick", "revert", "am") and elsewhere:
        return "ask", f"git {sub} may target another folder or branch."
    if sub == "rebase":
        return "ask", "git rebase rewrites history."
    if any(c.startswith("alias.") for c in conf):
        return "ask", "git -c alias.* defines a command the guard cannot read."
    return None, ""


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    command = (data.get("tool_input") or {}).get("command") or ""
    cwd = data.get("cwd") or os.getcwd()
    GUARD.update(guard_file(cwd))
    decision, reasons = None, []
    home = git(["rev-parse", "--show-toplevel"], cwd)

    def away(d):
        return d is None or not home or git(["rev-parse", "--show-toplevel"], d) != home

    def off_branch(d):
        return "branch" in GUARD and git(["symbolic-ref", "--short", "HEAD"], d) != GUARD["branch"]

    def note(d, reason):
        nonlocal decision
        if d:
            reasons.append(reason)
            if RANK[d] > RANK[decision]:
                decision = d

    here, left = cwd, False

    def check(seg, unknown=False):
        nonlocal here, left
        i = 0
        while i < len(seg) and (seg[i] in ("command", "builtin", "exec")
                                or "=" in seg[i] and not seg[i].startswith("-")):
            i += 1
        env = any(w.startswith(("GIT_DIR=", "GIT_WORK_TREE=")) for w in seg[:i])
        seg = seg[i:]
        if not seg:
            return False
        if seg[0] in ("cd", "pushd"):
            target = (seg[1:] or [None])[0]
            logical, physical = resolve(here, target, os.path.normpath), resolve(here, target)
            left = left or away(logical) or away(physical)
            here = logical if logical and os.path.isdir(logical) else physical
            return False
        parsed = parse_git(seg)
        if parsed:
            sub, args, cdir, elsewhere, conf = parsed
            gitdir = resolve(here, cdir) if cdir else here
            note(*judge(sub, args, gitdir or cwd, unknown or env or elsewhere or left
                        or away(gitdir) or off_branch(gitdir), conf))
            left = left or sub in ("switch", "checkout")
        return os.path.basename(seg[0]) == "git"

    try:
        for seg in segments(command):
            check(seg)
    except ValueError:
        decision, reasons, here, left = None, [], cwd, False
        for line in command.split("\n"):
            if not GIT_WORD.search(line.translate(UNQUOTE)):
                continue
            try:
                found = [check(seg, True) for seg in segments(line)]
            except ValueError:
                note("ask", "The git guard could not parse the command.")
                continue
            if not any(found):
                note("ask", "The git guard could not read a git command on this line.")
    if decision:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": "\n\n".join(reasons),
        }}))


if __name__ == "__main__":
    main()
