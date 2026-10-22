# Contract: `scripts/st-herdr-workspace.sh`

Bash and jq only. Calls `herdr`, `ssh`, `git`, `jq` and `sleep` by bare name, so a test can put
stubs first on `PATH`. Reads no `HERDR_*_ID` variable and never passes `--current`.

## 1. Usage

```text
st-herdr-workspace.sh <folder> --label <name> [--machine <label-or-id>] [--template full|basic] [--agent claude|claude2]
```

| Arg | Rule | Default |
|-----|------|---------|
| `<folder>` | First argument. Local: any path to a folder. Remote: starts with `/` or `~`. | required |
| `--label` | `^[A-Za-z0-9][A-Za-z0-9._-]*$` (FR-009). | required |
| `--machine` | A `label` or `id` from `herdr machine list --json`. | none (this machine) |
| `--template` | `full` or `basic` (FR-002). | `full` |
| `--agent` | `claude` or `claude2` (FR-008). Ignored by `basic`. | `claude` |

Exit codes: `0` workspace made (also when a program is `not seen`), `1` stopped (a pre-check or a
herdr call failed), `2` usage error (unknown option, missing value).

## 2. Pre-checks, in order (FR-006, FR-008, FR-009, D8)

Each failure prints exactly one line and exits 1 with no mutating herdr call. The only herdr
calls allowed before section 4 step 1 are `machine list --json` and `workspace list`.

| # | Check | Line printed (the script builds these words; tests assert them, lessons L1) |
|---|-------|------|
| 1 | `--label` given and shaped | `Label is required: --label <issue-or-name>.` / `Label must be letters, digits, dot, dash or underscore, and start with a letter or digit.` |
| 2 | template | `Template must be full or basic.` |
| 3 | agent | `Agent must be claude or claude2.` |
| 4a | local: `HERDR_ENV` is `1` | `Not inside a herdr pane. Run it from a herdr pane, or name a --machine.` |
| 4b | remote: folder starts with `/` or `~` | `A remote folder must start with / or ~.` |
| 4c | remote: machine in `herdr machine list --json` (`.label == m or .id == m`) | `Unknown machine: <m>. Saved: <labels, comma separated>.` |
| 4d | remote: `herdr --machine <m> workspace list` exits 0 | `Machine <m> does not answer: <first stderr line from herdr>` |
| 5 | folder exists on the target (probe, section 3) | `Folder not found on <local\|m>: <folder>` / `ssh to <target> failed: <first stderr line>` (ssh exit 255) |

## 3. Target probe (FR-006, FR-007, D3, D5)

One shell command `P` runs on the target: locally with `bash -c "$P"`, remotely with
`ssh -o BatchMode=yes -- "<target>" "$P"`, where `<target>` is the `target` field of the
matched `machine list` entry and nothing else.

```text
P = cd -- <Q> && pwd && { git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null || true; }
```

- `<Q>` is `printf %q` of the folder with one leading `\~` turned back into `~`, so `~` and
  `~/x y` expand on the target and every other character stays quoted (research R3).
- Line 1 of the output is the absolute folder `D`. Every `--cwd` in section 4 is `D`, never the
  raw input and never `~`.
- The rest is git porcelain v2. Git state text: `<branch>, clean|<n> changed, ahead <a>, behind <b> (as of last fetch)`;
  `<branch>, <clean|n changed>, no upstream`; or `not a git repo` (no `# branch.` line).
  Git state never stops the run (D3). No `git fetch` (research R4).

## 4. herdr calls (FR-001 to FR-005, FR-011, FR-012)

`H` is `herdr` locally and `herdr --machine <m>` remotely. Every call below goes through `H`.
Ids come only from the JSON of the call that made them (`jq -er`; a missing id is a failed call).

`full`:

```text
1  H workspace create --cwd D --label <label> --no-focus   -> WS, T1, P1
2  H tab rename T1 Main
3  H pane split P1 --direction right --cwd D --no-focus      -> P2
4  H pane run P1 <agent>
5  H pane run P2 lazygit
6  H tab create --workspace WS --cwd D --label "Dev Servers" --no-focus -> T2, P3
7  H pane split P3 --direction right --cwd D --no-focus      -> P4
8  H tab create --workspace WS --cwd D --label VM --no-focus -> T3, P5
9  H pane split P5 --direction right --cwd D --no-focus      -> P6
10 H workspace focus WS
11 H pane process-info --pane P1 / --pane P2, once per round, sleep 1, up to 10 rounds (D20)
12 H pane list --workspace WS                                 (read back cwd per pane)
```

`basic`: steps 1, 2, 3, 10, 12. No `pane run`, no running check.

Rules the test enforces:

- Exactly one `workspace create`. `--cwd D` on it, on every `tab create` and on every `pane split`.
- `workspace focus WS` is the last mutating call and comes once.
- `pane run` only on P1 (the agent) and P2 (`lazygit`), only in `full`.
- `pane process-info` only on P1 and P2, only in `full`, after `workspace focus`, at most 10 times each.
  `running` = a foreground process `name` is `claude` (P1, also for `claude2`) or `lazygit` (P2).
- Never: zero arguments, `close`, `reconnect`, `machine add`, `machine remove`, `machine enable`,
  `machine disable`, `server`, `--current`, `--session`, `--remote`.
- Remote: every call except `machine list --json` starts `herdr --machine <m>`.
- Local: no call has `--machine`.

A call that fails at or after step 1 stops the run: print `stopped: <first stderr line>`, then
the report of what exists (section 5), exit 1. No further mutating call, nothing closed, no focus.
The read back (step 12) still runs, since it is a read; its failure only puts `?` in the cwd
column. Step 12 does not run when step 1 itself failed (no `WS`).

## 5. Report (FR-010, SC-003)

Printed on stdout, one entity per line, fields separated by one TAB. The pane lines are stable
for the next feature (D10), which reads pane ids from them.

```text
workspace	<WS>	<label>	<local|m>
folder	<D>	<git state>
tab	<T1>	Main
pane	<P1>	<T1>	<claude|claude2>	<running|not seen>	<cwd>
pane	<P2>	<T1>	lazygit	<running|not seen>	<cwd>
tab	<T2>	Dev Servers
pane	<P3>	<T2>	shell	-	<cwd>
pane	<P4>	<T2>	shell	-	<cwd>
tab	<T3>	VM
pane	<P5>	<T3>	shell	-	<cwd>
pane	<P6>	<T3>	shell	-	<cwd>
```

- `<cwd>` is the pane's `cwd` from step 12. If step 12 fails or has no entry for the pane: `?`.
- On a stop, the report lists only the ids made so far, after the `stopped:` line.
- `basic`: the `workspace`, `folder`, `tab T1 Main` lines and two `shell` pane lines.
