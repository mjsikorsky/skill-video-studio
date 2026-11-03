#!/usr/bin/env bash
# Optional local config for host-specific infra — sourced by tts.sh / avatar.sh / variant.sh.
# These features are "bring your own": narration needs any OpenAI-compatible TTS endpoint, the
# avatar needs any SSH host with a LatentSync checkout. Put your values ONCE in a file that is
# NOT committed (default: ~/.config/devrel-video/env, override with DEVREL_VIDEO_ENV), e.g.:
#
#   ORPHEUS_URL="https://my-tts.example.com/v1/audio/speech"   # OpenAI-compatible /v1/audio/speech
#   ORPHEUS_KEY="sk-..."                                        # bearer token (omit if the endpoint needs none)
#   AVATAR_HOST="user@gpu-host"                                 # ssh target for the LatentSync GPU box
#   LS_DIR="\$HOME/LatentSync"                                   # LatentSync checkout path on that host
#
# ponytail: no config framework — just source a dotfile if it exists. Env vars already set win.
_cfg="${DEVREL_VIDEO_ENV:-$HOME/.config/devrel-video/env}"
# shellcheck source=/dev/null  # a private, user-chosen file
if [ -f "$_cfg" ]; then . "$_cfg"; fi   # `if` (not `&&`) so a missing file returns 0 under `set -e`
