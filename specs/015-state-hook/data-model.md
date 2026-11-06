# Data Model: State writes from the hook only

## State file (`.stratum/state.json`)

A JSON object. The hook keeps every key it does not write.

| Key | Values | Writer after this feature | File |
|-----|--------|---------------------------|------|
| `risk` | `high`, `normal`, `low`, `none` | hook: `Lane:` marker, `risk <level>` prompt | main checkout: `dirname(git rev-parse --path-format=absolute --git-common-dir)/.stratum/state.json`; fallback: cwd-walked file only when `git` fails. When `git` works and the main file is missing or bad: no write, nothing created |
| `feature_directory` | `specs/NNN-<name>` | hook: `specs/` scan while `phase` is `define`; unchanged otherwise | cwd-walked file |
| `phase` | `define` ... `close`, `fast`, `quick`, `done`, null | hook (existing); new: `done` from the `Phase: done` marker; `st-quick` agent (unchanged) | cwd-walked file |
| `lane` | `full`, `fast`, `quick`, `none` | hook (existing, unchanged) | cwd-walked file |
| `skill` | `st-build`, `st-worker`, `""` | hook (existing set); new: `""` from the `Build done.` marker | cwd-walked file |
| `skill_session` | session id | hook (existing, unchanged) | cwd-walked file |
| `define_floor` | integer, 0 or more | hook only (new key, read only by the hook): set when Define starts with a description, removed when Define starts with none | cwd-walked file |

The cwd-walked file is the one the hook finds today: walk up from the input `cwd` to the first
folder that has `.stratum/` or `.git` (`hooks/st-phase.py:29-33`).

### Rules

- Missing file, unreadable file or not a JSON object: no write, no output.
- Write only when the new value differs from the stored one (a missing `skill` key counts as
  different from `""`, as the deleted script added it).
- Every write: `tempfile.mkstemp(dir=<state folder>, prefix=".state-")`, then `os.replace`, as
  `hooks/st-phase.py:61-64` does. One write per file per hook run.

### `feature_directory` transition (FR-004)

At Define start (UserPromptSubmit `/stratum:st-define <text>` or PreToolUse Skill `st-define`), in
the same write that sets `phase` to `define`:

- Description given (the prompt has non-blank text after the command, or `tool_input.args` is
  non-blank): `define_floor` = the highest `NNN` of the folders in `<root>/specs/` whose name starts
  with `^\d{3}-`, or 0 when there is none or `specs/` is missing.
- No description (a redo of the current feature): remove `define_floor`.

Only on PostToolUse, only while `phase == "define"`:

1. No `define_floor` (or not an integer): stop, no write.
2. List `<root>/specs/`. Candidates: folders whose name matches `^\d{3}-[a-z0-9-]+$` and that hold a
   file `spec.md`. Any other name (such as `999-x$(y)`) is ignored.
3. Pick the highest number. On a tie, pick the name that sorts last. Current number: the `NNN` of
   `specs/NNN-` in `feature_directory`, or none when the key is missing, empty or does not match.
4. Write `specs/<folder>` only when the picked number is higher than `define_floor` and the current
   number is none or lower than the picked number.

`<root>` is the folder that holds the cwd-walked `.stratum/`.

Examples (scenarios 4 and 5, and the redo):

| Start | On disk | Result |
|-------|---------|--------|
| redo of `specs/013-x` (no description, floor removed) | `013-x`, `015-y` with `spec.md` | stays `specs/013-x` |
| new Define, floor 15 | `013-x`, `015-y`, then `016-z/spec.md` written | `specs/016-z` |
| new Define, floor 15, `feature_directory` `specs/016-z` | `013-x/spec.md` edited | stays `specs/016-z` |

## Transcript turn

The JSONL file at `transcript_path` (main session file, research R2).

- **Real user prompt**: a line with `type == "user"`, no `isMeta: true`, no `isSidechain: true`, and
  `message.content` that is a string, or a list with at least one block whose `type` is not
  `tool_result` (research R4).
- **Current turn**: the lines after the last real user prompt.
- **Reply text**: the `text` of each `text` block in `message.content` of lines with
  `type == "assistant"` and no `isSidechain: true`, in file order. Every other line type is skipped,
  `api-request-blob` and `attachment` included.
- **Read bound**: read backward from the end in 64 KiB blocks; stop at the first real user prompt or
  after 16 MiB (research R3). No file, a bad line or a read error: that line or the whole read gives
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
