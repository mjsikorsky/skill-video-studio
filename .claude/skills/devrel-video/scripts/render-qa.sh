#!/usr/bin/env bash
# Render a HyperFrames project, make a web-delivery copy, then QA.
# Usage: render-qa.sh <project-dir> [quality]   quality: draft|standard|high (default: high)
set -euo pipefail

PROJ="$(cd "${1:?project dir}" && pwd)"; Q="${2:-high}"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_versions.sh"
export HYPERFRAMES_NO_TELEMETRY=1 DO_NOT_TRACK=1 HYPERFRAMES_SKIP_SKILLS=1
HF=(npx --yes "hyperframes@$HYPERFRAMES_VERSION")   # one pinned version for lint, check, and render
cd "$PROJ"; mkdir -p renders

echo "== lint + check (hyperframes@$HYPERFRAMES_VERSION) =="
"${HF[@]}" lint
"${HF[@]}" check

echo "== render ($Q) =="
"${HF[@]}" render --quality "$Q" -o renders/out.mp4

echo "== web-delivery copy =="
ffmpeg -v error -y -i renders/out.mp4 -c:v libx264 -crf 21 -preset veryfast \
  -pix_fmt yuv420p -movflags +faststart renders/out-web.mp4

echo "== ffprobe =="
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_name,codec_type,width,height,r_frame_rate -of default renders/out.mp4

echo "== contact sheet =="
# Spread the 12 tiles over the whole video, whatever its length.
DUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 renders/out.mp4)"
STEP="$(python3 -c "import sys; print(max(float(sys.argv[1]) / 12, 0.1))" "$DUR")"
ffmpeg -v error -y -i renders/out.mp4 -vf "fps=1/$STEP,scale=360:-1,tile=4x3" -frames:v 1 renders/contact.png

echo "wrote renders/out.mp4 (master) · renders/out-web.mp4 ($(du -h renders/out-web.mp4 | cut -f1)) · renders/contact.png"
echo "REVIEW the contact sheet: no clipped text · correct product state · chapters aligned · NO PII."
