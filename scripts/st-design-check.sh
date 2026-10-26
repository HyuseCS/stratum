#!/usr/bin/env bash
node_cmd="https://nodejs.org/en/download"
browser_cmd="set CHROME_PATH to a Chrome or Chromium binary"
for m in pacman apt-get dnf brew winget; do
  command -v "$m" >/dev/null 2>&1 || continue
  case $m in
    pacman) node_cmd="sudo pacman -S nodejs npm"; browser_cmd="sudo pacman -S chromium" ;;
    apt-get) node_cmd="sudo apt install nodejs npm"; browser_cmd="sudo apt install chromium" ;;
    dnf) node_cmd="sudo dnf install nodejs"; browser_cmd="sudo dnf install chromium" ;;
    brew) node_cmd="brew install node"; browser_cmd="brew install --cask google-chrome" ;;
    winget) node_cmd="winget install OpenJS.NodeJS.LTS"; browser_cmd="winget install Google.Chrome" ;;
  esac
  break
done

missing=0
v=$(node -p process.versions.node 2>/dev/null)
major=${v%%.*}
if ! [[ $major =~ ^[0-9]+$ ]] || (( major < 18 )); then
  echo "missing: node 18 or later. Install: $node_cmd"
  missing=1
fi

has_pptr() { [ -d "$1/puppeteer-core" ] || [ -d "$1/puppeteer" ]; }
found=0
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  d=$PWD
  while :; do
    has_pptr "$d/node_modules" && { found=1; break; }
    [ -z "$d" ] && break
    d=${d%/*}
  done
  [ "$found" = 0 ] && g=$(npm root -g 2>/dev/null) && has_pptr "$g" && found=1
fi
if [ "$found" = 0 ]; then
  echo "missing: puppeteer-core. Install: npm i -g puppeteer-core"
  missing=1
fi

found=0
[ -n "${CHROME_PATH:-}" ] && [ -x "$CHROME_PATH" ] && found=1
for b in google-chrome google-chrome-stable chromium chromium-browser; do
  [ "$found" = 1 ] && break
  command -v "$b" >/dev/null 2>&1 && found=1
done
for p in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium" "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"; do
  [ "$found" = 1 ] && break
  [ -f "$p" ] && found=1
done
if [ "$found" = 0 ]; then
  echo "missing: Chrome or Chromium. Install: $browser_cmd"
  missing=1
fi

[ "$missing" = 0 ] && echo "design tools: ok"
exit "$missing"
