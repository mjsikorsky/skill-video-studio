#!/usr/bin/env bash
# avatar.sh — face-only talking-head from a plate + audio, via LatentSync on a GPU host over SSH.
#
# "Bring your own GPU box": set AVATAR_HOST (ssh target) + LS_DIR (LatentSync checkout on it) — see
# scripts/_env.sh. The remote recipe below is the reference for an AMD ROCm host; NVIDIA users adapt
# the GPU env in the remote block (HIP_VISIBLE_DEVICES → CUDA_VISIBLE_DEVICES, torch build, etc.).
#
# Produces a SQUARE, muted, 30fps face crop (drop it into the #avatar seam; the circle is CSS
# border-radius:50%). The mouth is lip-synced to <audio> — feed it the exact narration segment
# the bubble should "say" (e.g. one line trimmed from narration-mix.mp3), so it matches what's heard.
#
# Usage:  avatar.sh <plate> <audio.wav> <out.mp4> [face_scale]
#   plate       local video, OR  remote:/abs/path  (a plate already on AVATAR_HOST, e.g. a demo clip)
#   audio.wav   the speech the mouth should say (plate must be >= audio; no auto-loop)
#   out.mp4     local output path for the cropped face video
#   face_scale  square crop = face_height * this (default 2.0 → head + a little shoulder)
#
# The face is PINNED by per-frame face-tracking (track_crop.py) so a lively plate doesn't jitter
# in the small circle.
#
# Reference recipe for the AMD ROCm host (see references/production-notes.md → Avatar):
#   The discrete GPU was HIP device 1 (device 0 = iGPU) → HIP_VISIBLE_DEVICES=1 was mandatory there.
#   256 path (stage2.yaml) peaks ~14GB → free idle GPU memory (e.g. stop other model servers) first.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

PLATE="${1:?plate}"; AUDIO="${2:?audio.wav}"; OUT="${3:?out.mp4}"; FACE_SCALE="${4:-2.0}"
STEPS="${STEPS:-20}"          # LatentSync diffusion steps; raise (e.g. 30) for a crisper mouth
HOST="${AVATAR_HOST:?set AVATAR_HOST to the ssh target with a LatentSync checkout (see scripts/_env.sh)}"
LS_DIR="${LS_DIR:?set LS_DIR to the LatentSync checkout path on $HOST (see scripts/_env.sh)}"
SSHO=(-o ConnectTimeout=120 -o ServerAliveInterval=15 -o ServerAliveCountMax=8 -o BatchMode=yes)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[avatar] staging inputs on $HOST…"
# A private, per-run staging dir: the plate is a private recording, and a fixed shared path would let
# concurrent runs overwrite each other and other users on the host read it. Removed on exit
# (set AVATAR_KEEP_REMOTE=1 to keep it for debugging).
REMOTE="$(ssh "${SSHO[@]}" "$HOST" 'umask 077; mktemp -d "${TMPDIR:-/tmp}/devrel-avatar.XXXXXX"')"
[ -n "$REMOTE" ] || { echo "[avatar] could not create a staging dir on $HOST" >&2; exit 1; }
cleanup_remote() {
  if [ "${AVATAR_KEEP_REMOTE:-0}" = 1 ]; then echo "[avatar] kept $HOST:$REMOTE"; return; fi
  ssh "${SSHO[@]}" "$HOST" "rm -rf $(printf %q "$REMOTE")" >/dev/null 2>&1 || true
}
trap cleanup_remote EXIT
if [[ "$PLATE" == remote:* ]]; then
  RPLATE="${PLATE#remote:}"
else
  RPLATE="$REMOTE/plate.mp4"; scp "${SSHO[@]}" "$PLATE" "$HOST:$RPLATE"
fi
scp "${SSHO[@]}" "$AUDIO" "$HOST:$REMOTE/audio.wav"
scp "${SSHO[@]}" "$SCRIPT_DIR/track_crop.py" "$HOST:$REMOTE/track_crop.py"

echo "[avatar] lip-sync + face-crop on $HOST (this is the slow GPU step, ~10 min cold)…"
# Ship the remote script as a FILE (scp is integrity-checked) instead of piping via 'ssh bash -s' <<EOF —
# on a flaky link that stream corrupts (we saw echo→cho and a dropped line-continuation → command not found).
REMOTE_SH="$(mktemp)"
cat > "$REMOTE_SH" <<'REMOTE_EOF'
set -euo pipefail
# LS_DIR may carry a literal ~ or $HOME (see scripts/_env.sh); expand just those, never eval.
LS="${LS_DIR/#\~/$HOME}"; LS="${LS/#\$HOME/$HOME}"
cd "$LS"
export HIP_VISIBLE_DEVICES=1 HF_HUB_DISABLE_TELEMETRY=1
export PYTORCH_ALLOC_CONF=expandable_segments:True PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# free VRAM by unloading idle ollama models (the service keeps running); AVATAR_FREE_VRAM=0 skips this
if [ "${AVATAR_FREE_VRAM:-1}" = 1 ] && command -v ollama >/dev/null 2>&1; then
  for m in $(ollama ps 2>/dev/null | awk 'NR>1{print $1}'); do ollama stop "$m" >/dev/null 2>&1 || true; done
  sleep 2
fi

# LatentSync is a 25fps model (stage2.yaml video_fps:25; feature2chunks maps whisper at 25fps).
# A plate at any other fps makes the mouth drift against the audio → normalize to 25fps first.
ffmpeg -y -i "$RPLATE" -vf fps=25 -an -c:v libx264 -pix_fmt yuv420p -crf 18 "$REMOTE/plate25.mp4" >/dev/null 2>&1

./venv/bin/python -m scripts.inference \
  --unet_config_path configs/unet/stage2.yaml \
  --inference_ckpt_path checkpoints/latentsync_unet.pt \
  --inference_steps "$STEPS" --guidance_scale 1.5 \
  --video_path "$REMOTE/plate25.mp4" --audio_path "$REMOTE/audio.wav" \
  --video_out_path "$REMOTE/lipsynced.mp4" > "$REMOTE/run.log" 2>&1 \
  || { echo "LATENTSYNC FAILED:"; tail -15 "$REMOTE/run.log"; exit 1; }

# face-tracking crop: follow the face every frame so the head stays PINNED in the bubble (CPU-only)
./venv/bin/python "$REMOTE/track_crop.py" "$REMOTE/lipsynced.mp4" "$REMOTE/face_tracked.mp4" "$FACE_SCALE" \
  || { echo "TRACK_CROP FAILED"; exit 1; }
# finalize: 30fps + dense keyframes (HyperFrames seeks every frame) + faststart
ffmpeg -y -i "$REMOTE/face_tracked.mp4" -vf "fps=30" \
  -an -c:v libx264 -pix_fmt yuv420p -crf 18 \
  -g 30 -keyint_min 30 -sc_threshold 0 -movflags +faststart \
  "$REMOTE/avatar-face.mp4" >/dev/null 2>&1
echo "[avatar] done $(ls -lh "$REMOTE/avatar-face.mp4" | awk '{print $5}')"
REMOTE_EOF
scp "${SSHO[@]}" "$REMOTE_SH" "$HOST:$REMOTE/remote.sh"
rm -f "$REMOTE_SH"
# %q-quote every value so paths with spaces or quotes survive the remote shell.
REMOTE_ENV="$(printf 'FACE_SCALE=%q STEPS=%q LS_DIR=%q REMOTE=%q RPLATE=%q AVATAR_FREE_VRAM=%q' \
  "$FACE_SCALE" "$STEPS" "$LS_DIR" "$REMOTE" "$RPLATE" "${AVATAR_FREE_VRAM:-1}")"
ssh "${SSHO[@]}" "$HOST" "$REMOTE_ENV bash $(printf %q "$REMOTE/remote.sh")"

echo "[avatar] pulling result back…"
scp "${SSHO[@]}" "$HOST:$REMOTE/avatar-face.mp4" "$OUT"
echo "[avatar] ✓ $OUT"
