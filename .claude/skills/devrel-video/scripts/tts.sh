#!/usr/bin/env bash
# Synthesize one narration line to a silence-trimmed WAV via an OpenAI-compatible TTS endpoint
# (reference implementation: Orpheus). Voice must MATCH the presenter; the sample voices below are
# Orpheus's: male leo/dan/zac, female leah/tara/jess/mia/zoe (default leah). Usage: tts.sh "<text>" <out.wav> [voice]
# Config: set ORPHEUS_URL (+ optional ORPHEUS_KEY, ORPHEUS_MODEL) — see scripts/_env.sh.
# Clean the text first (no parens/version numbers; em-dash -> comma).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

TEXT="${1:?text}"; OUT="${2:?out.wav}"; VOICE="${3:-leah}"
URL="${ORPHEUS_URL:?set ORPHEUS_URL to your OpenAI-compatible TTS /v1/audio/speech endpoint (see scripts/_env.sh)}"
KEY="${ORPHEUS_KEY:-}"
MODEL="${ORPHEUS_MODEL:-orpheus-tts}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
TMP="$WORK/raw.wav"
AUTH=(); [ -n "$KEY" ] && AUTH=(-H "Authorization: Bearer $KEY")

# Build the request with a real JSON encoder: narration text may contain quotes or backslashes.
python3 -c 'import json, sys; print(json.dumps({"model": sys.argv[1], "voice": sys.argv[2], "input": sys.argv[3], "response_format": "wav"}))' \
  "$MODEL" "$VOICE" "$TEXT" > "$WORK/request.json"

code=$(curl -s -w "%{http_code}" --max-time 120 "$URL" \
  ${AUTH[@]+"${AUTH[@]}"} -H "Content-Type: application/json" \
  --data-binary "@$WORK/request.json" \
  --output "$TMP" || true)
if [ "$code" != "200" ]; then
  echo "TTS endpoint returned $code for $URL" >&2
  echo "  Check the endpoint is reachable and the model '$MODEL' / voice '$VOICE' are available." >&2
  exit 1
fi
# trim leading/trailing silence so lines place tightly on the timeline
ffmpeg -v error -y -i "$TMP" -af \
  "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.04,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.04,areverse" \
  "$OUT"
echo "wrote $OUT ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")s, voice=$VOICE)"
