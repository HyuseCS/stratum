#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
sw="$root/scripts/st-shell-writes.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

bash_line() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",id:"t1",name:"Bash",input:{command:$c}}]}}'; }
write_line() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",id:"t2",name:"Write",input:{file_path:"/tmp/x",content:$c}}]}}'; }
user_line() { jq -nc --arg c "$1" '{type:"user",message:{content:$c}}'; }
blob_line() { jq -nc --arg c "$1" '{type:"api-request-blob",message:{content:[{type:"tool_use",id:"t3",name:"Bash",input:{command:$c}}]}}'; }

hits() {
  local n=$1 cmd=$2
  bash_line "$cmd" > "$T/$n.jsonl"
  out=$(bash "$sw" "$T/$n.jsonl" 2>&1); rc=$?
  check "$n exit 1" "[ $rc = 1 ]"
  check "$n prints the command" "printf '%s' \"\$out\" | grep -qF -- \"\$cmd\""
}
clean() {
  local n=$1; shift
  "$@" > "$T/$n.jsonl"
  out=$(bash "$sw" "$T/$n.jsonl" 2>&1); rc=$?
  check "$n exit 0" "[ $rc = 0 ]"
  check "$n prints nothing" "[ -z \"\$out\" ]"
}

hits heredoc $'python3 - <<EOF\nprint(1)\nEOF'
hits cat-redirect 'cat > f.txt'
hits tee 'echo hi | tee f.txt'
hits sed-i "sed -i 's/a/b/' f.txt"
hits echo-redirect 'echo x > f.txt'
hits printf-append "printf 'x' >> f.txt"
hits cat-copy 'cat a.txt > b.txt'
hits cat-append 'cat a b >> c'
hits sed-Ei "sed -Ei 's/a/b/' f.txt"
hits sed-in-place "sed --in-place 's/a/b/' f.txt"

clean write-call write_line $'cat > f <<EOF\nx\nEOF'
clean bash-cat bash_line 'cat f'
clean echo-stderr bash_line 'echo x >&2'
clean here-string bash_line 'cat <<< "hello"'
clean user-message user_line $'cat > f <<EOF\nx\nEOF'
clean blob-line blob_line $'cat > f <<EOF\nx\nEOF'
clean grep-tee bash_line "grep -n 'tee' scripts/st-advisor.sh"
clean cat-null bash_line 'cat f 2>/dev/null'

{ bash_line 'echo x > f'; bash_line 'cat f'; } > "$T/resent.jsonl"
out=$(bash "$sw" <(tail -n +2 "$T/resent.jsonl") 2>&1); rc=$?
check "new lines only after a send-back: exit 0" "[ $rc = 0 ] && [ -z \"\$out\" ]"

{ bash_line 'cat f'; bash_line 'echo x > f'; } > "$T/mixed.jsonl"
out=$(bash "$sw" "$T/mixed.jsonl" 2>&1); rc=$?
check "mixed exit 1" "[ $rc = 1 ]"
check "mixed prints only the write" "printf '%s' \"\$out\" | grep -qF 'echo x > f' && ! printf '%s' \"\$out\" | grep -qxF 'cat f'"

{ blob_line $'cat > f <<EOF\nx\nEOF'; bash_line $'cat > f <<EOF\nx\nEOF'; } > "$T/dup.jsonl"
out=$(bash "$sw" "$T/dup.jsonl" 2>&1); rc=$?
check "blob duplicate counts once" "[ $rc = 1 ] && [ \$(printf '%s\n' \"\$out\" | grep -c 'cat > f') = 1 ]"

out=$(bash "$sw" "$T/missing.jsonl" 2>&1); rc=$?
check "missing file exit 2" "[ $rc = 2 ]"

exit $fail
