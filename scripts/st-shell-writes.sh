#!/usr/bin/env bash
[ $# -ge 1 ] || { echo "usage: st-shell-writes.sh <transcript.jsonl>..."; exit 2; }
exec python3 -I - "$@" <<'PY'
import json, re, sys
# ponytail: the redirect check covers only cat, echo and printf; upgrade when a lane is seen to write with another command
pat = re.compile(r"(?<!<)<<(?!<)|\|\s*tee\b|\bsed\b[^|;&\n]*\s(-[a-zA-Z]*i|--in-place)|\b(cat|echo|printf)\b[^|;&\n]*?(?<!>)>>?(?!&|\s*/dev/null)")
hit = 0
for path in sys.argv[1:]:
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError as e:
        print(f"st-shell-writes: cannot read {path}: {e.strerror}", file=sys.stderr)
        sys.exit(2)
    for line in lines:
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if not isinstance(d, dict) or d.get("type") != "assistant":
            continue
        content = (d.get("message") or {}).get("content")
        for c in content if isinstance(content, list) else []:
            if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Bash":
                cmd = (c.get("input") or {}).get("command")
                if isinstance(cmd, str) and pat.search(cmd):
                    print(cmd)
                    hit = 1
sys.exit(hit)
PY
