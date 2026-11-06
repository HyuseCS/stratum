# Data Model: State writes from the hook only

## State file (`.stratum/state.json`)

A JSON object. The hook keeps every key it does not write.

| Key | Values | Writer after this feature | File |
|-----|--------|---------------------------|------|
| `risk` | `high`, `normal`, `low`, `none` | hook: `Lane:` marker, `risk <level>` prompt | main checkout: `dirname(git rev-parse --path-format=absolute --git-common-dir)/.stratum/state.json`; fallback: cwd-walked file only when `git` fails. When `git` works and the main file is missing or bad: no write, nothing created |
| `feature_directory` | `specs/<name>` (any name matching `[A-Za-z0-9._-]+`, no number needed) | hook: new-folder scan while `phase` is `define` and `define_before` is a list; unchanged otherwise | cwd-walked file |
| `phase` | `define` ... `close`, `fast`, `quick`, `done`, null | hook (existing); new: `done` from the `Phase: done` marker; `st-quick` agent (unchanged) | cwd-walked file |
| `lane` | `full`, `fast`, `quick`, `none` | hook (existing, unchanged) | cwd-walked file |
| `skill` | `st-build`, `st-worker`, `""` | hook (existing set); new: `""` from the `Build done.` marker | cwd-walked file |
| `skill_session` | session id | hook (existing, unchanged) | cwd-walked file |
| `define_before` | sorted list of folder names (strings), may be empty | hook only (new key, read only by the hook): set when Define starts with a description; removed when Define starts with none, and when the hook finds the new folder | cwd-walked file |

The cwd-walked file is the one the hook finds today: walk up from the input `cwd` to the first
folder that has `.stratum/` or `.git` (the walk at the top of `main` in `hooks/st-phase.py`).

### Rules

- The cwd-walked file missing, unreadable or not a JSON object: no key is written to it, and no
  output. The risk still goes to the main checkout's file when the walk found a `.stratum/` folder or
  a `.git` file (a linked worktree with no `state.json`).
- Write only when the new value differs from the stored one (a missing `skill` key counts as
  different from `""`, as the deleted script added it).
- Every write: `tempfile.mkstemp(dir=<state folder>, prefix=".state-")`, then `os.replace`, as the
  `save` function in `hooks/st-phase.py` does. One write per file per hook run.

### `feature_directory` transition (FR-004)

At Define start (UserPromptSubmit `/stratum:st-define <text>` or PreToolUse Skill `st-define`), in
the same write that sets `phase` to `define`:

- Description given (the prompt has non-blank text after the command, or `tool_input.args` is
  non-blank): `define_before` = the sorted list of all folder names in `<root>/specs/` (no name
  filter), or `[]` when there is none or `specs/` is missing.
- No description (a redo of the current feature): remove `define_before`.

Only on PostToolUse, only while `phase == "define"`:

1. `define_before` missing or not a list: stop, no write.
2. List `<root>/specs/`. New folders: folders whose name is not in `define_before`, fully matches
   `[A-Za-z0-9._-]+`, and that hold a file `spec.md`. Any other name (such as `x$(y)`) is ignored.
3. No new folder: stop, no write (the list stays for the next tool call).
4. One or more: set `feature_directory` = `specs/<name>` for the name that sorts last, and remove
   `define_before`, in one write.

`<root>` is the folder that holds the cwd-walked `.stratum/`. No folder name needs a number:
`apps-own-lockfiles`, `2420-parasat-area-step`, `1000-fix-x` and `012126_max-qty-per-package` all
work, and two folders may share a number.

Examples (scenarios 4 and 5, and the redo):

| Start | On disk | Result |
|-------|---------|--------|
| redo of `specs/013-x` (no description, `define_before` removed) | `013-x`, `015-y` with `spec.md` | stays `specs/013-x` |
| new Define, `define_before` `["013-x", "015-y"]` | `016-z/spec.md` written | `specs/016-z`, `define_before` removed |
| after that, `feature_directory` `specs/016-z`, no `define_before` | `013-x/spec.md` edited | stays `specs/016-z` |
| new Define, `define_before` `["013-x"]` | `014-a/` made, no `spec.md` yet | no change, list stays |
| new Define, `define_before` `[]` | `apps-own-lockfiles/spec.md` written | `specs/apps-own-lockfiles` |
| new Define, `define_before` `["013-x"]` | `x$(y)/spec.md` written | no change (name rule) |

## Transcript turn

The JSONL file at `transcript_path` (main session file, research R2).

- **Real user prompt**: a line with `type == "user"`, no `isMeta: true`, no `isSidechain: true`, and
  `message.content` that is a string, or a list with at least one block whose `type` is not
  `tool_result` (research R4).
- **Current turn**: the lines after the last real user prompt.
- **Turn boundary by `promptId`** (research R10): the backward read also stops at a `user` line whose
  `promptId` differs from the input's `prompt_id`, when both are present. This covers a prompt line
  that is not in the file yet, so the read never runs into the previous turn. At that stop, only the
  reply text after the first `user` line with the input's `prompt_id` counts. Reply text before it, or
  all reply text when no such line was read, is dropped: it can be the previous turn's last reply.
  With either value missing, the real-prompt rule alone sets the boundary. Assistant lines have no
  `promptId` and never stop the read.
- **Reply text**: the `text` of each `text` block in `message.content` of lines with
  `type == "assistant"` and no `isSidechain: true`, in file order. Every other line type is skipped,
  `api-request-blob` and `attachment` included.
- **Read bound**: read backward from the end in 64 KiB blocks; stop at the first real user prompt, at
  the first `user` line of another `promptId`, or after 16 MiB (research R3). No file, a bad line or a read error: that line or the whole read gives
  no text.
- **Stop**: append the input's `last_assistant_message` (a string) after the transcript text, since
  the transcript can lag (research R1).
- Not read when the input has `agent_id` (a subagent event, research R2).

## Marker lines

Matched per line of the reply text (`re.M`). Last match in the turn wins.

Shared parts (D1: A, extended):

- `PRE` = `^(?:\[[^\]\n]*\][ \t]*)?(?:- )?`: at the line start, an optional reply label such as
  `[Orchestrator] `, then an optional `- ` list bullet, in that order.
- `W` = ``(?:\*\*|`)?``: an optional `**` or backtick. It stands before the marker, and after it on the
  two whole-line markers. The opener and closer are not paired.

| Marker | Pattern | Effect |
|--------|---------|--------|
| Risk | `PRE W Lane: [A-Za-z]+, risk (high\|normal\|low\|none)\b`. The `(...)` reason tail after the level stays free text. The level matches without case and is stored lower case | `risk` = level |
| Phase done | `PRE W Phase: done\.? W [ \t]*$` | `phase` = `done`, any phase |
| Label clear | `PRE W Build done\.? W [ \t]*$` | `skill` = `""` |
| Risk prompt (UserPromptSubmit `prompt`) | whole prompt `\s*risk (high\|normal\|low\|none)\s*`, without case | `risk` = level |

(`PRE W` and `W` are written apart here for reading. In code they join with no spaces.)

Positive rows the tests hold, one per allowed form: plain line, `[Orchestrator] ` label, `- ` bullet,
`**` wrap, backtick wrap, and a final `.` on `Phase: done` / `Build done`.

Non-matches: `- Phase: done | Lane: full` and `Build done. Next: /stratum:st-close` (not the whole line
after the prefix), `Lane: full, risk extreme`, a marker inside a sentence (`I said Lane: full, risk low`),
a marker in a `tool_result`, an `isMeta` line, an `api-request-blob` line, a sidechain reply, or an
earlier turn.
