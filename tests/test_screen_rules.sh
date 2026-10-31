#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dl11='A task marked `[screen: <mode>]` goes to `/stratum:st-design` (Skill tool) in that mode, not to `st-build`. Go on with the other tasks while the screen waits, and show the screen'\''s report with the story review.'
dl12='If the Design lane cannot start (its tool check fails, or no dev server answers), pause only that task. Tell the user what is missing in short, simple words, and go on with the other tasks. On the user'\''s "go", run the screen again from `/stratum:st-design` step 1.'
dl13='Never move a `[screen]` task to `st-build` and `st-ui-ux` without telling the user.'
dl14='If `/stratum:st-design` ends with no report, the screen task stays open: tell the user.'
dl15='User stories that tasks.md says share no files run at the same time.'
dl16='and merge it into the feature branch yourself.'
dl17='5. Screen tasks: load `st-ui-ux` (Skill tool) before you build, and follow the project'\''s `DESIGN.md` if one exists.'
merge='merge it into `main`'
check "DL11 skills/st-build/SKILL.md" 'grep -qF "$dl11" "$root/skills/st-build/SKILL.md"'
check "DL12 skills/st-build/SKILL.md" 'grep -qF "$dl12" "$root/skills/st-build/SKILL.md"'
check "DL13 skills/st-build/SKILL.md" 'grep -qF "$dl13" "$root/skills/st-build/SKILL.md"'
check "DL14 skills/st-build/SKILL.md" 'grep -qF "$dl14" "$root/skills/st-build/SKILL.md"'
check "DL15 skills/st-build/SKILL.md" 'grep -qF "$dl15" "$root/skills/st-build/SKILL.md"'
check "DL16 skills/st-build/SKILL.md" 'grep -qF "$dl16" "$root/skills/st-build/SKILL.md"'
check "DL17 agents/st-build.md" 'grep -qF "$dl17" "$root/agents/st-build.md"'
check "design brief gone: agents/st-build.md" '[ -f "$root/agents/st-build.md" ] && ! grep -qF "design brief" "$root/agents/st-build.md"'
check "merge into main gone: skills/st-build/SKILL.md" '[ -f "$root/skills/st-build/SKILL.md" ] && ! grep -qF "$merge" "$root/skills/st-build/SKILL.md"'
exit $fail
