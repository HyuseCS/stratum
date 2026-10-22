# Quickstart: Open a herdr Workspace From a Layout Template

Run from the project root. Contracts: [script](contracts/script.md), [skill](contracts/skill.md).

## 1. Automated checks (no herdr needed)

```bash
bash tests/test_herdr_workspace.sh
bash tests/test_on_demand.sh
bash tests/test_inspect.sh
```

Expected: every line `ok`, exit 0. The test file runs its own negative controls (contracts and
tasks T001, T005, T008): each prints `ok   NC<n> ... goes red`.

Expected red states between tasks:

| After task | Red | Why |
|------------|-----|-----|
| T001 | every case in `tests/test_herdr_workspace.sh` | the script does not exist |
| T003 | the `#32` rows in `tests/test_on_demand.sh` | the skill does not exist |
| T005 | the remote cases | no `--machine` path yet |
| T008 | the basic cases | no `basic` branch yet |

## 2. Local live run (SC-001, SC-003)

Prerequisites: run from a pane inside herdr (`echo $HERDR_ENV` prints `1`), `claude` and
`lazygit` on `PATH`.

```bash
time bash scripts/st-herdr-workspace.sh "$PWD" --label 32-herdr-workspace
```

Expected:

1. Exit 0. A new workspace `32-herdr-workspace` is in front.
2. The report has 1 `workspace`, 1 `folder`, 3 `tab` and 6 `pane` lines. Every pane `<cwd>` is
   `$PWD`. P1 says `claude running`, P2 says `lazygit running`.
3. Check by reading back (use the `WS` id from the report):
   `herdr tab list --workspace <WS>` shows `Main`, `Dev Servers`, `VM`, `pane_count` 2 each;
   `herdr pane list --workspace <WS> | jq -r '.result.panes[].cwd'` prints `$PWD` six times;
   `herdr pane process-info --pane <P1>` names `claude`, `--pane <P2>` names `lazygit`.
4. Note the `time` result. The wait bound (research R5, 10 s) must be longer than the time
   `claude` takes to show as running here. Write the measured time into research R5.
5. The script closes nothing. The user closes the test workspace by hand.

Negative live checks (nothing made, one line, exit 1):

```bash
bash scripts/st-herdr-workspace.sh /no/such/dir --label ada
bash scripts/st-herdr-workspace.sh "$PWD" --label ada --agent codex
HERDR_ENV= bash scripts/st-herdr-workspace.sh "$PWD" --label ada
bash scripts/st-herdr-workspace.sh "$PWD" --label ada --machine nosuchbox
```

After each: `herdr workspace list | jq '.result.workspaces | length'` is the same as before.

## 3. Remote live run (SC-002): needs a machine that answers

Blocked on 2026-10-23: `herdr machine status laptop --json` gives `"status":"error"`,
`ssh: connect to host 100.73.64.64 port 22: Connection timed out`.

Run only when `herdr --machine laptop workspace list` exits 0:

```bash
bash scripts/st-herdr-workspace.sh '~/Desktop/<project>' --label ada --machine laptop
herdr --machine laptop tab list --workspace <WS>
herdr --machine laptop pane list --workspace <WS> | jq -r '.result.panes[].cwd'
env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_TAB_ID -u HERDR_WORKSPACE_ID bash scripts/st-herdr-workspace.sh '~/Desktop/<project>' --label ada --machine laptop
```

Run the last command once from a terminal outside herdr. It must work the same as the first
(D8: the `--machine` path does not need `HERDR_ENV`). That run is the live proof of D8.

Expected: the same six panes on the laptop, every cwd the remote absolute path, P1 `claude
running`, P2 `lazygit running`. Then `bash scripts/st-herdr-workspace.sh '~/no-such' --label ada --machine laptop`
prints `Folder not found on laptop: ~/no-such` and makes nothing, even if that path exists here.
The user closes both remote test workspaces by hand.

## 4. Basic layout (US3)

```bash
bash scripts/st-herdr-workspace.sh "$PWD" --label ada --template basic
```

Expected: one tab `Main`, two `shell` panes in `$PWD`, no `pane run`. The user closes it.
