#!/usr/bin/env python3
import json
import os
import sys

MODELS = ["sonnet", "opus", "haiku", "fable"]
EFFORTS = ["low", "medium", "high", "xhigh", "max"]
AGENTS = sorted(f[:-3] for f in os.listdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "agents"))
                if f.endswith(".md"))


def problems(models):
    if not isinstance(models, dict):
        return ["the file must be a JSON object that maps agent names to settings."]
    out = []
    for agent, entry in models.items():
        name = json.dumps(agent)[:80]
        if agent not in AGENTS:
            out.append(f"unknown agent {name}. Allowed agents: {', '.join(AGENTS)}.")
        elif not isinstance(entry, dict):
            out.append(f"{name} must be an object with optional keys model, effort.")
        else:
            for key, value in entry.items():
                allowed = {"model": MODELS, "effort": EFFORTS}.get(key)
                if allowed is None:
                    out.append(f"unknown key {json.dumps(key)[:80]} for {name}. Allowed keys: model, effort.")
                elif value not in allowed:
                    out.append(f"unknown {key} {json.dumps(value)[:80]} for {name}. "
                               f"Allowed: {', '.join(allowed)}.")
    return out


def deny(path, found):
    if len(found) > 10:
        found = found[:10] + [f"... and {len(found) - 10} more."]
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": f"{path}: " + "\n".join(found) + "\nFix the file, then run the step again.",
    }}))


def main():
    try:
        data = json.load(sys.stdin.buffer)
        tool_input = data.get("tool_input") or {}
        agent = tool_input.get("subagent_type") or ""
        if not agent.startswith("stratum:"):
            return
    except Exception:
        return
    d = data.get("cwd") or os.getcwd()
    while not os.path.isdir(os.path.join(d, ".stratum")) and not os.path.exists(os.path.join(d, ".git")) \
            and os.path.dirname(d) != d:
        d = os.path.dirname(d)
    path = os.path.join(d, ".stratum", "models.json")
    try:
        models = json.load(open(path, "rb"))
    except FileNotFoundError:
        return
    except Exception as e:
        return deny(path, [f"cannot be read: {e}"])
    try:
        found = problems(models)
    except Exception as e:
        found = [f"cannot be checked: {e}"]
    if found:
        return deny(path, found)
    entry = models.get(agent[len("stratum:"):])
    if not entry:
        return
    updated = dict(tool_input)
    for key in ("model", "effort"):
        if key in entry:
            updated[key] = entry[key]
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": updated}}))


if __name__ == "__main__":
    main()
