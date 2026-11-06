import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
HOOK = os.path.join(ROOT, "hooks", "st-phase.py")
CMD = 'python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-phase.py"'


def prompt_line(text, pid="p1"):
    return {"type": "user", "promptId": pid, "message": {"role": "user", "content": text}}


def result_line(text, pid="p1"):
    return {"type": "user", "promptId": pid, "message": {"role": "user",
            "content": [{"type": "tool_result", "tool_use_id": "t1", "content": text}]}}


def meta_line(text, pid="p1"):
    return {"type": "user", "promptId": pid, "isMeta": True,
            "message": {"role": "user", "content": [{"type": "text", "text": text}]}}


def reply_line(text):
    return {"type": "assistant", "message": {"role": "assistant", "content": [{"type": "text", "text": text}]}}


def sidechain_line(text):
    return {**reply_line(text), "isSidechain": True}


def blob_line(text):
    return {"type": "api-request-blob", "message": {"content": [{"type": "text", "text": text}]}}


def state_path(folder):
    return os.path.join(folder, ".stratum", "state.json")


class PhaseHookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.proj = self.tmp.name
        os.makedirs(os.path.join(self.proj, ".stratum"))
        self.state = os.path.join(self.proj, ".stratum", "state.json")

    def tearDown(self):
        self.tmp.cleanup()

    def write_state(self, **state):
        with open(self.state, "w") as f:
            json.dump(state, f, indent=2)

    def raw(self):
        with open(self.state) as f:
            return f.read()

    def read_state(self):
        with open(self.state) as f:
            return json.load(f)

    def run_hook(self, payload, cwd=None):
        if isinstance(payload, dict):
            payload = json.dumps({"cwd": cwd or self.proj, **payload})
        r = subprocess.run([sys.executable, HOOK], input=payload, capture_output=True, text=True, timeout=10,
                           env={**os.environ, "GIT_CEILING_DIRECTORIES": os.path.dirname(self.proj)})
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def prompt(self, text, cwd=None, sid="s1"):
        return self.run_hook({"hook_event_name": "UserPromptSubmit", "prompt": text, "session_id": sid}, cwd)

    def skill(self, name, sid="s1", args="x"):
        return self.run_hook({"hook_event_name": "PreToolUse", "tool_name": "Skill", "session_id": sid,
                              "tool_input": {"skill": name, "args": args}})

    def context(self, out, event):
        out = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], event)
        self.assertNotIn("permissionDecision", out)
        self.assertEqual(len(out["additionalContext"].splitlines()), 1)
        return out["additionalContext"]

    def send(self, event, cwd=None, **fields):
        return self.run_hook({"hook_event_name": event, "session_id": "s1", "prompt_id": "p1",
                              **{k: v for k, v in fields.items() if v is not None}}, cwd)

    def pre_skill(self, name, transcript=None, cwd=None):
        return self.send("PreToolUse", cwd, tool_name="Skill", tool_input={"skill": name},
                         transcript_path=transcript)

    def pre_agent(self, transcript=None, cwd=None, agent_id=None):
        return self.send("PreToolUse", cwd, tool_name="Agent", tool_input={"prompt": "p"},
                         transcript_path=transcript, agent_id=agent_id)

    def post_tool(self, tool, transcript=None, cwd=None, agent_id=None):
        return self.send("PostToolUse", cwd, tool_name=tool, tool_input={"prompt": "p"},
                         transcript_path=transcript, agent_id=agent_id)

    def stop_event(self, transcript=None, cwd=None, last=None, agent_id=None):
        return self.send("Stop", cwd, transcript_path=transcript, last_assistant_message=last, agent_id=agent_id)

    def transcript(self, *lines):
        path = os.path.join(self.proj, "transcript.jsonl")
        with open(path, "w") as f:
            f.writelines(json.dumps(line) + "\n" for line in lines)
        return path

    def put(self, path, **state):
        with open(path, "w") as f:
            json.dump(state, f, indent=2)

    def read_text(self, path):
        with open(path) as f:
            return f.read()

    def reset(self, risk="normal"):
        self.write_state(feature_directory="specs/001-x", phase="build", lane="full", risk=risk)
        return self.raw()

    def make_worktree(self):
        main = os.path.join(self.proj, "main")
        linked = os.path.join(self.proj, "linked")
        env = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"}
        os.makedirs(main)
        for args in (["init", "-q"],
                     ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "x"],
                     ["worktree", "add", "-q", "--detach", linked]):
            subprocess.run(["git", "-C", main, *args], check=True, capture_output=True, env=env)
        for folder in (main, linked):
            os.makedirs(os.path.join(folder, ".stratum"))
            self.put(state_path(folder), feature_directory="specs/001-x", phase="build", lane="full", risk="normal")
        return main, linked

    def spec_folder(self, name, spec=True):
        folder = os.path.join(self.proj, "specs", name)
        os.makedirs(folder, exist_ok=True)
        if spec:
            open(os.path.join(folder, "spec.md"), "w").close()

    def test_prompt_sets_phase_keeps_keys(self):
        self.write_state(feature_directory="specs/001-x", phase="define", lane="full")
        self.assertEqual(self.context(self.prompt("/stratum:st-plan"), "UserPromptSubmit"),
                         "Start your reply with [Full lane | Plan].")
        self.assertEqual(self.read_state(), {"feature_directory": "specs/001-x", "phase": "plan", "lane": "full"})

    def test_skill_sets_phase(self):
        self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
        self.assertEqual(self.skill("stratum:st-close").strip(), "")
        self.assertEqual(self.read_state()["phase"], "close")

    def test_full_order_is_silent(self):
        self.write_state(feature_directory="specs/001-x", phase=None, lane="full")
        for p in ("define", "plan", "plan", "inspect", "build", "build", "close"):
            self.assertEqual(self.skill("stratum:st-" + p).strip(), "", p)
            self.assertEqual(self.read_state()["phase"], p)

    def test_out_of_order_warns_and_sets(self):
        self.write_state(feature_directory="specs/001-x", phase="plan", lane="full")
        w = self.context(self.prompt("/stratum:st-build add it"), "UserPromptSubmit")
        self.assertTrue(w.startswith("Start your reply with [Full lane | Build]. "), w)
        self.assertIn("out of order", w)
        self.assertIn("plan", w)
        self.assertEqual(self.read_state()["phase"], "build")
        self.write_state(feature_directory="specs/001-x", phase="define", lane="full")
        self.context(self.skill("stratum:st-close"), "PreToolUse")
        self.assertEqual(self.read_state()["phase"], "close")

    def test_define_never_warns(self):
        self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
        self.assertNotIn("out of order", self.prompt("/stratum:st-define new thing"))
        self.assertEqual(self.read_state()["phase"], "define")

    def test_no_feature_leaves_state(self):
        self.write_state(feature_directory=None, phase=None, lane=None)
        before = self.raw()
        self.assertEqual(self.skill("stratum:st-plan").strip(), "")
        self.assertEqual(self.raw(), before)
        self.prompt("/stratum:st-define x")
        self.assertEqual(self.read_state()["phase"], "define")

    def test_non_phase_changes_nothing(self):
        self.write_state(feature_directory="specs/001-x", phase="done", lane="full")
        before = self.raw()
        for text in ("/stratum:st", "/stratum:st-planner", "please run /stratum:st-build", "stratum:st-plan",
                     "/stratum:st-build-x", "hello", "", "/stratum:st-quick-x", "please run /stratum:st-fast", "/stratum:st-fuller"):
            self.assertEqual(self.prompt(text).strip(), "", text)
        for name in ("stratum:st-status", "stratum:st-fastx", "other:st-quick", "st-close", "other:st-build", ""):
            self.assertEqual(self.skill(name).strip(), "", name)
        self.assertEqual(self.raw(), before)

    def test_label_on_any_prompt_while_lane_runs(self):
        for phase, label in (("define", "[Full lane | Define]"), ("build", "[Full lane | Build]"),
                             ("close", "[Full lane | Close]"), ("fast", "[Fast lane]"), ("quick", "[Quick lane]")):
            self.write_state(feature_directory="specs/001-x", phase=phase, lane="full")
            before = self.raw()
            self.assertEqual(self.context(self.prompt("what next?"), "UserPromptSubmit"),
                             f"Start your reply with {label}.", phase)
            self.assertEqual(self.raw(), before)

    def test_lane_label_beats_phase(self):
        for lane, phase, label in (("fast", "build", "[Fast lane]"), ("fast", "close", "[Fast lane]"),
                                   ("quick", "build", "[Quick lane]"), ("full", "build", "[Full lane | Build]")):
            self.write_state(feature_directory="specs/001-x", phase=phase, lane=lane)
            self.assertEqual(self.context(self.prompt("what next?"), "UserPromptSubmit"),
                             f"Start your reply with {label}.", lane + "/" + phase)

    def test_held_skill_labels_until_cleared(self):
        for name in ("st-worker", "st-build"):
            self.write_state(feature_directory="specs/001-x", phase="done", lane="full")
            self.assertEqual(self.skill("stratum:" + name).strip(), "", name)
            self.assertEqual(self.read_state(), {"feature_directory": "specs/001-x", "phase": "done", "lane": "none",
                                                 "skill": name, "skill_session": "s1"}, name)
            self.assertEqual(self.context(self.prompt("what next?"), "UserPromptSubmit"),
                             f"Start your reply with [{name}].", name)
            self.assertEqual(self.prompt("what next?", sid="s2").strip(), "", name + " new session")
            state = self.read_state()
            state["skill"] = ""
            self.write_state(**state)
            self.assertEqual(self.prompt("what next?").strip(), "", name + " cleared")
        self.write_state(feature_directory=None, phase=None, lane=None)
        self.assertEqual(self.context(self.prompt("/stratum:st-build T001"), "UserPromptSubmit"),
                         "Start your reply with [st-build].")
        self.assertEqual(self.read_state()["phase"], None)

    def test_held_skill_keeps_running_lane(self):
        for lane, phase in (("full", "build"), ("fast", "fast")):
            self.write_state(feature_directory="specs/001-x", phase=phase, lane=lane)
            before = self.raw()
            self.skill("stratum:st-worker")
            self.assertEqual(self.raw(), before, lane)

    def test_phase_after_held_skill_is_full_lane(self):
        self.write_state(feature_directory="specs/001-x", phase="done", lane="none", skill="st-worker", skill_session="s1")
        self.assertEqual(self.context(self.prompt("/stratum:st-define x"), "UserPromptSubmit"),
                         "Start your reply with [Full lane | Define].")
        self.assertEqual(self.read_state()["lane"], "full")

    def test_typed_skill_labels_its_reply(self):
        self.write_state(feature_directory="specs/001-x", phase="done", lane="none", skill="st-worker", skill_session="s1")
        before = self.raw()
        self.assertEqual(self.context(self.prompt("/stratum:st-status"), "UserPromptSubmit"),
                         "Start your reply with [st-status].")
        self.assertEqual(self.raw(), before)
        self.assertEqual(self.skill("stratum:st-status").strip(), "")
        self.assertEqual(self.raw(), before)
        self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
        self.assertEqual(self.context(self.prompt("/stratum:st-status"), "UserPromptSubmit"),
                         "Start your reply with [Full lane | Build].")

    def test_no_label_when_no_lane_runs(self):
        for phase in ("done", None, "implement"):
            self.write_state(feature_directory="specs/001-x", phase=phase, lane="full")
            self.assertEqual(self.prompt("what next?").strip(), "", phase)

    def test_skill_event_never_labels(self):
        self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
        self.assertEqual(self.skill("stratum:st-status").strip(), "")
        self.assertEqual(self.skill("stratum:st-build").strip(), "")

    def test_lane_skills_set_lane_and_phase(self):
        keep = {"feature_directory": None, "phase": "done", "keep": 1}
        for x, before, lane, phase in (("fast", "full", "fast", "fast"), ("quick", "full", "quick", "quick"),
                                       ("full", "fast", "full", "done")):
            want = dict(keep, lane=lane, phase=phase)
            self.write_state(lane=before, **keep)
            self.prompt("/stratum:st-" + x + " do it")
            self.assertEqual(self.read_state(), want, "prompt " + x)
            self.write_state(lane=before, **keep)
            self.assertEqual(self.skill("stratum:st-" + x).strip(), "", "skill " + x)
            self.assertEqual(self.read_state(), want, "skill " + x)
        for old in ("fast", "quick"):
            want = {"feature_directory": None, "phase": None, "lane": "full"}
            self.write_state(feature_directory=None, phase=old, lane=old)
            self.assertEqual(self.prompt("/stratum:st-full do it").strip(), "", "prompt full from " + old)
            self.assertEqual(self.read_state(), want, "prompt full from " + old)
            self.write_state(feature_directory=None, phase=old, lane=old)
            self.skill("stratum:st-full")
            self.assertEqual(self.read_state(), want, "skill full from " + old)
        self.write_state(lane="full", **keep)
        self.assertEqual(self.context(self.prompt("/stratum:st-fast do it"), "UserPromptSubmit"),
                         "Start your reply with [Fast lane].")
        self.write_state(lane="full", **keep)
        self.assertEqual(self.context(self.prompt("/stratum:st-quick do it"), "UserPromptSubmit"),
                         "Start your reply with [Quick lane].")

    def test_phase_sets_lane_only_when_unset(self):
        for lane in (None, ""):
            self.write_state(feature_directory="specs/001-x", phase="define", lane=lane)
            self.skill("stratum:st-plan")
            self.assertEqual(self.read_state().get("lane"), "full", repr(lane))
        self.write_state(feature_directory="specs/001-x", phase="define")
        self.skill("stratum:st-plan")
        self.assertEqual(self.read_state().get("lane"), "full", "missing")
        self.write_state(feature_directory="specs/001-x", phase="fast", lane="fast")
        self.skill("stratum:st-close")
        self.assertEqual(self.read_state(), {"feature_directory": "specs/001-x", "phase": "close", "lane": "fast"})
        self.write_state(feature_directory="specs/001-x", phase="fast", lane="fast")
        self.skill("stratum:st-define")
        self.assertEqual(self.read_state(), {"feature_directory": "specs/001-x", "phase": "define", "lane": "full",
                                             "define_before": []})

    def test_agents_write_done(self):
        for name in ("st", "st-fast", "st-quick", "st-full", "st-close"):
            with open(os.path.join(ROOT, "skills", name, "SKILL.md")) as f:
                text = f.read()
            for stale in ("Write `lane`", "Set `lane`", "Set `phase`"):
                self.assertNotIn(stale, text, name)
        phrase = "set `phase` to `done` in `<project>/.stratum/state.json`"
        with open(os.path.join(ROOT, "agents", "st-quick.md")) as f:
            self.assertIn(phrase, f.read())
        with open(os.path.join(ROOT, "agents", "st-close.md")) as f:
            self.assertNotIn(phrase, f.read())
        done = "say `Phase: done` on its own line"
        with open(os.path.join(ROOT, "skills", "st-close", "SKILL.md")) as f:
            self.assertIn(done, f.read())
        with open(os.path.join(ROOT, "skills", "st-fast", "SKILL.md")) as f:
            self.assertIn(done, f.read())

    def test_write_replaces_file_atomically(self):
        self.write_state(feature_directory="specs/001-x", phase="define", lane="full")
        before = os.stat(self.state).st_ino
        self.prompt("/stratum:st-plan")
        self.assertEqual(self.read_state()["phase"], "plan")
        self.assertNotEqual(os.stat(self.state).st_ino, before)
        self.assertEqual(sorted(os.listdir(os.path.dirname(self.state))), ["state.json"])

    def test_found_from_subfolder(self):
        self.write_state(feature_directory="specs/001-x", phase="define", lane="full")
        sub = os.path.join(self.proj, "a", "b")
        os.makedirs(sub)
        self.prompt("/stratum:st-plan", cwd=sub)
        self.assertEqual(self.read_state()["phase"], "plan")

    def test_no_state_file_does_nothing(self):
        self.assertEqual(self.prompt("/stratum:st-plan").strip(), "")
        self.assertEqual(self.skill("stratum:st-build").strip(), "")
        self.assertFalse(os.path.exists(self.state))

    def test_bad_input_is_silent(self):
        self.write_state(feature_directory="specs/001-x", phase="define", lane="full")
        before = self.raw()
        for payload in ("{not json", "[]", json.dumps({"hook_event_name": "PreToolUse", "tool_input": "x"})):
            self.assertEqual(self.run_hook(payload).strip(), "")
        with open(self.state, "w") as f:
            f.write("{bad")
        self.assertEqual(self.prompt("/stratum:st-plan").strip(), "")
        self.assertEqual(self.raw(), "{bad")
        self.assertNotEqual(before, "{bad")

    def test_hook_registered(self):
        with open(os.path.join(ROOT, "hooks", "commands.json")) as f:
            hooks = json.load(f)["hooks"]
        pre = [e for e in hooks["PreToolUse"] if e.get("matcher") == "Skill|Agent"]
        self.assertEqual(len(pre), 1)
        self.assertIn(CMD, [h["command"] for h in pre[0]["hooks"]])
        post = [e for e in hooks.get("PostToolUse", []) if e.get("matcher") == "Bash|Write|Edit|MultiEdit|Agent"]
        self.assertEqual(len(post), 1)
        self.assertIn(CMD, [h["command"] for h in post[0]["hooks"]])
        self.assertIn(CMD, [h["command"] for e in hooks.get("Stop", []) for h in e["hooks"]])
        self.assertIn(CMD, [h["command"] for e in hooks["UserPromptSubmit"] for h in e["hooks"]])

    def test_risk_from_reply(self):
        line = reply_line("[Orchestrator]\n\nLane: full, risk high (data model: x). Say so.")
        for name, fire in (
            ("PreToolUse Skill", lambda t: self.pre_skill("stratum:st-status", t)),
            ("PreToolUse Agent", lambda t: self.pre_agent(t)),
            ("PostToolUse Agent", lambda t: self.post_tool("Agent", t)),
            ("Stop", lambda t: self.stop_event(t)),
        ):
            with self.subTest(name):
                self.reset()
                self.assertEqual(fire(self.transcript(prompt_line("go"), line)), "")
                self.assertEqual(self.read_state().get("risk"), "high")
                self.assertEqual(os.listdir(os.path.dirname(self.state)), ["state.json"])
        with self.subTest("two Lane lines, last wins"):
            self.reset()
            self.stop_event(self.transcript(prompt_line("go"), reply_line("Lane: full, risk high (a)"),
                                            reply_line("Lane: full, risk low (b)")))
            self.assertEqual(self.read_state().get("risk"), "low")
        with self.subTest("lane word and level in any case"):
            self.reset()
            self.stop_event(self.transcript(prompt_line("go"), reply_line("Lane: Fast, risk Low (quick)")))
            self.assertEqual(self.read_state().get("risk"), "low")
        for level in ("high", "normal", "low", "none"):
            with self.subTest(level):
                self.reset("high" if level == "normal" else "normal")
                self.stop_event(self.transcript(prompt_line("go"), reply_line(f"Lane: full, risk {level} (x)")))
                self.assertEqual(self.read_state().get("risk"), level)

    def test_risk_reads_past_one_block(self):
        big = result_line("x" * (70 * 1024))
        with self.subTest("reply line before more than 64 KiB of tool results"):
            self.reset()
            self.stop_event(self.transcript(prompt_line("go"), reply_line("Lane: full, risk high (x)"), big))
            self.assertEqual(self.read_state().get("risk"), "high")
        with self.subTest("prompt before more than 64 KiB of tool results stops the read"):
            before = self.reset("high")
            self.stop_event(self.transcript(prompt_line("first"), reply_line("Lane: full, risk low (x)"),
                                            prompt_line("second"), big))
            self.assertEqual(self.raw(), before)

    def test_risk_ignores_out_of_turn(self):
        with self.subTest("control: line in this turn sets risk"):
            self.reset()
            self.stop_event(self.transcript(prompt_line("go"), reply_line("Lane: full, risk high (x)")))
            self.assertEqual(self.read_state().get("risk"), "high")
        with self.subTest("line in an earlier turn, risk high prompt, reply ok"):
            before = self.reset("high")
            self.stop_event(self.transcript(prompt_line("first"), reply_line("Lane: full, risk low (x)"),
                                            prompt_line("risk high"), reply_line("ok")))
            self.assertEqual(self.raw(), before)
        rows = {
            "tool result": [prompt_line("go"), result_line("Lane: full, risk high (x)"), reply_line("ok")],
            "meta line": [prompt_line("go"), meta_line("Lane: full, risk high (x)"), reply_line("ok")],
            "sidechain reply": [prompt_line("go"), sidechain_line("Lane: full, risk high (x)"), reply_line("ok")],
            "api-request-blob": [prompt_line("go"), blob_line("Lane: full, risk high (x)"), reply_line("ok")],
            "inside a sentence": [prompt_line("go"), reply_line("I said Lane: full, risk high (x)")],
            "risk extreme": [prompt_line("go"), reply_line("Lane: full, risk extreme (x)")],
        }
        for name, lines in rows.items():
            with self.subTest(name):
                before = self.reset()
                self.stop_event(self.transcript(*lines))
                self.assertEqual(self.raw(), before)
        t = self.transcript(prompt_line("go"), reply_line("Lane: full, risk high (x)"))
        for name, fire in (
            ("PreToolUse Agent", lambda: self.pre_agent(t, agent_id="a1")),
            ("PostToolUse Agent", lambda: self.post_tool("Agent", t, agent_id="a1")),
            ("Stop", lambda: self.stop_event(t, agent_id="a1")),
        ):
            with self.subTest(name + " with agent_id"):
                before = self.reset()
                fire()
                self.assertEqual(self.raw(), before)
        with self.subTest("no transcript_path"):
            before = self.reset()
            self.stop_event()
            self.assertEqual(self.raw(), before)
        with self.subTest("missing file"):
            before = self.reset()
            self.stop_event(os.path.join(self.proj, "missing.jsonl"))
            self.assertEqual(self.raw(), before)
        with self.subTest("bad JSON line that carries the marker"):
            before = self.reset()
            path = os.path.join(self.proj, "bad.jsonl")
            with open(path, "w") as f:
                f.write(json.dumps(reply_line("Lane: full, risk high (x)"))[:-1] + "\n")
            self.stop_event(path)
            self.assertEqual(self.raw(), before)

    def test_risk_at_stop_from_last_message(self):
        t = self.transcript(prompt_line("go"), reply_line("ok"))
        with self.subTest("last message has the line"):
            self.reset()
            self.stop_event(t, last="Lane: full, risk high (x)")
            self.assertEqual(self.read_state().get("risk"), "high")
        with self.subTest("last message without the line"):
            before = self.reset()
            self.stop_event(t, last="ok")
            self.assertEqual(self.raw(), before)

    def test_risk_goes_to_main_checkout(self):
        main, linked = self.make_worktree()
        main_state, linked_state = state_path(main), state_path(linked)
        t = self.transcript(prompt_line("go"), reply_line("Lane: full, risk high (x)"))
        with self.subTest("main file gets risk, worktree file untouched"):
            linked_before = self.read_text(linked_state)
            self.stop_event(t, cwd=linked)
            self.assertEqual(json.loads(self.read_text(main_state)).get("risk"), "high")
            self.assertEqual(self.read_text(linked_state), linked_before)
        with self.subTest("main file missing: nothing created"):
            os.remove(main_state)
            linked_before = self.read_text(linked_state)
            self.stop_event(t, cwd=linked)
            self.assertFalse(os.path.exists(main_state))
            self.assertEqual(self.read_text(linked_state), linked_before)
        with self.subTest("main file bad: nothing changed"):
            with open(main_state, "w") as f:
                f.write("{bad")
            linked_before = self.read_text(linked_state)
            self.stop_event(t, cwd=linked)
            self.assertEqual(self.read_text(main_state), "{bad")
            self.assertEqual(self.read_text(linked_state), linked_before)

    def test_risk_reads_past_meta_line(self):
        t = self.transcript(prompt_line("go"), reply_line("Lane: full, risk high (x)"), meta_line("skill text"),
                            reply_line("ok"))
        for name, fire in (("PreToolUse Agent", lambda: self.pre_agent(t)), ("Stop", lambda: self.stop_event(t))):
            with self.subTest(name):
                self.reset()
                fire()
                self.assertEqual(self.read_state().get("risk"), "high")

    def test_fast_lane_risk_before_step2(self):
        self.reset()
        t = self.transcript(prompt_line("/stratum:st-fast do it"))
        self.pre_skill("stratum:st-fast", t)
        self.assertEqual(self.read_state().get("risk"), "normal")
        with open(t, "a") as f:
            for line in (reply_line("Lane: fast, risk high (x)"), result_line("r")):
                f.write(json.dumps(line) + "\n")
        self.pre_agent(t)
        self.assertEqual(self.read_state().get("risk"), "high")
        self.post_tool("Bash", t)
        self.assertEqual(self.read_state().get("risk"), "high")

    def test_risk_to_main_when_worktree_has_no_state(self):
        main, linked = self.make_worktree()
        os.remove(state_path(linked))
        self.stop_event(self.transcript(prompt_line("go"), reply_line("Lane: full, risk high (x)")), cwd=linked)
        self.assertEqual(json.loads(self.read_text(state_path(main))).get("risk"), "high")
        self.assertEqual(os.listdir(os.path.join(linked, ".stratum")), [])

    def test_plain_repo_without_state_reads_nothing(self):
        plain = os.path.join(self.proj, "plain")
        os.makedirs(os.path.join(plain, ".git"))
        fifo = os.path.join(self.proj, "fifo")
        os.mkfifo(fifo)
        self.assertEqual(self.stop_event(fifo, cwd=plain, last="Lane: full, risk high (x)"), "")
        self.assertEqual(os.listdir(plain), [".git"])
        self.assertEqual(os.listdir(os.path.join(self.proj, ".stratum")), [])

    def test_turn_stops_at_other_prompt_id(self):
        old_turn = [prompt_line("go", "p0"), reply_line("Lane: full, risk low (x)"), result_line("r", "p0")]
        for name, event, tool in (("Stop", "Stop", None), ("PreToolUse Agent", "PreToolUse", "Agent")):
            with self.subTest(name + ": new prompt line not written yet"):
                before = self.reset()
                self.send(event, tool_name=tool, transcript_path=self.transcript(*old_turn))
                self.assertEqual(self.raw(), before)
            with self.subTest(name + ": reply after a tool result of this prompt"):
                self.reset()
                self.send(event, tool_name=tool, transcript_path=self.transcript(
                    *old_turn, result_line("r", "p1"), reply_line("Lane: full, risk high (x)")))
                self.assertEqual(self.read_state().get("risk"), "high")
            with self.subTest(name + ": old turn ends with a reply, new prompt line not written yet"):
                self.write_state(feature_directory="specs/001-x", phase="build", lane="full", risk="high",
                                 skill="st-build", skill_session="s1")
                before = self.raw()
                self.send(event, tool_name=tool, transcript_path=self.transcript(
                    prompt_line("old task", "p0"), reply_line("Lane: fast, risk low (x)\nPhase: done\nBuild done.")))
                self.assertEqual(self.raw(), before)

    def test_lane_marker_forms(self):
        for line in ("[Orchestrator] Lane: full, risk high (data model: x)",
                     "- Lane: full, risk high (data model: x)",
                     "[Orchestrator] - Lane: full, risk high (x)",
                     "**Lane: full, risk high (x)**",
                     "`Lane: full, risk high (x)`"):
            with self.subTest(line):
                self.reset()
                self.stop_event(self.transcript(prompt_line("go"), reply_line(line)))
                self.assertEqual(self.read_state().get("risk"), "high")
        for line in ("I said Lane: full, risk low (x)",
                     "[Orchestrator] Lane: full, risk extreme",
                     "-- Lane: full, risk low (x)"):
            with self.subTest(line):
                before = self.reset()
                self.stop_event(self.transcript(prompt_line("go"), reply_line(line)))
                self.assertEqual(self.raw(), before)

    def test_risk_stops_at_other_prompt_past_block(self):
        before = self.reset("high")
        self.stop_event(self.transcript(
            prompt_line("first", "p0"), reply_line("Lane: full, risk low (x)"), reply_line("y" * (70 * 1024)),
            result_line("r", "p0"), result_line("z" * (70 * 1024)),
        ))
        self.assertEqual(self.raw(), before)

    def test_risk_prompt(self):
        for text, level in (("risk low", "low"), (" Risk Normal ", "normal")):
            with self.subTest(text):
                self.reset("high")
                self.prompt(text)
                self.assertEqual(self.read_state().get("risk"), level)
        for text in ("risk low please", "set risk low", "risk extreme", "/stratum:st risk low"):
            with self.subTest(text):
                before = self.reset("high")
                self.prompt(text)
                self.assertEqual(self.raw(), before)
        with self.subTest("linked worktree writes the main checkout only"):
            main, linked = self.make_worktree()
            linked_before = self.read_text(state_path(linked))
            self.prompt("risk low", cwd=linked)
            self.assertEqual(json.loads(self.read_text(state_path(main))).get("risk"), "low")
            self.assertEqual(self.read_text(state_path(linked)), linked_before)
        with self.subTest("label unchanged"):
            self.reset("high")
            self.assertEqual(self.context(self.prompt("risk low"), "UserPromptSubmit"),
                             "Start your reply with [Full lane | Build].")
            self.assertEqual(self.read_state().get("risk"), "low")

    def spec_folders_reset(self, folders, **state):
        shutil.rmtree(os.path.join(self.proj, "specs"), ignore_errors=True)
        for name in folders:
            self.spec_folder(name)
        self.write_state(**state)

    def test_define_before(self):
        with self.subTest("no specs folder"):
            self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
            self.prompt("/stratum:st-define x")
            self.assertEqual(self.read_state()["define_before"], [])
            self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
            self.skill("stratum:st-define", args="x")
            self.assertEqual(self.read_state()["define_before"], [])
        for name in ("015-y", "apps-own-lockfiles", "013-x"):
            self.spec_folder(name)
        self.spec_folder("2420-parasat-area-step", spec=False)
        open(os.path.join(self.proj, "specs", "README.md"), "w").close()
        listed = ["013-x", "015-y", "2420-parasat-area-step", "apps-own-lockfiles"]
        with self.subTest("prompt sets the list"):
            self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
            self.prompt("/stratum:st-define x")
            self.assertEqual(self.read_state()["define_before"], listed)
        with self.subTest("skill sets the list"):
            self.write_state(feature_directory="specs/001-x", phase="build", lane="full")
            self.skill("stratum:st-define", args="x")
            self.assertEqual(self.read_state()["define_before"], listed)
        for args in ("", "  ", None):
            with self.subTest("redo removes the list", args=args):
                self.write_state(feature_directory="specs/013-x", phase="done", lane="full", define_before=listed)
                self.skill("stratum:st-define", args=args)
                self.assertNotIn("define_before", self.read_state())
        with self.subTest("redo prompt removes the list"):
            self.write_state(feature_directory="specs/013-x", phase="done", lane="full", define_before=listed)
            self.prompt("/stratum:st-define")
            self.assertNotIn("define_before", self.read_state())
        with self.subTest("other skills keep the list"):
            self.write_state(feature_directory="specs/001-x", phase="define", lane="full", define_before=listed)
            self.prompt("/stratum:st-plan")
            self.assertEqual(self.read_state()["define_before"], listed)
            self.write_state(feature_directory="specs/001-x", phase="define", lane="full", define_before=listed)
            self.skill("stratum:st-plan")
            self.assertEqual(self.read_state()["define_before"], listed)

    def test_feature_directory_on_define(self):
        old = ["013-x", "015-y"]
        with self.subTest("redo keeps the feature, no list"):
            self.spec_folders_reset(old, phase="define", feature_directory="specs/013-x")
            self.spec_folder("apps-own-lockfiles")
            before = self.raw()
            self.assertEqual(self.post_tool("Write"), "")
            self.assertEqual(self.raw(), before)
        for name in ("apps-own-lockfiles", "2420-parasat-area-step", "012126_max-qty-per-package"):
            for tool in ("Write", "Bash", "Agent"):
                with self.subTest("new define records " + name, tool=tool):
                    self.spec_folders_reset(old, phase="define", define_before=old, feature_directory="specs/013-x")
                    self.spec_folder(name)
                    self.assertEqual(self.post_tool(tool), "")
                    state = self.read_state()
                    self.assertEqual(state["feature_directory"], "specs/" + name)
                    self.assertNotIn("define_before", state)
        with self.subTest("a later new folder does not move the recorded feature"):
            self.spec_folders_reset(old, phase="define", define_before=old)
            self.spec_folder("apps-own-lockfiles")
            self.post_tool("Write")
            self.spec_folder("zzz")
            before = self.raw()
            self.assertEqual(self.post_tool("Write"), "")
            self.assertEqual(self.raw(), before)
            self.assertEqual(self.read_state()["feature_directory"], "specs/apps-own-lockfiles")
        with self.subTest("edit to an older spec changes nothing"):
            self.spec_folders_reset(old, phase="define", define_before=old, feature_directory="specs/013-x")
            before = self.raw()
            self.assertEqual(self.post_tool("Edit"), "")
            self.assertEqual(self.raw(), before)
        with self.subTest("two new folders, the name that sorts last wins"):
            self.spec_folders_reset(old + ["016-a", "016-z"], phase="define", define_before=old)
            self.assertEqual(self.post_tool("Write"), "")
            self.assertEqual(self.read_state().get("feature_directory"), "specs/016-z")
        with self.subTest("plan phase does not record"):
            self.spec_folders_reset(old + ["016-z"], phase="plan", define_before=old)
            before = self.raw()
            self.assertEqual(self.post_tool("Write"), "")
            self.assertEqual(self.raw(), before)
        with self.subTest("folder without spec.md"):
            self.spec_folders_reset(old, phase="define", define_before=old)
            self.spec_folder("017-w", spec=False)
            before = self.raw()
            self.assertEqual(self.post_tool("Write"), "")
            self.assertEqual(self.raw(), before)
        with self.subTest("bad names"):
            self.spec_folders_reset(old + ["new$(x)", "a b"], phase="define", define_before=old)
            before = self.raw()
            self.assertEqual(self.post_tool("Write"), "")
            self.assertEqual(self.raw(), before)
        with self.subTest("status skill and stop while define"):
            self.spec_folders_reset(old + ["016-z"], phase="define", define_before=old)
            before = self.raw()
            self.assertEqual(self.pre_skill("stratum:st-status"), "")
            self.assertEqual(self.stop_event(), "")
            self.assertEqual(self.raw(), before)

    def test_phase_done_marker(self):
        for phase in ("close", "fast", "build"):
            with self.subTest(phase):
                self.write_state(feature_directory="specs/001-x", phase=phase, lane="full")
                self.stop_event(self.transcript(prompt_line("go"), reply_line("Phase: done")))
                self.assertEqual(self.read_state()["phase"], "done")
        with self.subTest("last message alone"):
            self.write_state(feature_directory="specs/001-x", phase="close", lane="full")
            self.stop_event(self.transcript(prompt_line("go"), reply_line("ok")), last="Phase: done")
            self.assertEqual(self.read_state()["phase"], "done")
        rows = {
            "more text on the line": [prompt_line("go"), reply_line("- Phase: done | Lane: full")],
            "text after done": [prompt_line("go"), reply_line("Phase: done and pushed")],
            "tool result": [prompt_line("go"), result_line("Phase: done"), reply_line("ok")],
            "meta line": [prompt_line("go"), meta_line("Phase: done"), reply_line("ok")],
            "earlier turn": [prompt_line("first", "p0"), reply_line("Phase: done"), prompt_line("second"),
                             reply_line("ok")],
        }
        for name, lines in rows.items():
            with self.subTest(name):
                self.write_state(feature_directory="specs/001-x", phase="close", lane="full")
                before = self.raw()
                self.stop_event(self.transcript(*lines))
                self.assertEqual(self.raw(), before)

    def test_build_done_clears_label(self):
        for name in ("st-build", "st-worker"):
            with self.subTest(name):
                self.write_state(feature_directory="specs/001-x", phase="done", lane="none", skill=name,
                                 skill_session="s1")
                self.stop_event(self.transcript(prompt_line("go"), reply_line("Build done.")))
                self.assertEqual(self.read_state()["skill"], "")
                self.assertEqual(self.prompt("what next?").strip(), "")
        rows = {
            "same line as the next step": [prompt_line("go"), reply_line("Build done. Next: /stratum:st-close")],
            "tool result": [prompt_line("go"), result_line("Build done."), reply_line("ok")],
            "earlier turn": [prompt_line("first", "p0"), reply_line("Build done."), prompt_line("second"),
                             reply_line("ok")],
        }
        for name, lines in rows.items():
            with self.subTest(name):
                self.write_state(feature_directory="specs/001-x", phase="done", lane="none", skill="st-build",
                                 skill_session="s1")
                before = self.raw()
                self.stop_event(self.transcript(*lines))
                self.assertEqual(self.raw(), before)

    def test_done_marker_forms(self):
        for line, key, value in (
            ("[Orchestrator] Phase: done", "phase", "done"),
            ("- Phase: done", "phase", "done"),
            ("[Orchestrator] - Phase: done", "phase", "done"),
            ("`Phase: done`", "phase", "done"),
            ("**Phase: done**", "phase", "done"),
            ("Phase: done.", "phase", "done"),
            ("[st-build] Build done.", "skill", ""),
            ("- Build done", "skill", ""),
            ("`Build done.`", "skill", ""),
            ("**Build done.**", "skill", ""),
        ):
            with self.subTest(line):
                self.write_state(feature_directory="specs/001-x", phase="close", lane="full", skill="st-build",
                                 skill_session="s1")
                out = self.stop_event(self.transcript(prompt_line("go"), reply_line(line)))
                self.assertEqual(out, "")
                self.assertEqual(self.read_state()[key], value)
        for line in ("- Phase: done | Lane: full", "[Orchestrator] Phase: done and pushed",
                     "- Build done. Next: /stratum:st-close", "Note: Phase: done", "-- Phase: done"):
            with self.subTest(line):
                self.write_state(feature_directory="specs/001-x", phase="close", lane="full", skill="st-build",
                                 skill_session="s1")
                before = self.raw()
                out = self.stop_event(self.transcript(prompt_line("go"), reply_line(line)))
                self.assertEqual(out, "")
                self.assertEqual(self.raw(), before)


if __name__ == "__main__":
    unittest.main()
