#!/usr/bin/env bash
# Duck a music bed under a voice track and master to broadcast loudness (-16 LUFS).
# Usage: mix-audio.sh <music.wav> <voice.wav> <out.mp3> [music_gain]   (music_gain default 0.42)
set -euo pipefail

MUSIC="${1:?music.wav}"; VOICE="${2:?voice.wav}"; OUT="${3:?out.mp3}"; G="${4:-0.42}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
TMP="$WORK/mix.wav"

ffmpeg -v error -y -i "$MUSIC" -i "$VOICE" -filter_complex \
"[0:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=${G}[m];\
[1:a]aformat=sample_rates=48000:channel_layouts=stereo,asplit=2[v1][v2];\
[m][v2]sidechaincompress=threshold=0.04:ratio=8:attack=15:release=350[mc];\
[mc][v1]amix=inputs=2:weights=1 1:normalize=0[s];\
[s]loudnorm=I=-16:TP=-1.5:LRA=11[out]" -map "[out]" -ar 48000 "$TMP"
ffmpeg -v error -y -i "$TMP" -codec:a libmp3lame -b:a 192k "$OUT"
echo "wrote $OUT (voice ducked over the bed, mastered to -16 LUFS)"
