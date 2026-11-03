#!/usr/bin/env bash
# Build a YouTube thumbnail (1280x720 JPG, <2MB) from a project's thumbnail.html + a hero frame of capture.mp4.
# Every DevRel video ships one (not just the QA contact sheet). Usage: thumbnail.sh <project-dir> [hero_time_s]
set -euo pipefail
PROJ="$(cd "${1:?project dir}" && pwd)"; HERO_T="${2:-2.0}"
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
. "$SKILL/scripts/_versions.sh"
[ -f "$PROJ/thumbnail.html" ] || { echo "thumbnail: need $PROJ/thumbnail.html (copy templates/thumbnail.html + fill)"; exit 1; }
[ -f "$PROJ/capture.mp4" ]   || { echo "thumbnail: need $PROJ/capture.mp4 (run capture.sh first)"; exit 1; }
mkdir -p "$PROJ/renders"

echo "[thumbnail] hero frame @ ${HERO_T}s -> renders/hero.png"
ffmpeg -v error -y -ss "$HERO_T" -i "$PROJ/capture.mp4" -frames:v 1 "$PROJ/renders/hero.png"

export PLAYWRIGHT_MCP_SANDBOX=false
ensure_playwright_cli "$SKILL"

# playwright-cli blocks file:// — serve the project over http so thumbnail.html + renders/hero.png load.
# Bind to loopback only: the project folder can hold private media (voice, avatar, captures).
# Default to a free ephemeral port so concurrent runs don't collide; THUMB_PORT overrides.
PORT="${THUMB_PORT:-$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')}"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$PROJ" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true; playwright-cli close >/dev/null 2>&1 || true' EXIT
for _ in $(seq 50); do
  python3 -c "import socket,sys; socket.create_connection(('127.0.0.1', int(sys.argv[1])), 0.2)" "$PORT" 2>/dev/null && break
  sleep 0.1
done

echo "[thumbnail] render 1280x720"
playwright-cli open   >/dev/null
playwright-cli resize 1280 720 >/dev/null
playwright-cli goto "http://127.0.0.1:$PORT/thumbnail.html" >/dev/null
playwright-cli eval "() => new Promise(r => setTimeout(r, 1200))" >/dev/null  # fonts + hero img settle
playwright-cli screenshot --filename="$PROJ/renders/thumbnail.png" >/dev/null

echo "[thumbnail] -> JPG (<2MB)"
ffmpeg -v error -y -i "$PROJ/renders/thumbnail.png" -q:v 3 "$PROJ/renders/thumbnail.jpg"
echo "[thumbnail] ✓ $PROJ/renders/thumbnail.jpg ($(du -h "$PROJ/renders/thumbnail.jpg" | cut -f1), $(ffprobe -v error -show_entries stream=width,height -of csv=p=0:s=x "$PROJ/renders/thumbnail.jpg"))"
