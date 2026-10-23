# Contract: `skills/st-herdr-workspace/SKILL.md`

Thin skill (D2). The script makes every herdr call. Rule P1: keep each phrase in section 2 whole
on one line of the file, because the test greps it with `grep -qF`.

## 1. Content

- Frontmatter: `name: st-herdr-workspace`. `description:` says it opens a project folder as a new
  herdr workspace with the `full` or `basic` layout, on this machine or a saved machine, and gives
  trigger examples ("open a workspace for issue 32 in ~/Desktop/stratum-003", "open a
  parasat-staging workspace on the laptop", "template 1 with the three tabs").
- Heading: `# /stratum:st-herdr-workspace <folder> [machine] [full|basic] [claude|claude2]`.
- `Plugin root is two levels up from this skill's base directory.`
- Steps:
  1. Read from the request: the folder, the machine (label or id, as the user says it), the
     template (`full` by default; "template 1" or "the three tabs" means `full`), the agent
     (`claude` by default, `claude2` when asked).
  2. Pick the label (FR-009): the issue or task the workspace is for, `<number>-<short-name>`
     when an issue number is known; when the request names none, one first name, like a person
     (`ada`).
  3. Run the script with each value as one quoted argument.
  4. Show its output as it is. On a one-line failure, show the line and stop.
  5. After a failure, do not run it again: the report shows what exists, and a failed remote call
     may still have made something (herdr skill: inspect before retry).
- Make no herdr call yourself.
- The drift line (FR-013).

## 2. Phrase table (tests/test_on_demand.sh)

| Name | Phrase |
|------|--------|
| `#32 FR-001 skill` | `` bash <plugin root>/scripts/st-herdr-workspace.sh `` |
| `#32 FR-009 label` | `` `<number>-<short-name>` when an issue number is known `` |
| `#32 FR-009 label` | `one first name, like a person` |
| `#32 FR-002 default` | `` `full` by default `` |
| `#32 FR-008 default` | `` `claude` by default `` |
| `#32 FR-011 no calls` | `Make no herdr call yourself.` |
| `#32 FR-013 drift` | `` The layouts live in `scripts/st-herdr-workspace.sh`. The user's `~/.config/herdr/templates.sh` can drift from them. `` |
| `#32 stop` | `On a one-line failure, show the line and stop.` |
| `#32 no retry` | `After a failure, do not run it again` |

The phrase is the cell text inside its outer backticks, with no space at either end. Plus one
`check` that the file has `name: st-herdr-workspace` and a line starting
`# /stratum:st-herdr-workspace`.
