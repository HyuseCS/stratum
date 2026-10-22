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

Expected: every line `ok`, exit 0, and `git status --porcelain` shows nothing new from the runs
(lessons L8).

## 2. Live local run (US1, SC-001, SC-005; measures research R1, R4, R5, R6, R11)

Needs: a herdr pane (`HERDR_ENV=1`), Claude Code 2.1.302 or later, auto mode available.
Use a scratch base so the merge does not touch the feature branch:

```bash
bash scripts/st-worktree.sh worker-demo-base demo      # prints ../stratum-003-demo
```

Open a pane in `../stratum-003-demo` and run these from there (the plugin root is
`/home/hyuse/Desktop/stratum-003`; `S=/home/hyuse/Desktop/stratum-003/scripts/st-worker.sh`):

```bash
printf 'Create demo/hello.txt with the one line hi.\n' > /tmp/t900.txt
printf 'worker-t900\tlocal\tworker-t900\tT900\n' > /tmp/roster.txt
time bash $S start T900 --task /tmp/t900.txt --test 'grep -qx hi demo/hello.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
```

Record in research.md:

1. `start` exit code, and whether a trust dialog showed (R4). Expected: exit 0, `state working`.
2. The worker pane shows `◎ /goal active` (R5: the pasted `/goal` ran as the command).
3. The commit: the worker commits with no dialog (D24), and `cat ../stratum-003-demo-worker-t900/.stratum/git-guard.json` shows `{"commit":"auto"}`.
4. `bash $S wait T900` until `state finished`. Note every `state` line and how long the worker sat
   `idle` between goal turns, if at all (R6).
5. `bash $S result T900`: the four result lines; the pane text is not printed.
6. `git log --oneline worker-demo-base..worker-t900`: the worker's commit. Then
   `git merge --no-ff --no-edit worker-t900` and `grep -qx hi demo/hello.txt; echo $?` gives `0`.
7. `bash $S close T900`: `closed worker-t900` and `folder ... ready to remove`. Then all three are
   empty: `herdr agent list | jq -r '.result.agents[].name' | grep -x worker-t900`,
   `herdr workspace list | jq -r '.result.workspaces[].label' | grep -x worker-t900`,
   `pgrep -af -- '-n worker-t90[0]'` (SC-005; the bracket keeps pgrep from matching the shell
   that runs it, lessons L14). The answer of `workspace close` (R1).

The user removes `../stratum-003-demo`, `../stratum-003-demo-worker-t900` and the two branches when
they want.

## 3. Question path live (US2, SC-003; measures R7)

Same setup. Run it through the skill ("run T901 in a worker") so the orchestrator decides each
question with the `/stratum:st` rule (D26). The task forces one small and one big question:

```bash
printf 'Ask with AskUserQuestion which word to write, options hi and hello, and write it to demo/q.txt. Then ask with AskUserQuestion whether to push the branch to origin, options yes and no; push only on yes.\n' > /tmp/t901.txt
printf 'worker-t901\tlocal\tworker-t901\tT901\n' > /tmp/roster.txt
bash $S start T901 --task /tmp/t901.txt --test 'test -s demo/q.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
bash $S wait T901           # expected: state blocked, exit 4, the question in the pane text
bash $S answer T901 --keys 1   # small: the orchestrator answers; record which key picks "hi"
bash $S wait T901           # expected: state blocked again, the push question
                            # big: the orchestrator asks the user first; the recorded answer is no (nothing is pushed)
bash $S answer T901 --keys 2   # "no"; record which key picks it
bash $S wait T901           # expected: state finished
```

The end-of-run list names the word question as answered by the orchestrator, and not the push
question. Then once more with the user typing the answer in the pane first: `answer` must print
`not blocked: working` and send nothing (US2 scenario 3). Record which keys or text reach the
free-text field of the dialog.

## 4. Team live (US4, SC-004)

Two workers here, the second builds on the first:

```bash
printf 'Create demo/a.txt with the line a.\n' > /tmp/t902.txt
printf 'Wait until worker-t902 has committed demo/a.txt (ask it by name with SendMessage), merge its branch, then create demo/b.txt with the content of demo/a.txt.\n' > /tmp/t903.txt
printf 'worker-t902\tlocal\tworker-t902\tT902\nworker-t903\tlocal\tworker-t903\tT903\n' > /tmp/roster.txt
bash $S start T902 --task /tmp/t902.txt --test 'grep -qx a demo/a.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
bash $S start T903 --task /tmp/t903.txt --test 'grep -qx a demo/b.txt' --lane 'plain edit, no lane' --roster /tmp/roster.txt
```

Expected: both briefs hold both roster rows; worker-t903's transcript shows a SendMessage to
`worker-t902` and a `git merge worker-t902`; both finish. Then the skill's steps 8 to 11 merge
both in task order and close both.

## 5. Headless live (US5, SC-006; measures R12)

```bash
printf 'Create demo/h.txt with the line h.\n' > /tmp/t904.txt
git rev-parse HEAD
bash $S headless T904 --task /tmp/t904.txt --test 'grep -qx h demo/h.txt'
git rev-parse HEAD; git status --porcelain; pgrep -af -- '-n worker-t90[4]'
```

Expected: `headless worker-t904 success <turns> <cost>`, exit 0, the same HEAD before and after,
`demo/h.txt` untracked, no process. Record `num_turns` and how `--max-turns` counted the goal
turns.

## 6. Remote live (US3, SC-002), gated

Only when `herdr --machine laptop workspace list` exits 0. Needs the repo on the laptop at a
commit that holds this repo's `HEAD`.

```bash
bash $S start T905 --machine laptop --repo '~/Desktop/stratum' --task /tmp/t900.txt --test 'grep -qx hi demo/hello.txt' --lane 'plain edit, no lane' --roster /tmp/roster-laptop.txt
bash $S wait T905 --machine laptop
bash $S result T905 --machine laptop      # reads the file over ssh, then fetched worker-t905 <sha>
bash $S close T905 --machine laptop
```

Expected: every line as in section 2, the brief and result on the laptop, `git log worker-t905`
here after the fetch. If the laptop does not answer: `Machine laptop does not answer: ...`, one
line, nothing made (US3 scenario 3).
