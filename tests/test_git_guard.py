import json
import os
import shlex
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

    options = {}

    def set_mode(self, mode, key="commit"):
        self.options = {**self.options, f"CLAUDE_PLUGIN_OPTION_{key.upper()}": mode}

    def run_guard(self, command):
        env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE_PLUGIN_OPTION_")}
        env.update(self.options)
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

    def write_guard_file(self, text, where=None):
        d = os.path.join(where or self.repo, ".stratum")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "git-guard.json"), "w") as f:
            f.write(text)

    def test_repo_file_beats_plugin_option(self):
        self.set_mode("auto")
        self.write_guard_file('{"commit": "deny"}')
        self.assertEqual(self.run_guard("git commit -m x")[0], "deny")

    def test_repo_file_found_from_subfolder(self):
        self.set_mode("auto")
        self.write_guard_file('{"commit": "deny"}')
        self.repo = os.path.join(self.repo, "deep", "er")
        os.makedirs(self.repo)
        self.assertEqual(self.run_guard("git commit -m x")[0], "deny")

    def test_repo_file_bad_value_falls_back(self):
        self.set_mode("auto")
        self.write_guard_file('{"commit": "maybe"}')
        self.assertEqual(self.run_guard("git commit -m x"), (None, ""))
        self.write_guard_file('not json')
        self.assertEqual(self.run_guard("git commit -m x"), (None, ""))

    def test_commit_invalid_mode(self):
        self.set_mode("yolo")
        self.assertEqual(self.run_guard("git commit -m x")[0], "ask")

    def test_commit_amend_asks_in_auto(self):
        self.set_mode("auto")
        self.assertEqual(self.run_guard("git commit --amend --no-edit")[0], "ask")

    def test_commit_auto_only_in_session_folder(self):
        self.write_guard_file('{"commit":"auto"}')
        self.assertEqual(self.run_guard("git commit -m x"), (None, ""))
        for cmd in ("git -C /other/repo commit -m x", "git -C/other/repo commit -m x",
                    "cd /other && git commit -m x", "git commit --amend"):
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)

    def test_commit_auto_elsewhere_forms(self):
        self.write_guard_file('{"commit":"auto"}')
        self.assertEqual(self.run_guard("git commit -m x"), (None, ""))
        for cmd in ("git --git-dir /x commit -m x", "git --git-dir=/x commit -m x",
                    "git --work-tree /x commit -m x", "git --work-tree=/x commit -m x",
                    "GIT_DIR=/x git commit -m x", "GIT_WORK_TREE=/x git commit -m x",
                    "pushd /x && git commit -m x"):
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)

    def test_commit_auto_same_checkout_paths(self):
        self.write_guard_file('{"commit":"auto"}')
        os.makedirs(os.path.join(self.repo, "deep"))
        with tempfile.TemporaryDirectory() as other:
            subprocess.run(["git", "init", "-q", other], check=True)
            r, o = shlex.quote(self.repo), shlex.quote(other)
            for cmd in (f"cd {r} && git commit -m x", f"git -C {r} commit -m x",
                        f"cd {r}/deep && git commit -m x", f"pushd {r} && git commit -m x"):
                self.assertEqual(self.run_guard(cmd), (None, ""), cmd)
            for cmd in (f"cd {o} && git commit -m x", f"git -C {o} commit -m x",
                        "cd $X && git commit -m x", f"cd {r}/sub && git commit -m x",
                        f"cd {r} && git -C {o} merge b"):
                self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)

    def test_merge_elsewhere_asks(self):
        self.write_guard_file('{"commit":"auto"}')
        for cmd in ("git merge b", "git pull"):
            self.assertEqual(self.run_guard(cmd), (None, ""), cmd)
        for cmd in ("git -C /x merge b", "cd /x && git merge b", "GIT_DIR=/x git merge b",
                    "git -C /x pull", "git -C /x cherry-pick c", "git -C /x revert c",
                    "git -C /x am p"):
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)

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

    def test_local_branch_and_worktree_delete_asks(self):
        for cmd in ("git branch -d old", "git branch --delete old", "git branch -D old",
                    "git worktree remove ../wt", "git worktree prune"):
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)
        self.assertEqual(self.run_guard("git worktree list"), (None, ""))
        self.assertEqual(self.run_guard("git branch -a"), (None, ""))

    DESTRUCTIVE = {"reset_hard": "git reset --hard HEAD~1", "clean": "git clean -fd",
                   "discard": "git restore .", "branch_delete": "git branch -D old",
                   "worktree_remove": "git worktree remove ../wt",
                   "worktree_prune": "git worktree prune", "force_push": "git push --force"}

    def test_destructive_per_command(self):
        for key, cmd in self.DESTRUCTIVE.items():
            for m, want in (("auto", None), ("deny", "deny"), ("ask", "ask"), ("yolo", "ask")):
                self.options = {}
                self.set_mode(m, key)
                self.assertEqual(self.run_guard(cmd)[0], want, (key, m))
            others = [c for k, c in self.DESTRUCTIVE.items() if k != key]
            self.set_mode("auto", key)
            for c in others:
                self.assertEqual(self.run_guard(c)[0], "ask", (key, c))
        self.options = {}

    def test_auto_keeps_fixed_rules(self):
        for key in self.DESTRUCTIVE:
            self.set_mode("auto", key)
        self.assertEqual(self.run_guard("git rebase main")[0], "ask")
        self.assertEqual(self.run_guard("git push origin main")[0], "ask")
        self.assertEqual(self.run_guard("git push origin --delete old")[0], "deny")

    def test_remote_branch_delete_denied(self):
        for cmd in ("git push origin --delete old", "git push -d origin old",
                    "git push origin :old"):
            self.assertEqual(self.run_guard(cmd)[0], "deny", cmd)

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

    def test_hash_comment_does_not_hide_rest(self):
        self.assertEqual(self.run_guard("# note\ngit push --force")[0], "ask")
        self.set_mode("auto")
        self.assertEqual(self.run_guard("# note\ngit commit --no-verify -m x")[0], "deny")

    def test_cd_through_symlink_is_logical(self):
        with tempfile.TemporaryDirectory() as top:
            w, m = os.path.join(top, "w"), os.path.join(top, "main")
            for d in (w, m):
                subprocess.run(["git", "init", "-q", d], check=True)
            os.makedirs(os.path.join(w, "deep", "deeper"))
            os.makedirs(os.path.join(w, "main"))
            os.symlink(os.path.join(w, "deep", "deeper"), os.path.join(w, "s"))
            self.repo = w
            self.write_guard_file('{"commit":"auto"}')
            self.assertEqual(self.run_guard("cd s/../../main && git commit -m x")[0], "ask")

    def test_parse_error_asks(self):
        self.assertEqual(self.run_guard("echo $'\\'' ; git push --force")[0], "ask")

    def test_dash_c_hookspath_and_alias(self):
        cmd = "git -c core.hooksPath=/dev/null commit -m x"
        self.assertEqual(self.run_guard(cmd)[0], "deny")
        self.write_guard_file('{"commit":"auto"}')
        self.assertEqual(self.run_guard(cmd)[0], "deny")
        for cmd in ("git --config-env=core.hooksPath=HP commit -m x",
                     "git --config-env core.hooksPath=HP commit -m x"):
            self.assertEqual(self.run_guard(cmd)[0], "deny", cmd)
        self.assertEqual(self.run_guard("git -c alias.ci='!git -C /x commit' ci -m x")[0], "ask")

    def test_prefix_words_before_cd_and_git(self):
        self.write_guard_file('{"commit":"auto"}')
        with tempfile.TemporaryDirectory() as other:
            subprocess.run(["git", "init", "-q", other], check=True)
            o = shlex.quote(other)
            for cmd in (f"builtin cd {o} && git commit -m x", f"command cd {o} && git commit -m x",
                        f"FOO=1 cd {o} && git commit -m x", f"command git -C {o} commit -m x",
                        f"exec git -C {o} commit -m x"):
                self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)

    def test_summary_skips_fsmonitor(self):
        marker = os.path.join(self.repo, "fsmonitor-ran")
        subprocess.run(["git", "-C", os.path.join(self.repo, "sub"), "config",
                        "core.fsmonitor", f"touch {marker}"], check=True)
        self.run_guard("git -C sub commit -m x")
        self.assertFalse(os.path.exists(marker))

    def git_setup(self, *args):
        subprocess.run(["git", "-C", self.repo, "-c", "user.name=t", "-c", "user.email=t@t", *args],
                       check=True, capture_output=True)

    def test_commit_auto_needs_worker_branch(self):
        self.git_setup("commit", "--allow-empty", "-m", "init")
        self.git_setup("checkout", "-q", "-B", "main")
        self.git_setup("switch", "-q", "-c", "worker-t1")
        self.write_guard_file('{"commit":"auto","branch":"worker-t1"}')
        for cmd in ("git commit -m x", "git merge b"):
            self.assertEqual(self.run_guard(cmd), (None, ""), cmd)
        self.git_setup("switch", "-q", "-c", "other")
        for cmd in ("git commit -m x", "git merge b"):
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)
        self.git_setup("switch", "-q", "worker-t1")
        self.assertEqual(self.run_guard("git switch main && git commit -m x")[0], "ask")
        self.assertEqual(self.run_guard("git checkout other && git merge b")[0], "ask")
        self.git_setup("switch", "-q", "other")
        self.write_guard_file('{"commit":"auto"}')
        self.assertEqual(self.run_guard("git commit -m x"), (None, ""))

    def test_ref_moves_ask(self):
        moves = ("git update-ref refs/heads/main HEAD", "git branch -f main HEAD",
                 "git branch --force main HEAD", "git branch -M main", "git fetch . a:main",
                 "git pull origin a:main")
        for cmd in moves:
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)
        self.write_guard_file('{"commit":"auto"}')
        for cmd in moves:
            self.assertEqual(self.run_guard(cmd)[0], "ask", cmd)
        for cmd in ("git branch -a", "git fetch origin", "git fetch origin main",
                    "git pull origin main", "git pull"):
            self.assertEqual(self.run_guard(cmd), (None, ""), cmd)

    def test_stray_quote_heredoc_without_git_word_no_decision(self):
        self.assertEqual(self.run_guard("cat > t.txt <<EOF\nit's here\nEOF\ngrep -n here t.txt"),
                         (None, ""))

    def test_stray_quote_heredoc_read_only_git_no_decision(self):
        for last in ("git status", "git log --oneline"):
            self.assertEqual(self.run_guard(f"cat > t.txt <<EOF\nit's here\nEOF\n{last}"),
                             (None, ""), last)

    def test_stray_quote_commit_asks(self):
        cmd = "cat > t.txt <<EOF\nit's here\nEOF\ngit commit -m x"
        d, reason = self.run_guard(cmd)
        self.assertEqual(d, "ask")
        self.assertIn("git commit (commit: ask)", reason)
        self.set_mode("auto")
        d, reason = self.run_guard(cmd)
        self.assertEqual(d, "ask")
        self.assertIn("may target another folder or branch", reason)

    def test_stray_quote_force_push_asks(self):
        d, reason = self.run_guard("cat > t.txt <<EOF\nit's here\nEOF\ngit push --force")
        self.assertEqual(d, "ask")
        self.assertIn("force push", reason)

    def test_stray_quote_add_all_denied(self):
        self.assertEqual(self.run_guard("cat > t.txt <<EOF\nit's here\nEOF\ngit add -A")[0],
                         "deny")

    def test_stray_quote_python_heredoc_git_line_asks(self):
        cmd = ("python3 - <<'PY'\nsubprocess.run([\"git\", \"commit\", \"-m\", \"x\"])\n"
               "# it's a test\nPY")
        d, reason = self.run_guard(cmd)
        self.assertEqual(d, "ask")
        self.assertIn("The git guard could not read a git command on this line.", reason)

    def test_stray_quote_quoted_git_text_asks(self):
        d, reason = self.run_guard("echo \"run git status\"\necho it's")
        self.assertEqual(d, "ask")
        self.assertIn("The git guard could not read a git command on this line.", reason)

    def test_stray_quote_path_with_git_no_decision(self):
        self.assertEqual(self.run_guard("cat > t.txt <<EOF\nhooks/st-git-guard.py it's\nEOF"),
                         (None, ""))

    def test_stray_quote_escaped_git_words(self):
        for cmd in ("\\git push --force", "g''it push --force", "gi\\t push --force"):
            d, reason = self.run_guard(f"echo it's\n{cmd}")
            self.assertEqual(d, "ask", cmd)
            self.assertIn("force push", reason, cmd)
        for cmd in ("\\git status", "g''it status", "gi\\t status"):
            self.assertEqual(self.run_guard(f"echo it's\n{cmd}"), (None, ""), cmd)

    def test_stray_quote_wrapped_git_asks(self):
        for cmd in ("$'git' push --force", '$"git" push --force', "git>/dev/null push --force",
                    "git</dev/null push origin main", "git status && env git push --force",
                    "git status; sudo git push origin main", "git log | xargs git add -A",
                    "git status && bash -c 'git push --force'", "x=git; $x push"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_guard(f"echo it's\n{cmd}")[0], "ask", cmd)

    def test_quoted_heredoc_cat_body_no_decision(self):
        self.assertEqual(self.run_guard(
            "cat > f.md <<'EOF'\nthe git guard can't read this\ngit push --force\nEOF"), (None, ""))

    def test_quoted_heredoc_tee_body_no_decision(self):
        for cmd in ("tee notes.md <<'EOF'\ngit push --force\nit's text\nEOF",
                    "tee -a notes.md <<\"EOF\"\ngit push --force\nit's text\nEOF",
                    "cat <<-'EOF' >> notes.md\ngit push --force\nit's text\n\tEOF"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_guard(cmd), (None, ""))

    def test_quoted_heredoc_python_text_asks(self):
        self.assertEqual(self.run_guard(
            "python3 - <<'PY'\ns=\"it's git push text\"\nopen('a','w').write(s)\n# it's\nPY")[0], "ask")

    def test_quoted_heredoc_python_subprocess_asks(self):
        cmd = ("python3 - <<'PY'\nimport subprocess\nsubprocess.run(['git','push','--force'])\n"
               "# it's\nPY")
        self.assertEqual(self.run_guard(cmd)[0], "ask")

    def test_quoted_heredoc_ruby_popen_asks(self):
        cmd = "ruby - <<'RB'\nIO.popen(\"git push --force\")\n# it's\nRB"
        self.assertEqual(self.run_guard(cmd)[0], "ask")

    def test_quoted_heredoc_shell_reader_judged(self):
        d, reason = self.run_guard("bash <<'EOF'\ngit push --force\necho it's\nEOF")
        self.assertEqual(d, "ask")
        self.assertIn("force push", reason)

    def test_unquoted_heredoc_body_judged(self):
        self.assertEqual(self.run_guard("cat <<EOF\n$(git push --force)\nit's\nEOF")[0], "ask")

    def test_quoted_heredoc_commit_opener_judged(self):
        self.set_mode("ask")
        d, reason = self.run_guard("git commit -F - <<'EOF'\nmsg it's\nEOF")
        self.assertEqual(d, "ask")
        self.assertIn("git commit (commit: ask)", reason)

    def test_heredoc_must_ask_reader_after_redirect_or_keyword(self):
        for opener in ("<<'EOF' bash", "time bash <<'EOF'", "if bash <<'EOF'", "! bash <<'EOF'"):
            with self.subTest(opener=opener):
                d, reason = self.run_guard(f"{opener}\ngit push --force\n# it's a push\nEOF")
                self.assertEqual(d, "ask")
                self.assertIn("force push", reason)

    def test_heredoc_must_ask_opener_in_comment(self):
        for opener in ("# Example: cat <<'exit'", "true # note; cat <<'exit'"):
            with self.subTest(opener=opener):
                d, reason = self.run_guard(f"{opener}\ngit push --force\n# it's a comment\nexit")
                self.assertEqual(d, "ask")
                self.assertIn("force push", reason)

    def test_heredoc_must_ask_inside_unquoted_body(self):
        for cmd in ("cat <<OUTER\ncat <<'INNER'\n$(git push --force)\n# it's expanded\nINNER\nOUTER",
                    "cat <<OUTER\ncat <<'INNER'\nINNER\nOUTER\ngit push --force\n# it's",
                    "cat <<E\nx\\\nE\ncat <<'X'\n$(git push --force)\n# it's\nX\nE"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_guard(cmd)[0], "ask")

    def test_heredoc_must_ask_python_execvp(self):
        cmd = ("python3 - <<'PYTHON'\nfrom os import execvp\n# it's a push\n"
               "execvp('git', ['git', 'push', '--force'])\nPYTHON")
        self.assertEqual(self.run_guard(cmd)[0], "ask")

    def test_heredoc_must_ask_cat_feeds_a_reader(self):
        for cmd in ("cat <<'EOF' | sh\ngit push --force\n# it's\nEOF",
                    "{\ncat <<'EOF'\ngit push --force\n# it's\nEOF\n} | sh",
                    "$(\ncat <<'EOF'\ngit push --force\nEOF\n)\n# it's",
                    "bash -c \"\ncat <<'EOF'\n\" ; git push --force\nEOF",
                    "cat <<'EOF' 2>${x- #} | sh\ngit push --force\n# it's\nEOF",
                    "sh -s \\; cat <<'EOF'\ngit push --force\n# it's\nEOF",
                    "cat <<'EOF'\ngit push --force\n# it's"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_guard(cmd)[0], "ask")

    def test_heredoc_must_ask_file_then_run(self):
        for cmd in ("cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\nsh f.sh",
                    "cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\nchmod +x f.sh && ./f.sh",
                    "cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\ncat <<X\n$(sh f.sh)\nX",
                    "cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\nx=$(sh f.sh)",
                    "cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\ntimeout 5 ./f.sh",
                    "cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\nnohup ./f.sh",
                    "cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\nmake",
                    "cat > f.sh <<'EOF'\ngit push --force\n# it's\nEOF\nnpm run x",
                    "PATH=/tmp/x cat > f.md <<'EOF'\ngit push --force\n# it's\nEOF",
                    "PATH=/tmp/x\ncat > f.md <<'EOF'\ngit push --force\n# it's\nEOF"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_guard(cmd)[0], "ask")

    def test_quoted_heredoc_then_plain_command_no_decision(self):
        for cmd in ("cat > f.md <<'EOF'\ngit push text\n# it's\nEOF\nls f.md",
                    "cd /tmp && cat > a/b.md <<'EOF'\ngit push text\n# it's\nEOF\nls a"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_guard(cmd), (None, ""))


if __name__ == "__main__":
    unittest.main()
