# Troubleshooting

| Symptom | Check |
| --- | --- |
| Claude does not discover `/devrel-video` | Run Claude Code from the cloned studio root; keep `.claude/skills/devrel-video/` intact. |
| Playwright cannot launch Chromium | Install the browser/system dependencies and review the platform-specific sandbox notes. |
| Capture disappears between commands | Use the installed Playwright CLI daemon and the capture wrapper; avoid separate bare `npx` sessions. |
| Captured footage freezes during render | Preserve the wrappers' dense-keyframe conversion; composition rendering seeks through the video. |
| `hyperframes init` says the directory is not empty | Skip it. Capture fills the project folder first, and the render only needs `index.html`, copied from `templates/composition.html`. |
| Composition lint/check fails | Read the error; check clip IDs, timing fields, GSAP selectors, contrast, and referenced assets. |
| Narration endpoint fails | Check your own configured endpoint/model/voice; keep credentials out of logs and chat. |
| Avatar output drifts or fails | Review the private plate, required frame rate, host/model dependencies, and GPU memory notes. |
| New project does not show up in Git | Local projects are ignored by default; publish only reviewed, sanitized sources via the allowlist. |
| A generated MP4 or audio file is missing from a clone | Media build outputs are ignored; regenerate them from the included source. |

The [production notes](../.claude/skills/devrel-video/references/production-notes.md) and original [studio guide](local-devrel-video-studio-guide.md) contain the detailed environment findings. The original guides describe their development environment and include optional integrations; a documentation check is not a full render test.
