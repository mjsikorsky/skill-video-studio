# Production notes

Hard-won environment facts and the roadmap. The full design rationale is in the repo-root guide
(`docs/local-devrel-video-studio-guide.md`, v1.2).

## Environment gotchas (verified on Ubuntu 26.04, Node 24, ffmpeg 8)

- **Browser sandbox.** On AppArmor/userns-restricted hosts (`apparmor_restrict_unprivileged_userns=1`),
  capture needs `PLAYWRIGHT_MCP_SANDBOX=false`. HyperFrames' render (chrome-headless-shell) needs **no** flag.
  Both are handled by the scripts.
- **playwright-cli daemon.** Install the binary (local/global) — a bare per-command `npx @playwright/cli`
  drops the browser between `open` / `run-code` / `close`. `capture.sh` installs it under `.pw/` once.
- **`hyperframes init`** is non-interactive for agents and **requires** `--example|--video|--audio` plus
  `--non-interactive`. It refuses a non-empty folder, so projects skip it: `capture.sh` fills the folder first
  and the render only needs `index.html`. It pings GitHub for skills unless `HYPERFRAMES_SKIP_SKILLS=1`. Telemetry off:
  `hyperframes telemetry disable` or `HYPERFRAMES_NO_TELEMETRY=1` / `DO_NOT_TRACK=1`.
- **Determinism.** The browser *capture* is reproducible, not frame-identical — drive chapter timing from
  recorded beats, not wall-clock. The HyperFrames *render* is deterministic (same HTML → same frames).
- **Composition contract.** Sibling `class="clip"` elements with `data-start`/`data-duration`/`data-track-index`;
  video is a `<video class="clip">`; a **paused** GSAP timeline on `window.__timelines["main"]`; every animated
  element needs a stable `id` (`:nth-of-type` counts all tags of that type, not the class). Clips may overlap
  in time on the same track.

## Vendoring (required for confidential/production)

The composition template loads **GSAP** and **Inter** from CDNs (fine for public drafts; the security hook
flags the script tag on purpose). For a confidential render:

- GSAP → download `gsap.min.js` into the project and `<script src="gsap.min.js">`.
- Inter → drop `.woff2` files in the project and add `@font-face` rules; remove the Google Fonts `<link>`.
- Re-run the §14.5 check: no remote `<script>`, `<link>`, font, or media reference survives.

## Capture modes (pick by intent)

- **Interaction walkthrough** (default): Playwright `page.screencast` — shows the product being *used*.
- **Static showcase**: `hyperframes capture <URL>` — screenshots + brand tokens, camera over stills
  (this is what `/product-launch-video` uses, and how `brand-extract.sh` pulls tokens + logo).
- **Terminal / Claude Code**: `scripts/capture-terminal.sh <tape>` — VHS renders the real CLI TUI headlessly
  (feature 5 below). Combine with the browser modes for a multi-environment demo.

## Production features (all supported)

Each has a commented seam in `templates/composition.html` and a field in `brief.yaml`.

1. **Music.** ✅ Supported. Fastest path (no auth/model): `scripts/gen-bgm.py` → a local synth bed
   (`gen-bgm.py bed.wav [dur] [style]`, then ffmpeg → `bgm.mp3`), wired through the `<audio id="bgm" … data-track-index="9">`
   seam. Six styles (3rd arg or `BGM_STYLE` env, default **corporate**): corporate · ambient · lofi · uplift ·
   minimal · focus — warm engine (windowed-sinc lowpass + FFT reverb + FM/Rhodes keys + soft drums; see the
   repo-root `docs/usage.md` "Music & voice" table). Audition one: `gen-bgm.py sample.wav 15 <style>`. Produced track: `/media-use resolve --type bgm` (HeyGen catalog — needs `heygen` sign-in) or
   `--local-only` (MusicGen). Under narration, lower the bed and duck with `/hyperframes-audio` (voiceover
   carve). Tune key/tempo/layers in `gen-bgm.py`. Note: convert footage with **dense keyframes**
   (`-g 30 -keyint_min 30 -sc_threshold 0`) or the renderer freezes footage frames between seeks.
2. **Background narration (2a).** ✅ Supported. TTS each beat line with `scripts/tts.sh` in a **voice that
   matches the presenter** (any OpenAI-compatible TTS endpoint; the reference is Orpheus — male `leo`/`dan`/`zac`,
   female `leah`/`tara`/`jess`/`mia`/`zoe`). Set `ORPHEUS_URL`/`ORPHEUS_KEY` (+ optional `ORPHEUS_MODEL`) once —
   see `scripts/_env.sh`; if it errors, check the endpoint is reachable and the model/voice exist. Changing the
   voice later is one command — `scripts/variant.sh <project> <voice>`
   (re-TTS → narrate.py → `retime.py` auto-applies the new `timing.json` to index.html → mix → re-lip-sync the
   avatar bubbles → `renders/out-<voice>.mp4`; `--no-avatar` skips the GPU step). `retime.py` is idempotent and
   keys off element ids/GSAP selectors, so it's safe to re-run for any voice. `templates/narrate.py` measures the lines, **derives the scene/chapter
   times from the audio** (never the reverse), writes `voice.wav`, and re-times `captions.<lang>.srt` to the
   voice. Retime the composition to those numbers (a 26s silent cut → ~31s), then `scripts/mix-audio.sh`
   ducks the music bed under the voice and masters to −16 LUFS. Clean text first (no parens/version numbers;
   em-dash → comma). Piper (`en_US-lessac-medium`, bundles its own onnxruntime) is a working no-auth fallback.
   `narrated-devrel` mode.
3. **Avatar (2b).** ✅ Supported — **face-only circular bubble**, lip-synced, shown ONLY at intro / one
   transition / CTA (product stays the hero — a full-time presenter turns it into a webinar). `scripts/avatar.sh
   <plate> <line.wav> avatar-face.mp4` runs **LatentSync (256) on a GPU host over SSH** (reference: an AMD RX 9060
   XT / ROCm box — proven local, no HeyGen/NVIDIA needed; set `AVATAR_HOST`/`LS_DIR`, see `scripts/_env.sh`). Feed
   `<line.wav>` = the exact narration segment the mouth should say (trim it
   from `narration-mix.mp3` so lips match what's heard); the script lip-syncs, then **face-tracks** the head into
   a pinned square (`track_crop.py` follows the face every frame at constant size so it doesn't drift in the circle
   — vidstab alone can't calm a *moving subject*; the circle is CSS `border-radius:50%`, `data-track-index=11`). Depends on (2a):
   narration first, avatar rendered against a segment of it (feed the clean per-line `voN.wav` for the tightest sync).
   **Gotchas baked into avatar.sh** (spike + real use): (a) LatentSync is a **25fps model** (`stage2.yaml
   video_fps:25`) → avatar.sh normalizes any plate to 25fps first, else the lips **drift** against the audio (a
   30fps plate was a real sync bug); (b) on the reference AMD box the discrete GPU was HIP **device 1** (device 0 =
   iGPU) → `HIP_VISIBLE_DEVICES=1` (NVIDIA hosts use `CUDA_VISIBLE_DEVICES` instead); (c) 256 inference peaks
   ~14 GB → avatar.sh frees idle model-server VRAM, but another model server can reload mid-run → for a clean run
   stop it (e.g. `sudo systemctl stop ollama`; the TTS server is separate, unaffected) and restart
   after — `variant.sh` does this only with `AVATAR_STOP_OLLAMA=1`, and restarts it even if the lip-sync fails;
   `AVATAR_FREE_VRAM=0` skips unloading idle models; each run stages in a private `mktemp -d` dir that is removed on exit; (d) **SSH to the GPU host can be flaky** → avatar.sh ships its remote script as a *file* (scp, integrity-checked),
   not piped over stdin. `STEPS=30` (env) for a crisper mouth; brighten a backlit plate (`ffmpeg eq`). ~10 min/clip
   cold. Plate must be ≥ the line (no auto-loop). Reference env: LatentSync 1.5 ckpt + a torch build for your GPU
   (the AMD box used 2.9.1+rocm6.4); set `AVATAR_HOST`/`LS_DIR` (see `scripts/_env.sh`). **Privacy + consent:** use only a face you have rights to; `<plate>` is
   `avatar_plate:` from the brief — a **private recording kept OUTSIDE the (public) repo**
   (`~/Videos/<Org>/DevRel/Talking_Head/<name>/`), and every derived `avatar-*.mp4`/render is gitignored. Sharper
   mouth (512 / LatentSync 1.6) needs Orpheus stopped for VRAM — not worth it at bubble size. `narrated-devrel` + avatar.
4. **Subtitles (3).** ✅ Supported. Author caption cues timed to the beats → `captions.<lang>.srt` (soft,
   toggleable, one file per language). Ship the `.srt` alongside the clean video; burn a social/autoplay
   cut with `scripts/subtitles.sh`. Once narration exists, generate cues from its transcript (WhisperX via
   `/media-use`, word-level timing) instead of authoring, or hand off to `/embedded-captions`. Keep a
   terminology dictionary (product names, protocols like x402/MPP) and proofread. "Alternative subtitles"
   = multiple language `.srt` from the same cues.
5. **Multi-environment — terminal ⇄ browser.** ✅ Supported. A demo can move between the CLI (Claude Code)
   and the browser (prompt in Claude Code → the product in the browser → back). Capture terminal beats with
   `scripts/capture-terminal.sh <tape>` → **VHS** (`.tape` is to the terminal what `hero-script.js` is to the
   browser) renders the **real Claude Code TUI headlessly** to `term<N>.mp4`. Spike facts:
   - **Fidelity is perfect.** The full-screen TUI (logo, welcome box, highlighted prompt bar, streamed answer,
     `✻ Cooked for 2s`, menu popups) renders pixel-perfect — the alt-screen/redraw worry was unfounded. VHS's
     bundled headless chromium **launched clean on this AppArmor/Wayland host — no `--no-sandbox` needed** (unlike
     Playwright capture). Real `claude` calls work from inside VHS (auth inherited, cheap).
   - **Sanitation is mandatory — the terminal's "no-PII" gate.** A raw take leaked the cwd path, `N MCP servers
     need authentication`, the `CLAUDE_CODE_CHILD_SESSION` "transcript saving is off" warning, git branch, plan
     name, and a surprise "Teach auto mode about your environment?" popup. The template tape fixes it: record in a
     **clean throwaway dir**, `unset CLAUDE_CODE_CHILD_SESSION`, `Escape` popups, and alias `claude` to
     `claude --strict-mcp-config` to drop the "N MCP servers need authentication" line (the alias is defined in the
     tape's hidden section, so the recorded command stays a clean `claude`, not the flag).
   - **Live = non-deterministic.** Wording *and* surprise popups vary run to run. Two paths — **support both**:
     (a) **capture** a real session (VHS scripted, or `asciinema rec` + `agg` render for a free-form take) —
     authentic; (b) **re-enact** with the ready-made template `templates/cc-terminal.html` (a styled `.cc-terminal`
     whose prompt+answer are typed/revealed by GSAP — monospace `width` in `ch` + `ease:"steps(N)"`) —
     deterministic, re-times to narration, zero PII, you author the text.
   - **Smooth hand-off = fade through the brand teal.** Place beats as sequential timeline clips with
     terminal-/browser-frame chrome and fade each **down to the `.bg`** (the composition already fades scenes over
     it). A pure crossfade is **muddy** (terminal text ghosts through the page); fade-through-**black** is clean but
     off-brand; fade-through-**teal** is clean *and* on-brand, and the GSAP version adds the scale-pop. Quick
     non-composition preview: `scripts/stitch-envs.sh out.mp4 0b1020 term1.mp4 capture.mp4 term2.mp4`. Worked
     example of the re-enactment beat: `templates/cc-terminal.html`. Match VHS `Set Width/Height` to the browser viewport (1600×900) so
     beats stitch without letterboxing.
   - **Tooling (one-time, `scripts/capture-terminal.sh` self-installs vhs+ttyd):** `go install github.com/charmbracelet/vhs@$VHS_VERSION` (pinned in `scripts/_versions.sh`);
     ttyd static binary from `tsl0922/ttyd` releases; ffmpeg (present). Free-form path: `asciinema` (pip) + `agg`
     (`cargo install --git https://github.com/asciinema/agg agg`, needs rustc ≥1.86 — use `+stable` if your default is older).

Dependency order: **narration → avatar**; subtitles, music, and multi-environment are independent (author
subtitles to the beats now; re-time them to the narration transcript when it exists).
