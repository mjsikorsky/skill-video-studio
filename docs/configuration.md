# Configuration

A video is configured by `projects/<slug>/brief.yaml`; start from the [brief template](../.claude/skills/devrel-video/templates/brief.example.yaml). The [worked brief](../projects/example-walkthrough/brief.yaml) shows a complete project. Brand assets live under `brands/<name>/`.

| Brief field | Purpose |
| --- | --- |
| `id`, `mode`, `audience`, `message` | Project identity, video mode, audience, and one outcome |
| `cta`, `duration_target_seconds`, `brand` | Closing action, target length, and brand selection |
| `capture` | URL, local start command, viewport, and address-bar label |
| `beats` | Chapter labels and capture-relative timing |
| `approved_claims` | Only claims allowed to appear on screen |
| `outputs` | Output profile; `docs-16x9` is the working example |
| `audio` | Music, narration voice, subtitles, and optional avatar |
| `environments`, `terminal` | Optional terminal/browser sequence |

Portrait/social output profiles remain roadmap work. Avoid presenting them as completed features merely because the template lists a seam.

## Local settings

The scripts source `DEVREL_VIDEO_ENV` if provided, otherwise `~/.config/devrel-video/env`. This file is shell configuration: use only a file you trust. Keep it outside the repository. The [environment helper](../.claude/skills/devrel-video/scripts/_env.sh) documents the actual settings.

| Setting | Purpose |
| --- | --- |
| `DEVREL_VIDEO_ENV` | Optional path to your private local settings file |
| `ORPHEUS_URL` | Your compatible narration endpoint |
| `ORPHEUS_KEY`, `ORPHEUS_MODEL` | Optional endpoint token/model settings |
| `AVATAR_HOST`, `LS_DIR` | Your own SSH GPU host and LatentSync checkout |
| `AVATAR_STOP_OLLAMA` | `1` lets `variant.sh` stop the `ollama` service on the GPU host (via `sudo`) during lip-sync and restart it afterwards; off by default |
| `AVATAR_FREE_VRAM` | `0` stops `avatar.sh` from unloading idle `ollama` models on the GPU host; default `1` |
| `AVATAR_KEEP_REMOTE` | `1` keeps the per-run staging folder on the GPU host for debugging; it is removed by default |
| `THUMB_PORT` | Fixed loopback port for `thumbnail.sh`; a free port is chosen by default |
| `HYPERFRAMES_VERSION`, `PLAYWRIGHT_CLI_VERSION`, `VHS_VERSION`, `TTYD_VERSION` | Override a [pinned tool version](../.claude/skills/devrel-video/scripts/_versions.sh) |
| `BGM_STYLE` | Local music style; default `corporate` |

Silent browser walkthroughs do not need narration credentials or a GPU host. Optional services may incur costs according to your own setup. No provider account or service is provisioned by cloning this repo.

## Private media and Git ignores

Presenter plates belong outside the public repo. Derived avatar footage and generated MP4/audio files are ignored. Only two curated public project folders are currently allowlisted. See [security and privacy](security-and-privacy.md) before changing the allowlist or sharing a recording.
