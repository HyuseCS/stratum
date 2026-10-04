#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

mkdir -p "$tmp/bin" "$tmp/home/proj/.stratum" "$tmp/home/.claude"
cat > "$tmp/bin/bunx" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
cp "${2#--config=}" "$(dirname "$0")/../seen-config.json"
printf '\e[0m\e[48;2;25;23;36m\e[38;2;235;188;186m ✱ Opus 5.5 \e[0m\e[48;2;38;35;58m\e[38;2;25;23;36m\e[48;2;38;35;58m\e[38;2;196;167;231m ~/Desktop/stratum \e[0m\e[48;2;31;29;46m\e[38;2;38;35;58m\e[48;2;31;29;46m\e[38;2;156;207;216m ⎇ main ● \e[0m\e[48;2;82;79;103m\e[38;2;31;29;46m\e[48;2;82;79;103m\e[38;2;224;222;244m ⧖ 12m \e[0m\e[38;2;82;79;103m\e[0m\n'
SH
chmod +x "$tmp/bin/bunx"
echo deny > "$tmp/home/proj/.stratum/commit-mode"
echo full > "$tmp/home/.claude/.ponytail-active"
input="{\"workspace\":{\"current_dir\":\"$tmp/home/proj\"}}"

run() { printf '%s' "$input" | PATH="$tmp/bin:$PATH" HOME="$tmp/home" CLAUDE_CONFIG_DIR= COLUMNS="$1" bash "$root/statusline/st-statusline.sh"; }
plain() { sed $'s/\e\\[[0-9;]*m//g'; }
cols() { python3 -c 'import sys; print(len(sys.stdin.read().rstrip("\n")))'; }

wide=$(run 200 | plain)
l1=$(sed -n 1p <<<"$wide"); l2=$(sed -n 2p <<<"$wide")
check "wide: two lines" '[ "$(wc -l <<<"$wide")" = 2 ]'
check "line 1: Stratum, folder path, branch, time in order" '[[ "$l1" == " Stratum "*" ~/proj "*"⎇ main"*"⧖ 12m"* ]]'
check "line 2: model, ponytail, commit in order" '[[ "$l2" == " ✱ Opus 5.5 "*" ponytail full "*" commit deny "* ]]'
check "width 37: path shortened to folder name, time kept" 'out=$(run 37 | plain); grep -q " proj " <<<"$out" && ! grep -q "~/proj" <<<"$out" && grep -q "12m" <<<"$out"'
check "no SR-OPUS-5" '! grep -q "SR" <<<"$wide"'
for w in 40 30 20; do
  out=$(run $w | plain)
  check "width $w: every line fits" '[ "$(while read -r l; do cols <<<"$l"; done <<<"$out" | sort -n | tail -1)" -lt '$w' ]'
  check "width $w: branch and commit mode kept" 'grep -q "main" <<<"$out" && grep -q "deny" <<<"$out"'
done
check "width 30: time dropped first" '! grep -q "12m" <<<"$(run 30 | plain)" && grep -q "Stratum" <<<"$(run 30 | plain)"'
mkdir -p "$tmp/nobunx"
for c in bash python3 cat stty cut dirname ps tr; do ln -s "$(command -v $c)" "$tmp/nobunx/$c"; done
nob=$(printf '%s' "$input" | PATH="$tmp/nobunx" HOME="$tmp/home" CLAUDE_CONFIG_DIR= COLUMNS=80 "$tmp/nobunx/bash" "$root/statusline/st-statusline.sh" | plain)
check "no bunx: own segments only" 'grep -q "Stratum" <<<"$nob" && grep -q " ~/proj " <<<"$nob" && grep -q "ponytail full" <<<"$nob" && grep -q "commit deny" <<<"$nob" && ! grep -q "Opus" <<<"$nob"'

rgb() { python3 -c 'import sys; h=sys.argv[1].lstrip("#"); print(";".join(str(int(h[i:i+2],16)) for i in (0,2,4)))' "$1"; }
check "default: rose-pine commit-deny color" 'run 200 | grep -qF "38;2;$(rgb eb6f92)m commit deny"'
echo '{"theme":"nord"}' > "$tmp/home/proj/.stratum/powerline.json"
check "project theme nord: commit-deny color" 'run 200 | grep -qF "38;2;$(rgb bf616a)m commit deny"'
check "project config merged over plugin config" 'python3 -c "import json,sys; c=json.load(open(sys.argv[1])); assert c[\"theme\"]==\"nord\" and c[\"display\"][\"colorCompatibility\"]==\"truecolor\" and c[\"display\"][\"lines\"][0][\"segments\"][\"model\"][\"enabled\"]" "$tmp/seen-config.json"'
echo '{"theme":"custom","colors":{"custom":{"git":{"bg":"#112233","fg":"#ffffff"},"commit":{"deny":"#abcdef"}}}}' > "$tmp/home/proj/.stratum/powerline.json"
check "custom: own key used" 'run 200 | grep -qF "38;2;$(rgb abcdef)m commit deny"'
check "custom: git bg used for commit" 'run 200 | grep -qF "48;2;$(rgb 112233)m"$'"'"'\e'"'"'"[38;2;$(rgb abcdef)m commit deny"'
check "custom: missing keys filled from rose-pine" 'python3 -c "import json,sys; c=json.load(open(sys.argv[1]))[\"colors\"][\"custom\"]; assert c[\"git\"][\"bg\"]==\"#112233\" and c[\"model\"][\"bg\"]==\"#191724\"" "$tmp/seen-config.json"'
rm "$tmp/home/proj/.stratum/powerline.json"

exit $fail
