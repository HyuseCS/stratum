import collections
import importlib.util
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(PLUGIN, "hooks", "st-approve.py")
GUARD = os.path.join(PLUGIN, "hooks", "st-git-guard.py")
ALLOW = '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
DENY_REASON = ".stratum/approve/, .stratum/autonomous and .stratum/worker are written only by the orchestrator."
COMMIT_DENY = (r"Commit form denied: a commit with a heredoc, <<, a backtick, $( or a backslash line break cannot "
               r"be judged by the approve channel. Run it again as git commit -m 'subject' -m 'body': single quotes, "
               r"and no <<, backticks, $( or backslash line breaks anywhere, not even in the message. Write an "
               r"apostrophe as '\''.")
CMD = 'python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-approve.py"'
MATCHER = "Bash|Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Glob"
RID_FILE = re.compile(r"[0-9]+-[0-9]+\.(req|ok|user)")
RID_REQ = r"^[0-9]+-[0-9]+\.req$"
Run = collections.namedtuple("Run", "rc out err reqs leftover")
MONITOR_REASON = ("st-monitor runs only st-worker.sh wait, answer, approve, pass and resend, and HERDR_ENV=0 "
                  "st-advisor.sh round decisions <folder> 1 <file>. It acts only in the monitor folder that its own "
                  "agent id owns, writes only spec.md and views-<n>.md there, and reads no result file.")
MONITOR_OWNER_REASON = MONITOR_REASON + " Another agent id owns this monitor folder."
MONITOR = "stratum:st-monitor"
ID_A = "a0123456789abcdef"
ID_B = "afedcba9876543210"
WORKER_SH = os.path.join(os.path.realpath(PLUGIN), "scripts", "st-worker.sh")
ADVISOR_SH = os.path.join(os.path.realpath(PLUGIN), "scripts", "st-advisor.sh")
LOCK_SH = os.path.join(os.path.realpath(PLUGIN), "scripts", "st-lock.sh")
SLOW_CREATE = ("import os, runpy, sys, time\n"
               "real = os.open\n"
               "def slow(path, flags, *args, **kw):\n"
               "    fd = real(path, flags, *args, **kw)\n"
               "    if flags & os.O_EXCL:\n"
               "        time.sleep(0.05)\n"
               "    return fd\n"
               "os.open = slow\n"
               "sys.argv = sys.argv[1:]\n"
               "runpy.run_path(sys.argv[0], run_name='__main__')\n")

NEVER_BASH = [
    "git push",
    "git push --force",
    "git branch -D x",
    "git worktree remove ../w",
    "git reset --hard",
    "cat .env",
    "cat /etc/passwd",
    "cat ../other/f",
    "npm install left-pad",
    "pip install x",
    "curl https://example.com",
    "gh pr list",
    "echo x > .stratum/approve/1-1.ok",
    "sudo ls",
    "git clean -fd",
    "git update-ref -d refs/heads/main",
    "git \\\npush --force origin main",
    "cat .\\\n./other/f",
    "# x\\\ngit push --force origin main",
]

REFUSED_COMMITS = [
    "git commit --amend -m x",
    "git commit --no-verify -m x",
    "git commit -n -m x",
    "git commit -a -m x",
    "git checkout -b other && git add src/a.py && git commit -m x",
    "git add src/b.py && git commit -m x",
    "git -C ../x commit -m x",
    "git commit -m x src/b.py",
    "git commit -o -m x src/a.py",
    "git commit --only -m x src/a.py",
    "git commit --pathspec-from-file=f -m x",
    "git add -u && git commit -m x",
    "git add -A && git commit -m x",
    "GIT_INDEX_FILE=idx git commit -m x",
    "GIT_DIR=.git git commit -m x",
    "GIT_WORK_TREE=. git commit -m x",
    "git -c user.name=x commit -m x",
    "git checkout other && git add src/a.py && git commit -m x",
    "git rm src/b.py && git commit -m x",
    "git mv src/a.py src/c.py && git commit -m x",
    "git restore --staged src/b.py && git commit -m x",
    "git apply --cached p.diff && git commit -m x",
    "git stash pop && git commit -m x",
    "\\git checkout other # it's x\ngit add src/a.py && git commit -m x",
    'sh -c "git checkout other" && git add src/a.py && git commit -m x',
    'bash -c "git add src/b.py" && git commit -m x',
    "git commit -F - <<'EOF'\nfix the thing\nEOF",
    "git commit --file=- -m x",
    'git add src/a.py && git commit -m "$(git add src/b.py; echo m)"',
    'git add src/a.py && git commit -m "$(git stash; echo m)"',
    'git add src/a.py && git commit -m "$(git reset --soft HEAD~1; echo m)"',
    'git add src/a.py && git commit -m "`git add src/b.py`"',
    "\n".join(['git add src/a.py && git commit -m "$(cat <<\'EOF\'', "m", "EOF", "git add src/b.py", ')"']),
    "\n".join(['git add src/a.py && git commit -m "$(cat <<\'EOF\'', "m", "EOF", "git stash", "EOF", ')"']),
    "\n".join(['git add src/a.py && git commit -m "$(cat <<EOF', "$(git stash)", "EOF", ')"']),
    "\n".join(['git add "$(cat <<\'EOF\'', "src/b.py", "EOF", ')" && git commit -m x']),
    "git add src/a.py && git commit -F <(git stash; echo m)",
    'git add src/a.py && git commit -m "${ git stash; echo m; }"',
    'git add src/a.py && git commit -m "${| git add src/b.py; REPLY=m; }"',
    "\n".join(['git add src/a.py && git commit -m "$(cat <<\'EOF\'', "a message", "EOF", ')"']),
]

OWN_COMMITS = [
    "git commit -m x -- src/a.py",
    'git add src/a.py && git commit -m "demo heredoc"',
    "git add src/a.py && git commit -m x > log.txt",
    "git add src/a.py && git commit -m x 2>&1",
    'git add src/a.py && git commit -m "explain git guard"',
    'git add src/a.py && git commit -m "fix(a): b" -m "why it changed"',
]

TEST_RUNNERS = ["npm test", "npm run test", "npx vitest run", "cargo test", "go test ./...", "pytest", "uv run pytest"]

INSTALLS = ["npm install x", "npm i x", "pnpm add x", "yarn add x", "bun add x", "pip install x", "uv add x", "uv pip install x", "cargo add x", "go get x"]

LOCK2_BASH = [
    "echo x > .stratum/approve/1-1.ok",
    "touch .stratum/'approve'/1-1.ok",
    "touch .stra\\tum/approve/1-1.ok",
    "touch .stratum/./approve/1-1.ok",
    "touch .stratum//approve/1-1.ok",
    "ls .stratum/approve",
    "echo S9 > .stratum/autonomous",
    "touch .stratum/././approve/1-1.ok",
    "touch .stratum///approve/1-1.ok",
    "touch .stratum/x/../approve/1-1.ok",
    "touch .stratum/autonomous/S9",
    "rm -f .stratum/autonomous/S1",
    "mkdir -p .stratum/autonomous",
    "rm -rf .stratum/autonomous",
]

LOCK2_MARKER_BASH = [
    "echo f > .stratum/worker",
    "rm -f .stratum/worker",
    "mv x .stratum/worker",
    "cp x ./.stratum/worker",
    "touch $PWD/.stratum/worker",
    "dd if=/dev/null of=.stratum/worker",
    "python3 -c \"open('.stratum/worker','w')\"",
    "cp x y,.stratum/worker",
]

LOCK2_WORKER_CALLS = [
    "bash scripts/st-worker.sh approve worker-t1 --request 1-1 --input-stdin --record r",
    "st-worker.sh pass worker-t1 --request 1-1",
    "st-worker.sh autonomous-off --roster r",
    "st-worker.sh autonomous-on",
    "bash scripts/st-worker.sh autonomous-on",
    "bash scripts/st-worker.sh $'approve' worker-t1",
    'bash scripts/st-worker.sh "pass" worker-t1',
    "st-worker.sh wait worker-b",
    "st-worker.sh start t9 --autonomous",
    "st-worker.sh resend worker-b",
    "st-worker.sh followup worker-b --task t --test x",
    "st-worker.sh watch --roster r",
]

D30_SILENT = [
    "ls scripts/st-worker.sh",
    "cat scripts/st-worker.sh",
    "bash -n scripts/st-worker.sh",
    "shellcheck scripts/st-worker.sh",
    "grep -n approve scripts/st-worker.sh",
    "git add scripts/st-worker.sh && git commit -m x",
    "bash tests/x.sh",
]

COMMIT_FORMS = [
    ("F1", 'git commit -m "$(cat <<\'EOF\'\nfeat: x\n\nbody\nEOF\n)"'),
    ("F2", 'git commit -m "$(cat <<\'EOF\'\nfeat: say "hi\n\nbody\nEOF\n)"'),
    ("F3", "git commit -F - <<'EOF'\nfix it\nEOF"),
    ("F4", 'git commit -m "$(echo m)"'),
    ("F5", "git commit -m 'use `x` here'"),
    ("F6", 'git commit -m "${ echo m; }"'),
    ("F7", "git commit -F <(echo m)"),
    ("F8", "git commit -m 'a' -m 'b' > >(cat)"),
    ("F9", 'git add src/a.py && git -C . commit -m "$(echo m)"'),
    ("F10", "cat > n.txt <<'EOF'\nnote\nEOF\ngit commit -m x"),
    ("H2", "cat > a.md <<'EOF'\ngit commit -m x\nEOF"),
    ("P1", "git commit -m 'feat(a): b' -m 'why it changed'"),
    ("P2", "git commit -m 'subject' -m 'line one\nline two'"),
    ("P3", r"git commit -m 'it'\''s fine'"),
    ("P4", 'git add src/a.py && git commit -m "fix: b"'),
    ("N1", "cat > a.txt <<'EOF'\nhello\nEOF"),
    ("N2", "python3 - <<'PY'\nprint(1)\nPY"),
    ("N3", 'echo "git commit -m x <<EOF"'),
    ("N4", "git push"),
]

DROPS = [
    ("never-list", None, "git add src/a.py && git commit -m x && git push", {}),
    ("commit-never", None, "cd . && git add src/a.py && git commit -m x", {}),
    ("unjudgeable", None, 'git commit -m "$(echo m)"', {}),
    ("git-word", "status", "git status && git commit -m x", {}),
    ("flag", "-a", "git commit -a -m x", {}),
    ("branch", None, "git add src/a.py && git commit -m x", {"guard": "worker-t9"}),
    ("owns-missing", None, "git add src/a.py && git commit -m x", {"owns": None}),
    ("owns-missing", None, "git add src/a.py && git commit -m x", {"owns": ""}),
    ("outside-owns", "src/b.py", "git add src/b.py && git commit -m x", {}),
    ("unjudgeable", None, 'git \\\ncommit -m "$(x)"', {}, 'git \\?commit -m "$(x)"'),
    ("flag", "-a", "git commit -a -m 'a\tb\nc' " + "x" * 300, {}, "git commit -a -m 'a?b?c' " + "x" * 275),
    ("commit-never", None, "GIT_IN\\\nDEX_FILE=alternate-index git commit -\\\nm x", {},
     "GIT_IN\\?DEX_FILE=alternate-index git commit -\\?m x"),
    ("never-list", None, "ev\\\nal git commit -m x", {}, "ev\\?al git commit -m x"),
    ("never-list", None, "c\\\nd .. && git commit -m x", {}, "c\\?d .. && git commit -m x"),
    ("commit-never", None, "c\\\nd src && git commit -m x", {}, "c\\?d src && git commit -m x"),
    ("commit-never", None, "bash -\\\nc true; git commit -m x", {}, "bash -\\?c true; git commit -m x"),
    ("unjudgeable", None, "gi\\\nt commit -a -m $'x\\'y'", {}, "gi\\?t commit -a -m $'x\\'y'"),
    ("unjudgeable", None, "git add 'src/a\\\n.py' && git commit -m x", {}, "git add 'src/a\\?.py' && git commit -m x"),
    ("unjudgeable", None, 'git add "src/a\\\n.py" && git commit -m x', {}, 'git add "src/a\\?.py" && git commit -m x'),
]


def write(path, text=""):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def remove(path):
    try:
        os.remove(path)
    except FileNotFoundError:
        pass


def git(*args, cwd):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com",
                    "-c", "commit.gpgsign=false", *args],
                   cwd=cwd, check=True, capture_output=True)


def listing(folder):
    try:
        return os.listdir(folder)
    except FileNotFoundError:
        return []


def read_json(path):
    try:
        with open(path, "rb") as f:
            return json.loads(f.read())
    except (OSError, ValueError):
        return None


class ApproveHookTest(unittest.TestCase):
    def setUp(self):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        self.tmp = os.path.realpath(td.name)
        self.root = os.path.join(self.tmp, "main")
        git("init", "-q", "-b", "main", self.root, cwd=self.tmp)
        write(os.path.join(self.root, "src", "a.py"), "x = 1\n")
        write(os.path.join(self.root, "scripts", "st-worker.sh"), "#!/bin/bash\n")
        git("add", ".", cwd=self.root)
        git("commit", "-q", "--no-verify", "-m", "init", cwd=self.root)
        self.stratum = os.path.join(self.root, ".stratum")
        self.approve = os.path.join(self.stratum, "approve")
        self.auto = os.path.join(self.stratum, "autonomous")
        write(os.path.join(self.auto, "S1"))
        self.make_approve(self.root)

    def make_linked(self, name, session):
        wt = os.path.join(self.tmp, name)
        git("worktree", "add", "-q", "-b", "worker-" + name, wt, cwd=self.root)
        self.make_approve(wt, session=session + "\n")
        return wt

    def make_approve(self, folder, session="S1\n", owns="src/a.py\n"):
        approve = os.path.join(folder, ".stratum", "approve")
        write(os.path.join(approve, "session"), session)
        write(os.path.join(approve, "owns"), owns)

    def make_branch_repo(self, name, branch):
        folder = os.path.join(self.tmp, name)
        git("init", "-q", "-b", branch, folder, cwd=self.tmp)
        return folder

    def make_worker(self):
        wt = os.path.join(self.tmp, "wt")
        git("worktree", "add", "-q", "-b", "worker-t1", wt, cwd=self.root)
        self.make_approve(wt)
        return wt

    def make_marker_worker(self):
        wt = os.path.join(self.tmp, "mwt")
        git("worktree", "add", "-q", "-b", "repo-94", wt, cwd=self.root)
        write(os.path.join(wt, ".stratum", "worker"), "t1\n")
        return wt

    def make_symlink_marker_repo(self):
        folder = self.make_branch_repo("sym", "010-demo")
        target = os.path.join(self.tmp, "marker-target")
        write(target, "t1\n")
        os.makedirs(os.path.join(folder, ".stratum"))
        os.symlink(target, os.path.join(folder, ".stratum", "worker"))
        return folder

    def worker_flag(self, cwd):
        self.assertTrue(os.path.isfile(HOOK), "hooks/st-approve.py does not exist yet")
        env = {k: v for k, v in os.environ.items() if k != "CLAUDE_PROJECT_DIR"}
        r = subprocess.run([sys.executable, HOOK, "--worker"], cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=20)
        return r.returncode, r.stdout, r.stderr

    def commit_setup(self, branch="worker-t1", guard="worker-t1", owns="src/a.py\n"):
        git("checkout", "-q", "-B", branch, cwd=self.root)
        guard_path = os.path.join(self.stratum, "git-guard.json")
        owns_path = os.path.join(self.approve, "owns")
        if guard is None:
            remove(guard_path)
        else:
            write(guard_path, json.dumps({"branch": guard}))
        if owns is None:
            remove(owns_path)
        else:
            write(owns_path, owns)

    def staged_setup(self, **options):
        self.commit_setup(**options)
        write(os.path.join(self.root, "src", "a.py"), "x = 2\n")
        git("add", "src/a.py", cwd=self.root)

    def guard_decision(self, command):
        env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE_PLUGIN_OPTION_")}
        payload = json.dumps({"tool_name": "Bash", "cwd": self.root, "tool_input": {"command": command}})
        r = subprocess.run([sys.executable, GUARD], input=payload, env=env, cwd=self.root,
                           capture_output=True, text=True, timeout=20)
        self.assertEqual((r.returncode, r.stderr), (0, ""))
        if not r.stdout.strip():
            return None, ""
        out = json.loads(r.stdout)["hookSpecificOutput"]
        return out["permissionDecision"], out["permissionDecisionReason"]

    def dropped(self):
        path = os.path.join(self.approve, "dropped")
        self.assertTrue(os.path.isfile(path), "no dropped file in the approve folder")
        with open(path, encoding="utf-8") as f:
            return f.readline().rstrip("\n").split("\t")

    def run_hook(self, data, cwd, answer="user", env=None):
        self.assertTrue(os.path.isfile(HOOK), "hooks/st-approve.py does not exist yet")
        stdin_path = os.path.join(self.tmp, "stdin")
        with open(stdin_path, "wb") as f:
            f.write(data)
        run_env = {k: v for k, v in os.environ.items() if k not in ("CLAUDE_PROJECT_DIR", "ST_APPROVE_WAIT")}
        run_env.update(env or {})
        approve = os.path.join(cwd, ".stratum", "approve")
        with open(stdin_path, "rb") as stdin:
            proc = subprocess.Popen([sys.executable, HOOK], cwd=cwd, env=run_env, stdin=stdin,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        reqs = {}
        deadline = time.monotonic() + 20
        while proc.poll() is None:
            if time.monotonic() > deadline:
                proc.kill()
                proc.communicate()
                self.fail("the hook did not exit within 20 s")
            for name in listing(approve):
                if name.endswith(".req") and name not in reqs:
                    req = read_json(os.path.join(approve, name))
                    if req is not None:
                        reqs[name] = req
                        if answer:
                            open(os.path.join(approve, name[:-4] + "." + answer), "w").close()
            time.sleep(0.01)
        out, err = proc.communicate()
        leftover = sorted(n for n in listing(approve) if RID_FILE.fullmatch(n))
        return Run(proc.returncode, out.decode("utf-8"), err.decode("utf-8"), reqs, leftover)

    def payload(self, event, tool, tool_input, cwd):
        body = {"hook_event_name": event, "session_id": "S1", "cwd": cwd,
                "tool_name": tool, "tool_input": tool_input}
        return json.dumps(body, ensure_ascii=False).encode("utf-8")

    def ask(self, tool, tool_input, cwd=None, answer="user", env=None):
        cwd = cwd or self.root
        return self.run_hook(self.payload("PermissionRequest", tool, tool_input, cwd), cwd, answer, env)

    def bash(self, command, cwd=None, answer="user", env=None):
        return self.ask("Bash", {"command": command}, cwd, answer, env)

    def pre(self, tool, tool_input, cwd, env=None):
        return self.run_hook(self.payload("PreToolUse", tool, tool_input, cwd), cwd, env=env)

    def pre_bash(self, command, cwd, env=None):
        return self.pre("Bash", {"command": command}, cwd, env)

    def render(self, path):
        self.assertTrue(os.path.isfile(HOOK), "hooks/st-approve.py does not exist yet")
        r = subprocess.run([sys.executable, HOOK, "--render", path], stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=20)
        return Run(r.returncode, r.stdout.decode("utf-8"), r.stderr.decode("utf-8"), {}, [])

    def hook_text(self):
        self.assertTrue(os.path.isfile(HOOK), "hooks/st-approve.py does not exist yet")
        with open(HOOK, encoding="utf-8") as f:
            return f.read()

    def one_req(self, run):
        self.assertEqual(len(run.reqs), 1, "expected exactly one .req")
        [(name, req)] = run.reqs.items()
        self.assertRegex(name, RID_REQ)
        return req

    def assertSilent(self, run):
        self.assertEqual((run.rc, run.err, run.out, run.reqs, run.leftover), (0, "", "", {}, []))

    def assertSent(self, run):
        self.assertEqual((run.rc, run.err, run.out, run.leftover), (0, "", "", []))
        return self.one_req(run)

    def assertDenied(self, run):
        self.assertEqual((run.rc, run.err, run.reqs, run.leftover), (0, "", {}, []))
        self.assertTrue(run.out.strip(), "no output")
        self.assertEqual(json.loads(run.out), {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": DENY_REASON,
        }})

    def test_a1_stale_folder_without_autonomous(self):
        remove(os.path.join(self.auto, "S1"))
        self.assertSilent(self.bash("bash tests/x.sh"))

    def test_a2_session_id_differs(self):
        write(os.path.join(self.approve, "session"), "S2\n")
        self.assertSilent(self.bash("bash tests/x.sh"))

    def test_a3_stop_autonomous_after_a_round(self):
        self.assertSent(self.bash("bash tests/x.sh"))
        remove(os.path.join(self.auto, "S1"))
        self.assertSilent(self.bash("bash tests/y.sh"))

    def test_a4_linked_worktree_with_its_own_flag(self):
        remove(os.path.join(self.auto, "S1"))
        wt = self.make_worker()
        write(os.path.join(wt, ".stratum", "autonomous", "S1"))
        self.assertSilent(self.bash("bash tests/x.sh", cwd=wt))

    def test_a5_empty_first_lines(self):
        write(os.path.join(self.approve, "session"), "\n")
        self.assertSilent(self.bash("bash tests/x.sh"))

    def test_two_sessions_each_worker_is_sent(self):
        write(os.path.join(self.auto, "S2"))
        w1 = self.make_linked("w1", "S1")
        w2 = self.make_linked("w2", "S2")
        self.assertSent(self.bash("bash tests/x.sh", cwd=w1))
        self.assertSent(self.bash("bash tests/x.sh", cwd=w2))

    def test_removing_one_entry_leaves_the_other_session(self):
        write(os.path.join(self.auto, "S2"))
        w1 = self.make_linked("w1", "S1")
        w2 = self.make_linked("w2", "S2")
        remove(os.path.join(self.auto, "S1"))
        self.assertSilent(self.bash("bash tests/x.sh", cwd=w1))
        self.assertSent(self.bash("bash tests/x.sh", cwd=w2))

    def test_session_without_entry_is_silent(self):
        w3 = self.make_linked("w3", "S3")
        self.assertSilent(self.bash("bash tests/x.sh", cwd=w3))

    def test_old_single_file_is_off(self):
        shutil.rmtree(self.auto)
        write(self.auto, "S1\n")
        w1 = self.make_linked("w1", "S1")
        self.assertSilent(self.bash("bash tests/x.sh", cwd=w1))

    def test_symlinked_folder_is_off(self):
        shutil.rmtree(self.auto)
        target = os.path.join(self.tmp, "elsewhere")
        write(os.path.join(target, "S1"))
        os.symlink(target, self.auto)
        w1 = self.make_linked("w1", "S1")
        self.assertSilent(self.bash("bash tests/x.sh", cwd=w1))

    def test_symlinked_entry_is_off(self):
        remove(os.path.join(self.auto, "S1"))
        target = os.path.join(self.tmp, "real-entry")
        write(target)
        os.symlink(target, os.path.join(self.auto, "S1"))
        w1 = self.make_linked("w1", "S1")
        self.assertSilent(self.bash("bash tests/x.sh", cwd=w1))

    def test_session_id_with_dots_is_off(self):
        remove(os.path.join(self.auto, "S1"))
        write(os.path.join(self.auto, "S2"))
        write(os.path.join(self.stratum, "x"))
        w1 = self.make_linked("w1", "../x")
        self.assertSilent(self.bash("bash tests/x.sh", cwd=w1))

    def test_no_approve_folder_writes_nothing(self):
        shutil.rmtree(self.approve)
        self.assertSilent(self.bash("bash tests/x.sh"))
        self.assertEqual(listing(self.stratum), ["autonomous"])

    def test_approve_symlink_is_not_a_channel(self):
        shutil.rmtree(self.approve)
        target = os.path.join(self.tmp, "elsewhere")
        write(os.path.join(target, "session"), "S1\n")
        write(os.path.join(target, "owns"), "src/a.py\n")
        os.symlink(target, self.approve)
        self.assertSilent(self.bash("bash tests/x.sh"))

    def test_ok_allows_once_and_removes_its_files(self):
        run = self.bash("bash tests/x.sh", answer="ok")
        self.assertEqual((run.rc, run.err, run.out.strip(), run.leftover), (0, "", ALLOW, []))
        req = self.one_req(run)
        self.assertEqual((req["tool_name"], req["tool_input"]), ("Bash", {"command": "bash tests/x.sh"}))
        self.assertIn("time", req)

    def test_user_passes_and_removes_its_files(self):
        self.assertSent(self.bash("bash tests/x.sh", answer="user"))

    def test_no_answer_gives_up_after_the_wait(self):
        self.assertSent(self.bash("bash tests/x.sh", answer=None, env={"ST_APPROVE_WAIT": "1"}))

    def test_never_list_and_outside_edits_are_never_sent(self):
        for command in NEVER_BASH:
            with self.subTest(command=command):
                self.assertSilent(self.bash(command))
        for tool, tool_input in [
            ("Edit", {"file_path": os.path.join(self.tmp, "outside.py"), "old_string": "a", "new_string": "b"}),
            ("Edit", {"file_path": ".env.local", "old_string": "a", "new_string": "b"}),
            ("Edit", {"file_path": "package.json", "old_string": "a", "new_string": "b"}),
            ("Edit", {"file_path": ".stratum/git-guard.json", "old_string": "a", "new_string": "b"}),
            ("Write", {"file_path": ".git/config", "content": "x"}),
            ("WebFetch", {"url": "https://example.com"}),
        ]:
            with self.subTest(tool=tool, tool_input=tool_input):
                self.assertSilent(self.ask(tool, tool_input))

    def test_source_edit_and_unsplittable_commit_are_sent(self):
        with self.subTest("edit inside the root"):
            req = self.assertSent(self.ask("Edit", {"file_path": "src/a.py", "old_string": "1", "new_string": "2"}))
            self.assertEqual(req["tool_input"]["file_path"], "src/a.py")
        command = "cat > notes.txt <<'EOF'\nit's a note\nEOF\ngit commit -m x"
        with self.subTest("heredoc with it's and a git commit last, default setup"):
            self.assertSilent(self.bash(command))
        with self.subTest("heredoc with it's and a git commit last"):
            self.commit_setup()
            write(os.path.join(self.root, "src", "a.py"), "x = 2\n")
            git("add", "src/a.py", cwd=self.root)
            self.assertSilent(self.bash(command))

    def test_non_ascii_command_is_sent_under_cp1252(self):
        command = "echo café > notes.txt"
        req = self.assertSent(self.bash(command, env={"PYTHONIOENCODING": "cp1252"}))
        self.assertEqual(req["tool_input"], {"command": command})

    def test_own_commit_is_sent_with_branch_and_staged(self):
        self.commit_setup()
        req = self.assertSent(self.bash("git add src/a.py && git commit -m x"))
        self.assertEqual((req.get("branch"), req.get("staged")), ("worker-t1", ["src/a.py"]))

    def test_own_commit_forms_are_sent_with_staged(self):
        self.commit_setup()
        for command in OWN_COMMITS:
            with self.subTest(command=command):
                req = self.assertSent(self.bash(command))
                self.assertEqual(req.get("staged"), ["src/a.py"])

    def test_refused_commit_forms_are_never_sent(self):
        self.commit_setup()
        for command in REFUSED_COMMITS:
            with self.subTest(command=command):
                self.assertSilent(self.bash(command))

    def test_unowned_file_already_staged_is_not_sent(self):
        self.commit_setup()
        write(os.path.join(self.root, "src", "b.py"), "y = 2\n")
        git("add", "src/b.py", cwd=self.root)
        self.assertSilent(self.bash("git add src/a.py && git commit -m x"))

    def test_commit_needs_owns_and_a_matching_branch(self):
        cases = [
            ("owns missing", {"owns": None}),
            ("owns empty", {"owns": ""}),
            ("guard file missing", {"guard": None}),
            ("guard names another branch", {"guard": "worker-t9"}),
            ("HEAD is main, guard says worker-t1", {"branch": "main"}),
        ]
        for label, options in cases:
            with self.subTest(label):
                self.commit_setup(**options)
                self.assertSilent(self.bash("git add src/a.py && git commit -m x"))

    def test_test_runners_are_sent(self):
        for command in TEST_RUNNERS:
            with self.subTest(command=command):
                self.assertSent(self.bash(command))

    def test_install_and_add_commands_are_silent(self):
        for command in INSTALLS:
            with self.subTest(command=command):
                self.assertSilent(self.bash(command))

    def test_agent_config_files_are_not_sent(self):
        for path in [".claude/settings.json", ".mcp.json", "CLAUDE.md", "AGENTS.md",
                     ".githooks/pre-commit", ".husky/pre-commit"]:
            with self.subTest(path=path):
                self.assertSilent(self.ask("Edit", {"file_path": path, "old_string": "a", "new_string": "b"}))
        for command in ["echo x > .claude/settings.json", "cd .claude && echo x > settings.local.json",
                        "echo {} > .mcp.json"]:
            with self.subTest(command=command):
                self.assertSilent(self.bash(command))

    def test_test_lock_from_the_plugin_root_is_judged_by_its_rest(self):
        scripts = os.path.join(os.path.realpath(PLUGIN), "scripts")
        lock = os.path.join(scripts, "st-lock.sh")
        for command in [f"bash {lock} -- bash tests/x.sh", f"{lock} -- pytest"]:
            with self.subTest(command=command):
                self.assertSent(self.bash(command))
        for command in [f"bash {lock} -- cat ../other/f", f"bash {lock} -- git push", f"echo x > {lock}",
                        f"bash {os.path.join(scripts, 'st-worker.sh')} pass x",
                        f"bash tests/x.sh && bash {lock} -- pytest"]:
            with self.subTest(command=command):
                self.assertSilent(self.bash(command))

    def test_sigterm_and_sighup_remove_the_req(self):
        stdin_path = os.path.join(self.tmp, "stdin")
        with open(stdin_path, "wb") as f:
            f.write(self.payload("PermissionRequest", "Bash", {"command": "bash tests/x.sh"}, self.root))
        env = {k: v for k, v in os.environ.items() if k != "CLAUDE_PROJECT_DIR"}
        env["ST_APPROVE_WAIT"] = "60"
        for name in ("SIGTERM", "SIGHUP"):
            if not hasattr(signal, name):
                continue
            with self.subTest(name), open(stdin_path, "rb") as stdin:
                proc = subprocess.Popen([sys.executable, HOOK], cwd=self.root, env=env, stdin=stdin,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                deadline = time.monotonic() + 20
                while not any(n.endswith(".req") for n in listing(self.approve)):
                    if proc.poll() is not None or time.monotonic() > deadline:
                        proc.kill()
                        proc.communicate()
                        self.fail("the hook wrote no .req")
                    time.sleep(0.01)
                proc.send_signal(getattr(signal, name))
                out, _ = proc.communicate(timeout=10)
                self.assertEqual(out, b"")
                self.assertEqual(sorted(n for n in listing(self.approve) if RID_FILE.fullmatch(n)), [])

    def test_render_is_one_sorted_ascii_line(self):
        first = os.path.join(self.tmp, "first.req")
        second = os.path.join(self.tmp, "second.req")
        write(first, json.dumps({"tool_name": "Bash", "tool_input": {"command": "echo é", "description": "d"},
                                 "time": 1}, ensure_ascii=False))
        write(second, json.dumps({"tool_name": "Bash", "tool_input": {"description": "d", "command": "echo é"},
                                  "time": 1}, ensure_ascii=False))
        a = self.render(first)
        b = self.render(second)
        self.assertEqual((a.rc, a.err), (0, ""))
        self.assertEqual(a.out.splitlines(), ['Bash: {"command":"echo \\u00e9","description":"d"}'])
        self.assertEqual(a.out, b.out)

    def test_stdin_that_is_not_json_is_silent(self):
        self.assertSilent(self.run_hook(b"not json\n", cwd=self.root))

    def test_registered_in_commands_json(self):
        with open(os.path.join(PLUGIN, "hooks", "commands.json"), encoding="utf-8") as f:
            hooks = json.load(f)["hooks"]
        hook = {"type": "command", "command": CMD, "timeout": 310}
        self.assertEqual(hooks.get("PermissionRequest"), [{"hooks": [hook]}])
        pre = {"type": "command", "command": CMD, "timeout": 10}
        entries = [e for e in hooks.get("PreToolUse", []) if e.get("matcher") == MATCHER]
        self.assertEqual([e.get("hooks") for e in entries], [[pre]])

    def test_hook_never_answers_deny(self):
        text = self.hook_text()
        self.assertNotIn('"behavior": "deny"', text)
        self.assertNotIn('"behavior":"deny"', text)

    def test_worker_denies_approve_and_autonomous_writes(self):
        wt = self.make_worker()
        for command in LOCK2_BASH:
            with self.subTest(command=command):
                self.assertDenied(self.pre_bash(command, cwd=wt))

    def test_worker_denies_st_worker_control_calls(self):
        wt = self.make_worker()
        sub = os.path.join(wt, "sub")
        git("init", "-q", sub, cwd=wt)
        cases = [(command, wt, None) for command in LOCK2_WORKER_CALLS]
        cases += [
            (f"cd {self.root} && bash scripts/st-worker.sh pass worker-t1", wt, {"CLAUDE_PROJECT_DIR": wt}),
            ("git init sub && cd sub && st-worker.sh pass x", sub, None),
        ]
        for command, cwd, env in cases:
            with self.subTest(command=command, cwd=cwd):
                self.assertDenied(self.pre_bash(command, cwd=cwd, env=env))

    def test_worker_denies_file_tools_on_approve_and_autonomous(self):
        wt = self.make_worker()
        targets = [
            os.path.join(wt, ".stratum", "approve", "1-1.ok"),
            os.path.join(wt, ".stratum", ".", "approve", "x"),
            os.path.join(wt, ".stratum", "autonomous"),
            os.path.join(wt, ".stratum", "autonomous", "S1"),
            os.path.join(wt, ".stratum", ".", "autonomous", "S1"),
        ]
        cases = []
        for p in targets:
            cases += [
                ("Edit", {"file_path": p, "old_string": "a", "new_string": "b"}),
                ("Write", {"file_path": p, "content": "x"}),
                ("MultiEdit", {"file_path": p, "edits": []}),
                ("NotebookEdit", {"notebook_path": p, "new_source": "x"}),
            ]
        cases += [
            ("Read", {"file_path": os.path.join(wt, ".stratum", "approve", "session")}),
            ("Read", {"file_path": os.path.join(wt, ".stratum", "autonomous")}),
            ("Read", {"file_path": os.path.join(wt, ".stratum", "autonomous", "S1")}),
            ("Glob", {"pattern": ".stratum/autonomous/*"}),
            ("Grep", {"pattern": "x", "path": os.path.join(wt, ".stratum", "autonomous")}),
            ("Grep", {"pattern": "x", "path": os.path.join(wt, ".stratum", "approve")}),
            ("Grep", {"pattern": "x", "glob": ".stratum/approve/*"}),
            ("Glob", {"pattern": ".stratum/approve/*"}),
            ("Glob", {"pattern": "*", "path": os.path.join(wt, ".stratum", "approve")}),
        ]
        for tool, tool_input in cases:
            with self.subTest(tool=tool, tool_input=tool_input):
                self.assertDenied(self.pre(tool, tool_input, wt))

    def test_worker_allows_work_on_st_worker_files(self):
        wt = self.make_worker()
        for command in D30_SILENT:
            with self.subTest(command=command):
                self.assertSilent(self.pre_bash(command, cwd=wt))
        with self.subTest("Edit of scripts/st-worker.sh"):
            self.assertSilent(self.pre("Edit", {"file_path": "scripts/st-worker.sh", "old_string": "a", "new_string": "b"}, wt))
        with self.subTest("Grep pattern names approve, path is scripts"):
            self.assertSilent(self.pre("Grep", {"pattern": ".stratum/approve", "path": "scripts"}, wt))
        with self.subTest("Edit of src/a.py"):
            self.assertSilent(self.pre("Edit", {"file_path": "src/a.py", "old_string": "a", "new_string": "b"}, wt))

    def test_worker_is_found_by_project_dir_symlink_or_branch(self):
        wt = self.make_worker()
        demo = self.make_branch_repo("demo", "010-demo")
        with self.subTest("cwd is not a worker, CLAUDE_PROJECT_DIR is"):
            self.assertDenied(self.pre_bash("echo x > .stratum/approve/1-1.ok", cwd=demo,
                                            env={"CLAUDE_PROJECT_DIR": wt}))
        with self.subTest("symlink to .stratum/approve"):
            os.symlink(".stratum/approve", os.path.join(wt, "link"))
            self.assertDenied(self.pre("Edit", {"file_path": "link/1-1.ok", "old_string": "a", "new_string": "b"}, wt))
        br = self.make_branch_repo("br", "worker-t1")
        with self.subTest("branch only, no .stratum/approve"):
            self.assertDenied(self.pre_bash("echo x > .stratum/autonomous", cwd=br))
            self.assertDenied(self.pre_bash("echo x > .stratum/auto\\\nnomous", cwd=br))
            self.assertSilent(self.pre("Edit", {"file_path": "src/a.py", "old_string": "a", "new_string": "b"}, br))
            self.assertSilent(self.pre_bash("bash tests/x.sh", cwd=br))

    def test_orchestrator_session_is_silent(self):
        demo = self.make_branch_repo("demo", "010-demo")
        self.assertSilent(self.pre_bash(
            "bash scripts/st-worker.sh approve worker-t1 --request 1-1 --input-stdin --record r", cwd=demo))
        self.assertSilent(self.pre_bash("printf S1 > .stratum/autonomous", cwd=demo))
        self.assertSilent(self.pre_bash("touch .stratum/autonomous/S1", cwd=demo))

    def test_marker_session_denies_marker_writes(self):
        wt = self.make_marker_worker()
        for command in LOCK2_MARKER_BASH + LOCK2_BASH:
            with self.subTest(command=command):
                self.assertDenied(self.pre_bash(command, cwd=wt))
        marker = os.path.join(wt, ".stratum", "worker")
        for tool, tool_input in [
            ("Edit", {"file_path": marker, "old_string": "a", "new_string": "b"}),
            ("Write", {"file_path": marker, "content": "x"}),
            ("MultiEdit", {"file_path": marker, "edits": []}),
            ("NotebookEdit", {"notebook_path": marker, "new_source": "x"}),
        ]:
            with self.subTest(tool=tool):
                self.assertDenied(self.pre(tool, tool_input, wt))

    def test_marker_session_is_a_worker(self):
        wt = self.make_marker_worker()
        self.assertDenied(self.pre_bash("bash scripts/st-worker.sh approve worker-t1 --request 1-1", cwd=wt))
        self.assertDenied(self.pre_bash("echo x > .stratum/autonomous", cwd=wt))

    def test_worker_branch_without_marker_denies_marker_writes(self):
        br = self.make_branch_repo("br", "worker-t1")
        self.assertDenied(self.pre_bash("echo f > .stratum/worker", cwd=br))

    def test_marker_symlink_is_not_a_worker(self):
        sym = self.make_symlink_marker_repo()
        self.assertSilent(self.pre_bash("touch .stratum/autonomous/S1", cwd=sym))

    def test_orchestrator_marker_write_is_silent(self):
        demo = self.make_branch_repo("demo", "010-demo")
        self.assertSilent(self.pre_bash("echo f > .stratum/worker", cwd=demo))

    def test_worker_setup_is_not_the_marker(self):
        wt = self.make_marker_worker()
        write(os.path.join(wt, ".stratum", "worker-setup.sh"), "#!/bin/bash\n")
        for command in ["cat .stratum/worker-setup.sh", "bash .stratum/worker-setup.sh"]:
            with self.subTest(command=command):
                self.assertSilent(self.pre_bash(command, cwd=wt))
        with self.subTest("Edit of .stratum/worker-setup.sh"):
            self.assertSilent(self.pre("Edit", {"file_path": os.path.join(wt, ".stratum", "worker-setup.sh"),
                                                "old_string": "a", "new_string": "b"}, wt))

    def test_worker_flag(self):
        wt = self.make_marker_worker()
        sub = os.path.join(wt, "sub")
        os.makedirs(sub)
        branch_repo = self.make_branch_repo("br", "worker-t1")
        for label, cwd in [("marker worktree", wt), ("subfolder of it", sub),
                           ("worker-t1 branch repo", branch_repo), ("approve folder repo", self.root)]:
            with self.subTest(label):
                self.assertEqual(self.worker_flag(cwd), (0, b"", b""))
        for label, cwd in [("010-demo", self.make_branch_repo("demo", "010-demo")),
                           ("symlink marker", self.make_symlink_marker_repo())]:
            with self.subTest(label):
                self.assertEqual(self.worker_flag(cwd), (3, b"", b""))

    def test_table_commit_forms_through_both_hooks(self):
        self.staged_setup()
        for row, command in COMMIT_FORMS:
            guard = self.guard_decision(command)
            with self.subTest(row=row, hook="guard"):
                if row[0] in ("F", "H"):
                    self.assertEqual(guard, ("deny", COMMIT_DENY))
                elif row[0] == "P":
                    self.assertNotEqual(guard, ("deny", COMMIT_DENY))
                elif row == "N4":
                    self.assertEqual(guard, ("ask", "git push sends commits to the remote."))
                else:
                    self.assertEqual(guard, (None, ""))
            if row[0] == "N" and row != "N4":
                continue
            with self.subTest(row=row, hook="channel"):
                run = self.bash(command)
                if row[0] == "P":
                    req = self.assertSent(run)
                    self.assertEqual((req["tool_input"]["command"], req.get("branch"), req.get("staged")),
                                     (command, "worker-t1", ["src/a.py"]))
                else:
                    self.assertSilent(run)

    def test_unjudgeable_is_the_one_form_test(self):
        spec = importlib.util.spec_from_file_location("st_approve", HOOK)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        unjudgeable = module.unjudgeable
        for row, command in COMMIT_FORMS:
            if row[0] != "N":
                with self.subTest(row=row):
                    self.assertEqual(unjudgeable(command), row[0] in ("F", "H"))

    def test_dropped_names_the_rule_that_refused_a_commit(self):
        for rule, detail, command, options, *shown in DROPS:
            with self.subTest(rule=rule, command=command, options=options):
                self.staged_setup(**options)
                remove(os.path.join(self.approve, "dropped"))
                self.assertSilent(self.bash(command))
                fields = self.dropped()
                self.assertEqual(fields[0], rule)
                if detail is not None:
                    self.assertEqual(fields[1], detail)
                self.assertEqual(fields[2], shown[0] if shown else command)

    def test_failed_drop_leaves_no_tmp_file(self):
        self.staged_setup()
        os.makedirs(os.path.join(self.approve, "dropped", "x"))
        self.assertSilent(self.bash("git commit -a -m x"))
        self.assertEqual([n for n in listing(self.approve) if n.endswith(".tmp")], [])

    def test_dropped_git_error_when_git_cannot_read_the_index(self):
        self.staged_setup()
        write(os.path.join(self.root, ".git", "index"), "not an index\n")
        self.assertSilent(self.bash("git add src/a.py && git commit -m x"))
        self.assertEqual(self.dropped()[0], "git-error")

    def test_sent_commit_removes_a_stale_dropped_file(self):
        self.staged_setup()
        write(os.path.join(self.approve, "dropped"), "x\t\t\n")
        self.assertSent(self.bash("git add src/a.py && git commit -m x"))
        self.assertFalse(os.path.exists(os.path.join(self.approve, "dropped")))

    def mon_dir(self, wid, tag, beat=True, owner=None, parent=None, machine="local"):
        folder = os.path.join(parent or self.tmp, f"monitor-{machine}-{wid}-{(tag + 'k' * 16)[:16]}")
        os.makedirs(folder)
        if beat:
            write(os.path.join(folder, "beat"))
        if owner is not None:
            write(os.path.join(folder, "owner"), owner)
        return folder

    def monitors(self, owner_a=ID_A):
        self.A = self.mon_dir("t004", "A1", owner=owner_a)
        self.B = self.mon_dir("t005", "B1", owner=ID_B)
        self.plain = os.path.join(self.tmp, "plain")
        os.makedirs(self.plain, exist_ok=True)

    def monitor(self, tool, tool_input, agent_id=ID_A, agent_type=MONITOR, cwd=None):
        cwd = cwd or self.plain
        body = {"hook_event_name": "PreToolUse", "session_id": "S1", "cwd": cwd,
                "tool_name": tool, "tool_input": tool_input}
        if agent_type is not None:
            body["agent_type"] = agent_type
        if agent_id is not None:
            body["agent_id"] = agent_id
        return self.run_hook(json.dumps(body).encode(), cwd)

    def assertMonitorDeny(self, run, reason=MONITOR_REASON):
        self.assertEqual((run.rc, run.err, run.reqs, run.leftover), (0, "", {}, []))
        self.assertTrue(run.out.strip(), "no output")
        self.assertEqual(json.loads(run.out), {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }})

    def sh(self, sub, wid, *args):
        return " ".join(["bash", WORKER_SH, sub, wid, *args])

    def bash_row(self, command):
        return (command, "Bash", {"command": command})

    def forms(self, folder, wid):
        record = os.path.join(folder, "record.tsv")
        return [self.bash_row(c) for c in [
            self.sh("wait", wid, "--beat", os.path.join(folder, "beat")),
            self.sh("answer", wid, "--screen", "h1", "--record", record),
            self.sh("approve", wid, "--request", "1-1", "--input-hash", "h1", "--record", record),
            self.sh("pass", wid, "--request", "1-1", "--record", record),
            self.sh("resend", wid, "--record", record),
        ]] + [("Write views-1.md", "Write", {"file_path": os.path.join(folder, "views-1.md"), "content": "x"})]

    def deny_rows(self, rows, reason=MONITOR_REASON, **kw):
        for label, tool, tool_input, *cwd in rows:
            with self.subTest(label):
                self.assertMonitorDeny(self.monitor(tool, tool_input, cwd=cwd[0] if cwd else None, **kw), reason)

    def at_once(self, folder, agent_ids):
        env = {k: v for k, v in os.environ.items() if k not in ("CLAUDE_PROJECT_DIR", "ST_APPROVE_WAIT")}
        command = self.sh("wait", "T004", "--beat", folder + "/beat")
        second, first = [subprocess.Popen(args, cwd=self.plain, env=env, stdin=subprocess.PIPE,
                                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                          for args in ([sys.executable, HOOK], [sys.executable, "-c", SLOW_CREATE, HOOK])]
        body = lambda agent_id: json.dumps({"hook_event_name": "PreToolUse", "session_id": "S1", "cwd": self.plain,
                                            "tool_name": "Bash", "tool_input": {"command": command},
                                            "agent_type": MONITOR, "agent_id": agent_id}).encode()
        first.stdin.write(body(agent_ids[0]))
        first.stdin.close()
        first.stdin = None
        deadline = time.monotonic() + 20
        while first.poll() is None and not any(n.startswith("owner") for n in listing(folder)):
            if time.monotonic() > deadline:
                first.kill()
                second.kill()
                self.fail("the first call made no owner file within 20 s")
            time.sleep(0.001)
        second.stdin.write(body(agent_ids[1]))
        second.stdin.close()
        second.stdin = None
        runs = []
        for proc in (first, second):
            out, err = proc.communicate(timeout=20)
            runs.append((proc.returncode, out.decode(), err.decode()))
        return runs

    def test_monitor_first_call_makes_owner(self):
        self.monitors(owner_a=None)
        self.assertSilent(self.monitor("Bash", {"command": self.sh("wait", "T004", "--beat", self.A + "/beat")}))
        owner = os.path.join(self.A, "owner")
        self.assertTrue(os.path.isfile(owner) and not os.path.islink(owner), "no owner file")
        with open(owner, "rb") as f:
            self.assertEqual(f.read(), ID_A.encode())
        for label, tool, tool_input in self.forms(self.A, "T004"):
            with self.subTest(label):
                self.assertSilent(self.monitor(tool, tool_input))

    def test_monitor_first_call_makes_owner_through_a_symlinked_parent(self):
        self.monitors()
        real = os.path.join(self.tmp, "real")
        os.makedirs(real)
        os.symlink(real, os.path.join(self.tmp, "link"))
        folder = self.mon_dir("t004", "P1", parent=real)
        via = os.path.join(self.tmp, "link", os.path.basename(folder))
        self.assertSilent(self.monitor("Bash", {"command": self.sh("wait", "T004", "--beat", via + "/beat")}))
        self.assertTrue(os.path.isfile(os.path.join(folder, "owner")), "no owner file")

    def test_monitor_same_id_first_calls_at_once_are_both_allowed(self):
        self.monitors()
        for i in range(100):
            folder = self.mon_dir("t004", f"R{i}")
            runs = self.at_once(folder, [ID_A, ID_A])
            self.assertEqual(runs, [(0, "", "")] * 2, f"round {i}")
            self.assertEqual(sorted(n for n in listing(folder) if n.startswith("owner")), ["owner"], f"round {i}")

    def test_monitor_two_ids_at_once_are_never_both_allowed(self):
        self.monitors()
        for i in range(100):
            folder = self.mon_dir("t004", f"R{i}")
            runs = self.at_once(folder, [ID_A, ID_B])
            self.assertLessEqual(runs.count((0, "", "")), 1, f"round {i}: {runs}")
            self.assertEqual(sorted(n for n in listing(folder) if n.startswith("owner")), ["owner"], f"round {i}")

    def test_monitor_allows_its_own_calls_with_empty_stdout(self):
        self.monitors()
        for label, tool, tool_input in self.forms(self.A, "T004"):
            with self.subTest("A " + label):
                self.assertSilent(self.monitor(tool, tool_input))
        with self.subTest("A spec.md"):
            self.assertSilent(self.monitor("Write", {"file_path": self.A + "/spec.md", "content": "x"}))
        for label, tool, tool_input in self.forms(self.B, "T005"):
            with self.subTest("B " + label):
                self.assertSilent(self.monitor(tool, tool_input, agent_id=ID_B))
        with self.subTest("B spec.md"):
            self.assertSilent(self.monitor("Write", {"file_path": self.B + "/spec.md", "content": "x"}, agent_id=ID_B))
        for path in (os.path.join(self.root, "src", "a.py"), os.path.join(self.tmp, "any.txt"), "/etc/hostname"):
            with self.subTest(path=path):
                self.assertSilent(self.monitor("Read", {"file_path": path}))
        record, beat = self.A + "/record.tsv", self.A + "/beat"
        for command in [
            self.sh("answer", "T004", "--screen", "h1", "--record", record, "--keys", "1"),
            self.sh("answer", "T004", "--screen", "h1", "--record", record, "--keys", "1", "2"),
            self.sh("answer", "T004", "--screen", "h1", "--record", record, "--text", '"use main"'),
            self.sh("wait", "T004", "--beat", beat),
        ]:
            with self.subTest(command):
                self.assertSilent(self.monitor("Bash", {"command": command}))
        with self.subTest("B round call"):
            self.assertSilent(self.monitor("Bash", {"command": self.rnd(self.B)}, agent_id=ID_B))

    def machine_forms(self, folder, machine):
        record, beat = folder + "/record.tsv", folder + "/beat"
        return [self.bash_row(c) for c in [
            self.sh("answer", "T004", "--machine", machine, "--screen", "h1", "--record", record, "--keys", "2"),
            self.sh("wait", "T004", "--machine", machine, "--beat", beat),
            self.sh("approve", "T004", "--request", "1-1", "--input-hash", "h1", "--record", record, "--machine", machine),
            self.sh("pass", "T004", "--machine", machine, "--request", "1-1", "--record", record),
            self.sh("resend", "T004", "--machine", machine, "--record", record),
        ]]

    def test_monitor_binds_the_folder_to_the_machine(self):
        self.monitors()
        laptop = self.mon_dir("t004", "M1", owner=ID_A, machine="laptop")
        for machine in ("laptop", "LAPTOP", "Laptop"):
            for label, tool, tool_input in self.machine_forms(laptop, machine):
                with self.subTest("laptop folder " + label):
                    self.assertSilent(self.monitor(tool, tool_input))
        with self.subTest("laptop folder Write spec.md"):
            self.assertSilent(self.monitor("Write", {"file_path": laptop + "/spec.md", "content": "x"}))
        with self.subTest("laptop folder round call"):
            self.assertSilent(self.monitor("Bash", {"command": self.rnd(laptop)}))
        self.deny_rows(self.machine_forms(self.A, "laptop"))
        self.deny_rows(self.machine_forms(laptop, "desk"))
        self.deny_rows(self.machine_forms(laptop, "local"))
        self.deny_rows([self.bash_row(c) for c in [
            self.sh("wait", "T004", "--beat", laptop + "/beat"),
            self.sh("answer", "T004", "--screen", "h1", "--record", laptop + "/record.tsv", "--keys", "2"),
        ]])
        for machine in ("a.b", "a_b", "-ab", "a" * 26):
            folder = self.mon_dir("t004", "M2", owner=ID_A, machine=machine)
            with self.subTest(machine=machine):
                self.deny_rows(self.machine_forms(folder, machine))
        empty = self.mon_dir("t004", "M3", owner=ID_A, machine="")
        self.deny_rows(self.machine_forms(empty, "''"))
        self.deny_rows(self.machine_forms(self.A, "''"))
        old = os.path.join(self.tmp, "monitor-t004-" + ("O1" + "k" * 16)[:16])
        write(os.path.join(old, "beat"))
        write(os.path.join(old, "owner"), ID_A)
        self.deny_rows(self.forms(old, "T004"))

    def test_monitor_allows_a_folder_under_a_symlinked_parent(self):
        self.monitors()
        real = os.path.join(self.tmp, "real")
        os.makedirs(real)
        os.symlink(real, os.path.join(self.tmp, "link"))
        folder = self.mon_dir("t004", "P2", owner=ID_A, parent=real)
        via = os.path.join(self.tmp, "link", os.path.basename(folder))
        for label, tool, tool_input in self.forms(via, "T004"):
            with self.subTest(label):
                self.assertSilent(self.monitor(tool, tool_input))

    def test_monitor_denies_fr010_end_of_a_worker(self):
        self.monitors()
        self.deny_rows([self.bash_row(c) for c in [
            self.sh("result", "T004"), self.sh("followup", "T004", "--task", "t"), self.sh("close", "T004"),
            "git merge b", "gh pr merge 1",
        ]] + [
            ("Write tasks.md", "Write", {"file_path": os.path.join(self.root, "specs", "x", "tasks.md"), "content": "x"}),
            ("Read result.md", "Read", {"file_path": os.path.join(self.tmp, "wt", "result.md")}),
            ("Read result-round2.md", "Read", {"file_path": os.path.join(self.tmp, "wt", "result-round2.md")}),
        ])

    def test_monitor_denies_a_result_read_with_end_space_or_any_case(self):
        self.monitors()
        wt = os.path.join(self.tmp, "wt")
        self.deny_rows([("Read " + repr(name), "Read", {"file_path": wt + "/" + name})
                        for name in ("result.md ", "result.md\n", "Result.md", "RESULT-ROUND2.MD")])

    def test_monitor_denies_fr013_control_commands(self):
        self.monitors()
        self.deny_rows([self.bash_row(self.sh(sub, "T004")) for sub in
                        ("start", "goal", "autonomous-on", "autonomous-off", "watch", "list", "headless")]
                       + [self.bash_row(self.sh("close", "T004", "--record", self.A + "/record.tsv")),
                          self.bash_row(self.sh("start", "T004", "--beat", self.A + "/beat"))])

    def test_monitor_denies_fr014_paths_and_tools(self):
        self.monitors()
        no_beat = self.mon_dir("t004", "C1", beat=False)
        sym_record = self.mon_dir("t004", "D1", owner=ID_A)
        write(os.path.join(self.tmp, "record-target"))
        os.symlink(os.path.join(self.tmp, "record-target"), os.path.join(sym_record, "record.tsv"))
        sym_beat = self.mon_dir("t004", "T1", beat=False, owner=ID_A)
        write(os.path.join(self.tmp, "beat-target"))
        os.symlink(os.path.join(self.tmp, "beat-target"), os.path.join(sym_beat, "beat"))
        sym_folder = os.path.join(self.tmp, "monitor-local-t004-" + ("S1" + "k" * 16)[:16])
        os.symlink(self.A, sym_folder)
        in_tree = self.mon_dir("t004", "G1", owner=ID_A, parent=self.root)
        os.makedirs(os.path.join(self.tmp, "y", "z"))
        os.symlink(os.path.join(self.tmp, "y", "z"), os.path.join(self.tmp, "x"))
        self.mon_dir("t004", "A1", owner=ID_A, parent=os.path.join(self.tmp, "y"))
        os.makedirs(os.path.join(self.tmp, "q"))
        write(os.path.join(self.tmp, "monitor-local-t005", "beat"))
        keyless = os.path.join(self.tmp, "monitor-local-t004")
        write(os.path.join(keyless, "beat"))
        short = os.path.join(self.tmp, "monitor-local-t004-short")
        write(os.path.join(short, "beat"))
        write(os.path.join(self.tmp, "anyname", "beat"))
        os.symlink(os.path.join(self.tmp, "spec-target"), os.path.join(self.A, "spec.md"))
        os.symlink(os.path.join(self.tmp, "spec-target"), os.path.join(self.A, "views-1.md"))
        name_a = os.path.basename(self.A)
        answer = lambda record: self.sh("answer", "T004", "--screen", "h1", "--record", record)
        rows = [self.bash_row(c) for c in [
            "bash -c 'echo x > f'", "cp a b",
            answer(os.path.expanduser("~/.bashrc")),
            answer(os.path.join(self.tmp, "monitor-local-t005", "record.tsv")),
            self.sh("wait", "T004", "--beat", self.A + "/other"),
            self.sh("wait", "T004", "--beat", no_beat + "/beat"),
            answer(no_beat + "/record.tsv"),
            answer(sym_record + "/record.tsv"),
            self.sh("wait", "T004", "--beat", sym_beat + "/beat"),
            self.sh("wait", "T004", "--beat", sym_folder + "/beat"),
            answer(sym_folder + "/record.tsv"),
            self.sh("wait", "T004", "--beat", in_tree + "/beat"),
            self.sh("wait", "T004", "--beat", keyless + "/beat"),
            self.sh("wait", "T004", "--beat", short + "/beat"),
            answer(keyless + "/record.tsv"),
            f"bash {self.root}/scripts/st-worker.sh wait T004 --beat {self.A}/beat",
        ]] + [
            ("Write symlinked spec.md", "Write", {"file_path": self.A + "/spec.md", "content": "x"}),
            ("Write symlinked views-1.md", "Write", {"file_path": self.A + "/views-1.md", "content": "x"}),
            ("Write anyname spec.md", "Write", {"file_path": os.path.join(self.tmp, "anyname", "spec.md"), "content": "x"}),
            ("Write repo a.txt", "Write", {"file_path": os.path.join(self.root, "a.txt"), "content": "x"}),
            ("Write settings.json", "Write", {"file_path": os.path.expanduser("~/.claude/settings.json"), "content": "x"}),
            ("Write A/x.sh", "Write", {"file_path": self.A + "/x.sh", "content": "x"}),
            ("Write no-beat spec.md", "Write", {"file_path": no_beat + "/spec.md", "content": "x"}),
            ("Write symlinked folder views-2.md", "Write", {"file_path": sym_folder + "/views-2.md", "content": "x"}),
            ("Write in-tree spec.md", "Write", {"file_path": in_tree + "/spec.md", "content": "x"}),
            ("Edit A/spec.md", "Edit", {"file_path": self.A + "/spec.md", "old_string": "a", "new_string": "b"}),
            ("MultiEdit A/spec.md", "MultiEdit", {"file_path": self.A + "/spec.md", "edits": []}),
            ("NotebookEdit A/n.ipynb", "NotebookEdit", {"notebook_path": self.A + "/spec.md", "new_source": "x"}),
            ("Grep", "Grep", {"pattern": "x", "path": self.A}),
            ("Glob", "Glob", {"pattern": "*", "path": self.A}),
            ("Write relative", "Write", {"file_path": name_a + "/views-2.md", "content": "x"}, self.tmp),
            self.bash_row(answer(name_a + "/record.tsv")) + (self.tmp,),
            self.bash_row(self.sh("wait", "T004", "--beat", name_a + "/beat")) + (self.tmp,),
            self.bash_row(answer(os.path.join(self.tmp, "x", "..", name_a, "record.tsv"))),
            self.bash_row(self.sh("wait", "T004", "--beat", os.path.join(self.tmp, "x", "..", name_a, "beat"))),
            self.bash_row(self.sh("wait", "T004", "--beat", os.path.join(self.tmp, "q", "..", name_a, "beat"))),
            self.bash_row(self.sh("wait", "T004", "--beat", os.path.join(self.tmp, ".", name_a, "beat"))),
            self.bash_row(answer(os.path.join(self.tmp, ".", name_a, "record.tsv"))),
        ]
        self.deny_rows(rows)

    def test_monitor_denies_a_doubled_slash_in_a_path(self):
        self.monitors()
        self.deny_rows([
            ("Write A//spec.md", "Write", {"file_path": self.A + "//spec.md", "content": "x"}),
            self.bash_row(self.sh("answer", "T004", "--screen", "h1", "--record", self.A + "//record.tsv")),
        ])

    def test_monitor_denies_fr015_other_advisor_points_and_scripts(self):
        self.monitors()
        self.deny_rows([self.bash_row(f"bash {ADVISOR_SH} {point} x") for point in
                        ("review", "diff", "plan", "change", "test")]
                       + [self.bash_row(f"bash {LOCK_SH} -- true"), self.bash_row("bash tests/x.sh")])

    def test_monitor_denies_fr007_missing_required_flags(self):
        self.monitors()
        record = self.A + "/record.tsv"
        self.deny_rows([self.bash_row(c) for c in [
            self.sh("answer", "T004", "--record", record),
            self.sh("answer", "T004", "--screen", "h1"),
            self.sh("answer", "T004"),
            self.sh("approve", "T004", "--request", "1-1"),
            self.sh("resend", "T004"),
            self.sh("pass", "T004", "--request", "1-1"),
            self.sh("wait", "T004"),
            self.sh("answer", "T004", "--screen", "h1", "--text", "--record", record),
            self.sh("answer", "T004", "--text", "--screen", "--record", record),
            self.sh("wait", "T004", "--machine", "--beat", self.A + "/beat"),
            self.sh("pass", "T004", "--machine", "--record", record, "--request", "1-1"),
            self.sh("pass", "T004", "--request", "1-1", "--machine", "--record", record),
            self.sh("pass", "T004", "--request", "1-1", "x", "--record", record),
            self.sh("pass", "T004", "--request", "--record", record, "1-1"),
            self.sh("answer", "T004", "--screen", "h1", "--keys", "1", "--record", record),
            self.sh("answer", "T004", "--record", record, "--keys", "1", "--screen", "h1"),
            self.sh("wait", "T004", "--keys", "--beat", self.A + "/beat"),
            self.sh("pass", "T004", "--request", "1-1", "--beat", self.A + "/beat"),
            self.sh("approve", "T004", "--request", "1-1", "--input-hash", "a" * 64, "--beat", self.A + "/beat"),
            self.sh("resend", "T004", "--beat", self.A + "/beat"),
            self.sh("answer", "T004", "--screen", "h1", "--beat", self.A + "/beat", "--keys", "1"),
        ]])

    def test_monitor_denies_shell_operators_and_unparsable_input(self):
        self.monitors()
        base = self.sh("wait", "T004", "--beat", self.A + "/beat")
        self.deny_rows([self.bash_row(base + tail) for tail in (" ; echo x", " | cat", " $(echo x)", "\necho x",
                                                          " & touch x", " > out", " < in", " `id`", " ( true )",
                                                          " #x", " --machine {a,b}", "\r", " --machine a\x01b",
                                                          " --machine a\x7fb")])
        self.deny_rows([self.bash_row(base.replace(" --beat", "\t--beat"))])
        answer = self.sh("answer", "T004", "--screen", "h1", "--record", self.A + "/record.tsv", "--text")
        self.deny_rows([self.bash_row(answer + text) for text in (' "see #51"', ' "a (b)"')])
        self.deny_rows([self.bash_row(base + " '")])
        self.deny_rows([("tool_input is a string", "Bash", "x"), ("command is a list", "Bash", {"command": ["a"]})])

    def test_monitor_denies_a_character_outside_the_command_set(self):
        self.monitors()
        base = self.sh("wait", "T004", "--beat", self.A + "/beat")
        self.deny_rows([self.bash_row(base + tail) for tail in (
            " --machine m*", " --machine m?", " --machine [m]", " --machine ~m", " --machine m!", " --machine é",
            " --machine a\\b")])
        self.deny_rows([self.bash_row(self.sh("answer", "T004", "--screen", "h1", "--record", self.A + "/record.tsv",
                                              "--text", '"x?"'))])
        write(os.path.join(self.plain, "--beat"))
        self.deny_rows([self.bash_row(base + " --machine m --b* " + self.tmp + "/x")])

    def test_monitor_denies_another_agents_folder(self):
        self.monitors()
        self.deny_rows(self.forms(self.B, "T005"), MONITOR_OWNER_REASON, agent_id=ID_A)

    def test_monitor_other_denies_keep_the_general_reason(self):
        self.monitors()
        self.deny_rows([self.bash_row(c) for c in [
            f"bash {WORKER_SH} list",
            self.sh("answer", "T004", "--record", self.A + "/record.tsv"),
            self.sh("answer", "T004", "--screen", "h1", "--record", self.A + "/record.tsv", "--text", '"see #51"'),
        ]])
        fresh = self.mon_dir("t004", "F2")
        self.deny_rows([self.bash_row(self.sh("answer", "T004", "--record", fresh + "/record.tsv"))],
                       agent_id="a5555555555555555")
        self.assertFalse(os.path.lexists(os.path.join(fresh, "owner")), "owner was made")

    def test_monitor_denies_a_call_with_no_agent_id_or_an_empty_one(self):
        self.monitors(owner_a="")
        for label, agent_id in (("no agent_id", None), ("empty agent_id", "")):
            with self.subTest(label):
                self.deny_rows(self.forms(self.A, "T004"), agent_id=agent_id)

    def test_monitor_denies_a_symlinked_owner(self):
        self.monitors()
        folder = self.mon_dir("t004", "E1")
        write(os.path.join(self.tmp, "owner-target"), ID_A)
        os.symlink(os.path.join(self.tmp, "owner-target"), os.path.join(folder, "owner"))
        self.deny_rows(self.forms(folder, "T004"))

    def test_monitor_compares_the_owner_as_exact_bytes(self):
        self.monitors(owner_a=ID_A + "\n")
        self.deny_rows(self.forms(self.A, "T004"), MONITOR_OWNER_REASON)
        write(os.path.join(self.A, "owner"), ID_A)
        for agent_id in (" " + ID_A, ID_A + " "):
            with self.subTest(agent_id=agent_id):
                self.deny_rows(self.forms(self.A, "T004"), MONITOR_OWNER_REASON, agent_id=agent_id)

    def test_monitor_denies_worker_id_and_record_mismatch(self):
        self.monitors()
        self.deny_rows([self.bash_row(c) for c in [
            self.sh("pass", "T004", "--request", "1-1"),
            self.sh("wait", "T005", "--beat", self.A + "/beat"),
            self.sh("answer", "T005", "--screen", "h1", "--record", self.A + "/record.tsv"),
        ]])
        dot = self.mon_dir("t.4", "D2", owner=ID_A)
        long = self.mon_dir("a" * 26, "L1", owner=ID_A)
        upper = self.mon_dir("T004", "U1", owner=ID_A)
        under = self.mon_dir("t_04", "G4", owner=ID_A)
        self.deny_rows([self.bash_row(c) for c in [
            self.sh("wait", "t.4", "--beat", dot + "/beat"),
            self.sh("wait", "a" * 26, "--beat", long + "/beat"),
            self.sh("wait", "T004", "--beat", upper + "/beat"),
            self.sh("wait", "t_04", "--beat", under + "/beat"),
        ]] + [
            ("Write spec.md in monitor-t.4", "Write", {"file_path": dot + "/spec.md", "content": "x"}),
            ("Write spec.md in monitor-T004", "Write", {"file_path": upper + "/spec.md", "content": "x"}),
        ])

    def test_monitor_denies_a_revoked_folder_of_any_kind(self):
        self.monitors()
        write(os.path.join(self.tmp, "revoked-target"))
        makers = [
            ("file", write),
            ("folder", os.makedirs),
            ("broken symlink", lambda p: os.symlink(os.path.join(self.tmp, "nothing"), p)),
            ("symlink to a file", lambda p: os.symlink(os.path.join(self.tmp, "revoked-target"), p)),
        ]
        for i, (kind, make) in enumerate(makers):
            folder = self.mon_dir("t004", f"Rv{i}", owner=ID_A)
            make(os.path.join(folder, "revoked"))
            with self.subTest(kind):
                self.deny_rows(self.forms(folder, "T004"))

    def test_monitor_denies_a_flag_given_twice(self):
        self.monitors()
        a, b = self.A, self.B
        self.deny_rows([self.bash_row(c) for c in [
            self.sh("wait", "T004", "--beat", a + "/beat", "--beat", b + "/beat"),
            self.sh("answer", "T004", "--screen", "h1", "--record", a + "/record.tsv", "--record", b + "/record.tsv"),
            self.sh("answer", "T004", "--screen", "h1", "--screen", "h2", "--record", a + "/record.tsv"),
            self.sh("wait", "T004", "--beat", a + "/beat", "--machine", "m1", "--machine", "m2"),
            self.sh("pass", "T004", "--request", "1-1", "--request", "1-2", "--record", a + "/record.tsv"),
            self.sh("wait", "T004", "--beat", b + "/beat", "--beat", a + "/beat"),
            self.sh("answer", "T004", "--screen", "h1", "--record", b + "/record.tsv", "--record", a + "/record.tsv"),
        ]])

    def test_monitor_denies_an_agent_id_with_a_control_character(self):
        self.monitors()
        for label, bad in (("newline", "a0123\n456"), ("other control", "a01\x01zz"), ("delete", "a01\x7fzz")):
            write(os.path.join(self.A, "owner"), bad)
            with self.subTest(label):
                self.deny_rows(self.forms(self.A, "T004"), agent_id=bad)
        write(os.path.join(self.A, "owner"), ID_A)
        with self.subTest("trailing newline"):
            self.deny_rows(self.forms(self.A, "T004"), agent_id=ID_A + "\n")

    def test_monitor_leaves_no_owner_after_a_deny(self):
        self.monitors()
        with_beat = self.mon_dir("t004", "N1")
        no_beat = self.mon_dir("t004", "N2", beat=False)
        with self.subTest("; on a folder with beat and no owner"):
            self.assertMonitorDeny(self.monitor("Bash", {"command": self.sh(
                "wait", "T004", "--beat", with_beat + "/beat") + " ; true"}))
            self.assertFalse(os.path.lexists(os.path.join(with_beat, "owner")), "owner was made")
        with self.subTest("folder with no beat"):
            self.assertMonitorDeny(self.monitor("Bash", {"command": self.sh("wait", "T004", "--beat", no_beat + "/beat")}))
            self.assertFalse(os.path.lexists(os.path.join(no_beat, "owner")), "owner was made")
        sym_beat = self.mon_dir("t004", "N4", beat=False)
        write(os.path.join(self.tmp, "beat-target"))
        os.symlink(os.path.join(self.tmp, "beat-target"), os.path.join(sym_beat, "beat"))
        for label, tool, tool_input in [
            self.bash_row(self.sh("answer", "T004", "--screen", "h1", "--record", sym_beat + "/record.tsv")),
            ("Write spec.md", "Write", {"file_path": sym_beat + "/spec.md", "content": "x"}),
        ]:
            with self.subTest("beat is a symlink: " + label):
                self.assertMonitorDeny(self.monitor(tool, tool_input))
                self.assertFalse(os.path.lexists(os.path.join(sym_beat, "owner")), "owner was made")

    def test_monitor_fails_closed_when_lock2_raises(self):
        self.monitors()
        with self.subTest("monitor"):
            self.assertMonitorDeny(self.monitor("Bash", ["x"], cwd=self.root))
        with self.subTest("st-build"):
            self.assertSilent(self.monitor("Bash", ["x"], cwd=self.root, agent_type="stratum:st-build"))

    def test_lock2_reason_stands_for_a_monitor_in_a_worker_session(self):
        self.monitors()
        folder = self.mon_dir("x", "F1")
        command = {"command": self.sh("wait", "x", "--beat", folder + "/beat")}
        for label, agent_type in (("st-monitor", MONITOR), ("st-build", "stratum:st-build"), ("no agent_type", None)):
            with self.subTest(label):
                self.assertDenied(self.monitor("Bash", command, cwd=self.root, agent_type=agent_type,
                                               agent_id=None if agent_type is None else ID_A))
                self.assertFalse(os.path.lexists(os.path.join(folder, "owner")), "monitor rule was reached")

    def rnd(self, folder, views=None, rnd="1", point="decisions", env="HERDR_ENV=0", extra=""):
        views = views if views is not None else os.path.join(folder, "views-1.md")
        return " ".join(w for w in (env, "bash", ADVISOR_SH, "round", point, folder, rnd, views, extra) if w)

    def test_monitor_allows_the_round_call_on_its_own_folder(self):
        self.monitors()
        self.assertSilent(self.monitor("Bash", {"command": self.rnd(self.A)}))

    def test_monitor_denies_the_round_call_on_another_agents_folder(self):
        self.monitors()
        self.assertMonitorDeny(self.monitor("Bash", {"command": self.rnd(self.B)}, agent_id=ID_A), MONITOR_OWNER_REASON)

    def test_monitor_denies_other_forms_of_the_round_call(self):
        self.monitors()
        no_beat = self.mon_dir("t004", "N3", beat=False, owner=ID_A)
        in_tree = self.mon_dir("t004", "G2", owner=ID_A, parent=self.root)
        a = self.A
        self.deny_rows([self.bash_row(c) for c in [
            self.rnd(a, rnd="2"),
            self.rnd(a, rnd="3"),
            self.rnd(a, point="plan"),
            self.rnd(a, env=""),
            self.rnd(a, env="HERDR_ENV=1"),
            self.rnd(no_beat),
            self.rnd(in_tree),
            self.rnd(a, views=a + "/spec.md"),
            self.rnd(a, views=a + "/views-x.md"),
            self.rnd(a, views=a + "/views-1.md.bak"),
            self.rnd(a, views=a + "/sub/views-1.md"),
            self.rnd(a, extra="extra"),
            self.rnd(self.B, views=a + "/views-1.md"),
            self.rnd(self.plain, views=a + "/views-1.md"),
            self.rnd(self.root, views=a + "/views-1.md"),
            self.rnd(a + "/", views=a + "/views-1.md"),
            f"bash {ADVISOR_SH} review main",
            f"HERDR_ENV=0 bash {ADVISOR_SH} review main",
        ]])

    def test_monitor_denies_the_round_call_with_a_shell_character(self):
        self.monitors()
        a = self.A
        scripts = os.path.dirname(ADVISOR_SH)
        good = self.rnd(a)
        self.deny_rows([self.bash_row(c) for c in [
            good.replace(scripts + "/", scripts + "/$(id)/../"),
            good.replace(" " + a + "/views-1.md", "\n" + a + "/views-1.md"),
            good.replace(" round ", " round; "),
            good.replace(" round ", " round & "),
            good.replace(" round ", " round | "),
            good.replace(" round ", " round `id` "),
        ]])

    def test_monitor_denies_the_round_call_with_no_agent_id_or_an_empty_one(self):
        self.monitors(owner_a="")
        for label, agent_id in (("no agent_id", None), ("empty agent_id", "")):
            with self.subTest(label):
                self.deny_rows([self.bash_row(self.rnd(self.A))], agent_id=agent_id)

    def test_monitor_denies_the_round_call_on_a_symlinked_owner(self):
        self.monitors()
        folder = self.mon_dir("t004", "E2")
        write(os.path.join(self.tmp, "owner-target"), ID_A)
        os.symlink(os.path.join(self.tmp, "owner-target"), os.path.join(folder, "owner"))
        self.deny_rows([self.bash_row(self.rnd(folder))])

    def test_monitor_denies_the_round_call_on_a_revoked_folder(self):
        self.monitors()
        write(os.path.join(self.A, "revoked"))
        self.deny_rows([self.bash_row(self.rnd(self.A))])

    def never(self, text, hook=HOOK):
        self.assertTrue(os.path.isfile(hook), "hooks/st-approve.py does not exist yet")
        return subprocess.run([sys.executable, hook, "--never"], input=text.encode(), capture_output=True,
                              timeout=20).returncode

    def test_never_exits_0_on_the_never_list(self):
        clean = "bash tests/test_x.sh"
        for text in ("git push origin x", "cat .env", "curl https://x", "git pu'sh' origin x",
                     f"bash {LOCK_SH} -- git push origin x", "x && git\n  push origin x", "git \\\n  push origin x",
                     "git -C /home/u/Desktop/a-long-project-name/repo-t004\n  push origin worker-t004",
                     "git reset \\\n  --hard HEAD~3", "git pu\nsh origin x",
                     "─" * 40 + "\n Bash command\n\n   cat /home/u/Desktop/stratum-t004/specs/022-worker-monitors/"
                     "contracts/../../.en\n   v.local\n   Show the local settings\n\n Do you want to proceed?\n"
                     " ❯ 1. Yes\n   2. No\n"):
            with self.subTest(text=text):
                self.assertEqual((self.never(text), self.never(clean)), (0, 4))

    def test_never_exits_4_when_clean(self):
        for text in ("bash tests/test_x.sh", f"bash {LOCK_SH} -- bash tests/test_x.sh",
                     "Bash command\n  bash tests/test_x.sh\n  Run the tests\nDo you want to proceed?\n❯ 1. Yes\n  2. No",
                     "Rule Bash(test -f specs/022-worker-monitors/probe.txt) from user settings overrides auto mode.\n"
                     "Bash command\n  test -f specs/022-worker-monitors/probe.txt\n  Check the probe file\n"
                     "Do you want to proceed?\n❯ 1. Yes\n  2. No"):
            with self.subTest(text=text):
                self.assertEqual(self.never(text), 4)

    def test_never_strips_a_plugin_root_under_dot_claude(self):
        copy = os.path.join(self.tmp, ".claude", "plug", "hooks", "st-approve.py")
        os.makedirs(os.path.dirname(copy))
        shutil.copy(HOOK, copy)
        lock = os.path.join(self.tmp, ".claude", "plug", "scripts", "st-lock.sh")
        self.assertEqual(self.never(f"bash {lock} -- bash tests/test_x.sh", hook=copy), 4)


if __name__ == "__main__":
    unittest.main()
