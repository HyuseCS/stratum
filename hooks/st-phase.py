#!/usr/bin/env python3
import json
import os
import re
import sys
import tempfile

BEFORE = {"plan": "define", "inspect": "plan", "build": "inspect", "close": "build"}
LABEL = {p: f"[Full lane | {p.title()}]" for p in ("define", "plan", "inspect", "build", "close")}
LABEL.update(fast="[Fast lane]", quick="[Quick lane]")
PHASES = ("define", "plan", "inspect", "build", "close", "fast", "quick", "full")
HELD = ("build", "worker")
NAME = re.compile(r"/stratum:st-([a-z][a-z-]*)(?:\s|$)")
SKILLS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "skills")


def main():
    try:
        data = json.load(sys.stdin.buffer)
        event = data.get("hook_event_name")
        prompt = event == "UserPromptSubmit"
        m = NAME.match(data.get("prompt").lstrip() if prompt else "/" + (data.get("tool_input") or {}).get("skill"))
        if m and m.group(1) not in PHASES and not os.path.isfile(os.path.join(SKILLS, "st-" + m.group(1), "SKILL.md")):
            m = None
        if not m and not prompt:
            return
    except Exception:
        return
    d = data.get("cwd") or os.getcwd()
    while not os.path.isdir(os.path.join(d, ".stratum")) and not os.path.exists(os.path.join(d, ".git")) \
            and os.path.dirname(d) != d:
        d = os.path.dirname(d)
    path = os.path.join(d, ".stratum", "state.json")
    try:
        state = json.load(open(path, "rb"))
        old = state.get("phase")
    except Exception:
        return
    notes = []
    sid = data.get("session_id")
    name = m and m.group(1)
    write = False
    if name in HELD and old not in LABEL:
        state.update(lane="none", skill="st-" + name, skill_session=sid)
        write = True
    elif name in PHASES and (name in ("define", "fast", "quick", "full") or state.get("feature_directory")):
        phase = name
        if phase != "full":
            state["phase"] = phase
        elif old in ("fast", "quick"):
            state["phase"] = None
        if phase in ("fast", "quick"):
            state["lane"] = phase
        elif phase in ("define", "full") or state.get("lane") in (None, "", "none"):
            state["lane"] = "full"
        write = True
        if phase in BEFORE and old not in (BEFORE[phase], phase):
            notes.append(f"Stratum: phase {phase} started out of order (was {old}, expected "
                         f"{BEFORE[phase]} or {phase}). Warn the user once in one line, then run.")
    if write:
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".state-")
        with os.fdopen(fd, "w") as f:
            f.write(json.dumps(state, indent=2) + "\n")
        os.replace(tmp, path)
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
