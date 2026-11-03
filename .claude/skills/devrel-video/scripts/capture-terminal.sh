#!/usr/bin/env bash
# Record a Claude Code (or any terminal) beat with VHS, then convert to a dense-keyframe MP4.
# Usage: capture-terminal.sh <script.tape> [out.mp4]
# The .tape MUST declare `Output <name>.mp4`. We render it headlessly, then re-encode with dense
# keyframes (HyperFrames seeks every frame; a sparse GOP freezes footage between keyframes — same
# reason capture.sh re-encodes the browser webm).
#
# The terminal is the CLI's "browser" — SANITIZE it like capture step 2 so a public video leaks
# nothing: record in a clean throwaway dir, `unset CLAUDE_CODE_CHILD_SESSION` (kills the
# "transcript saving is off" warning), and Escape onboarding popups. The template tape does this.
#
# Portable across Linux and macOS (no GNU-only grep/mktemp flags). The ttyd auto-fetch covers Linux
# x86_64/aarch64; on macOS install it with `brew install ttyd`.
set -euo pipefail

TAPE="${1:?path to .tape}"; OUT_ARG="${2:-}"
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
. "$SKILL/scripts/_versions.sh"
TOOLS="$SKILL/.vhs"; mkdir -p "$TOOLS"
export PATH="$HOME/go/bin:$TOOLS:$PATH"

# vhs (Charm) renders a .tape headlessly to video; ttyd + ffmpeg are its runtime deps.
# Headless chromium inside vhs launched clean on an AppArmor/Wayland host — no sandbox flag needed.
if ! command -v vhs >/dev/null; then
  command -v go >/dev/null || { echo "ERROR: need 'go' to install vhs (https://github.com/charmbracelet/vhs)"; exit 1; }
  echo "installing vhs@$VHS_VERSION (one-time)…"; GOBIN="$HOME/go/bin" go install "github.com/charmbracelet/vhs@$VHS_VERSION"
fi
if ! command -v ttyd >/dev/null; then
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)         ASSET=ttyd.x86_64 ;;
    Linux/aarch64|Linux/arm64) ASSET=ttyd.aarch64 ;;
    Darwin/*) echo "ERROR: install ttyd first (brew install ttyd)"; exit 1 ;;
    *) echo "ERROR: no prebuilt ttyd for $(uname -s)/$(uname -m); install ttyd $TTYD_VERSION and retry"; exit 1 ;;
  esac
  echo "fetching ttyd $TTYD_VERSION ($ASSET, one-time)…"
  curl -fsSL -o "$TOOLS/ttyd" "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/${ASSET}" && chmod +x "$TOOLS/ttyd"
fi

TAPEDIR="$(cd "$(dirname "$TAPE")" && pwd)"; TAPEFILE="$(basename "$TAPE")"
cd "$TAPEDIR"

RAW="$(sed -nE 's/^[[:space:]]*Output[[:space:]]+([^[:space:]]+\.mp4).*/\1/p' "$TAPEFILE" | head -1)"
[ -n "$RAW" ] || { echo "ERROR: the tape must declare 'Output <name>.mp4'"; exit 1; }

rm -f "$RAW"   # never mistake an earlier take for this one
vhs "$TAPEFILE"
[ -f "$RAW" ] || { echo "ERROR: vhs did not produce $RAW"; exit 1; }

OUT="${OUT_ARG:-$RAW}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
ffmpeg -v error -y -i "$RAW" -c:v libx264 -r 30 -g 30 -keyint_min 30 -sc_threshold 0 \
  -pix_fmt yuv420p -movflags +faststart "$WORK/out.mp4"
mv -f "$WORK/out.mp4" "$OUT"
echo "wrote $TAPEDIR/$OUT ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")s)"
