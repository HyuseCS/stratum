# Quickstart: Harness Diagram

Run from the repo root. Prerequisites: `python3`, `bash`, and for the full check Node 22.22.3 or
later with `npx` (D9). The first `npx` run downloads `likec4@1.60.0` and needs the network.
Formats: [contracts/model-format.md](contracts/model-format.md). Checks:
[contracts/test-contract.md](contracts/test-contract.md).

## 1. The test passes (US2, US4)

```bash
bash tests/test_harness_model.sh
```

Expected: only `ok` lines, exit 0. On a machine with no `npx` or an older Node: `SKIP validate`
and `SKIP rebuild`, the other checks `ok`.

## 2. The page draws (US1, SC-002, SC-006)

1. Push the branch and open `docs/harness/README.md` on GitHub (the user pushes).
2. Expected: 7 headings, Full lane to Data flow, and each Mermaid block draws with no
   "Syntax error" or "Maximum text size" box.
3. In the Full lane diagram, read the steps `(1)`, `(2)` ... in order. Name Define, Plan, Inspect,
   Build and Close in order and each `gate:` step. Time it: under 2 minutes.
4. Open `README.md` on GitHub. Its Harness diagram section links to the page.

If Data flow does not draw, split it as model-format.md "Topic views" says.

## 3. The LLM reads the model (US2, SC-004)

1. Ask a new Claude Code session, with only `docs/harness/` as context: "From the model, which
   elements write `.stratum/state.json`?"
2. Compare with the code:

```bash
grep -n 'writes\]-> stratum.state-json' docs/harness/model/*.c4
grep -rlnE 'state\.json' skills agents hooks scripts statusline procedures
```

Expected: each file in the second list that writes `state.json` (not only reads it) has a
`writes` link in the first list, and the LLM's answer matches the first list.

## 4. Edit and rebuild (US3)

```bash
npx -y likec4@1.60.0 validate docs/harness
npx -y likec4@1.60.0 export markdown docs/harness
git diff --stat docs/harness/README.md
```

Expected: `Valid`, then a diff only where the model changed.

## 5. Drag and save (US3 scenario 1, check by hand)

1. Open the repo in VS Code with the LikeC4 extension. Open `docs/harness/views/1-full.c4` and its
   preview.
2. Drag one box. Save. Close and open the preview again.
3. Expected: the box stays where it was put, and `git status` shows a new
   `docs/harness/.likec4/full.likec4.snap`.
4. Run `bash tests/test_harness_model.sh nomcp rebuild`. Expected: `ok` (the snap file is allowed and
   does not change the page).

## 6. MCP server in a worktree (US3 scenario 3, check by hand)

1. Once per machine (the user runs it):
   `claude mcp add --scope user likec4 -- npx -y @likec4/mcp@1.60.0`
2. Start Claude Code in a worktree of this repo (for example `../stratum-078`).
3. Ask it to list the LikeC4 views with the likec4 MCP tools.
4. Expected: the 7 views of `docs/harness/`. If it finds no project, note it in `gaps.md` and give
   the server `-e LIKEC4_WORKSPACE=docs/harness` in the README command.

## 7. No harness change (FR-014)

```bash
git diff --stat main...HEAD -- skills agents hooks scripts statusline procedures templates .claude-plugin
```

Expected: no output.

## 8. Negative controls (US4)

Run the table in [contracts/test-contract.md](contracts/test-contract.md) "Negative controls" on a
copy:

```bash
c=$(mktemp -d) && cp -r . "$c/r" && mkdir "$c/r/skills/zz-probe" && ST_ROOT="$c/r" bash tests/test_harness_model.sh coverage-skills; rm -rf "$c"
```

Expected: `FAIL coverage-skills: skills/zz-probe has no element`, exit 1.
