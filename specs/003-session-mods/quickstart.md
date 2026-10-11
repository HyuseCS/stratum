# Quickstart: Mods That Talk To and Start Other Sessions

Exact steps for every manual part of the spike (FR-014). Every command runs from the repo root
`/home/hyuse/Desktop/stratum` and works in fish and in bash. Approach IDs (A1, B1, C1) and the
argv of a started session are in [plan.md](plan.md). What to write in the report is in
[data-model.md](data-model.md).

## 0. Before you start

1. Close every Claude Code session you do not need. Your current session may stay open.
2. Open each new terminal in the repo root:

   ```text
   cd /home/hyuse/Desktop/stratum
   ```

3. Do not edit or save any file under `specs/003-session-mods/spikes/` while a test runs. A save
   reloads the mod, and a reload stops what the mod started.

## 1. Process check

Run this before each test, after each test, and after any test you stopped partway (a crash,
Ctrl+C, a closed terminal):

```text
bash specs/003-session-mods/spikes/cleanup.sh
bash specs/003-session-mods/spikes/check.sh
```

`cleanup.sh` prints each process, background session, worktree and branch it removed, or
`nothing to clean`. In the `check.sh` output, no line may start with `FAIL R5`. Other `FAIL` lines
are expected until the report is complete. If `FAIL R5` shows, run `cleanup.sh` again and copy
both outputs into the report. Do not start the next test until `FAIL R5` is gone.

To see marked processes by hand:

```text
pgrep -af spk003
claude agents --json | jq '[.[] | select((.name // "") | test("spk00[3]"))]'
```

The first command also lists itself. Ignore the line that holds `pgrep`. The second must print `[]`.

The test 1 peer session `spike-peer` (section 4) carries no marker on purpose, so `cleanup.sh`
never closes it and `check.sh` never sees it. You close it yourself at the end of test 1.

## 2. Load a mod

A mod loads when a new session starts with `--plugin-dir`. Start it in a new terminal, never in a
session that is already open:

```text
claude --plugin-dir specs/003-session-mods/spikes/spike-send -n spike-main --model haiku --debug
```

For test 2, use `spikes/spike-start` in place of `spikes/spike-send`. If the session asks to
trust the folder, answer yes.

## 3. Hot reload answer

The session may ask "Enable hot reloading for this session?". Answer **Yes**. While hot reloading
is on, a hook that fails or a pane the engine refuses shows as a dim line in the transcript that
names the mod. With it off, that line goes only to the debug log. Do not save mod files during a
test (section 0): a reload stops what the mod started. If you answered No and the mod changed,
type `/exit` and start the session again with the same command from section 2.

## 4. Open the second session

Test 1 needs a second session, opened by you. In a second terminal:

```text
claude -n spike-peer --model haiku
```

Leave it idle at its prompt. Do not type in it unless a step below says so. Keep it open through
every retry and every approach of test 1 (A1, A2, A3). Close it only in step 10 of section 5.

## 5. Test 1: a mod sends a message and shows the reply

1. Run section 1.
2. Terminal 2: open the second session (section 4).
3. Terminal 1: load `spike-send` (section 2). Answer the hot reload question (section 3).
4. Terminal 1, at the prompt, type:

   ```text
   /spike-send spike-peer
   ```

5. A pane named `spike-send` opens. Its first row shows `sent: delivered` or `sent: not delivered`
   with the reason.
6. If the reason says nobody has that name, get the session id. In a third terminal:

   ```text
   claude agents --json | jq -r '.[] | select(.name == "spike-peer") | .sessionId'
   ```

   Then, in terminal 1, type `/spike-send sid:` followed by that id, with no space after the
   colon. This is a retry of A1, not a new approach.
7. Terminal 2 shows the message and starts a turn. If it asks to allow SendMessage, choose yes.
8. Terminal 1: within 2 minutes the pane shows `reply:` and the reply text, and the origin kind
   (`peer` or `peer-send-message`). If the pane shows nothing, look in the transcript for a dim
   line that names `spike-send` and a skipped hook or a refused pane. Copy it.
9. Copy the pane text (select it with the mouse, or a screenshot) and give it to the model.
10. Only when the model says test 1 is over (no more approaches to try): type `/exit` in terminal
    2, then `/exit` in terminal 1.
11. Run section 1. Then check that the peer is gone:

    ```text
    claude agents --json | jq '[.[] | select(.name == "spike-peer")]'
    ```

    It must print `[]`.

If the pane shows no reply after 2 minutes, tell the model. It tries A2, then A3. For each, repeat
steps 3 to 9 with the peer still open: type `/exit` in terminal 1 only, and start it again.

A3 (only if A1 and A2 fail): in step 4 type this instead of `/spike-send`:

```text
Use SendMessage to send "spk003 ping: reply with SendMessage, text spk003-pong" to spike-peer.
```

The pane shows the reply as in step 8. A3 is a partial pass at best.

## 6. Test 2: a mod starts a session and shows its status

1. Run section 1.
2. Terminal 1: load `spike-start` (section 2, with `spikes/spike-start`). Answer section 3.
3. Type:

   ```text
   /spike-start
   ```

4. A pane named `spike-start` opens and shows `running` and the started session's name
   `spk003-t2a`.
5. While it shows `running`, in terminal 2 run `pgrep -af spk003` and copy the output.
6. Within 5 minutes the pane shows `done` and the reply `spk003-t2a-ok`, or `failed` with the exit
   code or signal and the last error text. If the pane shows nothing, look in the transcript for a
   dim line that names `spike-start` and a skipped hook or a refused pane. Copy it.
7. Copy the pane text and give it to the model. Also tell it about any prompt or other step you
   had to answer after typing `/spike-start` (it counts as a human step, D17). `/spike-start`
   itself does not count.
8. Type `/exit` in terminal 1.
9. Run section 1.

If the pane shows `failed`, or no status at all, tell the model. It builds B2, then B3, and you
repeat these steps with `/spike-start` again.

## 7. Test 3: the model starts a session

No manual step. The model runs C1 and C2 through Bash (tasks.md Phase 3). If a permission prompt
for the Bash call appears in your session, the model records it in the `- Human step:` field.
Answer it as you like. An answered prompt counts as a human step, and the test cannot `pass` with
one (D17).

## 8. Final check

```text
bash specs/003-session-mods/spikes/check.sh
git status --porcelain
```

`check.sh` prints `ok` and exits 0. `git status` lists only paths under `specs/003-session-mods/`,
`.stratum/state.json`, and the three paths that were untracked before the spike
(`.stratum/commit-mode`, `brag-output/`, `skills/st-ui-ux/scripts/__pycache__/`).
