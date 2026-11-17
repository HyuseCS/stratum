# Contract: rule text

The exact text the build writes. The `#111` rows of `tests/test_research.sh` grep these strings, so copy them byte for byte. "Keep" means the line stays as it is.

## C1. `skills/st-research/SKILL.md`

### Step 3, first paragraph

Old:

```text
3. Output path, in this order: the path the caller gives; else `<feature folder>/research.md` when the caller names a feature folder; else `.stratum/research/<short-name>.md`, with a short name of 2 to 4 lowercase words joined by hyphens. Never take the feature folder from `.stratum/state.json`.
```

New:

```text
3. Output path, in this order: the path the caller gives; else `<feature folder>/research/<short-name>.md` when the caller names a feature folder; else `.stratum/research/<short-name>.md`. A short name is 2 to 4 lowercase words joined by hyphens; in a feature folder, it is one that no file in `<feature folder>/research/`, no queue line in `<feature folder>/decisions.md` and no research that runs uses. Never take the feature folder from `.stratum/state.json`.
```

The second paragraph of step 3 (quote rule and `realpath` command): keep.

### Step 4, first line

Old start: `4. Show the scope, the questions, the output path and the plan file, if any.`

New start (one sentence added before it, rest of the step kept):

```text
4. From the grill in `/stratum:st-define`: show the brief in one line and start the research at once, with no OK; skip the rest of this step. Show the scope, the questions, the output path and the plan file, if any.
```

### Step 5

New, whole step:

```text
5. From the project root, note `git rev-parse HEAD`, `git status --porcelain --untracked-files=all -- . ':(exclude,glob).stratu[m]/state.json' ':(exclude,glob)<folder>/decisions.m[d]' ':(exclude,glob)<folder>/research/*.md'`, `git ls-files -s -- . ':(exclude,glob).stratu[m]/state.json' ':(exclude,glob)<folder>/decisions.m[d]' ':(exclude,glob)<folder>/research/*.md' | sha256sum` (the staged contents) and `git ls-files -z --modified --others --exclude-standard -- . ':(exclude,glob).stratu[m]/state.json' ':(exclude,glob)<folder>/decisions.m[d]' ':(exclude,glob)<folder>/research/*.md' | xargs -0 -r sh -c 'for f; do [ ! -e "$f" ] || sha256sum -- "$f"; done' _` (the contents of changed and untracked files that exist). `<folder>` is the feature folder the caller names, as a path from the project root, else `.stratum`.
```

### Step 6

Append this sentence at the end of the step:

```text
From the grill in `/stratum:st-define`, start it in the background and go back to the grill; do steps 7 and 8 when its report comes in.
```

### Steps 1, 2, 7, 8

Keep.

## C2. `skills/st-define/SKILL.md` step 1

Old line 24 (one line, indented 3 spaces):

```text
   When the grill needs `/stratum:st-research`, make the feature folder first: `specs/<NNN>-<short-name>`, with the next free number and the short-name rule of `<plugin root>/procedures/specify.md` steps 1 and 2, made with `mkdir -p`. Make it once per run and use it again for later research in the same run. Pass `<folder>/research.md` as the research path. Outside a redo, never use the feature in `.stratum/state.json` for it. In a redo (step 0.2), make no folder: pass `<feature_directory>/research.md` for the feature in `.stratum/state.json` that step 0.2 redoes.
```

New, five lines in this order, each indented 3 spaces. Line A is added by US1, line B is the old line 24 changed by US2, line C by US2, line D by US3, line E by US4.

A:

```text
   For a fact a grill question or the plan needs, take a quick look first (a file or two, or a search). When it does not find the fact, run `/stratum:st-research` (Skill tool) in the background with the fact as its scope, and ask the next question that does not need the fact. When a report comes in, show a short summary of its findings before the next question. These rules replace the research rule of `st-grill`.
```

B:

```text
   When the grill needs `/stratum:st-research`, make the feature folder first: `specs/<NNN>-<short-name>`, with the next free number and the short-name rule of `<plugin root>/procedures/specify.md` steps 1 and 2, made with `mkdir -p`. Make it once per run and use it again for later research in the same run. Pass `feature <folder>`, not a path. Outside a redo, never use the feature in `.stratum/state.json` for it. In a redo (step 0.2), make no folder: pass `feature <feature_directory>` for the feature in `.stratum/state.json` that step 0.2 redoes.
```

C:

```text
   At most 3 research runs at a time: put a further scope in a queue and start it, first in, first out, when one ends. Start no scope whose questions are in the brief of research that runs, waits in the queue, or is done.
```

D:

```text
   From the time the folder exists, the grill writes its decisions to `<folder>/decisions.md`.
```

E:

```text
   When the grill ends, before step 2, wait for all research that runs and show each finding that changes a grill answer or the scope. Do not start the queue: under `## Queued research` at the end of `<folder>/decisions.md`, write one line `- <short-name>: <scope and questions>` for each queued scope and each research that stopped or failed, with a short name that no file in `<folder>/research/` and no other queue line uses. Then read `<folder>/decisions.md` and show the user every line in it that this Define run did not write.
```

## C3. `skills/st-define/SKILL.md` gate

Old: `assumptions. Ask: "Do you agree the spec?" Edit and ask again until they say yes. Do not start`

New (one sentence added after `assumptions.`):

```text
assumptions. Name research that stopped or failed, and the queued scopes for Plan. Ask: "Do you agree the spec?" Edit and ask again until they say yes. Do not start
```

## C4. `skills/st-plan/SKILL.md`, new step 0.3

Add after step 0.2, step 0.2 kept:

```text
3. If `<feature dir>/decisions.md` has `## Queued research`, run `/stratum:st-research` (Skill tool) for each line under it in the form `- <short-name>: <scope and questions>` whose `<feature dir>/research/<short-name>.md` does not exist, with its scope and questions, `feature <feature dir>` and `path <feature dir>/research/<short-name>.md`, before step 1 of "Steps". A line in another form, such as `- D13 (Q12): ...`, is not a scope. Show the user each queue line before you run it. A short name that is not 2 to 4 lowercase words joined by hyphens is not a scope.
```

## C5. `procedures/plan.md`, Phase 0 first paragraph

Old:

```text
**Research from st-research.** If `FEATURE_DIR/research.md` has the line `Written by: st-research`, keep all its rounds and sections as they are and use its facts. Do not research again what it answers. Research only the unknowns it does not cover, and add your Decision/Rationale/Alternatives items under a `## Decisions` heading at the end of the file (add to it if it exists). With no such file, follow steps 1 to 3.
```

New, two paragraphs:

```text
**Research from st-research.** If `FEATURE_DIR/research/` has files, read each one and use its facts. Do not research again what they answer. Research only the unknowns they do not cover. Write `research.md` as your own file: a `## Sources` list that names each research file, then your Decision/Rationale/Alternatives items. Never copy their facts into it.

If `FEATURE_DIR/research.md` has the line `Written by: st-research`, keep all its rounds and sections as they are and use its facts. Do not research again what it answers. Research only the unknowns it does not cover, and add your Decision/Rationale/Alternatives items under a `## Decisions` heading at the end of the file (add to it if it exists). With `research/` too, put the `## Sources` list, which also names this file's rounds, before `## Decisions`. With neither, follow steps 1 to 3.
```

## C6. `tests/test_research.sh` command copies

The heredocs hold the step 5 commands with the literal `<folder>`:

```text
st:   git status --porcelain --untracked-files=all -- . ':(exclude,glob).stratu[m]/state.json' ':(exclude,glob)<folder>/decisions.m[d]' ':(exclude,glob)<folder>/research/*.md'
idx:  git ls-files -s -- . ':(exclude,glob).stratu[m]/state.json' ':(exclude,glob)<folder>/decisions.m[d]' ':(exclude,glob)<folder>/research/*.md' | sha256sum
hash: git ls-files -z --modified --others --exclude-standard -- . ':(exclude,glob).stratu[m]/state.json' ':(exclude,glob)<folder>/decisions.m[d]' ':(exclude,glob)<folder>/research/*.md' | xargs -0 -r sh -c 'for f; do [ ! -e "$f" ] || sha256sum -- "$f"; done' _
```

A block runs one with `bash -c "${cmd//<folder>/<relative folder>}"` from the repo root.

## C7. Harness model and README (D13, task T009)

Each pair is old, then new. Each old text occurs once in its file.

### `docs/harness/model/data.c4`: the `research-md` element gets a new summary, and a new element follows it

Old:

```text
      summary 'The decisions and reasons for the open questions of the plan. procedures/plan.md writes it in phase 0.'
      metadata {
        data 'specs/NNN-feature/research.md'
      }
    }
```

New:

```text
      summary 'A Sources list of the research files, then the decisions and reasons of the plan. procedures/plan.md writes it in phase 0.'
      metadata {
        data 'specs/NNN-feature/research.md'
      }
    }
    research-files = datafile 'specs/NNN-feature/research/<short-name>.md' {
      summary 'One file per research scope of a feature. The st-research agent writes each one, and procedures/plan.md reads them.'
      metadata {
        data 'specs/NNN-feature/research/<short-name>.md'
      }
    }
```

### `docs/harness/model/agents.c4` (line 269 at `7b18033`)

```text
  agents.st-research -[writes]-> feature.research-md 'rounds of facts in a feature'
```

```text
  agents.st-research -[writes]-> feature.research-files 'one file per scope in a feature'
```

### `docs/harness/model/procedures.c4` (line 118 at `7b18033`)

```text
  procedures.plan-md -[reads]-> feature.research-md 'st-research rounds and facts'
```

```text
  procedures.plan-md -[reads]-> feature.research-files 'research facts it names in Sources'
```

### `docs/harness/atlas/data.mjs`, structure F

```text
<code>research.md</code>, <code>data-model.md</code>
```

```text
<code>research.md</code>, <code>research/</code> (one file per research scope), <code>data-model.md</code>
```

```text
<code>feature.research-md</code>, <code>feature.data-model-md</code>
```

```text
<code>feature.research-md</code>, <code>feature.research-files</code>, <code>feature.data-model-md</code>
```

### `README.md` (line 196 at `7b18033`)

```text
specs/NNN-feature/       spec, plan, research, data model,
```

```text
specs/NNN-feature/       spec, plan, research, research/, data model,
```

Generated, not hand-edited: `docs/harness/atlas/atlas.html`, `docs/harness/atlas/SYSTEM.md` (atlas build) and `docs/harness/README.md` (`npx -y likec4@1.60.0 export markdown docs/harness`).
