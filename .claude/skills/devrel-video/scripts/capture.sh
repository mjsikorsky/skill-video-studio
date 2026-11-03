#!/usr/bin/env bash
# Record a walkthrough with playwright-cli page.screencast, then convert to MP4.
# Usage: capture.sh <hero-script.js> [start-url] [WxH]
# The hero script MUST call: page.screencast.start({ path: 'capture.webm', ... })
set -euo pipefail

HERO="${1:?path to hero script (.js)}"; URL="${2:-}"; VP="${3:-1600x900}"
W="${VP%x*}"; H="${VP#*x}"
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
. "$SKILL/scripts/_versions.sh"

# AppArmor/userns-restricted hosts need the sandbox off for capture; harmless elsewhere.
export PLAYWRIGHT_MCP_SANDBOX=false

# Install playwright-cli locally so the open->run-code->close session daemon persists.
# (A bare per-command `npx @playwright/cli` drops the browser between invocations.)
ensure_playwright_cli "$SKILL"

HERODIR="$(cd "$(dirname "$HERO")" && pwd)"; HEROFILE="$(basename "$HERO")"
cd "$HERODIR"

# A leftover capture.webm from an earlier take would pass the check below even if this take fails.
rm -f capture.webm
# Close the browser session even when a step fails, so no daemon is left running.
trap 'playwright-cli close >/dev/null 2>&1 || true' EXIT

playwright-cli open   >/dev/null
playwright-cli resize "$W" "$H" >/dev/null
if [ -n "$URL" ]; then playwright-cli goto "$URL" >/dev/null; fi
playwright-cli eval "() => new Promise(r => setTimeout(r, 4000))" >/dev/null  # let the SPA settle
playwright-cli run-code --filename="$HEROFILE"
playwright-cli close  >/dev/null 2>&1 || true
trap - EXIT

[ -f capture.webm ] || { echo "ERROR: hero script did not produce capture.webm"; exit 1; }
# Dense keyframes (-g 30 -keyint_min 30 -sc_threshold 0 at -r 30): HyperFrames seeks every frame,
# and a sparse GOP freezes footage frames between keyframes during the render.
ffmpeg -v error -y -i capture.webm -c:v libx264 -r 30 -g 30 -keyint_min 30 -sc_threshold 0 \
  -pix_fmt yuv420p -movflags +faststart capture.mp4
echo "wrote $HERODIR/capture.mp4 ($(ffprobe -v error -show_entries format=duration -of csv=p=0 capture.mp4)s)"
