# Quickstart: Orchestrator Starts Worker Sessions

Run from the project root (`/home/hyuse/Desktop/stratum-003`). Contracts:
[script](contracts/script.md), [skill](contracts/skill.md). Fields: [data-model.md](data-model.md).

## 1. Stub tests (no herdr, ssh or claude needed)

```bash
bash tests/test_st_worker.sh
bash tests/test_on_demand.sh
bash tests/test_inspect.sh
git status --porcelain
```

Expected: every line `ok` (308 at close), exit 0, and `git status --porcelain` shows nothing new from the runs
(lessons L8).

## 2. Live local run (US1, SC-001, SC-005; measures research R1, R4, R5, R6, R11)

Needs: a herdr pane (`HERDR_ENV=1`), Claude Code 2.1.302 or later, auto mode available.
Use a scratch base so the merge does not touch the feature branch. The live run used id T910, because the first two attempts of T900 left `../stratum-worker-t900` and its branch (research R1); use a fresh id when a folder or branch `worker-<id>` exists:

```bash
bash scripts/st-worktree.sh worker-demo-base demo      # prints ../stratum-003-demo
```

Open a pane in `../stratum-003-demo` and run these from there (the plugin root is
`/home/hyuse/Desktop/stratum-003`; `S=/home/hyuse/Desktop/stratum-003/scripts/st-worker.sh`):

```bash
printf 'Create demo/hello.txt with the one line hi.\n' > /tmp/t910.txt
printf 'worker-t910\tlocal\tworker-t910\tT910\n' > /tmp/roster.txt
time bash $S start T910 --task /tmp/t910.txt --test 'grep -qx hi demo/hello.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
```

Record in research.md:

1. `start` exit code, and whether a trust dialog showed (R4). Expected: exit 0, `state working`. Live: exit 0 in about 4.6 s, no trust dialog; `agent start` may first answer `agent_pane_busy`, which the script retries.
2. The worker pane shows `◎ /goal active` (R5: the pasted `/goal` ran as the command).
3. The commit: the worker commits with no dialog (D24), and `cat ../stratum-worker-t910/.stratum/git-guard.json` shows `{"commit":"auto","branch":"worker-t910"}`.
4. `bash $S wait T910` until `state finished`. Note every `state` line and how long the worker sat
   `idle` between goal turns, if at all (R6). Live: one `state finished` line after 133 s, the goal took one turn, so no idle gap was measured.
5. `bash $S result T910`: the four result lines; the pane text is not printed.
6. `git log --oneline worker-demo-base..worker-t910`: the worker's commit. Then
   `git merge --no-ff --no-edit worker-t910` and `grep -qx hi demo/hello.txt; echo $?` gives `0`.
7. `bash $S close T910`: `closed worker-t910` and `folder ... ready to remove`. Then all three are
   empty: `herdr agent list | jq -r '.result.agents[].name' | grep -x worker-t910`,
   `herdr tab list | jq -r '.result.tabs[].label' | grep -x worker-t910` (before #71:
   `workspace list`),
   `pgrep -af -- '-n worker-t91[0]'` (SC-005; the bracket keeps pgrep from matching the shell
   that runs it, lessons L21). The answer of `workspace close` (R1). Since #71 see section 2b.

## 2b. Worker tab live (#71, FR-001, FR-010, FR-018, SC-005; measures research R17)

Needs: this PC, a herdr pane (`HERDR_ENV=1`), the #71 script. Run from the orchestrator's own pane
(the plugin root is this checkout; `S=<project root>/scripts/st-worker.sh`). Pick an id with no
folder or branch `worker-<id>` yet (`git branch --list 'worker-t92*'`); T920 is used below.

```bash
herdr tab list --workspace "$HERDR_WORKSPACE_ID" | jq -c '[.result.tabs[] | {tab_id, label}]' > /tmp/tabs-before.json
printf 'Create demo/hello.txt with the one line hi.\n' > /tmp/t920.txt
printf 'worker-t920\tlocal\tworker-t920\tT920\n' > /tmp/roster-t920.txt
time bash $S start T920 --task /tmp/t920.txt --test 'grep -qx hi demo/hello.txt' --lane 'plain edit, no lane' --roster /tmp/roster-t920.txt
herdr tab list --workspace "$HERDR_WORKSPACE_ID" | jq -c '[.result.tabs[] | {tab_id, label}]'
herdr pane list --workspace "$HERDR_WORKSPACE_ID" | jq -c --arg t "<tab id from field 4 of the worker line>" '[.result.panes[] | select(.tab_id == $t) | {pane_id, cwd}]'
bash $S wait T920
bash $S result T920
bash $S close T920
herdr tab list --workspace "$HERDR_WORKSPACE_ID" | jq -c '[.result.tabs[] | {tab_id, label}]' > /tmp/tabs-after.json
diff /tmp/tabs-before.json /tmp/tabs-after.json && echo same-tabs
herdr workspace list | jq -r --arg w "$HERDR_WORKSPACE_ID" '.result.workspaces[] | select(.workspace_id == $w) | .workspace_id'
herdr agent list | jq -r '.result.agents[].name' | grep -x worker-t920; echo "agent grep exit $?"
pgrep -af -- '-n worker-t92[0]'; echo "pgrep exit $?"
```

Expected: `start` exit 0, the `worker` line's field 4 is a tab id in this workspace; the tab list
after `start` is the one before plus one tab labelled `worker-t920`, with no `Dev Servers` or `VM`
tab added; that tab has two panes, both with cwd `/home/hyuse/Desktop/stratum-worker-t920`, lazygit
in the right one (look at it). The user sees the tab in this workspace. `wait` ends
`state finished`, `result` prints the four lines. `close` prints `closed worker-t920` and
`folder /home/hyuse/Desktop/stratum-worker-t920 ready to remove`; `same-tabs` prints (the
orchestrator's own tab ids unchanged), this workspace id is still printed, the agent grep and pgrep
exit 1. Do not merge `worker-t920`: the folder and branch stay for the user to remove.

The user removes `../stratum-003-demo`, `../stratum-worker-t910` (next to the main checkout
`/home/hyuse/Desktop/stratum`, research R3) and the two branches when they want.

## 3. Question path live (US2, SC-003; measures R7)

Same setup. Run it through the skill ("run T901 in a worker") so the orchestrator decides each
question with the `/stratum:st` rule (D26). The task forces one small and one big question:

```bash
printf 'Ask with AskUserQuestion which word to write, options hi and hello, and write it to demo/q.txt. Then ask with AskUserQuestion whether to push the branch to origin, options yes and no; push only on yes.\n' > /tmp/t901.txt
printf 'worker-t901\tlocal\tworker-t901\tT901\n' > /tmp/roster.txt
bash $S start T901 --task /tmp/t901.txt --test 'test -s demo/q.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
bash $S wait T901           # expected: state blocked, exit 4, the question in the pane text
bash $S answer T901 --keys <n>   # small: the orchestrator answers; <n> is the option number of hi as the pane shows it
bash $S wait T901           # expected: state blocked again, the push question
                            # big: the orchestrator asks the user first; the recorded answer is no (nothing is pushed)
bash $S answer T901 --keys <n>   # <n> is the option number of no as the pane shows it
bash $S wait T901           # expected: state finished
```

The end-of-run list names the word question as answered by the orchestrator, and not the push
question. Then once more with the user typing the answer in the pane first: `answer` must print
`not blocked: working` and send nothing (US2 scenario 3). Record which keys or text reach the
free-text field of the dialog.

Recorded live (T008): the worker sets the option order, so read the number from the pane each
time. Both live keys were `1` (`hi` was option 1, and both push dialogs had `no` as option 1).
One key picks and submits the option; no `enter` is needed. Before the settle wait, `answer`
printed `state blocked` and exit 4 right after the key, because `blocked` lingers about 2 s. Now
`answer` waits up to 5 s for `working` first. The settled path was not re-run live: expect
`state working` and exit 0 after a dialog key. The scenario 3 run (user answers first) used T902.

## 4. Team live (US4, SC-004)

Two workers here, the second builds on the first. The live run used T912 and T913, because
`../stratum-worker-t902` already existed from section 3:

```bash
printf 'Create demo/a.txt with the line a.\n' > /tmp/t912.txt
printf 'Wait until worker-t912 has committed demo/a.txt (ask it by name with SendMessage), merge its branch, then create demo/b.txt with the content of demo/a.txt.\n' > /tmp/t913.txt
printf 'worker-t912\tlocal\tworker-t912\tT912\nworker-t913\tlocal\tworker-t913\tT913\n' > /tmp/roster.txt
bash $S start T912 --task /tmp/t912.txt --test 'grep -qx a demo/a.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
bash $S start T913 --task /tmp/t913.txt --test 'grep -qx a demo/b.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
```

Expected: both briefs hold both roster rows; worker-t913's transcript shows a SendMessage to
`worker-t912` and a `git merge worker-t912`; both finish. Then the skill's steps 8 to 11 merge
both in task order and close both. Live: both finished in 2 min 43 s, 2 goal turns each, no
question. The `/stratum:st-review` call was skipped in that run; only the commit listing and the
worktree tests ran (research R15).

## 5. Headless live (US5, SC-006; measures R12)

```bash
printf 'Create demo/h.txt with the line h.\n' > /tmp/t904.txt
git rev-parse HEAD
bash $S headless T904 --task /tmp/t904.txt --test 'grep -qx h demo/h.txt'
git rev-parse HEAD; git status --porcelain; pgrep -af -- '-n worker-t90[4]'
```

Expected: `headless worker-t904 success <turns> <cost>`, exit 0, the same HEAD before and after,
`demo/h.txt` untracked, no process. Record `num_turns` and how `--max-turns` counted the goal
turns. Live: `headless worker-t904 success 9 0.73994277`, 48 s, two goal turns (the quiet `grep -qx`
printed nothing, so the first turn had no evidence), `num_turns` counts model requests over both
turns (research R12).

## 6. Remote live (US3, SC-002), gated

Only when `herdr --machine laptop workspace list` exits 0. Needs the repo on the laptop at a
commit that holds this repo's `HEAD`.

```bash
bash $S start T905 --machine laptop --repo '~/Desktop/stratum' --task /tmp/t910.txt --test 'grep -qx hi demo/hello.txt' --lane 'plain edit, no lane' --roster /tmp/roster-laptop.txt
bash $S wait T905 --machine laptop
bash $S result T905 --machine laptop      # reads the file over ssh, then fetched worker-t905 <sha>
bash $S close T905 --machine laptop
```

Expected: every line as in section 2, the brief and result on the laptop, `git log worker-t905`
here after the fetch. If the laptop does not answer: `Machine laptop does not answer: ...`, one
line, nothing made (US3 scenario 3).

Live 2026-10-24 (laptop repo at 3275e07): `start` exit 0 in 10 s, `state working`; `wait` one
`state finished` after 31 s; `result` printed the four lines and `fetched worker-t905 865aca5`;
`git show worker-t905:demo/hello.txt` gives `hi` here; `close` printed `closed worker-t905` and
`folder ... ready to remove`; agent, workspace and pgrep checks on the laptop all empty. The no-answer
path was not run live.

## 6b. Worker tab on the laptop, new `st-workers` workspace (#71, US3, FR-001, FR-010, FR-018, D35, D37; measures research R17)

Only when `herdr --machine laptop workspace list` exits 0. Needs, on the laptop: the repo at
`~/Desktop/stratum` at a commit that holds this repo's `HEAD`, no branch or folder `worker-t921`
(pick a fresh id otherwise), no workspace with the main checkout open (the main entry of
`worktree list --cwd` has no `open_workspace_id`), and no workspace labelled `st-workers`. Run from
a herdr pane here, after T021 and T022 (`S=<project root>/scripts/st-worker.sh`).

```bash
L='herdr --machine laptop'
$L worktree list --cwd '~/Desktop/stratum' | jq -c '.result.worktrees[] | select(.is_linked_worktree == false) | {path, open_workspace_id}'
$L workspace list | jq -c '[.result.workspaces[] | {workspace_id, label, tab_count}]'
$L tab list | jq -c '[.result.tabs[] | {tab_id, label, workspace_id}]'
printf 'Create demo/hello.txt with the one line hi.\n' > /tmp/t921.txt
printf 'worker-t921\tlaptop\tworker-t921\tT921\n' > /tmp/roster-t921.txt
time bash $S start T921 --machine laptop --repo '~/Desktop/stratum' --task /tmp/t921.txt --test 'grep -qx hi demo/hello.txt' --lane 'plain edit, no lane' --roster /tmp/roster-t921.txt
$L workspace list | jq -c '[.result.workspaces[] | {workspace_id, label, tab_count}]'
$L tab list | jq -c '[.result.tabs[] | {tab_id, label, workspace_id}]'
$L pane list --workspace "<WS of the st-workers workspace>" | jq -c '[.result.panes[] | {pane_id, tab_id, cwd}]'
bash $S wait T921 --machine laptop
bash $S result T921 --machine laptop
bash $S close T921 --machine laptop
$L workspace list | jq -c '[.result.workspaces[] | {workspace_id, label, tab_count}]'
$L tab list | jq -c '[.result.tabs[] | {tab_id, label, workspace_id}]'
$L tab list | jq -r '.result.tabs[].label' | grep -x worker-t921; echo "tab grep exit $?"
$L workspace list | jq -r '.result.workspaces[].label' | grep -x st-workers; echo "workspace grep exit $?"
```

Expected: before `start`, no `open_workspace_id` on the main entry and no `st-workers` workspace.
`start` exit 0; after it, one new workspace labelled `st-workers` with two tabs: its own first tab
and `worker-t921` (field 4 of the `worker` line). The worker tab has two panes, both with cwd
`/home/hyuse/Desktop/stratum-worker-t921` (an absolute path, so `~` was expanded by
`tab create --cwd` and `pane split --cwd`), lazygit in the right one. `wait` ends `state finished`,
`result` prints the four lines and `fetched worker-t921 <sha>`. `close` prints `closed worker-t921`
and `folder ~/Desktop/stratum-worker-t921 ready to remove`; then the `st-workers` workspace is gone
(`close` ran `workspace close`: the workspace's own first tab is still there when the worker tab
closes, so herdr has no reason to close it by itself), every other laptop workspace and tab is as
before, and both greps exit 1. The herdr #4379 case (closing a workspace's last tab) is not reached
here, because the worker tab is never the last tab; record that, and record a workspace that was
already gone before `workspace close` ran (a `close` stop with herdr's line) as a finding. Do not
merge `worker-t921`: the folder and branch stay on the laptop, the fetched branch here, for the
user to remove.
