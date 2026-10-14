# Quickstart: Run Stratum Steps On Demand

Run from the repo root `/home/hyuse/Desktop/stratum` unless a step says otherwise. Phrases:
[contracts/commands.md](contracts/commands.md) and [contracts/background.md](contracts/background.md).
Every scratch dir comes from `mktemp -d`. Set `PYTHONDONTWRITEBYTECODE=1` for every run (lessons L8).

## 1. Automated tests

```bash
export PYTHONDONTWRITEBYTECODE=1
bash tests/test_on_demand.sh
bash tests/test_inspect.sh
bash tests/test_model_files.sh
bash tests/test_session_hooks.sh
bash tests/test_verify.sh
python3 -m unittest tests/test_model_hook.py
python3 tests/test_phase_hook.py
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
| T001 | `test_on_demand.sh`: FR-001 to FR-004 checks, and `FAIL every agent has a command: st-debug st-git st-review st-test` | the 4 skills do not exist |
| T003 | `test_on_demand.sh` FR-006 and FR-007 checks; `test_inspect.sh` "13 agents" and the `Show a table of the 13 agents` phrase; `test_model_hook.py` `test_module_constants` | the 3 agents and their docs do not exist |
| T005 | `test_on_demand.sh` FR-008 checks | the hook line does not exist |
| T007 | `test_on_demand.sh` FR-009 check | `st-handoff` not changed |

## 2. Negative controls (each check can fail)

Run in T009. Each phrase control breaks one thing in a copy of the plugin and must turn exactly one
check red. A structure control turns its named checks red (C2 to C4 turn two). A control that leaves 0 `FAIL` lines is a check that cannot fail: fix the check.

```bash
export PYTHONDONTWRITEBYTECODE=1
s=$(mktemp -d)
cp -r agents skills hooks scripts sr-opus-5.md "$s/"
run() { ST_ROOT="$s" bash tests/test_on_demand.sh | grep '^FAIL'; }
echo "baseline: $(run | wc -l)"
while IFS='|' read -r file phrase; do
  cp "$s/$file" "$s/.bak"
  grep -vF -- "$phrase" "$s/.bak" > "$s/$file"
  echo "$(run | wc -l)  $(run | head -1)  <- $file: $phrase"
  mv "$s/.bak" "$s/$file"
done <<'EOF'
skills/st-review/SKILL.md|name: st-review
skills/st-review/SKILL.md|main..HEAD
skills/st-review/SKILL.md|Check each finding against the source before you show it
skills/st-test/SKILL.md|No current feature. Run
skills/st-test/SKILL.md|Run each test command it reports again
skills/st-debug/SKILL.md|scripts/st-verify.sh
skills/st-git/SKILL.md|git status --porcelain --untracked-files=all
skills/st-git/SKILL.md|Nothing to commit.
skills/st-git/SKILL.md|git log -1 --name-only --format=
agents/st-impeccable.md|Runs only audit in the background.
agents/st-ponytail-audit.md|You change no file and never commit.
agents/st-ponytail-debt.md|Write the ledger to a file
skills/st-handoff/SKILL.md|You are the fork.
EOF
```

Expected: baseline `0`, then `1` on every line, each naming its own check.

Structure controls, each on a fresh copy (`rm -rf "$s"`, `mkdir -p "$s"`, then the `cp` line again):

| # | Break | Expected red |
|---|-------|--------------|
| C1 | `printf -- '---\nname: st-nope\n---\n' > "$s/agents/st-nope.md"` | `FAIL every agent has a command: st-nope` |
| C2 | `sed -i 's/^tools: Read, Grep, Glob, Skill$/tools: Read, Grep, Glob, Edit, Skill/' "$s/agents/st-ponytail-audit.md"` | the FR-006 frontmatter and FR-007 no-edit checks of `st-ponytail-audit` |
| C3 | `sed -i 's/^tools: Read, Grep, Glob, Skill$/tools: Read, Grep, Glob, Bash, Skill/' "$s/agents/st-ponytail-debt.md"` | the FR-006 frontmatter and FR-007 no-Bash checks of `st-ponytail-debt` |
| C4 | `rm -r "$s/skills/st-ponytail-debt"` | `FAIL every agent has a command: st-ponytail-debt` and the FR-006 skill check |
| C5 | ``echo 'x (`stratum:st-git`)' >> "$s/skills/st-git/SKILL.md"`` | the FR-001 one-start-line check of `st-git` |
| C6 | `sed -i 's/except st-handoff/except handoff/' "$s/hooks/st-session-start.sh"` | `FAIL FR-008 rule` |

README control (copy, the repo file is not touched):

```bash
grep -vF '| `st-ponytail-debt` |' README.md > "$s/README.md"
ST_INSPECT_README="$s/README.md" bash tests/test_inspect.sh | grep '^FAIL'
```

Expected: exactly `FAIL README agents`.

## 3. Live checks in Claude Code (by hand, T010)

Scratch clone, so no commit lands in the real repo:

```bash
s=$(mktemp -d)
git clone -q -b 013-agent-skills /home/hyuse/Desktop/stratum "$s/p"
cd "$s/p"
git branch main origin/main
mkdir -p specs/900-demo
printf -- '- [ ] T001 Write tests/test_demo.sh: it runs scripts/demo.sh and expects the output hi. Run `bash tests/test_demo.sh`.\n- [ ] T002 Make scripts/demo.sh print hi. Run `bash tests/test_demo.sh`.\n' > specs/900-demo/tasks.md
printf '# Demo\n\n## User Story 1\nFR-001: scripts/demo.sh prints hi.\n' > specs/900-demo/spec.md
printf '{"feature_directory": "specs/900-demo", "phase": "done", "lane": null}\n' > .stratum/state.json
printf '<html><body><div onclick="go()">Go</div><img src="a.png"></body></html>\n' > index.html
printf '# Plan\n\n**Testing**: bash tests/test_demo.sh\n' > specs/900-demo/plan.md
git add specs/900-demo index.html .stratum/state.json
git -c user.name=t -c user.email=t@t commit -qm demo
claude --plugin-dir "$s/p"
```

If Stratum is also installed as a plugin, turn it off in `/plugin` for this test so only the
clone's copy runs.

In that session:

| # | Type | Expected |
|---|------|----------|
| L1 | `/stratum:st-test T001` | `st-test` writes `tests/test_demo.sh`. The main session runs `bash tests/test_demo.sh` again and shows it fails because `scripts/demo.sh` is missing (US1-2) |
| L2 | `printf 'echo hello\n' > scripts/demo.sh` in a shell, then `/stratum:st-debug T002` | `st-debug` fixes `scripts/demo.sh`. The main session prints one `ok test green, no added comments ...` line from `st-verify.sh` (US1-3) |
| L3 | `/stratum:st-git` | the changed files are listed and you are asked which to commit. Pick only `scripts/demo.sh`. `git log -1 --name-only --format=` shows only that file (US1-4) |
| L4 | `/stratum:st-git tests/test_demo.sh` | the commit's file list is shown and equals `tests/test_demo.sh` (US1-5) |
| L5 | `/stratum:st-git` with a clean tree | `Nothing to commit.` and no commit |
| L6 | `/stratum:st-review` | `st-review` runs on `main..HEAD`. Each finding shown was checked against the source; dropped ones are listed (US1-1) |
| L7 | set `"feature_directory": null` in `.stratum/state.json`, then `/stratum:st-review` | one line: `No current feature. Run /stratum:st-define.` Put the value back after |
| L8 | "run st-ponytail-debt in the background", then at once "what is 2+2?" | the agent row reads `st-ponytail-debt` from start to end. The 2+2 answer comes before the report. The report arrives. `git status --porcelain` is the same as before (US2-1, US2-2, SC-002, SC-003, SC-004) |
| L9 | "run st-ponytail-audit and an impeccable audit of index.html in the background" | two rows, `st-ponytail-audit` and `st-impeccable`, each with its own name. Both report. No file changed |
| L10 | "run st-define in the background" | one line saying it runs only in the main session. No agent starts (US2-3) |
| L11 | say "we decided the demo prints hi, not hello", then "write the handoff", then at once "what is 3+3?" | an agent row `Handoff` (type fork) starts. The 3+3 answer comes before it ends. `.stratum/handoff.md` names the hi/hello decision (US3-1, SC-003) |
| L12 | "I'm done for today" | the handoff is written in the main session (no new agent row) and the reply ends after the file is written (US3-2) |

Delete the scratch dir after: `rm -rf "$s"`.

Recorded (T010, 2026-10-15, headless `claude -p --plugin-dir` on a scratch clone, model sonnet):
L1 passed (test written, re-run fails with `FAIL: expected 'hi', got ''`), L5 passed
(`Nothing to commit.`), L7 passed (`No current feature. Run /stratum:st-define.`), L10 passed
(one line, no agent started). L2 to L4, L6, L8, L9, L11 and L12 need commit prompts or the
agent panel, so the user runs them while using the feature on real projects.
