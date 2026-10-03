---
name: st-ponytail-help
description: >
  Quick-reference card for all ponytail modes, skills, and commands.
  One-shot display, not a persistent mode. Trigger: /st-ponytail-help,
  "ponytail help", "what ponytail commands", "how do I use ponytail".
---

# Ponytail Help

Display this reference card when invoked. One-shot, do NOT change mode,
write flag files, or persist anything.

## Levels

| Level | Trigger | What change |
|-------|---------|-------------|
| **Lite** | `/st-ponytail lite` | Build what's asked, name the lazier alternative in one line. |
| **Full** | `/st-ponytail` | The ladder enforced: YAGNI → stdlib → native → one line → minimum. Default. |
| **Ultra** | `/st-ponytail ultra` | YAGNI extremist. Deletion before addition. Challenges requirements before building. |

Level sticks until changed or session end.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **ponytail** | `/st-ponytail` | Lazy mode itself. Simplest solution that works. |
| **st-ponytail-review** | `/st-ponytail-review` | Over-engineering review: `L42: yagni: factory, one product. Inline.` |
| **st-ponytail-audit** | `/st-ponytail-audit` | Whole-repo over-engineering audit: ranked list of what to delete. |
| **st-ponytail-debt** | `/st-ponytail-debt` | Harvest `ponytail:` shortcut comments into a tracked ledger. |
| **st-ponytail-gain** | `/st-ponytail-gain` | Measured-impact scoreboard: less code, less cost, more speed. |
| **st-ponytail-help** | `/st-ponytail-help` | This card. |

In Codex CLI and the IDE extension, invoke skills with `$ponytail`,
`$st-ponytail-review`, or `$st-ponytail-help`. Claude Code and OpenCode use the
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
