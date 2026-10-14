#!/usr/bin/env python3
import json
import os
import re
import sys

BEFORE = {"plan": "define", "inspect": "plan", "build": "inspect", "close": "build"}
NAME = re.compile(r"/stratum:st-(define|plan|inspect|build|close)(?:\s|$)")


def main():
    try:
        data = json.load(sys.stdin.buffer)
        event = data.get("hook_event_name")
        text = data.get("prompt") if event == "UserPromptSubmit" else (data.get("tool_input") or {}).get("skill")
        m = NAME.match(text.lstrip() if event == "UserPromptSubmit" else "/" + text)
        if not m:
            return
    except Exception:
        return
    phase = m.group(1)
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
    if phase != "define" and not state.get("feature_directory"):
        return
    state["phase"] = phase
    with open(path, "w") as f:
        f.write(json.dumps(state, indent=2) + "\n")
    if phase in BEFORE and old not in (BEFORE[phase], phase):
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": event,
            "additionalContext": f"Stratum: phase {phase} started out of order (was {old}, expected "
                                 f"{BEFORE[phase]} or {phase}). Warn the user once in one line, then run.",
        }}))


if __name__ == "__main__":
    main()
