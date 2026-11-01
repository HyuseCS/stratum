#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

while IFS='|' read -r id file phrase; do
  check "$id" 'grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
R1|skills/st/SKILL.md|Before the first lane skill or agent starts, Quick too, say it in one line: `Lane: <lane>, risk <level> (<area>: <why>). Say "full", "fast", "quick" or "design" to override. Say "risk high", "risk normal" or "risk low" to change the risk.`
R2|skills/st/SKILL.md|Risk level: High for privacy and access, the data model, contracts, secrets, money, or work that cannot be undone. Normal for other Full work. Low for Fast. None for Quick and Design.
R3|skills/st/SKILL.md|Write the risk (`high`, `normal`, `low` or `none`) with `bash <plugin root>/scripts/st-state.sh "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/state.json" risk <level>`. On the user's "risk <level>", run it again with the new level.
R4|skills/st-build/SKILL.md|The mode comes from `.stratum/advisor.json`: `auto` (the default when the file has no `mode`), `codex`, `both` or `off`.
R5|skills/st-build/SKILL.md|`advisors: codex`: Codex runs. `advisors: both`: Codex runs, then consult `/advisor` on the same input, then hold the talk. `advisors: /advisor`: consult `/advisor` only. `advisors: none`: no advisor at this point, and skip `check plan`.
R6|skills/st-build/SKILL.md|| test red after 2 tries | Codex, then both if still red | Codex | `/advisor` | none |
R7|skills/st-build/SKILL.md|In herdr, with the Stratum Codex home in place, Codex runs as the `st-codex-<NNN>` agent in the `Codex` tab of this workspace, read-only and never asking, and the user can watch it there. Otherwise it runs in the background as before.
R8|skills/st-build/SKILL.md|At a High point both advisors first answer alone. Then hold the talk: at most 3 rounds of `bash <plugin root>/scripts/st-advisor.sh round <point> <feature dir> <n> <views file>`, each with `/advisor`'s answer to the same views.
R9|skills/st-build/SKILL.md|In round 3 each advisor proposes a compromise for every open point. A compromise both accept is a combined finding. A point with no compromise both accept goes to the user with both views, in short, simple words.
R10|skills/st-build/SKILL.md|If one advisor has no answer (`no advisor`, mode off), the point runs with the one left, and the talk record says so.
R11|skills/st-build/SKILL.md|After the talk, record it: `bash <plugin root>/scripts/st-advisor.sh talk <point> <feature dir> <file>` with the rounds, the agreed points, the compromises, the points sent to the user and the calls.
R12|skills/st/SKILL.md|Write each small decision in a list as you make it. At each story review, and at the end of a Fast change, the list goes to the advisors the matrix names. A decision an advisor sends to the user is undone if the user says no.
R13|skills/st-build/SKILL.md|Send the story's small-decision list to the advisors: `bash <plugin root>/scripts/st-advisor.sh decisions <feature dir> <list file>`.
R14|skills/st-fast/SKILL.md|At the end of the change, send the small-decision list to `/advisor` if one is set. A decision it sends to the user is undone if the user says no.
R15|skills/st-init/SKILL.md|advisor mode `auto` (recommended: the risk level picks Codex, `/advisor` or both at each point; needs `codex` logged in for Codex), `codex` (Codex reviews the plan and a test red after 2 tries), `both` (Codex, then `/advisor` if set), or `off` (no Codex, nothing sent to OpenAI)?
R16|README.md|`{"mode": "auto"}` (the default when the file has no `mode`): the risk level picks the advisors at each point.
R17|README.md|Inside herdr, Codex runs as an agent in a `Codex` tab of your workspace, read-only and never asking, so you can watch it. The tab uses Stratum's own Codex home, `~/.local/state/stratum/codex-home`, which holds only a link to your Codex login and a `config.toml` that marks the project untrusted: your `~/.codex/config.toml`, `~/.codex/hooks.json` and a project's `.codex/config.toml` do not load there, and the model comes from `.stratum/advisor.json`.
R19|skills/st-init/SKILL.md|If the answer is `auto`, `codex` or `both`, run `bash <plugin root>/scripts/st-advisor.sh codex-home` and show its line word for word.
R20|skills/st-build/SKILL.md|When the user asks to add a Codex advisor, or sets a mode that uses Codex, run `bash <plugin root>/scripts/st-advisor.sh codex-home` and show its line word for word. Never run it on your own.
R18|README.md|With no file the advisor is off and prints `no advisor: mode not set. Write .stratum/advisor.json with "mode": "auto", "codex", "both" or "off".`
R21|README.md|The background call runs with `--ignore-user-config`: neither `~/.codex/config.toml` nor a project `.codex/config.toml` is read
K1|skills/st-build/SKILL.md|First line `mode both: also consult /advisor if one is set`
TABLE

while IFS='|' read -r id file phrase; do
  check "$id gone" '[ -f "$root/$file" ] && ! grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
G1|skills/st-build/SKILL.md|It runs at two points
G2|skills/st-build/SKILL.md|The mode comes from `.stratum/advisor.json` (`codex`, `both` or `off`).
G3|skills/st/SKILL.md|Lane: <lane> (<area>: <why>).
G4|skills/st-init/SKILL.md|advisor mode `codex` (recommended
TABLE

exit $fail
