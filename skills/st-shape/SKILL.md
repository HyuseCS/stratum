---
name: st-shape
description: Set the statusline segment shape for this project to arrow, rounded, slanted, blocks, or flat.
---

# /stratum:st-shape <arrow|rounded|slanted|blocks|flat>

1. Accept only `arrow`, `rounded`, `slanted`, `blocks` or `flat`. Anything else, or no value: show
   the five values and stop.
2. In `<project>/.stratum/powerline.json`, set `"shape"` to the value. Keep every other key. Create
   the file as `{"shape": "<value>"}` if it is missing.
3. Reply in one line: `Shape: <value>. It shows on the next statusline refresh.` For `arrow`,
   `rounded` or `slanted`, add: "Needs a Nerd Font."
