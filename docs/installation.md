# Installation

The repository is now `aaitor/skill-video-studio`. Existing clones can update their remote:

```bash
git remote set-url origin https://github.com/aaitor/skill-video-studio.git
```

The Claude Code skill remains `/devrel-video`.


The repository is the workspace: the skill lives at `.claude/skills/devrel-video`, while brands and video projects live at the root. Preserve that layout rather than cloning the whole studio inside another skill directory.

## Open in Claude Code

```bash
git clone https://github.com/aaitor/skill-video-studio.git
cd skill-video-studio
claude
```

Claude Code discovers the project skill. Ask `/devrel-video` to prepare a brief first; this planning step needs an authenticated harness but does not require the capture/render stack. The [recorded example](../examples/README.md) shows this step with the bundled public Acme fixture.

## Capture and rendering prerequisites

| Tool | Used for |
| --- | --- |
| Node.js 22+ and npm | Playwright CLI and HyperFrames |
| FFmpeg and ffprobe | Conversion, mastering, audio mixing, and media QA |
| Chromium / Playwright browser | Capture, composition rendering, and thumbnails |
| Python 3.10+ | Utility scripts and narration/timing helpers |
| NumPy | The local background-music generator and some optional image/video helpers |

The existing pipeline was developed on Linux. For the original environment commands and known platform constraints, see the [full setup guide](local-devrel-video-studio-guide.md#5-initial-ubuntu-setup) and [production notes](../.claude/skills/devrel-video/references/production-notes.md). Review the commands for your machine rather than assuming a different distribution has the same packages.

The bundled scripts target Linux (x86_64 or aarch64) and avoid GNU-only flags where practical, but macOS is not a tested platform: install `ttyd` yourself (`brew install ttyd`) for terminal capture, and expect to adapt host-specific steps. Windows is not supported outside WSL.

The capture wrapper installs Playwright CLI under `.pw/` if needed; it uses npm and may download packages/browsers. HyperFrames is invoked through `npx`. Tool versions (HyperFrames, Playwright CLI, VHS, ttyd) are pinned in [`scripts/_versions.sh`](../.claude/skills/devrel-video/scripts/_versions.sh) for reproducible renders; override one with its environment variable, such as `HYPERFRAMES_VERSION=…`, and bump the pin deliberately after a test render. Install the browser and required system libraries before trying a full render. Optional HyperFrames/creative/media skills described in the guide are additional integrations, not bundled dependencies.

## First full video

Follow the [worked example](../projects/example-walkthrough/README.md) to serve the local Acme app, capture three real interactions, compose, render, and generate a thumbnail. Begin with a silent cut. Narration, avatars, and voice swapping have extra requirements documented in [configuration](configuration.md) and [usage](usage.md).

Full video generation is a local production workflow and can take time and disk space. The README demo plans a brief only; it does not prove your capture/render stack is installed.

## Install v1.0.1

For a stable install, clone the release tag instead of the moving default branch:

```bash
git clone --branch v1.0.1 --depth 1 https://github.com/aaitor/skill-video-studio.git
cd skill-video-studio
claude
```

The release keeps the native workspace layout and `/devrel-video` invocation. See the [release notes](https://github.com/aaitor/skill-video-studio/releases/tag/v1.0.1) for included features and validation limits.
