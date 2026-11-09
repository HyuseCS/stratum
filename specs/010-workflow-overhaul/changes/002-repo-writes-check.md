# 002 repo-writes-check

What: Fix issue #95. The "no repo writes" check in three advisor tests compares the full `git status --porcelain` text from the start and the end of the run. A commit or `git add` by another process in the same worktree changes that text and the check fails. The new check fails only when a path shows up in the status at the end that was not there at the start. A real write by the advisor scripts into the repo still fails it.
FRs: FR-001, FR-002, FR-012 (the advisor tests that hold the check). FR-009 does not apply: `st-lock.sh` cannot serialise a `git commit`.
Impact area: core runtime (test suite only, no script change)

## Cause (proven, red run 2026-11-09)

A wrapper `git` on PATH runs a second action right after the test's first `git -C <root> status --porcelain`. `ST_ROOT` points at a scratch clone that has one staged file and one untracked file. Results for each of the three tests:

- none: `ok   no repo writes`
- commit of the staged file: `FAIL no repo writes`, rc 1
- `git add` of the untracked file: `FAIL no repo writes`, rc 1
- append to tracked `README.md`: `FAIL no repo writes`, rc 1

No other check failed in any run. So the commit (or the staging) is the full cause.

## Files

The same two-line edit in each file:
- tests/test_advisor_matrix.sh:9 and :532
- tests/test_advisor.sh:9 and :619
- tests/test_advisor_waive.sh:9 and :206

Line 9 becomes:
```
repo_paths() { git -C "$root" status --porcelain --no-renames --untracked-files=all | cut -c4- | sort; }
repo_before=$(repo_paths)
```
The check line becomes:
```
check "no repo writes" '[ -z "$(repo_paths | comm -13 <(printf "%s\n" "$repo_before") -)" ]'
```
`cut -c4-` drops the two status letters, so staging (` M` to `M `, `??` to `A `) leaves the path list the same. `--untracked-files=all` lists each untracked file, so staging a file in a new folder does not turn `?? dir/` into a new `dir/file` path. `--no-renames` lists a staged move as its two paths, not as `old -> new`. A commit only removes paths, and `comm -13` prints only paths that are new at the end.

## Tests (written first, must fail before the build)

Harness (not committed, it runs each full test once per case). Save it outside the repo, for example as `$TMPDIR/race.sh`. It clones the repo, copies the three test files from the working tree into the clone, runs one test with `ST_ROOT=<clone>`, and prints the "no repo writes" line. It never writes to the repo.

```
#!/usr/bin/env bash
set -u
src=/home/hyuse/Desktop/stratum
t=$1 mode=$2
w=$(mktemp -d "${TMPDIR:-/tmp}/race.XXXXXX")
c=$w/clone
git clone -q "$src" "$c"
cp "$src"/tests/test_advisor.sh "$src"/tests/test_advisor_matrix.sh "$src"/tests/test_advisor_waive.sh "$c/tests/"
printf 'staged\n' > "$c/race-staged.txt"
git -C "$c" add race-staged.txt
printf 'untracked\n' > "$c/race-untracked.txt"
mkdir -p "$c/race-dir" "$w/bin"
printf 'untracked\n' > "$c/race-dir/f.txt"
cat > "$w/bin/git" <<EOF
#!/usr/bin/env bash
$(command -v git) "\$@"; rc=\$?
if [[ "\$*" == "-C $c status --porcelain"* ]] && [ ! -e $w/fired ]; then
  touch $w/fired
  case $mode in
    commit) $(command -v git) -C $c -c user.name=t -c user.email=t@t commit -qm race ;;
    stage) $(command -v git) -C $c add race-untracked.txt ;;
    stagedir) $(command -v git) -C $c add race-dir/f.txt ;;
    write) printf 'x\n' >> $c/README.md ;;
    newfile) printf 'x\n' > $c/scripts/race-new.txt ;;
  esac
fi
exit \$rc
EOF
chmod +x "$w/bin/git"
out=$(PATH="$w/bin:$PATH" ST_ROOT="$c" bash "$c/tests/$t" 2>&1); rc=$?
echo "== $t $mode rc=$rc fired=$([ -e "$w/fired" ] && echo yes || echo no)"
printf '%s\n' "$out" | grep -E '^FAIL|no repo writes'
rm -rf "$w"
```

Command (from the folder that holds `race.sh`, about 1 min in parallel):
`for t in test_advisor_matrix.sh test_advisor.sh test_advisor_waive.sh; do for m in none commit stage stagedir write newfile; do bash race.sh $t $m & done; done; wait`

- Red before the build (done): `commit`, `stage` and `stagedir` show `FAIL no repo writes` for all three tests.
- Green after the build: `none`, `commit`, `stage`, `stagedir` show `ok   no repo writes`, rc 0, `fired=yes`.
- Negative control after the build: `write` (append to tracked `README.md`) and `newfile` (new untracked `scripts/race-new.txt`) still show `FAIL no repo writes`, rc 1.
- Pre-check (done): the same 15 cases with the edit above applied to the clone gave exactly the green and negative-control results.
- Normal runs stay green: `bash tests/test_advisor.sh && bash tests/test_advisor_matrix.sh && bash tests/test_advisor_waive.sh`.

## Risks

- A write to a path that was already dirty at the start is not caught. The old check had the same gap. The new check also misses this case: a commit of that path, then an advisor write to it.
- A new file or a first edit by another process during the run still fails the check, as before. Only commits and staging are now ignored.
- The new check no longer catches removals or reverts by the code under test (deleting a file untracked at the start, `git checkout` of a modified file). The old check did, and today's advisor scripts do neither.
- `comm` needs both lists in the same sort order. Both come from `repo_paths` in one process with one locale.
