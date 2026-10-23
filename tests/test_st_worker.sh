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
M=; if [ "$1" = --machine ]; then M=$2; shift 2; fi
if [ "$1 $2" = "agent start" ] && [ -n "${STUB_BUSY:-}" ]; then
  b=$(cat "$T/n_busy" 2>/dev/null || echo 0); b=$((b+1)); echo $b > "$T/n_busy"
  if [ $b -le "$STUB_BUSY" ]; then printf '{"error":{"code":"agent_pane_busy","message":"stub busy"}}\n' >&2; exit 1; fi
fi
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
  [ -n "$M" ] || mkdir -p "$p/.stratum"
  p=${STUB_WT_PATH:-$p}
  w="stubWS$X"
  jq -nc --arg w "$w" --arg p "$p" --arg b "$b" '{result:{type:"worktree_created",workspace:{workspace_id:$w},tab:{tab_id:($w+":t1")},root_pane:{pane_id:($w+":p1")},worktree:{path:$p,branch:$b}}}' | tee "$T/wc.json"
  upd ws.json --arg w "$w" --arg l "$l" '. + [{workspace_id:$w,label:$l}]'
  upd wt.json --arg w "$w" --arg p "$p" --arg b "$b" '. + [{path:$p,branch:$b,open_workspace_id:$w}]' ;;
"worktree list")
  jq -c --arg w "$4" '{result:{worktrees:map(select(.open_workspace_id==$w))}}' "$T/wt.json" ;;
"machine list")
  case "${STUB_ML:-}" in fail) exit 1 ;; junk) echo 'not json'; exit 0 ;; esac
  printf '%s\n' '[{"id":"stubid0001","label":"laptop","target":"u@stubhost","session":"default","enabled":true,"selected":false}]' ;;
"workspace list")
  if [ -n "${STUB_DOWN:-}" ] && [ -n "$M" ]; then echo 'Error: stub machine down' >&2; exit 1; fi
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
  printf 'STUB PANE %s\n' "$X" ;;
"agent wait")
  if [[ " $* " == *" --until "* ]] && [ -e "$T/resume_result" ]; then
    printf 'RESULT FILE %s\n' "$X" > "$(jq -r .result.worktree.path "$T/wc.json")/result.md"
  fi
  echo '{"result":{}}' ;;
*) echo '{"result":{}}' ;;
esac
EOF
cat > "$tmp/bin/ssh" <<'EOF'
#!/usr/bin/env bash
T=$STUB_T
n=$(cat "$T/n_ssh" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n_ssh"
( IFS=$'\t'; printf '%s\n' "$*" >> "$T/ssh" )
if [ -n "${STUB_SSH_RC:-}" ]; then echo 'ssh: stub failure' >&2; exit "$STUB_SSH_RC"; fi
while [ $# -gt 0 ] && [ "$1" != -- ]; do shift; done
shift 2
c="$*"
case "$c" in
"cat > "*) cat > "$T/ssh_in.$n" ;;
"cat -- "*result.md) printf 'RESULT FILE %s\n' "$(cat "$T/x")" ;;
"test -f "*) [ -e "$T/ssh_has_result" ] ;;
esac
EOF
cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = fetch ]; then ( IFS=$'\t'; printf 'ENV=%s\t%s\n' "${GIT_SSH_COMMAND:-}" "$*" >> "$STUB_T/gitlog" ); exit 0; fi
exec "$STUB_REAL_GIT" "$@"
EOF
cat > "$tmp/bin/sleep" <<'EOF'
#!/usr/bin/env bash
( IFS=$'\t'; printf 'sleep\t%s\n' "$*" >> "$STUB_T/calls" )
EOF
cat > "$tmp/bin/timeout" <<'EOF'
#!/usr/bin/env bash
( IFS=$'\t'; printf '%s\n' "$*" > "$STUB_T/timeout_args" )
if [ "$1" = -k ]; then shift 2; fi
shift
exec "$@"
EOF
chmod +x "$tmp/bin/herdr" "$tmp/bin/ssh" "$tmp/bin/git" "$tmp/bin/sleep" "$tmp/bin/timeout"
export STUB_T="$tmp" STUB_REAL_GIT="$(command -v git)"

cat > "$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
T=$STUB_T
printf '%s\n' "$@" > "$T/claude_args"
bp=$(sed -E 's/.*; read (.*) first and follow it$/\1/' <<<"$2")
printf '%s\n' "$bp" > "$T/brief.path"
printf '%s\n' "$PWD" > "$T/claude_pwd"
cp "$bp" "$T/brief.copy" 2>/dev/null
turns=$((RANDOM % 20 + 1)); cost="0.0$RANDOM"
printf '%s\n%s\n' "$turns" "$cost" > "$T/claude_nums"
case "${STUB_CLAUDE:-}" in
slow) exit 124 ;;
killed) exit 137 ;;
commitslow) git -c user.name=t -c user.email=t@t commit -q --allow-empty -m worker; exit 124 ;;
errturns) jq -nc --argjson n "$turns" --argjson c "$cost" --arg r "ERRTURNS $(cat "$T/x")" '{type:"result",subtype:"error_max_turns",is_error:true,num_turns:$n,total_cost_usd:$c,session_id:"stubsession",result:$r}'; exit 1 ;;
commit) git -c user.name=t -c user.email=t@t commit -q --allow-empty -m worker ;;
commitjunk) git -c user.name=t -c user.email=t@t commit -q --allow-empty -m worker; echo 'not json at all'; exit 0 ;;
junk) echo 'not json at all'; exit 0 ;;
esac
jq -nc --argjson n "$turns" --argjson c "$cost" --arg r "HEADLESS $(cat "$T/x")" '{type:"result",subtype:"success",is_error:false,num_turns:$n,total_cost_usd:$c,session_id:"stubsession",result:$r}'
EOF
chmod +x "$tmp/bin/claude"
for b in herdr ssh git sleep timeout claude; do
  found=$(PATH="$tmp/bin:$PATH" command -v $b)
  if [ "$found" != "$tmp/bin/$b" ]; then echo "FAIL stub $b is first on PATH: found $found"; exit 1; fi
done

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
  '1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md or .stratum/git-guard.json.' \
  "2. Before you build on a teammate's work, merge its branch: \`git log <branch>\`, \`git merge <branch>\`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work." \
  '3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.' \
  '4. Never merge into the base branch and never push. Merging a teammate'"'"'s branch into your own (rule 2) is fine. The orchestrator reviews every branch and is the only one who merges into the base.' > "$rules"
P="/goal \`$testcmd\` exits 0, the change is committed on branch worker-t004, and result.md is written; read brief.md in this folder first and follow it"
sargs=(T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$roster")

reset() { : > "$tmp/calls"; }
states() { rm -f "$tmp/n_get"; printf '%s\n' "$@" > "$tmp/states"; }
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
  out=$(cd "${RUNDIR:-$repo}" && PATH="$tmp/bin:$PATH" HERDR_ENV="${HENV-1}" HERDR_PANE_ID=w1P:p1 HERDR_TAB_ID=w1P:t1 HERDR_WORKSPACE_ID=w1P env ${NOENV:+-u HERDR_ENV} "$@" 2>&1); rc=$?
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
  local b pr; b="$(wt)/brief.md"; pr=$(cd "$(dirname "$1")/.." && pwd)
  check "S1 exit 0" '[ $rc = 0 ]'
  check "S1 one worktree create, argv as built" '[ "$(cnt "^worktree\tcreate\t")" = 1 ] && hascall "worktree\tcreate\t--cwd\t%s\t--branch\tworker-t004\t--base\t%s\t--path\t%s\t--label\tworker-t004\t--no-focus" "$repo" "$sha" "$tmp/repo-worker-t004"'
  check "S1 brief has the task text" 'grep -qxF "TASK BODY $(rnd)" "$b"'
  check "S1 brief heading, test, lane, branch, machine, result path" 'grep -qxF "# Brief: worker-t004" "$b" && grep -qxF -- "- Test command: \`$testcmd\`" "$b" && grep -qxF -- "- Lane: $lane. If it names a skill, start it with the Skill tool. Run only task T004; skip every other task, ticked or not." "$b" && grep -qxF -- "- Branch: worker-t004" "$b" && grep -qxF -- "- Your machine: local. \`local\` is the orchestrator'"'"'s machine." "$b" && grep -qxF -- "- Result file: $(wt)/result.md" "$b"'
  check "S1 brief names the plugin root" 'grep -qxF -- "- Plugin root: $pr" "$b"'
  check "S1 brief order: Model, then Plugin root, then Your machine" 'mo=$(grep -n "^- Model: " "$b" | cut -d: -f1) && po=$(grep -n "^- Plugin root: " "$b" | cut -d: -f1) && yo=$(grep -n "^- Your machine: " "$b" | cut -d: -f1) && [ "$mo" -lt "$po" ] && [ "$po" -lt "$yo" ]'
  check "S1 brief has every roster row" 'grep -qxF "| worker-t004 | local | worker-t004 | T004 |" "$b" && grep -qxF "| worker-t005 | local | worker-t005 | T005 |" "$b"'
  check "S1 brief has the four team rules" '[ "$(grep -cxFf "$rules" "$b")" = 4 ]'
  check "S1 brief rule 1 names .stratum/git-guard.json" 'grep -q "^1\. .*Never commit .*\.stratum/git-guard\.json\.\$" "$b"'
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
printf '{"force_push":"deny"}\n' > "$repo/.stratum/git-guard.json"
run bash "$script" start "${sargs[@]}"
check "S1b exit 0" '[ $rc = 0 ]'
check "S1b worker git-guard.json merges the repo file with commit auto" '[ "$(jq -S -c . "$(wt)/.stratum/git-guard.json")" = "$(jq -S -c -n "{force_push:\"deny\",commit:\"auto\"}")" ] && [ "$(grep -c . "$(wt)/.stratum/git-guard.json")" = 1 ]'
check "S1b repo git-guard.json is unchanged" '[ "$(cat "$repo/.stratum/git-guard.json")" = "{\"force_push\":\"deny\"}" ]'
rm -f "$repo/.stratum/git-guard.json"

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
run bash "$script" goal T004 --test "$testcmd"
check "S3 goal exit 0" '[ $rc = 0 ]'
check "S3 goal sends exactly one agent prompt with P" 'hascall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P" && never 0 1'

fresh
STUB_FAIL="worktree create" run bash "$script" start "${sargs[@]}"
check "S4 exit 1" '[ $rc = 1 ]'
check "S4 stopped line with the stub message" 'grep -q "^stopped: .*stub refused" <<<"$out"'
check "S4 worker line has - ids" 'hasline "worker\tworker-t004\tlocal\t-\t-\t-\t-"'
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
run bash "$script" goal T004 --test "$testcmd"
check "S7 goal exit 0, exactly one prompt" '[ $rc = 0 ] && never 0 1'

fresh; states idle
run bash "$script" start "${sargs[@]}"
check "S8 exit 0" '[ $rc = 0 ]'
check "S8 agent get idle prints state working, no idle" 'hasline "state\tworking\tworker-t004\t%s" "$(pane)" && ! grep -q idle <<<"$out"'

fresh
STUB_WT_PATH="$tmp/elsewhere" run bash "$script" start "${sargs[@]}"
check "S9 exit 1" '[ $rc = 1 ]'
check "S9 stopped line names both paths" 'hasline "stopped: herdr made the worktree in %s, not %s" "$tmp/elsewhere" "$tmp/repo-worker-t004"'
check "S9 worker line with the ids made so far" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$tmp/elsewhere"'
check "S9 no agent start, no prompt" '[ "$(cnt "^agent\tstart\t")" = 0 ] && never 0 0'

fresh
git -C "$repo" worktree add -q "$tmp/repo-feat" -b feat
git -C "$tmp/repo-feat" -c user.name=t -c user.email=t@t commit -q --allow-empty -m feat
featsha=$(git -C "$tmp/repo-feat" rev-parse HEAD)
printf '{"force_push":"deny"}\n' > "$tmp/repo-feat/.stratum/git-guard.json"
repo="$tmp/repo-feat" run bash "$script" start "${sargs[@]}"
check "S10 exit 0" '[ $rc = 0 ]'
check "S10 worktree create from the main checkout, base is the linked worktree HEAD" '[ "$featsha" != "$sha" ] && [ "$(cnt "^worktree\tcreate\t")" = 1 ] && hascall "worktree\tcreate\t--cwd\t%s\t--branch\tworker-t004\t--base\t%s\t--path\t%s\t--label\tworker-t004\t--no-focus" "$repo" "$featsha" "$tmp/repo-worker-t004"'
check "S10 guard file read from the linked worktree" '[ ! -e "$repo/.stratum/git-guard.json" ] && [ "$(jq -S -c . "$(wt)/.stratum/git-guard.json")" = "$(jq -S -c -n "{force_push:\"deny\",commit:\"auto\"}")" ]'
check "S10 never-list, one prompt" 'never 0 1'
git -C "$repo" worktree remove --force "$tmp/repo-feat"
git -C "$repo" branch -q -D feat

startcall() { printf 'agent\tstart\tworker-t004\t--kind\tclaude\t--pane\t%s\t--timeout\t120000\t--\t--permission-mode\tauto\t-n\tworker-t004' "$(pane)"; }
busylog() { local i; for ((i = 1; i <= $1; i++)); do printf '%s\nsleep\t1\n' "$(startcall)"; done; startcall; }
fresh
STUB_BUSY=3 run bash "$script" start "${sargs[@]}"
check "S11 exit 0" '[ $rc = 0 ]'
check "S11 four agent start calls with the same argv, a sleep 1 after each busy one" '[ "$(grep -P "^(agent\tstart|sleep)\t" "$tmp/calls")" = "$(busylog 3)" ]'
check "S11 then one agent prompt" '[ "$(grep -P "^(agent\tstart|sleep|agent\tprompt)\t" "$tmp/calls" | tail -1 | cut -f1,2)" = "$(printf "agent\tprompt")" ] && never 0 1'
check "S11 worker and state lines" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$(wt)" && hasline "state\tworking\tworker-t004\t%s" "$(pane)"'

fresh
STUB_FAIL="agent start" STUB_FAIL_CODE=agent_pane_busy run bash "$script" start "${sargs[@]}"
check "S11b exit 1" '[ $rc = 1 ]'
check "S11b exactly 10 agent start calls, 9 sleep 1" '[ "$(cnt "^agent\tstart\t")" = 10 ] && [ "$(cnt "^sleep\t1\$")" = 9 ] && [ "$(grep -P "^(agent\tstart|sleep)\t" "$tmp/calls")" = "$(busylog 9)" ]'
check "S11b stopped line with the stub agent_pane_busy line" 'grep -qxF "stopped: {\"error\":{\"code\":\"agent_pane_busy\",\"message\":\"stub refused\"}}" <<<"$out"'
check "S11b worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$(wt)"'
check "S11b no agent prompt, nothing closed" 'never 0 0'

fresh; run bash "$script" start 'bad id' --task "$task" --test "$testcmd" --lane "$lane" --roster "$roster"
prej P1 "Task id must be letters, digits or dash, start with a letter or digit, and be at most 25 characters."
fresh; run bash "$script" start T004 --task "$tmp/nofile" --test "$testcmd" --lane "$lane" --roster "$roster"
prej P2 "Task file not found or empty: $tmp/nofile"
: > "$tmp/empty"
fresh; run bash "$script" start T004 --task "$tmp/empty" --test "$testcmd" --lane "$lane" --roster "$roster"
prej P2b "Task file not found or empty: $tmp/empty"
fresh; run bash "$script" start T004 --task "$task" --test 'foo (bar)' --lane "$lane" --roster "$roster"
prej P3 "Test command must be one line with no ( or )."
fresh; run bash "$script" start T004 --task "$task" --test "$testcmd" --lane $'a\nb' --roster "$roster"
prej P4 "Lane must be one line."
printf 'worker-t004\tlocal\tworker-t004\tT004\nbroken\tline\n' > "$tmp/roster_bad"
fresh; run bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$tmp/roster_bad"
prej P5 "Roster line 2 must be: name, machine, branch, task, split by TAB."
printf 'worker-t004\tlocal\t\tworker-t004\tT004\n' > "$tmp/roster_empty"
fresh; run bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$tmp/roster_empty"
prej P5c "Roster line 1 must be: name, machine, branch, task, split by TAB."
printf 'worker-t004\tlocal\tworker-t004\tT004\nworker-t005\tlocal\tworker-t005\tT005\n\n' > "$tmp/roster_blank"
fresh; run bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$tmp/roster_blank"
check "P5d roster with a trailing blank line starts, two roster rows" '[ $rc = 0 ] && [ "$(grep -c "^| worker-" "$(wt)/brief.md")" = 2 ]'
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
run bash "$script" wait T004
check "W1 exit 0" '[ $rc = 0 ]'
check "W1 state finished" 'hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
check "W1 finds the worker by label and workspace" 'hascall "worktree\tlist\t--workspace\t%s" "$(wsid)" && [ "$(cnt "^agent\twait\tworker-t004\t--timeout\t")" = 1 ]'
check "W1 never-list, no prompt, no pane text" 'never 0 0 && nopane'

mk; states working
STUB_FAIL="agent wait" STUB_FAIL_CODE=timeout run bash "$script" wait T004
check "W2 exit 3" '[ $rc = 3 ]'
check "W2 state working with the pane" 'hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
check "W2 never-list" 'never 0 0'

mk; states idle done; : > "$tmp/resume_result"
run bash "$script" wait T004
check "W3 exit 0" '[ $rc = 0 ]'
check "W3 state finished" 'hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
check "W3 two waits without --until, one resume check with it" '[ "$(grep -P "^agent\twait\t" "$tmp/calls" | grep -vc -- "--until")" = 2 ] && [ "$(grep -P "^agent\twait\t" "$tmp/calls" | grep -c -- "--until")" = 1 ]'
check "W3 never-list" 'never 0 0'

mk; states idle
STUB_FAIL_UNTIL="agent wait" STUB_FAIL_CODE=timeout run bash "$script" wait T004
check "W4 exit 5" '[ $rc = 5 ]'
check "W4 state stopped, pane text, the stub pane text" 'hasline "state\tstopped\tworker-t004\t%s" "$(pane)" && paneshown'
check "W4 never-list" 'never 0 0'

mk; states blocked
run bash "$script" wait T004
check "W5 exit 4" '[ $rc = 4 ]'
check "W5 state blocked with the worker name, pane text" 'hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && paneshown'
check "W5 never-list" 'never 0 0'

g1() {
  mk
  printf 'RESULT FILE %s\n' "$(rnd)" > "$(wt)/result.md"
  run bash "$1" result T004
  check "G1 exit 0" '[ $rc = 0 ]'
  check "G1 result line and the file text" 'hasline "result\tworker-t004\t%s/result.md" "$(wt)" && grep -qxF "RESULT FILE $(rnd)" <<<"$out"'
  check "G1 the pane is not printed and not read" 'nopane && [ "$(cnt "^agent\tread\t")" = 0 ]'
  check "G1 never-list" 'never 0 0'
}
g1 "$script"

mk
run bash "$script" result T004
check "G2 exit 1" '[ $rc = 1 ]'
check "G2 no result file line, pane text, the stub pane text" 'grep -qxF "no result file: $(wt)/result.md" <<<"$out" && paneshown'
check "G2 never-list" 'never 0 0'

mk; states done
run bash "$script" close T004
check "C1 exit 0" '[ $rc = 0 ]'
check "C1 one workspace close on the stub WS" 'hascall "workspace\tclose\t%s" "$(wsid)" && never 1 0'
check "C1 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'

mk; states working
run bash "$script" close T004
check "C2 exit 1" '[ $rc = 1 ]'
check "C2 the refuse line, no closed line, no workspace close" '[ "$out" = "Worker worker-t004 is working. Close refused." ] && ! grep -q "^closed" <<<"$out" && never 0 0'

mk; states done
STUB_KEEP_AGENT=1 run bash "$script" close T004
check "C3 exit 1" '[ $rc = 1 ]'
check "C3 close left agent line" 'grep -qxF "close left agent worker-t004" <<<"$out"'
check "C3 one workspace close on the stub WS" 'hascall "workspace\tclose\t%s" "$(wsid)" && never 1 0'

fresh
run bash "$script" close T004
check "C4 exit 1" '[ $rc = 1 ]'
check "C4 no worker line, no workspace close" 'grep -qxF "No worker worker-t004 on local." <<<"$out" && never 0 0'

mk; states done
STUB_FAIL="agent get" run bash "$script" close T004
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

sendlog() { grep -P '^(agent\t(get|send-keys|wait)|pane\tsend-text)\t' "$tmp/calls"; }
a1() {
  mk; states blocked working
  run bash "$1" answer T004 --keys 1
  check "A1 exit 0" '[ $rc = 0 ]'
  check "A1 agent get, one send-keys, agent wait until working, agent get, in order" '[ "$(sendlog)" = "$(printf "agent\tget\tworker-t004\nagent\tsend-keys\tworker-t004\t1\nagent\twait\tworker-t004\t--until\tworking\t--timeout\t5000\nagent\tget\tworker-t004")" ]'
  check "A1 state line after the answer" 'hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
  check "A1 never-list, no prompt" 'never 0 0'
}
a2() {
  mk; states working
  run bash "$1" answer T004 --text yes
  check "A2 exit 1" '[ $rc = 1 ]'
  check "A2 the not blocked line" '[ "$out" = "not blocked: working" ]'
  check "A2 one agent get, no send-keys, no send-text" '[ "$(cnt "^agent\tget\t")" = 1 ] && [ "$(cnt "^agent\tsend-keys\t")" = 0 ] && [ "$(cnt "^pane\tsend-text\t")" = 0 ] && never 0 0'
}
a3() {
  mk; states blocked blocked
  STUB_FAIL_UNTIL="agent wait" STUB_FAIL_CODE=timeout run bash "$1" answer T004 --text "use main"
  check "A3 exit 4" '[ $rc = 4 ]'
  check "A3 agent get, send-text, send-keys enter, agent wait until working, agent get, in order" '[ "$(sendlog)" = "$(printf "agent\tget\tworker-t004\npane\tsend-text\t%s\tuse main\nagent\tsend-keys\tworker-t004\tenter\nagent\twait\tworker-t004\t--until\tworking\t--timeout\t5000\nagent\tget\tworker-t004" "$(pane)")" ]'
  check "A3 state blocked line" 'hasline "state\tblocked\tworker-t004\t%s" "$(pane)"'
  check "A3 never-list, no prompt" 'never 0 0'
}
a1 "$script"
a2 "$script"
a3 "$script"
for a in --keys --text; do
  fresh; reset
  run bash "$script" answer T004 $a -x
  check "A4 $a -x exit 2, the dash line" '[ $rc = 2 ] && [ "$out" = "Answer values must not start with -." ]'
  check "A4 $a -x no herdr call" '[ ! -s "$tmp/calls" ]'
done

nc() {
  local nm=$1 fn=$2
  check "$1 sed changed the script" '[ -f "$script" ] && ! cmp -s "$script" "$tmp/$nm.sh"'
  check "$1 copy parses" 'bash -n "$tmp/$nm.sh"'
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
sed -E 's/cat( --)? [^|;&)]*result\.md[^|;&)]*/herdr agent read worker-t004 --source recent-unwrapped --lines 40/' "$script" > "$tmp/NC4.sh" 2>/dev/null
nc NC4 g1
sed -E '/>"\$WT\/\.stratum\/git-guard\.json"/d' "$script" > "$tmp/NC7.sh" 2>/dev/null
check "NC7 sed deletes exactly one line" '[ "$(diff "$script" "$tmp/NC7.sh" | grep -c "^<")" = 1 ]'
nc NC7 s1
sed -E '/not blocked: /d' "$script" > "$tmp/NC5.sh" 2>/dev/null
check "NC5 sed deletes exactly one line" '[ "$(diff "$script" "$tmp/NC5.sh" | grep -c "^<")" = 1 ]'
nc NC5 a2

rroster="$tmp/rroster"
printf 'worker-t004\tlaptop\tworker-t004\tT004\nworker-t005\tlocal\tworker-t005\tT005\n' > "$rroster"
rsargs=(T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop --repo '~/proj')
rfresh() { fresh; : > "$tmp/ssh"; : > "$tmp/gitlog"; rm -f "$tmp"/ssh_in.* "$tmp/ssh_has_result"; }
rrun() { HENV=0 run "$@"; }
rmk() { rfresh; rrun bash "$script" start "${rsargs[@]}"; reset; : > "$tmp/ssh"; rm -f "$tmp"/ssh_in.* "$tmp/n_ssh"; }
sshs() { tr '\t' ' ' < "$tmp/ssh"; }
mach() { awk -F'\t' '$0=="machine\tlist\t--json"{next} !($1=="--machine"&&$2=="laptop"){bad=1} END{exit bad}' "$tmp/calls"; }
rcnt() { grep -cP "^--machine\tlaptop\t$1" "$tmp/calls"; }
rcall() { local f=$1; shift; grep -qxF -- "$(printf -- "--machine\tlaptop\t$f" "$@")" "$tmp/calls"; }
rnorm() { sed -E 's/^--machine\tlaptop\t//' "$tmp/calls"; }
rnever() {
  ! grep -qx BARE "$tmp/calls" && ! grep -q w1P "$tmp/calls" && hascall "machine\tlist\t--json" && mach &&
  ! rnorm | grep -qP '(^|\t)(--current|--session|--remote|--trust-repository|--group)(\t|$)' &&
  ! rnorm | grep -qP '^(pane\tclose|worktree\tremove|server\t|machine\t(reconnect|add|remove|enable|disable)(\t|$))' &&
  [ "$(rcnt 'workspace\tclose\t')" = "$1" ] && [ "$(rcnt 'agent\tprompt\t')" = "$2" ]
}
rreadonly() { ! grep -qvP '^(machine\tlist\t--json|--machine\tlaptop\tworkspace\tlist)$' "$tmp/calls"; }
rrej() {
  local n=$1 ph=$2
  rfresh; shift 2
  rrun bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" "$@"
  check "$n exit 1" '[ $rc = 1 ]'
  check "$n one line, the phrase" '[ "$(printf "%s\n" "$out" | grep -c .)" = 1 ] && [ "$out" = "$ph" ]'
  check "$n only machine list and workspace list calls" 'rreadonly'
}

r1() {
  rfresh; STUB_WT_PATH=/home/u/proj-worker-t004 rrun bash "$1" start "${rsargs[@]}"
  local in="$tmp/ssh_in.1" g; g=$(printf '%q' '{"commit":"auto"}')
  check "R1 exit 0" '[ $rc = 0 ]'
  check "R1 machine list, every other call starts --machine laptop, never-list, one prompt" 'rnever 0 1'
  check "R1 workspace list on the machine" 'rcall "workspace\tlist"'
  check "R1 worktree create has --path ~/proj-worker-t004" 'rcall "worktree\tcreate\t--cwd\t%s\t--branch\tworker-t004\t--base\t%s\t--path\t%s\t--label\tworker-t004\t--no-focus" "~/proj" "$sha" "~/proj-worker-t004"'
  check "R1 one ssh call to the saved target with BatchMode" '[ "$(grep -c . "$tmp/ssh")" = 1 ] && grep -qP "^-o\tBatchMode=yes\t--\tu@stubhost\t" "$tmp/ssh"'
  check "R1 ssh writes brief.md and git-guard.json under the path herdr answered" 'c=$(sshs); [ "$(wt)" = /home/u/proj-worker-t004 ] && grep -qF -- "cat > /home/u/proj-worker-t004/brief.md" <<<"$c" && grep -qF -- "mkdir -p /home/u/proj-worker-t004/.stratum" <<<"$c" && grep -qF -- "> /home/u/proj-worker-t004/.stratum/git-guard.json" <<<"$c" && grep -qF -- "$g" <<<"$c" && ! grep -qF -- "~/proj-worker-t004" "$tmp/ssh"'
  check "R1 brief on ssh stdin: heading, task, machine, result path" 'grep -qxF "# Brief: worker-t004" "$in" && grep -qxF "TASK BODY $(rnd)" "$in" && grep -qxF -- "- Your machine: laptop. \`local\` is the orchestrator'"'"'s machine." "$in" && grep -qxF -- "- Result file: /home/u/proj-worker-t004/result.md" "$in"'
  check "R1 brief on ssh stdin: roster rows and the four rules" 'grep -qxF "| worker-t004 | laptop | worker-t004 | T004 |" "$in" && grep -qxF "| worker-t005 | local | worker-t005 | T005 |" "$in" && [ "$(grep -cxFf "$rules" "$in")" = 4 ]'
  check "R1 nothing written on this machine" '[ ! -e "$tmp/repo-worker-t004" ] && [ ! -e "$repo/~" ]'
  check "R1 agent start argv" 'rcall "agent\tstart\tworker-t004\t--kind\tclaude\t--pane\t%s\t--timeout\t120000\t--\t--permission-mode\tauto\t-n\tworker-t004" "$(pane)"'
  check "R1 agent prompt with P" 'rcall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P"'
  check "R1 worker line names laptop, ids from the stub log" 'hasline "worker\tworker-t004\tlaptop\t%s\t%s\tworker-t004\t%s" "$(wsid)" "$(pane)" "$(wt)"'
}
r1 "$script"

rfresh; rrun bash "$script" start "${rsargs[@]}"
check "R1b exit 0" '[ $rc = 0 ]'
check "R1b ssh writes brief.md under ~/proj-worker-t004, no \\~" 'sshs | grep -qF -- "cat > ~/proj-worker-t004/brief.md" && ! grep -qF -- "\\~" "$tmp/ssh"'

rfresh; STUB_SSH_RC=255 rrun bash "$script" start "${rsargs[@]}"
check "R1c ssh down on start: exit 1, one stopped line, one worker line" '[ $rc = 1 ] && [ "$(grep -c "^stopped: ssh to u@stubhost failed" <<<"$out")" = 1 ] && [ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && [ "$(grep -cP "^worker\t" <<<"$out")" = 1 ]'

rmk
git -C "$repo" branch -q worker-t004
bsha=$(git -C "$repo" rev-parse worker-t004)
rrun bash "$script" result T004 --machine laptop
check "R2 exit 0" '[ $rc = 0 ]'
check "R2 one ssh cat of the quoted result path" '[ "$(grep -c . "$tmp/ssh")" = 1 ] && grep -qP "^-o\tBatchMode=yes\t--\tu@stubhost\t" "$tmp/ssh" && sshs | grep -qF -- "cat -- ~/proj-worker-t004/result.md"'
check "R2 result line and the file text" 'hasline "result\tworker-t004\t~/proj-worker-t004/result.md" && grep -qxF "RESULT FILE $(rnd)" <<<"$out"'
check "R2 one git fetch of target:WT worker-t004:worker-t004 with GIT_SSH_COMMAND BatchMode" '[ "$(grep -c . "$tmp/gitlog")" = 1 ] && grep -qxF "$(printf "ENV=ssh -o BatchMode=yes\tfetch\tu@stubhost:~/proj-worker-t004\tworker-t004:worker-t004")" "$tmp/gitlog"'
check "R2 fetched line has the branch sha" 'hasline "fetched\tworker-t004\t%s" "$bsha"'
check "R2 the pane is not printed, never-list" 'nopane && rnever 0 0'
git -C "$repo" branch -q -D worker-t004

rmk
STUB_SSH_RC=255 rrun bash "$script" result T004 --machine laptop
check "R2b ssh down on result: exit 1, one stopped line, no result file line, no pane text" '[ $rc = 1 ] && [ "$(grep -c "^stopped: ssh to u@stubhost failed" <<<"$out")" = 1 ] && [ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && ! grep -q "^no result file" <<<"$out" && nopane && ! grep -qxF "pane text:" <<<"$out"'

rmk; states done; : > "$tmp/ssh_has_result"
rrun bash "$script" wait T004 --machine laptop
check "R3 exit 0" '[ $rc = 0 ]'
check "R3 state finished" 'hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
check "R3 the result check is one ssh test -f" '[ "$(grep -c . "$tmp/ssh")" = 1 ] && grep -qP "^-o\tBatchMode=yes\t--\tu@stubhost\t" "$tmp/ssh" && sshs | grep -qF -- "test -f ~/proj-worker-t004/result.md"'
check "R3 never-list" 'rnever 0 0'
rmk; states done
STUB_FAIL_UNTIL="agent wait" STUB_FAIL_CODE=timeout rrun bash "$script" wait T004 --machine laptop
check "R3b no result file on the machine: exit 5, state stopped" '[ $rc = 5 ] && hasline "state\tstopped\tworker-t004\t%s" "$(pane)" && sshs | grep -qF -- "test -f ~/proj-worker-t004/result.md"'

rrej R4 "Unknown machine: nosuch. Saved: laptop." --machine nosuch --repo '~/proj'
STUB_DOWN=1 rrej R5 "Machine laptop does not answer: Error: stub machine down" --machine laptop --repo '~/proj'
STUB_ML=fail rrej R6 "herdr machine list failed." --machine laptop --repo '~/proj'
STUB_ML=junk rrej R7 "herdr machine list gave no machine list." --machine laptop --repo '~/proj'

rfresh
rrun bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop
prej R8 "A saved machine needs --repo <path> starting with / or ~."
rfresh
rrun bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop --repo proj
prej R8b "A saved machine needs --repo <path> starting with / or ~."

rmk; states done
rrun bash "$script" close T004 --machine laptop
check "R9 exit 0" '[ $rc = 0 ]'
check "R9 one workspace close on the stub WS, --machine rule" 'rcall "workspace\tclose\t%s" "$(wsid)" && rnever 1 0'
check "R9 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'

rmk; states blocked working
rrun bash "$script" answer T004 --machine laptop --keys 1
check "R10 exit 0" '[ $rc = 0 ]'
check "R10 one agent send-keys, --machine rule" '[ "$(rcnt "agent\tsend-keys\t")" = 1 ] && rcall "agent\tsend-keys\tworker-t004\t1" && rnever 0 0'

rmk
rrun bash "$script" goal T004 --machine laptop --test "$testcmd"
check "R11 exit 0" '[ $rc = 0 ]'
check "R11 exactly one agent prompt with P, --machine rule" 'rcall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P" && rnever 0 1'

rfresh
x=$(rnd)
jq -nc --arg x "$x" '[{workspace_id:("stubA"+$x),label:"worker-t004"},{workspace_id:("stubB"+$x),label:"worker-t005"},{workspace_id:("stubC"+$x),label:"notaworker"}]' > "$tmp/ws.json"
jq -nc --arg x "$x" '[{path:("/stub/a"+$x),branch:"worker-t004",open_workspace_id:("stubA"+$x)},{path:("/stub/b"+$x),branch:"worker-t005",open_workspace_id:("stubB"+$x)},{path:("/stub/c"+$x),branch:"notaworker",open_workspace_id:("stubC"+$x)}]' > "$tmp/wt.json"
jq -nc --arg x "$x" '[{name:"worker-t004",pane_id:("stubA"+$x+":p1"),workspace_id:("stubA"+$x),agent_status:"blocked"}]' > "$tmp/agents.json"
rrun bash "$script" list --machine laptop
check "R12 exit 0" '[ $rc = 0 ]'
check "R12 found lines name laptop, the other workspace is absent" '[ "$(grep -cP "^found\t" <<<"$out")" = 2 ] && hasline "found\tworker-t004\tlaptop\tstubA%s\tstubA%s:p1\tblocked\t/stub/a%s" "$x" "$x" "$x" && hasline "found\tworker-t005\tlaptop\tstubB%s\t-\tgone\t/stub/b%s" "$x" "$x" && ! grep -q notaworker <<<"$out"'
check "R12 --machine rule, never-list" 'rnever 0 0'

h1() {
  fresh; rm -f "$tmp/claude_args" "$tmp/brief.path" "$tmp/brief.copy" "$tmp/claude_nums" "$tmp/timeout_args"
  run bash "$1" headless T004 --task "$task" --test "$testcmd"
  local bp turns cost hp
  bp=$(cat "$tmp/brief.path" 2>/dev/null); turns=$(sed -n 1p "$tmp/claude_nums" 2>/dev/null); cost=$(sed -n 2p "$tmp/claude_nums" 2>/dev/null)
  hp="/goal \`$testcmd\` exits 0 and the change is left uncommitted; read $bp first and follow it"
  check "H1 exit 0" '[ $rc = 0 ]'
  check "H1 claude argv is exactly the contract flags, in order" '[ "$(cat "$tmp/claude_args" 2>/dev/null)" = "$(printf "%s\n" -p "$hp" --output-format json --max-turns 30 -n worker-t004 --tools Read,Edit,Write,Glob,Grep,Bash --allowedTools Read Edit Write Glob Grep "Bash($testcmd)" --permission-mode dontAsk --permission-prompts none --strict-mcp-config)" ]'
  check "H1 brief file is outside the repo" '[ -n "$bp" ] && [ "$(dirname "$bp")" != "$repo" ] && [[ "$bp" != "$repo"/* ]] && [[ "$bp" == /* ]]'
  check "H1 brief heading and task text" 'grep -qxF "# Brief: worker-t004 (headless)" "$tmp/brief.copy" && grep -qxF "## Task T004" "$tmp/brief.copy" && grep -qxF "TASK BODY $(rnd)" "$tmp/brief.copy"'
  check "H1 brief facts" 'grep -qxF -- "- Test command: \`$testcmd\`" "$tmp/brief.copy" && grep -qxF -- "- Work in this folder. Leave the change uncommitted: never commit, never push." "$tmp/brief.copy" && grep -qxF -- "- Run the test command exactly as written, as one Bash call." "$tmp/brief.copy" && grep -qxF -- "- You cannot ask questions. If you need a decision, stop and say in your last reply what is missing." "$tmp/brief.copy"'
  check "H1 headless line" 'hasline "headless\tworker-t004\tsuccess\t%s\t%s" "$turns" "$cost"'
  check "H1 result: line then the stub result text" '[ "$(grep -xF -A1 "result:" <<<"$out" | tail -n1)" = "HEADLESS $(rnd)" ]'
  check "H1 no herdr call" '[ ! -s "$tmp/calls" ]'
  check "H1 timeout is called with -k 10 540 before claude" 'grep -qP "^-k\t10\t540\tclaude\t" "$tmp/timeout_args" 2>/dev/null'
}
h1 "$script"
check "H5 brief file is gone after the run" 'bp=$(cat "$tmp/brief.path" 2>/dev/null); [ -n "$bp" ] && [ ! -e "$bp" ]'

fresh
old=$(git -C "$repo" rev-parse HEAD)
STUB_CLAUDE=commit run bash "$script" headless T004 --task "$task" --test "$testcmd"
new=$(git -C "$repo" rev-parse HEAD)
check "H2 exit 1, worker committed line" '[ $rc = 1 ] && [ "$new" != "$old" ] && hasline "worker committed: %s -> %s" "$old" "$new"'
git -C "$repo" reset -q --hard "$sha"

fresh
STUB_CLAUDE=commitjunk run bash "$script" headless T004 --task "$task" --test "$testcmd"
new=$(git -C "$repo" rev-parse HEAD)
check "H2b commit and junk output: exit 1, worker committed line wins" '[ $rc = 1 ] && [ "$new" != "$sha" ] && hasline "worker committed: %s -> %s" "$sha" "$new" && ! grep -q "no JSON" <<<"$out"'
git -C "$repo" reset -q --hard "$sha"

fresh
STUB_CLAUDE=commitslow run bash "$script" headless T004 --task "$task" --test "$testcmd"
new=$(git -C "$repo" rev-parse HEAD)
check "H3b commit then timeout: exit 1, worker committed line wins, no timed out line" '[ $rc = 1 ] && [ "$new" != "$sha" ] && hasline "worker committed: %s -> %s" "$sha" "$new" && ! grep -q "timed out" <<<"$out"'
git -C "$repo" reset -q --hard "$sha"

fresh
STUB_CLAUDE=slow run bash "$script" headless T004 --task "$task" --test "$testcmd"
check "H3 exit 1, timed out line" '[ $rc = 1 ] && hasline "timed out after 540 s"'

fresh
STUB_CLAUDE=killed run bash "$script" headless T004 --task "$task" --test "$testcmd"
check "H3c killed (137): exit 1, timed out line" '[ $rc = 1 ] && hasline "timed out after 540 s"'

fresh
STUB_CLAUDE=junk run bash "$script" headless T004 --task "$task" --test "$testcmd"
check "H4 exit 1, no JSON line" '[ $rc = 1 ] && hasline "claude gave no JSON result."'

fresh
STUB_CLAUDE=errturns run bash "$script" headless T004 --task "$task" --test "$testcmd"
turns=$(sed -n 1p "$tmp/claude_nums"); cost=$(sed -n 2p "$tmp/claude_nums")
check "H6 error_max_turns: exit 1, headless line and result text print" '[ $rc = 1 ] && hasline "headless\tworker-t004\terror_max_turns\t%s\t%s" "$turns" "$cost" && [ "$(grep -xF -A1 "result:" <<<"$out" | tail -n1)" = "ERRTURNS $(rnd)" ]'

fresh; rm -f "$tmp/claude_nums"
NOENV=1 run bash "$script" headless T004 --task "$task" --test "$testcmd"
turns=$(sed -n 1p "$tmp/claude_nums" 2>/dev/null); cost=$(sed -n 2p "$tmp/claude_nums" 2>/dev/null)
check "H7 no HERDR_ENV: exit 0, same headless and result lines as H1, no herdr call" '[ $rc = 0 ] && hasline "headless\tworker-t004\tsuccess\t%s\t%s" "$turns" "$cost" && [ "$(grep -xF -A1 "result:" <<<"$out" | tail -n1)" = "HEADLESS $(rnd)" ] && [ ! -s "$tmp/calls" ]'

fresh; rm -f "$tmp/claude_args"
run bash "$script" headless T004 --task "$task" --test "$testcmd" --machine laptop
check "H8 --machine: usage line, exit 2, no herdr call, no claude call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ] && [ ! -e "$tmp/claude_args" ]'

fresh; rm -f "$tmp/claude_args" "$tmp/claude_pwd"
mkdir -p "$repo/sub"
RUNDIR="$repo/sub" run bash "$script" headless T004 --task "$task" --test "$testcmd"
bp=$(cat "$tmp/brief.path" 2>/dev/null)
check "H9 from a subfolder: exit 0, brief outside the repo, claude ran in the toplevel" '[ $rc = 0 ] && [ -n "$bp" ] && [[ "$bp" != "$repo"/* ]] && [ "$(cat "$tmp/claude_pwd" 2>/dev/null)" = "$repo" ]'
fresh
STUB_CLAUDE=commit RUNDIR="$repo/sub" run bash "$script" headless T004 --task "$task" --test "$testcmd"
new=$(git -C "$repo" rev-parse HEAD)
check "H9 from a subfolder: HEAD compare sees the worker commit" '[ $rc = 1 ] && [ "$new" != "$sha" ] && hasline "worker committed: %s -> %s" "$sha" "$new"'
git -C "$repo" reset -q --hard "$sha"
rmdir "$repo/sub"

fresh; rm -f "$tmp/claude_args"
run bash "$script" headless T004 --task "$task" --test 'grep -q a *'
check "H10 headless rejects * in the test: one line, exit 1, no claude call" '[ $rc = 1 ] && [ "$out" = "Test command must not contain * for headless." ] && [ ! -e "$tmp/claude_args" ]'
fresh
run bash "$script" start T004 --task "$task" --test 'grep -q a *' --lane "$lane" --roster "$roster"
check "H10 start still accepts * in the test" '! grep -qF "must not contain *" <<<"$out"'

mphrase='Model must be one token of letters, digits, dot, underscore or dash, starting with a letter or digit.'
mfile="$repo/.stratum/models.json"
startargv() { printf 'agent\tstart\tworker-t004\t--kind\tclaude\t--pane\t%s\t--timeout\t120000\t--\t%s' "$(pane)" "$1"; }

fresh; rm -f "$mfile"
run bash "$script" start "${sargs[@]}" --model opus
check "M1 exit 0" '[ $rc = 0 ]'
check "M1 agent start args after -- are exactly the mode, name and model" 'hascall "$(startargv "--permission-mode	auto	-n	worker-t004	--model	opus")"'
check "M1 brief has Model: opus" 'grep -qxF -- "- Model: opus" "$(wt)/brief.md"'

fresh
printf '{"st-worker":{"model":"sonnet","effort":"high"}}\n' > "$mfile"
run bash "$script" start "${sargs[@]}"
check "M2 exit 0" '[ $rc = 0 ]'
check "M2 models.json model reaches the args" 'hascall "$(startargv "--permission-mode	auto	-n	worker-t004	--model	sonnet")"'
check "M2 brief has Model: sonnet" 'grep -qxF -- "- Model: sonnet" "$(wt)/brief.md"'
rm -f "$mfile"

fresh
run bash "$script" start "${sargs[@]}"
check "M3 exit 0" '[ $rc = 0 ]'
check "M3 args after -- have no --model" 'hascall "$(startargv "--permission-mode	auto	-n	worker-t004")"'
check "M3 brief has Model: default" 'grep -qxF -- "- Model: default" "$(wt)/brief.md"'

fresh
run bash "$script" start "${sargs[@]}" --model 'a b'
prej "M4 space" "$mphrase"
fresh
run bash "$script" start "${sargs[@]}" --model 'x;y'
prej "M4 semicolon" "$mphrase"
fresh
printf '{"st-worker":{"model":"x;y"}}\n' > "$mfile"
run bash "$script" start "${sargs[@]}"
prej "M4 models.json value" "$mphrase"
rm -f "$mfile"
fresh
printf '{"st-worker":{"model":"--dangerously-skip-permissions"}}\n' > "$mfile"
run bash "$script" start "${sargs[@]}"
prej "M4d start models.json leading dash" "$mphrase"
fresh; rm -f "$tmp/claude_args"
run bash "$script" headless T004 --task "$task" --test "$testcmd"
prej "M4d headless models.json leading dash" "$mphrase"
check "M4d headless no claude call" '[ ! -e "$tmp/claude_args" ]'
rm -f "$mfile"
fresh
run bash "$script" start "${sargs[@]}" --model -x
prej "M4d start --model -x" "$mphrase"
fresh; rm -f "$tmp/claude_args"
run bash "$script" headless T004 --task "$task" --test "$testcmd" --model -x
prej "M4d headless --model -x" "$mphrase"
check "M4d headless --model -x no claude call" '[ ! -e "$tmp/claude_args" ]'

fresh; rm -f "$tmp/claude_args" "$tmp/brief.copy"
run bash "$script" headless T004 --task "$task" --test "$testcmd" --model opus
check "M5 exit 0" '[ $rc = 0 ]'
check "M5 claude argv has --model opus right after -n worker-t004" '[[ "$(tr "\n" " " < "$tmp/claude_args")" == *"-n worker-t004 --model opus "* ]]'
check "M5 headless brief has Model: opus" 'grep -qxF -- "- Model: opus" "$tmp/brief.copy"'

fresh; rm -f "$tmp/claude_args" "$tmp/brief.copy"
printf '{"st-worker":{"model":"haiku"}}\n' > "$mfile"
run bash "$script" headless T004 --task "$task" --test "$testcmd"
check "M6 exit 0" '[ $rc = 0 ]'
check "M6 claude argv has --model haiku right after -n worker-t004" '[[ "$(tr "\n" " " < "$tmp/claude_args")" == *"-n worker-t004 --model haiku "* ]]'
check "M6 headless brief has Model: haiku" 'grep -qxF -- "- Model: haiku" "$tmp/brief.copy"'
rm -f "$mfile"

fresh; rm -f "$tmp/claude_args" "$tmp/brief.copy"
run bash "$script" headless T004 --task "$task" --test "$testcmd"
check "M6 no file: exit 0" '[ $rc = 0 ]'
check "M6 no file: no --model in claude argv" '[ -s "$tmp/claude_args" ] && ! grep -qxF -- --model "$tmp/claude_args"'
check "M6 no file: headless brief has Model: default" 'grep -qxF -- "- Model: default" "$tmp/brief.copy"'

fresh; rm -f "$tmp/claude_args"
run bash "$script" start "${sargs[@]}" --model
check "M7 start --model without a value: usage line, exit 2, no call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ]'
fresh
run bash "$script" start "${sargs[@]}" --model opus --model sonnet
check "M7 start --model twice: usage line, exit 2, no call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ]'
fresh; rm -f "$tmp/claude_args"
run bash "$script" headless T004 --task "$task" --test "$testcmd" --model
check "M7 headless --model without a value: usage line, exit 2, no call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ] && [ ! -e "$tmp/claude_args" ]'
fresh; rm -f "$tmp/claude_args"
run bash "$script" headless T004 --task "$task" --test "$testcmd" --model opus --model sonnet
check "M7 headless --model twice: usage line, exit 2, no call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ] && [ ! -e "$tmp/claude_args" ]'
fresh
run bash "$script" start "${sargs[@]}" --model ''
check "M7 start --model empty: usage line, exit 2, no call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ]'
fresh; rm -f "$tmp/claude_args"
run bash "$script" headless T004 --task "$task" --test "$testcmd" --model ''
check "M7 headless --model empty: usage line, exit 2, no call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ] && [ ! -e "$tmp/claude_args" ]'

sed -E '/--allowedTools/d' "$script" > "$tmp/NC6.sh" 2>/dev/null
check "NC6 sed deletes exactly one line" '[ "$(diff "$script" "$tmp/NC6.sh" | grep -c "^<")" = 1 ]'
nc NC6 h1

sed -E '/H\+=\(--machine/d' "$script" > "$tmp/NC1.sh" 2>/dev/null
check "NC1 sed deletes exactly one line" '[ "$(diff "$script" "$tmp/NC1.sh" | grep -c "^<")" = 1 ]'
nc NC1 r1

exit $fail
