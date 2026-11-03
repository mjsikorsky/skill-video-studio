#!/usr/bin/env python3
"""Face-tracking crop → a pinned 512x512 face bubble.

LatentSync keeps the plate's real head motion (only the mouth is regenerated), so a lively
plate looks jittery once cropped to a small circle. vidstab only removes *frame* motion, not a
*moving subject*. This follows the face every frame — keeping it centered AND at constant apparent
size — so the head stays pinned in the bubble; only natural rotation/expression remains.

Run inside the LatentSync venv, cwd = LatentSync dir (needs checkpoints/auxiliary/models/buffalo_l).
Usage: track_crop.py <in.mp4> <out.mp4> [face_scale=2.0]   (out is mp4v; caller re-encodes to h264)
"""
import sys, cv2, numpy as np
from insightface.app import FaceAnalysis

inp, out = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0

cap = cv2.VideoCapture(inp)
W, H = int(cap.get(3)), int(cap.get(4))
FPS = cap.get(5) or 25.0

app = FaceAnalysis(name="buffalo_l", root="checkpoints/auxiliary", providers=["CPUExecutionProvider"])
app.prepare(ctx_id=-1, det_size=(512, 512))

frames, cx, cy, sz, last = [], [], [], [], None
while True:
    ok, fr = cap.read()
    if not ok:
        break
    frames.append(fr)
    faces = app.get(fr)
    if faces:                                    # largest face; carry last through misses
        b = max(faces, key=lambda f: (f.bbox[2]-f.bbox[0])*(f.bbox[3]-f.bbox[1])).bbox
        last = ((b[0]+b[2])/2, (b[1]+b[3])/2, b[3]-b[1])
    c = last if last is not None else (W/2, H/2, H/3.0)
    cx.append(c[0]); cy.append(c[1]); sz.append(c[2])

n = len(frames)
if n == 0:
    sys.exit("track_crop: no frames read")

def smooth(a, k):                                # light box filter: kill detector jitter, keep the face pinned
    a = np.asarray(a, float)
    if len(a) < 3:
        return a
    k = max(3, min(k | 1, (len(a)//2)*2 + 1))     # odd window: an even one shifts the track by half a frame
    return np.convolve(np.pad(a, k//2, mode="edge"), np.ones(k)/k, mode="valid")

K = max(3, int(FPS * 0.25) | 1)                  # ~0.25s window → tight follow; odd so it stays centred
cxs, cys, szs = smooth(cx, K), smooth(cy, K), smooth(sz, K)

vw = cv2.VideoWriter(out, cv2.VideoWriter_fourcc(*"mp4v"), FPS, (512, 512))
for i, fr in enumerate(frames):
    s = int(min(szs[i] * scale, min(W, H)))      # crop side tracks face size → constant apparent size (no lean-zoom)
    x = int(min(max(cxs[i] - s/2, 0), W - s))
    y = int(min(max(cys[i] - s*0.55, 0), H - s)) # bias up: headroom over chin
    vw.write(cv2.resize(fr[y:y+s, x:x+s], (512, 512), interpolation=cv2.INTER_LANCZOS4))
vw.release()
print("track_crop: %d frames, K=%d, side~%d" % (n, K, int(np.median(szs)*scale)))
