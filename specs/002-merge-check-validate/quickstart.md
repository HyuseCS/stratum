# Quickstart: Merge Check and Validate into Inspect

Run from the repo root `/home/hyuse/Desktop/stratum` unless a step says otherwise. Phrases and
rename rows: [contracts/st-inspect.md](contracts/st-inspect.md). Never run a step on a tracked
`specs/` dir. Every scratch dir comes from `mktemp -d`.

## 1. Automated tests

```bash
bash tests/test_inspect.sh
python3 -m unittest tests/test_model_hook.py
bash tests/test_model_files.sh
```

Expected after T020: every line starts `ok`, unittest prints `OK`, each exits 0.

Expected red states during the build (do not "fix" these by editing the tests):

| After | Red | Why |
|-------|-----|-----|
| T001 | every check in `test_inspect.sh` | new files missing |
| T002 to T007 | `test_module_constants`; `test_docs_cover_feature`, `test_st_model_skill_matches_hook`; `test_model_files.sh` "st-model names every agent" | 12 agents; README and st-model do not name `st-inspect` yet |
| T008, T009 | the above, plus the new US3 checks in `test_inspect.sh` | old files and names still there |
| T010 | the above except `test_module_constants` and the agent count | references not renamed yet |

## 2. Negative controls for the phrase checks (FR-012, lessons L1)

Each check must go red alone when its first phrase is removed. Run in T007, before the delete:

```bash
s=$(mktemp -d)
while IFS='|' read -r var file phrase; do
  grep -vF -- "$phrase" "$file" > "$s/copy"
  n=$(env "$var=$s/copy" bash tests/test_inspect.sh | grep -c '^FAIL')
  echo "$n  $phrase"
done <<'EOF'
ST_INSPECT_AGENT|agents/st-inspect.md|Duplicate requirements
ST_INSPECT_AGENT|agents/st-inspect.md|Vague words with no measure
ST_INSPECT_AGENT|agents/st-inspect.md|a story with no acceptance criteria
ST_INSPECT_AGENT|agents/st-inspect.md|Any break of a constitution MUST rule is CRITICAL
ST_INSPECT_AGENT|agents/st-inspect.md|a requirement with no task
ST_INSPECT_AGENT|agents/st-inspect.md|one concept with two names
ST_INSPECT_AGENT|agents/st-inspect.md|a test task placed after its build task
ST_INSPECT_AGENT|agents/st-inspect.md|Severity: critical, high, medium, low
ST_INSPECT_AGENT|agents/st-inspect.md|Coverage line: requirements covered by tasks / total, by tests / total
ST_INSPECT_AGENT|agents/st-inspect.md|Offer each fix, never apply it
ST_INSPECT_AGENT|agents/st-inspect.md|Do not install anything
ST_INSPECT_AGENT|agents/st-inspect.md|a named test that can fail
ST_INSPECT_AGENT|agents/st-inspect.md|Name each caller that breaks
ST_INSPECT_AGENT|agents/st-inspect.md|minors' data
ST_INSPECT_AGENT|agents/st-inspect.md|PASS, CONCERN or FAIL
ST_INSPECT_AGENT|agents/st-inspect.md|replace an older `## Validate` section
ST_INSPECT_AGENT|agents/st-inspect.md|Edit anything except the `## Validate` section of `plan.md`
ST_INSPECT_AGENT|agents/st-inspect.md|Line 1: the verdict and counts
ST_INSPECT_SKILL|skills/st-inspect/SKILL.md|Set `phase` to `inspect`
ST_INSPECT_SKILL|skills/st-inspect/SKILL.md|only `plan.md` may change
ST_INSPECT_SKILL|skills/st-inspect/SKILL.md|drop the false ones
ST_INSPECT_SKILL|skills/st-inspect/SKILL.md|Fixes to spec, plan or tasks go to the `st-plan` subagent
ST_INSPECT_SKILL|skills/st-inspect/SKILL.md|If any CRITICAL finding was fixed, run `st-inspect` once more
ST_INSPECT_SKILL|skills/st-inspect/SKILL.md|a simpler or better approach
ST_INSPECT_SKILL|skills/st-inspect/SKILL.md|OK to build?
EOF
```

Expected: every line starts with the baseline plus 1. Baseline: `bash tests/test_inspect.sh |
grep -c '^FAIL'` with no override (after T020 it is 0, so every line starts `1`). A line at the
baseline means that check cannot fail. A line above baseline plus 1 means two checks share a
line (contract rule P2).

Frontmatter and one-agent controls (T007):

```bash
s=$(mktemp -d)
sed 's/^model: opus$/model: sonnet/' agents/st-inspect.md > "$s/a"
ST_INSPECT_AGENT="$s/a" bash tests/test_inspect.sh | grep '^FAIL'
sed 's/^tools: .*/tools: Read, Grep, Glob/' agents/st-inspect.md > "$s/b"
ST_INSPECT_AGENT="$s/b" bash tests/test_inspect.sh | grep '^FAIL'
{ cat skills/st-inspect/SKILL.md; echo 'Start the `st-x` subagent (`stratum:st-x`).'; } > "$s/c"
ST_INSPECT_SKILL="$s/c" bash tests/test_inspect.sh | grep '^FAIL'
```

Expected: each command prints one FAIL line more than the baseline: the frontmatter check
twice, then the one-agent check.

Old-name search control (after T010 to T020 are committed, so the baseline is 0):

```bash
s=$(mktemp -d)
git clone -q . "$s/c"
echo 'see st-validate' >> "$s/c/README.md"
git -C "$s/c" add README.md
bash "$s/c/tests/test_inspect.sh" | grep '^FAIL'
```

Expected: one FAIL line, the old-name search.

## 3. Rename and the 10 agents (US3)

```bash
git grep -nwE 'st-(check|validate)' -- . ':!specs'
ls agents
```

Expected: the search prints nothing. `agents/` lists 10 files, `st-inspect.md` among them.
Then reload the plugin (`/plugin` or a new session) and type `/stratum:st-`: `st-inspect` is in
the list and `st-check` is not.

## 4. A model file that names an old agent (FR-010)

```bash
p=$(mktemp -d); mkdir "$p/.stratum"
for old in st-check st-validate; do
  echo "{\"$old\": {\"model\": \"opus\"}}" > "$p/.stratum/models.json"
  printf '{"cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"stratum:st-inspect","prompt":"p","description":"d"}}' "$p" | python3 hooks/st-models.py
done
echo '{"st-inspect": {"model": "opus"}}' > "$p/.stratum/models.json"
printf '{"cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"stratum:st-inspect","prompt":"p","description":"d"}}' "$p" | python3 hooks/st-models.py
```

Expected: the first two print `"permissionDecision": "deny"` with
`unknown agent "st-check". Allowed agents: st-build, st-close, st-debug, st-fast, st-git, st-inspect, st-plan, st-quick, st-review, st-test.`
(and the same for `st-validate`). The last one, the recovery, prints `updatedInput` with
`"model": "opus"` and no deny.

## 5. Planted gaps (SC-004, US1 acceptance 2 and 3, edge case 1)

Needs T002 to T020 committed: the clone copies HEAD only. Build a scratch clone with a copy of
feature 001 that has one cross-artifact gap and one missing tool:

```bash
s=$(mktemp -d)
git clone -q /home/hyuse/Desktop/stratum "$s/p"
cd "$s/p"
cp -r specs/001-agent-model-overrides specs/900-planted
printf '{"feature_directory": "specs/900-planted", "phase": "plan", "lane": "full"}\n' > .stratum/state.json
sed -i '/^- \[X\] T01[34] /d' specs/900-planted/tasks.md
sed -i '/^\*\*Testing\*\*:/a\\n**Lint**: `zqlint` 2.0 checks every hook file (`zqlint hooks/`).' specs/900-planted/plan.md
command -v zqlint || echo "zqlint missing, as planted"
grep -c '^## Validate' specs/900-planted/plan.md
git add specs/900-planted .stratum/state.json
git status --porcelain > "$s/before"
```

Expected: `zqlint missing, as planted`, and the count `1` (feature 001's plan already has a
`## Validate` section). FR-010 of the copy now has no task (T013 and T014 removed).

First confirm the session that runs the phase loads this repo's built plugin, not the installed
0.1.26 copy: `/stratum:st-inspect` is in its skill list and `/stratum:st-check` is not. If it is
not, load the repo as the plugin for that session before you go on.

Run the phase with `$s/p` as the project: in a Claude Code session started in `$s/p`, run
`/stratum:st-inspect`, or start the `stratum:st-inspect` subagent with plugin root
`/home/hyuse/Desktop/stratum`, project root `$s/p`, feature dir `$s/p/specs/900-planted`.

Then:

```bash
cd "$s/p"
git status --porcelain
git diff --stat
grep -c '^## Validate' specs/900-planted/plan.md
git diff specs/900-planted/plan.md
```

Expected:

- Exactly 1 agent started (the session's agent list), SC-001.
- The report names FR-010 with no task (coverage gap, C5), and `zqlint` not installed with no
  setup task (setup check, V1). Line 1 has a verdict. The report has a coverage line.
- `git status --porcelain` differs from `$s/before` only by ` M specs/900-planted/plan.md`.
- The `## Validate` count is still `1` (replaced, not appended).
- `git diff` changes only lines inside the `## Validate` section.

## 6. Advisor step (US2)

Read `skills/st-inspect/SKILL.md` step **Advisor**. Expected: it names the risks (missed auth
invariants, schema or contract breaks, hidden breaking changes) and the improvements (a simpler or
better approach, tasks to cut or merge), says the answers are findings checked against the
source, and that big ones go to the user before the gate. With an advisor set, run section 5
through `/stratum:st-inspect` and confirm the advisor is asked both kinds of question.

## 7. Release note (FR-011)

After T021:

```bash
grep '"version"' .claude-plugin/plugin.json
git log -1 --format=%B
```

Expected: `"version": "0.1.27"`, and the message equals contracts/st-inspect.md section 4 word
for word, with no trailer.

## 8. Mid-feature project (edge case 3)

In a scratch project whose `.stratum/state.json` says `"phase": "check"`, run
`/stratum:st-build`. Expected: one line that warns the order is unexpected, then the phase runs.
