import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
HOOK = os.path.join(ROOT, "hooks", "st-phase.py")
CMD = 'python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-phase.py"'


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
        r = subprocess.run([sys.executable, HOOK], input=payload, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def prompt(self, text, cwd=None):
        return self.run_hook({"hook_event_name": "UserPromptSubmit", "prompt": text}, cwd)

    def skill(self, name):
        return self.run_hook({"hook_event_name": "PreToolUse", "tool_name": "Skill",
                              "tool_input": {"skill": name, "args": "x"}})

    def context(self, out, event):
        out = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], event)
        self.assertNotIn("permissionDecision", out)
        self.assertEqual(len(out["additionalContext"].splitlines()), 1)
        return out["additionalContext"]

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
        for text in ("/stratum:st-status", "/stratum:st", "/stratum:st-planner", "please run /stratum:st-build", "stratum:st-plan",
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
        self.assertEqual(self.read_state(), {"feature_directory": "specs/001-x", "phase": "define", "lane": "full"})

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
        with open(os.path.join(ROOT, "skills", "st-close", "SKILL.md")) as f:
            self.assertIn(phrase, f.read())
        with open(os.path.join(ROOT, "skills", "st-fast", "SKILL.md")) as f:
            self.assertIn(phrase, f.read())

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
        skill = [e for e in hooks["PreToolUse"] if e.get("matcher") == "Skill"]
        self.assertEqual(len(skill), 1)
        self.assertIn(CMD, [h["command"] for h in skill[0]["hooks"]])
        self.assertIn(CMD, [h["command"] for e in hooks["UserPromptSubmit"] for h in e["hooks"]])


if __name__ == "__main__":
    unittest.main()
