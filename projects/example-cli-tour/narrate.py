#!/usr/bin/env python3
# Fixed-beat narration for the multi-env cut. The composition beats are FIXED (not voice-driven), so we
# PLACE each spoken line at its beat start and fit the voice to a 27.2s total. Expects vo1..voN.wav in cwd.
# Writes voice.wav + captions.<lang>.srt (timed to the line starts). `--lines` prints the spoken lines.
import sys, wave
import numpy as np

SR = 48000
TOTAL = 27.2
# (start_seconds, spoken line) — placed at the composition beats: title / T1 / browser / T2 / CTA.
LINES = [
    (0.4,  "Making a product demo? Let Claude Code do it."),
    (4.0,  "Just point it at your product's URL."),
    (10.2, "It opens the page and records the real flow. Browse, filter, open."),
    (19.2, "Then it composes, masters, and hands you a finished video."),
    (24.6, "Make your own."),
]
if "--lines" in sys.argv:
    print("\n".join(l for _, l in LINES)); raise SystemExit

def load(path):
    with wave.open(path, 'rb') as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        d = np.frombuffer(w.readframes(n), dtype='<i2').astype(np.float32) / 32768.0
    if ch == 2: d = d.reshape(-1, 2).mean(axis=1)
    if sr != SR: d = np.interp(np.arange(int(len(d)*SR/sr))/SR, np.arange(len(d))/sr, d)
    return d

starts = [s for s, _ in LINES]
vos = [load(f"vo{i}.wav") for i in range(1, len(LINES) + 1)]
dur = [len(v) / SR for v in vos]

# Lines are placed at fixed beats; a line longer than its slot would overlap the next one.
for i in range(len(starts)):
    end = starts[i] + dur[i]
    nxt = starts[i + 1] if i + 1 < len(starts) else TOTAL
    if end > nxt:
        sys.exit(f"narrate: line {i + 1} ends at {end:.2f}s, past {nxt:.2f}s — shorten it or move the beat")

N = int(TOTAL * SR)
voice = np.zeros(N)
for v, s in zip(vos, starts):
    i0 = int(s * SR); i1 = min(N, i0 + len(v)); voice[i0:i1] += v[:i1 - i0]
st = np.clip(np.stack([voice, voice], axis=1), -1, 1)
with wave.open('voice.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((st * 32767).astype('<i2').tobytes())

def ts(x):
    ms = int(round(x * 1000))
    return f"{ms//3600000:02d}:{ms%3600000//60000:02d}:{ms%60000//1000:02d},{ms%1000:03d}"
EN = ["Making a product demo?\nLet Claude Code do it.",
      "Just point it at\nyour product's URL.",
      "It opens the page and records the real flow:\nbrowse, filter, open.",
      "Then it composes, masters,\nand hands you a finished video.",
      "Make your own."]
ES = ["¿Haciendo un demo de producto?\nDeja que Claude Code lo haga.",
      "Solo apúntalo a la URL\nde tu producto.",
      "Abre la página y graba el flujo real:\nexplora, filtra, abre.",
      "Luego compone, masteriza\ny te entrega un vídeo terminado.",
      "Crea el tuyo."]
for lang, txt in (('en', EN), ('es', ES)):
    out = [f"{i}\n{ts(s)} --> {ts(s + d)}\n{t}\n" for i, (s, d, t) in enumerate(zip(starts, dur, txt), 1)]
    open(f"captions.{lang}.srt", 'w').write("\n".join(out))
print(f"wrote voice.wav + captions (lines at {starts})")
