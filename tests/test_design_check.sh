#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
script="$root/scripts/st-design-check.sh"
git_before=$(git -C "$root" status --porcelain)
chrome_ok="$tmp/chrome"; : > "$chrome_ok"
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
linux_only() { [ "$(uname -s)" = Linux ] || { echo "skip $1 (Linux only)"; return 1; }; }
mk() { c="$tmp/$1"; bin="$c/bin"; proj="$c/proj"; glob="$c/global"; mkdir -p "$bin" "$proj" "$glob"; }
tool() { : > "$bin/$1"; chmod +x "$bin/$1"; }
fake_node() { printf '#!/bin/sh\ncase "$1" in -p) echo %s;; *) exit 1;; esac\n' "$1" > "$bin/node"; chmod +x "$bin/node"; }
fake_npm() { printf '#!/bin/sh\ncase "$1 $2" in "root -g") echo %s;; *) exit 1;; esac\n' "$glob" > "$bin/npm"; chmod +x "$bin/npm"; }
run() {
  (
    cd "$1" || exit 99
    unset CHROME_PATH
    [ -n "${3:-}" ] && export CHROME_PATH=$3
    PATH=$2 "$BASH" "$script" 2>&1
  )
}
kcase() {
  local out rc
  out=$(run "$4" "$5" "${6:-}"); rc=$?
  if [ "$rc" = "$2" ] && [ "$out" = "$3" ]; then echo "ok   $1"; return 0; fi
  echo "FAIL $1: exit $rc, want exit $2"
  printf '     got:  %s\n     want: %s\n' "$out" "$3"
  fail=1; return 1
}

mk K1; fake_node 20.11.1; fake_npm; mkdir -p "$glob/puppeteer-core"
kcase "K1 all present" 0 "design tools: ok" "$proj" "$bin" "$chrome_ok"; k1=$?

mk K2; fake_node 20.11.1; fake_npm
kcase "K2 no puppeteer" 1 "missing: puppeteer-core. Install: npm i -g puppeteer-core" "$proj" "$bin" "$chrome_ok"

mk K3; fake_node 20.11.1; fake_npm; mkdir -p "$glob/puppeteer-core"; tool pacman
linux_only "K3 no browser, pacman" && kcase "K3 no browser, pacman" 1 "missing: Chrome or Chromium. Install: sudo pacman -S chromium" "$proj" "$bin"

mk K4; fake_node 16.20.2; fake_npm; mkdir -p "$glob/puppeteer-core"; tool brew
kcase "K4 old node, brew" 1 "missing: node 18 or later. Install: brew install node" "$proj" "$bin" "$chrome_ok"

mk K5; tool apt-get
kcase "K5 no node, apt-get" 1 $'missing: node 18 or later. Install: sudo apt install nodejs npm\nmissing: puppeteer-core. Install: npm i -g puppeteer-core' "$proj" "$bin" "$chrome_ok"

mk K6; fake_node 20.11.1; fake_npm; mkdir -p "$proj/node_modules/puppeteer-core"
kcase "K6 project puppeteer" 0 "design tools: ok" "$proj" "$bin" "$chrome_ok"

mk K7; fake_node 20.11.1; fake_npm; mkdir -p "$glob/puppeteer-core"; tool pacman; tool chromium
kcase "K7 browser on PATH" 0 "design tools: ok" "$proj" "$bin"

mk K8; fake_node 20.11.1; fake_npm; mkdir -p "$glob/puppeteer-core"
linux_only "K8 no manager" && kcase "K8 no manager" 1 "missing: Chrome or Chromium. Install: set CHROME_PATH to a Chrome or Chromium binary" "$proj" "$bin"

mk K9; fake_node 20.11.1; fake_npm; mkdir -p "$glob/puppeteer-core"; tool dnf
linux_only "K9 dead CHROME_PATH" && kcase "K9 dead CHROME_PATH" 1 "missing: Chrome or Chromium. Install: sudo dnf install chromium" "$proj" "$bin" "$tmp/no-such-chrome"

mk K10; tool winget
linux_only "K10 order" && kcase "K10 order" 1 $'missing: node 18 or later. Install: winget install OpenJS.NodeJS.LTS\nmissing: puppeteer-core. Install: npm i -g puppeteer-core\nmissing: Chrome or Chromium. Install: winget install Google.Chrome' "$proj" "$bin"

mk K12; fake_node 20.11.1; fake_npm; mkdir -p "$c/node_modules/puppeteer-core"
kcase "K12 parent puppeteer" 0 "design tools: ok" "$proj" "$bin" "$chrome_ok"

git_after=$(git -C "$root" status --porcelain)
check "K11 no writes" '[ "$git_before" = "$git_after" ] && [ "$k1" = 0 ]'
exit $fail
