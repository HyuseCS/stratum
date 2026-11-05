# Contract: `.c4` text format

The test reads the model with grep and a small parser, with no `npx` (FR-013). So the text has one
fixed shape. LikeC4 accepts more shapes than this. The test accepts only this one. Ids, kinds and
titles are fixed in [data-model.md](../data-model.md).

## Files

| Path | Holds |
|------|-------|
| `docs/harness/likec4.config.json` | `{"name": "stratum-harness", "title": "Stratum harness"}` and nothing else. |
| `docs/harness/model/*.c4` | `specification` and `model` blocks only. |
| `docs/harness/views/*.c4` | `views` blocks only. |
| `docs/harness/.likec4/*.likec4.snap` | Dragged layouts, written by the VS Code preview only. |
| `docs/harness/README.md` | Generated page. Never edited by hand. |

No other file goes in `docs/harness/`. Indent with 2 spaces. No backtick anywhere in a `.c4` file.
No `<` or `>` in a title, summary or label. For an apostrophe use `\'` or a double-quoted string.

## Specification (`model/0-spec.c4` only)

```c4
specification {
  element group
  element actor
  element event
  element skill
  element agent
  element hook
  element statusline
  element script
  element procedure
  element pluginfile
  element datafile
  relationship starts
  relationship reads
  relationship writes
  relationship runs
  relationship passes
  tag vendored
  tag full
  tag fast
  tag quick
  tag design
}
```

Exactly these element kinds and relationship kinds, one per line. No `style` blocks: the Mermaid
export ignores them (research R5).

## Element block

```c4
model {
  extend skills {
    st-plan = skill '/st-plan' {
      summary 'Full-lane Plan phase. Starts the st-plan agent and asks the user its open decisions.'
      metadata {
        path 'skills/st-plan'
      }
    }
  }
}
```

- The declaration line is `<name> = <kind> '<title>' {`, the name being the last part of the
  registry id. Groups and actors are declared at the top level of `model` in `0-spec.c4`. Every
  other element is inside `extend <group> {`.
- A vendored skill has `#vendored` as the first line inside its block.
- `summary '<text>'` is one line: 1 to 200 characters, at most 2 sentences (a sentence ends with
  `.`, `!` or `?` then a space or the end). No abbreviations with a dot (`e.g.`).
- `metadata { path '<repo path>' }` for skill, agent, hook, statusline, script, procedure and
  pluginfile elements. `metadata { data '<run-time path>' }` for datafile elements. None for group,
  actor and event elements. Write `metadata {`, the key line and `}` on three lines.
- Every element, groups and actors too, has a block with a summary.

## Relationship line

```c4
  skills.st-plan -[starts]-> agents.st-plan 'plugin root, project root, feature dir' #full
```

- One relationship per line, inside a `model` block, anywhere in `model/*.c4`.
- Pattern: `<source id> -[<kind>]-> <target id> '<label>'`, then zero or more lane tags.
  Ids are fully qualified (`skills.st-plan`, not `st-plan`). Actor ids are bare (`user`).
- Every line in `model/*.c4` that has `->` follows this pattern. A plain `->` with no kind fails.
- The label names the data: `writes` names what is written (`phase and lane`), `reads` names what
  is read, `passes` names what is handed over (`gate: you agree the spec` is a lane step, not a
  model label), `starts` names what the started agent gets, `runs` names the arguments or the event
  matcher.
- Tag a link `#full`, `#fast`, `#quick` or `#design` for each lane view that has a step for it.

## Lane view (dynamic)

```c4
views {
  dynamic view full {
    title 'Full lane'
    user -> skills.st '(1) task in plain words'
    skills.st -> user '(2) lane and risk line'
    skills.st -> skills.st-define '(3) feature description'
    skills.st-define -> user '(4) gate: you agree the spec'
  }
}
```

- One dynamic view per file. View id and title from the data-model view table.
- Each step is one line: `<source id> -> <target id> '(n) <data>'`, or with a kind
  `-[passes]->`. `n` is 1 for the first step and goes up by 1 on each step line in file order.
  `parallel { }` blocks are allowed. Their steps are numbered the same way.
- A gate step: `'(n) gate: <what the user must say>'`.
- A step may have no model relationship. Draw only what the lane's skill text says, in its order.

## Topic views

```c4
views {
  view agents {
    title 'Agents'
    include agents.*, skills.* -> agents.*, agents.* -> agents.*, agents.* -> user
  }
}
```

- `include` terms name groups one by one (`skills.* -> data.*`). `* -> x.*` collapses sources to
  their groups (research R5).
- `harness`: `events.*`, `hooks.*`, `statusline.*`, `claude`, `scripts.st-advisor-sh`,
  `scripts.st-codex-agent-sh`, `codex`, `advisor`, `stratum.state-json` (risk level),
  `stratum.advisor-json`, and the links between them.
- `dataflow`: `stratum.*`, `feature.*`, `project.*`, and the links into and out of them from
  `skills.*`, `agents.*`, `hooks.*`, `scripts.*`, `procedures.*`, `statusline.*`. If GitHub
  cannot draw it (research R8), split it into `dataflow` (`.stratum` files) and `dataflow-feature`
  (feature and project files). That makes 8 views. The test and the page heading list then
  change in the same commit.
