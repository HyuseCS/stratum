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
python3 -I - "$tmp/cfg/plugins/installed_plugins.json" "\$target" "\$scope" "$tmp/cfg/plugins/cache/stratum/stratum/0.7.0" <<'PY' || { echo '{"command":"update","outcome":"failed","message":"no record for this folder","failureCode":"not_found"}'; exit 1; }
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

printf '{"st-gone": {"model": "haiku"}, "st-build": {"model": "opus"}}\n' > "$tmp/proj/.stratum/models.json"
cat > "$tmp/proj/.claude/settings.json" <<'EOF'
{"permissions": {"allow": ["Skill(stratum:st-gone)", "Skill(stratum:x$(touch pwned))", "Skill(stratum:../x)", "Bash(npm test:*)", "mcp__plugin_stratum_figcraft__get_node", "mcp__plugin_stratum_figcraft__gone_tool"]}}
EOF
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
exit "$fail"
