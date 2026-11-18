# 003 worker-models-copy

What: `start` copies `.stratum/models.json` of the main checkout into the new worker worktree. This applies to a local worker and a `--machine` worker. The Stratum agents in the worker session then use the project's model and effort. The file is gitignored, so `git worktree add` does not bring it, and `hooks/st-models.py` (:52-60) stops at the worktree and returns with no change when the file is missing.
FRs: 008 FR-017 (model choice for workers). The spec does not cover the copy today: add the spec line below.
Impact area: core runtime

## Spec line to add (orchestrator, not this lane)
FR-017, at the end, after "(D27, D28).":
"`start` also copies `.stratum/models.json` of the main checkout (with `--machine`, of the main checkout on that machine) into the new worktree when that file exists and the worktree has none, so the Stratum agents of the worker session use the project's model and effort. A symlink at `<WT>/.stratum/models.json` stops the start (D39)."

## Rules
- Source: `$repo/.stratum/models.json`. For a local start, `$repo` is the main checkout (`--git-common-dir`, st-worker.sh:315). With `--machine`, it is `$qr` on that machine. The brief `Model:` line still reads `$top` (:92), which is the calling folder.
- Copy only when the source is a file (`-f`) and the destination does not exist. A project that tracks `models.json` already has the file in the worktree: keep that file and do not stop.
- The destination is a symlink: stop, as for the other `.stratum` files, because `cp` would write through the link. This check runs also when there is no source.
- Copy only `models.json`. Copy it before `worker-setup.sh`, so the setup hook can still change it.

## Files
- scripts/st-worker.sh local branch (:365-372):
  - After the `for p in ...` check line: `[ ! -L "$WT/.stratum/models.json" ] || stop "$WT/.stratum/models.json is a symlink"`.
  - After the `.stratum/worker` write: `[ ! -f "$repo/.stratum/models.json" ] || [ -e "$WT/.stratum/models.json" ] || cp -- "$repo/.stratum/models.json" "$WT/.stratum/models.json" || stop "cannot copy .stratum/models.json to $WT"`.
- scripts/st-worker.sh remote branch (:387), in the same `rsh` call (no new ssh call):
  - Prelude, after the `for ... done`: `&& { [ ! -L $Q/.stratum/models.json ] || { echo "$Q/.stratum/models.json is a symlink" >&2; exit 3; }; }`.
  - After `> $Q/.stratum/worker` and before `$A$U`: `&& { [ ! -f $qr/.stratum/models.json ] || [ -e $Q/.stratum/models.json ] || cp -- $qr/.stratum/models.json $Q/.stratum/models.json; }`.
  - A failure uses the present exit path and text: `stopped: cannot write brief.md and .stratum/git-guard.json in <WT> on <m>: <first stderr line>`.
- tests/test_st_worker.sh git stub (:159-168): two new `STUB_WT_LINK` cases. `models` makes `$p/.stratum/models.json` a symlink to `$T/outside.json`. `modelsfile` writes `TRACKED MODELS` to `$p/.stratum/models.json`.
- specs/008-herdr-workers/contracts/script.md:
  - Section 3 (:84-92): one paragraph with the rules above.
  - Step 4 (:195): "write brief.md and .stratum/git-guard.json (section 3), copy .stratum/models.json, the autonomous files, then worker-setup.sh".
  - New rows MD1 to MD7 in the test table, after M3 (:567).
- specs/008-herdr-workers/decisions.md: D39, with the rules above. Rejected: send this machine's models.json over ssh to a `--machine` worker (the way `G` is sent). The request names the main checkout on the machine, and `worker-setup.sh` also runs from there.

## Tests (written first, must fail before the build)
Command: `bash tests/test_st_worker.sh`

Red before the build:
- MD1 local: `$mfile` = `{"st-review":{"model":"opus","effort":"high"}}`, then `start`. Checks: exit 0. `cmp "$mfile" "$(wt)/.stratum/models.json"`. The copy is a plain file, not a symlink. `git -C "$repo" status --porcelain` is empty (the test repo excludes models.json, :243).
- MD3 local: `models:.stratum/models.json` is added to the S12 loop (:466). The present S12 checks apply: exit 1, one `stopped: <WT>/.stratum/models.json is a symlink` line, no agent start, `outside.json` unchanged.
- MD5 `--machine`, SU3 shape (`rfresh; xsetup`, `STUB_SSH_EXEC=1`, `--repo "$rrepo"`): `$rrepo/.stratum/models.json` exists. Checks: exit 0. `cmp "$rrepo/.stratum/models.json" "$rw/.stratum/models.json"`. Two ssh calls.
- MD6 `--machine`, `STUB_SSH_EXEC=1`, `STUB_WT_LINK=models`: exit 1. One stopped line: `cannot write brief.md and .stratum/git-guard.json in $rw on laptop: $rw/.stratum/models.json is a symlink`. `outside.json` unchanged. No agent start.

Guard rows (green before and after, they stop a wrong build):
- MD2 local, no `$mfile`: no `$(wt)/.stratum/models.json`. This is one more check in M3 (:1229).
- MD4 local, `STUB_WT_LINK=modelsfile` and a different `$mfile`: exit 0, and the worktree file is still `TRACKED MODELS`.
- MD7 `--machine`, SU3 shape, no source file: exit 0, no `$rw/.stratum/models.json`.

Changed:
- R13 (:1088): the expected prelude string gets the models.json symlink check after `done &&`. The ssh call count (3) stays.
- R13b, MK3 and SU3 do not change.

## Risks
- R1: The local source is the main checkout, but the brief `Model:` line and `G` read the calling folder (`$top`). When `start` runs from a linked worktree (S10) that has its own models.json, the two can differ. The request names the main checkout.
- R2: With `--machine`, the copy comes from the main checkout on that machine. A laptop checkout without models.json gives no copy, and that worker uses the agent frontmatter and no effort.
- R3: A copy made at start does not follow later edits of the main file.
- R4: A tracked models.json in the worktree is kept as committed and is not replaced with the main checkout's working copy. This keeps the worktree clean.
