# example-walkthrough

The studio's worked example: a product tour recorded, framed, and chaptered by the `/devrel-video` pipeline.
It records a **self-contained Acme mock app** (`./site/` — served locally, no login, no PII, no external
dependency) and frames it with the default **Acme** brand (`brands/acme/`). It ships both a **silent** cut and a
**narrated** one (voice `leah` + a ducked music bed + EN/ES subtitles, ~26s). Swap `./site/` for your real
product URL and the brand, and you have your own video.

[![example walkthrough](renders/demo.gif)](https://youtu.be/H6npd3uuqls)

▶ [Watch the full video with sound on YouTube](https://youtu.be/H6npd3uuqls).

> `capture.mp4` and `renders/*.mp4` are **gitignored** — regenerate them by running the pipeline. Committed:
> `brief.yaml`, `capture.js`, `site/`, `index.html`, `narrate.py`, `captions.*.srt`, and
> `renders/{contact-sample.png, thumbnail.jpg, demo.gif}`.

## Make it

```bash
# from the repo root
S=.claude/skills/devrel-video

# 1. serve the mock app, then capture the live flow (3 beats: workspace → filter by category → open a project)
python3 -m http.server 8000 --bind 127.0.0.1 --directory projects/example-walkthrough/site &
$S/scripts/capture.sh projects/example-walkthrough/capture.js "http://localhost:8000/"
kill %1   # stop the server

# 2. render the SILENT cut. index.html is already composed (from $S/templates/composition.html +
#    brands/acme/tokens.json) and expects the mix from step 3, so start with a silent track
ffmpeg -v error -y -f lavfi -i anullsrc=r=48000:cl=stereo -t 26 -q:a 9 projects/example-walkthrough/narration-mix.mp3
$S/scripts/render-qa.sh projects/example-walkthrough

# 3. add narration + music + EN/ES subtitles (one command — needs a TTS endpoint; see scripts/_env.sh)
DEVREL_VIDEO_ENV=~/.config/devrel-video/env.rc \
  $S/scripts/variant.sh projects/example-walkthrough leah --no-avatar     # → renders/out-leah.mp4

# 4. YouTube thumbnail (1280×720) + a README GIF
$S/scripts/thumbnail.sh projects/example-walkthrough                       # → renders/thumbnail.jpg
```

## Make it yours

- **Your product**: point `capture.url` at it (set `start_command` for a local app), confirm selectors in the
  Explore step (SKILL §2), set `url_label`.
- **Your brand**: `scripts/brand-extract.sh <your-url> <name>` → set `brand: <name>` in `brief.yaml`.
- **Swap the voice**: `scripts/variant.sh projects/example-walkthrough <voice> --no-avatar` (male leo/dan/zac,
  female leah/tara/jess/mia/zoe).
- **Optional layers**: a face-only avatar and multi-environment (terminal ⇄ browser) — see SKILL §5.7–5.8.
  Narration/avatar are "bring your own" infra (see `scripts/_env.sh`).
