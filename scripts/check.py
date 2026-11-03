#!/usr/bin/env python3
"""Offline source, documentation, manifest, and local music checks; no rendering/services."""

import ast
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlsplit
import wave
import xml.etree.ElementTree as ET

import numpy as np
import yaml

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {".git", ".venv", "__pycache__", "node_modules", ".pw", ".vhs", ".hyperframes", ".playwright-cli"}


def check_links(path, errors):
    text = re.sub(r"^(`{3,}|~{3,}).*?^\1[^\n]*$", "", path.read_text(), flags=re.M | re.S)
    # Inline source examples are instructions, not live document/media links.
    text = re.sub(r'`[^`\n]+`', '', text)
    links = re.findall(r'!?\[[^\]\n]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)', text)
    links += re.findall(r'(?:href|src)=["\x27]([^"\x27]+)', text)
    for link in links:
        parsed = urlsplit(html.unescape(link))
        if parsed.scheme or parsed.netloc:
            continue
        if parsed.path:
            target = (ROOT if parsed.path.startswith("/") else path.parent) / unquote(parsed.path).lstrip("/")
        else:
            target = path
        if not target.exists():
            errors.append(f"{path.relative_to(ROOT)}: missing target {link}")
            continue
        if parsed.fragment and target.suffix == ".md":
            headings = re.findall(r"^#{1,6}\s+(.+)$", target.read_text(), flags=re.M)
            anchors = {re.sub(r"[^\w\- ]", "", heading.lower()).replace(" ", "-") for heading in headings}
            if parsed.fragment not in anchors:
                errors.append(f"{path.relative_to(ROOT)}: missing heading {link}")


def check_brief(path):
    data = yaml.safe_load(path.read_text())
    required = ["id", "mode", "audience", "message", "brand", "capture", "beats", "outputs", "duration_target_seconds"]
    if not isinstance(data, dict) or any(key not in data for key in required):
        raise ValueError("Brief is missing required fields")
    duration = data["duration_target_seconds"]
    if not isinstance(duration, (int, float)) or duration <= 0:
        raise ValueError("Brief duration must be positive")
    if not isinstance(data["beats"], list) or not data["beats"]:
        raise ValueError("Brief needs at least one beat")
    for beat in data["beats"]:
        if not beat.get("label") or not 0 <= beat["at_seconds"] < duration:
            raise ValueError("Brief beat needs a label and time within the duration")
    if not data["capture"].get("url") or not data["outputs"]:
        raise ValueError("Brief needs a capture URL and output profile")


def check_render_path(errors):
    """Guard the documented capture and silent-render path; the tools themselves stay out of CI."""
    skill = ROOT / ".claude/skills/devrel-video"
    example = ROOT / "projects/example-walkthrough"
    readme = (example / "README.md").read_text()
    # Capture fills the project folder first, and init refuses a non-empty folder.
    for path in (skill / "SKILL.md", example / "README.md"):
        if "hyperframes init projects/" in path.read_text():
            errors.append(f"{path.relative_to(ROOT)}: hyperframes init fails on a captured project")
    # npm installs into any ancestor with a package.json unless the prefix is explicit.
    if 'npm i --prefix "$skill/.pw"' not in (skill / "scripts/_versions.sh").read_text():
        errors.append("_versions.sh: install playwright-cli with an explicit --prefix")
    for script in sorted((skill / "scripts").glob("*.sh")):
        text = script.read_text()
        if "npm i" in text and script.name != "_versions.sh":
            errors.append(f"{script.name}: install playwright-cli through ensure_playwright_cli (_versions.sh)")
        # Reproducible renders: tools come from the pins in _versions.sh, never @latest.
        if "@latest" in text or "releases/latest" in text:
            errors.append(f"{script.name}: use a pinned version from _versions.sh, not latest")
        # The thumbnail server must not expose the project folder (private media) to the network.
        if "http.server" in text and "--bind 127.0.0.1" not in text:
            errors.append(f"{script.name}: bind the local http.server to 127.0.0.1")
    # The silent render must not need audio that only exists after a later step.
    before_render = readme.split("render-qa.sh")[0]
    for source in re.findall(r'<audio[^>]+src="([^"]+)"', (example / "index.html").read_text()):
        if source not in before_render:
            errors.append(f"projects/example-walkthrough/README.md: create {source} before render-qa.sh")


def check_shell(errors):
    """Lint every shell script; shellcheck comes from requirements-dev.txt (shellcheck-py)."""
    scripts = sorted(
        str(path)
        for path in ROOT.rglob("*.sh")
        if not any(part in EXCLUDED for part in path.relative_to(ROOT).parts)
    )
    try:
        result = subprocess.run(["shellcheck", "-S", "warning", "-x", *scripts], capture_output=True, text=True)
    except FileNotFoundError:
        errors.append("shellcheck not found: pip install -r requirements-dev.txt")
        return
    if result.returncode:
        errors.append("shellcheck:\n" + result.stdout.strip())


def write_tone(path, seconds, rate=24000):
    samples = np.arange(int(seconds * rate))
    tone = (0.3 * np.sin(2 * np.pi * 220 * samples / rate) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(tone.tobytes())


def check_narration_retime(errors):
    """Run the example's narrate.py + retime.py on synthetic voice lines; no TTS or render."""
    skill = ROOT / ".claude/skills/devrel-video"
    with tempfile.TemporaryDirectory(prefix="studio-retime-check-") as temporary:
        project = Path(temporary) / "project"
        shutil.copytree(ROOT / "projects/example-walkthrough", project, ignore=shutil.ignore_patterns("renders", "site"))
        for index, seconds in enumerate([2.6, 2.4, 2.1, 2.5, 3.0], 1):
            write_tone(project / f"vo{index}.wav", seconds)
        steps = [
            [sys.executable, "narrate.py"],
            [sys.executable, str(skill / "scripts/retime.py"), "."],
        ]
        for command in steps:
            result = subprocess.run(command, cwd=project, capture_output=True, text=True)
            if result.returncode:
                errors.append(f"narration/retime check: {Path(command[1]).name} failed: {result.stderr.strip()}")
                return
        timing = json.loads((project / "timing.json").read_text())
        retimed = (project / "index.html").read_text()
        cta = re.search(r'<[^>]*(?<![\w-])id="cta"[^>]*>', retimed)
        if not cta or f'data-start="{timing["cta_start"]:g}"' not in cta.group(0):
            errors.append("narration/retime check: #cta was not moved to timing.json's cta_start")
        result = subprocess.run(steps[1], cwd=project, capture_output=True, text=True)
        if result.returncode or (project / "index.html").read_text() != retimed:
            errors.append("narration/retime check: retime.py is not idempotent")
        # A line too long for its slot must stop the build instead of overlapping the next line.
        write_tone(project / "vo4.wav", 12.0)
        result = subprocess.run(steps[0], cwd=project, capture_output=True, text=True)
        if result.returncode == 0:
            errors.append("narration/retime check: narrate.py accepted overlapping narration lines")


def main():
    errors = []
    counts = {"python": 0, "shell": 0, "javascript": 0, "manifests": 0}
    for path in ROOT.rglob("*"):
        if not path.is_file() or any(part in EXCLUDED for part in path.relative_to(ROOT).parts):
            continue
        try:
            if path.suffix == ".md":
                check_links(path, errors)
            elif path.suffix == ".svg":
                ET.parse(path)
            elif path.suffix == ".json":
                json.loads(path.read_text())
            elif path.suffix in (".yaml", ".yml"):
                yaml.safe_load(path.read_text())
                if path.name in ("brief.yaml", "recorded-brief.yaml", "brief.example.yaml"):
                    check_brief(path)
                    counts["manifests"] += 1
            elif path.suffix == ".py":
                ast.parse(path.read_text(), filename=str(path))
                counts["python"] += 1
            elif path.suffix in (".sh", ".js"):
                command = ["bash", "-n"] if path.suffix == ".sh" else ["node", "--check"]
                result = subprocess.run(command + [str(path)], capture_output=True, text=True)
                if result.returncode:
                    errors.append(f"{path.relative_to(ROOT)}: {result.stderr.strip()}")
                counts["shell" if path.suffix == ".sh" else "javascript"] += 1
        except (SyntaxError, ValueError, ET.ParseError, yaml.YAMLError, TypeError, KeyError) as exc:
            errors.append(f"{path.relative_to(ROOT)}: {exc}")
    check_render_path(errors)
    check_shell(errors)
    check_narration_retime(errors)
    # Exercise one existing local utility, without TTS, GPUs, browsers, or any API.
    with tempfile.TemporaryDirectory(prefix="studio-music-check-") as temporary:
        output = Path(temporary) / "bed.wav"
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / ".claude/skills/devrel-video/scripts/gen-bgm.py"),
                str(output),
                "2",
                "corporate",
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode:
            errors.append("Local music smoke test failed: " + result.stderr)
        else:
            with wave.open(str(output)) as audio:
                if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate(), audio.getnframes()) != (
                    2,
                    2,
                    44100,
                    88200,
                ) or not any(audio.readframes(audio.getnframes())):
                    errors.append("Local music output has unexpected format, length, or silence.")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        raise SystemExit(1)
    print("OK: documentation links/headings, SVG/JSON/YAML, source syntax, shellcheck, brief fields, narration/retime, local WAV smoke test.")
    print(counts)


if __name__ == "__main__":
    main()
