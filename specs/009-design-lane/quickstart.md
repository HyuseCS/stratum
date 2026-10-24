# Quickstart: Design Lane

Run from the repo root. Texts and cases are in [contracts/design-lane.md](contracts/design-lane.md).

## 0. Prerequisites

- node 18 or later, npm, Chrome or Chromium (this machine: node v24.14.1, `/usr/bin/chromium`).
- `puppeteer-core` is not installed on this machine. Section 4 L1 runs before it is installed;
  then run `npm i -g puppeteer-core` for L2 to L6.
- A scratch web project for the live runs, outside this repo:
  `mkdir -p "$SCRATCH/site" && cd "$SCRATCH/site" && git init -q`, where `$SCRATCH` is the
  session scratchpad.

## 1. Tests

```bash
bash tests/test_design_check.sh
bash tests/test_design_lane.sh
bash tests/test_inspect.sh
bash tests/test_on_demand.sh
bash tests/test_session_hooks.sh
bash tests/test_model_files.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_model_hook.py
claude plugin validate .claude-plugin/plugin.json
git status --porcelain --untracked-files=all
```

Expected: every line `ok`, the unittest `OK`, and `git status` lists only the feature's files
(lessons L8).

Red states before each build task (tasks.md names the task):

| After | Red |
|-------|-----|
| T001 | every K case of `tests/test_design_check.sh` (no script) |
| T003 | `FR-017 lock`, `FR-017 copy`, the `FR-017` phrase rows |
| T005 | `FR-010 one place`, `FR-008 map`, the `skills/st-design/engine.md` rows |
| T007 | the `FR-001` checks, the US1 rows of `skills/st-design/SKILL.md` and `agents/st-design.md`; `tests/test_inspect.sh` `15 agents`; `test_module_constants` |
| T010, T013 | the `skills/st-design/SKILL.md` rows of that story |
| T016 | the `skills/st/SKILL.md`, `skills/st-status/SKILL.md` and `skills/st-sync/SKILL.md` rows |

The `FR-015 st-init` row (`steps 4 and 5`) is green from the start: it guards a line that already
reuses `st-status` step 4.

## 2. Negative controls (lessons L2, L7, L20)

Run each on a scratch copy: `cp -r . "$SCRATCH/nc"`, break the file there, then
`ST_ROOT="$SCRATCH/nc" bash "$SCRATCH/nc/tests/<test file>"`. Right before each break, the same
command is green on the unbroken copy (lessons L25).

| Id | Break | Turns red |
|----|-------|-----------|
| N1 | delete the puppeteer check from the script | K2 |
| N2 | print the browser line before the node line | K10 |
| N3 | delete the Design row from `skills/st/SKILL.md` | `FR-002` |
| N4 | delete the `hallmark` entry from `vendor.lock` | `FR-017 lock` |
| N5 | add the word hallmark to `agents/st-design.md` | `FR-010 one place` |
| N6 | copy one `keep:` id onto the `ignore:` line | `FR-008 map` |
| N7 | delete the step 4 sentence from `skills/st-status/SKILL.md` | `FR-015` |
| N8 | add a README skills row `st-nothing` | `tests/test_inspect.sh` `README skills` |
| N9 | delete the README agent row `st-design` | `tests/test_inspect.sh` `README agents` |

N8 and N9 run `ST_INSPECT_README="$SCRATCH/nc/README.md" bash tests/test_inspect.sh`: that test
reads `ST_INSPECT_README`, not `ST_ROOT`.

## 3. Vendored files unchanged (FR-018)

```bash
git diff --stat main -- skills/st-impeccable
gh api "repos/nutlope/hallmark/git/trees/<sha in vendor.lock>?recursive=1" --jq '.tree[] | select(.type=="blob" and (.path|startswith("skills/hallmark/"))) | .path' | wc -l
find skills/st-hallmark -type f | wc -l
```

Expected: no impeccable diff; the two counts match (178 at `7ec8682`). Each file but
`SKILL.md` hashes the same as upstream (`git hash-object` against the tree's `sha`), and
`SKILL.md` differs only in the `name:` line.

## 4. Live runs (lessons L32; record each in research.md before its task is ticked)

| Id | Scenario | Steps | Expected |
|----|----------|-------|----------|
| L1 | SC-005 tool missing | before `npm i -g puppeteer-core`, run `/stratum:st-design a pricing page` in the scratch site | exactly the line `missing: puppeteer-core. Install: npm i -g puppeteer-core`, no file changed (`git status` empty) |
| L2 | `st-status` names it | same state, `/stratum:st-status` | the same line under Tools |
| L3 | SC-001 new look | in an empty scratch site, the brief "a booking page for a pottery studio in Porto", built once the old way with `/stratum:st-fast <brief>` in `$SCRATCH/old` (its `st-build` loads `st-ui-ux` at step 5; brief mode would stop at `agents/st-build.md:67`), once with `/stratum:st-design` in `$SCRATCH/site` | the grill asks one question per message, the theme branch shows 3 themes, `DESIGN.md` is shown for confirm before any screen; the gate shows screenshots and picks; the user picks the lane's version from the two sets of screenshots |
| L4 | SC-002 autonomous | in L3's site after yes, `/stratum:st-design a class schedule page for adult beginners who book a class` | 0 questions; report has screenshots, 4 check results, fixed, open, assumed answers, tests; `.impeccable/config.local.json` has none of the added ids after the run |
| L5 | SC-003 vague | same site, `/stratum:st-design another page` | exactly 1 message listing the missing job, visitor and main action; 0 messages after the answer until the report |
| L6 | US3 code look | a scratch site with a styled `index.html` and no `DESIGN.md`, `/stratum:st-design a contact page` | grill answers start from the code's colors and fonts; confirm; then the page; a second request runs no grill |
| L7 | dev server stop | a scratch Vite project with no server running, `/stratum:st-design a page` | the start-it line with `npm run dev`; no file changed |
| L8 | changes at the gate | in L3, answer "make the header smaller" at the gate | a new build, all four checks again, the gate again |

For each live run, also check: no live server left (`curl -sf localhost:8400/health` fails), the
commit holds only the reported paths (`git log -1 --name-only --format=`), and nothing under
`.hallmark/` or `.impeccable/critique/` is committed.
