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
2. Expected: 15 headings in the order of the data-model view table, Full lane to Data flow, and
   each Mermaid block draws with no "Syntax error" or "Maximum text size" box.
3. In the Full lane overview diagram, read the steps `(1)`, `(2)` ... in order. Name Define, Plan,
   Inspect, Build and Close in order and each `gate:` step. Expected: 4 gate steps, in this order:
   you agree the spec, you answer each open decision, OK to build, push. Time it: under 2 minutes.
   Then check that each phase diagram (Full lane: Define ... Full lane: Close) starts at `(1)`.
4. US1 scenario 3: find `st-build agent` in the Full lane: Build diagram and in the Fast lane
   diagram. Expected: in the Full lane its steps carry Full-lane data (tasks from `tasks.md`), in
   the Fast lane they carry Fast-lane data (tests from the change plan), and no step of one lane
   shows in the other. Do the same for `st-git agent` in the Full phase diagrams, Fast and Quick.
5. US1 scenario 5, check by hand in VS Code (needs the extension of section 5 step 1): open
   `docs/harness/views/1-full.c4` and the preview of the `full` view. Click the `/st-plan` box (or
   the step that starts Plan). Expected: the Full lane: Plan view opens. Go back, then do the same
   for one Design mode in the `design` view of `docs/harness/views/4-design.c4`.
6. Open `README.md` on GitHub. Its Harness diagram section links to the page.

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

1. Install the LikeC4 VS Code extension once (the user runs it; the PC does not have it today):
   `code --install-extension likec4.likec4-vscode`. Open the repo in VS Code. Open
   `docs/harness/views/1-full.c4` and its preview.
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
4. Expected: the 15 views of `docs/harness/`. If it finds no project, report it with the error
   text. A change to the README command (for example `-e LIKEC4_WORKSPACE=docs/harness`) is a
   decision for the user, as T020 says.

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

## 9. The system atlas (US5)

Layout and fields: [data-model.md](data-model.md) "Atlas". Run from the repo root. The build
needs the system-atlas skill installed at `~/.claude/skills/system-atlas` on this machine (the
user's PC and laptop). The skill's `build.mjs` and `template.html` are not in the repo (D17): the
build line copies them and `data.mjs` into a temp folder, builds there, and copies the two
outputs back.

1. Build and check the script:

```bash
t=$(mktemp -d) && cp ~/.claude/skills/system-atlas/assets/build.mjs ~/.claude/skills/system-atlas/assets/template.html docs/harness/atlas/data.mjs "$t" && node "$t/build.mjs" && cp "$t/atlas.html" "$t/SYSTEM.md" docs/harness/atlas/ && rm -rf "$t"
node -e 'const h=require("fs").readFileSync("docs/harness/atlas/atlas.html","utf8"); new Function(h.split("<script>")[1].split("</script>")[0]); console.log("script ok")'
```

Expected: `built SYSTEM.md + atlas.html · 13 open · 0 resolved · <n> structures · <n> decisions`,
then `script ok`. `ls docs/harness/atlas` shows exactly `SYSTEM.md`, `atlas.html`, `data.mjs`, and
`git status --short docs/harness` shows changes only in `docs/harness/atlas/`.

2. Check the chapter rule, the fields and the 13 questions:

```bash
node --input-type=module -e '
const { NODES, CH } = await import(process.cwd() + "/docs/harness/atlas/data.mjs");
const bad = [], shown = new Set();
for (const n of NODES) for (const k of ["one", "what", "how", "short", "kind"]) if (!n[k]) bad.push(`${n.code} has no ${k}`);
for (const n of NODES) if (n.short.length > 14) bad.push(`${n.code} short is over 14`);
if (CH.length !== 10) bad.push(`${CH.length} chapters, expected 10`);
CH.forEach((c, i) => {
  if (i < CH.length - 1 && c.reveal.length > 3) bad.push(`chapter ${i + 1} adds ${c.reveal.length}`);
  c.reveal.forEach((r) => shown.add(r));
  for (const h of c.flow || []) for (const x of [h[0], h[1]]) if (!shown.has(x)) bad.push(`chapter ${i + 1} flow uses ${x} before it is shown`);
});
if (CH.at(-1).flow !== null || CH.at(-1).reveal.length) bad.push("last chapter must add none and have flow null");
const q = NODES.flatMap((n) => n.cond || []).length;
if (q !== 13) bad.push(`${q} questions, expected 13`);
console.log(bad.length ? bad.join("\n") : "atlas ok");
process.exit(bad.length ? 1 : 0);'
```

Expected: `atlas ok`.

3. Check that each skill, agent, hook, statusline, script and procedure id of the LikeC4 model is
   in the `how` of exactly one structure:

```bash
node --input-type=module -e '
import { readdirSync, statSync } from "node:fs";
const { NODES } = await import(process.cwd() + "/docs/harness/atlas/data.mjs");
const id = (g, f) => g + "." + f.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const walk = (d) => readdirSync(d).flatMap((f) => statSync(`${d}/${f}`).isDirectory() ? (f === "__pycache__" ? [] : walk(`${d}/${f}`)) : [f]);
const ids = [
  ...readdirSync("skills").map((d) => "skills." + d),
  ...readdirSync("agents").filter((f) => f.endsWith(".md")).map((f) => "agents." + f.slice(0, -3)),
  ...walk("hooks").filter((f) => !f.endsWith(".pyc")).map((f) => id("hooks", f)),
  ...walk("statusline").map((f) => id("statusline", f)),
  ...readdirSync("scripts").filter((f) => f.endsWith(".sh")).map((f) => id("scripts", f)),
  ...readdirSync("procedures").filter((f) => f.endsWith(".md")).map((f) => id("procedures", f)),
];
const bad = ids.map((i) => [i, NODES.filter((n) => n.how.includes(`<code>${i}</code>`)).length]).filter(([, c]) => c !== 1);
console.log(bad.length ? bad.map(([i, c]) => `${i} is in ${c} structures, expected 1`).join("\n") : `all ${ids.length} ids in exactly one structure`);
process.exit(bad.length ? 1 : 0);'
```

Expected: `all 99 ids in exactly one structure`.

4. Open it from a static server (the user, or the orchestrator with a browser):
   `python3 -m http.server 8765 -d docs/harness/atlas`, then open
   `http://localhost:8765/atlas.html` at about 1280×800. Not from `file://`. Expected: chapter 1
   shows 2 structures and one moving flow, `Next ▸` adds at most 3 structures per chapter, chapter
   10 shows all with a flow picker (Full, Fast, Quick, Design lanes, a commit, All flows). The
   Open questions tab lists 13 ids `Q-<code><n>`, and no question is drawn on the map. Check the
   light theme and one "go inside" view. Stop the server with Ctrl+C.
5. Open the published atlas URL (the orchestrator publishes it, T031; the URL is in the handoff and
   project memory, not in the repo, D18). Expected: the same atlas.
6. Compare (SC-007), check by hand: answer "where does the Full lane ask me first?" and "which
   parts write `.stratum/state.json`?" once with the atlas and once with the LikeC4 views
   (`docs/harness/README.md`, VS Code preview). Say which form helped more and why.
