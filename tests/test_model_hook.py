import glob
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AGENT_NAMES = sorted(os.path.basename(f)[:-3] for f in glob.glob(os.path.join(ROOT, "agents", "*.md")))
HOOK = os.environ.get("ST_MODELS_HOOK") or os.path.join(ROOT, "hooks", "st-models.py")


class ModelHookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.proj = self.tmp.name
        os.makedirs(os.path.join(self.proj, ".stratum"))

    def tearDown(self):
        self.tmp.cleanup()

    def write_models(self, text):
        with open(os.path.join(self.proj, ".stratum", "models.json"), "w") as f:
            f.write(text)

    def run_hook(self, tool_input, cwd=None):
        payload = json.dumps({"cwd": cwd or self.proj, "tool_name": "Agent",
                              "tool_input": tool_input})
        r = subprocess.run([sys.executable, HOOK], input=payload,
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def rewrite(self, tool_input, cwd=None):
        out = self.run_hook(tool_input, cwd)
        self.assertTrue(out.strip(), "expected a rewrite, got empty stdout")
        return json.loads(out)["hookSpecificOutput"]

    def call(self, **extra):
        return {"description": "d", "prompt": "p", "subagent_type": "stratum:st-close", **extra}

    def test_model_only(self):
        self.write_models('{"st-close": {"model": "haiku"}}')
        out = self.rewrite(self.call())
        self.assertEqual(out["updatedInput"]["model"], "haiku")
        self.assertNotIn("effort", out["updatedInput"])

    def test_effort_only_keeps_model(self):
        self.write_models('{"st-validate": {"effort": "high"}}')
        ti = self.call(subagent_type="stratum:st-validate", model="sonnet")
        out = self.rewrite(ti)["updatedInput"]
        self.assertEqual(out["effort"], "high")
        self.assertEqual(out["model"], "sonnet")
        ti = self.call(subagent_type="stratum:st-validate")
        out = self.rewrite(ti)["updatedInput"]
        self.assertEqual(out["effort"], "high")
        self.assertNotIn("model", out)

    def test_file_replaces_call_model(self):
        self.write_models('{"st-close": {"model": "haiku"}}')
        out = self.rewrite(self.call(model="sonnet"))
        self.assertEqual(out["updatedInput"]["model"], "haiku")

    def test_other_fields_kept(self):
        self.write_models('{"st-close": {"model": "haiku", "effort": "low"}}')
        ti = self.call(model="sonnet", foo=1, run_in_background=True)
        out = self.rewrite(ti)["updatedInput"]
        want = {**ti, "model": "haiku", "effort": "low"}
        self.assertEqual(out, want)

    def test_output_shape(self):
        self.write_models('{"st-close": {"model": "haiku"}}')
        out = self.rewrite(self.call())
        self.assertEqual(out["hookEventName"], "PreToolUse")
        self.assertNotIn("permissionDecision", out)

    def test_silent_cases(self):
        self.assertEqual(self.run_hook(self.call()).strip(), "")
        self.write_models('{"st-git": {"model": "haiku"}}')
        self.assertEqual(self.run_hook(self.call()).strip(), "")
        self.write_models('{"st-close": {}}')
        self.assertEqual(self.run_hook(self.call()).strip(), "")

    def test_found_from_subfolder(self):
        self.write_models('{"st-close": {"model": "haiku"}}')
        sub = os.path.join(self.proj, "deep", "er")
        os.makedirs(sub)
        out = self.rewrite(self.call(), cwd=sub)
        self.assertEqual(out["updatedInput"]["model"], "haiku")

    def test_non_stratum_agents_ignored(self):
        self.write_models('{"st-close": {"model": "haiku"}}')
        for ti in ({"description": "d", "prompt": "p", "subagent_type": "Explore"},
                   {"description": "d", "prompt": "p", "subagent_type": "st-close"},
                   {"description": "d", "prompt": "p"}):
            self.assertEqual(self.run_hook(ti).strip(), "", ti)

    def deny(self, text, tool_input=None):
        self.write_models(text)
        out = json.loads(self.run_hook(tool_input or self.call()))["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], "PreToolUse")
        self.assertEqual(out["permissionDecision"], "deny")
        self.assertNotIn("updatedInput", out)
        reason = out["permissionDecisionReason"]
        self.assertIn(".stratum/models.json", reason)
        self.assertIn("Fix the file, then run the step again.", reason)
        return reason

    def test_deny_unreadable(self):
        r = self.deny("{not json")
        self.assertIn("cannot be read", r)
        self.assertIn("Expecting", r)

    def test_deny_not_object(self):
        self.assertIn("must be a JSON object", self.deny("[1]"))

    def test_deny_unknown_agent(self):
        r = self.deny('{"st-nope": {"model": "haiku"}}')
        self.assertIn("st-nope", r)
        for a in AGENT_NAMES:
            self.assertIn(a, r)

    def test_deny_entry_not_object(self):
        r = self.deny('{"st-close": "haiku"}')
        for w in ("st-close", "model", "effort"):
            self.assertIn(w, r)

    def test_deny_unknown_key(self):
        r = self.deny('{"st-close": {"modle": "haiku"}}')
        for w in ("modle", "st-close", "model", "effort"):
            self.assertIn(w, r)

    def test_deny_unknown_model(self):
        r = self.deny('{"st-close": {"model": "gpt"}}')
        for w in ("gpt", "st-close", "sonnet", "opus", "haiku", "fable"):
            self.assertIn(w, r)

    def test_deny_unknown_effort(self):
        r = self.deny('{"st-close": {"effort": "ultra"}}')
        for w in ("ultra", "st-close", "low", "medium", "high", "xhigh", "max"):
            self.assertIn(w, r)

    def test_deny_checks_whole_file_for_other_agent(self):
        r = self.deny('{"st-git": {"model": "gpt"}, "st-close": {"model": "haiku"}}')
        self.assertIn("gpt", r)

    def test_deny_one_line_per_problem(self):
        r = self.deny('{"st-a": {}, "st-b": {}}')
        self.assertIn("st-a", r)
        self.assertIn("st-b", r)
        lines = r.split("\n")
        self.assertEqual(len(lines), 3)
        self.assertTrue(lines[0].count("st-") >= 1)

    def test_deny_long_value_cut(self):
        r = self.deny('{"st-close": {"model": "%s"}}' % ("x" * 500))
        self.assertNotIn("x" * 100, r)

    def test_deny_model_not_string(self):
        r = self.deny('{"st-close": {"model": 1}}')
        self.assertIn("st-close", r)

    def test_deny_models_json_is_folder(self):
        os.makedirs(os.path.join(self.proj, ".stratum", "models.json"))
        out = json.loads(self.run_hook(self.call()))["hookSpecificOutput"]
        self.assertEqual(out["permissionDecision"], "deny")
        self.assertIn("cannot be read", out["permissionDecisionReason"])

    def test_deny_prompt_key(self):
        r = self.deny('{"st-close": {"prompt": "x"}}')
        self.assertIn("prompt", r)

    def test_deny_long_agent_name_cut(self):
        r = self.deny('{"%s": {}}' % ("a" * 500))
        self.assertLess(len(r), 600)
        self.assertNotIn("a" * 500, r)

    def test_deny_ignores_non_stratum_agent(self):
        self.write_models("{bad")
        ti = {"description": "d", "prompt": "p", "subagent_type": "Explore"}
        self.assertEqual(self.run_hook(ti).strip(), "")

    def test_valid_file_not_denied(self):
        self.write_models('{"st-close": {"model": "fable", "effort": "max"}}')
        self.assertEqual(self.rewrite(self.call())["updatedInput"]["effort"], "max")

    def test_module_constants(self):
        spec = importlib.util.spec_from_file_location("st_models", HOOK)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertEqual(set(mod.AGENTS), set(AGENT_NAMES))
        self.assertEqual(len(AGENT_NAMES), 11)
        self.assertEqual(set(mod.MODELS), {"sonnet", "opus", "haiku", "fable"})
        self.assertEqual(set(mod.EFFORTS), {"low", "medium", "high", "xhigh", "max"})

    def test_hook_registered(self):
        with open(os.path.join(ROOT, "hooks", "commands.json")) as f:
            entries = json.load(f)["hooks"]["PreToolUse"]
        agent = [e for e in entries if e.get("matcher") == "Agent"]
        self.assertEqual(len(agent), 1)
        cmds = [h["command"] for h in agent[0]["hooks"]]
        self.assertIn('python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-models.py"', cmds)


if __name__ == "__main__":
    unittest.main()
