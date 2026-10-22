---
name: st-ponytail-help
description: >
  Quick reference for ponytail levels, skills and commands. One-shot display.
  Use for /st-ponytail-help, "ponytail help", "how do I use ponytail".
---

# Ponytail Help

Display this reference card when invoked. One-shot, do NOT change mode,
write flag files, or persist anything.

## Levels

| Level | Trigger | What change |
|-------|---------|-------------|
| **Lite** | `/st-ponytail lite` | Build what was asked, name the smaller option in one line. |
| **Full** | `/st-ponytail` | The smallest complete change, a check where the logic needs one, and a reply that names what was skipped and any risk. Default. |
| **Ultra** | `/st-ponytail ultra` | Also questions the request and pushes back before building. |

Level sticks until changed or session end.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **ponytail** | `/st-ponytail` | Lazy mode itself: least new code, clear replies that name skipped work and risks. |
| **st-ponytail-review** | `/st-ponytail-review` | Quality review of a diff: bugs, security, load, missing tests, speed, what to cut. Each finding says what goes wrong and how to fix it. |
| **st-ponytail-audit** | `/st-ponytail-audit` | The same quality review for the whole repo, ranked. |
| **st-ponytail-debt** | `/st-ponytail-debt` | Harvest `ponytail:` comments into a tracked ledger. |
| **st-ponytail-gain** | `/st-ponytail-gain` | Measured-impact scoreboard: less code, less cost, more speed. |
| **st-ponytail-help** | `/st-ponytail-help` | This card. |

In Codex CLI and the IDE extension, invoke skills with `$stratum:st-ponytail`,
`$stratum:st-ponytail-review`, or `$stratum:st-ponytail-help`. Claude Code and OpenCode use the
slash-command forms above (OpenCode ships all six as slash commands).

## Deactivate

Say "stop ponytail" or "normal mode". Resume anytime with `/st-ponytail`.
`/st-ponytail off` also works.

## Configure Default Mode

Default mode = `full`, auto-active every session. Change it:

**Environment variable** (highest priority):
```bash
export PONYTAIL_DEFAULT_MODE=ultra
```

**Config file** (`~/.config/ponytail/config.json`, Windows: `%APPDATA%\ponytail\config.json`):
```json
{ "defaultMode": "lite" }
```

Set `"off"` to disable auto-activation on session start, activate manually
with `/st-ponytail` when wanted.

Resolution: env var > config file > `full`.

## Update

Enable auto-update once: open `/plugin`, go to Marketplaces, pick ponytail, Enable auto-update. Claude Code then pulls new versions at startup (run `/reload-plugins` when it prompts). Manual refresh: `/plugin marketplace update ponytail` then `/reload-plugins`.

If `/plugin` is not recognized, your Claude Code is out of date. Update it (`npm install -g @anthropic-ai/claude-code@latest`, or `brew upgrade claude-code`) and restart. Other hosts use their own update flow.

## More

Full docs + examples: https://github.com/DietrichGebert/ponytail
