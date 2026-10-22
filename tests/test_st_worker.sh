#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/scripts/st-worker.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(cd "$tmp" && pwd -P)
fail=0
q=
check() { if eval "$2"; then [ -n "$q" ] || echo "ok   $1"; else [ -n "$q" ] || echo "FAIL $1"; fail=1; fi; }

mkdir -p "$tmp/bin"
cat > "$tmp/bin/herdr" <<'EOF'
#!/usr/bin/env bash
T=$STUB_T
X=$(cat "$T/x")
if [ $# -eq 0 ]; then echo BARE >> "$T/calls"; exit 99; fi
( IFS=$'\t'; printf '%s\n' "$*" >> "$T/calls" )
if [ "${STUB_FAIL:-}" = "$1 $2" ] || { [ "${STUB_FAIL_UNTIL:-}" = "$1 $2" ] && [[ " $* " == *" --until "* ]]; }; then
  printf '{"error":{"code":"%s","message":"stub refused"}}\n' "${STUB_FAIL_CODE:-stub}" >&2
  exit 1
fi
upd() { jq -c "${@:2}" "$T/$1" > "$T/$1.new" && mv "$T/$1.new" "$T/$1"; }
case "$1 $2" in
"worktree create")
  while [ $# -gt 0 ]; do
    case "$1" in --path) p=$2 ;; --branch) b=$2 ;; --label) l=$2 ;; esac
    shift
  done
  mkdir -p "$p/.stratum"
  w="stubWS$X"
  jq -nc --arg w "$w" --arg p "$p" --arg b "$b" '{result:{type:"worktree_created",workspace:{workspace_id:$w},tab:{tab_id:($w+":t1")},root_pane:{pane_id:($w+":p1")},worktree:{path:$p,branch:$b}}}' | tee "$T/wc.json"
  upd ws.json --arg w "$w" --arg l "$l" '. + [{workspace_id:$w,label:$l}]'
  upd wt.json --arg w "$w" --arg p "$p" --arg b "$b" '. + [{path:$p,branch:$b,open_workspace_id:$w}]' ;;
"worktree list")
  jq -c --arg w "$4" '{result:{worktrees:map(select(.open_workspace_id==$w))}}' "$T/wt.json" ;;
"workspace list")
  jq -c '{result:{workspaces:.}}' "$T/ws.json" ;;
"workspace close")
  upd ws.json --arg w "$3" 'map(select(.workspace_id!=$w))'
  [ -n "${STUB_KEEP_AGENT:-}" ] || upd agents.json --arg w "$3" 'map(select(.workspace_id!=$w))'
  jq -nc --arg w "$3" '{result:{type:"workspace_closed",workspace_id:$w}}' ;;
"agent start")
  n=$3
  while [ $# -gt 0 ]; do
    case "$1" in --pane) pn=$2 ;; esac
    shift
  done
  upd agents.json --arg n "$n" --arg p "$pn" --slurpfile c "$T/wc.json" '. + [{name:$n,pane_id:$p,workspace_id:$c[0].result.workspace.workspace_id,agent_status:"working"}]'
  jq -nc --arg n "$n" '{result:{type:"agent_started",agent:{name:$n},argv:[]}}' ;;
"agent get")
  n=$(cat "$T/n_get" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n_get"
  s=$(sed -n "${n}p" "$T/states"); [ -n "$s" ] || s=$(tail -n1 "$T/states")
  jq -nc --arg s "$s" --arg n "$3" --slurpfile c "$T/wc.json" '{result:{agent:{agent_status:$s,name:$n,pane_id:$c[0].result.root_pane.pane_id,workspace_id:$c[0].result.workspace.workspace_id}}}' ;;
"agent list")
  jq -c '{result:{agents:.}}' "$T/agents.json" ;;
"agent read")
  jq -nc --arg t "STUB PANE $X" '{result:{read:{text:$t}}}' ;;
"agent wait")
  if [[ " $* " == *" --until "* ]] && [ -e "$T/resume_result" ]; then
    printf 'RESULT FILE %s\n' "$X" > "$(jq -r .result.worktree.path "$T/wc.json")/result.md"
  fi
  echo '{"result":{}}' ;;
*) echo '{"result":{}}' ;;
esac
EOF
chmod +x "$tmp/bin/herdr"
export STUB_T="$tmp"

found=$(PATH="$tmp/bin:$PATH" command -v herdr)
if [ "$found" != "$tmp/bin/herdr" ]; then echo "FAIL stub herdr is first on PATH: found $found"; exit 1; fi

repo="$tmp/repo"
mkdir -p "$repo/.stratum"
git -C "$repo" init -q
printf '{}\n' > "$repo/.stratum/state.json"
git -C "$repo" add .stratum/state.json
git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m first
sha=$(git -C "$repo" rev-parse HEAD)

task="$tmp/task.md"
roster="$tmp/roster"
rules="$tmp/rules"
testcmd='bash tests/test_demo.sh'
lane=st-build
printf 'worker-t004\tlocal\tworker-t004\tT004\nworker-t005\tlocal\tworker-t005\tT005\n' > "$roster"
printf '%s\n' \
  '1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md or result.md.' \
  "2. Before you build on a teammate's work, merge its branch: \`git log <branch>\`, \`git merge <branch>\`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work." \
  '3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.' \
  '4. Never merge and never push. The orchestrator reviews every branch and is the only one who merges.' > "$rules"
P="/goal \`$testcmd\` exits 0, the change is committed on branch worker-t004, and result.md is written; read brief.md in this folder first and follow it"
sargs=(T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$roster")

reset() { : > "$tmp/calls"; }
states() { printf '%s\n' "$@" > "$tmp/states"; }
fresh() {
  rm -rf "$tmp"/repo-worker-* "$tmp"/n_* "$tmp/closed" "$tmp/resume_result" "$tmp/wc.json" "$tmp/s2"
  printf 'x%s\n' "$RANDOM$RANDOM" > "$tmp/x"
  printf 'TASK BODY %s\n' "$(cat "$tmp/x")" > "$task"
  jq -nc '[{workspace_id:"stubDecoyWS",label:"notaworker"}]' > "$tmp/ws.json"
  jq -nc '[{path:"/stub/decoy",branch:"notaworker",open_workspace_id:"stubDecoyWS"}]' > "$tmp/wt.json"
  echo '[]' > "$tmp/agents.json"
  states working
  reset
}
run() {
  out=$(cd "$repo" && PATH="$tmp/bin:$PATH" HERDR_ENV="${HENV-1}" HERDR_PANE_ID=w1P:p1 HERDR_TAB_ID=w1P:t1 HERDR_WORKSPACE_ID=w1P "$@" 2>&1); rc=$?
}
mk() { fresh; run bash "$script" start "${sargs[@]}"; reset; }
wsid() { jq -r .result.workspace.workspace_id "$tmp/wc.json"; }
pane() { jq -r .result.root_pane.pane_id "$tmp/wc.json"; }
wt() { jq -r .result.worktree.path "$tmp/wc.json"; }
rnd() { cat "$tmp/x"; }
cnt() { grep -cP "$1" "$tmp/calls"; }
hasline() { grep -qxF "$(printf "$@")" <<<"$out"; }
hascall() { grep -qxF "$(printf "$@")" "$tmp/calls"; }
never() {
  ! grep -qx BARE "$tmp/calls" && ! grep -q w1P "$tmp/calls" &&
  ! grep -qP '(^|\t)(--current|--session|--remote|--trust-repository|--group|--machine)(\t|$)' "$tmp/calls" &&
  ! grep -qP '^(pane\tclose|worktree\tremove|server\t|machine\t(reconnect|add|remove|enable|disable)(\t|$))' "$tmp/calls" &&
  [ "$(cnt '^workspace\tclose\t')" = "$1" ] && [ "$(cnt '^agent\tprompt\t')" = "$2" ]
}
nopane() { ! grep -q 'STUB PANE' <<<"$out"; }
paneshown() { grep -qxF 'pane text:' <<<"$out" && grep -qxF "STUB PANE $(rnd)" <<<"$out"; }

prej() {
  local ph=$2
  check "$1 exit 1" '[ $rc = 1 ]'
  check "$1 one line, the phrase" '[ "$(printf "%s\n" "$out" | grep -c .)" = 1 ] && [ "$out" = "$ph" ]'
  check "$1 no herdr call" '[ ! -s "$tmp/calls" ]'
}

s1() {
  fresh; run bash "$1" start "${sargs[@]}"
  local b; b="$(wt)/brief.md"
  check "S1 exit 0" '[ $rc = 0 ]'
  check "S1 one worktree create, argv as built" '[ "$(cnt "^worktree\tcreate\t")" = 1 ] && hascall "worktree\tcreate\t--cwd\t%s\t--branch\tworker-t004\t--base\t%s\t--path\t%s\t--label\tworker-t004\t--no-focus" "$repo" "$sha" "$tmp/repo-worker-t004"'
  check "S1 brief has the task text" 'grep -qxF "TASK BODY $(rnd)" "$b"'
  check "S1 brief heading, test, lane, branch, machine, result path" 'grep -qxF "# Brief: worker-t004" "$b" && grep -qxF "- Test command: \`$testcmd\`" "$b" && grep -qxF "- Lane: $lane. Start it with the Skill tool. Run only task T004; skip every other task, ticked or not." "$b" && grep -qxF "- Branch: worker-t004" "$b" && grep -qxF "- Your machine: local. \`local\` is the orchestrator'"'"'s machine." "$b" && grep -qxF "- Result file: $(wt)/result.md" "$b"'
  check "S1 brief has every roster row" 'grep -qxF "| worker-t004 | local | worker-t004 | T004 |" "$b" && grep -qxF "| worker-t005 | local | worker-t005 | T005 |" "$b"'
  check "S1 brief has the four team rules" '[ "$(grep -cxFf "$rules" "$b")" = 4 ]'
  check "S1 brief has no advisor block" '[ -f "$b" ] && ! grep -q "^## Advisor" "$b"'
  check "S1 git-guard.json in the worktree is auto" '[ "$(cat "$(wt)/.stratum/git-guard.json")" = "{\"commit\":\"auto\"}" ]'
  check "S1 repo has no git-guard.json and is unchanged" '[ ! -e "$repo/.stratum/git-guard.json" ] && [ -z "$(git -C "$repo" status --porcelain)" ]'
  check "S1 one agent start, args after -- are exactly the permission mode and name" '[ "$(cnt "^agent\tstart\t")" = 1 ] && hascall "agent\tstart\tworker-t004\t--kind\tclaude\t--pane\t%s\t--timeout\t120000\t--\t--permission-mode\tauto\t-n\tworker-t004" "$(pane)"'
  check "S1 one agent prompt with P" 'hascall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P"'
  check "S1 worker line, ids from the stub log" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$(wt)"'
  check "S1 state line" 'hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
  check "S1 never-list, one prompt, no close, no pane text" 'never 0 1 && nopane'
}
s1 "$script"

fresh
mkdir "$tmp/s2"
cp "$script" "$tmp/s2/st-worker.sh" 2>/dev/null
: > "$tmp/s2/st-advisor.sh"
run bash "$tmp/s2/st-worker.sh" start "${sargs[@]}"
check "S2 exit 0" '[ $rc = 0 ]'
check "S2 brief has the advisor block" 'grep -qxF "## Advisor" "$(wt)/brief.md" && grep -qxF "The Codex advisor is installed (\`scripts/st-advisor.sh\` in the Stratum plugin). At each advisor point your lane names, run it and follow its verdict." "$(wt)/brief.md"'
check "S2 never-list" 'never 0 1'

fresh
STUB_FAIL="agent start" STUB_FAIL_CODE=agent_not_ready run bash "$script" start "${sargs[@]}"
check "S3 exit 4" '[ $rc = 4 ]'
check "S3 worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$(wt)"'
check "S3 state blocked, pane text, the stub pane text" 'hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && paneshown'
check "S3 pane read call, no agent prompt" 'hascall "agent\tread\tworker-t004\t--source\trecent-unwrapped\t--lines\t40" && never 0 0'
reset
run bash "$script" goal worker-t004 --test "$testcmd"
check "S3 goal exit 0" '[ $rc = 0 ]'
check "S3 goal sends exactly one agent prompt with P" 'hascall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P" && never 0 1'

fresh
STUB_FAIL="worktree create" run bash "$script" start "${sargs[@]}"
check "S4 exit 1" '[ $rc = 1 ]'
check "S4 stopped line with the stub message" 'grep -q "^stopped: .*stub refused" <<<"$out"'
check "S4 worker line has - ids" 'grep -qP "^worker\tworker-t004\tlocal\t-\t-\t.*\t-\$" <<<"$out"'
check "S4 no agent start, no prompt" '[ "$(cnt "^agent\tstart\t")" = 0 ] && never 0 0'

fresh
STUB_FAIL="agent prompt" STUB_FAIL_CODE=agent_prompt_stalled run bash "$script" start "${sargs[@]}"
check "S5 exit 1" '[ $rc = 1 ]'
check "S5 stopped line" 'grep -q "^stopped: .*stub refused" <<<"$out"'
check "S5 worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$(wt)"'
check "S5 one prompt only, nothing closed" 'never 0 1'

fresh
jq -nc '[{workspace_id:"stubExistWS",label:"worker-t004"}]' > "$tmp/ws.json"
run bash "$script" start "${sargs[@]}"
check "S6 exit 1" '[ $rc = 1 ]'
check "S6 one line, already exists" '[ "$out" = "A worker worker-t004 already exists." ]'
check "S6 only read calls" '[ "$(cnt "^workspace\tlist(\t|\$)")" -ge 1 ] && [ "$(cnt "^workspace\tlist(\t|\$)")" = "$(grep -c . "$tmp/calls")" ] && never 0 0'

fresh
STUB_FAIL="agent prompt" STUB_FAIL_CODE=agent_blocked run bash "$script" start "${sargs[@]}"
check "S7 exit 4" '[ $rc = 4 ]'
check "S7 worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$(wt)"'
check "S7 state blocked, pane text, the stub pane text" 'hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && paneshown'
check "S7 one prompt only, nothing closed" 'never 0 1'
reset
run bash "$script" goal worker-t004 --test "$testcmd"
check "S7 goal exit 0, exactly one prompt" '[ $rc = 0 ] && never 0 1'

fresh; run bash "$script" start 'bad id' --task "$task" --test "$testcmd" --lane "$lane" --roster "$roster"
prej P1 "Task id must be letters, digits or dash, start with a letter or digit, and be at most 25 characters."
fresh; run bash "$script" start T004 --task "$tmp/nofile" --test "$testcmd" --lane "$lane" --roster "$roster"
prej P2 "Task file not found or empty: $tmp/nofile"
fresh; run bash "$script" start T004 --task "$task" --test 'foo (bar)' --lane "$lane" --roster "$roster"
prej P3 "Test command must be one line with no ( or )."
fresh; run bash "$script" start T004 --task "$task" --test "$testcmd" --lane $'a\nb' --roster "$roster"
prej P4 "Lane must be one line."
printf 'worker-t004\tlocal\tworker-t004\tT004\nbroken\tline\n' > "$tmp/roster_bad"
fresh; run bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$tmp/roster_bad"
prej P5 "Roster line 2 must be: name, machine, branch, task, split by TAB."
printf 'worker-t009\tlocal\tworker-t009\tT009\n' > "$tmp/roster_none"
fresh; run bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$tmp/roster_none"
prej P5b "Roster has no line for worker-t004."
longtest=$(head -c 4100 /dev/zero | tr '\0' x)
fresh; run bash "$script" start T004 --task "$task" --test "$longtest" --lane "$lane" --roster "$roster"
prej P6 "The /goal prompt is over 4000 characters."
fresh; HENV=0 run bash "$script" start "${sargs[@]}"
prej P7 "Not inside a herdr pane. Run it from a herdr pane, or name a --machine."

mk; states done
printf 'RESULT FILE %s\n' "$(rnd)" > "$(wt)/result.md"
run bash "$script" wait worker-t004
check "W1 exit 0" '[ $rc = 0 ]'
check "W1 state finished" 'hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
check "W1 finds the worker by label and workspace" 'hascall "worktree\tlist\t--workspace\t%s" "$(wsid)" && [ "$(cnt "^agent\twait\tworker-t004\t--timeout\t")" = 1 ]'
check "W1 never-list, no prompt, no pane text" 'never 0 0 && nopane'

mk; states working
STUB_FAIL="agent wait" STUB_FAIL_CODE=timeout run bash "$script" wait worker-t004
check "W2 exit 3" '[ $rc = 3 ]'
check "W2 state working with the pane" 'hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
check "W2 never-list" 'never 0 0'

mk; states idle done; : > "$tmp/resume_result"
run bash "$script" wait worker-t004
check "W3 exit 0" '[ $rc = 0 ]'
check "W3 state finished" 'hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
check "W3 two waits without --until, one resume check with it" '[ "$(grep -P "^agent\twait\t" "$tmp/calls" | grep -vc -- "--until")" = 2 ] && [ "$(grep -P "^agent\twait\t" "$tmp/calls" | grep -c -- "--until")" = 1 ]'
check "W3 never-list" 'never 0 0'

mk; states idle
STUB_FAIL_UNTIL="agent wait" STUB_FAIL_CODE=timeout run bash "$script" wait worker-t004
check "W4 exit 5" '[ $rc = 5 ]'
check "W4 state stopped, pane text, the stub pane text" 'hasline "state\tstopped\tworker-t004\t%s" "$(pane)" && paneshown'
check "W4 never-list" 'never 0 0'

mk; states blocked
run bash "$script" wait worker-t004
check "W5 exit 4" '[ $rc = 4 ]'
check "W5 state blocked with the worker name, pane text" 'hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && paneshown'
check "W5 never-list" 'never 0 0'

g1() {
  mk
  printf 'RESULT FILE %s\n' "$(rnd)" > "$(wt)/result.md"
  run bash "$1" result worker-t004
  check "G1 exit 0" '[ $rc = 0 ]'
  check "G1 result line and the file text" 'hasline "result\tworker-t004\t%s/result.md" "$(wt)" && grep -qxF "RESULT FILE $(rnd)" <<<"$out"'
  check "G1 the pane is not printed and not read" 'nopane && [ "$(cnt "^agent\tread\t")" = 0 ]'
  check "G1 never-list" 'never 0 0'
}
g1 "$script"

mk
run bash "$script" result worker-t004
check "G2 exit 1" '[ $rc = 1 ]'
check "G2 no result file line, pane text, the stub pane text" 'grep -qxF "no result file: $(wt)/result.md" <<<"$out" && paneshown'
check "G2 never-list" 'never 0 0'

mk; states done
run bash "$script" close worker-t004
check "C1 exit 0" '[ $rc = 0 ]'
check "C1 one workspace close on the stub WS" 'hascall "workspace\tclose\t%s" "$(wsid)" && never 1 0'
check "C1 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'

mk; states working
run bash "$script" close worker-t004
check "C2 exit 1" '[ $rc = 1 ]'
check "C2 a refuse line, no closed line, no workspace close" '[ -n "$out" ] && ! grep -q "^closed" <<<"$out" && never 0 0'

mk; states done
STUB_KEEP_AGENT=1 run bash "$script" close worker-t004
check "C3 exit 1" '[ $rc = 1 ]'
check "C3 close left agent line" 'grep -qxF "close left agent worker-t004" <<<"$out"'
check "C3 one workspace close on the stub WS" 'hascall "workspace\tclose\t%s" "$(wsid)" && never 1 0'

fresh
run bash "$script" close worker-t004
check "C4 exit 1" '[ $rc = 1 ]'
check "C4 no worker line, no workspace close" 'grep -qxF "No worker worker-t004 on local." <<<"$out" && never 0 0'

mk; states done
STUB_FAIL="agent get" run bash "$script" close worker-t004
check "C5 exit 0" '[ $rc = 0 ]'
check "C5 one workspace close on the stub WS" 'hascall "workspace\tclose\t%s" "$(wsid)" && never 1 0'
check "C5 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'

fresh
x=$(rnd)
jq -nc --arg x "$x" '[{workspace_id:("stubA"+$x),label:"worker-t004"},{workspace_id:("stubB"+$x),label:"worker-t005"},{workspace_id:("stubC"+$x),label:"notaworker"}]' > "$tmp/ws.json"
jq -nc --arg x "$x" '[{path:("/stub/a"+$x),branch:"worker-t004",open_workspace_id:("stubA"+$x)},{path:("/stub/b"+$x),branch:"worker-t005",open_workspace_id:("stubB"+$x)},{path:("/stub/c"+$x),branch:"notaworker",open_workspace_id:("stubC"+$x)}]' > "$tmp/wt.json"
jq -nc --arg x "$x" '[{name:"worker-t004",pane_id:("stubA"+$x+":p1"),workspace_id:("stubA"+$x),agent_status:"blocked"},{name:"other-agent",pane_id:("stubC"+$x+":p1"),workspace_id:("stubC"+$x),agent_status:"idle"}]' > "$tmp/agents.json"
run bash "$script" list
check "L1 exit 0" '[ $rc = 0 ]'
check "L1 two found lines, states from the stub" '[ "$(grep -cP "^found\t" <<<"$out")" = 2 ] && hasline "found\tworker-t004\tlocal\tstubA%s\tstubA%s:p1\tblocked\t/stub/a%s" "$x" "$x" "$x" && hasline "found\tworker-t005\tlocal\tstubB%s\t-\tgone\t/stub/b%s" "$x" "$x"'
check "L1 the other workspace is absent" '! grep -q notaworker <<<"$out" && ! grep -q "stubC" <<<"$out"'
check "L1 never-list, no prompt, no close" 'never 0 0'

nc() {
  local fn=$2
  check "$1 sed changed the script" '[ -f "$script" ] && ! cmp -s "$script" "$tmp/$1.sh"'
  check "$1 copy parses" 'bash -n "$tmp/$1.sh"'
  local f=$fail; fail=0; q=1
  local base=0
  "$fn" "$script"; base=$fail; fail=0
  "$fn" "$tmp/$1.sh"
  q=; local red=$fail; fail=$f
  check "$1 real script is green" '[ $base = 0 ]'
  check "$1 goes red" '[ $red = 1 ]'
}
sed -E '/\| %s \| %s \| %s \| %s \|/d' "$script" > "$tmp/NC2.sh" 2>/dev/null
nc NC2 s1
sed -E '/Commit each finished unit with the st-git agent/d' "$script" > "$tmp/NC3.sh" 2>/dev/null
nc NC3 s1
sed -E 's/cat( --)? [^|;&)]*result\.md[^|;&)]*/herdr agent read worker-t004 --source recent-unwrapped --lines 40 | jq -r .result.read.text/' "$script" > "$tmp/NC4.sh" 2>/dev/null
nc NC4 g1
sed -E '/git-guard\.json/d' "$script" > "$tmp/NC7.sh" 2>/dev/null
nc NC7 s1

exit $fail
