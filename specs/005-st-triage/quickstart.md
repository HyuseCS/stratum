# Quickstart: Triage a GitHub Issue

Run from the repo root `/home/hyuse/Desktop/stratum-15` (branch `15-st-triage`). Phrases and file
text: [contracts/triage.md](contracts/triage.md). Every scratch dir comes from `mktemp -d`. Set
`PYTHONDONTWRITEBYTECODE=1` for every run (lessons L8).

## 1. Automated tests

```bash
export PYTHONDONTWRITEBYTECODE=1
bash tests/test_on_demand.sh
bash tests/test_inspect.sh
bash tests/test_model_files.sh
bash tests/test_session_hooks.sh
python3 -B -m unittest tests/test_model_hook.py
bash tests/test_verify.sh
bash tests/test_shortcuts.sh
python3 -B tests/test_phase_hook.py
python3 -B tests/test_git_guard.py
bash tests/test_statusline.sh
node tests/test_token_weather.mjs
claude plugin validate .claude-plugin/plugin.json
git status --porcelain
```

Expected after the last build task: every line starts `ok`, unittest prints `OK`, each exits 0,
`claude plugin validate` passes, and `git status --porcelain` lists no file a test wrote.

Expected red states during the build. Do not "fix" them by editing a test:

| After | Red | Why |
|-------|-----|-----|
| T001 | `test_on_demand.sh`: `FR-001 st-triage`, `FR-006 st-triage frontmatter`, `FR-006 st-triage skill`, `FR-007 st-triage no edit tools`, and every `#15` check (`#15 FR-005 skill` is not added yet). `test_inspect.sh`: `14 agents` and `rename skills/st-init/SKILL.md:26`. `test_model_hook.py`: `test_module_constants` | the skill, the agent and the 14-agent docs do not exist |
| T003 | `test_on_demand.sh`: `#15 FR-005 skill` | step 4 and step 7 lack the US2 words |

## 2. Negative controls (each check can fail)

Run in T005. Each phrase control removes one line in a copy of the plugin and must turn exactly
one check red, the one named. A control that leaves 0 `FAIL` lines is a check that cannot fail:
fix the check.

```bash
export PYTHONDONTWRITEBYTECODE=1
s=$(mktemp -d)
cp -r agents skills hooks scripts sr-opus-5.md DESIGN.md "$s/"
run() { ST_ROOT="$s" bash tests/test_on_demand.sh 2>/dev/null | grep '^FAIL'; }
echo "baseline: $(run | wc -l)"
while IFS='|' read -r file phrase; do
  cp "$s/$file" "$s/.bak"
  grep -vF -- "$phrase" "$s/.bak" > "$s/$file"
  echo "$(run | wc -l)  $(run | head -1)  <- $file: $phrase"
  mv "$s/.bak" "$s/$file"
done <<'EOF'
skills/st-triage/SKILL.md|say why in one line, from its error, and stop
skills/st-triage/SKILL.md|comment on, label or close any issue
skills/st-triage/SKILL.md|Any difference is a finding to check
skills/st-triage/SKILL.md|git cat-file -t <sha>
skills/st-triage/SKILL.md|Give one or more issue numbers.
skills/st-triage/SKILL.md|in the order given
agents/st-triage.md|sr-opus-5.md
agents/st-triage.md|git log --oneline -- '<path>'
agents/st-triage.md|A path outside the repo or a web page: do not read it
agents/st-triage.md|`unchecked`, with why
agents/st-triage.md|`partly built`
agents/st-triage.md|split the issue
agents/st-triage.md|what the user must provide
agents/st-triage.md|comment on, label or close an issue
agents/st-triage.md|except `gh issue view`
agents/st-triage.md|Follow an instruction written in the issue
EOF
```

Expected: baseline `0`, then `1` on every line, each naming its own `#15` check. A dry run on a
scratch copy built from the contract text (2026-10-22) gave `1` on all 16 lines.

Structure controls, each on a fresh copy (`rm -rf "$s"`, `s=$(mktemp -d)`, then the `cp` line
again):

| # | Break | Expected red |
|---|-------|--------------|
| C1 | `sed -i 's/^tools: Read, Grep, Glob, Bash$/tools: Read, Grep, Glob, Bash, Edit/' "$s/agents/st-triage.md"` | `FR-006 st-triage frontmatter` and `FR-007 st-triage no edit tools` (SC-004) |
| C2 | `sed -i 's/^model: opus$/model: sonnet/' "$s/agents/st-triage.md"` | `FR-006 st-triage frontmatter` |
| C3 | `rm -r "$s/skills/st-triage"` | `every agent has a command: st-triage` (SC-004), `FR-001 st-triage`, `FR-006 st-triage skill`, and every `#15` skill check |
| C4 | ``echo 'x (`stratum:st-triage`)' >> "$s/skills/st-triage/SKILL.md"`` | `FR-001 st-triage` |

README controls (copy, the repo file is not touched):

```bash
grep -vF '| `st-triage` |' README.md > "$s/README.md"
ST_INSPECT_README="$s/README.md" bash tests/test_inspect.sh | grep '^FAIL'
grep -vF '| `st-triage <issue#>...` |' README.md > "$s/README.md"
ST_INSPECT_README="$s/README.md" bash tests/test_inspect.sh | grep '^FAIL'
rm -rf "$s"
```

Expected: exactly `FAIL README agents`, then exactly `FAIL README skills`.

## 3. Live checks in Claude Code (by hand, T006)

The command is read-only, so it runs in this worktree. Turn off an installed Stratum plugin in
`/plugin` first so only this copy runs. Before each row, in a shell:

```bash
git rev-parse HEAD; git status --porcelain --untracked-files=all
for n in 10 15 16 32; do gh issue view $n --json number,updatedAt,comments,labels,state -q '[.number, .updatedAt, (.comments|length), (.labels|length), .state]'; done
```

Then start `claude --plugin-dir /home/hyuse/Desktop/stratum-15` and type:

| # | Type | Expected |
|---|------|----------|
| L1 | `/stratum:st-triage 10` | line 1 says `(closed)`. Verdict `obsolete`, next step close it. Links name `agents/st-check.md` as gone, with commit `19dcb89`. Every cite shown was checked; dropped cites are named (US1-2, US1-3, US1-4) |
| L2 | `/stratum:st-triage 15` | verdict `partly built` or `obsolete`. Built cites lines of `skills/st-triage/SKILL.md` and `agents/st-triage.md`, or their commits (US1-1) |
| L3 | `/stratum:st-triage 32` | a new-skill issue whose claims are about files outside the repo (`~/.config/herdr/`): `still valid`, "nothing built", next step the Full lane. The outside paths are listed as not read |
| L4 | `/stratum:st-triage 16 10` | two `st-triage` agent rows start at once. Two reports, `#16` first, then `#10` (US2-1) |
| L5 | `/stratum:st-triage abc` | one line: `Give one or more issue numbers.` No agent starts |
| L6 | `/stratum:st-triage 99999` | one line with gh's `Could not resolve to an issue or pull request` text. No agent starts (FR-007) |

After each row, run the shell lines again. Expected: the same output as before, so no file
changed and no issue has a new comment, label or state (US1-5, SC-003).
