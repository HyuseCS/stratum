---
name: st-theme
description: Set the color theme of the statusline and the Token Weather band for this project to rose-pine, nord, tokyo-night, gruvbox, dark, light, or custom.
---

# /stratum:st-theme <rose-pine|nord|tokyo-night|gruvbox|dark|light|custom>

1. Accept only `rose-pine`, `nord`, `tokyo-night`, `gruvbox`, `dark`, `light` or `custom`.
   Anything else, or no value: show the seven values and stop.
2. In `<project>/.stratum/powerline.json`, set `"theme"` to the value. Keep every other key,
   including `colors`. Create the file as `{"theme": "<value>"}` if it is missing.
3. Reply in one line: `Theme: <value>. The statusline changes on its next refresh, the Token
   Weather band after the next turn.` For `custom`,
   add: "Set colors under `colors.custom`; keys you leave out keep rose-pine. See the README,
   Statusline colors."
