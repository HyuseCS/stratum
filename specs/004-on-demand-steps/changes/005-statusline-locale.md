# 005 statusline-locale

What: `tests/test_statusline.sh` fails under a non-UTF-8 locale (`LC_ALL=C`, `POSIX`). Bash
`printf` cannot turn the `` escapes into bytes there, so the glyph is the literal text
``, and `grep -P "\x{e0b0}"` stops with "code point value ... too large". The test sets a
UTF-8 locale itself when the current locale is not UTF-8.
FRs: none. spec.md has no FR for the statusline. The source is the failing run under `LC_ALL=C`
(same precedent as changes 003 and 004).
Impact area: core runtime (test files only)

## Files
- `tests/test_statusline.sh:3` - add on a new line after `set -u`:
  `[ "$(locale charmap 2>/dev/null)" = UTF-8 ] || export LC_ALL=C.UTF-8`. The export runs only
  when the current locale is not UTF-8, so a UTF-8 locale without `C.UTF-8` is left as it is.
  Proved on a copy with a plain `export LC_ALL=C.UTF-8`: exit 0 and only `ok` lines under
  `LC_ALL=C`, `LC_ALL=POSIX`, `LC_ALL=en_US.UTF-8` and `env -i`. Re-run at close with the guarded
  line: same result under the same four settings (`env -i` with `PATH` kept).
- `tests/test_inspect.sh:146` - one new `check` before `exit $fail` (see Tests).

No change: `statusline/st-statusline.sh`. Under `LC_ALL=C`, python3 coerces the C locale to UTF-8
(`sys.flags.utf8_mode` is 1), and the script prints the right glyph bytes (`356 202 266` for
``). The failure is in the test's own `printf` and `grep -P`.

## Tests (written first, must fail before the build)
- `tests/test_inspect.sh` - new check "statusline test passes under LC_ALL=C":
  `out=$(LC_ALL=C bash "$root/tests/test_statusline.sh" 2>&1); [ $? = 0 ] && ! grep -qv "^ok" <<<"$out"`.
  The `grep -qv "^ok"` part is needed: the `grep -P` error goes to stderr and does not set `fail`,
  so the exit code alone misses it. Red today: exit 1, four "FAIL shape ...: draws its glyph"
  lines and the grep error. Command: `bash /home/hyuse/Desktop/stratum/tests/test_inspect.sh`
- Negative control: after the build, delete the locale guard (`tests/test_statusline.sh:3`) once, run the
  command, see the new check go red, restore the line.

## Risks
- A machine with a non-UTF-8 locale and no `C.UTF-8` locale (older glibc, macOS) gets a setlocale
  warning and fails as today. This machine has `C.utf8`. There is no CI.
- `tests/test_inspect.sh` now runs the full statusline suite once more, so it takes longer.
