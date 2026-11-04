#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/scripts/st-update.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(cd "$tmp" && pwd -P)
fail=0
check() { local n=$1; shift; if "$@"; then echo "ok   $n"; else echo "FAIL $n"; fail=1; fi; }
exits() { [ "$rc" = "$1" ] && "${@:2}"; }

export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export CLAUDE_CONFIG_DIR="$tmp/cfg" PATH="$tmp/bin:$PATH"

mkdir -p "$tmp/home" "$tmp/bin" "$tmp/cfg/plugins" "$tmp/mkt/.claude-plugin" "$tmp/mkt/agents" "$tmp/mkt/skills/st-init" "$tmp/mkt/skills/st-design" "$tmp/proj/.stratum" "$tmp/proj/.claude" "$tmp/proj/apps/a" "$tmp/user-home" "$tmp/plain"
for v in 0.1.22 0.7.0; do
  mkdir -p "$tmp/cfg/plugins/cache/stratum/stratum/$v/statusline"
  touch "$tmp/cfg/plugins/cache/stratum/stratum/$v/statusline/st-statusline.sh"
done

cat > "$tmp/bin/claude" <<EOF
#!/usr/bin/env bash
echo "\$(pwd -P) \$*" >> "$tmp/claude.log"
[ "\$1 \$2 \$3" = "plugin update --json" ] || exit 9
scope=\$5
if [ -n "\${STUB_FAIL:-}" ]; then
  echo '{"command":"update","outcome":"failed","message":"stub refused the update","failureCode":"not_found"}'
  exit 1
fi
target=\$(pwd -P)
[ -n "\${STUB_OTHER:-}" ] && target="$tmp/other-x"
[ -n "\${STUB_NOMOVE:-}" ] || python3 -I - "$tmp/cfg/plugins/installed_plugins.json" "\$target" "\$scope" "$tmp/cfg/plugins/cache/stratum/stratum/0.7.0" <<'PY' || { echo '{"command":"update","outcome":"failed","message":"no record for this folder","failureCode":"not_found"}'; exit 1; }
import datetime, json, sys
path, target, scope, cache = sys.argv[1:]
doc = json.load(open(path))
hit = [r for r in doc["plugins"]["stratum@stratum"] if r["projectPath"] == target and r["scope"] == scope]
if not hit:
    sys.exit(1)
for rec in hit:
    rec.update(version="0.7.0", installPath=cache, lastUpdated=datetime.datetime.now(datetime.timezone.utc).isoformat())
with open(path, "w") as f:
    json.dump(doc, f, indent=2)
PY
printf '{"command":"update","outcome":"ok","scope":"%s","message":"Updated stratum@stratum","updateOutcome":"updated","oldVersion":"0.1.22","newVersion":"0.7.0"}\n' "\$scope"
EOF
chmod +x "$tmp/bin/claude"

cat > "$tmp/mkt/.claude-plugin/plugin.json" <<'EOF'
{"name": "stratum", "version": "0.7.0", "mcpServers": {"figcraft": {"command": "bash"}}}
EOF
printf 'name: st-build\n' > "$tmp/mkt/agents/st-build.md"
printf 'name: st-init\n' > "$tmp/mkt/skills/st-init/SKILL.md"
cat > "$tmp/mkt/skills/st-design/design-tool.md" <<'EOF'
- **Tools.** mcp__plugin_stratum_figcraft__get_node mcp__plugin_stratum_figcraft__set_properties
EOF

printf '{"enabledPlugins": {"ponytail@ponytail": true}}\n' > "$tmp/cfg/settings.json"
printf '{"stratum": {"source": {"source": "directory", "path": "%s"}, "installLocation": "%s"}}\n' "$tmp/mkt" "$tmp/mkt" > "$tmp/cfg/plugins/known_marketplaces.json"
cat > "$tmp/cfg/plugins/installed_plugins.json" <<EOF
{"version": 2, "plugins": {"stratum@stratum": [
{"scope": "local", "projectPath": "$tmp/proj", "installPath": "$tmp/cfg/plugins/cache/stratum/stratum/0.1.22", "version": "0.1.22"},
{"scope": "local", "projectPath": "$tmp/proj-wt", "installPath": "$tmp/cfg/plugins/cache/stratum/stratum/0.7.0", "version": "0.7.0"},
{"scope": "local", "projectPath": "$tmp/proj/apps/a", "installPath": "$tmp/cfg/plugins/cache/stratum/stratum/0.1.22", "version": "0.1.22"},
{"scope": "local", "projectPath": "$tmp/proj/apps/gone", "installPath": "$tmp/cfg/plugins/cache/stratum/stratum/0.1.22", "version": "0.1.22"},
{"scope": "local", "projectPath": "$tmp/proj-worker-w1a", "installPath": "$tmp/cfg/plugins/cache/stratum/stratum/0.1.22", "version": "0.1.22"},
{"scope": "local", "projectPath": "$tmp/other-x", "installPath": "$tmp/cfg/plugins/cache/stratum/stratum/0.1.22", "version": "0.1.22"},
{"scope": "user", "projectPath": "$tmp/user-home", "installPath": "$tmp/cfg/plugins/cache/stratum/stratum/0.1.22", "version": "0.1.22"}
]}}
EOF

git init -q -b main "$tmp/proj"
printf 'node_modules/\n' > "$tmp/proj/.gitignore"
printf '@AGENTS.md\n' > "$tmp/proj/CLAUDE.md"
printf 'Agents.\n' > "$tmp/proj/AGENTS.md"
printf '{}\n' > "$tmp/proj/.claude/settings.json"
printf '# Constitution\n' > "$tmp/proj/.stratum/constitution.md"
git -C "$tmp/proj" add -A
git -C "$tmp/proj" commit -qm init
printf '{}\n' > "$tmp/proj/.claude/settings.local.json"
printf '.stratum/handoff.md\n' >> "$tmp/proj/.git/info/exclude"
git -C "$tmp/proj" worktree add -q -b feat-wt "$tmp/proj-wt"
git -C "$tmp/proj" worktree add -q -b feat-norec "$tmp/proj-norec"
git init -q -b main "$tmp/plain"

audit() { rows=$(cd "$tmp" && bash "$script" audit "$@"); rc=$?; }
rowsof() { awk -F'\t' -v f="$1" -v k="$2" -v n="$3" '$1 == f && $2 == k && $3 == n' <<<"$rows"; }
rowsin() { awk -F'\t' -v f="$1" -v k="$2" -v n="$3" '$1 == f && $2 == k && index($3, n)' <<<"$rows"; }
state() { rowsof "$@" | cut -f4 | head -n1; }
statein() { rowsin "$@" | cut -f4 | head -n1; }
folderrows() { awk -F'\t' -v f="$1" '$1 == f' <<<"$rows"; }
kindrows() { awk -F'\t' -v f="$1" -v k="$2" '$1 == f && $2 == k' <<<"$rows"; }
listedcount() { awk -F'\t' '$2 == "install" && $4 == "listed" { n++ } END { print n + 0 }' <<<"$rows"; }
contains() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }
snap() {
  find "$tmp" -path '*/.git' -prune -o -type f -exec sha256sum {} + | sort
  for d in "$tmp/proj" "$tmp/proj-wt" "$tmp/proj-norec"; do git -C "$d" status --porcelain; done
}
slcmd() { printf '{"statusLine": {"type": "command", "command": "%s"}}\n' "$1" > "$tmp/proj/.claude/settings.local.json"; audit "$tmp/proj"; state "$tmp/proj" statusline statusLine; }
slraw() { printf '%s\n' "$1" > "$tmp/proj/.claude/settings.local.json"; audit "$tmp/proj"; state "$tmp/proj" statusline statusLine; }

before=$(snap)
err=$(cd "$tmp" && bash "$script" audit "$tmp/plain" 2>&1 >/dev/null); rc=$?
after=$(snap)
check "U1 exits 1" [ "$rc" = 1 ]
check "U1 st-init line on stderr" [ "$err" = "Not a Stratum project: $tmp/plain. Run /stratum:st-init there." ]
check "U1 changes nothing" exits 1 [ "$before" = "$after" ]

audit "$tmp/proj"
check "U2 audit exits 0" [ "$rc" = 0 ]
check "U2 main has an install row" [ -n "$(rowsof "$tmp/proj" install stratum@stratum)" ]
check "U2 linked worktree has an install row" [ -n "$(rowsof "$tmp/proj-wt" install stratum@stratum)" ]
check "U2 record subfolder has an install row" [ -n "$(rowsof "$tmp/proj/apps/a" install stratum@stratum)" ]
check "U2 worktree with no record is listed" [ "$(state "$tmp/proj-norec" install stratum@stratum)" = listed ]
check "U2 no-record row says no install" contains "$(rowsof "$tmp/proj-norec" install stratum@stratum)" "no install"
check "U2 gone record under a checkout" [ "$(state "$tmp/proj/apps/gone" install stratum@stratum)" = gone ]
check "U2 gone sibling of the main checkout" [ "$(state "$tmp/proj-worker-w1a" install stratum@stratum)" = gone ]
check "U2 gone folder of another project has no row" exits 0 [ -z "$(folderrows "$tmp/other-x")" ]
check "U2 user record and no-record worktree are listed" exits 0 [ "$(listedcount)" = 2 ]

check "U3 0.1.22 record outdated" [ "$(state "$tmp/proj" install stratum@stratum)" = outdated ]
check "U3 0.7.0 record current" [ "$(state "$tmp/proj-wt" install stratum@stratum)" = current ]
check "U3 subfolder 0.1.22 record outdated" [ "$(state "$tmp/proj/apps/a" install stratum@stratum)" = outdated ]

check "U4 statusLine at an old cache path outdated" [ "$(slcmd "bash $tmp/cfg/plugins/cache/stratum/stratum/0.1.0/statusline/st-statusline.sh")" = outdated ]
check "U4 statusLine at a missing path outdated" [ "$(slcmd "bash $tmp/gone-cache/statusline/st-statusline.sh")" = outdated ]
check "U4 statusLine at the source folder outdated" [ "$(slcmd "bash $tmp/mkt/statusline/st-statusline.sh")" = outdated ]
check "U4 statusLine at the record path current" [ "$(slcmd "bash $tmp/cfg/plugins/cache/stratum/stratum/0.1.22/statusline/st-statusline.sh")" = current ]
check "U4 no statusLine is new" [ "$(slraw '{}')" = new ]
check "U4 custom statusLine is ask" [ "$(slcmd 'bash /opt/mine/statusline.sh')" = ask ]
check "U4 bad JSON is invalid" [ "$(slraw '{"statusLine": ')" = invalid ]
audit "$tmp/proj"
check "U4 bad settings.local.json gives one invalid row" [ "$(awk -F'\t' -v f="$tmp/proj" '$1 == f && $4 == "invalid" && index($5, "settings.local.json")' <<<"$rows" | wc -l)" = 1 ]

printf '{"st-gone": {"model": "haiku"}, "st-build": {"model": "opus"}}\n' > "$tmp/proj/.stratum/models.json"
cat > "$tmp/proj/.claude/settings.json" <<'EOF'
{"permissions": {"allow": ["Skill(stratum:st-gone)", "Skill(stratum:x$(touch pwned))", "Skill(stratum:../x)", "Bash(npm test:*)", "mcp__plugin_stratum_figcraft__get_node", "mcp__plugin_stratum_figcraft__gone_tool", "mcp__plugin_stratum_figcraft__*"]}}
EOF
git -C "$tmp/proj" commit -qam "fixture: settings for the U5 and U7 rows"
audit "$tmp/proj"
check "U5 audit exits 0" [ "$rc" = 0 ]
check "U5 dead model key discontinued" exits 0 [ "$(state "$tmp/proj" models-key st-gone)" = discontinued ]
check "U5 live model key current" exits 0 [ "$(state "$tmp/proj" models-key st-build)" = current ]
check "U5 dead skill allow entry discontinued" exits 0 [ "$(statein "$tmp/proj" allow 'Skill(stratum:st-gone)')" = discontinued ]
check "U5 dead FigCraft allow entry discontinued" exits 0 [ "$(statein "$tmp/proj" allow mcp__plugin_stratum_figcraft__gone_tool)" = discontinued ]
check "U5 injected allow entry invalid" exits 0 [ "$(statein "$tmp/proj" allow 'Skill(stratum:x$(touch pwned))')" = invalid ]
check "U5 skill entry with a slash invalid" exits 0 [ "$(statein "$tmp/proj" allow 'Skill(stratum:../x)')" = invalid ]
check "U5 no file pwned under the temp folder" exits 0 [ -z "$(find "$tmp" -name pwned)" ]
check "U5 user Bash rule has no row" exits 0 [ -z "$(statein "$tmp/proj" allow 'npm test')" ]
check "U5 FigCraft wildcard allow entry current" exits 0 [ "$(state "$tmp/proj" allow 'mcp__plugin_stratum_figcraft__*')" = current ]
for d in agents skills; do
  mv "$tmp/mkt/$d" "$tmp/mkt/$d.off"
  err=$(cd "$tmp" && bash "$script" audit "$tmp/proj" 2>&1 >/dev/null); rc=$?
  mv "$tmp/mkt/$d.off" "$tmp/mkt/$d"
  check "U5 missing marketplace $d/ exits 1 with one line" exits 1 [ "$err" = "Cannot read $tmp/mkt/$d in the Stratum marketplace." ]
done

printf 'auto\n' > "$tmp/proj/.stratum/commit-mode"
audit "$tmp/proj"
check "U6 commit-mode discontinued" exits 0 [ "$(state "$tmp/proj" gone-file .stratum/commit-mode)" = discontinued ]
rm -f "$tmp/proj/.stratum/commit-mode"

printf '@.stratum/constitution.md\n' > "$tmp/proj/CLAUDE.local.md"
printf '{"enabledPlugins": {"ponytail@ponytail": false}}\n' > "$tmp/proj/.claude/settings.local.json"
audit "$tmp/proj"
check "U7 audit exits 0" [ "$rc" = 0 ]
check "U7 ignored only by .git/info/exclude is current" exits 0 [ "$(state "$tmp/proj" ignore .stratum/handoff.md)" = current ]
check "U7 ignored nowhere is new" exits 0 [ "$(state "$tmp/proj" ignore .stratum/weather.json)" = new ]
check "U7 constitution named only in CLAUDE.local.md is current" exits 0 [ "$(state "$tmp/proj" pointer @.stratum/constitution.md)" = current ]
check "U7 constitution named nowhere is new" exits 0 [ "$(state "$tmp/proj-wt" pointer @.stratum/constitution.md)" = new ]
check "U7 plugin false only in settings.local.json is current" exits 0 [ "$(state "$tmp/proj" plugins-off ponytail@ponytail)" = current ]
check "U7 plugin in neither file is new" exits 0 [ "$(state "$tmp/proj-wt" plugins-off ponytail@ponytail)" = new ]
check "U7 allowed FigCraft tool is current" exits 0 [ "$(statein "$tmp/proj" figcraft get_node)" = current ]
check "U7 unallowed FigCraft tool is new" exits 0 [ "$(statein "$tmp/proj" figcraft set_properties)" = new ]
check "U7 no FigCraft row when none is allowed" exits 0 [ -z "$(kindrows "$tmp/proj-wt" figcraft)" ]
printf '{"enabledPlugins": {"ponytail@ponytail": true, "token-weather$(touch pwned)@x": true}}\n' > "$tmp/cfg/settings.json"
audit "$tmp/proj"
check "U7 unsafe plugin key is invalid" exits 0 [ "$(state "$tmp/proj" plugins-off 'token-weather$(touch pwned)@x')" = invalid ]
printf '{"enabledPlugins": {"ponytail@ponytail": true}}\n' > "$tmp/cfg/settings.json"
printf 'lessons\n' > "$tmp/proj/.stratum/lessons.md"
git -C "$tmp/proj" add -- .stratum/lessons.md
printf '.stratum/lessons.md\n' >> "$tmp/proj/.gitignore"
git -C "$tmp/proj" commit -qm "fixture: tracked lessons named in .gitignore" -- .gitignore .stratum/lessons.md
audit "$tmp/proj"
check "U7 tracked path named in .gitignore is current" exits 0 [ "$(state "$tmp/proj" ignore .stratum/lessons.md)" = current ]
out=$(bash "$script" fix "$tmp/proj" ignore .stratum/lessons.md 2>&1); rc=$?
check "U7 fix ignore on that path prints same" exits 0 contains "$out" "same .gitignore"

before=$(snap)
audit "$tmp/proj"
after=$(snap)
check "U8 audit exits 0 and changes no file" exits 0 [ "$before" = "$after" ]

git init -q -b feat-x "$tmp/mkt"
git -C "$tmp/mkt" add -A
git -C "$tmp/mkt" commit -qm init
audit "$tmp/proj"
check "U20 feat-x marketplace warns naming the branch" exits 0 [ "$(state - marketplace-branch feat-x)" = warn ]
git -C "$tmp/mkt" branch -q -m main
audit "$tmp/proj"
check "U20 main has no marketplace-branch row" exits 0 [ -z "$(kindrows - marketplace-branch)" ]
rm -rf "$tmp/mkt/.git"
audit "$tmp/proj"
check "U20 plain folder has no marketplace-branch row" exits 0 [ -z "$(kindrows - marketplace-branch)" ]

check "no audit calls claude" exits 0 [ ! -e "$tmp/claude.log" ]

calls() { cat "$tmp/claude.log" 2>/dev/null | wc -l; }
calledwith() { grep -qxF -- "$1" "$tmp/claude.log" 2>/dev/null; }
run() { out=$(bash "$script" "$@" 2>&1); rc=$?; }
rec() { python3 -I -c 'import json, sys
for r in json.load(open(sys.argv[1]))["plugins"]["stratum@stratum"]:
    if r["projectPath"] == sys.argv[2] and r["scope"] == "local":
        print(r.get(sys.argv[3], ""))' "$tmp/cfg/plugins/installed_plugins.json" "$1" "$2"; }
pyq() { python3 -I -c 'import json, sys
v = eval(sys.argv[2], {"d": json.load(open(sys.argv[1]))})
print(v if isinstance(v, str) else json.dumps(v))' "$1" "$2" 2>/dev/null; }
fullrun() {
  local f k n s d
  audit "$tmp/proj"
  while IFS=$'\t' read -r f k n s d; do
    [ "$k" = install ] && [ "$s" = outdated ] && bash "$script" plugin "$f" >/dev/null 2>&1 </dev/null
  done <<< "$rows"
  audit "$tmp/proj"
  while IFS=$'\t' read -r f k n s d; do
    case "$s" in outdated|new|discontinued) ;; *) continue ;; esac
    case "$k" in
      statusline) bash "$script" fix "$f" statusline "$n" >/dev/null 2>&1 </dev/null ;;
      allow) bash "$script" fix "$f" allow "$d:$n" >/dev/null 2>&1 </dev/null ;;
      ignore|pointer|plugins-off|figcraft|file|models-key|gone-file) bash "$script" fix "$f" "$k" "$n" >/dev/null 2>&1 </dev/null ;;
    esac
  done <<< "$rows"
  audit "$tmp/proj"
}
cache7="$tmp/cfg/plugins/cache/stratum/stratum/0.7.0"

run fix "$tmp/proj" install stratum@stratum
check "U9 fix on an outdated install row exits 3, no fix for that kind" exits 3 contains "$out" "skip: install has no fix"
run plugin "$tmp/proj"
check "U9 plugin exits 0" [ "$rc" = 0 ]
check "U9 plugin prints ok, the new version and path" contains "$out" "ok 0.7.0 $cache7"
check "U9 claude runs in the folder with the record scope" calledwith "$tmp/proj plugin update --json -s local stratum@stratum"
check "U9 record version moves to 0.7.0" [ "$(rec "$tmp/proj" version)" = 0.7.0 ]
check "U9 record path moves to the 0.7.0 cache" [ "$(rec "$tmp/proj" installPath)" = "$cache7" ]
before=$(calls); run plugin "$tmp/proj/apps/gone"
check "U9 gone record under a checkout exits 1, claude not called" exits 1 [ "$(calls)" = "$before" ]
before=$(calls); run plugin "$tmp/proj-worker-w1a"
check "U9 gone sibling exits 1, claude not called" exits 1 [ "$(calls)" = "$before" ]
before=$(calls); run plugin "$tmp/user-home"
check "U9 user record exits 1, claude not called" exits 1 [ "$(calls)" = "$before" ]
before=$(calls); run plugin "$tmp/proj-norec"
check "U9 folder with no record exits 1, claude not called" exits 1 [ "$(calls)" = "$before" ]
out=$(STUB_FAIL=1 bash "$script" plugin "$tmp/proj/apps/a" 2>&1); rc=$?
check "U9 failed CLI update exits 1 and leaves the record at 0.1.22" exits 1 [ "$(rec "$tmp/proj/apps/a" version)" = 0.1.22 ]
check "U9 failed CLI update prints the CLI message" contains "$out" "stub refused the update"
check "U9 failed CLI update prints the command" contains "$out" "Run: cd $tmp/proj/apps/a && claude plugin update stratum@stratum -s local"
out=$(STUB_NOMOVE=1 bash "$script" plugin "$tmp/proj/apps/a" 2>&1); rc=$?
check "U9 ok outcome with an unmoved record exits 1" exits 1 [ "$(rec "$tmp/proj/apps/a" version)" = 0.1.22 ]

out=$(STUB_OTHER=1 bash "$script" plugin "$tmp/proj-wt" 2>&1); rc=$?
check "U10 update of another record exits 1" [ "$rc" = 1 ]
check "U10 prints the command" contains "$out" "Run: cd $tmp/proj-wt && claude plugin update stratum@stratum -s local"

run fix "$tmp/proj/apps/a" statusline statusLine
check "U11 fix statusline before plugin exits 3 with the reason" exits 3 contains "$out" "skip: install not updated"
check "U11 fix statusline before plugin writes nothing" exits 3 [ ! -e "$tmp/proj/apps/a/.claude/settings.local.json" ]
run fix "$tmp/proj" statusline statusLine
check "U11 fix statusline after plugin exits 0" [ "$rc" = 0 ]
check "U11 statusLine points at the record's new path" [ "$(pyq "$tmp/proj/.claude/settings.local.json" 'd["statusLine"]["command"]')" = "bash $cache7/statusline/st-statusline.sh" ]
check "U11 other keys kept" exits 0 [ "$(pyq "$tmp/proj/.claude/settings.local.json" 'd["enabledPlugins"]["ponytail@ponytail"]')" = false ]
run fix "$tmp/proj-norec" statusline statusLine
check "U11 fix statusline with no settings.local.json exits 0" [ "$rc" = 0 ]
check "U11 that new file holds only statusLine" [ "$(pyq "$tmp/proj-norec/.claude/settings.local.json" 'sorted(d)')" = '["statusLine"]' ]
check "U11 its statusLine is the main record's new path" [ "$(pyq "$tmp/proj-norec/.claude/settings.local.json" 'd["statusLine"]["command"]')" = "bash $cache7/statusline/st-statusline.sh" ]

run fix "$tmp/proj" file .stratum/state.json
check "U13 fix file state.json exits 0" [ "$rc" = 0 ]
check "U13 state.json holds the st-init value" [ "$(pyq "$tmp/proj/.stratum/state.json" 'd == {"feature_directory": None, "phase": None, "lane": None}')" = true ]
check "U13 new state.json has mode 644" [ "$(stat -c %a "$tmp/proj/.stratum/state.json")" = 644 ]
run fix "$tmp/proj" file .stratum/advisor.json
check "U13 fix file advisor.json exits 3 and writes nothing" exits 3 [ ! -e "$tmp/proj/.stratum/advisor.json" ]

run fix "$tmp/proj" models-key st-gone
check "U14 fix models-key st-gone exits 0" [ "$rc" = 0 ]
check "U14 models-key keeps st-build and drops st-gone" [ "$(pyq "$tmp/proj/.stratum/models.json" 'd == {"st-build": {"model": "opus"}}')" = true ]
printf 'auto\n' > "$tmp/proj/.stratum/commit-mode"
run fix "$tmp/proj" gone-file .stratum/commit-mode
check "U14 gone-file commit-mode exits 0 and deletes it" exits 0 [ ! -e "$tmp/proj/.stratum/commit-mode" ]
printf 'lessons\n' > "$tmp/proj/.stratum/lessons.md"
run fix "$tmp/proj" gone-file .stratum/lessons.md
check "U14 gone-file lessons.md exits 3 and keeps it" exits 3 [ -e "$tmp/proj/.stratum/lessons.md" ]
mkdir "$tmp/proj/.stratum/commit-mode"
run fix "$tmp/proj" gone-file .stratum/commit-mode
check "U14 gone-file on a commit-mode folder exits 3 and keeps it" exits 3 [ -d "$tmp/proj/.stratum/commit-mode" ]
rmdir "$tmp/proj/.stratum/commit-mode"

mkdir -p "$tmp/bin18"
for b in /usr/bin/*; do [ "${b##*/}" = claude ] || ln -s "$b" "$tmp/bin18/${b##*/}"; done
out=$(PATH="$tmp/bin18" bash "$script" plugin "$tmp/proj/apps/a" 2>&1); rc=$?
check "U18 no claude on PATH: plugin exits 1" [ "$rc" = 1 ]
check "U18 no claude on PATH: plugin prints the command" contains "$out" "claude not found. Run: cd $tmp/proj/apps/a && claude plugin update stratum@stratum -s local"
out=$(PATH="$tmp/bin18" bash "$script" fix "$tmp/proj-norec" plugins-off ponytail@ponytail 2>&1); rc=$?
check "U18 no claude on PATH: fix exits 0 and changes a file" exits 0 contains "$out" "changed"
check "U18 no claude on PATH: the fix wrote the plugin key" [ "$(pyq "$tmp/proj-norec/.claude/settings.json" 'd["enabledPlugins"]["ponytail@ponytail"]')" = false ]

printf '{"permissions": {"allow": ["Skill(stratum:st-gone)", "mcp__plugin_stratum_figcraft__get_node", "mcp__plugin_stratum_figcraft__gone_tool"]}}\n' > "$tmp/proj/.claude/settings.json"
git -C "$tmp/proj" commit -qam "fixture: settings"
printf '{}\n' > "$tmp/proj/.stratum/git-guard.json"
printf '{}\n' > "$tmp/proj/.stratum/powerline.json"
printf '{}\n' > "$tmp/proj/.stratum/advisor.json"
fullrun
check "U17 audit exits 0" [ "$rc" = 0 ]
check "U17 main install is current" [ "$(state "$tmp/proj" install stratum@stratum)" = current ]
bad=$(awk -F'\t' '$4 != "current" && $4 != "gone" && $4 != "listed"' <<<"$rows")
check "U17 only current, gone and listed rows" [ -z "$bad" ]
[ -z "$bad" ] || printf '%s\n' "$bad"

noggit() { ! grep -Eq '\bgit\b.*\b(add|commit|push)\b' "$script"; }
check "U19 script has the fix subcommand" grep -q '^ *fix)' "$script"
check "U19 script runs no git add, commit or push" noggit

u3="$tmp/u3"
git init -q -b main "$u3"
mkdir -p "$u3/.stratum" "$u3/.claude"
printf 'node_modules/\nuser-line/\n' > "$u3/.gitignore"
printf '@AGENTS.md\nuser pointer\n' > "$u3/CLAUDE.md"
printf 'Agents.\n' > "$u3/AGENTS.md"
printf '{"env": {"SECRET": "hunter2"}, "enabledPlugins": {"ponytail@ponytail": true}, "permissions": {"allow": ["Skill(stratum:st-gone)", "Bash(npm test:*)", "mcp__plugin_stratum_figcraft__get_node"]}}\n' > "$u3/.claude/settings.json"
printf '# My constitution\n' > "$u3/.stratum/constitution.md"
git -C "$u3" add -A
git -C "$u3" commit -qm init
printf '{"feature_directory": "specs/x", "phase": "build", "lane": "x"}\n' > "$u3/.stratum/state.json"
printf 'my lessons\n' > "$u3/.stratum/lessons.md"
printf 'my handoff\n' > "$u3/.stratum/handoff.md"
printf '{"mode": "auto"}\n' > "$u3/.stratum/git-guard.json"
printf '{"theme": "mine"}\n' > "$u3/.stratum/powerline.json"
printf '{"enabled": true}\n' > "$u3/.stratum/advisor.json"
printf '{"st-gone": {"model": "haiku"}, "st-build": {"model": "opus"}}\n' > "$u3/.stratum/models.json"
printf 'auto\n' > "$u3/.stratum/commit-mode"
printf '{"env": {"SECRET": "hunter2"}, "statusLine": {"type": "command", "command": "bash %s/statusline/st-statusline.sh"}}\n' "$tmp/cfg/plugins/cache/stratum/stratum/0.1.22" > "$u3/.claude/settings.local.json"
cat > "$tmp/cfg/plugins/installed_plugins.json" <<EOF
{"version": 2, "plugins": {"stratum@stratum": [
{"scope": "local", "projectPath": "$u3", "installPath": "$cache7", "version": "0.7.0"}
]}}
EOF

userfiles() { (cd "$u3/.stratum" && sha256sum constitution.md state.json lessons.md handoff.md git-guard.json powerline.json advisor.json); }
before=$(userfiles)
run fix "$u3" ignore .stratum/handoff.md
check "U12 ignore fix changes .gitignore" exits 0 contains "$out" "changed .gitignore"
run fix "$u3" pointer @.stratum/constitution.md
check "U12 pointer fix changes CLAUDE.md" exits 0 contains "$out" "changed CLAUDE.md"
run fix "$u3" plugins-off ponytail@ponytail
check "U12 plugins-off fix changes settings.json" exits 0 contains "$out" "changed .claude/settings.json"
run fix "$u3" statusline statusLine
check "U12 statusline fix changes settings.local.json" exits 0 contains "$out" "changed .claude/settings.local.json"
run fix "$u3" figcraft mcp__plugin_stratum_figcraft__set_properties
check "U12 figcraft fix changes settings.json" exits 0 contains "$out" "changed .claude/settings.json"
run fix "$u3" file .stratum/advisor.json
check "U12 file fix refuses a user file" exits 3 contains "$out" "skip:"
run fix "$u3" models-key st-gone
check "U12 models-key fix changes models.json" exits 0 contains "$out" "changed .stratum/models.json"
run fix "$u3" allow ".claude/settings.json:Skill(stratum:st-gone)"
check "U12 allow fix changes settings.json" exits 0 contains "$out" "changed .claude/settings.json"
run fix "$u3" gone-file .stratum/commit-mode
check "U12 gone-file fix removes commit-mode" exits 0 [ ! -e "$u3/.stratum/commit-mode" ]
after=$(userfiles)
check "U12 user data files byte-equal" [ "$before" = "$after" ]
check "U12 .gitignore keeps the user line" grep -qxF 'user-line/' "$u3/.gitignore"
check "U12 CLAUDE.md keeps the user line" grep -qxF 'user pointer' "$u3/CLAUDE.md"
check "U12 settings.json keeps env" [ "$(pyq "$u3/.claude/settings.json" 'd["env"] == {"SECRET": "hunter2"}')" = true ]
check "U12 settings.json keeps the user allow rule and drops the dead one" [ "$(pyq "$u3/.claude/settings.json" 'd["permissions"]["allow"] == ["Bash(npm test:*)", "mcp__plugin_stratum_figcraft__get_node", "mcp__plugin_stratum_figcraft__set_properties"]')" = true ]
check "U12 settings.json turns the plugin off" [ "$(pyq "$u3/.claude/settings.json" 'd["enabledPlugins"] == {"ponytail@ponytail": False}')" = true ]
check "U12 settings.local.json keeps env" [ "$(pyq "$u3/.claude/settings.local.json" 'd["env"] == {"SECRET": "hunter2"}')" = true ]
check "U12 statusLine moves to the record's path" [ "$(pyq "$u3/.claude/settings.local.json" 'd["statusLine"]["command"]')" = "bash $cache7/statusline/st-statusline.sh" ]
check "U12 models-key keeps the live key" [ "$(pyq "$u3/.stratum/models.json" 'd == {"st-build": {"model": "opus"}}')" = true ]
audit "$u3"
check "U12 audit output does not show the env value" [ "$(grep -c hunter2 <<<"$rows")" = 0 ]

printf '{"statusLine": {"type": "command", "command": "bash /opt/mine/statusline.sh"}}\n' > "$u3/.claude/settings.local.json"
slbefore=$(sha256sum "$u3/.claude/settings.local.json")
run fix "$u3" statusline statusLine
check "U16 custom statusLine is refused with exit 3" exits 3 contains "$out" "skip: not a Stratum statusline"
check "U16 refused statusLine fix writes nothing" [ "$slbefore" = "$(sha256sum "$u3/.claude/settings.local.json")" ]
run fix "$u3" statusline statusLine --force
check "U16 statusLine fix with --force exits 0 and changes it" exits 0 contains "$out" "changed .claude/settings.local.json"
check "U16 --force points statusLine at the record's path" [ "$(pyq "$u3/.claude/settings.local.json" 'd["statusLine"]["command"]')" = "bash $cache7/statusline/st-statusline.sh" ]

git -C "$u3" worktree add -q -b feat-dirty "$tmp/u3-dirty"
printf 'user edit\n' >> "$tmp/u3-dirty/CLAUDE.md"
git -C "$u3" worktree add -q --detach "$tmp/u3-det"
dirtysum=$(sha256sum "$tmp/u3-dirty/CLAUDE.md")
audit "$u3"
check "U15 audit exits 0" [ "$rc" = 0 ]
check "U15 non-current CLAUDE.md row in the dirty worktree is skip" [ "$(state "$tmp/u3-dirty" pointer @.stratum/constitution.md)" = skip ]
check "U15 skip row names CLAUDE.md as uncommitted" [ "$(rowsof "$tmp/u3-dirty" pointer @.stratum/constitution.md | cut -f5)" = "CLAUDE.md has uncommitted changes" ]
check "U15 current CLAUDE.md row in the dirty worktree stays current" [ "$(state "$tmp/u3-dirty" pointer @AGENTS.md)" = current ]
check "U15 other rows of the dirty worktree are not skip" [ -z "$(awk -F'\t' -v f="$tmp/u3-dirty" '$1 == f && $4 == "skip" && $2 != "pointer"' <<<"$rows")" ]
check "U15 dirty CLAUDE.md is byte-equal after audit" [ "$dirtysum" = "$(sha256sum "$tmp/u3-dirty/CLAUDE.md")" ]
check "U15 detached worktree has committed-file rows" [ -n "$(awk -F'\t' -v f="$tmp/u3-det" '$1 == f && $2 == "ignore"' <<<"$rows")" ]
check "U15 non-current committed-file rows of the detached worktree are skip with the detached reason" [ -z "$(awk -F'\t' -v f="$tmp/u3-det" '$1 == f && ($2 == "ignore" || $2 == "pointer" || $2 == "plugins-off" || $2 == "figcraft" || $2 == "allow") && $4 != "current" && ($4 != "skip" || $5 != "detached HEAD, no branch to commit on")' <<<"$rows")" ]
check "U15 detached worktree has a non-current committed-file row" [ -n "$(awk -F'\t' -v f="$tmp/u3-det" '$1 == f && $2 == "pointer" && $4 == "skip"' <<<"$rows")" ]
check "U15 current CLAUDE.md row in the detached worktree stays current" [ "$(state "$tmp/u3-det" pointer @AGENTS.md)" = current ]

git init -q -b main "$tmp/u21"
git -C "$tmp/u21" commit -q --allow-empty -m init
mkdir -p "$tmp/u21/.stratum"
run fix "$tmp/u21" pointer @AGENTS.md
check "U21 pointer @AGENTS.md with no AGENTS.md is same" exits 0 contains "$out" "same CLAUDE.md"
check "U21 that fix creates no CLAUDE.md" [ ! -e "$tmp/u21/CLAUDE.md" ]
check "U21 that fix creates no AGENTS.md" [ ! -e "$tmp/u21/AGENTS.md" ]
run fix "$tmp/u21" pointer @.stratum/constitution.md
check "U21 CLAUDE.md gets only the constitution pointer" [ "$(cat "$tmp/u21/CLAUDE.md")" = "@.stratum/constitution.md" ]
check "U21 no AGENTS.md after the constitution fix" [ ! -e "$tmp/u21/AGENTS.md" ]

printf '{"st-gone": {}, "st-build": {}}\n' > "$tmp/u21-models.json"
ln -s "$tmp/u21-models.json" "$tmp/u21/.stratum/models.json"
outsum=$(sha256sum "$tmp/u21-models.json")
run fix "$tmp/u21" models-key st-gone
check "JSON write through a symlink outside the checkout exits 3" exits 3 contains "$out" "skip: .stratum/models.json points outside $tmp/u21"
check "JSON write leaves the outside file byte-equal" [ "$outsum" = "$(sha256sum "$tmp/u21-models.json")" ]
rm "$tmp/u21/.stratum/models.json"
printf '{"st-gone": {}, "st-build": {}}\n' > "$tmp/u21/models-real.json"
chmod 600 "$tmp/u21/models-real.json"
ln -s ../models-real.json "$tmp/u21/.stratum/models.json"
run fix "$tmp/u21" models-key st-gone
check "JSON write through a symlink exits 0" [ "$rc" = 0 ]
check "JSON write keeps the symlink" [ -L "$tmp/u21/.stratum/models.json" ]
check "JSON write changes the link target" [ "$(pyq "$tmp/u21/models-real.json" 'sorted(d)')" = '["st-build"]' ]
check "JSON write keeps mode 600" [ "$(stat -c %a "$tmp/u21/models-real.json")" = 600 ]
check "JSON write leaves no .tmp file" [ -z "$(find "$tmp" -name '*.tmp')" ]
printf '%s\n' '{"st-gone": {}, "x": "\ud800"}' > "$tmp/u21/models-real.json"
surrsum=$(sha256sum "$tmp/u21/models-real.json")
run fix "$tmp/u21" models-key st-gone
check "JSON write of a lone surrogate exits 3" exits 3 contains "$out" "skip: cannot write .stratum/models.json:"
check "JSON write of a lone surrogate leaves no .tmp file" [ -z "$(find "$tmp" -name '*.tmp')" ]
check "JSON write of a lone surrogate leaves the file byte-equal" [ "$surrsum" = "$(sha256sum "$tmp/u21/models-real.json")" ]

mkdir -p "$tmp/u21/.claude"
printf '{}\n' > "$tmp/u21/.claude/settings.json"
chmod 644 "$tmp/u21/.claude/settings.json"
printf 'victim\n' > "$tmp/victim"
victimsum=$(sha256sum "$tmp/victim")
ln -s ../../victim "$tmp/u21/.claude/settings.json.tmp"
run fix "$tmp/u21" plugins-off ponytail@ponytail
check "JSON write with a planted .tmp symlink exits 0" [ "$rc" = 0 ]
check "JSON write does not follow the .tmp symlink" [ "$victimsum" = "$(sha256sum "$tmp/victim")" ]
check "JSON write leaves settings.json not a symlink" [ ! -L "$tmp/u21/.claude/settings.json" ]
check "JSON write turns the plugin off in settings.json" [ "$(pyq "$tmp/u21/.claude/settings.json" 'd["enabledPlugins"]["ponytail@ponytail"]')" = false ]
check "JSON write keeps mode 644" [ "$(stat -c %a "$tmp/u21/.claude/settings.json")" = 644 ]
rm "$tmp/u21/.claude/settings.json.tmp"

git init -q -b main "$tmp/u22"
mkdir -p "$tmp/u22/.stratum" "$tmp/u22/docs"
printf 'victim\n' > "$tmp/u22-victim"
ln -s ../u22-victim "$tmp/u22/CLAUDE.md"
git -C "$tmp/u22" add -A
git -C "$tmp/u22" commit -qm init
victimsum=$(sha256sum "$tmp/u22-victim")
audit "$tmp/u22"
check "audit of a committed CLAUDE.md symlink outside the checkout keeps new" [ "$(rowsof "$tmp/u22" pointer @.stratum/constitution.md | cut -f4,5)" = "$(printf 'new\tCLAUDE.md')" ]
run fix "$tmp/u22" pointer @.stratum/constitution.md
check "append through a committed CLAUDE.md symlink outside the checkout exits 3" exits 3 contains "$out" "skip: CLAUDE.md points outside $tmp/u22"
check "append leaves the outside file byte-equal" [ "$victimsum" = "$(sha256sum "$tmp/u22-victim")" ]
rm "$tmp/u22/CLAUDE.md"
printf 'mine\n' > "$tmp/u22/docs/claude.md"
ln -s docs/claude.md "$tmp/u22/CLAUDE.md"
run fix "$tmp/u22" pointer @.stratum/constitution.md
check "append through a CLAUDE.md symlink inside the checkout exits 0" [ "$rc" = 0 ]
check "append writes the line into the link target" grep -qxF '@.stratum/constitution.md' "$tmp/u22/docs/claude.md"
check "append keeps the CLAUDE.md symlink" [ -L "$tmp/u22/CLAUDE.md" ]

mkdir -p "$tmp/u23/.stratum"
audit "$tmp/u23"
check "U15 non-git folder audit exits 0" [ "$rc" = 0 ]
check "U15 non-git folder has a new pointer row" exits 0 [ "$(state "$tmp/u23" pointer @.stratum/constitution.md)" = new ]
check "U15 non-git folder has no skip row" exits 0 [ -z "$(awk -F'\t' '$4 == "skip"' <<<"$rows")" ]

git init -q -b main "$tmp/u24"
mkdir -p "$tmp/u24/.stratum"
printf 'x\n' > "$tmp/u24/CLAUDE.md"
git -C "$tmp/u24" add -A
git -C "$tmp/u24" commit -qm init
printf 'corrupt\n' > "$tmp/u24/.git/index"
audit "$tmp/u24"
check "U15 corrupt index audit exits 0" [ "$rc" = 0 ]
check "U15 corrupt index gives a skip row with the git status detail" exits 0 [ "$(rowsof "$tmp/u24" pointer @.stratum/constitution.md | cut -f4,5)" = "skip	git status failed for CLAUDE.md" ]
git init -q -b main "$tmp/u25"
mkdir -p "$tmp/u25/.stratum"
printf 'node_modules/\n.stratum/models.json\n.stratum/weather.json.bak\nxstratum/handoff_md\nx/.stratum/powerline.json\n.stratum/lessons.md\n!.stratum/lessons.md\n' > "$tmp/u25/.gitignore"
printf '@AGENTS.md\n@.stratum/constitution.md\n' > "$tmp/u25/CLAUDE.md"
printf 'Agents.\n' > "$tmp/u25/AGENTS.md"
git -C "$tmp/u25" add -A
git -C "$tmp/u25" commit -qm init
printf 'node_modules/\n.stratum/lessons.md\n!.stratum/lessons.md\n' > "$tmp/u25/.gitignore"
printf '@AGENTS.md\n' > "$tmp/u25/CLAUDE.md"
git -C "$tmp/u25" commit -qam "fixture: drop the stratum lines"
sha=$(git -C "$tmp/u25" log -1 --format=%h)
audit "$tmp/u25"
check "U25 ignore .stratum/models.json removed in the commit that dropped it" [ "$(rowsof "$tmp/u25" ignore .stratum/models.json | cut -f4,5)" = "$(printf 'new\tremoved in %s' "$sha")" ]
check "U25 pointer @.stratum/constitution.md removed in the commit that dropped it" [ "$(rowsof "$tmp/u25" pointer @.stratum/constitution.md | cut -f4,5)" = "$(printf 'new\tremoved in %s' "$sha")" ]
check "U25 ignore never committed keeps .gitignore" [ "$(rowsof "$tmp/u25" ignore .stratum/handoff.md | cut -f4,5)" = "$(printf 'new\t.gitignore')" ]
check "U25 ignore whose only removed line is a longer .bak keeps .gitignore" [ "$(rowsof "$tmp/u25" ignore .stratum/weather.json | cut -f4,5)" = "$(printf 'new\t.gitignore')" ]
check "U25 ignore whose line is in the file now keeps .gitignore" [ "$(rowsof "$tmp/u25" ignore .stratum/lessons.md | cut -f4,5)" = "$(printf 'new\t.gitignore')" ]
check "U25 ignore whose only removed line has a prefix keeps .gitignore" [ "$(rowsof "$tmp/u25" ignore .stratum/powerline.json | cut -f4,5)" = "$(printf 'new\t.gitignore')" ]
audit "$tmp/u23"
check "U25 non-git folder pointer keeps CLAUDE.md" [ "$(rowsof "$tmp/u23" pointer @.stratum/constitution.md | cut -f5)" = CLAUDE.md ]
printf 'x\n' >> "$tmp/u25/.gitignore"
audit "$tmp/u25"
check "U25 uncommitted .gitignore wins over the lookup" [ "$(rowsof "$tmp/u25" ignore .stratum/models.json | cut -f4,5)" = "$(printf 'skip\t.gitignore has uncommitted changes')" ]
check "U25 no ignore or pointer name holds an ERE special character but ." [ -z "$(bash "$script" items | awk -F'\t' '$1 == "ignore" || $1 == "pointer" { print $2 }' | grep -E '[][(){}*+?|^$\\]')" ]

mkdir -p "$tmp/u26/.stratum" "$tmp/u26/.claude"
printf '{"permissions": {"allow": ["Skill(stratum:st-gone)"]}}\n' > "$tmp/u26/.claude/settings.json"
printf '{"permissions": {"allow": ["Skill(stratum:st-gone)"]}}\n' > "$tmp/u26/.claude/settings.local.json"
audit "$tmp/u26"
check "U26 audit gives the dead allow entry in both settings files" [ "$(rowsof "$tmp/u26" allow 'Skill(stratum:st-gone)' | cut -f4,5)" = "$(printf 'discontinued\t.claude/settings.json\ndiscontinued\t.claude/settings.local.json')" ]
jsonsum=$(sha256sum "$tmp/u26/.claude/settings.json")
run fix "$tmp/u26" allow ".claude/settings.local.json:Skill(stratum:st-gone)"
check "U26 fix of the local row exits 0 and changes that file" exits 0 contains "$out" "changed .claude/settings.local.json"
check "U26 the skipped settings.json row is byte-equal" [ "$jsonsum" = "$(sha256sum "$tmp/u26/.claude/settings.json")" ]
audit "$tmp/u26"
check "U26 second audit keeps only the settings.json row" [ "$(rowsof "$tmp/u26" allow 'Skill(stratum:st-gone)' | cut -f4,5)" = "$(printf 'discontinued\t.claude/settings.json')" ]

git init -q -b main "$tmp/u27"
mkdir -p "$tmp/u27-out"
printf 'auto\n' > "$tmp/u27-out/commit-mode"
ln -s ../u27-out "$tmp/u27/.stratum"
run fix "$tmp/u27" gone-file .stratum/commit-mode
check "gone-file through a .stratum symlink outside the checkout exits 3" exits 3 contains "$out" "skip: .stratum/commit-mode points outside $tmp/u27"
check "gone-file through a .stratum symlink keeps the outside file" [ -e "$tmp/u27-out/commit-mode" ]
rm "$tmp/u27/.stratum"
mkdir -p "$tmp/u27/.stratum"
ln -s ../../u27-out/commit-mode "$tmp/u27/.stratum/commit-mode"
outsum=$(sha256sum "$tmp/u27-out/commit-mode")
run fix "$tmp/u27" gone-file .stratum/commit-mode
check "gone-file on a commit-mode symlink removes the link" exits 0 [ ! -L "$tmp/u27/.stratum/commit-mode" ]
check "gone-file on a commit-mode symlink prints the link path" contains "$out" "changed .stratum/commit-mode"
check "gone-file on a commit-mode symlink keeps the target byte-equal" [ "$outsum" = "$(sha256sum "$tmp/u27-out/commit-mode")" ]

git init -q -b main "$tmp/u29"
mkdir -p "$tmp/u29/.stratum" "$tmp/u29/docs"
printf 'mine\n' > "$tmp/u29/docs/instructions.md"
ln -s docs/instructions.md "$tmp/u29/CLAUDE.md"
printf '{"feature_directory": null, "phase": null, "lane": null}\n' > "$tmp/u29/.stratum/state.json"
git -C "$tmp/u29" add -A
git -C "$tmp/u29" commit -qm init
rm "$tmp/u29/.stratum/state.json"
audit "$tmp/u29"
check "deleted tracked state.json is skip" [ "$(rowsof "$tmp/u29" file .stratum/state.json | cut -f4,5)" = "$(printf 'skip\t.stratum/state.json has uncommitted changes')" ]
printf '{"feature_directory": null, "phase": null, "lane": null}\n' > "$tmp/u29/.stratum/state.json"
printf 'user edit\n' >> "$tmp/u29/docs/instructions.md"
audit "$tmp/u29"
check "dirty target of a CLAUDE.md symlink is skip" [ "$(rowsof "$tmp/u29" pointer @.stratum/constitution.md | cut -f4,5)" = "$(printf 'skip\tdocs/instructions.md has uncommitted changes')" ]
printf 'mine\n' > "$tmp/u29/docs/instructions.md"
audit "$tmp/u29"
check "clean target of a CLAUDE.md symlink is new" [ "$(state "$tmp/u29" pointer @.stratum/constitution.md)" = new ]
run fix "$tmp/u29" pointer @.stratum/constitution.md
check "fix through a CLAUDE.md symlink prints the real file" exits 0 [ "$out" = "changed docs/instructions.md" ]

git init -q -b main "$tmp/u30"
mkdir -p "$tmp/u30/.stratum"
printf '.stratum/state.json\n' > "$tmp/u30/.gitignore"
printf '{}\n' > "$tmp/u30/.stratum/advisor.json"
git -C "$tmp/u30" add -A
git -C "$tmp/u30" commit -qm init
git -C "$tmp/u30" checkout -q --detach
rm "$tmp/u30/.stratum/advisor.json"
audit "$tmp/u30"
check "detached checkout with an ignored missing state.json keeps new" [ "$(rowsof "$tmp/u30" file .stratum/state.json | cut -f4,5)" = "$(printf 'new\tmissing')" ]
check "detached checkout with a tracked missing advisor.json is skip" [ "$(rowsof "$tmp/u30" file .stratum/advisor.json | cut -f4,5)" = "$(printf 'skip\tdetached HEAD, no branch to commit on')" ]

sp="$tmp/sp ace/0.7.0"
mkdir -p "$sp/statusline" "$tmp/u28/.stratum"
printf 'echo ran\n' > "$sp/statusline/st-statusline.sh"
cat > "$tmp/cfg/plugins/installed_plugins.json" <<EOF
{"version": 2, "plugins": {"stratum@stratum": [
{"scope": "local", "projectPath": "$tmp/u28", "installPath": "$sp", "version": "0.7.0"}
]}}
EOF
run fix "$tmp/u28" statusline statusLine
cmd=$(pyq "$tmp/u28/.claude/settings.local.json" 'd["statusLine"]["command"]')
check "statusline fix with a space in the install path quotes the script" exits 0 [ "$cmd" = "bash '$sp/statusline/st-statusline.sh'" ]
audit "$tmp/u28"
check "statusline with a quoted path is current on a second audit" [ "$(state "$tmp/u28" statusline statusLine)" = current ]
check "quoted statusline command runs the script" [ "$(bash -c "$cmd" 2>&1)" = ran ]
printf '{"statusLine": {"type": "command", "command": "bash '"'"'%s/statusline/st-statusline.sh'"'"'"}}\n' "$tmp/old cache" > "$tmp/u28/.claude/settings.local.json"
audit "$tmp/u28"
check "quoted statusline at an old path is outdated" [ "$(state "$tmp/u28" statusline statusLine)" = outdated ]

exit "$fail"
