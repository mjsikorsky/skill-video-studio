# Changelog

## Unreleased

- `tts.sh`: JSON-encode the request so narration lines containing quotes or backslashes work.
- `variant.sh`: stopping `ollama` on the GPU host is now opt-in (`AVATAR_STOP_OLLAMA=1`) and it is always restarted, even when lip-sync fails; a failing `narrate.py --lines` now stops the run; the CTA bubble uses the last line.
- `avatar.sh`: stage each run in a private, per-run folder on the GPU host that is removed afterwards; quote remote values safely; no `eval`.
- `thumbnail.sh`: install `playwright-cli` with an explicit prefix, serve the project on 127.0.0.1 only, and use a free port.
- `narrate.py` (template and examples): stop instead of overlapping narration lines when a voice is too slow for its beats.
- Pin HyperFrames, Playwright CLI, VHS, and ttyd in `scripts/_versions.sh`; `render-qa.sh` uses one pinned HyperFrames for lint, check, and render, and the contact sheet spans the whole video.
- `capture.sh`/`capture-terminal.sh`: never reuse an earlier take; always close the browser session; no GNU-only flags; ttyd for aarch64.
- `retime.py`: handle `)` inside tween options and `NUM+NUM` positions, match ids exactly, and fail when a present avatar bubble's tweens can't be retimed.
- `track_crop.py`: use an odd smoothing window so the face track isn't shifted by half a frame.
- Clean up temporary files in `tts.sh`, `mix-audio.sh`, and `brand-extract.sh`; surface `hyperframes capture` errors.
- `record_demo.py --repo` records a published fork instead of upstream.
- Move the original guides to `docs/`.
- `scripts/check.py`: add shellcheck and an offline narrate → retime test.

## v1.0.1 — 2026-11-02

- Fix the compose step: `hyperframes init` refuses a captured project folder, so new videos start from `templates/composition.html`.
- Fix the silent render of `example-walkthrough`, which stopped on a narration mix that only exists after step 3.
- Install `playwright-cli` under `.pw/` even when a parent folder has a `package.json`, and show npm errors.

## v1.0 — 2026-10-29

- Publish the first release as Video Studio Skill with updated shared artwork.
- Rename the repository to `skill-video-studio`; update installation, project CTA links, and recording commands. Keep `/devrel-video` unchanged.

- Adopt the shared repository format with a branded banner, MIT license, focused README, guides, and community files.
- Add a real black-background Claude Code intake demo, producing a walkthrough brief before capture/render.
- Add offline source/documentation checks and a local background-music smoke test.
- Preserve the studio's native skill layout, production helpers, worked examples, and original long-form guides.
