#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/scripts/st-herdr-workspace.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
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
[ "$1" = --machine ] && shift 2
if [ "${STUB_FAIL:-}" = "$1 $2" ]; then
  echo '{"error":{"code":"stub","message":"stub refused"}}' >&2
  exit 1
fi
next() { local n; n=$(cat "$T/n_$1" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n_$1"; echo $n; }
emit() { printf '%s\n' "$1" | tee -a "$T/resp"; }
case "$1 $2" in
"machine list")
  printf '%s\n' '[{"id":"stubid0001","label":"laptop","target":"u@stubhost","session":"default","enabled":true,"selected":false}]' ;;
"workspace list")
  if [ -n "${STUB_DOWN:-}" ]; then echo 'Error: stub machine down' >&2; exit 1; fi
  emit '{"result":{}}' ;;
"workspace create")
  next t > /dev/null; next p > /dev/null
  echo "stubW:p1$X stubW:t1$X" > "$T/panes"
  emit "{\"result\":{\"workspace\":{\"workspace_id\":\"stubW\"},\"tab\":{\"tab_id\":\"stubW:t1$X\"},\"root_pane\":{\"pane_id\":\"stubW:p1$X\"}}}" ;;
"tab create")
  t=stubW:t$(next t)$X; p=stubW:p$(next p)$X
  echo "$p $t" >> "$T/panes"
  emit "{\"result\":{\"tab\":{\"tab_id\":\"$t\"},\"root_pane\":{\"pane_id\":\"$p\"}}}" ;;
"pane split")
  p=stubW:p$(next p)$X; t=$(awk -v id="$3" '$1==id{print $2}' "$T/panes")
  echo "$p $t" >> "$T/panes"
  emit "{\"result\":{\"pane\":{\"pane_id\":\"$p\"}}}" ;;
"pane list")
  emit "$(jq -Rnc --arg c "${STUB_CWD:-}" '{result:{panes:[inputs|split(" ")|{pane_id:.[0],tab_id:.[1],cwd:$c}]}}' "$T/panes")" ;;
"pane process-info")
  prog=$(awk -F'\t' -v id="$4" '{o=($1=="--machine")?2:0; if($(o+1)=="pane"&&$(o+2)=="run"&&$(o+3)==id)p=$(o+4)} END{print p}' "$T/calls")
  case "$prog" in claude|claude2) n=claude ;; lazygit) n=lazygit ;; *) n=zsh ;; esac
  [ -n "${STUB_NOTSEEN:-}" ] && n=zsh
  echo "{\"result\":{\"process_info\":{\"pane_id\":\"$4\",\"foreground_processes\":[{\"name\":\"$n\"}]}}}" ;;
*) emit '{"result":{}}' ;;
esac
EOF
cat > "$tmp/bin/ssh" <<'EOF'
#!/usr/bin/env bash
( IFS=$'\t'; printf '%s\n' "$*" >> "$STUB_T/ssh" )
if [ -n "${STUB_SSH_RC:-}" ]; then echo 'ssh: stub failure' >&2; exit "$STUB_SSH_RC"; fi
[ -z "${STUB_SSH_OUT:-}" ] || echo 'hello from zshrc'
printf '%s\n' '/home/u/proj x' '# branch.oid 0123' '# branch.head main' '# branch.upstream origin/main' '# branch.ab +3 -2'
EOF
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/sleep"
chmod +x "$tmp/bin/herdr" "$tmp/bin/sleep" "$tmp/bin/ssh"
export STUB_T="$tmp"

found=$(PATH="$tmp/bin:$PATH" command -v herdr)
if [ "$found" != "$tmp/bin/herdr" ]; then echo "FAIL stub herdr is first on PATH: found $found"; exit 1; fi
found=$(PATH="$tmp/bin:$PATH" command -v ssh)
if [ "$found" != "$tmp/bin/ssh" ]; then echo "FAIL stub ssh is first on PATH: found $found"; exit 1; fi
found=$(PATH="$tmp/bin:$PATH" command -v sleep)
if [ "$found" != "$tmp/bin/sleep" ]; then echo "FAIL stub sleep is first on PATH: found $found"; exit 1; fi

run() {
  : > "$tmp/calls"; : > "$tmp/resp"; : > "$tmp/ssh"; rm -f "$tmp"/n_* "$tmp/panes"
  printf 'x%04x\n' $RANDOM > "$tmp/x"
  out=$(PATH="$tmp/bin:$PATH" HERDR_PANE_ID=w1P:p1 HERDR_TAB_ID=w1P:t1 HERDR_WORKSPACE_ID=w1P "$@" 2>&1); rc=$?
}
norm() { sed -E 's/^--machine\t[^\t]*\t//' "$tmp/calls"; }
cnt() { norm | grep -cP "$1"; }
cwdbad() { awk -F'\t' -v d="$1" '{ok=0;for(i=1;i<NF;i++)if($i=="--cwd"&&$(i+1)==d)ok=1;if(!ok)bad=1}END{exit !bad}'; }
ids() { norm | awk -F'\t' '{for(i=1;i<NF;i++)if($i~/^(rename|split|run|focus|--workspace|--pane)$/)print $(i+1)}'; }
idsresp() { local id; for id in $(ids); do grep -qF "\"$id\"" "$tmp/resp" || return 1; done; }
forbid() { norm | awk -F'\t' '$2=="close"||($1=="machine"&&$2~/^(reconnect|add|remove|enable|disable)$/)||$1=="server"{bad=1}END{exit bad}'; }
focusok() { norm | awk -F'\t' '$1=="workspace"&&$2=="focus"{f++;next} f&&(($1=="workspace"&&$2=="create")||($1=="tab"&&($2=="create"||$2=="rename"))||($1=="pane"&&($2=="split"||$2=="run"))){bad=1} END{exit !(f==1)||bad}'; }
pid() { awk -v n="$1" 'NR==n{print $1}' "$tmp/panes"; }
tid() { awk -v n="$1" 'NR==n{print $2}' "$tmp/panes"; }
piok() { norm | awk -F'\t' -v a="$(pid 1)" -v b="$(pid 2)" '$1=="workspace"&&$2=="focus"{f=NR} $1=="pane"&&$2=="process-info"{c[$4]++; if(!f)bad=1; if($3!="--pane"||($4!=a&&$4!=b))bad=1} END{for(k in c)if(c[k]>10)bad=1; exit (c[a]<1||c[b]<1||bad)}'; }
machok() { awk -F'\t' -v m="$1" '$0=="machine\tlist\t--json"{next} !($1=="--machine"&&$2==m){bad=1} END{exit bad}' "$tmp/calls"; }
panes_exp() {
  printf 'pane\t%s\t%s\t%s\t%s\t%s\n' "$(pid 1)" "$(tid 1)" "$1" "$2" "$4"
  printf 'pane\t%s\t%s\tlazygit\t%s\t%s\n' "$(pid 2)" "$(tid 2)" "$3" "$4"
  local i; for i in 3 4 5 6; do printf 'pane\t%s\t%s\tshell\t-\t%s\n' "$(pid $i)" "$(tid $i)" "$4"; done
}

calls_ok() {
  local f=$2 m=$3
  check "$1 one workspace create" '[ "$(cnt "^workspace\tcreate\t")" = 1 ]'
  check "$1 workspace create has --cwd folder" '! { norm | grep -P "^workspace\tcreate\t" | cwdbad "$f"; }'
  check "$1 every tab create has --cwd folder" '! { norm | grep -P "^tab\tcreate\t" | cwdbad "$f"; }'
  check "$1 every pane split has --cwd folder" '! { norm | grep -P "^pane\tsplit\t" | cwdbad "$f"; }'
  check "$1 every pane split has --direction right" '! norm | grep -P "^pane\tsplit\t" | grep -qvP "\t--direction\tright(\t|$)"'
  check "$1 one tab rename, T1 to Main" '[ "$(cnt "^tab\trename\t")" = 1 ] && norm | grep -qxF "$(printf "tab\trename\t%s\tMain" "$(tid 1)")"'
  if [ -z "$m" ]; then
    check "$1 no --machine" '! grep -qF -- --machine "$tmp/calls"'
  else
    check "$1 --machine $m on every call but machine list" 'machok "$m"'
  fi
  check "$1 ids are stub ids" '[ -n "$(ids)" ] && ! ids | grep -qv "^stub"'
  check "$1 ids come from a herdr answer" 'idsresp'
  check "$1 no live id, --current, --session, --remote" '! grep -qE -- "w1P|--current|--session|--remote" "$tmp/calls"'
  check "$1 no close, reconnect, machine edit, server" 'forbid'
  check "$1 no bare herdr" '! grep -qx BARE "$tmp/calls"'
  check "$1 focus once, last mutating call" 'focusok'
}

rejects() {
  local name=$1 phrase=$2; shift 2
  run "$@"
  check "$name exit 1" '[ $rc = 1 ]'
  check "$name one line with the phrase" '[ "$(printf "%s\n" "$out" | grep -c .)" = 1 ] && grep -qF -- "$phrase" <<<"$out"'
  check "$name no herdr call" '[ ! -s "$tmp/calls" ]'
}

proj="$tmp/proj dir"
mkdir "$proj"
git -C "$proj" init -q
printf 'x\n' > "$proj/a.txt"
git -C "$proj" add a.txt
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -m first
printf 'y\n' > "$proj/new.txt"
export HERDR_ENV=1

l1() {
  STUB_CWD="$proj" run bash "$1" "$proj" --label 32-herdr-workspace
  check "L1 exit 0" '[ $rc = 0 ]'
  calls_ok L1 "$proj" ""
  check "L1 two tab create, Dev Servers and VM" '[ "$(cnt "^tab\tcreate\t")" = 2 ] && norm | grep -P "^tab\tcreate\t" | grep -qP "\t--label\tDev Servers\t" && norm | grep -P "^tab\tcreate\t" | grep -qP "\t--label\tVM\t"'
  check "L1 three pane split" '[ "$(cnt "^pane\tsplit\t")" = 3 ]'
  check "L1 two pane run, claude on root pane, lazygit on first split" '[ "$(cnt "^pane\trun\t")" = 2 ] && norm | grep -qxF "$(printf "pane\trun\t%s\tclaude" "$(pid 1)")" && norm | grep -qxF "$(printf "pane\trun\t%s\tlazygit" "$(pid 2)")"'
  check "L1 workspace line" 'grep -qxF "$(printf "workspace\tstubW\t32-herdr-workspace\tlocal")" <<<"$out"'
  check "L1 folder line" 'grep -P "^folder\t" <<<"$out" | grep -qP "^folder\t\Q$proj\E\t.*1 changed.*no upstream"'
  check "L1 tab lines" '[ "$(grep -cP "^tab\t" <<<"$out")" = 3 ] && grep -qxF "$(printf "tab\t%s\tMain" "$(tid 1)")" <<<"$out" && grep -qxF "$(printf "tab\t%s\tDev Servers" "$(tid 3)")" <<<"$out" && grep -qxF "$(printf "tab\t%s\tVM" "$(tid 5)")" <<<"$out"'
  check "L1 six pane lines" '[ "$(grep -P "^pane\t" <<<"$out")" = "$(panes_exp claude running running "$proj")" ]'
}
l1 "$script"
nc() {
  local fn=$2
  check "$1 sed changed the script" '[ -f "$script" ] && ! cmp -s "$script" "$tmp/$1.sh"'
  local f=$fail; fail=0; q=1
  local base=0
  "$fn" "$script"; base=$fail; fail=0
  "$fn" "$tmp/$1.sh"
  q=; local red=$fail; fail=$f
  check "$1 real script is green" '[ $base = 0 ]'
  check "$1 goes red" '[ $red = 1 ]'
}
sed -E '/pane split/{s/ --cwd ("[^"]*"|[^ ]+)//;:a;n;ba}' "$script" > "$tmp/NC1.sh" 2>/dev/null
nc NC1 l1
sed -E '/pane split/{s/pane split +("[^"]*"|[^ ]+)/pane split "$HERDR_PANE_ID"/;:a;n;ba}' "$script" > "$tmp/NC3.sh" 2>/dev/null
nc NC3 l1

STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace --agent claude2
check "L2 exit 0" '[ $rc = 0 ]'
check "L2 agent pane run ends claude2" 'norm | grep -qxF "$(printf "pane\trun\t%s\tclaude2" "$(pid 1)")"'
check "L2 report says claude2" 'grep -qP "^pane\t\Q$(pid 1)\E\t\Q$(tid 1)\E\tclaude2\trunning\t" <<<"$out"'

STUB_NOTSEEN=1 STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace
check "L3 exit 0" '[ $rc = 0 ]'
calls_ok L3 "$proj" ""
check "L3 both programs not seen" '[ "$(grep -P "^pane\t" <<<"$out" | head -2)" = "$(panes_exp claude "not seen" "not seen" "$proj" | head -2)" ]'
check "L3 process-info only on the Main panes, 1 to 10 each, after focus" 'piok'

git -C "$proj" -c user.name=t -c user.email=t@t commit -q --allow-empty -m second
git -C "$proj" branch up
git -C "$proj" reset -q --hard HEAD~1
git -C "$proj" branch -q --set-upstream-to=up
STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace
check "L4 exit 0" '[ $rc = 0 ]'
check "L4 behind 1 as of last fetch" 'grep -P "^folder\t" <<<"$out" | grep -qF "behind 1" && grep -P "^folder\t" <<<"$out" | grep -qF "(as of last fetch)"'

plain=$(mktemp -d -p "$tmp")
STUB_CWD="$plain" run bash "$script" "$plain" --label 32-herdr-workspace
check "L5 exit 0" '[ $rc = 0 ]'
check "L5 not a git repo" 'grep -P "^folder\t" <<<"$out" | grep -qF "not a git repo"'

clean="$tmp/clean"
mkdir "$clean"
git -C "$clean" init -q
git -C "$clean" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
br=$(git -C "$clean" branch --show-current)
STUB_CWD="$clean" run bash "$script" "$clean" --label 32-herdr-workspace
check "L17 exit 0" '[ $rc = 0 ]'
check "L17 folder line says branch, clean, no upstream" 'grep -qxF "$(printf "folder\t%s\t%s, clean, no upstream" "$clean" "$br")" <<<"$out"'

STUB_CWD="$proj" run bash "$script" "$proj/../proj dir" --label 32-herdr-workspace
check "L18 exit 0" '[ $rc = 0 ]'
calls_ok L18 "$proj" ""
check "L18 folder line shows the normalized folder" 'grep -qP "^folder\t\Q$proj\E\t" <<<"$out"'

HOME="$tmp" STUB_CWD="$proj" run bash "$script" "~/proj dir" --label 32-herdr-workspace
check "L19 exit 0" '[ $rc = 0 ]'
calls_ok L19 "$proj" ""

rejects L6 "Folder not found on local:" bash "$script" /no/such/dir --label x
rejects L7 "Agent must be claude or claude2." bash "$script" "$proj" --label x --agent codex
rejects L8 "Template must be full or basic." bash "$script" "$proj" --label x --template big
rejects L9 "Label is required: --label <issue-or-name>." bash "$script" "$proj"
rejects L10 "Label must be letters, digits, dot, dash or underscore" bash "$script" "$proj" --label -x
unset HERDR_ENV
rejects L11 "Not inside a herdr pane." bash "$script" "$proj" --label x
export HERDR_ENV=1

STUB_FAIL="tab create" STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace
check "L12 exit 1" '[ $rc = 1 ]'
check "L12 first line is stopped with the stub message" 'head -1 <<<"$out" | grep -q "^stopped: .*stub refused"'
check "L12 report so far" 'grep -qP "^workspace\t" <<<"$out" && grep -qxF "$(printf "tab\t%s\tMain" "$(tid 1)")" <<<"$out" && [ "$(grep -cP "^pane\t.*\t\Q$proj\E$" <<<"$out")" = 2 ] && [ "$(grep -cP "^pane\t" <<<"$out")" = 2 ]'
check "L12 one tab create, no focus, no close" '[ "$(cnt "^tab\tcreate\t")" = 1 ] && [ "$(cnt "^workspace\tfocus\t")" = 0 ] && forbid'

STUB_FAIL="pane run" STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace
check "L20 exit 1" '[ $rc = 1 ]'
check "L20 report has tab Main and P1, P2 as shell -" 'grep -qxF "$(printf "tab\t%s\tMain" "$(tid 1)")" <<<"$out" && [ "$(grep -P "^pane\t" <<<"$out")" = "$(printf "pane\t%s\t%s\tshell\t-\t%s\n" "$(pid 1)" "$(tid 1)" "$proj" "$(pid 2)" "$(tid 2)" "$proj")" ]'
check "L20 stops at the first pane run" '[ "$(cnt "^pane\trun\t")" = 1 ] && ! norm | grep -qP "^pane\trun\t.*\tlazygit$"'

run bash "$script" "$proj" --label x --bogus
check "L13 --bogus exits 2" '[ $rc = 2 ]'

STUB_CWD=/stub/elsewhere run bash "$script" "$proj" --label 32-herdr-workspace
check "L14 exit 0" '[ $rc = 0 ]'
check "L14 cwd column comes from the read back" '[ "$(grep -P "^pane\t" <<<"$out")" = "$(panes_exp claude running running /stub/elsewhere)" ]'

STUB_FAIL="pane list" STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace
check "L15 exit 0" '[ $rc = 0 ]'
check "L15 cwd is ? in every pane line" '[ "$(grep -P "^pane\t" <<<"$out")" = "$(panes_exp claude running running "?")" ]'

STUB_FAIL="pane process-info" STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace
check "L16 exit 0" '[ $rc = 0 ]'
check "L16 not seen for P1 and P2" '[ "$(grep -P "^pane\t" <<<"$out")" = "$(panes_exp claude "not seen" "not seen" "$proj")" ]'
check "L16 workspace focus present" '[ "$(cnt "^workspace\tfocus\t")" = 1 ]'

rem() {
  local n=$1 m=$3
  unset HERDR_ENV
  STUB_CWD='/home/u/proj x' run bash "$2" '~/proj x' --label 32-herdr-workspace --machine "$m"
  export HERDR_ENV=1
  check "$n exit 0" '[ $rc = 0 ]'
  calls_ok "$n" '/home/u/proj x' "$m"
  check "$n one ssh line to the saved target" '[ "$(grep -c . "$tmp/ssh")" = 1 ] && grep -qP "^-o\tBatchMode=yes\t--\tu@stubhost\t" "$tmp/ssh"'
  check "$n ssh command has ~ unescaped" 'awk -F"\t" "{print \$NF}" "$tmp/ssh" | grep -qF -- "cd -- ~/proj\\ x"'
  check "$n workspace line ends with $m" 'grep -qxF "$(printf "workspace\tstubW\t32-herdr-workspace\t%s" "$m")" <<<"$out"'
  check "$n folder line has ahead 3, behind 2" 'grep -P "^folder\t" <<<"$out" | grep -qF "ahead 3, behind 2"'
}
r1() { rem R1 "$1" laptop; }

rrej() {
  local n=$1 phrase=$2 nssh=$3; shift 3
  unset HERDR_ENV
  run bash "$script" "$@" --label 32-herdr-workspace
  export HERDR_ENV=1
  check "$n exit 1" '[ $rc = 1 ]'
  check "$n one line with the phrase" '[ "$(printf "%s\n" "$out" | grep -c .)" = 1 ] && grep -qF -- "$phrase" <<<"$out"'
  check "$n no mutating call" '! norm | grep -qP "^(workspace\t(create|focus)|tab\t(create|rename)|pane\t(split|run))\t"'
  check "$n ssh lines: $nssh" '[ "$(grep -c . "$tmp/ssh")" = $nssh ]'
}

r1 "$script"
rem R2 "$script" stubid0001
rrej R3 "Unknown machine: nosuch. Saved: laptop." 0 '~/proj x' --machine nosuch
STUB_DOWN=1 rrej R4 "Machine laptop does not answer: Error: stub machine down" 0 '~/proj x' --machine laptop
STUB_SSH_RC=1 rrej R5 "Folder not found on laptop: ~/proj x" 1 '~/proj x' --machine laptop
STUB_SSH_RC=255 rrej R6 "ssh to u@stubhost failed: ssh: stub failure" 1 '~/proj x' --machine laptop
rrej R7 "A remote folder must start with / or ~." 0 proj --machine laptop
STUB_SSH_OUT=1 rrej R8 "Folder not found on laptop: ~/proj x" 1 '~/proj x' --machine laptop

unset HERDR_ENV
STUB_CWD='/home/u/proj x' run bash "$script" '/home/u/proj x' --label 32-herdr-workspace --machine laptop
export HERDR_ENV=1
check "R9 exit 0" '[ $rc = 0 ]'
calls_ok R9 '/home/u/proj x' laptop
check "R9 ssh command has the absolute folder quoted" 'awk -F"\t" "{print \$NF}" "$tmp/ssh" | grep -qF -- "cd -- /home/u/proj\\ x"'

sed -E '/H\+=\(--machine/d' "$script" > "$tmp/NC2.sh" 2>/dev/null
nc NC2 r1
sed -E '/^Q=\$\{Q\/#/d' "$script" > "$tmp/NC4.sh" 2>/dev/null
nc NC4 r1

bchk() {
  local n=$1 f=$2 m=$3
  check "$n exit 0" '[ $rc = 0 ]'
  calls_ok "$n" "$f" "$m"
  check "$n one pane split" '[ "$(cnt "^pane\tsplit\t")" = 1 ]'
  check "$n workspace line" 'grep -qxF "$(printf "workspace\tstubW\t32-herdr-workspace\t%s" "${m:-local}")" <<<"$out"'
  check "$n folder line" 'grep -qP "^folder\t\Q$f\E\t" <<<"$out"'
  check "$n no tab create, pane run, pane process-info" '[ "$(cnt "^tab\tcreate\t")" = 0 ] && [ "$(cnt "^pane\trun\t")" = 0 ] && [ "$(cnt "^pane\tprocess-info\t")" = 0 ]'
  check "$n one tab line, T1 Main" '[ "$(grep -cP "^tab\t" <<<"$out")" = 1 ] && grep -qxF "$(printf "tab\t%s\tMain" "$(tid 1)")" <<<"$out"'
  check "$n two shell pane lines" '[ "$(grep -cP "^pane\t" <<<"$out")" = 2 ] && [ "$(grep -P "^pane\t" <<<"$out")" = "$(printf "pane\t%s\t%s\tshell\t-\t%s\npane\t%s\t%s\tshell\t-\t%s" "$(pid 1)" "$(tid 1)" "$f" "$(pid 2)" "$(tid 2)" "$f")" ]'
}
STUB_CWD="$proj" run bash "$script" "$proj" --label 32-herdr-workspace --template basic
bchk B1 "$proj" ""
unset HERDR_ENV
STUB_CWD='/home/u/proj x' run bash "$script" '~/proj x' --label 32-herdr-workspace --template basic --machine laptop
export HERDR_ENV=1
bchk B2 '/home/u/proj x' laptop

exit $fail
