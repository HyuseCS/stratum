#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
report() { if [ "$ok" = 1 ]; then echo "ok   $cur"; else echo "FAIL $cur"; fail=1; fi; }
phrases() {
  cur=""; ok=1
  while IFS=$'\t' read -r name target phrase; do
    if [ "$name" != "$cur" ]; then
      [ -n "$cur" ] && report
      cur=$name; ok=1
    fi
    case $target in
      hook) f=$tmp/hook.out ;;
      *) f=$root/$target ;;
    esac
    grep -qF -- "$phrase" "$f" || ok=0
  done
  report
}

for s in st-review st-test st-debug st-git; do
  f="$root/skills/$s/SKILL.md"
  n=$(grep -cF -- "(\`stratum:$s\`)" "$f")
  check "FR-001 $s" '[ -f "$f" ] && grep -qx "name: $s" "$f" && grep -q "^# /stratum:$s" "$f" && [ "$n" = 1 ]'
done

phrases <<'EOF'
FR-002 st-review	skills/st-review/SKILL.md	No `feature_directory`
FR-002 st-review	skills/st-review/SKILL.md	No current feature. Run
FR-002 st-review	skills/st-review/SKILL.md	main..HEAD
FR-002 st-test	skills/st-test/SKILL.md	No `feature_directory`
FR-002 st-test	skills/st-test/SKILL.md	No current feature. Run
FR-002 st-debug	skills/st-debug/SKILL.md	No `feature_directory`
FR-002 st-debug	skills/st-debug/SKILL.md	No current feature. Run
FR-003 st-git	skills/st-git/SKILL.md	git status --porcelain --untracked-files=all
FR-003 st-git	skills/st-git/SKILL.md	Nothing to commit.
FR-003 st-git	skills/st-git/SKILL.md	ask the user which to commit
FR-004 st-review	skills/st-review/SKILL.md	Check each finding against the source before you show it
FR-004 st-test	skills/st-test/SKILL.md	Run each test command it reports again
FR-004 st-test	skills/st-test/SKILL.md	fail for the right reason
FR-004 st-debug	skills/st-debug/SKILL.md	<plugin root>/scripts/st-verify.sh '<test command>' <files it changed>
FR-004 st-git	skills/st-git/SKILL.md	git log -1 --name-only --format=
FR-004 st-git	skills/st-git/SKILL.md	It must list exactly the files given
EOF

miss=$(for a in "$root"/agents/*.md; do n=$(basename "$a" .md); [ -f "$root/skills/$n/SKILL.md" ] || printf ' %s' "$n"; done)
check "every agent has a command:$miss" '[ -z "$miss" ]'

for a in st-impeccable st-ponytail-audit st-ponytail-debt; do
  f="$root/agents/$a.md"
  m=opus; t="Read, Grep, Glob, Skill"
  [ "$a" = st-ponytail-debt ] && m=sonnet
  [ "$a" = st-impeccable ] && t="Read, Grep, Glob, Bash, Skill"
  tools=$(sed -n 's/^tools: //p' "$f")
  check "FR-006 $a frontmatter" '[ -f "$f" ] && grep -qx "name: $a" "$f" && grep -qx "tools: $t" "$f" && grep -qx "model: $m" "$f"'
  check "FR-006 $a skill" '[ -f "$root/skills/$a/SKILL.md" ]'
  check "FR-007 $a no edit tools" '[ -n "$tools" ] && ! grep -qwE "Edit|Write" <<<"$tools"'
  [ "$a" = st-impeccable ] || check "FR-007 $a no Bash" '[ -n "$tools" ] && ! grep -qw Bash <<<"$tools"'
done

phrases <<'EOF'
FR-006 body	agents/st-impeccable.md	Read `<plugin root>/sr-opus-5.md` first
FR-006 body	agents/st-impeccable.md	in the background
FR-006 body	agents/st-impeccable.md	skill (Skill tool)
FR-006 body	agents/st-ponytail-audit.md	Read `<plugin root>/sr-opus-5.md` first
FR-006 body	agents/st-ponytail-audit.md	in the background
FR-006 body	agents/st-ponytail-audit.md	skill (Skill tool)
FR-006 body	agents/st-ponytail-debt.md	Read `<plugin root>/sr-opus-5.md` first
FR-006 body	agents/st-ponytail-debt.md	in the background
FR-006 body	agents/st-ponytail-debt.md	skill (Skill tool)
FR-006 audit only	agents/st-impeccable.md	Run its `audit` command on the target
FR-006 audit only	agents/st-impeccable.md	Run any mode except `audit`
FR-006 audit only	agents/st-impeccable.md	Runs only audit in the background.
FR-007 never	agents/st-impeccable.md	You change no file and never commit.
FR-007 never	agents/st-impeccable.md	Ask the user a question.
FR-007 never	agents/st-ponytail-audit.md	You change no file and never commit.
FR-007 never	agents/st-ponytail-audit.md	Ask the user a question.
FR-007 never	agents/st-ponytail-debt.md	You change no file and never commit.
FR-007 never	agents/st-ponytail-debt.md	Ask the user a question.
FR-007 ledger	agents/st-ponytail-debt.md	Write the ledger to a file
EOF

exit $fail
