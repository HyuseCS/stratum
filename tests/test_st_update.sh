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
echo "\$*" >> "$tmp/claude.log"
exit 9
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
{"permissions": {"allow": ["Skill(stratum:st-gone)", "Skill(stratum:x$(touch pwned))", "Bash(npm test:*)", "mcp__plugin_stratum_figcraft__get_node", "mcp__plugin_stratum_figcraft__gone_tool"]}}
EOF
audit "$tmp/proj"
check "U5 audit exits 0" [ "$rc" = 0 ]
check "U5 dead model key discontinued" exits 0 [ "$(state "$tmp/proj" models-key st-gone)" = discontinued ]
check "U5 live model key current" exits 0 [ "$(state "$tmp/proj" models-key st-build)" = current ]
check "U5 dead skill allow entry discontinued" exits 0 [ "$(statein "$tmp/proj" allow 'Skill(stratum:st-gone)')" = discontinued ]
check "U5 dead FigCraft allow entry discontinued" exits 0 [ "$(statein "$tmp/proj" allow mcp__plugin_stratum_figcraft__gone_tool)" = discontinued ]
check "U5 injected allow entry invalid" exits 0 [ "$(statein "$tmp/proj" allow 'Skill(stratum:x$(touch pwned))')" = invalid ]
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
exit "$fail"
