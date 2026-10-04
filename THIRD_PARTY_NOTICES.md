# Third-Party Notices

Stratum is MIT licensed (see `LICENSE`). It contains modified copies of the works below. Each
keeps its original license. Full license texts are in `licenses/`. Pinned upstream commits are in
`vendor.lock`.

| Work | Copyright | License | Stratum location | License text |
|------|-----------|---------|------------------|--------------|
| GitHub Spec Kit | Copyright GitHub, Inc. | MIT | `templates/`, `scripts/`, phase skills | `licenses/spec-kit.MIT.txt` |
| vibecode-pro-max-kit | Copyright (c) 2026 vibecode | MIT | `agents/st-*.md` | `licenses/vibecode-pro-max-kit.MIT.txt` |
| ponytail | Copyright (c) 2026 DietrichGebert | MIT | `skills/st-ponytail*`, `hooks/ponytail/` | `licenses/ponytail.MIT.txt` |
| mattpocock/skills (grilling, grill-me) | Copyright (c) 2026 Matt Pocock | MIT | `skills/st-grill` | `licenses/mattpocock-skills.MIT.txt` |
| ui-ux-pro-max | Copyright (c) 2024 Next Level Builder | MIT | `skills/st-ui-ux` | `licenses/ui-ux-pro-max.MIT.txt` |
| impeccable | Copyright 2025 Paul Bakaus | Apache-2.0 | `skills/st-impeccable` | `licenses/impeccable.Apache-2.0.txt`, `licenses/impeccable.NOTICE.md` |
| frontend-design | anthropics/claude-plugins-official authors | Apache-2.0 | `skills/st-frontend-design` | `licenses/frontend-design.Apache-2.0.txt` |
| graphify skill | Copyright 2026 Safi Shamsi and the Graphify contributors | Apache-2.0 (earlier parts MIT) | `skills/st-graphify` | `licenses/graphify.Apache-2.0.txt`, `licenses/graphify.NOTICE.txt`, `licenses/graphify.MIT.txt` |
| Token Weather | anthropics/claude-code-playground authors | Apache-2.0 | `hooks/token-weather.mjs`, `statusline/st-statusline.sh` (third line) | `licenses/claude-code-playground.Apache-2.0.txt` |
| claude-powerline theme colors | Copyright (c) 2025 Owloops | MIT | `statusline/themes.json` | `licenses/claude-powerline.MIT.txt` |

## Changes made by Stratum (Apache-2.0 section 4(b))

- **impeccable, frontend-design, ui-ux-pro-max, graphify skill:** renamed to `st-*` skill names and
  given Stratum's navigation and reporting rules. The design guidance itself is unchanged.
- **Token Weather:** the mod no longer draws. It writes the auto-compact threshold and mean growth
  to `.stratum/weather.json`, and the statusline draws the forecast as its third line, in the
  statusline theme, with a fill bar instead of the turn chart and an estimate of turns left.
- **Spec Kit:** paths changed from `.specify/` to `.stratum/` and the plugin folder; commands merged
  into Stratum's phase skills.
- **vibecode-pro-max-kit agents:** rewritten to read Spec Kit-style `specs/` files instead of the
  `process/` tree; renamed to `st-*`.
