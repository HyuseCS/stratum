# Engine

The Design lane's new-look engine: hallmark. A swap to another engine changes this file, the
vendored skill, its `vendor.lock` entry, its `licenses/` file and `THIRD_PARTY_NOTICES.md` row,
`skills/st-sync/SKILL.md` step 5, `skills/st-status/SKILL.md` step 5, `README.md` and the
`DESIGN.md` D7 row (D8). `<engine>` is `<plugin root>/skills/st-hallmark`.

- **Skill.** Read `<engine>/SKILL.md` and follow it for every build. Its frontmatter has
  `disable-model-invocation: true` (D22), so it is never loaded with the Skill tool.
- **Questions.** It needs material, audience, use and tone. The brief carries all four, so it asks
  nothing. Material not given: its library photos stand in, and no number, quote or logo is
  invented. List that as assumed.
- **Deal.** `node <engine>/scripts/theme.mjs deal --genre <genre> --prompt "<brief>" --json`. The
  genre comes from the tone answer by the skill's genre rule (Ask once, Genre). Pictures:
  `<engine>/references/themes/<slug>.jpg`. Another three: add `--reroll <n>`, counting up.
- **Scaffold.** `node <engine>/scripts/theme.mjs scaffold <slug> --dealt "<n>/3, seed <seed>"`,
  with `--dir <folder>` when the project has a stylesheet folder. It writes `tokens.css` and
  `base.css`.
- **Build.** Follow the skill's Flow with the theme named by the brief and `DESIGN.md` as the
  locked system. Do not run its Step 1 questions, its hero review, its finish review,
  `scripts/install.mjs` or `scripts/install-hook.mjs`.
- **Image key.** With `TOGETHER_API_KEY` set, its comp step may run: take the first comp and ask
  nothing. Report "hallmark may have used your TOGETHER_API_KEY to make images; the brief went to
  Together AI." With no key: "No image key set." Test only `[ -n "${TOGETHER_API_KEY:-}" ]`.
  Never ask for, print or set the key.
- **Check.** If `CHROME_PATH` is unset, set it for the run to the first path that
  `command -v google-chrome google-chrome-stable chromium chromium-browser` prints. Then
  `node <engine>/scripts/sloplint.mjs <files> --render --json`, with
  `--url <dev server route>` in a framework project and `--scope app` or `--scope component`
  where the skill's scope rules say. Lint: findings whose evidence does not start with
  `[<width>px]`. Render check: findings whose evidence does. Each passes with 0 `FAIL` and 0
  `REFLEX`. A `REFLEX` waived by the skill's waiver rules passes and goes in the report.
  `summary.render` other than `ran` fails the render check.
- **Before.** For a change to a built screen, run the Check command once before the rebuild,
  with `--before`. It keeps the old screenshots in `.hallmark/before/`, which is never committed.
- **Picks.** The skill's Picks block.
- **Files.** `tokens.css` and `base.css` are committed if they changed. The screenshots in
  `.hallmark/shots/` and the rest of `.hallmark/` are never committed.
- **Detector map** (D21). Ids from the `antipattern` field of `impeccable detect --json`. `ignore:`
  are the rules the lint owns; the detector ignores them. `keep:` are the rules only the detector
  has.

ignore: side-tab border-accent-on-rounded overused-font gradient-text ai-color-palette cream-palette nested-cards bounce-easing shape-assembled-illustration dark-glow radial-halo radial-spotlight-glow icon-tile-stack italic-serif-display hero-eyebrow-chip kicker-above-heading numbered-section-labels em-dash-overuse marketing-buzzword aphoristic-cadence broken-image content-hidden-at-rest text-occlusion gray-on-color low-contrast line-length cramped-padding body-text-viewport-edge tight-leading skipped-heading heading-rhythm justified-text unbalanced-heading tiny-text undersized-ui-text
keep: flat-type-hierarchy blinking-cursor buried-raster hard-offset-shadow extreme-negative-tracking script-error edge-flush-cards first-viewport-column-overflow straggler clipped-overflow-container design-system-font design-system-color design-system-radius design-system-font-size gpt-thin-border-wide-shadow theater-slop-phrase pulsing-dot repeated-container-text oversized-h1 monotonous-spacing marquee text-overflow all-caps-body wide-tracking organic-clip-path repeating-stripes-gradient codex-grid-background
