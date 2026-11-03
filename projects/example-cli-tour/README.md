# example-cli-tour

A **multi-environment** demo: the cut moves between **Claude Code (terminal)** and the **browser** — a prompt
in Claude Code → the Acme product recorded live in the browser → back to Claude Code with the result — and each
beat hands off by fading through the brand colour (SKILL §5.8).

[![claude code ⇄ browser demo](renders/demo.gif)](https://youtu.be/lvpKaYUVNws)

▶ [Watch the full video with sound on YouTube](https://youtu.be/lvpKaYUVNws).

The terminal beats are the **deterministic HTML re-enactment** (`templates/cc-terminal.html`, composed inline in
`index.html`): the prompt is typed with a GSAP `steps()` typewriter and the answer revealed line by line — no
VHS, no live model, no PII, pixel-perfect and re-timable. The browser beat reuses the Acme mock app
(`../example-walkthrough/site/`). It's **narrated** (voice `leah`) over a **studio** music bed, with EN/ES subtitles.

> `capture.mp4`, `bgm.*`, `voice.wav`, `narration-mix.mp3`, and `renders/*.mp4` are **gitignored**. Committed:
> `brief.yaml`, `capture.js`, `index.html`, `narrate.py`, `narrate.sh`, `thumbnail.html`, `captions.*.srt`, and
> `renders/{contact-sample.png, thumbnail.jpg, demo.gif}`.

## Make it

```bash
# from the repo root
S=.claude/skills/devrel-video

# 1. browser beat — serve the shared Acme mock app and capture it
python3 -m http.server 8000 --bind 127.0.0.1 --directory projects/example-walkthrough/site &
$S/scripts/capture.sh projects/example-cli-tour/capture.js "http://localhost:8000/"
kill %1

# 2. terminal beats — already authored inline in index.html (the cc-terminal re-enactment).
#    To capture a REAL Claude Code session instead, use VHS: $S/scripts/capture-terminal.sh <tape>

# 3. narration (leah) + studio music bed, pre-mixed → narration-mix.mp3 (needs a TTS endpoint — scripts/_env.sh)
DEVREL_VIDEO_ENV=~/.config/devrel-video/env.rc projects/example-cli-tour/narrate.sh leah
$S/scripts/render-qa.sh projects/example-cli-tour

# 4. thumbnail
$S/scripts/thumbnail.sh projects/example-cli-tour
```

## Make it yours

- **Change the story**: edit the two `cc-*` beats in `index.html` (the prompt + the answer lines) and the
  browser beat's `capture.js`. Keep the typewriter `width:Nch` in sync with its `steps(N)` (N = char count).
- **More environments / a real session**: see SKILL §5.8 (VHS capture, `stitch-envs.sh`, the composition seam).
- **Change the narration**: edit the lines + their beat-start times in `narrate.py`, then re-run `narrate.sh`
  (voice arg, e.g. `narrate.sh leo`) and render. The beats are fixed by the composition, so the voice fits them.
