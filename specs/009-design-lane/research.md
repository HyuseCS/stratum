# Research: Design Lane

All facts below were read from the files named, on 2026-10-24. Hallmark was read through
`gh api repos/nutlope/hallmark/contents/...` at commit `7ec868225c6caa040558c321ee0fefa0e73f83a8`
(main, 2026-10-22). No hallmark code was run.

D20 and D21 were decided by the user on 2026-10-24 (decisions.md, O35 and O39). Research R2,
R12 and R13 follow them. Impeccable's detector was run only on scratch copies of hallmark's
fixture HTML, outside the repo.

## R1. Design file name

- Decision: `DESIGN.md` at the project root.
- Rationale: hallmark reads `design.md` or `DESIGN.md` at the root (`skills/hallmark/SKILL.md:56`,
  `references/flow.md:7`, `references/design-md.md` "If `design.md` or `DESIGN.md` exists at the
  root"). `st-impeccable document` writes `DESIGN.md` (`skills/st-impeccable/reference/document.md:1`).
  One name both see. The spec assumption is resolved.
- Alternatives considered: `design.md` (impeccable would not write it).
- Risk: a project whose `DESIGN.md` is an architecture doc (this repo has one) is read as a design
  file by hallmark. `document` asks before it overwrites (`document.md` "do not silently
  overwrite"), so no data is lost.

## R2. The four checks against the real tools (FR-008)

| Check | Real command | Concern | Pass rule (two highest levels) |
|-------|--------------|---------|--------------------------------|
| Lint | `node <st-hallmark>/scripts/sloplint.mjs <files> --render --json [--url <dev server route>]`, findings whose evidence has no `[<width>px]` prefix | generic patterns in the code | 0 `FAIL` and 0 `REFLEX` |
| Render check | the same run, findings whose evidence starts with `[<width>px]` (`scripts/sloplint-render.mjs:156-201`), widths 320 to 1920 (`:6`) | layout at each width | 0 `FAIL` and 0 `REFLEX`, and `summary.render` is `ran` |
| Audit | `st-impeccable audit`, dimensions 1 (Accessibility) and 2 (Performance) only (`reference/audit.md:11`, `:24`) | accessibility and speed | 0 `P0` and 0 `P1` (`audit.md:92-96`) |
| Critique | `st-impeccable critique` in full, run by the skill in the main session (R13), with the detector's sloplint-owned rules ignored (R12) | UX | 0 `P0` and 0 `P1` in Priority Issues (`critique.md:154`, `:627-636`) |

- Hallmark grades (`references/gates.md:16`): `FAIL` (Floor), `REFLEX`, `WAIVED`, `WARN`,
  `ANSWERED`, `NOTE`. `FAIL` and `REFLEX` are the two highest. sloplint exits 1 when either is
  above 0 (`scripts/sloplint.mjs:4421`), so the exit code is the lint and render pass. A `REFLEX`
  waived in the stamp with hallmark's rules (`gates.md` section 2) counts as a pass; the report
  lists each waiver.
- Lint and render check are one run. Running sloplint twice (with and without `--render`) would
  run the static gates twice. The lane splits the one run by the `[<width>px]` evidence prefix.
- `render tier not run: <reason>` (`sloplint.mjs:4383`, `summary.render: "not run: ..."`) is a
  failed render check, never a pass. The start check (R5) makes this rare.
- Audit dimensions 3 (Theming), 4 (Responsive) and 5 (Implementation Integrity) are not run.
  Responsive is the duplicate FR-008 names. Implementation Integrity runs `impeccable detect`
  (`audit.md:60`) a second time, and the detector has one owner, the critique (D21). Theming
  (tokens, hard-coded colors) is hallmark Floor rule 1 and gate 48 (`SKILL.md:20`), so sloplint
  owns it.
- Hallmark's own reviewers are its hero review and finish review in fresh context (`gates.md:239`,
  `SKILL.md:133`, `:146`). The lane does not start them.
- Impeccable P0 to P3 (`critique.md:631-636`): P0 blocking, P1 major. P0 and P1 are the two
  highest.
- Critique's final-question gate (`critique.md:258`) asks the user when it lists 3 or more
  Priority Issues. The lane runs with no user in the loop (FR-007), so the skill answers it with
  fixed answers: priority = P0 and P1 first, scope = blocking findings only. The report lists them
  as assumed answers.
- Critique writes a snapshot under `.impeccable/critique/` (`critique.md:198-213`). The lane does
  not commit it.

## R3. Where the lane's build runs

- Decision: a new agent, `agents/st-design.md` (opus; tools Read, Grep, Glob, Bash, Edit, Write).
  It reads the engine's `SKILL.md` as a file (D22) and runs no other skill, so it has no Skill
  tool.
- Rationale: `st-build` brief mode stops when the brief "grows beyond a small bounded change"
  (`agents/st-build.md:67`) and a page build is not small. It also loads `st-ui-ux` for every
  screen task (`agents/st-build.md:44`). D10 forbids changing `st-build`. The orchestrator does
  not implement (`skills/st/SKILL.md:8`). The main session keeps the grill, the gates and the
  commit, which need the user.
- Ripple (feature 005 pattern): `tests/test_inspect.sh:89` (14 to 15 agents) and its rename phrase at `:97`
  for `skills/st-init/SKILL.md:26`, `tests/test_model_hook.py:213-215`,
  `skills/st-model/SKILL.md:10-11`, README agent row (two-way check `tests/test_inspect.sh:114-118`)
  and model overrides lists (`README.md:200-202`, `:207`), `DESIGN.md` roles table. `hooks/st-models.py:8`
  reads `agents/`, so no hook edit. `tests/test_session_hooks.sh:40-43` and
  `tests/test_on_demand.sh:50` pass once the agent has its report tag and its skill.
- Alternatives considered: `st-build` with hallmark loaded (blocked by line 67 and D10); the main
  session builds (breaks the orchestrator rule).

## R4. Vendoring hallmark (FR-017, FR-018)

- Decision: copy upstream `skills/hallmark/` whole into `skills/st-hallmark/`. Change only the
  frontmatter: `name: hallmark` to `name: st-hallmark`, and add `disable-model-invocation: true`
  (D22). Keep `skills/st-hallmark/LICENSE`, add
  `licenses/hallmark.MIT.txt` (upstream root `LICENSE`, "Copyright (c) 2026 Hallmark
  contributors", MIT), a `THIRD_PARTY_NOTICES.md` row and a "Changes made" bullet, and a
  `vendor.lock` entry `"hallmark": { "repo": "nutlope/hallmark", "ref": "main", "commit": "<sha at
  vendoring>", "path": "skills/hallmark", "version": "2.0.0", "license": "MIT" }`.
- Vendored (T004): commit `7ec868225c6caa040558c321ee0fefa0e73f83a8`, still `main` on 2026-10-25.
  178 files copied. Each file but `SKILL.md` has the upstream blob hash, and `SKILL.md` differs
  only in the two frontmatter lines (quickstart section 3).
- Rationale: `st-sync` already loops over every `vendor.lock` entry and limits the log to `path`
  (`skills/st-sync/SKILL.md` step 1), so it lists hallmark's changes with no skill edit (US4
  scenario 5). The scripts use `<skill-dir>`-relative paths (`SKILL.md:35`, `:80`, `:95`), so no
  path rewrite.
- Size: 178 files, 6.8 MB. 5.5 MB are the 98 theme files (48 pictures that the deal step shows).
  `scripts/fixtures/` (about 200 KB) is not read at runtime (no reference in `theme.mjs` or
  `sloplint.mjs`), but keeping the folder whole keeps the `st-sync` diff simple.
- Not run by the lane: `scripts/install.mjs` (installs into `~/.claude/skills`),
  `scripts/install-hook.mjs` (edit-time hook), `scripts/imagegen.mjs` unless the user set
  `TOGETHER_API_KEY`.
- Hallmark's description says "Use when the user asks to build or design something new"
  (`SKILL.md:3`). `disable-model-invocation: true` keeps Claude from loading `st-hallmark` on its
  own in Fast, Full, Quick or `st-build` (D22, keeps D10). The user can still call it by name.
  `st-status` step 5 also lists `~/.claude/skills/hallmark` as a duplicate install.

## R5. Tool check (FR-015, SC-005)

- Decision: one script, `scripts/st-design-check.sh`, used by the lane at its start and by
  `st-status` step 4 (and so `st-init` step 10, which reuses step 4: `skills/st-init/SKILL.md:60`).
  One script means one list of tools.
- What it checks, copied from the code that uses the tools (`scripts/sloplint-render.mjs:7`,
  `:79-111`, `references/flow.md:117`):
  1. `node` 18 or later (`node -p process.versions.node`).
  2. `puppeteer-core` or `puppeteer`: `node_modules/` in the project, then `$(npm root -g)`.
     `command -v` cannot see a node module. The script skips `$HALLMARK_PUPPETEER`, which would
     put the engine's name in a lane file (FR-010); a user who relies on it alone sees "missing"
     and the harmless `npm i -g puppeteer-core`.
  3. Chrome or Chromium: `$CHROME_PATH` if the file exists, then `command -v google-chrome
     google-chrome-stable chromium chromium-browser`, then the macOS and Windows paths of
     `sloplint-render.mjs:7`.
- Output: one line per missing tool, `missing: <tool>. Install: <command>`, exit 1. All present:
  `design tools: ok`, exit 0.
- Install commands: `npm i -g puppeteer-core` (`flow.md:117`). Node and the browser by the
  package manager found first: `pacman` (`sudo pacman -S nodejs npm`, `sudo pacman -S chromium`),
  `apt-get` (`sudo apt install nodejs npm`, `sudo apt install chromium`), `dnf`
  (`sudo dnf install nodejs`, `sudo dnf install chromium`), `brew` (`brew install node`,
  `brew install --cask google-chrome`), `winget` (`winget install OpenJS.NodeJS.LTS`,
  `winget install Google.Chrome`); none found: `https://nodejs.org/en/download` and `set
  CHROME_PATH to a Chrome or Chromium binary`.
- This machine (the laptop, 2026-10-25): `/usr/bin/google-chrome-stable` present, no
  `/usr/bin/chromium`. The check finds the browser either way. `puppeteer-core` was absent from
  `npm root -g` on the desktop, so a live SC-005 run is possible.
- Hallmark looks for a browser only in `CHROME_PATH` and the 8 fixed paths
  (`sloplint-render.mjs:7`, `:105`), not on PATH. So engine.md sets `CHROME_PATH` from
  `command -v` for the run when it is unset, and a browser the check finds on PATH also renders.
- Puppeteer lookup: hallmark resolves `puppeteer-core` with `createRequire` from the project
  folder (`sloplint-render.mjs:79-93`), which also looks in every folder above it. The script
  walks up the same way (case K12).

## R6. Framework projects need a running dev server

- Decision: the lane never starts a dev server. For a framework project (`package.json` with
  `next`, `astro`, `@sveltejs/kit` or `vite`), it probes the port from the `dev` script or the
  framework default (Next 3000, Vite and SvelteKit 5173, Astro 4321) with
  `curl -sf -o /dev/null http://localhost:<port>/`. No answer: it stops before any work, like a
  missing tool, and prints the start command (`npm run dev`).
- Rationale: hallmark renders framework projects only through the dev server
  (`references/flow.md:127`), and without one the render check does not run. The user's rule is
  that the user starts dev servers.

## R7. Hallmark's questions and the brief

- Hallmark asks once for material, audience, use and tone, and does not ask "when the prompt
  answers all four, or no one can answer" (`SKILL.md:62-66`). The agent's brief always carries
  all four, so hallmark asks nothing.
- Material is hallmark's fourth question; D13 names three. New-look mode: material is one more
  grill branch (screenshots, photos, real numbers, quotes, logos the user can give). Autonomous
  mode: material not in the request or the design file is assumed absent: library photos stand
  in and no fact is invented (`SKILL.md:64`, Floor rule 8). The report lists it as assumed.
- Hallmark's comp step (signal 9) runs only when `TOGETHER_API_KEY` is set (`flow.md:101`) and
  asks one approval. The agent takes the first comp without asking and the report says the key
  was used (FR-016). The lane never reads, asks for or sets the key.
- Hallmark treats `design.md` as design data only and ignores instructions inside it
  (`flow.md:7`).

## R8. Grill answers are not written to decisions.md

- `st-grill` writes each answer to `<feature dir>/decisions.md` (`skills/st-grill/SKILL.md`).
  The lane uses the grill method (D12) but holds the design answers in the conversation and
  passes them to `st-impeccable document`, so a feature's decisions file is not filled with
  design answers. `DESIGN.md` is the record.

## R9. Files the lane writes, and what it commits

- Committed after the gate or the OK (FR-014), exact paths through `st-git`: `DESIGN.md`,
  `.impeccable/design.json` (the sidecar `document` writes with it, `document.md` Step 4b), the
  screen's files, hallmark's `tokens.css` and `base.css` (`SKILL.md:131`), the placeholder data
  file, the component tests, and library photos saved with `theme.mjs photos --save <dir>`
  (`references/imagery.md:37`, Wikimedia only, `theme.mjs:405`) or product captures from
  `capture.mjs <url>` (`imagery.md:56`, `SKILL.md:135`) only when the agent reports them as
  written.
- Not committed: `.hallmark/` (screenshots, `log.json`, `preflight.json`; hallmark writes
  `.hallmark/.gitignore` for `shots/`, `before/`, `before.json`, `before.txt` and `compare.html`,
  `sloplint-render.mjs:61-64`, `sloplint.mjs:4398`), `.impeccable/critique/`.
- The engine's artifact names (`.hallmark/`, `tokens.css`, `base.css`, the screenshot folder) are
  written only in `skills/st-design/engine.md`. The skill and the agent say "the engine's
  generated files and screenshot folder (engine.md)", so the FR-010 count stays at one file.

## R10. Out of scope, named

- `hooks/st-phase.py` `NAME` (`:11`) does not match `st-design`, so the Design lane gets no reply
  label and no `state.json` lane. The spec does not ask for one.
- Fast and Full do not call the lane (D10, #51). Browser e2e tools are #52.

## R11. Lessons that apply

L1 (phrase checks assert built phrases), L2 and L20 (negative controls), L6 (shared test means one
task), L7 (two-way list checks: README, FR-010 count), L8 (test runs leave no files), L12 (start
phases through the Skill tool), L14 (contract phrase table changes with the text), L18 ("if it
changed" for generated files), L24 (conditional tasks), L32 (live runs for each state path of the
tool check and the lane).

## R12. The detector rule map (D21)

- Source of the ids: the `id:` rows of `crates/foundation/src/registry.rs` (`ANTIPATTERNS`, lines
  32-694) in `pbakaus/impeccable` at the pinned commit `c4cfe52`, whose skill `VERSION` is
  `0.1.16`, the engine the desktop had installed (`~/.impeccable/bin/0.1.16/impeccable --version`:
  `0.1.16+engine`). The laptop has no engine binary: the launcher
  `skills/st-impeccable/scripts/impeccable` downloads it from GitHub releases on its first call.
  Run `skills/st-impeccable/scripts/impeccable engine-probe` once with network before T006. 62 ids. 61 appear in the binary's strings; `hard-offset-shadow` does not, so
  the source at the pin may be ahead of the binary. The map holds all 62: `hard-offset-shadow` is
  on `keep:`, where an id that never fires costs nothing.
- The id in `impeccable detect --json` output is the `antipattern` field (run on hallmark's
  fixtures: `ai-color-palette`, `border-accent-on-rounded`, `bounce-easing`, `cramped-padding`,
  `cream-palette`, `flat-type-hierarchy`, `gradient-text`, `low-contrast`, `overused-font`,
  `skipped-heading`). `ignores add-rule` uses the same ids (`gradient-text` ignored, then gone
  from the output).
- T006 run (2026-10-25, laptop, `impeccable-engine 0.1.16`, `detect --json --no-config` on a
  scratch copy of `skills/st-hallmark/scripts/fixtures/`, 43 findings): the same 10 ids fire.
  9 are on `ignore:`: `ai-color-palette`, `border-accent-on-rounded`, `bounce-easing`,
  `cramped-padding`, `cream-palette`, `gradient-text`, `low-contrast`, `overused-font`,
  `skipped-heading`. `flat-type-hierarchy` is on `keep:`. No id is unmapped.
- `impeccable detect --list-rules` exists upstream (`crates/detect/src/list_rules.rs`) but the
  0.1.16 binary prints nothing for it. A later engine will answer it.
- `ignores add-rule` accepts any string (`bogus-id-xyz` was added), so a wrong id fails silently.
  The runtime catch below finds it.
- The map (user's measurement, orchestrator decision of 2026-10-25), all 62 ids, written out in
  contracts section 2:
  - `ignore:` 35 ids, each the same as or partly the same as a sloplint gate: `side-tab`,
    `border-accent-on-rounded`, `overused-font`, `gradient-text`, `ai-color-palette`,
    `cream-palette`, `nested-cards`, `bounce-easing`, `shape-assembled-illustration`, `dark-glow`,
    `radial-halo`, `radial-spotlight-glow`, `icon-tile-stack`, `italic-serif-display`,
    `hero-eyebrow-chip`, `kicker-above-heading`, `numbered-section-labels`, `em-dash-overuse`,
    `marketing-buzzword`, `aphoristic-cadence`, `broken-image`, `content-hidden-at-rest`,
    `text-occlusion`, `gray-on-color`, `low-contrast`, `line-length`, `cramped-padding`,
    `body-text-viewport-edge`, `tight-leading`, `skipped-heading`, `heading-rhythm`,
    `justified-text`, `unbalanced-heading`, `tiny-text`, `undersized-ui-text`.
  - `keep:` 27 ids. 16 are detector-only: `flat-type-hierarchy`, `blinking-cursor`,
    `buried-raster` (raster under a wash), `hard-offset-shadow`, `extreme-negative-tracking`
    (crushed letter spacing), `script-error`, `edge-flush-cards` (scroller edge),
    `first-viewport-column-overflow`, `straggler`, `clipped-overflow-container`,
    `design-system-font`, `design-system-color`, `design-system-radius`,
    `design-system-font-size`, `gpt-thin-border-wide-shadow` (the "card shadow row"),
    `theater-slop-phrase`. 11 were unsure. For each, the sloplint gate checks a different thing
    or a person judges it, so sloplint does not own it: `pulsing-dot`, `repeated-container-text`,
    `oversized-h1`, `monotonous-spacing`, `marquee`, `text-overflow`, `all-caps-body`,
    `wide-tracking`, `organic-clip-path`, `repeating-stripes-gradient`, `codex-grid-background`.
- The map lives in `skills/st-design/engine.md` as two lines, `ignore:` and `keep:`. Checks with no
  new script: the test asserts 62 ids (35 and 27), each once, the two lines share none, and the
  16 detector-only ids are on `keep:`. At runtime, a detector id in critique's output that is on neither line is
  reported as an unmapped rule. At `st-sync`, after an impeccable or hallmark port, the skill
  diffs the map against `impeccable detect --list-rules` (or `registry.rs` at the new pin while
  the engine does not answer it) and rechecks any rule whose sloplint gate changed.
- Scope: `impeccable ignores add-rule <id> --local` writes `.impeccable/config.local.json` and
  adds that path to `.git/info/exclude` (seen in a scratch repo). No committed file and no
  `.gitignore` edit. In a folder with no `.git`, there is no exclude line. The skill adds only the
  ids not already listed (`impeccable ignores list`) before the first critique and removes only
  those after the last round, so the user's own detector runs are as before. The CLI scan and the
  browser overlay both read this file (`skills/st-impeccable/scripts/live-browser-ignores.js`
  header).

## R13. Where the impeccable checks run

- Decision: the skill runs `st-impeccable audit` (dimensions 1 and 2) and `st-impeccable
  critique` in the main session, through the Skill tool. The agent runs the engine, the build, the
  component tests and sloplint.
- Rationale: critique must run Assessment A and B as two isolated subagents whenever a subagent
  tool exists, and inline is a degraded run (`critique.md:8-9`). A subagent has no subagent tool,
  so inside `st-design` critique could never run in full (D21). `skills/st-build/SKILL.md:46`
  already has the orchestrator run the `st-impeccable` skill on changed screens. Both checks are
  read-only, so the orchestrator still does not implement.
- Fix round: the skill collects the blocking findings from the agent's report and its own two
  checks, starts `st-design` again with them, then runs step 3 again: audit, and `critique` in full,
  not only its detector. The skill keeps the round count (at most 2).
- Live server: critique's overlay step starts `impeccable live-server --background` when a browser
  can be driven (`critique.md:79`), each round, and injects the overlay through the browser.
  `live-server stop` takes no port (`impeccable live-server --help`). A bare `stop` also runs
  `live-inject --remove` on the project's entry file (`reference/live.md:318-321`,
  `critique.md:79`). `stop --keep-inject` stops only the server. No script tag went into a file,
  so that form leaves the project's files as they were. The skill runs it after each critique
  that printed connection JSON. Failure states: a server already running before the critique
  (critique picks a free port from 8400; the stop may stop that server too, and the report says
  so); a critique that prints no connection JSON (no stop runs, the report says the overlay did
  not run); a server that cannot start (critique reports the fallback signal; the report names
  it).

## R14. New-look flow with the theme branch (D20)

- The grill's tone answer gives the genre by hallmark's own rule (`SKILL.md:68`). The skill runs
  the engine's deal command (`theme.mjs deal --genre <genre> --prompt "<brief>" --json`, read-only
  but for reading `.hallmark/log.json`), shows the three themes with their pictures
  (`references/themes/<slug>.jpg`), and recommends one. "Another three" reruns it with
  `--reroll 1`, counting up.
- After the pick, the skill runs the engine's scaffold command (`theme.mjs scaffold <slug>
  --dealt "<n>/3, seed <seed>" [--dir <styles folder>]`, `theme.mjs` scaffold function), which
  writes `tokens.css` and `base.css`. This is a generator run, not hand-written code.
- `st-impeccable document` then runs in scan mode on the project with the grill answers as its
  Step 3 answers (`document.md` Step 3). It writes `DESIGN.md` and `.impeccable/design.json` and
  runs its Step 5 confirm, which is the first of the two stops (FR-006). With an existing
  `DESIGN.md`, the skill answers its refresh, overwrite or merge question with "overwrite" from
  the new-look request.
- The agent brief names the theme slug, so hallmark takes its "user named a theme" route
  (`SKILL.md:90`) and loads the theme file (`SKILL.md:104`).
- No PRODUCT.md is written. Seed mode, which would need it, does not run.
- A different direction at the gate goes back to the theme branch: a new deal, a new scaffold, a
  new `DESIGN.md` confirm. That is the same two-stop loop again (FR-006 "the same gate again").

## R15. Validation results (T019, SC-004)

Run on 2026-10-25 at `c5bd851` (branch `009-design-lane`), from the repo root. Negative controls
ran on scratch copies of the repo (`cp -r`), one fresh copy per control, outside the repo.

- Tests (quickstart section 1), each exit 0 and every line `ok`:

| Command | Result |
|---------|--------|
| `bash tests/test_design_check.sh` | 12 ok |
| `bash tests/test_design_lane.sh` | 31 ok |
| `bash tests/test_inspect.sh` | 65 ok |
| `bash tests/test_on_demand.sh` | 170 ok |
| `bash tests/test_session_hooks.sh` | 28 ok |
| `bash tests/test_model_files.sh` | 26 ok |
| `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_model_hook.py` | 35 tests, `OK` |
| `claude plugin validate .claude-plugin/plugin.json` | `Validation passed` |

- Negative controls (quickstart section 2). Each row was `ok` on the unbroken copy with the same
  command right before the break (exit 0), and `FAIL` after it (exit 1). N1 to N7 and N10 ran
  `ST_ROOT=<copy> bash <copy>/tests/<test file>`. N8 and N9 ran
  `ST_INSPECT_README=<copy>/README.md bash tests/test_inspect.sh`.

| Id | Break | Before | After |
|----|-------|--------|-------|
| N1 | puppeteer check deleted from `scripts/st-design-check.sh` | `ok K2 no puppeteer` | `FAIL K2 no puppeteer: exit 0, want exit 1` (K5 and K10 also fail: their want has the puppeteer line) |
| N2 | browser check moved before the node check | `ok K10 order` | `FAIL K10 order` (same exit, wrong line order) |
| N3 | Design row deleted from `skills/st/SKILL.md` | `ok FR-002 st` | `FAIL FR-002 st` |
| N4 | `hallmark` entry deleted from `vendor.lock` | `ok FR-017 lock` | `FAIL FR-017 lock` |
| N5 | `hallmark` added to `agents/st-design.md` | `ok FR-010 one place` | `FAIL FR-010 one place` |
| N6 | keep id `flat-type-hierarchy` added to the `ignore:` line | `ok FR-008 map` | `FAIL FR-008 map` |
| N7 | step 4 Design lane sentence deleted from `skills/st-status/SKILL.md` | `ok FR-015 st-status` | `FAIL FR-015 st-status` |
| N8 | README skills row `st-nothing` added | `ok README skills` | `FAIL README skills` |
| N9 | README agent row `st-design` deleted | `ok README agents` | `FAIL README agents` |
| N10 | `disable-model-invocation: true` deleted from `skills/st-hallmark/SKILL.md` | `ok FR-017 copy` | `FAIL FR-017 copy` |

No control turned another row red, except N1 as named.

- Vendored files (quickstart section 3, FR-018): `git diff --stat main -- skills/st-impeccable`
  prints nothing. The upstream tree at `7ec8682` has 178 blobs under `skills/hallmark/`, and
  `skills/st-hallmark` has 178 files. 177 files hash the same as upstream (`git hash-object`
  against the tree's `sha`). `SKILL.md` differs only in `name: hallmark` to `name: st-hallmark`
  and the added `disable-model-invocation: true` line (D22).
- `git status --porcelain --untracked-files=all` before this R15 edit listed only the local
  `.stratum/state.json` and `.stratum/commit-mode`. After it, it also lists
  `specs/009-design-lane/research.md`. No other file (lessons L8).
- Rerun on 2026-10-26 at `07c1166` on the PC, after change 001 and the live runs:
  - Section 1: the same commands, each exit 0 and every line `ok`. `tests/test_design_lane.sh`
    now prints 33 ok; the other counts are as in the table. The unittest prints `OK`, and
    `claude plugin validate` prints `Validation passed`. `git status` listed only the local
    `.stratum/commit-mode` and `brag-output/` files.
  - Section 2: N1 to N10 each green on a fresh unbroken copy (0 `FAIL`), then red on the named
    row after the break. N1 also turns K5 and K10 red, as before. This N2 moved the node check to
    the end, after the puppeteer check too, so K5 also turns red.
  - Section 3: no impeccable diff. 178 upstream blobs and 178 files. Every file but `SKILL.md`
    hashes the same as upstream, and `SKILL.md` differs only in the `name:` line and the added
    `disable-model-invocation: true` line.
- Fix rounds of each live run (quickstart section 4):

| Id | Task | Fix rounds |
|----|------|------------|
| L1 | T018 | Stopped at the start check, no build (2026-10-25, PC) |
| L2 | T018 | Reports only, no build (2026-10-25, PC) |
| L3 | T009 | 2, cap reached, 4 P1 open at the gate (`site`); 1 (`old`, second lane run) |
| L4 | T012 | 1; the follow-up change needed 0 |
| L5 | T012 | 2 |
| L6 | T015 | 0 (contact page); 1 (second request) |
| L7 | T018 | Stopped at the dev-server check, no build |
| L8 | T009 | 0, a change at the gate, not a fix round |
| L9 | T020 | 0 |

- L1 and L2 ran on 2026-10-25 at `5c08f54` on the PC, headless (`claude -p --plugin-dir <repo>`) in
  an empty git scratch site, with `puppeteer-core` not installed and Chrome present:
  - L1: `/stratum:st-design a pricing page` printed the line
    `missing: puppeteer-core. Install: npm i -g puppeteer-core` and stopped. `git status` was
    empty. The reply also had one sentence before the line and one after it. SC-005 holds: 0 work
    and 1 install command.
  - L2: `/stratum:st-status` listed under Tools: "The design lane needs `puppeteer-core`. Run
    `npm i -g puppeteer-core`." FR-015 holds: the exact install command. The quickstart expects
    the script line as printed. The agent wrote it in its own words. `git status` was empty.
  - Then `npm i -g puppeteer-core` (25.16.0). `st-design-check.sh` prints `design tools: ok`,
    exit 0.
- L3 and L8 ran on 2026-10-25 at `90e1869` on the PC, in empty git repos under
  `~/Desktop/design-runs/`, with `--plugin-dir <repo>`:
  - `site` (L3, user typed `/stratum:st-design <brief>`): new-look mode. 12 questions, one per
    message, each with a recommended option. 3 themes dealt (Coral, Kiln, Vellum); the user's
    own answer "Kiln, greyish like Coral" was taken as a light Kiln colourway. `DESIGN.md` and
    `.impeccable/design.json` shown for confirm before any build (stop 1). Build, then lint,
    render, audit and critique per round. Round 1: audit 1 P1, critique 27/36 with 2 P1. Round 2:
    critique 26/36 with 1 P1. Final: audit 3 P1, critique 1 P1. After 2 fix rounds it stopped at
    the gate with the 4 P1 open (FR-008 cap), screenshots, picks, the 4 checks, fixed, open and
    assumed answers (stop 2). The 35 temporary ignores were removed. Nothing committed. A short
    tool-approval outage stopped the audit agent once; the main session audited by reading the
    code, and the final audit raised 3 of its P2 items to P1.
  - L8: the session was forked headless (`claude -p --resume <id> --fork-session`) with
    `make the header smaller`. It rebuilt (heading 36 to 60px from 44 to 84px, `DESIGN.md`
    updated), ran lint, render, tests, detector, critique (26/36, 1 P1) and audit (2 P1), and
    showed the gate again. Ignores removed again, nothing committed.
  - Old way (`base`): `/stratum:st-ui-ux build <brief>, as a plain index.html`, headless. One
    `index.html`, no questions, no checks, no gate. Screenshots by headless Chrome at 1440 and
    375. The commit guard stopped its commit headless.
  - `old`: `/stratum:st-fast <brief>` stopped (no spec in `specs/`) and offered
    `/stratum:st-design`; the user picked it, so this is a second lane run, not the old way. Same
    stops. Round 1 fixed 1 audit P1 and 1 critique P1; round 2 checks were the detector, tests and
    screenshots, not a new full critique. Gate yes, commit `39f4677` held only the 8 reported
    paths, nothing under `.hallmark/` or `.impeccable/critique/`, ignores empty.
  - Each run: `curl -sf localhost:8400/health` failed (exit 7).
  - SC-001 pick between `base` and `site` screenshots, 2026-10-26: the user picked `site`
    (`site/.hallmark/shots/index-1440-full.png`), the lane's version. SC-001 passes.
- L4 and L5 ran on 2026-10-25 on the PC, headless (`claude -p`, replies by `--resume`,
  `--permission-mode bypassPermissions`), in `~/Desktop/design-runs/old` (the lane run that got
  yes and commit `39f4677`, so it has a committed `DESIGN.md`):
  - L4: `/stratum:st-design a class schedule page for adult beginners who book a class`. Mode
    autonomous, 0 questions. Report: screenshot, lint, render, audit, critique, tests (20 pass),
    fixed (2 critique P1 in round 1), open (P2), assumed answers, no picks line. The critique's
    closing questions were answered by the lane. `config.local.json` ignores empty after. Nothing
    committed; it asked for OK. Then `make the schedule denser`: a new build (6 sessions on the
    first screen, was 3), all four checks and tests again, a new report, no commit (FR-014). It
    named the conflict with `DESIGN.md` "Density is low" and did not edit it. It kept before
    screenshots in `/tmp/sched-before/`, outside the project.
  - L5: `/stratum:st-design another page`. Exactly 1 message: job, visitor and main action, with
    a recommended answer. After `go`: 0 messages until the report (2 fix rounds, all checks pass,
    no open P0 or P1, ignores removed, no commit). The report has a "Picks" line, which only the
    new-look mode should have (US2 review F2). It offered one commit for the uncommitted L4 and
    L5 work, or two.
- L7 and the T018 routing runs, 2026-10-25 on the PC, headless:
  - L7: `~/Desktop/design-runs/vite` (`package.json` with `vite`, `dev: vite`, nothing on 5173),
    `/stratum:st-design a page`: "Vite project. The dev server on port 5173 gives no answer.
    Start your dev server with `npm run dev`, then run /stratum:st-design again." `git status`
    empty.
  - Routing in `~/Desktop/design-runs/route` (one static `index.html` and a `.stratum/state.json`
    of `{}`; without `.stratum/` every case stops and asks for `/stratum:st-init`). Each case ran
    `claude -p "/stratum:st <task>" --max-turns 4`, the repo reset after each:
    - `add a pricing page`: `Lane: Design (new page: ... It needs no API, data or sign-in). Say
      "full", "fast", "quick" or "design" to override.`
    - `add a settings page that saves to the API`: `Lane: Full (new page plus API work: ...)`.
    - `fix the header spacing on the home page` (`--max-turns 12`): it went to the Quick lane
      (`stratum:st-quick` agent, a one-line fix, verified at 360 and 1280px) but printed no
      `Lane:` line. The commit stopped at the commit guard.
    - `add a pricing page, fast`: it printed `Lane: Design`, then said the Fast lane cannot run
      with no `specs/` (it would move up to Full) and recommended Design. The override was
      heard but not used, because Fast needs a spec here.
- L6 and L9, 2026-10-25 on the PC, headless; each grill question answered "yes" (the recommended
  option) by `--resume`:
  - L6: `~/Desktop/design-runs/code`, a committed `index.html` (navy `#14213d`, paper `#f4f1ea`,
    orange `#e85d04`, Space Grotesk and IBM Plex Sans), no `DESIGN.md`.
    `/stratum:st-design a contact page`: autonomous mode; the first message listed the code's
    colors, fonts, flat surfaces and 4px corners, then Q1. 6 questions, one per message, each
    starting from the code. The confirm message showed `DESIGN.md` and `.impeccable/design.json`
    and also asked the main action and the contact facts, and proposed `#c2410c` for button
    backgrounds (white on `#e85d04` is about 3.5:1). After yes: the page, all checks pass, 0 fix
    rounds, ignores removed, no commit. Then `/stratum:st-design a services and prices page`: 0
    questions, a report (1 critique P1 fixed in round 1), no commit.
  - L9: `~/Desktop/design-runs/uitest`, `devDependencies` `vite`, `vitest`,
    `@testing-library/dom`, `jsdom`; dev server started by the runner (`npm run dev`, port 5173)
    and stopped after. `/stratum:st-design a signup page for a pottery class newsletter`: new-look
    mode, 11 questions one per message, 3 themes, `DESIGN.md` confirm, then the gate with
    screenshots of `localhost:5173`. It wrote `signup.test.js` (5 tests with
    `@testing-library/dom`: labels, empty email, bad email, error clears, success and focus) and
    the report lists them. `npx vitest run`: 5 passed. 0 fix rounds, ignores removed, no commit.
- Routing re-runs, 2026-10-25, in `route` with `specs/001-site/spec.md` and `.stratum/state.json`
  naming it:
  - `add a pricing page, fast`: `Lane: Fast (you said "fast". By the table this is Design: a new
    page the site does not have yet). Say "design" to change it.`, then the `stratum:st-fast`
    agent. The override works when a spec exists.
  - `fix the header spacing on the home page`, run again: the `st-quick` skill and agent, and
    again no `Lane:` line (2 of 2 runs). Open: the Quick route skips the say line that
    `skills/st/SKILL.md` section 1 asks for. Change 001 (`42d7b06`) fixed the wording after this
    run: the say line now comes before the first lane skill or agent, Quick too. The live behavior
    is not re-run.
- Change 001 (`42d7b06`, `specs/009-design-lane/changes/001-live-run-gaps.md`) also fixes four
  small gaps from the live runs above: the L2 check line (`st-status` prints the script's lines
  word for word), the L5 picks line (the autonomous report has no picks), the old run's round 2
  critique (a fix round runs `critique` in full) and the L4 `/tmp` before-shots (the engine's
  Before step keeps them in `.hallmark/before/`). None is re-run live. At `42d7b06`,
  `tests/test_design_lane.sh` prints 33 ok and exits 0.
- FR-008 cap (open after 2 fix rounds, no loop): seen in L3 `site`. After round 2 it went to the
  gate with 4 P1 open and offered changes or yes.
- All live runs are recorded here, and the 2026-10-26 rerun passed. T019 is done.
