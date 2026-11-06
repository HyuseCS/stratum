#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import tempfile

BEFORE = {"plan": "define", "inspect": "plan", "build": "inspect", "close": "build"}
LABEL = {p: f"[Full lane | {p.title()}]" for p in ("define", "plan", "inspect", "build", "close")}
LABEL.update(fast="[Fast lane]", quick="[Quick lane]")
PHASES = ("define", "plan", "inspect", "build", "close", "fast", "quick", "full")
HELD = ("build", "worker")
NAME = re.compile(r"/stratum:st-([a-z][a-z-]*)(?:\s|$)")
SKILLS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "skills")
PRE = r"^(?:\[[^\]\n]*\][ \t]*)?(?:- )?(?:\*\*|`)?"
RISK = re.compile(PRE + r"Lane: [A-Za-z]+, risk ((?i:high|normal|low|none))\b", re.M)
ASK = re.compile(r"\s*risk (high|normal|low|none)\s*", re.I)
DONE = re.compile(PRE + r"Phase: done\.?(?:\*\*|`)?[ \t]*$", re.M)
CLEAR = re.compile(PRE + r"Build done\.?(?:\*\*|`)?[ \t]*$", re.M)
SPEC = re.compile(r"[A-Za-z0-9._-]+")


def turn_text(path, pid):
    texts = []
    mine = 0
    try:
        with open(path, "rb") as f:
            pos = end = f.seek(0, 2)
            rest = b""
            # ponytail: a turn past 16 MiB loses its oldest replies, raise the cap if real turns get that long
            while pos and end - pos < 16 << 20:
                n = min(1 << 16, pos)
                pos -= n
                f.seek(pos)
                lines = (f.read(n) + rest).split(b"\n")
                rest = lines.pop(0) if pos else b""
                for raw in reversed(lines):
                    try:
                        line = json.loads(raw)
                        kind, content = line.get("type"), line["message"]["content"]
                    except Exception:
                        continue
                    if line.get("isSidechain") is True:
                        continue
                    if kind == "user" and pid and line.get("promptId") == pid:
                        mine = len(texts)
                    if kind == "user" and pid and line.get("promptId") and line["promptId"] != pid:
                        return "\n".join(reversed(texts[:mine]))
                    if kind == "user" and line.get("isMeta") is not True and (isinstance(content, str) or (
                            isinstance(content, list) and any(not isinstance(b, dict) or b.get("type") != "tool_result"
                                                              for b in content))):
                        return "\n".join(reversed(texts))
                    if kind == "assistant" and isinstance(content, list):
                        texts += [b["text"] for b in reversed(content) if isinstance(b, dict)
                                  and b.get("type") == "text" and isinstance(b.get("text"), str)]
    except Exception:
        return ""
    return "\n".join(reversed(texts))


def folders(root):
    try:
        return [e.name for e in os.scandir(os.path.join(root, "specs")) if e.is_dir()]
    except OSError:
        return []


def save(path, state):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".state-")
    with os.fdopen(fd, "w") as f:
        f.write(json.dumps(state, indent=2) + "\n")
    os.replace(tmp, path)


def main():
    try:
        data = json.load(sys.stdin.buffer)
        event = data.get("hook_event_name")
        tool = data.get("tool_name")
        prompt = event == "UserPromptSubmit"
        m = None
        if prompt or tool == "Skill":
            m = NAME.match(data.get("prompt").lstrip() if prompt else "/" + (data.get("tool_input") or {}).get("skill"))
        if m and m.group(1) not in PHASES and not os.path.isfile(os.path.join(SKILLS, "st-" + m.group(1), "SKILL.md")):
            m = None
    except Exception:
        return
    cwd = d = data.get("cwd") or os.getcwd()
    while not os.path.isdir(os.path.join(d, ".stratum")) and not os.path.exists(os.path.join(d, ".git")) \
            and os.path.dirname(d) != d:
        d = os.path.dirname(d)
    path = os.path.join(d, ".stratum", "state.json")
    try:
        state = json.load(open(path, "rb"))
        old = state.get("phase")
        loaded = dict(state)
    except Exception:
        if not os.path.isdir(os.path.join(d, ".stratum")) and not os.path.isfile(os.path.join(d, ".git")):
            return
        state = None
    text = ""
    if not data.get("agent_id") and (event == "Stop" or tool == "Agent" or (tool == "Skill" and event == "PreToolUse")):
        text = turn_text(data.get("transcript_path"), data.get("prompt_id"))
        if event == "Stop" and isinstance(data.get("last_assistant_message"), str):
            text += "\n" + data["last_assistant_message"]
    ask = prompt and ASK.fullmatch(data["prompt"])
    risk = [ask.group(1)] if ask else RISK.findall(text)
    if risk:
        risk, top = risk[-1].lower(), path
        try:
            r = subprocess.run(["git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                               capture_output=True, text=True, timeout=3)
            if r.returncode == 0:
                top = os.path.join(os.path.dirname(r.stdout.strip()), ".stratum", "state.json")
        except Exception:
            pass
        if state is not None and os.path.realpath(top) == os.path.realpath(path):
            state["risk"] = risk
        else:
            try:
                other = json.load(open(top, "rb"))
                stale = other.get("risk") != risk
            except Exception:
                stale = False
            if stale:
                other["risk"] = risk
                save(top, other)
    if state is None:
        return
    if DONE.search(text):
        state["phase"] = "done"
    if CLEAR.search(text):
        state["skill"] = ""
    old = state.get("phase")
    seen = state.get("define_before")
    if event == "PostToolUse" and old == "define" and isinstance(seen, list):
        found = [n for n in folders(d) if n not in seen and SPEC.fullmatch(n)
                 and os.path.isfile(os.path.join(d, "specs", n, "spec.md"))]
        if found:
            state["feature_directory"] = "specs/" + max(found)
            del state["define_before"]
    notes = []
    sid = data.get("session_id")
    name = m and m.group(1)
    if name in HELD and old not in LABEL:
        state.update(lane="none", skill="st-" + name, skill_session=sid)
    elif name in PHASES and (name in ("define", "fast", "quick", "full") or state.get("feature_directory")):
        phase = name
        if phase != "full":
            state["phase"] = phase
        elif old in ("fast", "quick"):
            state["phase"] = None
        if phase == "define":
            desc = data["prompt"].lstrip()[m.end():] if prompt else (data.get("tool_input") or {}).get("args")
            if isinstance(desc, str) and desc.strip():
                state["define_before"] = sorted(folders(d))
            else:
                state.pop("define_before", None)
        if phase in ("fast", "quick"):
            state["lane"] = phase
        elif phase in ("define", "full") or state.get("lane") in (None, "", "none"):
            state["lane"] = "full"
        if phase in BEFORE and old not in (BEFORE[phase], phase):
            notes.append(f"Stratum: phase {phase} started out of order (was {old}, expected "
                         f"{BEFORE[phase]} or {phase}). Warn the user once in one line, then run.")
    if state != loaded:
        save(path, state)
    lane, phase = state.get("lane"), state.get("phase")
    label = None
    if phase in LABEL:
        label = LABEL[lane] if lane in ("fast", "quick") else LABEL[phase]
    elif name and name not in PHASES:
        label = f"[st-{name}]"
    elif lane == "none" and state.get("skill") and state.get("skill_session") == sid:
        label = f"[{state['skill']}]"
    if prompt and label:
        notes.insert(0, f"Start your reply with {label}.")
    if notes:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": " ".join(notes)}}))


if __name__ == "__main__":
    main()
