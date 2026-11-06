Side note from building the harness model (#78): places where harness files disagree or a piece is missing.

- `skills/st-close/SKILL.md:32` says `st-close` records defer and drop in spec.md. `agents/st-close.md:47-48` only returns the list and has no record step.
- `skills/st-full/SKILL.md:11` names a Plan gate (the user answers its open decisions). The `## Gate` section of `skills/st-plan/SKILL.md:36-38` names no user gate, only the next phase.
- `docs/harness/model/data.c4:168` declares `specs/NNN-feature/gaps.md`, but no skill, agent, procedure, script, hook or template names `gaps.md`. The gap report is returned as findings instead (`procedures/converge.md:29`, `agents/st-close.md:47`).
- `procedures/tasks.md:67` says "Tests are OPTIONAL". `procedures/tasks.md:92` says every task ends with `Test:`, and `agents/st-build.md:40` needs a red test before each build.
- `procedures/specify.md:80` uses "the checklist template structure" with no path and no `resolve-template.sh` call. Only the spec template is resolved (`procedures/specify.md:38`), though `templates/checklist.md` exists.
- `skills/st-model/SKILL.md:11` lists `st-worker` as an agent. `agents/st-worker.md` does not exist, and `skills/st-status/SKILL.md:36` says it has no agents file.
- `agents/st-quick.md:48` sets `phase` in `.stratum/state.json` with no script (its tools include Edit, `:4`). Other writers use `scripts/st-state.sh` (`skills/st-close/SKILL.md:58`, `skills/st-fast/SKILL.md:41`).
- `skills/st-hallmark/SKILL.md:3,57` call the command `/hallmark`. The skill name is `st-hallmark` (`:2`).
- `skills/st-impeccable/SKILL.md:19,82` name `.claude/skills/st-impeccable/scripts`, which is not this plugin's layout. `:84,86` call `/impeccable`, not `/st-impeccable`.
- `skills/st-ponytail-help/SKILL.md:64,70` tell the user to update and read the upstream ponytail plugin, not Stratum.
- `agents/st-build.md:20` gives the Fast-lane path as `changes/NNN-name.md` with no feature folder. `skills/st-fast/SKILL.md:14` and `agents/st-fast.md:40` put it under `specs/<feature>/changes/`.
- `hooks/ponytail/ponytail-activate.js:106` copies `ponytail-statusline.ps1` on Windows, but `hooks/ponytail/` has no such file. The copy error is swallowed by the catch at `:165`.
- `hooks/ponytail/ponytail-statusline.sh` is only copied (`hooks/ponytail/ponytail-activate.js:125`). Nothing in the repo runs it, and `statusline/st-statusline.sh:43` reads `.ponytail-active` itself.
