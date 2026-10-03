import json
import os
import subprocess
import sys
import tempfile
import unittest

GUARD = os.environ.get("ST_GIT_GUARD") or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "hooks", "st-git-guard.py")


class GitGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = self.tmp.name
        sub = os.path.join(self.repo, "sub")
        os.makedirs(os.path.join(sub, "src"))
        for d in (self.repo, sub):
            subprocess.run(["git", "init", "-q", d], check=True)
        with open(os.path.join(sub, "src", "a.txt"), "w") as f:
            f.write("hi\n")
        subprocess.run(["git", "-C", sub, "add", "src/a.txt"], check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def set_mode(self, mode):
        os.makedirs(os.path.join(self.repo, ".stratum"), exist_ok=True)
        with open(os.path.join(self.repo, ".stratum", "commit-mode"), "w") as f:
            f.write(mode + "\n")

    def run_guard(self, command):
        env = {**os.environ, "CLAUDE_PROJECT_DIR": self.repo}
        payload = json.dumps({"tool_name": "Bash", "cwd": self.repo,
                              "tool_input": {"command": command}})
        r = subprocess.run([sys.executable, GUARD], input=payload, env=env,
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        if not r.stdout.strip():
            return None, ""
        out = json.loads(r.stdout)["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], "PreToolUse")
        return out["permissionDecision"], out["permissionDecisionReason"]

    def test_commit_auto(self):
        self.set_mode("auto")
        self.assertEqual(self.run_guard("git commit -m x"), (None, ""))

    def test_commit_ask(self):
        self.set_mode("ask")
        self.assertEqual(self.run_guard("git commit -m x")[0], "ask")

    def test_commit_deny(self):
        self.set_mode("deny")
        self.assertEqual(self.run_guard("git commit -m x")[0], "deny")

    def test_commit_missing_mode(self):
        self.assertEqual(self.run_guard("git commit -m x")[0], "ask")

    def test_commit_invalid_mode(self):
        self.set_mode("yolo")
        self.assertEqual(self.run_guard("git commit -m x")[0], "ask")

    def test_commit_amend_asks_in_auto(self):
        self.set_mode("auto")
        self.assertEqual(self.run_guard("git commit --amend --no-edit")[0], "ask")

    def test_push(self):
        d, reason = self.run_guard("git push origin main")
        self.assertEqual(d, "ask")
        self.assertNotIn("DESTRUCTIVE", reason)

    def test_push_force(self):
        for cmd in ("git push --force", "git push -f origin x", "git push --force-with-lease"):
            d, reason = self.run_guard(cmd)
            self.assertEqual(d, "ask", cmd)
            self.assertIn("DESTRUCTIVE", reason, cmd)

    def test_add_all_denied(self):
        for cmd in ("git add -A", "git add --all", "git add .", "git add -Av"):
            self.assertEqual(self.run_guard(cmd)[0], "deny", cmd)

    def test_add_exact_path(self):
        self.assertEqual(self.run_guard("git add src/a.txt"), (None, ""))

    def test_no_verify(self):
        self.set_mode("auto")
        self.assertEqual(self.run_guard("git commit --no-verify -m x")[0], "deny")

    def test_config_write_denied_read_allowed(self):
        self.assertEqual(self.run_guard("git config user.name x")[0], "deny")
        self.assertEqual(self.run_guard("git config --global --unset user.name")[0], "deny")
        self.assertEqual(self.run_guard("git config user.name"), (None, ""))
        self.assertEqual(self.run_guard("git config --get user.email"), (None, ""))

    def test_destructive_asks(self):
        for cmd in ("git reset --hard HEAD~1", "git clean -fd", "git checkout -- .",
                    "git restore .", "git branch -D old", "git rebase main"):
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)

    def test_chained(self):
        self.set_mode("deny")
        self.assertEqual(self.run_guard("echo hi && git commit -m x")[0], "deny")
        self.assertEqual(self.run_guard("ls; git add -A || true")[0], "deny")
        self.assertEqual(self.run_guard("git status | cat")[0], None)

    def test_dash_c_commit_summary(self):
        d, reason = self.run_guard("git -C sub commit -m x")
        self.assertEqual(d, "ask")
        self.assertIn("src/a.txt", reason)
        self.assertIn("1 file changed", reason)

    def test_non_git(self):
        self.assertEqual(self.run_guard("ls -la && echo 'git add -A'"), (None, ""))

    def test_quoted_message_not_split(self):
        self.set_mode("auto")
        self.assertEqual(self.run_guard('git commit -m "a && git push"'), (None, ""))


if __name__ == "__main__":
    unittest.main()
