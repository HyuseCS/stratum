#!/usr/bin/env python3
import json
import os
import re
import sys

BEFORE = {"plan": "define", "inspect": "plan", "build": "inspect", "close": "build"}
LABEL = {p: f"[Full lane | {p.title()}]" for p in ("define", "plan", "inspect", "build", "close")}
LABEL.update(fast="[Fast lane]", quick="[Quick lane]")
NAME = re.compile(r"/stratum:st-(define|plan|inspect|build|close)(?:\s|$)")


def main():
    try:
        data = json.load(sys.stdin.buffer)
        event = data.get("hook_event_name")
        prompt = event == "UserPromptSubmit"
        m = NAME.match(data.get("prompt").lstrip() if prompt else "/" + (data.get("tool_input") or {}).get("skill"))
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
    if m and (m.group(1) == "define" or state.get("feature_directory")):
        phase = m.group(1)
        state["phase"] = phase
        with open(path, "w") as f:
            f.write(json.dumps(state, indent=2) + "\n")
        if phase in BEFORE and old not in (BEFORE[phase], phase):
            notes.append(f"Stratum: phase {phase} started out of order (was {old}, expected "
                         f"{BEFORE[phase]} or {phase}). Warn the user once in one line, then run.")
    if prompt and state.get("phase") in LABEL:
        notes.insert(0, f"Start your reply with {LABEL[state['phase']]}.")
    if notes:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": " ".join(notes)}}))


if __name__ == "__main__":
    main()
