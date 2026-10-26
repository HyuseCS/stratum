#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
report() { if [ "$ok" = 1 ]; then echo "ok   $cur"; else echo "FAIL $cur"; fail=1; fi; }
phrases() {
  cur=""; ok=1
  while IFS=$'\t' read -r name target phrase; do
    if [ "$name" != "$cur" ]; then
      [ -n "$cur" ] && report
      cur=$name; ok=1
    fi
    grep -qF -- "$phrase" "$root/$target" || ok=0
  done
  report
}
lock() {
python3 -I - "$root/vendor.lock" <<'PY'
import json, re, sys
h = json.load(open(sys.argv[1])).get("hallmark", {})
sys.exit(not (h.get("repo") == "nutlope/hallmark" and re.fullmatch("[0-9a-f]{40}", h.get("commit", "")) and h.get("path") == "skills/hallmark" and h.get("license") == "MIT"))
PY
}

detector_map() {
python3 -I - "$root/skills/st-design/engine.md" <<'PY'
import sys
ig, kp = [], []
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith("ignore: "):
        ig += line.split()[1:]
    elif line.startswith("keep: "):
        kp += line.split()[1:]
detector_only = "flat-type-hierarchy blinking-cursor buried-raster hard-offset-shadow extreme-negative-tracking script-error edge-flush-cards first-viewport-column-overflow straggler clipped-overflow-container design-system-font design-system-color design-system-radius design-system-font-size gpt-thin-border-wide-shadow theater-slop-phrase".split()
sys.exit(not (len(ig) == 35 and len(kp) == 27 and len(set(ig)) == 35 and len(set(kp)) == 27 and not set(ig) & set(kp) and len(set(ig + kp)) == 62 and set(detector_only) <= set(kp)))
PY
}

check "FR-017 lock" 'lock'
check "FR-017 copy" '[ -f "$root/skills/st-hallmark/SKILL.md" ] &&
  grep -qx "name: st-hallmark" "$root/skills/st-hallmark/SKILL.md" &&
  grep -qx "disable-model-invocation: true" "$root/skills/st-hallmark/SKILL.md" &&
  ! grep -qx "name: hallmark" "$root/skills/st-hallmark/SKILL.md" &&
  [ -f "$root/skills/st-hallmark/LICENSE" ] &&
  [ -f "$root/skills/st-hallmark/scripts/sloplint.mjs" ] &&
  [ -f "$root/skills/st-hallmark/scripts/sloplint-render.mjs" ] &&
  [ -f "$root/skills/st-hallmark/scripts/theme.mjs" ] &&
  [ -f "$root/skills/st-hallmark/references/themes/index.json" ] &&
  grep -qF "MIT License" "$root/licenses/hallmark.MIT.txt"'
check "FR-010 one place" '[ "$(grep -rliE "hallmark|sloplint" "$root/skills/st-design" "$root/agents/st-design.md" "$root/scripts/st-design-check.sh")" = "$root/skills/st-design/engine.md" ]'
check "FR-008 map" 'detector_map'
check "FR-001 skill frontmatter" '[ -f "$root/skills/st-design/SKILL.md" ] && grep -qx "name: st-design" "$root/skills/st-design/SKILL.md"'
check "FR-001 agent frontmatter" '[ -f "$root/agents/st-design.md" ] && grep -qx "name: st-design" "$root/agents/st-design.md" && grep -qx "tools: Read, Grep, Glob, Bash, Edit, Write" "$root/agents/st-design.md" && grep -qx "model: opus" "$root/agents/st-design.md"'
n_design=$(grep -cF -- '(`stratum:st-design`)' "$root/skills/st-design/SKILL.md" 2>/dev/null)
n_git=$(grep -cF -- '(`stratum:st-git`)' "$root/skills/st-design/SKILL.md" 2>/dev/null)
check "FR-001 one start each" '[ "$n_design" = 1 ] && [ "$n_git" = 1 ]'

phrases <<'EOF'
FR-017 st-sync	skills/st-sync/SKILL.md	Design lane detector map: after an impeccable or hallmark port
FR-017 THIRD_PARTY_NOTICES.md	THIRD_PARTY_NOTICES.md	| `skills/st-hallmark` | `licenses/hallmark.MIT.txt` |
EOF

phrases <<'EOF'
FR-008 engine.md	skills/st-design/engine.md	Each passes with 0 `FAIL` and 0
FR-008 engine.md	skills/st-design/engine.md	Do not run its Step 1 questions, its hero review, its finish review,
FR-008 engine.md	skills/st-design/engine.md	`summary.render` other than `ran` fails the render check.
FR-016 engine.md	skills/st-design/engine.md	Never ask for, print or set the key.
FR-016 engine.md	skills/st-design/engine.md	Test only `[ -n "${TOGETHER_API_KEY:-}" ]`.
FR-014 engine.md	skills/st-design/engine.md	with `--before`. It keeps the old screenshots in `.hallmark/before/`, which is never committed.
EOF

phrases <<'EOF'
FR-001 SKILL.md	skills/st-design/SKILL.md	# /stratum:st-design <task>
FR-001 SKILL.md	skills/st-design/SKILL.md	Pick the mode and say it in one line.
FR-001 SKILL.md	skills/st-design/SKILL.md	Else autonomous. Styled screens: a tracked file
FR-001 SKILL.md	skills/st-design/SKILL.md	A design file is a root `DESIGN.md` with `.impeccable/design.json` beside it.
FR-001 SKILL.md	skills/st-design/SKILL.md	is not a design file: say
FR-002 st	skills/st/SKILL.md	| New look, page or screen | a new look, or a page or screen the project does not have yet, when the screen is the whole task | Design |
FR-002 st	skills/st/SKILL.md	Say "full", "fast", "quick" or "design" to override.
FR-002 st	skills/st/SKILL.md	Before the first lane skill or agent starts, Quick too, say it in one line:
FR-002 st	skills/st/SKILL.md	- **Design:** run `/stratum:st-design`.
FR-002 st	skills/st/SKILL.md	A new page that also needs API, data or sign-in work goes to Full.
FR-002 st	skills/st/SKILL.md	picks the lane (Full, Fast, Quick, Design)
FR-003 SKILL.md	skills/st-design/SKILL.md	one question per message, each with a recommended answer,
FR-003 SKILL.md	skills/st-design/SKILL.md	First branches: audience, use, tone, material, theme, North Star,
FR-003 SKILL.md	skills/st-design/SKILL.md	overview voice, color character, elevation, components, UX (density, how a user moves through
FR-003 SKILL.md	skills/st-design/SKILL.md	run the engine's deal command, show the 3 themes with their pictures
FR-004 SKILL.md	skills/st-design/SKILL.md	run `document` in scan mode with the grill answers as
FR-004 SKILL.md	skills/st-design/SKILL.md	build nothing until
FR-004 SKILL.md	skills/st-design/SKILL.md	answer its refresh, overwrite
FR-005 SKILL.md	skills/st-design/SKILL.md	read the look from the code (tokens, the global stylesheet, the main
FR-005 SKILL.md	skills/st-design/SKILL.md	start each recommended answer from the draft
FR-006 SKILL.md	skills/st-design/SKILL.md	The user is stopped exactly twice per direction
FR-006 SKILL.md	skills/st-design/SKILL.md	A different direction: back to step 1 at
FR-006 SKILL.md	skills/st-design/SKILL.md	Gate rounds do not count as fix rounds.
FR-007 SKILL.md	skills/st-design/SKILL.md	Find the page's job, its visitor and its main action
FR-007 SKILL.md	skills/st-design/SKILL.md	ask once, with all missing items in one message
FR-008 SKILL.md	skills/st-design/SKILL.md	dimensions 1 (Accessibility) and 2
FR-008 SKILL.md	skills/st-design/SKILL.md	run `critique` on the screen in full
FR-008 SKILL.md	skills/st-design/SKILL.md	ignores add-rule <id> --all-values --local
FR-008 SKILL.md	skills/st-design/SKILL.md	ignores remove-rule <id> --local
FR-008 SKILL.md	skills/st-design/SKILL.md	live-server stop
FR-008 SKILL.md	skills/st-design/SKILL.md	so this form leaves
FR-008 SKILL.md	skills/st-design/SKILL.md	Never a bare `stop`
FR-008 SKILL.md	skills/st-design/SKILL.md	Run at most 2 fix rounds.
FR-008 SKILL.md	skills/st-design/SKILL.md	goes in the report as an unmapped
FR-008 SKILL.md	skills/st-design/SKILL.md	then run step 3 again: audit, and `critique` in full, not only its detector.
FR-009 SKILL.md	skills/st-design/SKILL.md	Screenshots, the picks, each check's result, what was fixed, what is open, every assumed answer,
FR-009 SKILL.md	skills/st-design/SKILL.md	The autonomous mode's report has no picks.
FR-009 agent	agents/st-design.md	Fixed, open, assumed answers.
FR-009 agent	agents/st-design.md	- The picks, in the new-look mode only.
FR-011 agent	agents/st-design.md	layout, components, styles, copy, pictures, motion, UI state, client-side form
FR-012 agent	agents/st-design.md	Do not build what is behind the screen: API calls, data fetch and save,
FR-012 agent	agents/st-design.md	Put placeholder data of the same shape in one file
FR-013 agent	agents/st-design.md	UI behavior not tested: no UI test runner.
FR-013 agent	agents/st-design.md	and add no test tool.
FR-014 agent shots	agents/st-design.md	Save a screenshot outside the screenshot folders `engine.md` names.
FR-014 agent shots	agents/st-design.md	For a change to a built screen, run the engine's Before step before the rebuild.
FR-014 SKILL.md	skills/st-design/SKILL.md	Only after the user's yes at the gate (new look) or OK (autonomous)
FR-014 report	skills/st-design/SKILL.md	report again before any commit
FR-015 SKILL.md	skills/st-design/SKILL.md	bash <plugin root>/scripts/st-design-check.sh
FR-015 SKILL.md	skills/st-design/SKILL.md	Never start a dev server.
FR-015 st-status	skills/st-status/SKILL.md	Design lane: run `bash <plugin root>/scripts/st-design-check.sh`
FR-015 st-status	skills/st-status/SKILL.md	from the project root and print its lines word for word:
FR-016 SKILL.md	skills/st-design/SKILL.md	Ask for an image key or turn on image generation.
FR-018 SKILL.md	skills/st-design/SKILL.md	Edit a vendored file under `skills/st-impeccable/` or the engine's skill folder.
FR-018 agent	agents/st-design.md	Edit a vendored file under `skills/st-impeccable/` or the engine's skill folder.
EOF

exit $fail
