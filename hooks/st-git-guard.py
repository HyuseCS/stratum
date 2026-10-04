#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys

SEPARATORS = {"&&", "||", ";", "|", "&", "\n"}
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}
RANK = {None: 0, "ask": 1, "deny": 2}


def segments(command):
    lex = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    seg = []
    try:
        for tok in lex:
            if tok in SEPARATORS or set(tok) <= set("&|;()"):
                if seg:
                    yield seg
                seg = []
            else:
                seg.append(tok)
    except ValueError:
        pass
    if seg:
        yield seg


def parse_git(seg):
    i = 0
    while i < len(seg) and "=" in seg[i] and not seg[i].startswith("-"):
        i += 1
    if i >= len(seg) or os.path.basename(seg[i]) != "git":
        return None
    i += 1
    cdir = []
    while i < len(seg) and seg[i].startswith("-"):
        if seg[i] in GIT_OPTS_WITH_VALUE and i + 1 < len(seg):
            if seg[i] == "-C":
                cdir.append(seg[i + 1])
            i += 2
        else:
            i += 1
    if i >= len(seg):
        return None
    return seg[i], seg[i + 1:], os.path.join(*cdir) if cdir else ""


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
    ns = git(["diff", "--cached", "--name-status"], cwd)
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
    stat = git(["diff", "--cached", "--stat"], cwd).splitlines()
    if stat:
        out.append(stat[-1].strip())
    return "\n".join(out)


def mode(key):
    value = os.environ.get(f"CLAUDE_PLUGIN_OPTION_{key.upper()}", "").strip()
    return value if value in ("auto", "ask", "deny") else "ask"


def destructive(key, reason):
    m = mode(key)
    if m == "auto":
        return None, ""
    return m, f"DESTRUCTIVE ({key}: {m}): {reason}"


def judge(sub, args, gitdir):
    if "--no-verify" in args:
        return "deny", "--no-verify is blocked: hooks must run."
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
        if m == "auto" and not amend:
            return None, ""
        decision = "deny" if m == "deny" else "ask"
        head = f"git commit (commit: {m})" + (" with --amend rewrites the last commit" if amend else "")
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
    if sub == "worktree" and args[:1] in (["remove"], ["prune"]):
        return destructive(f"worktree_{args[0]}", f"git worktree {args[0]} deletes a worktree; it needs the user's OK.")
    if sub == "rebase":
        return "ask", "git rebase rewrites history."
    return None, ""


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    command = (data.get("tool_input") or {}).get("command") or ""
    cwd = data.get("cwd") or os.getcwd()
    decision, reasons = None, []
    for seg in segments(command):
        parsed = parse_git(seg)
        if not parsed:
            continue
        sub, args, cdir = parsed
        d, reason = judge(sub, args, os.path.join(cwd, cdir))
        if d:
            reasons.append(reason)
            if RANK[d] > RANK[decision]:
                decision = d
    if decision:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": "\n\n".join(reasons),
        }}))


if __name__ == "__main__":
    main()
