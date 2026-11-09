#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/scripts/st-worker.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(cd "$tmp" && pwd -P)
export CLAUDE_CONFIG_DIR="$tmp/cfg" CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1
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
printf '%s\n' "$1 $2" >> "$T/order"
p=; for a in "$@"; do [ "$p" != --cwd ] || [[ $a != \~* ]] || [ "$1 $2" = "worktree list" ] || { printf '{"error":{"code":"stub_tilde","message":"stub --cwd %s"}}\n' "$a" >&2; exit 1; }; p=$a; done
if [ "$1 $2" = "agent start" ] && [ -n "${STUB_BUSY:-}" ]; then
  b=$(cat "$T/n_busy" 2>/dev/null || echo 0); b=$((b+1)); echo $b > "$T/n_busy"
  if [ $b -le "$STUB_BUSY" ]; then printf '{"error":{"code":"agent_pane_busy","message":"stub busy"}}\n' >&2; exit 1; fi
fi
if [ "${STUB_FAIL:-}" = "$1 $2" ] || { [ "${STUB_FAIL_UNTIL:-}" = "$1 $2" ] && [[ " $* " == *" --until "* ]]; }; then
  printf '{"error":{"code":"%s","message":"stub refused"}}\n' "${STUB_FAIL_CODE:-stub}" >&2
  exit 1
fi
upd() { jq -c "${@:2}" "$T/$1" > "$T/$1.new" && mv "$T/$1.new" "$T/$1"; }
if [ -e "$T/closed" ] && [ "${STUB_LIST_JUNK:-}" = "$1 $2" ]; then printf '%s\n' "$STUB_JUNK_BODY"; exit 0; fi
case "$1 $2" in
"worktree list")
  f=.; [ -z "${STUB_NO_MAIN_WS:-}" ] || f='map(if .is_linked_worktree == false then del(.open_workspace_id) else . end)'
  jq -c "{result:{worktrees:($f)}}" "$T/wt.json" ;;
"workspace create")
  c= l=
  while [ $# -gt 0 ]; do case "$1" in --cwd) c=$2 ;; --label) l=$2 ;; esac; shift; done
  w=stubNewWS$RANDOM$RANDOM; t=$w:t1; rp=$w:p1
  upd ws.json --arg w "$w" --arg l "$l" '. + [{workspace_id:$w,label:$l}]'
  upd tabs.json --arg w "$w" --arg t "$t" '. + [{tab_id:$t,label:"1",workspace_id:$w}]'
  upd panes.json --arg w "$w" --arg t "$t" --arg p "$rp" --arg c "$c" '. + [{pane_id:$p,tab_id:$t,workspace_id:$w,cwd:$c}]'
  jq -nc --arg w "$w" --arg t "$t" --arg p "$rp" '{result:{type:"workspace_created",workspace:{workspace_id:$w},tab:{tab_id:$t},root_pane:{pane_id:$p}}}' ;;
"machine list")
  case "${STUB_ML:-}" in fail) exit 1 ;; junk) echo 'not json'; exit 0 ;; esac
  printf '%s\n' '[{"id":"stubid0001","label":"laptop","target":"u@stubhost","session":"default","enabled":true,"selected":false}]' ;;
"workspace list")
  if [ -n "${STUB_DOWN:-}" ] && [ -n "$M" ]; then echo 'Error: stub machine down' >&2; exit 1; fi
  jq -c '{result:{workspaces:.}}' "$T/ws.json" ;;
"workspace close")
  : > "$T/closed"
  upd ws.json --arg w "$3" 'map(select(.workspace_id!=$w))'
  upd tabs.json --arg w "$3" 'map(select(.workspace_id!=$w))'
  upd panes.json --arg w "$3" 'map(select(.workspace_id!=$w))'
  [ -n "${STUB_KEEP_AGENT:-}" ] || upd agents.json --arg w "$3" 'map(select(.workspace_id!=$w))'
  jq -nc --arg w "$3" '{result:{type:"workspace_closed",workspace_id:$w}}' ;;
"agent start")
  n=$3
  while [ $# -gt 0 ]; do
    case "$1" in --pane) pn=$2 ;; esac
    shift
  done
  upd agents.json --arg n "$n" --arg p "$pn" --slurpfile c "$T/tc.json" '. + [{name:$n,pane_id:$p,workspace_id:$c[0].result.tab.workspace_id,agent_status:"working"}]'
  jq -nc --arg n "$n" '{result:{type:"agent_started",agent:{name:$n},argv:[]}}' ;;
"agent get")
  n=$(cat "$T/n_get" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n_get"
  [ -z "${STUB_NO_STATUS:-}" ] || { jq -nc --arg n "$3" '{result:{agent:{name:$n}}}'; exit 0; }
  s=$(sed -n "${n}p" "$T/states"); [ -n "$s" ] || s=$(tail -n1 "$T/states")
  jq -nc --arg s "$s" --arg n "$3" --slurpfile c "$T/tc.json" '{result:{agent:{agent_status:$s,name:$n,pane_id:$c[0].result.root_pane.pane_id,workspace_id:$c[0].result.tab.workspace_id}}}' ;;
"agent list")
  jq -c '{result:{agents:.}}' "$T/agents.json" ;;
"tab create")
  w= c= l=
  while [ $# -gt 0 ]; do case "$1" in --workspace) w=$2 ;; --cwd) c=$2 ;; --label) l=$2 ;; esac; shift; done
  t=$w:t$RANDOM$RANDOM; rp=$w:p$RANDOM$RANDOM
  printf 'tab\t%s\t%s\n' "$t" "$rp" >> "$T/made"
  upd tabs.json --arg w "$w" --arg t "$t" --arg l "$l" '. + [{tab_id:$t,label:$l,workspace_id:$w}]'
  upd panes.json --arg w "$w" --arg t "$t" --arg p "$rp" --arg c "$c" '. + [{pane_id:$p,tab_id:$t,workspace_id:$w,cwd:$c}]'
  jq -nc --arg w "$w" --arg t "$t" --arg l "$l" --arg p "$rp" --arg c "$c" '{result:{type:"tab_created",tab:{tab_id:$t,workspace_id:$w,label:$l},root_pane:{pane_id:$p,cwd:$c}}}' | tee "$T/tc.json" ;;
"tab list")
  w=; while [ $# -gt 0 ]; do case "$1" in --workspace) w=$2 ;; esac; shift; done
  jq -c --arg w "$w" '{result:{tabs:(if $w == "" then . else map(select(.workspace_id == $w)) end)}}' "$T/tabs.json" ;;
"tab close")
  : > "$T/closed"
  ws=$(jq -r --arg t "$3" '.[] | select(.tab_id == $t) | .workspace_id' "$T/tabs.json")
  [ -n "${STUB_KEEP_AGENT:-}" ] || upd agents.json --arg t "$3" --slurpfile pn "$T/panes.json" 'map(select(.pane_id as $p | [$pn[0][] | select(.tab_id == $t) | .pane_id] | index($p) | not))'
  upd panes.json --arg t "$3" 'map(select(.tab_id != $t))'
  upd tabs.json --arg t "$3" 'map(select(.tab_id != $t))'
  [ -z "${STUB_TABCLOSE_WS:-}" ] || [ "$(jq --arg w "$ws" '[.[] | select(.workspace_id == $w)] | length' "$T/tabs.json")" != 0 ] || upd ws.json --arg w "$ws" 'map(select(.workspace_id != $w))'
  jq -nc --arg t "$3" '{result:{type:"tab_closed",tab_id:$t}}' ;;
"pane list")
  w=; while [ $# -gt 0 ]; do case "$1" in --workspace) w=$2 ;; esac; shift; done
  jq -c --arg w "$w" '{result:{panes:map(select(.workspace_id == $w))}}' "$T/panes.json" ;;
"pane split")
  p=stubP$RANDOM$RANDOM
  printf 'pane\t%s\n' "$p" >> "$T/made"
  jq -nc --arg p "$p" '{result:{type:"pane_created",pane:{pane_id:$p}}}' ;;
"agent read")
  if [ "$5" = visible ]; then cat "$T/pane.txt" 2>/dev/null || printf 'STUB PANE %s\n' "$X"
  elif [ -e "$T/pane.txt" ]; then tail -n "$7" "$T/pane.txt"; else printf 'STUB PANE %s\n' "$X"; fi ;;
"agent send-keys")
  [ ! -e "$T/pane.after" ] || [ "${*: -1}" != enter ] || mv "$T/pane.after" "$T/pane.txt"
  echo '{"result":{}}' ;;
"agent wait")
  if [[ " $* " == *" --until "* ]] && [ -e "$T/resume_result" ]; then
    printf 'RESULT FILE %s\n' "$X" > "$(jq -r .result.root_pane.cwd "$T/tc.json")/result.md"
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
printf 'ssh\n' >> "$T/order"
if [ -n "${STUB_SSH_RC:-}" ] && [[ "$*" == *"${STUB_SSH_ON:-}"* ]]; then [ -n "${STUB_SSH_QUIET:-}" ] || echo 'ssh: stub failure' >&2; exit "$STUB_SSH_RC"; fi
while [ $# -gt 0 ] && [ "$1" != -- ]; do shift; done
shift 2
c="$*"
[ -z "${STUB_SSH_EXEC:-}" ] || exec bash -c "$c"
case "$c" in
*"worktree add -q -b "*) set -- $c; while [ "$1" != -b ]; do shift; done; jq -c --arg p "$3" --arg b "$2" '. + [{path:$p,branch:$b}]' "$T/wt.json" > "$T/wt.new" && mv "$T/wt.new" "$T/wt.json" ;;
"cd "*" && pwd") d=${c#cd }; d=${d% && pwd}; printf '%s\n' "${d/#\~//stubhome}" ;;
*"cat > "*) cat > "$T/ssh_in.$n" ;;
"cat -- "*result.md) printf 'RESULT FILE %s\n' "$(cat "$T/x")" ;;
"test -f "*) [ -e "$T/ssh_has_result" ] ;;
esac
EOF
cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env bash
T=$STUB_T
if [ "$1" = fetch ]; then ( IFS=$'\t'; printf 'ENV=%s\t%s\n' "${GIT_SSH_COMMAND:-}" "$*" >> "$T/gitlog" ); exit 0; fi
if [ "$1" = -C ] && [ "$3" = worktree ] && [ "$4" = add ] && [ "$5" = -q ] && [ "$6" = -b ]; then
  ( IFS=$'\t'; printf '%s\n' "$*" >> "$T/gitlog" )
  printf 'worktree add\n' >> "$T/order"
  case ${STUB_GIT_FAIL:-} in add) echo 'fatal: stub git refused' >&2; exit 128 ;; add255) echo 'fatal: stub git refused 255' >&2; exit 255 ;; esac
  p=$8 b=$7
  case "$p" in "$T"/*) ;; *) echo "stub git: path outside the test dir: $p" >&2; exit 97 ;; esac
  [ ! -e "$p" ] || { echo "fatal: '$p' already exists" >&2; exit 128; }
  case "${STUB_WT_LINK:-}" in
    stratum) mkdir -p "$p" && ln -s "$T/outside-dir" "$p/.stratum" ;;
    brief) mkdir -p "$p/.stratum" && ln -s "$T/outside.txt" "$p/brief.md" ;;
    guard) mkdir -p "$p/.stratum" && ln -s "$T/outside.json" "$p/.stratum/git-guard.json" ;;
    result) mkdir -p "$p/.stratum" && ln -s "$T/outside.txt" "$p/result.md" ;;
    resultfile) mkdir -p "$p/.stratum" && printf 'TRACKED RESULT\n' > "$p/result.md" ;;
    brieffile) mkdir -p "$p/.stratum" && printf 'TRACKED BRIEF\n' > "$p/brief.md" ;;
    *) mkdir -p "$p/.stratum" ;;
  esac
  jq -c --arg p "$p" --arg b "$b" '. + [{path:$p,branch:$b}]' "$T/wt.json" > "$T/wt.new" && mv "$T/wt.new" "$T/wt.json"
  exit 0
fi
if [ "$1" = -C ] && [ "$3" = worktree ] && [ "$4" = remove ]; then
  ( IFS=$'\t'; printf '%s\n' "$*" >> "$T/gitlog" )
  [ "${STUB_GIT_FAIL:-}" != remove ] || { echo 'fatal: stub remove refused' >&2; exit 1; }
  case "$5" in "$T"/*) rm -rf "$5" ;; *) echo "stub git: path outside the test dir: $5" >&2; exit 97 ;; esac
  exit 0
fi
if [ "$1" = -C ] && [ "$3" = branch ] && [ "$4" = -D ]; then
  ( IFS=$'\t'; printf '%s\n' "$*" >> "$T/gitlog" )
  exit 0
fi
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
[ "${STUB_CLAUDE:-}" != okfail ] || exit 1
EOF
chmod +x "$tmp/bin/claude"
cat > "$tmp/bin/gh" <<'EOF2'
#!/usr/bin/env bash
( IFS=$'\t'; printf '%s\n' "$*" >> "$STUB_T/gh_calls" )
if [ -n "${STUB_GH_FAIL:-}" ]; then echo 'gh: stub failure' >&2; exit 1; fi
if [ -n "${STUB_PR_OPEN:-}" ]; then echo 1; else echo 0; fi
EOF2
chmod +x "$tmp/bin/gh"
for b in herdr ssh git sleep timeout claude gh; do
  found=$(PATH="$tmp/bin:$PATH" command -v $b)
  if [ "$found" != "$tmp/bin/$b" ]; then echo "FAIL stub $b is first on PATH: found $found"; exit 1; fi
done

repo="$tmp/repo"
mkdir -p "$repo/.stratum"
git -C "$repo" init -q
printf '{}\n' > "$repo/.stratum/state.json"
mkdir -p "$repo/src" "$repo/tests"; : > "$repo/src/keep"; : > "$repo/tests/keep"
git -C "$repo" add .stratum/state.json src/keep tests/keep
printf '.stratum/models.json\n' >> "$repo/.git/info/exclude"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m first
git -C "$repo" remote add origin https://github.com/stub/stub.git
sha=$(git -C "$repo" rev-parse HEAD)

task="$tmp/task.md"
roster="$tmp/roster"
rules="$tmp/rules"
testcmd='bash tests/test_demo.sh'
lane=st-build
printf 'worker-t004\tlocal\tworker-t004\tT004\nworker-t005\tlocal\tworker-t005\tT005\n' > "$roster"
printf '%s\n' \
  '1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md, .stratum/git-guard.json or .stratum/approve/, and never write in .stratum/approve/.' \
  "2. Before you build on a teammate's work, merge its branch: \`git log <branch>\`, \`git merge <branch>\`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work." \
  '3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.' \
  '4. Never merge into the base branch and never push. Merging a teammate'"'"'s branch into your own (rule 2) is fine. When your task says to run /stratum:st-pr, run it: it pushes your branch and opens the PR, and that is the only push allowed. The orchestrator reviews every branch and is the only one who merges into the base.' \
  '5. Commit from the worktree root with `git add <path> <path> && git commit -m '"'"'<subject>'"'"' -m '"'"'<body>'"'"'`. Use no `cd`, no `git -C`, no pipe, no shell variable, no `$(...)`, no heredoc and no `-F` file: the orchestrator approves only this form. Give this rule word for word to the st-git agent.' > "$rules"
P="/goal \`$testcmd\` exits 0, the change is committed on branch worker-t004, and result.md is written; read brief.md in this folder first and follow it"
sargs=(T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$roster")

reset() { : > "$tmp/calls"; : > "$tmp/gh_calls"; }
states() { rm -f "$tmp/n_get"; printf '%s\n' "$@" > "$tmp/states"; }
fresh() {
  rm -rf "$tmp"/repo-worker-* "$tmp"/rrepo-worker-* "$tmp"/n_* "$tmp/closed" "$tmp/resume_result" "$tmp/tc.json" "$tmp/s2" "$tmp/pane.txt" "$tmp/pane.after" "$tmp/made" "$tmp/order"
  printf 'x%s\n' "$RANDOM$RANDOM" > "$tmp/x"
  printf 'TASK BODY %s\nOwns: `src/a.py`.\n' "$(cat "$tmp/x")" > "$task"
  jq -nc '[{workspace_id:"w1P",label:"orchestrator"},{workspace_id:"stubDecoyWS",label:"notaworker"},{workspace_id:"stubMainWS",label:"main"}]' > "$tmp/ws.json"
  jq -nc '[{tab_id:"w1P:t1",label:"orchestrator",workspace_id:"w1P"},{tab_id:"stubDecoyWS:t1",label:"notaworker",workspace_id:"stubDecoyWS"},{tab_id:"stubMainWS:t1",label:"main",workspace_id:"stubMainWS"}]' > "$tmp/tabs.json"
  jq -nc '[{path:"/stub/decoy",branch:"notaworker",open_workspace_id:"stubDecoyWS"},{path:"~/proj",branch:"main",is_linked_worktree:false,open_workspace_id:"stubMainWS"}]' > "$tmp/wt.json"
  echo '[]' > "$tmp/agents.json"
  echo '[]' > "$tmp/panes.json"
  states working
  reset
  : > "$tmp/gitlog"
}
run() {
  out=$(cd "${RUNDIR:-$repo}" && PATH="$tmp/bin:$PATH" HERDR_ENV="${HENV-1}" HERDR_PANE_ID=w1P:p1 HERDR_TAB_ID=w1P:t1 HERDR_WORKSPACE_ID="${HWS-w1P}" env ${NOENV:+-u HERDR_ENV} "$@" 2>&1); rc=$?
}
mk() { fresh; run bash "$script" start "${sargs[@]}"; reset; }
wsid() { jq -r .result.tab.workspace_id "$tmp/tc.json"; }
tabid() { jq -r .result.tab.tab_id "$tmp/tc.json"; }
pane() { jq -r .result.root_pane.pane_id "$tmp/tc.json"; }
wt() { jq -r .result.root_pane.cwd "$tmp/tc.json"; }
rnd() { cat "$tmp/x"; }
cnt() { grep -cP "$1" "$tmp/calls"; }
hasline() { grep -qxF "$(printf "$@")" <<<"$out"; }
hascall() { grep -qxF "$(printf "$@")" "$tmp/calls"; }
shash() { awk -F'\t' '$1=="screen"{print $2; exit}' <<<"$out"; }
ghascall() { grep -qxF -- "$(printf -- "$@")" "$tmp/gitlog"; }
lazypane() { awk -F'\t' '$1=="pane"{print $2; exit}' "$tmp/made" 2>/dev/null; }
addtab() { jq -c --arg t "$1" --arg l "$2" --arg w "$3" '. + [{tab_id:$t,label:$l,workspace_id:$w}]' "$tmp/tabs.json" > "$tmp/tabs.new" && mv "$tmp/tabs.new" "$tmp/tabs.json"; }
never() {
  ! grep -qx BARE "$tmp/calls" && ! grep -qP '(^|\t)w1P:(t1|p1)(\t|$)' "$tmp/calls" &&
  awk -F'\t' '{ for (i = 1; i <= NF; i++) if ($i ~ /w1P/) { ok = ($i ~ /^w1P:[tp][0-9]+$/ && $i != "w1P:t1" && $i != "w1P:p1") || ($i == "w1P" && $(i - 1) == "--workspace" && (($1 == "tab" && $2 == "create") || ($1 == "pane" && $2 == "list"))); if (!ok) bad = 1 } } END { exit bad }' "$tmp/calls" &&
  ! grep -qP '^workspace\tclose\t.*w1P' "$tmp/calls" &&
  ! grep -qP '(^|\t)(--current|--session|--remote|--trust-repository|--group|--machine)(\t|$)' "$tmp/calls" &&
  ! grep -qP '^(pane\tclose|worktree\tremove|server\t|machine\t(reconnect|add|remove|enable|disable)(\t|$))' "$tmp/calls" &&
  [ "$(cnt '^tab\tclose\t')" = "$1" ] && [ "$(cnt '^agent\tprompt\t')" = "$2" ] && [ "$(cnt '^workspace\tclose\t')" = "${3:-0}" ]
}
nopane() { ! grep -q 'STUB PANE' <<<"$out"; }
nb=$'\xc2\xa0'
rule=$(printf '─%.0s' {1..40})
unsentpane() { printf '%s\n' '' "$rule" "❯$nb$P" "$rule" '  [PONYTAIL]' '  ⏵⏵ auto mode on (shift+tab to cycle)'; }
sentpane() { printf '%s\n' "❯$nb$P" '● Working on it.' "$rule" "❯$nb" "$rule" '  ⏵⏵ auto mode on (shift+tab to cycle)'; }
dialogpane() { printf '%s\n' ' ☐ Worker folder' '│ Which folder holds the brief.md?' '❯ 1. Newest brief.md folder (Recommended)' '     I pick the newest one.' '  2. I will type the path' '  3. Type something.' "$rule" '  4. Chat about this' 'Enter to select · ↑/↓ to navigate · Esc to cancel'; }
paneshown() { grep -qxF 'pane text:' <<<"$out" && grep -qxF "STUB PANE $(rnd)" <<<"$out"; }

prej() {
  local ph=$2
  check "$1 exit 1" '[ $rc = 1 ]'
  check "$1 one line, the phrase" '[ "$(printf "%s\n" "$out" | grep -c .)" = 1 ] && [ "$out" = "$ph" ]'
  check "$1 no herdr call" '[ ! -s "$tmp/calls" ]'
}

s1() {
  fresh; run bash "$1" start "${sargs[@]}"
  local b pr sd; b="$(wt)/brief.md"; pr=$(cd "$(dirname "$1")/.." && pwd); sd=$(dirname "$1")
  check "S1 exit 0" '[ $rc = 0 ]'
  check "S1 one git worktree add from the main checkout, base is HEAD" '[ "$(grep -c . "$tmp/gitlog")" = 1 ] && ghascall "-C\t%s\tworktree\tadd\t-q\t-b\tworker-t004\t%s\t%s" "$repo" "$tmp/repo-worker-t004" "$sha"'
  check "S1 one tab create in the orchestrator workspace, one split, lazygit, no rename, no Dev Servers or VM" '[ "$(cnt "^tab\tcreate\t")" = 1 ] && hascall "tab\tcreate\t--workspace\tw1P\t--cwd\t%s\t--label\tworker-t004\t--no-focus" "$tmp/repo-worker-t004" && [ "$(cnt "^pane\tsplit\t")" = 1 ] && hascall "pane\tsplit\t%s\t--direction\tright\t--cwd\t%s\t--no-focus" "$(pane)" "$(wt)" && hascall "pane\trun\t%s\tlazygit" "$(lazypane)" && [ "$(cnt "^tab\trename\t")" = 0 ] && ! grep -qP "Dev Servers|\tVM(\t|\$)" "$tmp/calls"'
  check "S1 brief has the task text" 'grep -qxF "TASK BODY $(rnd)" "$b"'
  check "S1 brief heading, test, lane, branch, machine, result path" 'grep -qxF "# Brief: worker-t004" "$b" && grep -qxF -- "- Test command: \`$testcmd\`" "$b" && grep -qxF -- "- Lane: $lane. If it names a skill, start it with the Skill tool. Run only task T004; skip every other task, ticked or not." "$b" && grep -qxF -- "- Branch: worker-t004" "$b" && grep -qxF -- "- Your machine: local. \`local\` is the orchestrator'"'"'s machine." "$b" && grep -qxF -- "- Result file: $(wt)/result.md" "$b"'
  check "S1 brief holds the whole B1 line" 'grep -qxF -- "- Test lock: if your task is marked [lock], run its test command as \`bash <plugin root>/scripts/st-lock.sh -- <test command>\`, with the plugin root of the Stratum plugin. Never write a wait loop of your own." "$b"'
  check "S1 brief names the plugin root" 'grep -qxF -- "- Plugin root: $pr" "$b"'
  check "S1 brief order: Model, then Plugin root, then Your machine" 'mo=$(grep -n "^- Model: " "$b" | cut -d: -f1) && po=$(grep -n "^- Plugin root: " "$b" | cut -d: -f1) && yo=$(grep -n "^- Your machine: " "$b" | cut -d: -f1) && [ "$mo" -lt "$po" ] && [ "$po" -lt "$yo" ]'
  check "S1 brief has every roster row" 'grep -qxF "| worker-t004 | local | worker-t004 | T004 |" "$b" && grep -qxF "| worker-t005 | local | worker-t005 | T005 |" "$b"'
  check "S1 brief has the five team rules" '[ "$(grep -cxFf "$rules" "$b")" = 5 ]'
  check "S1 brief rule 1 is the whole B2 line" 'grep -qxF -- "1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md, .stratum/git-guard.json or .stratum/approve/, and never write in .stratum/approve/." "$b"'
  check "S1 brief has the advisor block only when st-advisor.sh is next to the script" '[ -f "$b" ] && if [ -f "$sd/st-advisor.sh" ]; then grep -qxF "## Advisor" "$b"; else ! grep -q "^## Advisor" "$b"; fi'
  check "S1 git-guard.json in the worktree is auto with the worker branch" '[ "$(jq -S -c . "$(wt)/.stratum/git-guard.json")" = "$(jq -S -c -n "{commit:\"auto\",branch:\"worker-t004\"}")" ] && [ "$(grep -c . "$(wt)/.stratum/git-guard.json")" = 1 ]'
  check "S1 repo has no git-guard.json and is unchanged" '[ ! -e "$repo/.stratum/git-guard.json" ] && [ -z "$(git -C "$repo" status --porcelain)" ]'
  check "S1 one agent start, args after -- are exactly the permission mode and name" '[ "$(cnt "^agent\tstart\t")" = 1 ] && hascall "agent\tstart\tworker-t004\t--kind\tclaude\t--pane\t%s\t--timeout\t120000\t--\t--permission-mode\tauto\t-n\tworker-t004" "$(pane)"'
  check "S1 one agent prompt with P" 'hascall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P"'
  check "S1 worker line, ids from the stub log" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)"'
  check "S1 state line" 'hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
  check "S1 never-list, one prompt, no close, no pane text" 'never 0 1 && nopane'
}
s1 "$script"

fresh
printf '{"force_push":"deny","branch":"main"}\n' > "$repo/.stratum/git-guard.json"
run bash "$script" start "${sargs[@]}"
check "S1b exit 0" '[ $rc = 0 ]'
check "S1b worker git-guard.json merges the repo file with commit auto and overwrites its branch with the worker branch" '[ "$(jq -S -c . "$(wt)/.stratum/git-guard.json")" = "$(jq -S -c -n "{force_push:\"deny\",commit:\"auto\",branch:\"worker-t004\"}")" ] && [ "$(grep -c . "$(wt)/.stratum/git-guard.json")" = 1 ]'
check "S1b repo git-guard.json is unchanged" '[ "$(cat "$repo/.stratum/git-guard.json")" = "{\"force_push\":\"deny\",\"branch\":\"main\"}" ]'
rm -f "$repo/.stratum/git-guard.json"

fresh
: > "$repo/.stratum/git-guard.json"
run bash "$script" start "${sargs[@]}"
check "S1c exit 0" '[ $rc = 0 ]'
check "S1c empty repo git-guard.json gives a worker guard file of exactly commit auto and the worker branch" '[ "$(jq -S -c . "$(wt)/.stratum/git-guard.json")" = "$(jq -S -c -n "{commit:\"auto\",branch:\"worker-t004\"}")" ]'
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
check "S3 worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)"'
check "S3 state blocked, pane text, the stub pane text" 'hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && paneshown'
check "S3 pane read call, no agent prompt" 'hascall "agent\tread\tworker-t004\t--source\trecent-unwrapped\t--lines\t40" && never 0 0'
reset
run bash "$script" goal T004 --test "$testcmd"
check "S3 goal exit 0" '[ $rc = 0 ]'
check "S3 goal sends exactly one agent prompt with P" 'hascall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P" && never 0 1'

fresh
STUB_GIT_FAIL=add run bash "$script" start "${sargs[@]}"
check "S4 exit 1" '[ $rc = 1 ]'
check "S4 stopped line with the git message" 'grep -q "^stopped: .*stub git refused" <<<"$out"'
check "S4 worker line has - ids" 'hasline "worker\tworker-t004\tlocal\t-\t-\t-\t-"'
check "S4 no tab create, no undo, no agent start, no prompt" '[ "$(cnt "^tab\tcreate\t")" = 0 ] && [ "$(cnt "^agent\tstart\t")" = 0 ] && ! grep -qP "worktree\tremove|branch\t-D" "$tmp/gitlog" && never 0 0'

fresh; mkdir "$tmp/repo-worker-t004"
run bash "$script" start "${sargs[@]}"
check "S4b folder exists: exit 1, the already-exists stop line, worker line with -, no git worktree add, no tab create" '[ $rc = 1 ] && [ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && hasline "stopped: %s already exists" "$tmp/repo-worker-t004" && hasline "worker\tworker-t004\tlocal\t-\t-\t-\t-" && [ ! -s "$tmp/gitlog" ] && [ "$(cnt "^tab\tcreate\t")" = 0 ] && never 0 0'

fresh
STUB_FAIL="agent prompt" STUB_FAIL_CODE=agent_prompt_stalled run bash "$script" start "${sargs[@]}"
check "S5 exit 1" '[ $rc = 1 ]'
check "S5 stopped line" 'grep -q "^stopped: .*stub refused" <<<"$out"'
check "S5 worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)"'
check "S5 one prompt only, nothing closed" 'never 0 1'

fresh; unsentpane > "$tmp/pane.txt"; sentpane > "$tmp/pane.after"
STUB_FAIL="agent prompt" STUB_FAIL_CODE=agent_prompt_stalled run bash "$script" start "${sargs[@]}"
check "S5b stalled prompt in the box: one Enter, no second paste, exit 0, state working" '[ $rc = 0 ] && [ "$(cnt "^agent\tsend-keys\tworker-t004\tenter$")" = 1 ] && never 0 1 && hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
fresh; unsentpane > "$tmp/pane.txt"
STUB_FAIL="agent prompt" STUB_FAIL_CODE=agent_prompt_stalled run bash "$script" start "${sargs[@]}"
check "S5c prompt still in the box after the Enter: exit 7, worker line, state unsent, pane text" '[ $rc = 7 ] && [ "$(cnt "^agent\tsend-keys\tworker-t004\tenter$")" = 1 ] && never 0 1 && hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)" && hasline "state\tunsent\tworker-t004\t%s" "$(pane)" && grep -qxF "pane text:" <<<"$out"'

fresh
addtab "stubDecoyWS:t9" worker-t004 stubDecoyWS
run bash "$script" start "${sargs[@]}"
check "S6 exit 1" '[ $rc = 1 ]'
check "S6 one line, already exists" '[ "$out" = "A worker worker-t004 already exists." ]'
check "S6 only tab list calls, no git worktree add" '[ "$(cnt "^tab\tlist(\t|\$)")" -ge 1 ] && [ "$(cnt "^tab\tlist(\t|\$)")" = "$(grep -c . "$tmp/calls")" ] && [ ! -s "$tmp/gitlog" ] && never 0 0'

fresh
STUB_FAIL="agent prompt" STUB_FAIL_CODE=agent_blocked run bash "$script" start "${sargs[@]}"
check "S7 exit 4" '[ $rc = 4 ]'
check "S7 worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)"'
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
git -C "$repo" worktree add -q "$tmp/repo-feat" -b feat
git -C "$tmp/repo-feat" -c user.name=t -c user.email=t@t commit -q --allow-empty -m feat
featsha=$(git -C "$tmp/repo-feat" rev-parse HEAD)
printf '{"force_push":"deny"}\n' > "$tmp/repo-feat/.stratum/git-guard.json"
repo="$tmp/repo-feat" run bash "$script" start "${sargs[@]}"
check "S10 exit 0" '[ $rc = 0 ]'
check "S10 git worktree add from the main checkout, base is the linked worktree HEAD" '[ "$featsha" != "$sha" ] && [ "$(grep -c . "$tmp/gitlog")" = 1 ] && ghascall "-C\t%s\tworktree\tadd\t-q\t-b\tworker-t004\t%s\t%s" "$repo" "$tmp/repo-worker-t004" "$featsha"'
check "S10 guard file read from the linked worktree" '[ ! -e "$repo/.stratum/git-guard.json" ] && [ "$(jq -S -c . "$(wt)/.stratum/git-guard.json")" = "$(jq -S -c -n "{force_push:\"deny\",commit:\"auto\",branch:\"worker-t004\"}")" ]'
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
check "S11 worker and state lines" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)" && hasline "state\tworking\tworker-t004\t%s" "$(pane)"'

fresh
STUB_FAIL="agent start" STUB_FAIL_CODE=agent_pane_busy run bash "$script" start "${sargs[@]}"
check "S11b exit 1" '[ $rc = 1 ]'
check "S11b exactly 10 agent start calls, 9 sleep 1" '[ "$(cnt "^agent\tstart\t")" = 10 ] && [ "$(cnt "^sleep\t1\$")" = 9 ] && [ "$(grep -P "^(agent\tstart|sleep)\t" "$tmp/calls")" = "$(busylog 9)" ]'
check "S11b stopped line with the stub agent_pane_busy line" 'grep -qxF "stopped: {\"error\":{\"code\":\"agent_pane_busy\",\"message\":\"stub refused\"}}" <<<"$out"'
check "S11b worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)"'
check "S11b no agent prompt, nothing closed" 'never 0 0'

mkdir -p "$tmp/outside-dir"
printf 'OUTSIDE TXT\n' > "$tmp/outside.txt"
printf '{"outside":true}\n' > "$tmp/outside.json"
printf 'KEEP\n' > "$tmp/outside-dir/keep"
snap() { ls -A "$tmp/outside-dir"; cat "$tmp/outside.txt" "$tmp/outside.json" "$tmp/outside-dir/keep"; }
before=$(snap)
for k in brief:brief.md stratum:.stratum guard:.stratum/git-guard.json result:result.md; do
  fresh
  STUB_WT_LINK=${k%%:*} run bash "$script" start "${sargs[@]}"
  check "S12 ${k%%:*} exit 1" '[ $rc = 1 ]'
  check "S12 ${k%%:*} one stopped line naming the symlink" '[ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && hasline "stopped: %s is a symlink" "$(wt)/${k#*:}"'
  check "S12 ${k%%:*} worker line with ids" 'hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)"'
  check "S12 ${k%%:*} no agent start, no prompt" '[ "$(cnt "^agent\tstart\t")" = 0 ] && never 0 0'
  check "S12 ${k%%:*} outside targets unchanged" '[ "$(snap)" = "$before" ]'
done

for k in brieffile:brief.md:BRIEF resultfile:result.md:RESULT; do
  fresh
  STUB_WT_LINK=${k%%:*} run bash "$script" start "${sargs[@]}"
  f=${k#*:}; f=${f%%:*}
  check "S12b ${k%%:*} exit 1" '[ $rc = 1 ]'
  check "S12b ${k%%:*} one stopped line: already exists" '[ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && hasline "stopped: %s already exists" "$(wt)/$f"'
  check "S12b ${k%%:*} no agent start, no prompt" '[ "$(cnt "^agent\tstart\t")" = 0 ] && never 0 0'
  check "S12b ${k%%:*} tracked file unchanged" '[ "$(cat "$(wt)/$f")" = "TRACKED ${k##*:}" ]'
done

s13() {
  fresh; STUB_FAIL="tab create" run bash "$1" start "${sargs[@]}"
  check "S13 exit 1" '[ $rc = 1 ]'
  check "S13 git log in order: worktree add, worktree remove, branch -D" '[ "$(grep -c . "$tmp/gitlog")" = 3 ] && [ "$(sed -n 1p "$tmp/gitlog" | cut -f4)" = add ] && [ "$(sed -n 2p "$tmp/gitlog" | cut -f4)" = remove ] && [ "$(sed -n 3p "$tmp/gitlog" | cut -f4)" = -D ] && ghascall "-C\t%s\tworktree\tremove\t%s" "$repo" "$tmp/repo-worker-t004" && ghascall "-C\t%s\tbranch\t-D\tworker-t004" "$repo"'
  check "S13 folder gone" '[ ! -e "$tmp/repo-worker-t004" ]'
  check "S13 one stopped line with the stub message" '[ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && grep -q "^stopped: .*stub refused" <<<"$out"'
  check "S13 worker line has - in fields 4 to 7" 'hasline "worker\tworker-t004\tlocal\t-\t-\t-\t-"'
  check "S13 no pane split, no agent start" '[ "$(cnt "^pane\tsplit\t")" = 0 ] && [ "$(cnt "^agent\tstart\t")" = 0 ]'
  run bash "$1" start "${sargs[@]}"
  check "S13 a second start with no failure exits 0 (D33)" '[ $rc = 0 ]'
}
s13 "$script"

fresh; STUB_FAIL="tab create" STUB_GIT_FAIL=remove run bash "$script" start "${sargs[@]}"
check "S13b exit 1" '[ $rc = 1 ]'
check "S13b one stopped line: the stub message, then the left path and branch" '[ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && grep -qF "stub refused\"}}; left $tmp/repo-worker-t004 and branch worker-t004" <<<"$out"'
check "S13b worker line keeps the branch and the path" 'hasline "worker\tworker-t004\tlocal\t-\t-\tworker-t004\t%s" "$tmp/repo-worker-t004"'

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
fresh; HWS= run bash "$script" start "${sargs[@]}"
prej P7b "Not inside a herdr pane. Run it from a herdr pane, or name a --machine."

mk; states done
printf 'RESULT FILE %s\n' "$(rnd)" > "$(wt)/result.md"
run bash "$script" wait T004
check "W1 exit 0" '[ $rc = 0 ]'
check "W1 state finished" 'hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
check "W1 finds the worker by tab label, pane list, worktree list" 'hascall "tab\tlist" && hascall "pane\tlist\t--workspace\t%s" "$(wsid)" && hascall "worktree\tlist\t--cwd\t%s" "$(wt)" && [ "$(cnt "^agent\twait\tworker-t004\t--timeout\t")" = 1 ]'
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

mk; states idle; unsentpane > "$tmp/pane.txt"
run bash "$script" wait T004
check "W7 idle with the /goal prompt in the box: exit 7, state unsent, pane text, no key sent" '[ $rc = 7 ] && hasline "state\tunsent\tworker-t004\t%s" "$(pane)" && grep -qxF "pane text:" <<<"$out" && [ "$(cnt "^agent\tsend-keys\t")" = 0 ] && never 0 0'
mk; states done; dialogpane > "$tmp/pane.txt"; printf 'RESULT FILE %s\n' "$(rnd)" > "$(wt)/result.md"
run bash "$script" wait T004
check "W8 done with an open question and a result file: exit 4, state blocked, not finished" '[ $rc = 4 ] && hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && ! grep -q "^state	finished" <<<"$out"'
mk; states idle; sentpane > "$tmp/pane.txt"
STUB_FAIL_UNTIL="agent wait" STUB_FAIL_CODE=timeout run bash "$script" wait T004
check "W9 a sent /goal in the history and an empty box is not unsent: exit 5, state stopped" '[ $rc = 5 ] && hasline "state\tstopped\tworker-t004\t%s" "$(pane)"'
mk; unsentpane > "$tmp/pane.txt"
run bash "$script" goal T004 --test "$testcmd"
check "GO1 goal with the prompt still in the box: exit 1, the resend line, no prompt" '[ $rc = 1 ] && [ "$out" = "The /goal prompt is still in the input box of worker-t004. Run resend." ] && never 0 0'
mk; states idle working; unsentpane > "$tmp/pane.txt"; sentpane > "$tmp/pane.after"
run bash "$script" resend T004
check "RS1 resend: one Enter, no paste, exit 0, state working" '[ $rc = 0 ] && [ "$(cnt "^agent\tsend-keys\tworker-t004\tenter$")" = 1 ] && [ "$(cnt "^pane\tsend-text\t")" = 0 ] && never 0 0 && hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
mk; states idle; sentpane > "$tmp/pane.txt"
run bash "$script" resend T004
check "RS2 resend with an empty box: exit 1, the line, no key sent" '[ $rc = 1 ] && [ "$out" = "No unsent prompt in worker-t004: idle" ] && [ "$(cnt "^agent\tsend-keys\t")" = 0 ]'
mk; states idle; unsentpane > "$tmp/pane.txt"
run bash "$script" resend T004
check "RS3 resend and the prompt stays: exit 7, state unsent" '[ $rc = 7 ] && [ "$(cnt "^agent\tsend-keys\tworker-t004\tenter$")" = 1 ] && hasline "state\tunsent\tworker-t004\t%s" "$(pane)"'

fresh; states idle
STUB_WT_LINK=resultfile run bash "$script" start "${sargs[@]}"
check "W6 start with a pre-existing result.md stops: exit 1, already exists" '[ $rc = 1 ] && [ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && hasline "stopped: %s/result.md already exists" "$(wt)"'
check "W6 no agent start, no wait, no finished state, the file is not read" '[ "$(cnt "^agent\t(start|wait)\t")" = 0 ] && ! grep -q "^state" <<<"$out" && ! grep -q "TRACKED RESULT" <<<"$out" && never 0 0'

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
check "C1b guard file present before close" '[ -e "$(wt)/.stratum/git-guard.json" ]'
run bash "$script" close T004
check "C1b guard file gone after close" '[ ! -e "$(wt)/.stratum/git-guard.json" ]'
check "C1 exit 0" '[ $rc = 0 ]'
check "C1 one tab close on the worker tab, zero workspace close" 'hascall "tab\tclose\t%s" "$(tabid)" && never 1 0'
check "C1 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'
check "C1 one gh call: pr list --head worker-t004 --state open" '[ "$(cat "$tmp/gh_calls")" = "$(printf "pr\tlist\t--head\tworker-t004\t--state\topen\t--json\tnumber\t-q\tlength")" ]'

mk; states working
run bash "$script" close T004
check "C2 exit 1" '[ $rc = 1 ]'
check "C2 the refuse line, no closed line, no workspace close" '[ "$out" = "Worker worker-t004 is working. Close refused." ] && ! grep -q "^closed" <<<"$out" && never 0 0'
check "C2 refused close keeps git-guard.json" '[ -e "$(wt)/.stratum/git-guard.json" ]'

mk; states done
STUB_KEEP_AGENT=1 run bash "$script" close T004
check "C3 exit 1" '[ $rc = 1 ]'
check "C3 close left agent line" 'grep -qxF "close left agent worker-t004" <<<"$out"'
check "C3 one tab close on the worker tab, zero workspace close" 'hascall "tab\tclose\t%s" "$(tabid)" && never 1 0'

fresh
run bash "$script" close T004
check "C4 exit 1" '[ $rc = 1 ]'
check "C4 no worker line, no workspace close" 'grep -qxF "No worker worker-t004 on local." <<<"$out" && never 0 0'

mk; states done
STUB_FAIL="agent get" STUB_FAIL_CODE=agent_not_found run bash "$script" close T004
check "C5 exit 0" '[ $rc = 0 ]'
check "C5 one tab close on the worker tab, zero workspace close" 'hascall "tab\tclose\t%s" "$(tabid)" && never 1 0'
check "C5 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'

mk; states done
STUB_FAIL="agent get" STUB_FAIL_CODE=timeout run bash "$script" close T004
check "C6 exit 1" '[ $rc = 1 ]'
check "C6 the cannot-read refuse line, no closed line, no workspace close" '[ "$out" = "Worker worker-t004: cannot read worker state. Close refused." ] && ! grep -q "^closed" <<<"$out" && never 0 0'

mk; states done
STUB_NO_STATUS=1 run bash "$script" close T004
check "C7 exit 1" '[ $rc = 1 ]'
check "C7 the cannot-read refuse line, no closed line, no workspace close" '[ "$out" = "Worker worker-t004: cannot read worker state. Close refused." ] && ! grep -q "^closed" <<<"$out" && never 0 0'

for k in agent:'{}' agent:'not json' tab:'{}' tab:'not json'; do
  mk; states done
  STUB_LIST_JUNK="${k%%:*} list" STUB_JUNK_BODY="${k#*:}" run bash "$script" close T004
  check "C8 ${k%%:*} list answers ${k#*:} after the close: exit 1" '[ $rc = 1 ]'
  check "C8 ${k%%:*} list answers ${k#*:} after the close: one cannot-read line" '[ "$out" = "close left ${k%%:*} worker-t004: cannot read the list" ]'
  check "C8 ${k%%:*} list answers ${k#*:} after the close: one tab close" 'hascall "tab\tclose\t%s" "$(tabid)" && never 1 0'
done

mk; states done
STUB_PR_OPEN=1 run bash "$script" close T004
check "C9 exit 1" '[ $rc = 1 ]'
check "C9 the open-PR refuse line, no closed line, no workspace close" '[ "$out" = "Worker worker-t004 has an open PR. Close refused." ] && ! grep -q "^closed" <<<"$out" && never 0 0'
check "C9 refused close keeps git-guard.json" '[ -e "$(wt)/.stratum/git-guard.json" ]'

mk; states done
STUB_GH_FAIL=1 run bash "$script" close T004
check "C10 exit 1" '[ $rc = 1 ]'
check "C10 the cannot-read-PRs refuse line, no closed line, no workspace close" '[ "$out" = "Worker worker-t004: cannot read its PRs. Close refused." ] && ! grep -q "^closed" <<<"$out" && never 0 0'

mk; states done
git -C "$repo" remote set-url origin https://gitlab.com/stub/stub.git
STUB_GH_FAIL=1 run bash "$script" close T004
git -C "$repo" remote set-url origin https://github.com/stub/stub.git
check "C11 no GitHub remote: exit 0" '[ $rc = 0 ]'
check "C11 no GitHub remote: closed and folder lines, one tab close" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)" && hascall "tab\tclose\t%s" "$(tabid)" && never 1 0'
check "C11 no GitHub remote: no gh call" '[ ! -s "$tmp/gh_calls" ]'

mk; states done
mkdir "$tmp/guard-target"; echo '{}' > "$tmp/guard-target/git-guard.json"
rm -rf "$(wt)/.stratum"; ln -s "$tmp/guard-target" "$(wt)/.stratum"
run bash "$script" close T004
check "C12 exit 1" '[ $rc = 1 ]'
check "C12 the symlink refuse line, no closed line, no workspace close" '[ "$out" = "Worker worker-t004: .stratum is a symlink. Close refused." ] && ! grep -q "^closed" <<<"$out" && never 0 0'
check "C12 the symlink target keeps git-guard.json" '[ -e "$tmp/guard-target/git-guard.json" ]'

mk; states done
addtab "w1P:t9" worker-t005 w1P
run bash "$script" close T004
check "C13 exit 0" '[ $rc = 0 ]'
check "C13 one tab close, on worker-t004's tab" 'hascall "tab\tclose\t%s" "$(tabid)" && [ "$(cnt "^tab\tclose\t")" = 1 ] && never 1 0'
check "C13 worker-t005 and the orchestrator tab are still in tab list" 'jq -e "any(.[]; .label == \"worker-t005\") and any(.[]; .label == \"orchestrator\")" "$tmp/tabs.json" >/dev/null'

fresh
addtab "w1P:t7" worker-t004 w1P
addtab "stubDecoyWS:t7" worker-t004 stubDecoyWS
run bash "$script" close T004
check "C16 exit 1, the more-than-one line, no tab close" '[ $rc = 1 ] && [ "$out" = "More than one tab is labelled worker-t004." ] && never 0 0'

mk; states done
jq -c 'map(if .workspace_id == "w1P" then .label = "st-workers" else . end)' "$tmp/ws.json" > "$tmp/ws.new" && mv "$tmp/ws.new" "$tmp/ws.json"
run bash "$script" close T004
check "C18 exit 0, one tab close, zero workspace close (a local close never closes a workspace)" '[ $rc = 0 ] && hascall "tab\tclose\t%s" "$(tabid)" && never 1 0'

fresh
x=$(rnd)
jq -nc --arg x "$x" '[{tab_id:("stubA"+$x+":t1"),label:"worker-t004",workspace_id:("stubA"+$x)},{tab_id:("stubB"+$x+":t1"),label:"worker-t005",workspace_id:("stubB"+$x)},{tab_id:("stubC"+$x+":t1"),label:"notaworker",workspace_id:("stubC"+$x)}]' > "$tmp/tabs.json"
jq -nc --arg x "$x" '[{pane_id:("stubA"+$x+":p1"),tab_id:("stubA"+$x+":t1"),workspace_id:("stubA"+$x),cwd:("/stub/a"+$x)},{pane_id:("stubB"+$x+":p1"),tab_id:("stubB"+$x+":t1"),workspace_id:("stubB"+$x),cwd:("/stub/b"+$x)},{pane_id:("stubC"+$x+":p1"),tab_id:("stubC"+$x+":t1"),workspace_id:("stubC"+$x),cwd:("/stub/c"+$x)}]' > "$tmp/panes.json"
jq -nc --arg x "$x" '[{path:("/stub/a"+$x),branch:"worker-t004"},{path:("/stub/b"+$x),branch:"worker-t005"},{path:("/stub/c"+$x),branch:"notaworker"}]' > "$tmp/wt.json"
jq -nc --arg x "$x" '[{name:"worker-t004",pane_id:("stubA"+$x+":p1"),workspace_id:("stubA"+$x),agent_status:"blocked"},{name:"other-agent",pane_id:("stubC"+$x+":p1"),workspace_id:("stubC"+$x),agent_status:"idle"}]' > "$tmp/agents.json"
run bash "$script" list
check "L1 exit 0" '[ $rc = 0 ]'
check "L1 two found lines, states from the stub" '[ "$(grep -cP "^found\t" <<<"$out")" = 2 ] && hasline "found\tworker-t004\tlocal\tstubA%s:t1\tstubA%s:p1\tblocked\t/stub/a%s" "$x" "$x" "$x" && hasline "found\tworker-t005\tlocal\tstubB%s:t1\t-\tgone\t/stub/b%s" "$x" "$x"'
check "L1 the other workspace is absent" '! grep -q notaworker <<<"$out" && ! grep -q "stubC" <<<"$out"'
check "L1 never-list, no prompt, no close" 'never 0 0'
jq '.[0].agent_status = "idle"' "$tmp/agents.json" > "$tmp/a.new" && mv "$tmp/a.new" "$tmp/agents.json"
unsentpane > "$tmp/pane.txt"; run bash "$script" list
check "L2 idle worker with the prompt in the box shows unsent" '[ $rc = 0 ] && hasline "found\tworker-t004\tlocal\tstubA%s:t1\tstubA%s:p1\tunsent\t/stub/a%s" "$x" "$x" "$x"'
dialogpane > "$tmp/pane.txt"; run bash "$script" list
check "L2 idle worker with an open question shows blocked" '[ $rc = 0 ] && hasline "found\tworker-t004\tlocal\tstubA%s:t1\tstubA%s:p1\tblocked\t/stub/a%s" "$x" "$x" "$x"'

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
mk; states done working; dialogpane > "$tmp/pane.txt"
run bash "$script" answer T004 --text "use main"
check "AQ1 open question while done: --text picks Type something, types and sends, in one call" '[ $rc = 0 ] && [ "$(sendlog)" = "$(printf "agent\tget\tworker-t004\nagent\tsend-keys\tworker-t004\t3\npane\tsend-text\t%s\tuse main\nagent\tsend-keys\tworker-t004\tenter\nagent\twait\tworker-t004\t--until\tworking\t--timeout\t5000\nagent\tget\tworker-t004" "$(pane)")" ]'
mk; states done working; dialogpane > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 2
check "AQ2 open question while done: --keys sends the key" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t2"'
mk; states done; dialogpane | grep -v 'Type something' > "$tmp/pane.txt"
run bash "$script" answer T004 --text "use main"
check "AQ3 no Type something option: exit 1, the line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The question has no \"Type something.\" option. Answer with --keys." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states done; { printf '%s\n' ' Do you want to proceed?' '❯ 1. Yes' '  2. No'; echo 'Enter to select · Esc to cancel'; } > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 1
check "AQ4 permission dialog while done is not a question: exit 1, not blocked, nothing sent" '[ $rc = 1 ] && [ "$out" = "not blocked: done" ] && [ "$(cnt "^agent\tsend-keys\t")" = 0 ]'
reviewpane() { printf '%s\n' ' Review your answers' ' ● Which folder holds the brief.md? → Newest brief.md folder' '' 'Ready to submit your answers?' '' '❯ 1. Submit answers' '  2. Cancel'; }
mk; states done working; reviewpane > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 1
check "AQ6 review screen while done: exit 0, key 1 sent once" '[ $rc = 0 ] && [ "$(cnt "^agent\tsend-keys\tworker-t004\t1\$")" = 1 ]'
mk; states done; printf '%s\n' 'Done. Ran the tests.' 'All green.' > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 1
check "AQ7 plain output while done: exit 1, not blocked, nothing sent" '[ $rc = 1 ] && [ "$out" = "not blocked: done" ] && [ "$(cnt "^agent\tsend-keys\t")" = 0 ]'
mk; states done; { printf '%s\n' ' Do you want to proceed?'; reviewpane; } > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 1
check "AQ8 permission line above review screen: exit 1, not blocked, nothing sent" '[ $rc = 1 ] && [ "$out" = "not blocked: done" ] && [ "$(cnt "^agent\tsend-keys\t")" = 0 ]'
mk; states done; printf '%s\n' '$ grep -n Ready spec.md' '42: the "Ready to submit your answers?" screen (with "1. Submit answers / 2. Cancel")' '❯ ' > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 1
check "AQ9 review phrase as plain text while done: exit 1, not blocked, nothing sent" '[ $rc = 1 ] && [ "$out" = "not blocked: done" ] && [ "$(cnt "^agent\tsend-keys\t")" = 0 ]'
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
  [ "$(rcnt 'tab\tclose\t')" = "$1" ] && [ "$(rcnt 'agent\tprompt\t')" = "$2" ] && [ "$(rcnt 'workspace\tclose\t')" = "${3:-0}" ]
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
  rfresh; rrun bash "$1" start "${rsargs[@]}"
  local in="$tmp/ssh_in.3" g; g=$(printf '%q' '{"commit":"auto","branch":"worker-t004"}')
  check "R1 exit 0" '[ $rc = 0 ]'
  check "R1 machine list, every other call starts --machine laptop, never-list, one prompt" 'rnever 0 1'
  check "R1 tab create on the machine in the main checkout workspace, no w1P" 'rcall "tab\tcreate\t--workspace\tstubMainWS\t--cwd\t%s\t--label\tworker-t004\t--no-focus" "/stubhome/proj-worker-t004"'
  check "R1 first ssh resolves ~/proj, the second is the git worktree add, the third writes the brief, all with BatchMode" '[ "$(grep -c . "$tmp/ssh")" = 3 ] && [ "$(sed -n 1p "$tmp/ssh")" = "$(printf -- "-o\tBatchMode=yes\t--\tu@stubhost\tcd ~/proj && pwd")" ] && [ "$(sed -n 2p "$tmp/ssh")" = "$(printf -- "-o\tBatchMode=yes\t--\tu@stubhost\t[ ! -e /stubhome/proj-worker-t004 ] || { echo \"/stubhome/proj-worker-t004 already exists\" >&2; exit 1; }; git -C /stubhome/proj worktree add -q -b worker-t004 /stubhome/proj-worker-t004 %s || exit 1" "$sha")" ] && grep -qP "^-o\tBatchMode=yes\t--\tu@stubhost\t" "$tmp/ssh"'
  check "R1 brief ssh writes brief.md and git-guard.json under /stubhome/proj-worker-t004, no \\~" 'c=$(sed -n 3p "$tmp/ssh"); grep -qF -- "cat > /stubhome/proj-worker-t004/brief.md" <<<"$c" && grep -qF -- "mkdir -p /stubhome/proj-worker-t004/.stratum" <<<"$c" && grep -qF -- "> /stubhome/proj-worker-t004/.stratum/git-guard.json" <<<"$c" && grep -qF -- "$g" <<<"$c" && ! grep -qF -- "\\~" "$tmp/ssh"'
  check "R1 brief on ssh stdin: heading, task, machine, result path" 'grep -qxF "# Brief: worker-t004" "$in" && grep -qxF "TASK BODY $(rnd)" "$in" && grep -qxF -- "- Your machine: laptop. \`local\` is the orchestrator'"'"'s machine." "$in" && grep -qxF -- "- Result file: /stubhome/proj-worker-t004/result.md" "$in"'
  check "R1 brief on ssh stdin: roster rows and the five rules" 'grep -qxF "| worker-t004 | laptop | worker-t004 | T004 |" "$in" && grep -qxF "| worker-t005 | local | worker-t005 | T005 |" "$in" && [ "$(grep -cxFf "$rules" "$in")" = 5 ]'
  check "R1 brief on ssh stdin: no Plugin root line, no Advisor block" '[ -s "$in" ] && ! grep -q "^- Plugin root:" "$in" && ! grep -q "^## Advisor" "$in"'
  check "R1 agent start argv" 'rcall "agent\tstart\tworker-t004\t--kind\tclaude\t--pane\t%s\t--timeout\t120000\t--\t--permission-mode\tauto\t-n\tworker-t004" "$(pane)"'
  check "R1 agent prompt with P" 'rcall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$P"'
  check "R1 worker line names laptop, ids from the stub log" 'hasline "worker\tworker-t004\tlaptop\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)"'
}
r1 "$script"

rfresh; mkdir -p "$tmp/r1d"; cp "$script" "$tmp/r1d/st-worker.sh"; : > "$tmp/r1d/st-advisor.sh"
rrun bash "$tmp/r1d/st-worker.sh" start "${rsargs[@]}"
check "R1d st-advisor.sh next to the script, saved machine: exit 0, brief has no Plugin root line, no Advisor block" '[ $rc = 0 ] && [ -s "$tmp/ssh_in.3" ] && ! grep -q "^- Plugin root:" "$tmp/ssh_in.3" && ! grep -q "^## Advisor" "$tmp/ssh_in.3"'
rm -rf "$tmp/r1d"

rfresh; rrun bash "$script" start "${rsargs[@]}"
check "R1b exit 0" '[ $rc = 0 ]'
check "R1b ssh writes brief.md under /stubhome/proj-worker-t004, no \\~" 'sshs | grep -qF -- "cat > /stubhome/proj-worker-t004/brief.md" && ! grep -qF -- "\\~" "$tmp/ssh"'

rfresh; STUB_SSH_RC=255 rrun bash "$script" start "${rsargs[@]}"
check "R1c ssh down on start: exit 1, one stopped line, one worker line" '[ $rc = 1 ] && [ "$(grep -c "^stopped: ssh to u@stubhost failed" <<<"$out")" = 1 ] && [ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && [ "$(grep -cP "^worker\t" <<<"$out")" = 1 ]'

rmk
git -C "$repo" branch -q worker-t004
bsha=$(git -C "$repo" rev-parse worker-t004)
rrun bash "$script" result T004 --machine laptop
check "R2 exit 0" '[ $rc = 0 ]'
check "R2 one ssh cat of the quoted result path" '[ "$(grep -c . "$tmp/ssh")" = 1 ] && grep -qP "^-o\tBatchMode=yes\t--\tu@stubhost\t" "$tmp/ssh" && sshs | grep -qF -- "cat -- /stubhome/proj-worker-t004/result.md"'
check "R2 result line and the file text" 'hasline "result\tworker-t004\t/stubhome/proj-worker-t004/result.md" && grep -qxF "RESULT FILE $(rnd)" <<<"$out"'
check "R2 one git fetch of target:WT worker-t004:worker-t004 with GIT_SSH_COMMAND BatchMode" '[ "$(grep -c . "$tmp/gitlog")" = 1 ] && grep -qxF "$(printf "ENV=ssh -o BatchMode=yes\tfetch\t--\tu@stubhost:/stubhome/proj-worker-t004\tworker-t004:worker-t004")" "$tmp/gitlog"'
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
check "R3 the result check is one ssh test -f" '[ "$(grep -c . "$tmp/ssh")" = 1 ] && grep -qP "^-o\tBatchMode=yes\t--\tu@stubhost\t" "$tmp/ssh" && sshs | grep -qF -- "test -f /stubhome/proj-worker-t004/result.md"'
check "R3 never-list" 'rnever 0 0'
rmk; states done
STUB_FAIL_UNTIL="agent wait" STUB_FAIL_CODE=timeout rrun bash "$script" wait T004 --machine laptop
check "R3b no result file on the machine: exit 5, state stopped" '[ $rc = 5 ] && hasline "state\tstopped\tworker-t004\t%s" "$(pane)" && sshs | grep -qF -- "test -f /stubhome/proj-worker-t004/result.md"'

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

r9() {
  rfresh; rrun bash "$1" start "${rsargs[@]}"; reset; : > "$tmp/ssh"; rm -f "$tmp"/ssh_in.* "$tmp/n_ssh"
  states done
  rrun bash "$1" close T004 --machine laptop
  check "R9 exit 0" '[ $rc = 0 ]'
  check "R9 one tab close on the worker tab, zero workspace close, the main checkout tab stays, --machine rule" 'rcall "tab\tclose\t%s" "$(tabid)" && rnever 1 0 && jq -e "any(.[]; .tab_id == \"stubMainWS:t1\")" "$tmp/tabs.json" >/dev/null'
  check "R9 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'
  check "R9b ssh rm -f of the quoted git-guard.json path" 'sshs | grep -qF -- "rm -f $(wt)/.stratum/git-guard.json"'
  check "R9c ssh tests .stratum is not a symlink before the rm" 'c=$(sshs); t=${c%%rm -f *}; [ "$t" != "$c" ] && [[ $t == *"[ ! -L $(wt)/.stratum ]"* ]]'
}
r9 "$script"

rfresh; STUB_NO_MAIN_WS=1 rrun bash "$script" start "${rsargs[@]}"
reset; states done
STUB_NO_MAIN_WS=1 rrun bash "$script" close T004 --machine laptop
check "C14 exit 0" '[ $rc = 0 ]'
check "C14 one tab close, then one workspace close of the st-workers workspace, no --group" 'rcall "tab\tclose\t%s" "$(tabid)" && rcall "workspace\tclose\t%s" "$(wsid)" && rnever 1 0 1'
check "C14 closed and folder lines" 'hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'

rfresh; STUB_NO_MAIN_WS=1 rrun bash "$script" start "${rsargs[@]}"
jq -c 'map(select(.label != "1"))' "$tmp/tabs.json" > "$tmp/tabs.new" && mv "$tmp/tabs.new" "$tmp/tabs.json"
reset; states done
STUB_NO_MAIN_WS=1 STUB_TABCLOSE_WS=1 rrun bash "$script" close T004 --machine laptop
check "C15 exit 0, one tab close, zero workspace close, closed and folder lines" '[ $rc = 0 ] && rcall "tab\tclose\t%s" "$(tabid)" && rnever 1 0 && hasline "closed\tworker-t004" && hasline "folder\t%s\tready to remove" "$(wt)"'

rfresh; STUB_NO_MAIN_WS=1 rrun bash "$script" start T005 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop --repo '~/proj'
STUB_NO_MAIN_WS=1 rrun bash "$script" start "${rsargs[@]}"
reset; states done
STUB_NO_MAIN_WS=1 rrun bash "$script" close T004 --machine laptop
check "C17 exit 0, one tab close on worker-t004's tab, zero workspace close" '[ $rc = 0 ] && rcall "tab\tclose\t%s" "$(tabid)" && rnever 1 0'
check "C17 worker-t005 still in tab list" 'jq -e "any(.[]; .label == \"worker-t005\")" "$tmp/tabs.json" >/dev/null'

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
jq -nc --arg x "$x" '[{tab_id:("stubA"+$x+":t1"),label:"worker-t004",workspace_id:("stubA"+$x)},{tab_id:("stubB"+$x+":t1"),label:"worker-t005",workspace_id:("stubB"+$x)},{tab_id:("stubC"+$x+":t1"),label:"notaworker",workspace_id:("stubC"+$x)}]' > "$tmp/tabs.json"
jq -nc --arg x "$x" '[{pane_id:("stubA"+$x+":p1"),tab_id:("stubA"+$x+":t1"),workspace_id:("stubA"+$x),cwd:("/stub/a"+$x)},{pane_id:("stubB"+$x+":p1"),tab_id:("stubB"+$x+":t1"),workspace_id:("stubB"+$x),cwd:("/stub/b"+$x)},{pane_id:("stubC"+$x+":p1"),tab_id:("stubC"+$x+":t1"),workspace_id:("stubC"+$x),cwd:("/stub/c"+$x)}]' > "$tmp/panes.json"
jq -nc --arg x "$x" '[{path:("/stub/a"+$x),branch:"worker-t004"},{path:("/stub/b"+$x),branch:"worker-t005"},{path:("/stub/c"+$x),branch:"notaworker"}]' > "$tmp/wt.json"
jq -nc --arg x "$x" '[{name:"worker-t004",pane_id:("stubA"+$x+":p1"),workspace_id:("stubA"+$x),agent_status:"blocked"}]' > "$tmp/agents.json"
rrun bash "$script" list --machine laptop
check "R12 exit 0" '[ $rc = 0 ]'
check "R12 found lines name laptop, the other tab is absent" '[ "$(grep -cP "^found\t" <<<"$out")" = 2 ] && hasline "found\tworker-t004\tlaptop\tstubA%s:t1\tstubA%s:p1\tblocked\t/stub/a%s" "$x" "$x" "$x" && hasline "found\tworker-t005\tlaptop\tstubB%s:t1\t-\tgone\t/stub/b%s" "$x" "$x" && ! grep -q notaworker <<<"$out"'
check "R12 --machine rule, never-list" 'rnever 0 0'

rfresh; rrun bash "$script" start "${rsargs[@]}"
c=$(sshs | sed -n 3p); pre=${c%%cat > *}
check "R13 exit 0, three ssh calls" '[ $rc = 0 ] && [ "$(grep -c . "$tmp/ssh")" = 3 ]'
check "R13 ssh refuses a .stratum symlink, then a link or any existing brief.md, result.md, git-guard.json, before the cat > write" '[ "$pre" != "$c" ] && [ "${pre#*u@stubhost }" = "[ ! -L /stubhome/proj-worker-t004/.stratum ] || { echo \"/stubhome/proj-worker-t004/.stratum is a symlink\" >&2; exit 3; }; for p in /stubhome/proj-worker-t004/brief.md /stubhome/proj-worker-t004/result.md /stubhome/proj-worker-t004/.stratum/git-guard.json; do [ ! -L \"\$p\" ] || { echo \"\$p is a symlink\" >&2; exit 3; }; [ ! -e \"\$p\" ] || { echo \"\$p already exists\" >&2; exit 3; }; done && " ]'

rfresh; rrun bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop --repo "$tmp/rrepo"
check "R14 exit 0, ssh writes brief.md under the sibling of --repo" '[ $rc = 0 ] && sshs | grep -qF -- "cat > $tmp/rrepo-worker-t004/brief.md"'
check "R14 nothing written on this machine: the sibling folder does not exist" '[ ! -e "$tmp/rrepo-worker-t004" ]'

rfresh; STUB_NO_MAIN_WS=1 rrun bash "$script" start "${rsargs[@]}"
check "R15 exit 0" '[ $rc = 0 ]'
check "R15 one workspace create --cwd /stubhome/proj --label st-workers --no-focus, on the machine" 'rcall "workspace\tcreate\t--cwd\t%s\t--label\tst-workers\t--no-focus" "/stubhome/proj" && [ "$(rcnt "workspace\tcreate\t")" = 1 ]'
check "R15 tab create in the workspace the create answered, --machine rule" 'rcall "tab\tcreate\t--workspace\t%s\t--cwd\t%s\t--label\tworker-t004\t--no-focus" "$(wsid)" "/stubhome/proj-worker-t004" && rnever 0 1'

rfresh; x=$(rnd); jq -c --arg x "$x" '. + [{workspace_id:("stubSW"+$x),label:"st-workers"}]' "$tmp/ws.json" > "$tmp/ws.new" && mv "$tmp/ws.new" "$tmp/ws.json"
STUB_NO_MAIN_WS=1 rrun bash "$script" start "${rsargs[@]}"
check "R15b exit 0, no workspace create, tab create in the st-workers workspace that exists" '[ $rc = 0 ] && [ "$(rcnt "workspace\tcreate\t")" = 0 ] && rcall "tab\tcreate\t--workspace\tstubSW%s\t--cwd\t%s\t--label\tworker-t004\t--no-focus" "$x" "/stubhome/proj-worker-t004" && rnever 0 1'

rfresh; STUB_NO_MAIN_WS=1 rrun bash "$script" start "${rsargs[@]}"
check "R17 --repo ~/proj on a saved machine: exit 0, workspace create, tab create and pane split get absolute --cwd values, no herdr call has a --cwd starting with ~" '[ $rc = 0 ] && rcall "workspace\tcreate\t--cwd\t%s\t--label\tst-workers\t--no-focus" "/stubhome/proj" && rcall "tab\tcreate\t--workspace\t%s\t--cwd\t%s\t--label\tworker-t004\t--no-focus" "$(wsid)" "/stubhome/proj-worker-t004" && rcall "pane\tsplit\t%s\t--direction\tright\t--cwd\t%s\t--no-focus" "$(pane)" "/stubhome/proj-worker-t004" && ! grep -qP "\t--cwd\t[^/]" "$tmp/calls"'

rfresh; STUB_FAIL="tab create" rrun bash "$script" start "${rsargs[@]}"
check "R16 exit 1, stopped line with the stub message" '[ $rc = 1 ] && grep -q "^stopped: .*stub refused" <<<"$out"'
check "R16 third ssh is the git undo, no brief write" '[ "$(grep -c . "$tmp/ssh")" = 3 ] && [ "$(sed -n 3p "$tmp/ssh")" = "$(printf -- "-o\tBatchMode=yes\t--\tu@stubhost\tgit -C /stubhome/proj worktree remove /stubhome/proj-worker-t004 && git -C /stubhome/proj branch -D worker-t004 >/dev/null")" ] && ! grep -q "cat > " "$tmp/ssh" && rnever 0 0'

for k in "3::ssh: stub failure" "3:1:exit 3"; do
  rfresh; STUB_SSH_ON="cat >" STUB_SSH_RC=${k%%:*} STUB_SSH_QUIET=$(cut -d: -f2 <<<"$k") rrun bash "$script" start "${rsargs[@]}"
  check "R13b remote write fails (${k#*:*:}): exit 1, one stopped line with WT, machine and the reason" '[ $rc = 1 ] && [ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && hasline "stopped: cannot write brief.md and .stratum/git-guard.json in /stubhome/proj-worker-t004 on laptop: %s" "${k#*:*:}" && [ "$(cnt "^--machine\tlaptop\tagent\tstart\t")" = 0 ]'
done

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

fresh
STUB_CLAUDE=okfail run bash "$script" headless T004 --task "$task" --test "$testcmd"
check "H11 success JSON but exit 1: exit 1, claude exited line, no headless line" '[ $rc = 1 ] && hasline "claude exited 1" && ! grep -q "^headless" <<<"$out"'

for k in tracked untracked; do
  fresh; rm -f "$tmp/claude_args"
  if [ $k = tracked ]; then printf '{"dirty":1}\n' > "$repo/.stratum/state.json"; else : > "$repo/stray.txt"; fi
  run bash "$script" headless T004 --task "$task" --test "$testcmd"
  check "H12 $k change: exit 1, one line, no claude call" '[ $rc = 1 ] && [ "$out" = "Working tree is not clean." ] && [ ! -e "$tmp/claude_args" ]'
  printf '{}\n' > "$repo/.stratum/state.json"; rm -f "$repo/stray.txt"
done
check "H12 repo tree is clean again" '[ -z "$(git -C "$repo" status --porcelain)" ]'

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

m7() {
  k=$1; fresh; rm -f "$tmp/claude_args"
  [ $k = start ] && a=(start "${sargs[@]}") || a=(headless T004 --task "$task" --test "$testcmd")
  run bash "$script" "${a[@]}" "${@:3}"
  check "M7 $k --model $2: usage line, exit 2, no call" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == usage:* ]] && [ ! -s "$tmp/calls" ] && { [ $k = start ] || [ ! -e "$tmp/claude_args" ]; }'
}
m7 start 'without a value' --model
m7 start twice --model opus --model sonnet
m7 headless 'without a value' --model
m7 headless twice --model opus --model sonnet
m7 start empty --model ''
m7 headless empty --model ''

sed -E '/--allowedTools/d' "$script" > "$tmp/NC6.sh" 2>/dev/null
check "NC6 sed deletes exactly one line" '[ "$(diff "$script" "$tmp/NC6.sh" | grep -c "^<")" = 1 ]'
nc NC6 h1

sed -E '/H\+=\(--machine/d' "$script" > "$tmp/NC1.sh" 2>/dev/null
check "NC1 sed deletes exactly one line" '[ "$(diff "$script" "$tmp/NC1.sh" | grep -c "^<")" = 1 ]'
nc NC1 r1

sed -E '/h tab close "\$TAB"/a h workspace close "$WS"' "$script" > "$tmp/NC8.sh" 2>/dev/null
nc NC8 r9

sed -E 's/ worktree remove / worktree noop /; s/ branch -D / branch noop /' "$script" > "$tmp/NC9.sh" 2>/dev/null
nc NC9 s13

rrepo="$tmp/rrepo"
rw="$tmp/rrepo-worker-t004"
rxargs=(T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop --repo "$rrepo")
lw="$tmp/repo-worker-t004"
sid=sess$RANDOM$RANDOM
rid=1700000000000000001-4242
rec="$tmp/rec"
exp='Bash: {"command":"echo $(touch pwned)","description":"d \u00e9"}'
exp2='Bash: {"command":"echo $(touch pwned) `touch pwned`"}'
aroster="$tmp/aroster"
aoroster="$tmp/aoff"
oargs=(T004 --task "$tmp/task-owns.md" --test "$testcmd" --lane "$lane" --roster "$roster" --autonomous)
printf 'TASK BODY\nOwns: `src/a.py`, `tests/t.sh`.\n' > "$tmp/task-owns.md"
printf 'TASK BODY\n' > "$tmp/task-none.md"
autoset() { mkdir -p "$repo/.stratum/autonomous"; : > "$repo/.stratum/autonomous/$1"; }
autoclr() { rm -rf "$repo/.stratum/autonomous"; }
rautoset() { mkdir -p "$1/.stratum/autonomous"; : > "$1/.stratum/autonomous/$2"; }
apd() { mkdir -p "$lw/.stratum/approve"; }
mkreq() { apd; jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c},time:"2026-10-31T00:00:00Z"}' > "$lw/.stratum/approve/$1.req"; }
apx() { mk; apd; printf '%s\n' "$sid" > "$lw/.stratum/approve/session"; autoset "$sid"; rm -f "$rec" "$repo/pwned" "$tmp/pwned"; }
ih() { sha256sum <<<"$1" | cut -c1-64; }
apv() { CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$(ih "$(cat)")" --record "$rec" "$@"; }
recok() { [ "$(grep -c . "$rec")" = 1 ] && awk -F'\t' -v t="$1" 'NF==5 && $2=="worker-t004" && $3=="tab worker-t004" && $4=="Bash" && index($5,t){f=1} END{exit !f}' "$rec"; }
xsetup() { rm -rf "$rrepo" "$rw" "$tmp/rlink" "$tmp/rtarget"; mkdir -p "$rrepo/.stratum"; }
ax() { rfresh; xsetup; printf 'worker-t004\tlaptop\tworker-t004\tT004\t%s\nworker-t005\tlocal\tworker-t005\tT005\n' "$rrepo" > "$aroster"; }
axrun() { STUB_SSH_EXEC=1 CLAUDE_CODE_SESSION_ID="$sid" rrun bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$aroster" --machine laptop --repo "$rrepo" --autonomous; }
wtchk() { check "$1" '[ $rc = 1 ] && [ "$out" = "Run this from the orchestrator'"'"'s checkout, not a worker worktree." ] && [ ! -s "$tmp/calls" ]'; }

fresh; autoclr
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start "${sargs[@]}" --autonomous
check "B1 no flag file: exit 1, the off line, no herdr call" '[ $rc = 1 ] && [ "$out" = "Autonomous build mode is off for this session." ] && [ ! -s "$tmp/calls" ]'
fresh; autoset other-session
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start "${sargs[@]}" --autonomous
check "B2 the flag holds another id: exit 1, the off line, no herdr call" '[ $rc = 1 ] && [ "$out" = "Autonomous build mode is off for this session." ] && [ ! -s "$tmp/calls" ]'
fresh; autoset "$sid"
CLAUDE_CODE_SESSION_ID= run bash "$script" start "${sargs[@]}" --autonomous
check "B3 empty session id: exit 1, the off line, no herdr call" '[ $rc = 1 ] && [ "$out" = "Autonomous build mode is off for this session." ] && [ ! -s "$tmp/calls" ]'
fresh; autoset "$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start "${oargs[@]}"
check "B4 flag matches: exit 0" '[ $rc = 0 ]'
check "B4 approve folder, session holds the session id" '[ -d "$lw/.stratum/approve" ] && [ "$(cat "$lw/.stratum/approve/session")" = "$sid" ]'
check "B4 owns holds the backticked Owns paths, one per line" '[ "$(cat "$lw/.stratum/approve/owns")" = "$(printf "src/a.py\ntests/t.sh")" ]'
fresh; autoset "$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start T004 --task "$tmp/task-none.md" --test "$testcmd" --lane "$lane" --roster "$roster" --autonomous
check "B5 no Owns line: exit 1, the line, no herdr call" '[ $rc = 1 ] && [ "$out" = "The task has no Owns: paths. Autonomous mode needs them." ] && [ ! -s "$tmp/calls" ]'
for bad in 'src/*.py' 'src/a?.py' 'src/[ab].py' '/abs/a.py' '~/a.py' './src/a.py' 'src/../a.py' '../a.py'; do
  printf 'TASK BODY\nOwns: `%s`.\n' "$bad" > "$tmp/task-bad.md"
  fresh; autoset "$sid"
  CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start T004 --task "$tmp/task-bad.md" --test "$testcmd" --lane "$lane" --roster "$roster" --autonomous
  check "B7 Owns $bad: exit 1, the line, no herdr call" '[ $rc = 1 ] && [ "$out" = "Owns path $bad must be repo-relative, with no glob." ] && [ ! -s "$tmp/calls" ]'
done
printf 'TASK BODY\nOwns: `apps/crm/a.ts`.\n' > "$tmp/task-bad.md"
fresh; autoset "$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start T004 --task "$tmp/task-bad.md" --test "$testcmd" --lane "$lane" --roster "$roster" --autonomous
check "B8 Owns folder not in the base commit: exit 1, the line, no herdr call" '[ $rc = 1 ] && [ "$out" = "Owns path apps/crm/a.ts: folder apps/crm is not in the base commit." ] && [ ! -s "$tmp/calls" ]'
fresh; CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start T004 --task "$tmp/task-bad.md" --test "$testcmd" --lane "$lane" --roster "$roster"
check "B8 without --autonomous the Owns list is not checked: exit 0" '[ $rc = 0 ]'
printf 'TASK BODY\nOwns: `a.sh`,\n  `b.sh`. Test: x\n' > "$tmp/task-wrap.md"
fresh; autoset "$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start T004 --task "$tmp/task-wrap.md" --test "$testcmd" --lane "$lane" --roster "$roster" --autonomous
check "B6 Owns list wraps onto the next line: exit 0, owns holds both paths" '[ $rc = 0 ] && [ "$(cat "$lw/.stratum/approve/owns")" = "$(printf "a.sh\nb.sh")" ]'
autoclr

wk="$tmp/wk"; rm -rf "$wk"; mkdir -p "$wk/.stratum/approve"; git -C "$wk" init -q; git -C "$wk" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first; mkdir -p "$wk/.stratum/autonomous"; : > "$wk/.stratum/autonomous/$sid"
git -C "$repo" worktree add -q "$tmp/repo-w9" -b worker-t9
autoset "$sid"
for d in "$wk" "$tmp/repo-w9"; do
  fresh; RUNDIR="$d" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start "${oargs[@]}"
  wtchk "WT1 start from $d: exit 1, one line, no call"
  fresh; RUNDIR="$d" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$(ih 'Bash: {"command":"echo hi"}')" --record "$rec"
  wtchk "WT2 approve from $d: exit 1, one line, no call"
  fresh; RUNDIR="$d" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" pass T004 --request "$rid"
  wtchk "WT3 pass from $d: exit 1, one line, no call"
  fresh; RUNDIR="$d" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off --roster "$roster"
  wtchk "WT4 autonomous-off from $d: exit 1, one line, no call"
  fresh; RUNDIR="$d" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
  wtchk "WT5 autonomous-on from $d: exit 1, one line, no call"
done
git -C "$repo" worktree remove --force "$tmp/repo-w9"
git -C "$repo" branch -q -D worker-t9
autoclr

bgrun() { ( cd "$repo" && PATH="$tmp/bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1P:p1 HERDR_TAB_ID=w1P:t1 HERDR_WORKSPACE_ID=w1P CLAUDE_CODE_SESSION_ID="$1" bash "$script" "$2" >/dev/null 2>&1; echo $? > "$tmp/bg.$1" ); }
onbad="cannot turn on autonomous mode: session id must be letters, digits or -"
fresh; CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON1 autonomous-on from the main checkout: exit 0, the on line, no herdr call" '[ $rc = 0 ] && [ "$out" = "$(printf "autonomous on\tlocal")" ] && [ ! -s "$tmp/calls" ]'
check "ON1 the entry is an empty regular file in a real folder" '[ -d "$repo/.stratum/autonomous" ] && [ ! -L "$repo/.stratum/autonomous" ] && [ -f "$repo/.stratum/autonomous/$sid" ] && [ ! -s "$repo/.stratum/autonomous/$sid" ]'
autoclr; autoset other-session
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON3 another session's entry is kept: exit 0, both entries" '[ $rc = 0 ] && [ -f "$repo/.stratum/autonomous/other-session" ] && [ -f "$repo/.stratum/autonomous/$sid" ]'
autoclr; printf 'old\n' > "$repo/.stratum/autonomous"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON4 an old single file is replaced by the folder with the entry: exit 0" '[ $rc = 0 ] && [ -d "$repo/.stratum/autonomous" ] && [ ! -L "$repo/.stratum/autonomous" ] && [ -f "$repo/.stratum/autonomous/$sid" ]'
for bad in '' '../x'; do
  autoclr; rm -f "$repo/.stratum/x"
  CLAUDE_CODE_SESSION_ID="$bad" run bash "$script" autonomous-on
  check "ON5 id '$bad': exit 1, the id line, nothing made" '[ $rc = 1 ] && [ "$out" = "$onbad" ] && [ ! -e "$repo/.stratum/x" ] && [ ! -e "$repo/.stratum/autonomous" ]'
done
autoclr; rm -rf "$tmp/olink"; mkdir "$tmp/olink"; ln -s "$tmp/olink" "$repo/.stratum/autonomous"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON6 symlinked folder: exit 1, the symlink line, target unchanged" '[ $rc = 1 ] && [[ "$out" == "cannot turn on autonomous mode: "*" is a symlink" ]] && [ -z "$(ls -A "$tmp/olink")" ]'
autoclr; mkdir -p "$repo/.stratum/autonomous"; printf 'keep\n' > "$tmp/otarget"; ln -s "$tmp/otarget" "$repo/.stratum/autonomous/$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON6 symlinked entry: exit 1, the symlink line, target unchanged" '[ $rc = 1 ] && [[ "$out" == "cannot turn on autonomous mode: "*" is a symlink" ]] && [ "$(cat "$tmp/otarget")" = keep ]'
autoclr
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on extra
check "ON7 an argument: usage line, exit 2, nothing made" '[ $rc = 2 ] && grep -q "^usage: st-worker.sh" <<<"$out" && [ ! -e "$repo/.stratum/autonomous" ]'
mkdir -p "$tmp/nogit"
RUNDIR="$tmp/nogit" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON9 outside a git repo: exit 1, the not-in-a-repo line" '[ $rc = 1 ] && [ "$out" = "cannot turn on autonomous mode: not in a git repo" ] && [ ! -e "$tmp/nogit/.stratum" ]'
autoclr; mkdir -p "$repo/.stratum/autonomous"; printf 'keep\n' > "$repo/.stratum/autonomous/$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON10 an existing entry: exit 0, the on line, the entry is not truncated" '[ $rc = 0 ] && [ "$out" = "$(printf "autonomous on\tlocal")" ] && [ "$(cat "$repo/.stratum/autonomous/$sid")" = keep ]'
for n in 1 2 3; do
  autoclr; printf 'old\n' > "$repo/.stratum/autonomous"; rm -f "$tmp"/bg.*
  bgrun sA autonomous-on & bgrun sB autonomous-on & wait
  check "ON8 run $n: two sessions turn on at once over an old file: both exit 0, both entries exist" '[ "$(cat "$tmp/bg.sA")" = 0 ] && [ "$(cat "$tmp/bg.sB")" = 0 ] && [ -f "$repo/.stratum/autonomous/sA" ] && [ -f "$repo/.stratum/autonomous/sB" ]'
done
autoclr

git -C "$repo" worktree add -q "$tmp/repo-feat2" -b feat2
sid2=sessB$RANDOM$RANDOM
mkdir -p "$tmp/repo-feat2/.stratum/autonomous"; : > "$tmp/repo-feat2/.stratum/autonomous/other-session"
autoclr
fresh; RUNDIR="$tmp/repo-feat2" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-on
check "ON2 autonomous-on from the linked worktree: exit 0, the on line, the entry is in the main checkout" '[ $rc = 0 ] && [ "$out" = "$(printf "autonomous on\tlocal")" ] && [ -f "$repo/.stratum/autonomous/$sid" ] && [ ! -s "$repo/.stratum/autonomous/$sid" ]'
check "ON2 nothing is made in the worktree for this id, its own folder is left alone" '[ ! -e "$tmp/repo-feat2/.stratum/autonomous/$sid" ] && [ -e "$tmp/repo-feat2/.stratum/autonomous/other-session" ]'
fresh; RUNDIR="$tmp/repo-feat2" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" start "${oargs[@]}"
check "LW1 start from a feature's linked worktree: exit 0, session holds the main checkout's id" '[ $rc = 0 ] && [ "$(cat "$lw/.stratum/approve/session")" = "$sid" ]'
mkreq "$rid" 'echo hi'
RUNDIR="$tmp/repo-feat2" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$(ih 'Bash: {"command":"echo hi"}')" --record "$rec"
check "LW2 approve from the linked worktree: exit 0, approved line, .ok written" '[ $rc = 0 ] && hasline "approved\tworker-t004\t%s" "$rid" && [ -e "$lw/.stratum/approve/$rid.ok" ]'
rid2=1700000000000000002-4242
mkreq "$rid2" 'echo hi'
RUNDIR="$tmp/repo-feat2" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" pass T004 --request "$rid2"
check "LW3 pass from the linked worktree: exit 0, passed line" '[ $rc = 0 ] && hasline "passed\tworker-t004\t%s" "$rid2"'
git -C "$repo" worktree add -q "$tmp/repo-feat3" -b feat3
autoset "$sid2"
fresh; RUNDIR="$tmp/repo-feat3" CLAUDE_CODE_SESSION_ID="$sid2" run bash "$script" start "${oargs[@]}"
check "LW5 start from a second linked worktree with session 2: exit 0, session holds the second id" '[ $rc = 0 ] && [ "$(cat "$lw/.stratum/approve/session")" = "$sid2" ]'
mkreq "$rid" 'echo hi'
RUNDIR="$tmp/repo-feat2" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$(ih 'Bash: {"command":"echo hi"}')" --record "$rec"
check "LW5 approve from session 1 on session 2's worker: exit 1, the not-in-run line, no .ok" '[ $rc = 1 ] && [ "$out" = "Worker worker-t004 is not in this autonomous run." ] && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
RUNDIR="$tmp/repo-feat2" CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off --roster "$roster"
check "LW4 autonomous-off from the linked worktree removes only this session's entry" '[ $rc = 0 ] && hasline "autonomous off\tlocal" && [ ! -e "$repo/.stratum/autonomous/$sid" ] && [ -e "$repo/.stratum/autonomous/$sid2" ] && [ -e "$tmp/repo-feat2/.stratum/autonomous/other-session" ]'
autoclr
git -C "$repo" worktree remove --force "$tmp/repo-feat3"
git -C "$repo" branch -q -D feat3
git -C "$repo" worktree remove --force "$tmp/repo-feat2"
git -C "$repo" branch -q -D feat2

hintl=$(printf 'hint\t%s' "Autonomous build mode works better with Claude Code's built-in git instructions off: add \"includeGitInstructions\": false to .claude/settings.json (this project) or ~/.claude/settings.json (all projects), then start new sessions.")
onl=$(printf 'autonomous on\tlocal')
hreset() { autoclr; rm -rf "$repo/.claude" "$tmp/cfg"; }
hirun() { CLAUDE_CODE_SESSION_ID="$sid" run env -u CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS bash "$script" autonomous-on; }
hreset; hirun
check "HI1 no setting anywhere: exit 0, the on line and the hint line, the entry exists" '[ $rc = 0 ] && [ "$out" = "$(printf "%s\n%s" "$onl" "$hintl")" ] && [ -f "$repo/.stratum/autonomous/$sid" ]'
hreset; mkdir -p "$repo/.claude"; printf '{"a": 1, "includeGitInstructions": false}\n' > "$repo/.claude/settings.json"; hirun
check "HI2 project file has false: exit 0, only the on line, the entry exists" '[ $rc = 0 ] && [ "$out" = "$onl" ] && [ -f "$repo/.stratum/autonomous/$sid" ]'
hreset; mkdir -p "$repo/.claude"; printf '{"includeGitInstructions": false}\n' > "$repo/.claude/settings.local.json"; hirun
check "HI3 local file has false: exit 0, only the on line" '[ $rc = 0 ] && [ "$out" = "$onl" ]'
hreset; mkdir -p "$tmp/cfg"; printf '{"includeGitInstructions": false}\n' > "$tmp/cfg/settings.json"; hirun
check "HI4 user file has false: exit 0, only the on line" '[ $rc = 0 ] && [ "$out" = "$onl" ]'
hreset; CLAUDE_CODE_SESSION_ID="$sid" run env CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1 bash "$script" autonomous-on
check "HI5 env var set: exit 0, only the on line" '[ $rc = 0 ] && [ "$out" = "$onl" ]'
hreset; mkdir -p "$repo/.claude"; printf '{"includeGitInstructions": true}\n' > "$repo/.claude/settings.json"; hirun
check "HI6 project file has true: exit 0, the on line and the hint line" '[ $rc = 0 ] && [ "$out" = "$(printf "%s\n%s" "$onl" "$hintl")" ]'
hreset; mkdir -p "$repo/.claude"; printf '{not json\n' > "$repo/.claude/settings.json"; hirun
check "HI7 project file is not JSON: exit 0, the on line and the hint line" '[ $rc = 0 ] && [ "$out" = "$(printf "%s\n%s" "$onl" "$hintl")" ]'
hreset; CLAUDE_CODE_SESSION_ID='../x' run env -u CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS bash "$script" autonomous-on
check "HI8 id ../x: exit 1, the id line, no hint line" '[ $rc = 1 ] && [ "$out" = "$onbad" ] && ! grep -qP "^hint\t" <<<"$out"'
hreset

mk; states blocked; mkreq "$rid" 'echo hi'
run bash "$script" wait T004
check "WA1 approval: exit 6" '[ $rc = 6 ]'
check "WA1 state approval line with the pane" 'hasline "state\tapproval\tworker-t004\t%s" "$(pane)"'
check "WA1 request line" 'hasline "request\t%s" "$rid"'
check "WA1 tab line" 'hasline "tab\ttab worker-t004"'
check "WA1 input line: the tool and one-line JSON" 'hasline "input\tBash: {\"command\":\"echo hi\"}"'
check "WA1 pane text block with the stub pane" 'grep -qxF "pane text:" <<<"$out" && paneshown'
check "WA1 input line comes before pane text" '[ "$(grep -nP "^input\t" <<<"$out" | cut -d: -f1)" -lt "$(grep -n "^pane text:" <<<"$out" | cut -d: -f1)" ]'
check "WA1 no branch or staged line for a Bash request" '! grep -qP "^(branch|staged)\t" <<<"$out"'
check "WA1 never-list" 'never 0 0'
mk; states blocked; mkdir -p "$lw/.stratum/approve"
jq -nc '{tool_name:"Bash",tool_input:{command:"git commit -m x"},time:"2026-10-31T00:00:00Z",branch:"worker-t004",staged:["src/a.py","src/b.py"]}' > "$lw/.stratum/approve/$rid.req"
run bash "$script" wait T004
check "WA2 commit request: exit 6, branch and staged lines" '[ $rc = 6 ] && hasline "branch\tworker-t004" && hasline "staged\tsrc/a.py src/b.py"'
mk; states blocked; mkdir -p "$lw/.stratum/approve"
run bash "$script" wait T004
check "WA3 no request in the folder: exit 4, the blocked line, no approval line" '[ $rc = 4 ] && hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && ! grep -qP "^state\tapproval" <<<"$out"'

printf '%s\n' '{"tool_name":"Bash","tool_input":{"command":"echo $(touch pwned)","description":"d \u00e9"},"time":"t"}' > "$tmp/rq1.req"
printf '%s\n' '{"time":"t","tool_input":{"description":"d \u00e9","command":"echo $(touch pwned)"},"tool_name":"Bash"}' > "$tmp/rq2.req"
rd1=$(python3 "$root/hooks/st-approve.py" --render "$tmp/rq1.req")
rd2=$(python3 "$root/hooks/st-approve.py" --render "$tmp/rq2.req")
check "RD1 --render: key order does not change the line, and the line is the sorted compact JSON" '[ "$rd1" = "$rd2" ] && [ "$rd1" = "$exp" ]'
mk; states blocked; mkdir -p "$lw/.stratum/approve"; cp "$tmp/rq2.req" "$lw/.stratum/approve/$rid.req"
run bash "$script" wait T004
check "RD2 wait: the input line is the --render line, whatever the .req key order" 'hasline "input\t%s" "$exp"'
apx; cp "$tmp/rq2.req" "$lw/.stratum/approve/$rid.req"
apv <<'ST_INPUT_END'
Bash: {"command":"echo $(touch pwned)","description":"d \u00e9"}
ST_INPUT_END
check "RD3 approve: the sorted text matches the reordered .req, approved" '[ $rc = 0 ] && hasline "approved\tworker-t004\t%s" "$rid" && [ -e "$lw/.stratum/approve/$rid.ok" ]'
autoclr

apx; mkreq "$rid" 'echo $(touch pwned) `touch pwned`'
apv <<'ST_INPUT_END'
Bash: {"command":"echo $(touch pwned) `touch pwned`"}
ST_INPUT_END
check "AP1 pwned text: exit 0, approved line" '[ $rc = 0 ] && hasline "approved\tworker-t004\t%s" "$rid"'
check "AP1 pwned text: .ok written" '[ -e "$lw/.stratum/approve/$rid.ok" ]'
check "AP1 pwned text: no pwned file here, in the worker folder or in tmp" '[ ! -e "$repo/pwned" ] && [ ! -e "$lw/pwned" ] && [ ! -e "$tmp/pwned" ]'
check "AP1 pwned text: agent wait until working, 5 s" 'hascall "agent\twait\tworker-t004\t--until\tworking\t--timeout\t5000"'
check "AP1 pwned text: one record line with time, worker, tab, tool and input" 'recok "touch pwned"'
autoclr

rfresh; STUB_SSH_EXEC=1 rrun bash "$script" start "${rxargs[@]}"
mkdir -p "$rw/.stratum/approve"
autoset "$sid"; printf '%s\n' "$sid" > "$rw/.stratum/approve/session"
lw="$rw" mkreq "$rid" 'echo $(touch pwned) `touch pwned`'
states blocked; : > "$tmp/ssh"
STUB_SSH_EXEC=1 rrun bash "$script" wait T004 --machine laptop
check "AP1m wait on laptop: exit 6, approval state and the input line" '[ $rc = 6 ] && hasline "state\tapproval\tworker-t004\t%s" "$(pane)" && hasline "input\t%s" "$exp2"'
: > "$tmp/ssh"; rm -f "$rec"
STUB_SSH_EXEC=1 CLAUDE_CODE_SESSION_ID="$sid" rrun bash "$script" approve T004 --request "$rid" --input-hash "$(ih 'Bash: {"command":"echo $(touch pwned) `touch pwned`"}')" --record "$rec" --machine laptop
check "AP1m approve on laptop: exit 0, approved line, .ok written in the worker folder" '[ $rc = 0 ] && hasline "approved\tworker-t004\t%s" "$rid" && [ -e "$rw/.stratum/approve/$rid.ok" ]'
check "AP1m the .req is read over ssh, and the ssh log has no pwned text" 'grep -qF -- "$rid.req" "$tmp/ssh" && ! grep -q pwned "$tmp/ssh"'
check "AP1m ssh carries only the reads and the .ok write" '[ -s "$tmp/ssh" ] && ! grep -vE "$rid\.(req|ok)|approve/session" "$tmp/ssh" | grep -q .'
check "AP1m no pwned file here or in the worker folder" '[ ! -e "$repo/pwned" ] && [ ! -e "$rw/pwned" ] && [ ! -e "$tmp/pwned" ]'
autoclr

apx; autoclr; mkreq "$rid" 'echo hi'
apv <<'ST_INPUT_END'
Bash: {"command":"echo hi"}
ST_INPUT_END
check "AP2 flag off: exit 1, the off line, no .ok, no agent wait" '[ $rc = 1 ] && [ "$out" = "Autonomous build mode is off for this session." ] && [ ! -e "$lw/.stratum/approve/$rid.ok" ] && [ "$(cnt "^agent\twait\t")" = 0 ]'
apx; mkreq "$rid" 'echo hi'; printf '{}\n' > "$lw/.stratum/x.req"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request ../x --input-hash "$(ih 'Bash: {"command":"echo hi"}')" --record "$rec"
check "AP3 --request ../x: exit 1, no .ok in the worker folder, no agent wait" '[ $rc = 1 ] && [ -z "$(find "$lw" -name "*.ok")" ] && [ "$(cnt "^agent\twait\t")" = 0 ]'
apx
apv <<'ST_INPUT_END'
Bash: {"command":"echo hi"}
ST_INPUT_END
check "AP4 no .req for the id: exit 1, the no-request line" '[ $rc = 1 ] && [ "$out" = "No request $rid for worker-t004." ]'
apx; mkreq "$rid" 'echo hi'
apv <<'ST_INPUT_END'
Bash: {"command":"echo ho"}
ST_INPUT_END
check "AP5 one character differs: exit 1, the mismatch line, no .ok" '[ $rc = 1 ] && [ "$out" = "The input does not match request $rid. Approve nothing." ] && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
long=$(head -c 4100 /dev/zero | tr '\0' x)
apx; mkreq "$rid" "$long"
apv < <(printf 'Bash: {"command":"%s"}\n' "$long")
check "AP6 input over 4000 characters: exit 1, the too-long line, no .ok" '[ $rc = 1 ] && [ "$out" = "Request $rid is too long to approve. Pass it to the user." ] && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
apx; mkreq "$rid" 'echo hi'; printf '%s\n' other-session > "$lw/.stratum/approve/session"
apv <<'ST_INPUT_END'
Bash: {"command":"echo hi"}
ST_INPUT_END
check "AP7 session differs: exit 1, the not-in-run line, no .ok" '[ $rc = 1 ] && [ "$out" = "Worker worker-t004 is not in this autonomous run." ] && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
apx; mkreq "$rid" 'echo hi'; states blocked
run bash "$script" wait T004
nxt=$(awk -F'\t' 'p { print $1; exit } $1 == "input" { p = 1 }' <<<"$out")
ihv=$(awk -F'\t' '$1 == "inputhash" { print $2; exit }' <<<"$out")
inv=$(awk -F'\t' '$1 == "input" { print substr($0, 7); exit }' <<<"$out")
check "IH1 wait: an inputhash line right after the input line, 64 lower-case hex, the sha256 of the printed input text" '[ $rc = 6 ] && [ "$nxt" = inputhash ] && [[ "$ihv" =~ ^[0-9a-f]{64}$ ]] && [ "$ihv" = "$(ih "$inv")" ]'
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$ihv" --record "$rec"
check "IH2 approve with that hash: exit 0, approved line, .ok written, the same record line" '[ $rc = 0 ] && hasline "approved\tworker-t004\t%s" "$rid" && [ -e "$lw/.stratum/approve/$rid.ok" ] && recok "{\"command\":\"echo hi\"}"'
apx; mkreq "$rid" 'echo hi'
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$(ih 'Bash: {"command":"echo ho"}')" --record "$rec"
check "IH3 a hash of other text: exit 1, the mismatch line, no .ok" '[ $rc = 1 ] && [ "$out" = "The input does not match request $rid. Approve nothing." ] && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
h64=$(ih 'Bash: {"command":"echo hi"}')
apx; mkreq "$rid" 'echo hi'
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$h64" --record "$rec"
check "IH4 the 64-hex lower-case hash: exit 0, .ok written" '[ $rc = 0 ] && [ -e "$lw/.stratum/approve/$rid.ok" ]'
for bad in "${h64:0:12}" "${h64^^}"; do
  apx; mkreq "$rid" 'echo hi'
  CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-hash "$bad" --record "$rec"
  check "IH4 hash $bad is not 64 lower-case hex: exit 2, the usage line, no .ok" '[ $rc = 2 ] && grep -q "^usage: st-worker.sh" <<<"$out" && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
done
apx; mkreq "$rid" 'echo hi'
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" approve T004 --request "$rid" --input-stdin --record "$rec" <<'ST_INPUT_END'
Bash: {"command":"echo hi"}
ST_INPUT_END
check "IH5 --input-stdin is gone: exit 2, the usage line, no .ok" '[ $rc = 2 ] && grep -q "^usage: st-worker.sh" <<<"$out" && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
autoclr

apx; mkreq "$rid" 'echo hi'
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" pass T004 --request "$rid"
check "PS1 pass: exit 0, passed line, .user written, no .ok" '[ $rc = 0 ] && hasline "passed\tworker-t004\t%s" "$rid" && [ -e "$lw/.stratum/approve/$rid.user" ] && [ ! -e "$lw/.stratum/approve/$rid.ok" ]'
apx; autoclr; mkreq "$rid" 'echo hi'
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" pass T004 --request "$rid"
check "PS2 pass with the flag off: exit 1, the off line, no .user" '[ $rc = 1 ] && [ "$out" = "Autonomous build mode is off for this session." ] && [ ! -e "$lw/.stratum/approve/$rid.user" ]'
apx; mkreq "$rid" 'echo hi'; printf '%s\n' other-session > "$lw/.stratum/approve/session"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" pass T004 --request "$rid"
check "PS3 pass with a session mismatch: exit 1, the not-in-run line, no .user" '[ $rc = 1 ] && [ "$out" = "Worker worker-t004 is not in this autonomous run." ] && [ ! -e "$lw/.stratum/approve/$rid.user" ]'
autoclr

sydir() { apx; mkreq "$rid" 'echo hi'; rm -rf "$tmp/aptarget"; mv "$lw/.stratum/approve" "$tmp/aptarget"; ln -s "$tmp/aptarget" "$lw/.stratum/approve"; snap0=$(ls -A "$tmp/aptarget"); }
syfile() { apx; mkreq "$rid" 'echo hi'; rm -rf "$tmp/aptarget"; printf 'keep\n' > "$tmp/aptarget"; ln -s "$tmp/aptarget" "$lw/.stratum/approve/$rid.$1"; }
sydir
apv <<'ST_INPUT_END'
Bash: {"command":"echo hi"}
ST_INPUT_END
check "SY1 approve, .stratum/approve a symlink: exit 1, the cannot-write line, target unchanged" '[ $rc = 1 ] && [ "$out" = "Cannot write $rid.ok for worker-t004." ] && [ "$(ls -A "$tmp/aptarget")" = "$snap0" ]'
syfile ok
apv <<'ST_INPUT_END'
Bash: {"command":"echo hi"}
ST_INPUT_END
check "SY2 approve, $rid.ok a symlink: exit 1, the cannot-write line, target unchanged" '[ $rc = 1 ] && [ "$out" = "Cannot write $rid.ok for worker-t004." ] && [ "$(cat "$tmp/aptarget")" = keep ]'
sydir
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" pass T004 --request "$rid"
check "SY3 pass, .stratum/approve a symlink: exit 1, the cannot-write line, target unchanged" '[ $rc = 1 ] && [ "$out" = "Cannot write $rid.user for worker-t004." ] && [ "$(ls -A "$tmp/aptarget")" = "$snap0" ]'
syfile user
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" pass T004 --request "$rid"
check "SY4 pass, $rid.user a symlink: exit 1, the cannot-write line, target unchanged" '[ $rc = 1 ] && [ "$out" = "Cannot write $rid.user for worker-t004." ] && [ "$(cat "$tmp/aptarget")" = keep ]'
rm -rf "$tmp/aptarget"
autoclr

for pl in 'Do you want to proceed?' 'Do you want to make this edit to a.py?' 'Do you want to create b.py?' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)'; do
  mk; states blocked; printf '%s\n' "$rule" "$pl" > "$tmp/pane.txt"
  run bash "$script" answer T004 --text hi
  check "AN1 pane line '$pl': exit 1, the permission line, no key sent" '[ $rc = 1 ] && [ "$out" = "This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
done
mk; states blocked
STUB_FAIL="agent read" STUB_FAIL_CODE=timeout run bash "$script" answer T004 --keys 1
check "AN2 agent read fails: exit 1, the same permission line, no key sent" '[ $rc = 1 ] && [ "$out" = "This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
for pq in 'Should the helper be named normalizeInput?' 'Do you want to rename it?'; do
  mk; states blocked working; printf '%s\n' "$pq" '❯ 1. Yes' '  2. No' > "$tmp/pane.txt"
  run bash "$script" answer T004 --keys 1
  check "AN3 ordinary question '$pq': exit 0, the key sent" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
done
mk; states blocked working; { printf '%s\n' "$rule" ' Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)'; seq -f 'line %g' 15; printf '%s\n' 'Should the helper be named normalizeInput?' '❯ 1. Yes' '  2. No'; } > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 1
check "AN4 permission dialog more than 15 lines up: exit 0, the key sent" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked working
run bash "$script" answer T004 --screen "$h" --keys 1
check "AN5 permission dialog, option 1 is the one-time yes: exit 0, the key sent" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
mk; states blocked; printf '%s\n' "$rule" 'Do you want to make this edit to a.py?' '❯ 1. Yes' '  2. Yes, allow all edits during this session (shift+tab)' '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked working
run bash "$script" answer T004 --screen "$h" --keys 1
check "AN5b edit dialog, option 1 is the one-time yes: exit 0, the key sent" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
for ao in "  2. Yes, and don't ask again for git commands" "  2. Yes, and don’t ask again for git commands" '  2. Yes, allow reads for this session' '  2. Yes, allow all edits during this session (shift+tab)' '  2. Yes, and allow this in the future' '  2. Yes, and always allow access to other/ from this project'; do
  mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "$ao" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
  run bash "$script" wait T004; h=$(shash); states blocked
  run bash "$script" answer T004 --screen "$h" --keys 2
  check "AN6 option 2 '$ao' is not a one-time yes: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
done
mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' '  2. Yes, allow reading from other-project/secrets/' '     during this session' '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked
run bash "$script" answer T004 --screen "$h" --keys 2
check "AN6b option 2 wraps, 'during this session' on the next line: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; printf '%s\n' "$rule" 'Bash command' '  printf "3. step three"' 'Do you want to proceed?' '❯ 1. Yes' '  2. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked
run bash "$script" answer T004 --screen "$h" --keys 3
check "AN6c a command line with 3. is not option 3: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 3 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; printf '%s\n' "$rule" 'Bash command' '  2. Yes' 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked
run bash "$script" answer T004 --screen "$h" --keys 2
check "AN6d a command line 2. Yes above the dialog is not option 2: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; printf '%s\n' "$rule" 'Bash command' '  3. Yes' 'Do you want to proceed?' '❯ 1. Yes' '  2. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked
run bash "$script" answer T004 --screen "$h" --keys 3
check "AN6e a command line 3. Yes above the dialog is not option 3: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 3 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; printf '%s\n' "$rule" 'Read file' 'Do you want to proceed?' '❯ 1. Yes' '  2. Yes, allow reading from evil/' 'Do you want to proceed?' '  2. Yes' '/ during this session' '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004
check "AN6f two dialog heads in the window: wait exits 4 and prints no screen line" '[ $rc = 4 ] && ! grep -q "^screen" <<<"$out"'
states blocked working
run bash "$script" answer T004 --screen 0123456789ab --keys 2
check "AN6f option 2 under a second dialog head, any hash: exit 1, the another-prompt line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; printf '%s\n' "$rule" 'Read file' 'Do you want to proceed?' '❯ 1. Yes' '  2. Yes, allow reading from evil/' '  2. Yes' '/ during this session' '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked working
run bash "$script" answer T004 --screen "$h" --keys 2
check "AN6g a second 2. Yes line under the lasting option 2 is not a one-time yes: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; printf '%s\n' "$rule" 'Read file' 'Do you want to proceed?' '❯ 1. Yes' '  2. Yes' '/ during this session' '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked working
run bash "$script" answer T004 --screen "$h" --keys 2
check "AN6h option 2 reads 'Yes' and 'during this session' is on the next line: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; printf '%s\n' "$rule" 'Read file' 'Do you want to proceed?' '❯ 1. Yes' '  2. Yes' '  2. Yes, allow reading from evil/' '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked working
run bash "$script" answer T004 --screen "$h" --keys 2
check "AN6i two option 2 lines, the first '2. Yes', the second lasting: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
for ka in '1 enter' 'enter' 'down'; do
  mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
  run bash "$script" wait T004; h=$(shash); states blocked
  run bash "$script" answer T004 --screen "$h" --keys $ka
  check "AN7 --keys $ka: exit 1, the one-option line, nothing sent" '[ $rc = 1 ] && [ "$out" = "A permission prompt takes one option number. Nothing sent." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
done
mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash); states blocked
run bash "$script" answer T004 --screen "$h" --keys 4
check "AN8 --keys 4, the pane has no option 4: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 4 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
for no in '  2. No, and tell Claude what to do differently (esc)' '  2. No'; do
  mk; states blocked working; printf '%s\n' 'Bash command: very-long-command ...' 'Do you want to proceed?' '❯ 1. Yes' "$no" > "$tmp/pane.txt"
  run bash "$script" wait T004; h=$(shash); states blocked working
  run bash "$script" answer T004 --screen "$h" --keys 2
  check "NO1 cut-off dialog, option 2 '$no' with a matching hash: exit 0, the key sent" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t2"'
done
mk; states blocked; printf '%s\n' 'Bash command: very-long-command ...' 'Do you want to proceed?' '❯ 1. Yes' '  2. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; states blocked
run bash "$script" answer T004 --screen 000000000000 --keys 2
check "NO2 option 2 No with a wrong hash: exit 1, the other-prompt line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
for ao in '  2. Yes, and always allow access to other/ from this project' "  2. No, and don't ask again" '  2. No, always deny git commands' '  2. No, deny for this session' '  2. No, and deny this in the future' '  2. No, block example.com' '  2. Nope'; do
  mk; states blocked; printf '%s\n' 'Do you want to proceed?' '❯ 1. Yes' "$ao" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
  run bash "$script" wait T004; h=$(shash); states blocked
  run bash "$script" answer T004 --screen "$h" --keys 2
  check "NO3 option 2 '$ao' is refused: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
done
mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash)
check "AN9 permission dialog: wait prints one screen line with a 12 hex hash, after the state line and before pane text:" '[ $rc = 4 ] && [ "$(grep -c "^screen" <<<"$out")" = 1 ] && hasline "screen\t%s" "$h" && [[ "$h" =~ ^[0-9a-f]{12}$ ]] && [ "$(grep -oP "^(state(?=\t)|screen(?=\t)|pane text:$)" <<<"$out")" = "$(printf "state\nscreen\npane text:")" ]'
mk; states blocked; printf '%s\n' 'Should the helper be named normalizeInput?' '❯ 1. Yes' '  2. No' > "$tmp/pane.txt"
run bash "$script" wait T004
check "AN9 question pane: wait prints the state line and no screen line" '[ $rc = 4 ] && hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && ! grep -q "^screen" <<<"$out"'
mk; states blocked; { seq -f 'line %g' 25; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)'; } > "$tmp/pane.txt"
run bash "$script" wait T004; txt=$(sed -n '/^pane text:$/,$p' <<<"$out" | tail -n +2)
bb=$(printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' | sha256sum | cut -c1-12)
check "AN9b a 30-line dialog: the screen hash is the hash of the 5 block lines (rule through option 3), and the pane text holds line 5 (the 40-line read)" '[ $rc = 4 ] && [ "$(shash)" = "$bb" ] && grep -qxF "line 5" <<<"$txt"'
for p1 in '❯ 1. Yes' '  1. Yes' '│ 1. Yes' '❯ 1. Yes, proceed' '❯ 1. Yes, proceed (y)' '❯ 1. Yes, just this once'; do
  mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' "$p1" "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
  run bash "$script" wait T004; h=$(shash); states blocked working
  run bash "$script" answer T004 --screen "$h" --keys 1
  check "AN10 option 1 '$p1' is a one-time yes: exit 0, the key sent" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
done
mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash)
printf '%s\n' "$rule" 'Bash command' '  git push' 'Do you want to proceed?' '❯ 1. Yes' '  2. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
states blocked
run bash "$script" answer T004 --screen "$h" --keys 1
check "AN11 the pane changed after wait: exit 1, the another-prompt line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; states blocked; { seq -f 'line %g' 25; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)'; } > "$tmp/pane.txt"
run bash "$script" wait T004; h=$(shash)
sed -i 's/^line 5$/line five/' "$tmp/pane.txt"
states blocked working
run bash "$script" answer T004 --screen "$h" --keys 1
check "AN11b line 5 changes, outside the block (the 40-line read holds it): exit 0, key 1 sent" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
run bash "$script" answer T004 --keys 1
check "AN12 no --screen on a permission dialog: exit 1, the needs-screen line, nothing sent" '[ $rc = 1 ] && [ "$out" = "A permission prompt needs --screen <hash> from the screen line of wait or watch. Nothing sent." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
for bh in abc 0123456789abc 0123456789AB; do
  mk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
  run bash "$script" answer T004 --screen "$bh" --keys 1
  check "AN13 --screen '$bh' is not 12 lower-case hex: exit 2, the usage line, no herdr call" '[ $rc = 2 ] && grep -q "^usage: st-worker.sh" <<<"$out" && [ ! -s "$tmp/calls" ]'
done

rmk; states blocked; printf '%s\n' "$rule" 'Do you want to proceed?' '❯ 1. Yes' "  2. Yes, and don't ask again for git commands" '  3. No, and tell Claude what to do differently (esc)' > "$tmp/pane.txt"
rrun bash "$script" wait T004 --machine laptop; h=$(shash); states blocked working
rrun bash "$script" answer T004 --machine laptop --screen "$h" --keys 1
check "AN14 remote worker, permission dialog, --machine before --screen and --keys: exit 0, key 1 sent on laptop" '[ $rc = 0 ] && [ "$(rcnt "agent\tsend-keys\t")" = 1 ] && rcall "agent\tsend-keys\tworker-t004\t1" && rnever 0 0'

mk; states done; apd; printf '%s\n' "$sid" > "$lw/.stratum/approve/session"
run bash "$script" close T004
check "CL1 close: exit 0, the approve folder is gone" '[ $rc = 0 ] && [ ! -e "$lw/.stratum/approve" ]'

xsetup; printf 'worker-t004\tlocal\tworker-t004\tT004\nworker-t005\tlaptop\tworker-t005\tT005\t%s\n' "$rrepo" > "$aoroster"
autoclr; autoset "$sid"; rautoset "$rrepo" "$sid"
STUB_SSH_EXEC=1 CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off --roster "$aoroster"
check "AO1 exit 0, the local and laptop lines" '[ $rc = 0 ] && hasline "autonomous off\tlocal" && hasline "autonomous off\tlaptop"'
check "AO1 both entries with this session id are removed" '[ ! -e "$repo/.stratum/autonomous/$sid" ] && [ ! -e "$rrepo/.stratum/autonomous/$sid" ]'
xsetup; autoclr; autoset other-session; rautoset "$rrepo" other-session
STUB_SSH_EXEC=1 CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off --roster "$aoroster"
check "AO2 entries of another session are kept: exit 0" '[ $rc = 0 ] && [ -e "$repo/.stratum/autonomous/other-session" ] && [ -e "$rrepo/.stratum/autonomous/other-session" ]'
check "AO2 each machine says this session is not on" 'hasline "autonomous off skipped\tlocal\tnot on for this session" && hasline "autonomous off skipped\tlaptop\tnot on for this session" && ! grep -q "^autonomous off	" <<<"$out"'
reset; : > "$tmp/ssh"; CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off
check "AO5 no roster, not on: exit 0, the skipped line, other entry kept, no ssh" '[ $rc = 0 ] && [ "$out" = "$(printf "autonomous off skipped\tlocal\tnot on for this session")" ] && [ -e "$repo/.stratum/autonomous/other-session" ] && [ ! -s "$tmp/ssh" ]'
autoset "$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off
check "AO5 no roster, this id: exit 0, the local line, entry removed, other entry kept" '[ $rc = 0 ] && [ "$out" = "$(printf "autonomous off\tlocal")" ] && [ ! -e "$repo/.stratum/autonomous/$sid" ] && [ -e "$repo/.stratum/autonomous/other-session" ]'
xsetup; autoclr; autoset "$sid"; rautoset "$rrepo" "$sid"
STUB_SSH_RC=255 CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off --roster "$aoroster"
check "AO3 ssh down: exit 1, the failed laptop line, local removed, laptop entry kept" '[ $rc = 1 ] && hasline "autonomous off failed\tlaptop\tssh: stub failure" && hasline "autonomous off\tlocal" && [ ! -e "$repo/.stratum/autonomous/$sid" ] && [ -e "$rrepo/.stratum/autonomous/$sid" ]'
autoclr
xsetup; rm -rf "$tmp/rrepo2"; mkdir -p "$tmp/rrepo2/.stratum"
printf 'worker-t004\tlaptop\tworker-t004\tT004\t%s\nworker-t005\tlaptop\tworker-t005\tT005\t%s\n' "$rrepo" "$tmp/rrepo2" > "$aoroster"
rautoset "$rrepo" "$sid"; rautoset "$tmp/rrepo2" "$sid"
STUB_SSH_EXEC=1 CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off --roster "$aoroster"
check "AO4 two repos on one machine: exit 0, both entries removed" '[ $rc = 0 ] && [ ! -e "$rrepo/.stratum/autonomous/$sid" ] && [ ! -e "$tmp/rrepo2/.stratum/autonomous/$sid" ]'
autoset "$sid"
STUB_SSH_EXEC=1 CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off --roster "$aoroster"
check "AO6 a roster with saved machines only still clears the local entry" '[ $rc = 0 ] && hasline "autonomous off\tlocal" && [ ! -e "$repo/.stratum/autonomous/$sid" ]'

printf 'worker-t004\tlocal\tworker-t004\tT004\nworker-t005\tlaptop\tworker-t005\tT005\t%s\n' "$rrepo" > "$aoroster"
ofrun() { STUB_SSH_EXEC=1 CLAUDE_CODE_SESSION_ID="$1" run bash "$script" autonomous-off --roster "$aoroster"; }
xsetup; autoclr; autoset "$sid"; autoset other-session; rautoset "$rrepo" "$sid"; rautoset "$rrepo" other-session
ofrun "$sid"
check "OF1 exit 0, the local and laptop lines" '[ $rc = 0 ] && hasline "autonomous off\tlocal" && hasline "autonomous off\tlaptop"'
check "OF1 only this session's entries are removed, here and on the laptop" '[ ! -e "$repo/.stratum/autonomous/$sid" ] && [ ! -e "$rrepo/.stratum/autonomous/$sid" ] && [ -e "$repo/.stratum/autonomous/other-session" ] && [ -e "$rrepo/.stratum/autonomous/other-session" ]'
for bad in '' '../x'; do
  xsetup; autoclr; autoset "$sid"; autoset other-session; rautoset "$rrepo" "$sid"; : > "$repo/.stratum/x"; : > "$rrepo/.stratum/x"; : > "$tmp/ssh"
  ofrun "$bad"
  check "OF2 id '$bad': exit 1, the off line, nothing removed, no ssh" '[ $rc = 1 ] && [ "$out" = "Autonomous build mode is off for this session." ] && [ -e "$repo/.stratum/autonomous/$sid" ] && [ -e "$repo/.stratum/autonomous/other-session" ] && [ -e "$rrepo/.stratum/autonomous/$sid" ] && [ -e "$repo/.stratum/x" ] && [ -e "$rrepo/.stratum/x" ] && [ ! -s "$tmp/ssh" ]'
done
rm -f "$repo/.stratum/x"
xsetup; autoclr; rm -rf "$tmp/flink"; mkdir "$tmp/flink"; : > "$tmp/flink/$sid"; ln -s "$tmp/flink" "$repo/.stratum/autonomous"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off
check "OF3 symlinked folder: exit 1, the failed local line, target kept" '[ $rc = 1 ] && grep -qP "^autonomous off failed\tlocal\t.* is a symlink$" <<<"$out" && [ -e "$tmp/flink/$sid" ]'
autoclr; mkdir -p "$repo/.stratum/autonomous"; printf 'keep\n' > "$tmp/ftarget"; ln -s "$tmp/ftarget" "$repo/.stratum/autonomous/$sid"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off
check "OF3b symlinked entry: exit 1, the failed local line, target kept" '[ $rc = 1 ] && grep -qP "^autonomous off failed\tlocal\t.* is a symlink$" <<<"$out" && [ "$(cat "$tmp/ftarget")" = keep ]'
autoclr
xsetup; rm -rf "$tmp/rlink"; mkdir "$tmp/rlink"; : > "$tmp/rlink/$sid"; ln -s "$tmp/rlink" "$rrepo/.stratum/autonomous"
ofrun "$sid"
check "OF3c laptop symlinked folder: exit 1, the failed laptop line, target kept" '[ $rc = 1 ] && grep -qP "^autonomous off failed\tlaptop\t" <<<"$out" && [ -e "$tmp/rlink/$sid" ]'
xsetup; mkdir -p "$rrepo/.stratum/autonomous"; printf 'keep\n' > "$tmp/rtarget"; ln -s "$tmp/rtarget" "$rrepo/.stratum/autonomous/$sid"
ofrun "$sid"
check "OF3c laptop symlinked entry: exit 1, the failed laptop line, target kept" '[ $rc = 1 ] && grep -qP "^autonomous off failed\tlaptop\t" <<<"$out" && [ "$(cat "$tmp/rtarget")" = keep ]'
autoclr; autoset sA; autoset sB; autoset other-session; rm -f "$tmp"/bg.*
bgrun sA autonomous-off & bgrun sB autonomous-off & wait
check "OF4 two sessions turn off at once: both exit 0, both entries removed, the other kept" '[ "$(cat "$tmp/bg.sA")" = 0 ] && [ "$(cat "$tmp/bg.sB")" = 0 ] && [ ! -e "$repo/.stratum/autonomous/sA" ] && [ ! -e "$repo/.stratum/autonomous/sB" ] && [ -e "$repo/.stratum/autonomous/other-session" ]'
autoclr; printf 'old\n' > "$repo/.stratum/autonomous"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" autonomous-off
check "OF5 an old single file: exit 0, the skipped line, file kept" '[ $rc = 0 ] && [ "$out" = "$(printf "autonomous off skipped\tlocal\tnot on for this session")" ] && [ "$(cat "$repo/.stratum/autonomous")" = old ]'
autoclr

ax; autoset "$sid"
axrun
check "AM1 saved machine: exit 0" '[ $rc = 0 ]'
check "AM1 the entry on the machine is an empty file named with the session id" '[ -d "$rrepo/.stratum/autonomous" ] && [ -f "$rrepo/.stratum/autonomous/$sid" ] && [ ! -s "$rrepo/.stratum/autonomous/$sid" ]'
check "AM1 one ssh call writes the repo flag, before worktree add" '[ "$(grep -c "stratum/autonomous" "$tmp/ssh")" = 1 ] && o1=$(grep -n "^ssh$" "$tmp/order" | head -n1 | cut -d: -f1) && o2=$(grep -n "^worktree add$" "$tmp/order" | head -n1 | cut -d: -f1) && [ -n "$o1" ] && [ -n "$o2" ] && [ "$o1" -lt "$o2" ]'
check "AM1 the remote session file holds the session id" '[ "$(cat "$rw/.stratum/approve/session")" = "$sid" ]'
check "AM1 the remote brief has the four-column roster row and no repo path" 'grep -qxF "| worker-t004 | laptop | worker-t004 | T004 |" "$rw/brief.md" && ! sed "s#$rrepo-worker-t004##g" "$rw/brief.md" | grep -qF "$rrepo"'
autoclr
ax; autoset "$sid"; printf 'worker-t004\tlaptop\tworker-t004\tT004\nworker-t005\tlocal\tworker-t005\tT005\n' > "$aroster"
axrun
check "AM2 no fifth field: exit 1, the roster line, no call" '[ $rc = 1 ] && [ "$out" = "Roster row for worker-t004 needs the repo path as a fifth field." ] && [ ! -s "$tmp/calls" ] && [ ! -s "$tmp/ssh" ]'
ax; autoset "$sid"; printf 'worker-t004\tlaptop\tworker-t004\tT004\t%s\nworker-t005\tlocal\tworker-t005\tT005\n' "$tmp/other-repo" > "$aroster"
axrun
check "AM2b a different fifth field: the same roster line, no call" '[ $rc = 1 ] && [ "$out" = "Roster row for worker-t004 needs the repo path as a fifth field." ] && [ ! -s "$tmp/calls" ] && [ ! -s "$tmp/ssh" ]'
autoclr
ax; autoset "$sid"; printf '%s\n' old-session > "$rrepo/.stratum/autonomous"
axrun
check "AM3 an old single file in the repo is replaced by the folder with the entry" '[ $rc = 0 ] && [ -d "$rrepo/.stratum/autonomous" ] && [ ! -L "$rrepo/.stratum/autonomous" ] && [ -f "$rrepo/.stratum/autonomous/$sid" ]'
autoclr
ax; autoset "$sid"; rm -rf "$rrepo/.stratum"; mkdir "$tmp/rlink"; ln -s "$tmp/rlink" "$rrepo/.stratum"
axrun
check "AM4 symlinked .stratum: exit 1, the cannot-write line, no worktree add, no agent start, target empty" '[ $rc = 1 ] && grep -q "^cannot write .stratum/autonomous on laptop: " <<<"$out" && [ ! -e "$tmp/rlink/autonomous" ] && ! grep -q "worktree add" "$tmp/ssh" && [ "$(cnt "^--machine\tlaptop\tagent\tstart\t")" = 0 ]'
autoclr
ax; autoset "$sid"; printf 'keep\n' > "$tmp/rtarget"; mkdir -p "$rrepo/.stratum/autonomous"; ln -s "$tmp/rtarget" "$rrepo/.stratum/autonomous/$sid"
axrun
check "AM5 symlinked repo entry: exit 1, the cannot-write line, target unchanged, no worktree add" '[ $rc = 1 ] && grep -q "^cannot write .stratum/autonomous on laptop: " <<<"$out" && [ "$(cat "$tmp/rtarget")" = keep ] && ! grep -q "worktree add" "$tmp/ssh"'
autoclr
ax; autoset "$sid"
STUB_SSH_RC=255 axrun
check "AM6 ssh down on the repo flag write: exit 1, the line, no worktree add or agent start" '[ $rc = 1 ] && hasline "cannot write .stratum/autonomous on laptop: ssh: stub failure" && ! grep -q "worktree add" "$tmp/ssh" && [ "$(cnt "^--machine\tlaptop\tagent\tstart\t")" = 0 ]'
autoclr
ax; autoset "$sid"; mkdir -p "$rrepo/.stratum/autonomous"; printf 'keep\n' > "$rrepo/.stratum/autonomous/$sid"
axrun
check "AM7 an existing repo entry on the machine: exit 0, the entry is not truncated" '[ $rc = 0 ] && [ "$(cat "$rrepo/.stratum/autonomous/$sid")" = keep ]'
autoclr
rfresh; xsetup; STUB_SSH_EXEC=1 STUB_GIT_FAIL=add255 rrun bash "$script" start "${rxargs[@]}"
check "R16b saved machine, git worktree add exits 255: exit 1, git's fatal line, not ssh failed, no tab create" '[ $rc = 1 ] && [ "$(grep -c "^stopped:" <<<"$out")" = 1 ] && hasline "stopped: fatal: stub git refused 255" && ! grep -q "ssh to" <<<"$out" && hasline "worker\tworker-t004\tlaptop\t-\t-\t-\t-" && [ "$(rcnt "tab\tcreate\t")" = 0 ]'

wr="$tmp/wroster"; printf 'worker-t004\tlocal\tworker-t004\tT004\n' > "$wr"
sleeps() { grep -c '^sleep' "$tmp/calls"; }
rto=$(command -v timeout)
wrun() { run "$rto" 60 bash "$script" watch --roster "$wr"; }
mk; rm -f "$wr.seen"; states working working done; printf 'R\n' > "$lw/result.md"
wrun
check "WC1 watch: finished after two polls, exit 0, seen holds finished" '[ $rc = 0 ] && hasline "state\tfinished\tworker-t004\t%s" "$(pane)" && [ "$(sleeps)" = 2 ] && grep -qxP "worker-t004\tfinished [0-9]+ [0-9]+" "$wr.seen" && never 0 0'
states done done blocked; sentpane > "$tmp/pane.txt"; reset
wrun
check "WC2 a seen finished worker is skipped; a new question is reported: exit 4, blocked" '[ $rc = 4 ] && hasline "state\tblocked\tworker-t004\t%s" "$(pane)" && ! grep -q "^state	finished" <<<"$out" && [ "$(sleeps)" = 2 ]'
states blocked blocked working blocked; reset
wrun
check "WC3 the same open question is not reported again until the worker worked: exit 4 after three polls" '[ $rc = 4 ] && [ "$(sleeps)" = 3 ] && hasline "state\tblocked\tworker-t004\t%s" "$(pane)"'
mk; rm -f "$wr.seen"; states idle working done; unsentpane > "$tmp/pane.txt"; sentpane > "$tmp/pane.after"; : > "$tmp/resume_result"
wrun
check "WC4 unsent prompt: one Enter by itself, then finished" '[ $rc = 0 ] && [ "$(cnt "^agent\tsend-keys\tworker-t004\tenter$")" = 1 ] && hasline "state\tfinished\tworker-t004\t%s" "$(pane)" && never 0 0'
mk; rm -f "$wr.seen"; states idle; unsentpane > "$tmp/pane.txt"
wrun
check "WC5 prompt still in the box after the Enter: exit 7, state unsent" '[ $rc = 7 ] && [ "$(cnt "^agent\tsend-keys\tworker-t004\tenter$")" = 1 ] && hasline "state\tunsent\tworker-t004\t%s" "$(pane)"'
mk; rm -f "$wr.seen"; states idle; sentpane > "$tmp/pane.txt"
wrun
check "WC6 idle with no result, question or prompt for three polls: exit 5, stopped" '[ $rc = 5 ] && [ "$(sleeps)" = 2 ] && hasline "state\tstopped\tworker-t004\t%s" "$(pane)"'
mk; rm -f "$wr.seen"
STUB_FAIL="agent get" run bash "$script" watch --roster "$wr"
check "WC7 a worker that is gone and never seen: exit 5, the gone line" '[ $rc = 5 ] && [ "$out" = "$(printf "state\tgone\tworker-t004\t-")" ]'
apx; rm -f "$wr.seen"; states blocked; mkreq "$rid" 'npm test'
wrun
check "WC8 approval request: exit 6, the request lines, seen holds its id" '[ $rc = 6 ] && hasline "state\tapproval\tworker-t004\t%s" "$(pane)" && hasline "request\t%s" "$rid" && [ "$(cat "$wr.seen")" = "$(printf "worker-t004\tapproval %s" "$rid")" ]'
states blocked working done; printf 'R\n' > "$lw/result.md"; reset
wrun
check "WC9 the same request is not reported again: exit 0, finished" '[ $rc = 0 ] && ! grep -q "^state	approval" <<<"$out" && hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
autoclr
mk; rm -f "$wr.seen"; states done; printf 'ROUND1\n' > "$lw/result.md"
wrun
printf 'ROUND2\n' > "$lw/result.md"; reset
wrun
check "WC11 a new result.md after a reported finish is a new finish: exit 0, finished" '[ $rc = 0 ] && hasline "state\tfinished\tworker-t004\t%s" "$(pane)"'
mk; printf 'worker-t004\tblocked 123\n' > "$wr.seen"
STUB_FAIL="agent get" run "$rto" 60 bash "$script" watch --roster "$wr"
check "WC12 a blocked worker that is gone is reported: exit 5, the gone line" '[ $rc = 5 ] && [ "$out" = "$(printf "state\tgone\tworker-t004\t-")" ]'
printf 'worker-t004\tlocal\tworker-t004\tT004\nworker-t005\tlocal\tworker-t005\tT005\n' > "$tmp/wr2"; printf 'worker-t004\tfinished 1 2\n' > "$tmp/wr2.seen"
STUB_FAIL="agent get" run "$rto" 60 bash "$script" watch --roster "$tmp/wr2"
check "WC12 a finished worker that is gone (closed) is skipped: only the other worker is reported" '[ $rc = 5 ] && [ "$out" = "$(printf "state\tgone\tworker-t005\t-")" ]'
printf 'worker-t004\tnowhere\tworker-t004\tT004\n' > "$tmp/wbad"
fresh; run bash "$script" watch --roster "$tmp/wbad"
check "WC10 unknown machine: exit 1, the line, no agent call" '[ $rc = 1 ] && [ "$out" = "Unknown machine: nowhere." ] && [ "$(cnt "^agent\t")" = 0 ]'

box=$(printf '╌%.0s' {1..40})
REAL=('❯ Run this exact Bash command and nothing else: touch /tmp/p.txt' '  ⎿  $ touch /tmp/p.txt' '' "$rule" ' Bash command' ' Tip: auto mode handles these prompts for you — choose "switch to auto mode" below' ' Create empty file p.txt' "$box" ' │ touch /tmp/p.txt' "$box" ' Do you want to proceed?' ' ❯ 1. Yes' '   2. Yes, and always allow access to /tmp from this project' '   3. Yes, and switch to auto mode · auto mode handles these prompts for you' '   4. No' '' ' Esc to cancel · Tab to amend')
bh=$(printf '%s\n' "${REAL[@]:3:12}" | sha256sum | cut -c1-12)
dbput() { printf '%s\n' "$@" > "$tmp/pane.txt"; }
dbwait() { mk; states blocked; dbput "$@"; run bash "$script" wait T004; h=$(shash); }
dbans() { states blocked working; run bash "$script" answer T004 --screen "$h" --keys "$1"; }

dbwait "${REAL[@]}"
check "DB1 wait: one screen line, its hash is the first 12 hex of the 12 block lines (rule through 4. No)" '[ $rc = 4 ] && [ "$(grep -c "^screen" <<<"$out")" = 1 ] && [ "$h" = "$bh" ]'
dbwait "${REAL[@]}"; dbput 'step a' 'step b' 'step c' "${REAL[@]:0:1}" '  ⎿  Running… (12s)' "${REAL[@]:2}"; dbans 1
check "DB2 lines above the dialog and the ⎿ line change: exit 0, key 1 sent" '[ "$h" = "$bh" ] && [ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
dbwait "${REAL[@]}"; dbput "${REAL[@]:0:8}" ' │ touch /tmp/q.txt' "${REAL[@]:9}"; dbans 1
check "DB3 the command line changed: exit 1, the another-prompt line, nothing sent" '[ "$h" = "$bh" ] && [ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
dbwait "${REAL[@]}"; dbput "${REAL[@]:0:4}" ' Bash command (unsandboxed)' "${REAL[@]:5}"; dbans 1
check "DB4 the header line changed: exit 1, the another-prompt line, nothing sent" '[ "$h" = "$bh" ] && [ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
dbwait "${REAL[@]}"; dbput "${REAL[@]:0:12}" '   2. Yes, and always allow access to / from this project' "${REAL[@]:13}"; dbans 1
check "DB5 option 2 changed: exit 1, the another-prompt line, nothing sent" '[ "$h" = "$bh" ] && [ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
dbwait "${REAL[@]}"; dbput "${REAL[@]:0:16}" ' Esc to cancel · Tab to amend · changed'; dbans 1
check "DB6 the footer changed (outside the block): exit 0, key 1 sent" '[ "$h" = "$bh" ] && [ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t1"'
cut=("${REAL[@]:0:8}"); for i in $(seq 45); do cut+=(" │ line $i"); done; cut+=("${REAL[@]:9}")
dbwait "${cut[@]}"; txt=$(sed -n '/^pane text:$/,$p' <<<"$out" | tail -n +2)
check "DB7 cut: wait exits 4, one screen line, its hash is the first 12 hex of the printed 40-line pane text" '[ $rc = 4 ] && [ "$(grep -c "^screen" <<<"$out")" = 1 ] && [ "$h" = "$(sha256sum <<<"$txt" | cut -c1-12)" ] && [ "$(awk "END{print NR}" <<<"$txt")" = 40 ]'
dbans 1
check "DB7 cut: --keys 1 (a yes) refused with the cut-off line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The top of the dialog is not on the screen, so only its No can be sent. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
dbans 4
check "DB7b cut: --keys 4 (No) sent: exit 0, key 4" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t4"'
dbwait "${cut[@]}"; dbput "${cut[@]:0:37}" ' │ changed' "${cut[@]:38}"; dbans 4
check "DB7c cut: a transcript line inside the 40 lines changed: --keys 4 refused with the another-prompt line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
norule=("${REAL[@]:0:3}" "${REAL[@]:4}")
dbwait "${norule[@]}"; txt=$(sed -n '/^pane text:$/,$p' <<<"$out" | tail -n +2)
check "DB8 no top rule in the pane: wait exits 4, one screen line, its hash is the first 12 hex of the printed pane text" '[ $rc = 4 ] && [ "$(grep -c "^screen" <<<"$out")" = 1 ] && [ "$h" = "$(sha256sum <<<"$txt" | cut -c1-12)" ]'
dbans 1
check "DB8 --keys 1 (a yes) refused with the cut-off line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The top of the dialog is not on the screen, so only its No can be sent. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
dbans 4
check "DB8 --keys 4 (No) sent: exit 0, key 4" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t4"'
dbwait "${REAL[@]:0:13}" ' Do you want to proceed?' "${REAL[@]:13}"
check "DB9 a second dialog head between options 2 and 3: wait exits 4 and prints no screen line" '[ $rc = 4 ] && ! grep -q "^screen" <<<"$out"'
states blocked working; run bash "$script" answer T004 --screen 0123456789ab --keys 4
check "DB9 answer with hash 0123456789ab: exit 1, the another-prompt line, nothing sent" '[ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
mk; rm -f "$wr.seen"; states blocked; dbput "${REAL[@]}"
wrun
check "DB10 watch --roster: the screen hash is the block hash, the same as DB1" '[ $rc = 4 ] && [ "$(shash)" = "$bh" ]'
dbwait "${REAL[@]}"
dbans 2
check "DB11 the block hash holds; option 2 (a lasting yes) refused: exit 1, the not-one-time-yes line, nothing sent" '[ "$h" = "$bh" ] && [ $rc = 1 ] && [ "$out" = "Option 2 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
dbans 3
check "DB11 option 3 (a yes that switches mode) refused: exit 1, the not-one-time-yes line, nothing sent" '[ $rc = 1 ] && [ "$out" = "Option 3 is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'
dbans 4
check "DB11 option 4 (No) sent: exit 0, key 4" '[ $rc = 0 ] && hascall "agent\tsend-keys\tworker-t004\t4"'
fake=("${REAL[@]:0:6}" ' ─────' "${REAL[@]:7}")
fh=$(printf '%s\n' "${fake[@]:3:12}" | sha256sum | cut -c1-12)
dbwait "${fake[@]}"; dbput "${fake[@]:0:4}" ' Bash command (unsandboxed)' "${fake[@]:5}"; dbans 1
check "DB12 a description of only ─ after a space is not the top rule: the hash starts at the real rule, a header change refused, nothing sent" '[ "$h" = "$fh" ] && [ $rc = 1 ] && [ "$out" = "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt." ] && [ "$(cnt "^(agent\tsend-keys|pane\tsend-text)\t")" = 0 ]'

drl=$(printf 'outside-owns\tsrc/b.py\tgit add src/b.py && git commit -m x')
drop() { mkdir -p "$1/.stratum/approve"; printf '%s\n' "$2" > "$1/.stratum/approve/dropped"; }
mk; states blocked; drop "$(wt)" "$drl"; run bash "$script" wait T004
check "DR1 blocked worker with a dropped file: exit 4, the dropped line right after the state line, then pane text" '[ $rc = 4 ] && [ "$(sed -n 1p <<<"$out" | cut -f1,2)" = "$(printf "state\tblocked")" ] && [ "$(sed -n 2p <<<"$out")" = "$(printf "dropped\t%s" "$drl")" ] && [ "$(sed -n 3p <<<"$out")" = "pane text:" ]'
mk; states blocked; run bash "$script" wait T004
check "DR2 blocked worker with no dropped file: exit 4, no dropped line, pane text right after the state line" '[ $rc = 4 ] && [ "$(sed -n 2p <<<"$out")" = "pane text:" ] && ! grep -qP "^dropped\t" <<<"$out"'
mk; states blocked; drop "$(wt)" "$(printf 'never-list\t\tgit\033[31m commit')"; run bash "$script" wait T004
check "DR3 an ESC byte in the dropped line: the line prints without it" '[ "$(sed -n 2p <<<"$out")" = "$(printf "dropped\tnever-list\t\tgit[31m commit")" ]'
rfresh; xsetup; STUB_SSH_EXEC=1 rrun bash "$script" start "${rxargs[@]}"
drop "$rw" "$drl"; states blocked; STUB_SSH_EXEC=1 rrun bash "$script" wait T004 --machine laptop
check "DR4 saved machine: exit 4, the dropped line read from the machine, right after the state line" '[ $rc = 4 ] && [ "$(sed -n 2p <<<"$out")" = "$(printf "dropped\t%s" "$drl")" ] && [ "$(sed -n 3p <<<"$out")" = "pane text:" ]'
rto=$(command -v timeout)
printf '%s\n' "$drl" > "$tmp/outside-dropped"
droplink() { mkdir -p "$1/.stratum/approve"; ln -s "$tmp/outside-dropped" "$1/.stratum/approve/dropped"; }
dropfifo() { mkdir -p "$1/.stratum/approve"; mkfifo "$1/.stratum/approve/dropped"; }
nodrop() { [ $rc = 4 ] && [ "$(sed -n 2p <<<"$out")" = "pane text:" ] && ! grep -qP "^dropped\t" <<<"$out"; }
mk; states blocked; droplink "$(wt)"; run bash "$script" wait T004
check "DR5 a symlinked dropped file: exit 4, no dropped line" 'nodrop'
mk; states blocked; dropfifo "$(wt)"; run "$rto" 10 bash "$script" wait T004
check "DR6 a FIFO as the dropped file: no hang, exit 4, no dropped line" 'nodrop'
rxstart() { rfresh; xsetup; STUB_SSH_EXEC=1 rrun bash "$script" start "${rxargs[@]}"; }
rxstart; droplink "$rw"; states blocked; STUB_SSH_EXEC=1 rrun bash "$script" wait T004 --machine laptop
check "DR7 saved machine, a symlinked dropped file: exit 4, no dropped line" 'nodrop'
rxstart; dropfifo "$rw"; states blocked; STUB_SSH_EXEC=1 rrun "$rto" 10 bash "$script" wait T004 --machine laptop
check "DR8 saved machine, a FIFO as the dropped file: no hang, exit 4, no dropped line" 'nodrop'
rxstart; drop "$rw" "$drl"; states blocked; STUB_SSH_EXEC=1 STUB_SSH_RC=255 STUB_SSH_ON=approve/dropped rrun bash "$script" wait T004 --machine laptop
check "DR9 saved machine, ssh fails at the dropped read: still the blocked report, exit 4, no dropped line" 'nodrop'

su="$repo/.stratum/worker-setup.sh"
printf '%s\n' 'printf "%s\n%s\n" "$PWD" "$1" > setup.ran' 'echo setup >> "$STUB_T/order"' 'echo SETUP RAN' > "$su"
fresh; run bash "$script" start "${sargs[@]}"
check "SU1 setup script: exit 0, its output after the header" '[ $rc = 0 ] && hasline "setup output:" && hasline "SETUP RAN"'
check "SU1 it runs in the new worktree with the main checkout as its argument" '[ "$(cat "$(wt)/setup.ran")" = "$(printf "%s\n%s" "$(wt)" "$repo")" ]'
check "SU1 it runs after worktree add and before agent start" 'o1=$(grep -n "^worktree add$" "$tmp/order" | cut -d: -f1) && o2=$(grep -n "^setup$" "$tmp/order" | cut -d: -f1) && o3=$(grep -n "^agent start$" "$tmp/order" | cut -d: -f1) && [ "$o1" -lt "$o2" ] && [ "$o2" -lt "$o3" ]'
printf '%s\n' 'echo boom' 'exit 3' > "$su"
fresh; run bash "$script" start "${sargs[@]}"
check "SU2 setup fails: exit 1, its output, the stopped line, the worker line, no agent start" '[ $rc = 1 ] && hasline boom && hasline "stopped: worker-setup.sh exited 3" && hasline "worker\tworker-t004\tlocal\t%s\t%s\tworker-t004\t%s" "$(tabid)" "$(pane)" "$(wt)" && [ "$(cnt "^agent\tstart\t")" = 0 ]'
printf '%s\n' 'echo REMOTE SETUP "$1"' > "$su"
rfresh; xsetup; mkdir -p "$rrepo/.stratum"; cp "$su" "$rrepo/.stratum/worker-setup.sh"
STUB_SSH_EXEC=1 rrun bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop --repo "$rrepo"
check "SU3 saved machine: the machine's setup script runs with its main checkout, in the brief ssh call, after the worktree add ssh" '[ $rc = 0 ] && hasline "setup output:" && hasline "REMOTE SETUP $rrepo" && [ "$(grep -c . "$tmp/ssh")" = 2 ] && grep -q "worktree add" <(sed -n 1p "$tmp/ssh")'
rfresh; xsetup; printf '%s\n' 'echo rboom' 'exit 3' > "$rrepo/.stratum/worker-setup.sh"
STUB_SSH_EXEC=1 rrun bash "$script" start T004 --task "$task" --test "$testcmd" --lane "$lane" --roster "$rroster" --machine laptop --repo "$rrepo"
check "SU5 saved machine setup fails: exit 1, its output, the stopped line, no agent start" '[ $rc = 1 ] && hasline rboom && hasline "stopped: worker-setup.sh exited 3 on laptop" && [ "$(rcnt "agent\tstart\t")" = 0 ]'
rm -f "$su"
fresh; run bash "$script" start "${sargs[@]}"
check "SU4 no setup script: no setup output" '[ $rc = 0 ] && ! grep -q "setup output" <<<"$out"'

round="$tmp/round.md"
printf 'Fix the null check in src/a.py.\nOwns: `src/b.py`.\n' > "$round"
fuP="/goal \`$testcmd\` exits 0, the change is committed on branch worker-t004, and result.md is written; read brief.md in this folder first and follow it"
mk; states done working; printf 'ROUND1 RESULT\n' > "$lw/result.md"; cp "$lw/brief.md" "$tmp/brief.before"
run bash "$script" followup T004 --task "$round" --test "$testcmd"
check "FU1 exit 0, round 2 line, state working" '[ $rc = 0 ] && hasline "round\tworker-t004\t2" && hasline "state\tworking\tworker-t004\t%s" "$(pane)"'
check "FU1 brief starts with the round 2 text, then the old brief" '[ "$(head -n 1 "$lw/brief.md")" = "## Round 2" ] && grep -qxF "Fix the null check in src/a.py." "$lw/brief.md" && [ "$(tail -n "$(wc -l < "$tmp/brief.before")" "$lw/brief.md")" = "$(cat "$tmp/brief.before")" ]'
check "FU1 result.md moved to result-round1.md" '[ ! -e "$lw/result.md" ] && [ "$(cat "$lw/result-round1.md")" = "ROUND1 RESULT" ]'
check "FU1 one /goal prompt" 'hascall "agent\tprompt\tworker-t004\t%s\t--wait\t--until\tworking\t--until\tblocked\t--timeout\t30000" "$fuP" && never 0 1'
states done working; printf 'ROUND2 RESULT\n' > "$lw/result.md"; reset
run bash "$script" followup T004 --task "$round" --test "$testcmd"
check "FU2 a second followup is round 3, result-round2.md" '[ $rc = 0 ] && hasline "round\tworker-t004\t3" && [ "$(head -n 1 "$lw/brief.md")" = "## Round 3" ] && [ "$(cat "$lw/result-round2.md")" = "ROUND2 RESULT" ] && [ "$(cat "$lw/result-round1.md")" = "ROUND1 RESULT" ]'
mk; states working; printf 'R\n' > "$lw/result.md"; cp "$lw/brief.md" "$tmp/brief.before"
run bash "$script" followup T004 --task "$round" --test "$testcmd"
check "FU3 working worker: exit 1, refused, brief and result unchanged, no prompt" '[ $rc = 1 ] && [ "$out" = "Worker worker-t004 is working, not finished. Followup refused." ] && cmp -s "$lw/brief.md" "$tmp/brief.before" && [ -e "$lw/result.md" ] && never 0 0'
mk; states done
run bash "$script" followup T004 --task "$round" --test "$testcmd"
check "FU4 no result.md: exit 1, refused, no prompt" '[ $rc = 1 ] && [ "$out" = "Worker worker-t004 has no result.md, not finished. Followup refused." ] && never 0 0'
mk; states done; printf 'R\n' > "$lw/result.md"; dialogpane > "$tmp/pane.txt"
run bash "$script" followup T004 --task "$round" --test "$testcmd"
check "FU5 open question: exit 1, refused, result kept" '[ $rc = 1 ] && [ "$out" = "Worker worker-t004 has an open question. Answer it first." ] && [ -e "$lw/result.md" ] && never 0 0'
mk; states done working; printf 'R\n' > "$lw/result.md"; apd; printf '%s\n' "$sid" > "$lw/.stratum/approve/session"; printf 'src/a.py\n' > "$lw/.stratum/approve/owns"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" followup T004 --task "$round" --test "$testcmd"
check "FU6 autonomous worker: the round Owns paths are added" '[ $rc = 0 ] && [ "$(cat "$lw/.stratum/approve/owns")" = "$(printf "src/a.py\nsrc/b.py")" ]'
mk; states done; printf 'R\n' > "$lw/result.md"; apd; printf 'other\n' > "$lw/.stratum/approve/session"; printf 'src/a.py\n' > "$lw/.stratum/approve/owns"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" followup T004 --task "$round" --test "$testcmd"
check "FU7 another session's run: exit 1, refused, owns and result unchanged" '[ $rc = 1 ] && [ "$out" = "Worker worker-t004 is not in this autonomous run." ] && [ "$(cat "$lw/.stratum/approve/owns")" = src/a.py ] && [ -e "$lw/result.md" ] && never 0 0'
mk; states done; printf 'R\n' > "$lw/result.md"; apd; printf '%s\n' "$sid" > "$lw/.stratum/approve/session"; printf 'Fix it.\nOwns: `src/*.py`.\n' > "$tmp/round-bad.md"
CLAUDE_CODE_SESSION_ID="$sid" run bash "$script" followup T004 --task "$tmp/round-bad.md" --test "$testcmd"
check "FU8 a bad round Owns path: exit 1, the line, result kept" '[ $rc = 1 ] && [ "$out" = "Owns path src/*.py must be repo-relative, with no glob." ] && [ -e "$lw/result.md" ] && never 0 0'
rfresh; xsetup; STUB_SSH_EXEC=1 rrun bash "$script" start "${rxargs[@]}"
states done working; printf 'REMOTE R1\n' > "$rw/result.md"; reset
STUB_SSH_EXEC=1 rrun bash "$script" followup T004 --task "$round" --test "$testcmd" --machine laptop
check "FU9 saved machine: exit 0, the brief and result change on the machine, prompt on the machine" '[ $rc = 0 ] && [ "$(head -n 1 "$rw/brief.md")" = "## Round 2" ] && [ "$(cat "$rw/result-round1.md")" = "REMOTE R1" ] && [ ! -e "$rw/result.md" ] && [ "$(rcnt "agent\tprompt\t")" = 1 ]'

fresh; run bash "$script" start "${sargs[@]}"
check "LY1 exit 0" '[ $rc = 0 ]'
check "LY1 layout calls in order: tab create, pane split, pane run, agent start" '[ "$(grep -P "^(tab\tcreate\t|pane\tsplit\t|pane\trun\t|agent\tstart\t)" "$tmp/calls" | cut -f1-2)" = "$(printf "tab\tcreate\npane\tsplit\npane\trun\nagent\tstart")" ]'
check "LY1 one tab create, in the orchestrator workspace" '[ "$(cnt "^tab\tcreate\t")" = 1 ] && hascall "tab\tcreate\t--workspace\tw1P\t--cwd\t%s\t--label\tworker-t004\t--no-focus" "$(wt)"'
check "LY1 split the root pane right, no focus" 'hascall "pane\tsplit\t%s\t--direction\tright\t--cwd\t%s\t--no-focus" "$(pane)" "$(wt)"'
check "LY1 lazygit in the new pane" 'hascall "pane\trun\t%s\tlazygit" "$(lazypane)"'
check "LY1 no tab rename, no Dev Servers or VM tab" '[ "$(cnt "^tab\trename\t")" = 0 ] && ! grep -qP "Dev Servers|\tVM(\t|\$)" "$tmp/calls"'

rfresh; rrun bash "$script" start "${rsargs[@]}"
check "LY2 exit 0" '[ $rc = 0 ]'
check "LY2 layout calls on the machine, in order" '[ "$(grep -P "^--machine\tlaptop\t(tab\tcreate\t|pane\tsplit\t|pane\trun\t|agent\tstart\t)" "$tmp/calls" | cut -f3-4)" = "$(printf "tab\tcreate\npane\tsplit\npane\trun\nagent\tstart")" ]'
check "LY2 tab create in the main checkout workspace, on the machine" 'rcall "tab\tcreate\t--workspace\tstubMainWS\t--cwd\t%s\t--label\tworker-t004\t--no-focus" "/stubhome/proj-worker-t004"'
check "LY2 split the root pane right, no focus, on the machine" 'rcall "pane\tsplit\t%s\t--direction\tright\t--cwd\t%s\t--no-focus" "$(pane)" "$(wt)"'
check "LY2 lazygit in the new pane, on the machine" 'rcall "pane\trun\t%s\tlazygit" "$(lazypane)"'
check "LY2 no tab rename, no Dev Servers or VM, on the machine" '[ "$(rcnt "tab\trename\t")" = 0 ] && ! grep -qP "Dev Servers|\tVM(\t|\$)" "$tmp/calls"'

exit $fail
