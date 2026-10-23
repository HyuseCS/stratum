# Data Model: Open a herdr Workspace From a Layout Template

No stored data. The entities live only for one run of `scripts/st-herdr-workspace.sh`.

## Template

Fixed in the script (D1). Not read from `~/.config/herdr/templates.sh`.

| Name | Tabs in order | Panes per tab (left, right) | Program per pane |
|------|---------------|-----------------------------|------------------|
| `full` (default) | `Main`, `Dev Servers`, `VM` | 2, 2, 2 | Main: `<agent>`, `lazygit`. Others: shell, shell |
| `basic` | `Main` | 2 | shell, shell |

- `<agent>` is `claude` (default) or `claude2` (FR-008). Any other value stops the run.
- Every tab and pane starts in folder `D` (FR-003).

## Target machine

| Field | Source | Rule |
|-------|--------|------|
| selector `m` | `--machine` | absent = this machine |
| `target` | `target` of the `herdr machine list --json` entry whose `label` or `id` equals `m` | the only value passed to `ssh` (D5) |
| answers | `herdr --machine m workspace list` exit 0 | else stop (FR-006) |

Local target needs `HERDR_ENV=1` (D8).

## Folder

| Field | Rule |
|-------|------|
| input | local: any folder path. Remote: starts with `/` or `~` |
| `D` | absolute path printed by the target probe. Used as every `--cwd` |
| git state | from porcelain v2: branch, clean or `n changed`, ahead and behind vs last fetch, or `no upstream`, or `not a git repo`. Never stops the run (D3) |

## Workspace label

`^[A-Za-z0-9][A-Za-z0-9._-]*$`. Required. Chosen by the skill: `<number>-<short-name>` for a known
issue, else one first name (FR-009).

## Made ids

`WS`, `T1..T3`, `P1..P6`, each from the JSON of the call that made it (FR-005). Missing or `null`
id = a failed call.

## Pane state in the report

| Program | State |
|---------|-------|
| `claude`, `claude2`, `lazygit` | `running` or `not seen` after the wait (D7; `pane process-info` foreground name, up to 10 s, D20) |
| `shell` | `-` |

## Run states

```text
parse -> pre-checks -> build -> focus -> running check -> read back -> report (exit 0)
   |          |           |
 exit 2    exit 1      stopped: line + partial report (exit 1), nothing closed
           (one line,
           nothing made)
```
