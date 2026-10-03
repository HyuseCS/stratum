# Procedure: issues

Forked from GitHub Spec Kit v1.1.0 `speckit-taskstoissues` (MIT). Stratum changes: project data lives in `.stratum/`, scripts and templates live in the plugin, extension hook sections are removed.

`<PLUGIN_ROOT>` is the absolute plugin root path your caller gives you. Run scripts from the project root. `{INPUT}` is the input your caller passed with this procedure.

## User Input

```text
{INPUT}
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. Run `<PLUGIN_ROOT>/scripts/check-prerequisites.sh --require-plan --require-tasks --include-tasks` from the project root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").
1. **IF EXISTS**: Load `.stratum/constitution.md` for project principles and governance constraints.
1. From the executed script, extract the path to **tasks**.
1. Get the Git remote by running:

```bash
git remote get-url origin
```

> [!CAUTION]
> ONLY PROCEED TO NEXT STEPS IF THE REMOTE IS A GITHUB URL

If no GitHub MCP server is connected, use the `gh` CLI (`gh issue list`, `gh issue create`) for the same steps.

1. **Fetch existing issues for deduplication**: Before creating anything, build the set of task IDs you are about to process from `tasks.md` (each is a `T` followed by **at least** three digits, e.g. `T001` — the `converge` procedure assigns new IDs with `T{M+1:03d}`, which is a floor rather than a cap, so once a file has more than 999 tasks the IDs are four digits or longer). Then use the GitHub MCP server's `list_issues` tool to look for issues that already cover those IDs. Do not pass a `state` value, since omitting it makes the tool return both open and closed issues. Request `perPage: 100` to keep the number of calls down, and since the tool uses cursor-based pagination, request pages with the `after` parameter (using the `endCursor` from the previous response). For each issue title, match it against the task ID pattern `\bT\d{3,}\b` (the `{3,}` accepts four-digit and longer IDs — with `\d{3}` a title containing `T1000` would not match at all, because the trailing `\b` cannot fall between two digits, so that task would be silently neither deduplicated nor created; word boundaries still stop a token like `ST001` from matching, and force the whole digit run to be consumed so `T100` can never match inside `T1000`; this also recognises titles written as `T001 ...`, `T001: ...` or `[T001] ...`) and, when it matches one of your task IDs, mark that ID as already having an issue. Stop paginating as soon as every task ID has been matched, or when there are no more pages, so you do not keep fetching the whole repository's issue history once all task IDs are accounted for. This bounds the number of calls on repos with large issue histories and still prevents duplicates when the command is re-run after `tasks.md` is regenerated or the skill is re-invoked.
1. For each task in the list, use the GitHub MCP server to create a new issue in the repository that is representative of the Git remote. Task lines in `tasks.md` start with a markdown checkbox, so first strip the leading `- [ ]` (and any `[P]` / `[US#]` markers) to recover the task ID and its description. Create the issue with a single canonical title of the form `T001: <description>`, with the ID written once followed by the task description (for example, the line `- [ ] T001 Create project structure` becomes the title `T001: Create project structure`).
   - **Skip** any task whose ID is already present in the set of existing issues from the previous step, and report it (for example, `T001 already has an issue, skipping`).
   - Only create issues for tasks that do not yet have a matching issue.

> [!CAUTION]
> UNDER NO CIRCUMSTANCES EVER CREATE ISSUES IN REPOSITORIES THAT DO NOT MATCH THE REMOTE URL
