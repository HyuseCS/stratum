import collections
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(PLUGIN, "hooks", "st-approve.py")
ALLOW = '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
DENY_REASON = ".stratum/approve/ and .stratum/autonomous are written only by the orchestrator."
CMD = 'python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-approve.py"'
MATCHER = "Bash|Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Glob"
RID_FILE = re.compile(r"[0-9]+-[0-9]+\.(req|ok|user)")
RID_REQ = r"^[0-9]+-[0-9]+\.req$"
Run = collections.namedtuple("Run", "rc out err reqs leftover")

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
]

OWN_COMMITS = [
    "git commit -m x -- src/a.py",
    'git add src/a.py && git commit -m "demo heredoc"',
    "\n".join(['git add src/a.py && git commit -m "$(cat <<\'EOF\'', "a message", "EOF", ')"']),
    "git add src/a.py && git commit -m x > log.txt",
    "git add src/a.py && git commit -m x 2>&1",
    'git add src/a.py && git commit -m "explain git guard"',
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
]

LOCK2_WORKER_CALLS = [
    "bash scripts/st-worker.sh approve worker-t1 --request 1-1 --input-stdin --record r",
    "st-worker.sh pass worker-t1 --request 1-1",
    "st-worker.sh autonomous-off --roster r",
    "bash scripts/st-worker.sh $'approve' worker-t1",
    'bash scripts/st-worker.sh "pass" worker-t1',
    "st-worker.sh wait worker-b",
    "st-worker.sh start t9 --autonomous",
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
        write(os.path.join(self.stratum, "autonomous"), "S1\n")
        self.make_approve(self.root)

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
        remove(os.path.join(self.stratum, "autonomous"))
        self.assertSilent(self.bash("bash tests/x.sh"))

    def test_a2_session_id_differs(self):
        write(os.path.join(self.approve, "session"), "S2\n")
        self.assertSilent(self.bash("bash tests/x.sh"))

    def test_a3_stop_autonomous_after_a_round(self):
        self.assertSent(self.bash("bash tests/x.sh"))
        remove(os.path.join(self.stratum, "autonomous"))
        self.assertSilent(self.bash("bash tests/y.sh"))

    def test_a4_linked_worktree_with_its_own_flag(self):
        remove(os.path.join(self.stratum, "autonomous"))
        wt = self.make_worker()
        write(os.path.join(wt, ".stratum", "autonomous"), "S1\n")
        self.assertSilent(self.bash("bash tests/x.sh", cwd=wt))

    def test_a5_empty_first_lines(self):
        write(os.path.join(self.stratum, "autonomous"), "\n")
        write(os.path.join(self.approve, "session"), "\n")
        self.assertSilent(self.bash("bash tests/x.sh"))

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
        with self.subTest("heredoc with it's and a git commit last"):
            command = "cat > notes.txt <<'EOF'\nit's a note\nEOF\ngit commit -m x"
            req = self.assertSent(self.bash(command))
            self.assertEqual(req["tool_input"], {"command": command})

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
            self.assertSilent(self.pre("Edit", {"file_path": "src/a.py", "old_string": "a", "new_string": "b"}, br))
            self.assertSilent(self.pre_bash("bash tests/x.sh", cwd=br))

    def test_orchestrator_session_is_silent(self):
        demo = self.make_branch_repo("demo", "010-demo")
        self.assertSilent(self.pre_bash(
            "bash scripts/st-worker.sh approve worker-t1 --request 1-1 --input-stdin --record r", cwd=demo))
        self.assertSilent(self.pre_bash("printf S1 > .stratum/autonomous", cwd=demo))


if __name__ == "__main__":
    unittest.main()
