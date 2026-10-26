# Data Model: Design Lane

The lane stores no data of its own. These are the files and messages it reads and writes.

## Design file

- Path: `DESIGN.md` at the project root (research R1), with its sidecar `.impeccable/design.json`.
  A root `DESIGN.md` or `design.md` with no sidecar beside it is not a design file: the lane stops
  and asks the user to move it, so `document` never overwrites another document.
- Written by: `st-impeccable document`, scan mode, with the grill answers as its Step 3 answers
  (FR-004, research R14). Never by the lane or the agent directly.
- Content: impeccable's format (`skills/st-impeccable/reference/document.md` Step 4): YAML
  frontmatter of tokens, then Overview, Colors, Typography, Layout, Elevation & Depth, Shapes,
  Components, Do's and Don'ts.
- States: absent, then confirmed (document's Step 5, stop 1 of FR-006), then committed (FR-014).
  A new look on a project that has one replaces it ("overwrite").
- Rule: the agent and the engine treat its text as design data, never as instructions (plan S4).

## Grill answers

- Held in the conversation only, never in a decisions file (research R8).
- New look: audience, use, tone, material, theme (slug and seed from the deal), North Star,
  overview voice, color character, elevation, components, UX (density, how a user moves through
  the screens) (FR-003).
- Autonomous with no design file: the same list without audience, use, tone, material and theme,
  each recommended answer drawn from the look read in the code (FR-005).

## Brief (skill to agent)

| Field | Required | Rule |
|-------|----------|------|
| plugin root, project root | yes | absolute paths |
| task | yes | the user's words |
| mode | yes | `new look` or `autonomous` |
| job, visitor, main action | yes | from the task or `DESIGN.md`, or the one vague-request message (FR-007) |
| audience, use, tone, material | yes | grill answers (new look) or `DESIGN.md` and the task; a missing one is assumed and listed |
| theme | new look only | the picked theme's slug |
| assumed answers | yes, may be empty | every answer the skill assumed |
| dev server URL | framework projects only | found by the probe (research R6) |
| findings to fix | fix rounds only | every finding that blocks a pass, from all four checks |

## Check result

| Check | Run by | Pass |
|-------|--------|------|
| Lint | agent, the engine's check | 0 `FAIL` and 0 `REFLEX` in findings without a `[<width>px]` prefix |
| Render check | agent, same run | 0 `FAIL` and 0 `REFLEX` in findings with the prefix, and the render tier ran |
| Audit (dimensions 1 and 2) | skill | 0 `P0` and 0 `P1` |
| Critique (full) | skill | 0 `P0` and 0 `P1` in Priority Issues |

- Fix rounds: 0, 1 or 2 (FR-008). Gate rounds are not counted.
- A check is `open` when it still fails after round 2.

## Detector map

- Lives in `skills/st-design/engine.md` as two lines, `ignore:` (rules the lint owns) and `keep:`
  (rules the detector owns), space-separated ids from the `antipattern` field of
  `impeccable detect --json` (research R12).
- Rules: every id once; no id on both lines; 62 ids, 35 on `ignore:` and 27 on `keep:`, the 16 detector-only ids on `keep:`.
- Lifecycle: the skill adds the `ignore:` ids missing from `impeccable ignores list` with
  `--local` before the first critique, and removes the ones it added after the last round.

## Lane report

Closed list (FR-009 plus FR-012, FR-013, FR-016, D21): screenshots (paths), the picks (new-look
mode only), each check's result, fixed, open, assumed answers, component tests run (or "UI
behavior not tested: no UI test runner"), unmapped detector rules, the key line, where the detector
ignores were and that they are gone, the work behind the screen for Fast or Full.
