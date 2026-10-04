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
check "line 1: Stratum, path, time left; branch right" '[[ "$l1" == " 󰌨 Stratum "*" ~/proj "*"⧖ 12m "*" ⎇ main ● " ]]'
check "line 2: model, ponytail left; commit right" '[[ "$l2" == " ✱ Opus 5.5 "*" Ponytail "*" commit: deny " ]]'
check "width 100: right side ends at the edge" '[ "$(run 100 | plain | head -1 | cols)" = 92 ] && [ "$(run 100 | plain | sed -n 2p | cols)" = 92 ]'
check "width 48: path shortened to folder name, time kept" 'out=$(run 48 | plain); grep -q " proj " <<<"$out" && ! grep -q "~/proj" <<<"$out" && grep -q "12m" <<<"$out"'
check "ponytail off: level shown" 'echo off > "$tmp/home/.claude/.ponytail-active"; out=$(run 200 | plain); echo full > "$tmp/home/.claude/.ponytail-active"; grep -q "Ponytail off" <<<"$out"'
runi() { printf '%s' "$2" | PATH="$tmp/bin:$PATH" HOME="$tmp/home" CLAUDE_CONFIG_DIR= COLUMNS="$1" bash "$root/statusline/st-statusline.sh"; }
ws="\"workspace\":{\"current_dir\":\"$tmp/home/proj\"}"
check "thinking level in the model segment" '[[ "$(runi 200 "{$ws,\"effort\":{\"level\":\"xhigh\"},\"thinking\":{\"enabled\":true}}" | plain | sed -n 2p)" == " ✱ Opus 5.5 xhigh "*" Ponytail "* ]]'
check "thinking off" 'runi 200 "{$ws,\"effort\":{\"level\":\"high\"},\"thinking\":{\"enabled\":false}}" | plain | grep -q " ✱ Opus 5.5 off "'
check "no thinking data: model alone" 'grep -q " ✱ Opus 5.5 " <<<"$wide" && ! grep -qE "Opus 5.5 (off|on|high)" <<<"$wide"'
check "no SR-OPUS-5" '! grep -q "SR" <<<"$wide"'
for w in 40 30 20; do
  out=$(run $w | plain)
  check "width $w: every line fits" '[ "$(while read -r l; do cols <<<"$l"; done <<<"$out" | sort -n | tail -1)" -lt '$w' ]'
  check "width $w: branch and commit mode kept" 'grep -q "main" <<<"$out" && grep -q "deny" <<<"$out"'
done
check "width 40: time dropped first" '! grep -q "12m" <<<"$(run 40 | plain)" && grep -q "Stratum" <<<"$(run 40 | plain)"'
check "width 37: label becomes the logo only" 'out=$(run 37 | plain | head -1); grep -q "󰌨" <<<"$out" && ! grep -q "Stratum" <<<"$out"'
mkdir -p "$tmp/nobunx"
for c in bash python3 cat stty cut dirname ps tr; do ln -s "$(command -v $c)" "$tmp/nobunx/$c"; done
nob=$(printf '%s' "$input" | PATH="$tmp/nobunx" HOME="$tmp/home" CLAUDE_CONFIG_DIR= COLUMNS=80 "$tmp/nobunx/bash" "$root/statusline/st-statusline.sh" | plain)
check "no bunx: own segments only" 'grep -q "Stratum" <<<"$nob" && grep -q " ~/proj " <<<"$nob" && grep -q "Ponytail" <<<"$nob" && grep -q "commit: deny" <<<"$nob" && ! grep -q "Opus" <<<"$nob"'

ctx() { printf '{%s,"context_window":{"total_input_tokens":%s,"context_window_size":1000000,"used_percentage":%s}}' "$ws" "$1" "$2"; }
wfile="$tmp/home/proj/.stratum/weather.json"
printf '{"compactAt":800000,"growth":50000}' > "$wfile"
w3=$(runi 120 "$(ctx 600000 60)" | plain | sed -n 3p)
check "weather: bar and tokens left, turns right" '[[ "$w3" == "☂ Showers ━━━━━━━━━━━━──────── 600k/1M "*" about 4 turns left" ]] && [ "$(cols <<<"$w3")" = 112 ]'
check "weather: no percent" '! grep -q "%" <<<"$w3"'
check "weather: narrow drops the bar first" '[[ "$(runi 50 "$(ctx 600000 60)" | plain | sed -n 3p)" == "☂ Showers 600k/1M "*" about 4 turns left" ]]'
check "weather: very narrow drops the turns" '[ "$(runi 30 "$(ctx 600000 60)" | plain | sed -n 3p)" = "☂ Showers 600k/1M" ]'
check "weather: past threshold says compact now" 'runi 120 "$(ctx 850000 85)" | plain | sed -n 3p | grep -q "☇ Storm.*compact now$"'
printf '{"growth":100000}' > "$wfile"
check "weather: no threshold, turns to a full window" 'runi 120 "$(ctx 600000 60)" | plain | sed -n 3p | grep -q "about 4 turns left$"'
rm "$wfile"
check "weather: no file, no turns" '[ "$(runi 120 "$(ctx 100000 10)" | plain | sed -n 3p)" = "☀ Clear ━━────────────────── 100k/1M" ]'
check "weather: past 90% is Compact soon" 'runi 120 "$(ctx 950000 95)" | plain | sed -n 3p | grep -q "↯ Compact soon"'
check "weather: token counts round without .0" 'runi 120 "$(ctx 335956 34)" | plain | sed -n 3p | grep -q " 336k/1M" && runi 120 "$(ctx 1500 0)" | plain | sed -n 3p | grep -q " 1.5k/1M"'
check "weather: no context in input, no line 3" '[ "$(run 120 | wc -l)" = 2 ]'

rgb() { python3 -c 'import sys; h=sys.argv[1].lstrip("#"); print(";".join(str(int(h[i:i+2],16)) for i in (0,2,4)))' "$1"; }
check "default: rose-pine commit-deny color" 'run 200 | grep -qF "38;2;$(rgb eb6f92)m commit: deny"'
echo '{"theme":"nord"}' > "$tmp/home/proj/.stratum/powerline.json"
check "project theme nord: commit-deny color" 'run 200 | grep -qF "38;2;$(rgb bf616a)m commit: deny"'
check "project config merged over plugin config" 'python3 -c "import json,sys; c=json.load(open(sys.argv[1])); assert c[\"theme\"]==\"nord\" and c[\"display\"][\"colorCompatibility\"]==\"truecolor\" and c[\"display\"][\"lines\"][0][\"segments\"][\"model\"][\"enabled\"]" "$tmp/seen-config.json"'
echo '{"theme":"custom","colors":{"custom":{"git":{"bg":"#112233","fg":"#ffffff"},"commit":{"deny":"#abcdef"}}}}' > "$tmp/home/proj/.stratum/powerline.json"
check "custom: own key used" 'run 200 | grep -qF "38;2;$(rgb abcdef)m commit: deny"'
check "custom: git bg used for commit" 'run 200 | grep -qF "48;2;$(rgb 112233)m"$'"'"'\e'"'"'"[38;2;$(rgb abcdef)m commit: deny"'
check "custom: missing keys filled from rose-pine" 'python3 -c "import json,sys; c=json.load(open(sys.argv[1]))[\"colors\"][\"custom\"]; assert c[\"git\"][\"bg\"]==\"#112233\" and c[\"model\"][\"bg\"]==\"#191724\"" "$tmp/seen-config.json"'
echo '{"logo":""}' > "$tmp/home/proj/.stratum/powerline.json"
check "logo empty: plain Stratum label" '[[ "$(run 100 | plain | head -1)" == " Stratum "* ]]'
echo '{"weather":false}' > "$tmp/home/proj/.stratum/powerline.json"
check "weather false: no line 3, not passed on" '[ "$(runi 120 "$(ctx 600000 60)" | wc -l)" = 2 ] && ! grep -q weather "$tmp/seen-config.json"'
echo '{"reserve":2}' > "$tmp/home/proj/.stratum/powerline.json"
check "reserve 2: right side ends 2 from the edge" '[ "$(run 100 | plain | head -1 | cols)" = 98 ]'
for pair in "arrow:\ue0b0" "rounded:\ue0b6" "slanted:\ue0bc" "flat:│" "bogus:\ue0b0"; do
  echo "{\"shape\":\"${pair%%:*}\"}" > "$tmp/home/proj/.stratum/powerline.json"
  glyph=$(printf "${pair#*:}")
  check "shape ${pair%%:*}: draws its glyph" 'out=$(run 100); grep -qF "$glyph" <<<"$out" && [ "$(wc -l <<<"$out")" = 2 ]'
done
echo '{"shape":"flat"}' > "$tmp/home/proj/.stratum/powerline.json"
check "shape flat: no backgrounds" '! run 100 | grep -qF "[48;2;"'
mkdir -p "$tmp/home/proj/sub"
check "cd into a subfolder: project settings kept" '! runi 100 "{\"workspace\":{\"current_dir\":\"$tmp/home/proj/sub\",\"project_dir\":\"$tmp/home/proj\"}}" | grep -qF "[48;2;"'
echo '{"shape":"blocks"}' > "$tmp/home/proj/.stratum/powerline.json"
check "shape blocks: no shaped edges" 'out=$(run 100); ! grep -qP "[\x{e0b0}-\x{e0bc}]" <<<"$out" && grep -qF "[48;2;" <<<"$out"'
rm "$tmp/home/proj/.stratum/powerline.json"

exit $fail
