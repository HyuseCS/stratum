#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

while IFS='|' read -r id file phrase; do
  check "$id" 'grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
S1|skills/st-close/SKILL.md|After the commit lands, say `Phase: done` on its own line: the Stratum hook sets `phase` to `done`.
S2|skills/st-fast/SKILL.md|10. After the last commit lands (step 9, or step 6 when step 9 is skipped), say `Phase: done` on its own line: the Stratum hook sets `phase` to `done`.
S3|skills/st/SKILL.md|Put the `Lane:` line at the start of its own line: the Stratum hook writes the risk from it. On the user's "risk <level>", say the `Lane:` line again with the new level.
S4|procedures/specify.md|write `{}` to it. While Define runs, the Stratum hook writes `feature_directory` to it once `spec.md` exists. Later procedures find the feature through this file.
S5|skills/st-build/SKILL.md|Then say `Build done.` on its own line: the Stratum hook clears the reply label.
S6|skills/st-worker/SKILL.md|When the run ends (after the last close or the headless run), say `Build done.` on its own line: the Stratum hook clears the reply label. Skip this when `/stratum:st-build` sent you here: st-build says it.
S9|skills/st-define/SKILL.md|The Stratum hook records the new folder as `feature_directory` in `.stratum/state.json`.
TABLE

check S7 '[ ! -e "$root/scripts/st-state.sh" ]'
check S8 '! grep -rqF st-state.sh "$root/skills" "$root/procedures" "$root/agents" "$root/hooks" "$root/scripts"'
check S10 '! grep -qF -- "and writes \`.stratum/state.json\` with" "$root/skills/st-define/SKILL.md"'

exit $fail
