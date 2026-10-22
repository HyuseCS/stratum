# 005 statusline-locale

What: `tests/test_statusline.sh` fails under a non-UTF-8 locale (`LC_ALL=C`, `POSIX`). Bash
`printf` cannot turn the `` escapes into bytes there, so the glyph is the literal text
``, and `grep -P "\x{e0b0}"` stops with "code point value ... too large". The test sets a
UTF-8 locale itself.
FRs: none. spec.md has no FR for the statusline. The source is the failing run under `LC_ALL=C`
(same precedent as changes 003 and 004).
Impact area: core runtime (test files only)

## Files
- `tests/test_statusline.sh:2` - add `export LC_ALL=C.UTF-8` on a new line after `set -u`.
  Proved on a copy: exit 0 and only `ok` lines under `LC_ALL=C`, `LC_ALL=POSIX`,
  `LC_ALL=en_US.UTF-8` and `env -i`.
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
- Negative control: after the build, delete the `export LC_ALL=C.UTF-8` line once, run the
  command, see the new check go red, restore the line.

## Risks
- A machine without the `C.UTF-8` locale (older glibc, macOS) gets a setlocale warning and fails
  as today. This machine has `C.utf8`. There is no CI.
- `tests/test_inspect.sh` now runs the full statusline suite once more, so it takes longer.
