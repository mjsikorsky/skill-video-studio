# Real Claude Code demo

The committed recording and generated brief predate the repository rename to `skill-video-studio`. Their original URLs redirect to the current repository; the commands below and recording tape use the new name.


The short README GIF follows the approved black-background preset: install the studio, invoke `/devrel-video` in real Claude Code, and inspect a useful result. It records the skill's **intake stage**, creating `projects/demo/brief.yaml` and a three-beat walkthrough plan. No browser capture, video render, external media service, or publishing occurs.

The studio keeps its native layout. Clone the full repository and run Claude Code from its root; the project skill is already at `.claude/skills/devrel-video`.

```bash
git clone https://github.com/aaitor/skill-video-studio studio
cd studio
claude -p "/devrel-video Plan brief.md. Do not render."
```

Before that request, supply `brief.md` with your intended product, audience, flow, brand, duration, and claims. The recording uses [this public input](brief.md), the existing Acme fixture, and the actual brief template. The resulting [recorded brief](recorded-brief.yaml) is saved alongside the GIF for inspection.

## Reproduce the recording

Needs Python 3.10+, Git, authenticated Claude Code, [VHS with ttyd/ffmpeg](https://github.com/charmbracelet/vhs#installation), and DejaVu Sans Mono. This invokes your real Claude account and may consume model usage. It does not require the full video pipeline or optional narration/GPU infrastructure.

```bash
python3 examples/record_demo.py
```

The helper uses an isolated temporary project, records a real clone and harness invocation, then copies the finished GIF and actual generated brief back only after success. Use `--out /tmp/demo.gif --brief-out /tmp/brief.yaml` to choose other outputs. The recording clones the upstream repository shown on screen, not your local checkout; to record a published fork, pass `--repo https://github.com/<owner>/skill-video-studio`.

The helper loads only its session settings, disables optional hooks, excludes configured MCP servers, and permits file/skill tools only; it does not give Claude a shell/browser tool or bypass permissions. It leaves global settings unchanged. The visible `claude` command applies that configuration through a session-local shell function.

[demo.tape](demo.tape) sets the actual commands and pure black 1280 × 640 style. [claude-demo.md](claude-demo.md) defines the task and concise final response. Waiting time is omitted using `Hide`/`Show`; the commands, artifact creation, and final answer are real. Live recording is manual and never run in CI.

## Finished video examples

- [example-walkthrough](../projects/example-walkthrough/README.md): local Acme fixture, real browser capture, composition, narration/music, and subtitles.
- [example-cli-tour](../projects/example-cli-tour/README.md): composed terminal/browser film; its terminal scenes are authored HTML reenactments, explicitly documented by that example.

Those examples remain intact. Their generated MP4/audio outputs are ignored and must be rebuilt. The short setup GIF does not claim that a video was rendered during its planning-only session.
