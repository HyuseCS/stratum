# Procedure: plan

Forked from GitHub Spec Kit v1.1.0 `speckit-plan` (MIT). Stratum changes: project data lives in `.stratum/`, scripts and templates live in the plugin, extension hook sections are removed.

`<PLUGIN_ROOT>` is the absolute plugin root path your caller gives you. Run scripts from the project root. `{INPUT}` is the input your caller passed with this procedure.

## User Input

```text
{INPUT}
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run `<PLUGIN_ROOT>/scripts/check-prerequisites.sh --require-spec --template plan` from the project root and parse JSON for FEATURE_SPEC, IMPL_PLAN, FEATURE_DIR, and TEMPLATE (the active plan template path). If IMPL_PLAN does not exist, copy TEMPLATE to IMPL_PLAN. Never overwrite an existing plan.md.

2. **Load context**: Read FEATURE_SPEC and `.stratum/constitution.md`. Load IMPL_PLAN.

3. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Re-evaluate Constitution Check post-design

## Completion Report

Command ends after Phase 1 design. Report IMPL_PLAN path and generated artifacts.

Then list **open decisions**: choices that change scope, data, privacy, or cost and that the spec, constitution, and research do not settle. Number them. For each give the question, 2 options at most, and your recommendation. Do not guess them; the orchestrator brings them to the user and resumes you with the answers.

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Research each item** (do it yourself; you cannot start subagents):

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Define interface contracts** (if project has external interfaces) → `/contracts/`:
   - Identify what interfaces the project exposes to users or other systems
   - Document the contract format appropriate for the project type
   - Examples: public APIs for libraries, command schemas for CLI tools, endpoints for web services, grammars for parsers, UI contracts for applications
   - Skip if project is purely internal (build scripts, one-off tools, etc.)

3. **Create quickstart validation guide** → `quickstart.md`:
   - Document runnable validation scenarios that prove the feature works end-to-end
   - Include prerequisites, setup commands, test/run commands, and expected outcomes
   - Use links or references to contracts and data model details instead of duplicating them
   - Do not include full implementation code, model/service/controller bodies, migrations, or complete test suites
   - Keep this artifact as a validation/run guide; implementation details belong in `tasks.md` and the implementation phase

**Output**: data-model.md, /contracts/*, quickstart.md

## Key rules

- Use absolute paths for filesystem operations; use project-relative paths for references in documentation
- ERROR on gate failures or unresolved clarifications

## Done When

- [ ] Plan workflow executed and design artifacts generated
- [ ] Completion reported with plan path, generated artifacts, and open decisions
