#!/usr/bin/env bash
# Stitch environment beats (terminal + browser clips) into one clip with a smooth hand-off that
# fades each beat through a brand color — the same "fade over the background" move the HyperFrames
# composition uses between scenes. A pure crossfade is muddy (terminal text ghosts through the page);
# fading through the brand teal is clean and on-brand.
#
# This is the QUICK path (no composition). For the full pipeline, place the beats as timeline clips
# in index.html with browser-/terminal-frame chrome + a GSAP fade-through-teal hand-off (SKILL §5.8).
#
# Usage: stitch-envs.sh <out.mp4> <hex e.g. 082826> <clip1.mp4> <clip2.mp4> [clip3.mp4 ...]
set -euo pipefail

OUT="${1:?out.mp4}"; COLOR="0x${2:?brand hex, e.g. 082826 (brands/<name>/tokens.json teal-dark)}"; shift 2
CLIPS=("$@")
[ "${#CLIPS[@]}" -ge 2 ] || { echo "ERROR: need >=2 clips"; exit 1; }

F=0.35                                              # half-transition (fade to + from the colour)
NORM="fps=30,scale=1600:900,setsar=1,format=yuv420p"
last=$(( ${#CLIPS[@]} - 1 ))
inputs=(); filters=(); labels=""
for i in "${!CLIPS[@]}"; do
  c="${CLIPS[$i]}"; [ -f "$c" ] || { echo "ERROR: missing clip $c"; exit 1; }
  inputs+=(-i "$c")
  d="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$c")"
  st="$(python3 -c "print(round($d-$F,3))")"
  f="[$i:v]$NORM"
  [ "$i" -gt 0 ]      && f="$f,fade=t=in:st=0:d=$F:color=$COLOR"      # fade up from the colour
  [ "$i" -lt "$last" ] && f="$f,fade=t=out:st=$st:d=$F:color=$COLOR"  # fade down to the colour
  filters+=("${f}[v$i]"); labels+="[v$i]"
done
FC="$(IFS=';'; echo "${filters[*]}");${labels}concat=n=${#CLIPS[@]}:v=1:a=0[vout]"
ffmpeg -v error -y "${inputs[@]}" -filter_complex "$FC" -map "[vout]" \
  -c:v libx264 -r 30 -g 60 -pix_fmt yuv420p -movflags +faststart "$OUT"
echo "wrote $OUT ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")s)"
