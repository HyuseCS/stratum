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

bare=$(grep -lE '`st-[a-z-]+` \(`stratum:' "$root"/skills/*/SKILL.md | sed "s|$root/| |" | tr -d '\n')
check "lane wording no bare agent name:$bare" '[ -z "$bare" ]'

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

mkdir -p "$tmp/proj/.stratum" "$tmp/plain" "$tmp/home/.claude"
cp "$root/sr-opus-5.md" "$tmp/home/.claude/sr-opus-5.md"
HOME="$tmp/home" CLAUDE_PLUGIN_ROOT="$root" CLAUDE_PROJECT_DIR="$tmp/proj" bash "$root/hooks/st-session-start.sh" > "$tmp/hook.out"
HOME="$tmp/home" CLAUDE_PLUGIN_ROOT="$root" CLAUDE_PROJECT_DIR="$tmp/plain" bash "$root/hooks/st-session-start.sh" > "$tmp/nohook.out"

phrases <<'EOF'
FR-008 rule	hook	st-impeccable (an audit), st-review, st-ponytail-audit or st-ponytail-debt in the background
FR-008 rule	hook	start the agent of the same name (stratum:<name>)
FR-008 rule	hook	note git rev-parse HEAD and git status --porcelain --untracked-files=all
FR-008 rule	hook	the project root and, for st-impeccable, the target
FR-008 rule	hook	run both again: any difference is a finding to check
FR-008 rule	hook	the main session may also have changed files
FR-008 rule	hook	except st-handoff
FR-008 rule	hook	it runs only in the main session
FR-008 rule	hook	For st-review, pass the feature dir and the range
FR-008 rule	hook	check each finding against the source before you show it
EOF
check "FR-008 plugin root" 'grep -qF "plugin root ($root)" "$tmp/hook.out"'
check "FR-008 no rule outside Stratum" '! grep -qF "start the agent of the same name" "$tmp/nohook.out"'

phrases <<'EOF'
FR-009 handoff	skills/st-handoff/SKILL.md	The user said they are done or is ending the session: write it here, in the main session
FR-009 handoff	skills/st-handoff/SKILL.md	subagent_type: "fork"
FR-009 handoff	skills/st-handoff/SKILL.md	You are the fork.
FR-009 handoff	skills/st-handoff/SKILL.md	A `Handoff` fork is already running: do not start another
FR-009 handoff	skills/st-handoff/SKILL.md	If its report shows no file was written, write it here.
FR-009 handoff	skills/st-handoff/SKILL.md	Do not start another agent.
FR-009 handoff	skills/st-handoff/SKILL.md	The fork cannot start: write it here
EOF
d=$(grep -m1 "^description:" "$root/skills/st-handoff/SKILL.md")
check "FR-009 handoff description" 'grep -qF "background fork" <<<"$d"'

phrases <<'EOF'
#14 review body	agents/st-review.md	Load the `st-ponytail-review` skill (Skill tool)
#14 review body	agents/st-review.md	`correctness`, `security`, `plan`, `simplify`
#14 review body	agents/st-review.md	one ranked list
#14 review body	agents/st-review.md	the change plan
EOF
check "#14 review tools" '[ -f "$root/agents/st-review.md" ] && grep -qx "tools: Read, Grep, Glob, Bash, Skill" "$root/agents/st-review.md"'
check "#14 no copied rules" 'grep -qF "st-ponytail-review" "$root/agents/st-review.md" && ! grep -qF "yagni:" "$root/agents/st-review.md"'
check "#14 lanes" '! grep -qF st-ponytail-review "$root/skills/st-build/SKILL.md" && ! grep -qF st-ponytail-review "$root/skills/st-fast/SKILL.md" && grep -qF "stratum:st-review" "$root/skills/st-fast/SKILL.md"'
check "#14 ponytail-review kept" '[ -f "$root/skills/st-ponytail-review/SKILL.md" ]'
check "#14 design" '! grep -qF ponytail-review "$root/DESIGN.md"'

phrases <<'EOF'
Q2 fast docs commit	skills/st-fast/SKILL.md	commits the docs `st-close` changed
Q2 fast docs commit	DESIGN.md	shortcut list → commit docs
EOF

phrases <<'EOF'
#16 brief mode	agents/st-build.md	Brief mode
#16 brief mode	agents/st-build.md	the brief itself
#16 brief mode	agents/st-build.md	schema or migration
#16 brief mode	agents/st-build.md	auth or access rules
#16 brief mode	agents/st-build.md	money
#16 brief mode	agents/st-build.md	Needs the Fast lane
#16 st routes brief	skills/st/SKILL.md	the `stratum:st-build` agent
#16 st routes brief	skills/st/SKILL.md	never `general-purpose`
#37 quick handoff	skills/st-quick/SKILL.md	commits the exact files it touched
#37 quick handoff	skills/st-quick/SKILL.md	Needs the Fast lane
EOF
check "#16 general-purpose only as never" 'grep -qF general-purpose "$root/skills/st/SKILL.md" && ! grep -F general-purpose "$root/skills/st/SKILL.md" | grep -qvF never'

exit $fail
