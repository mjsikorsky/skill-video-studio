#!/usr/bin/env python3
"""Apply narrate.py's timing map to a project's index.html — the deterministic re-time step.

Reads <project>/timing.json (written by narrate.py) and rewrites every timing token in
<project>/index.html by ELEMENT ID / GSAP SELECTOR (not by current value), so it's idempotent
and safe to re-run for any voice. This is what makes "change the voice" reliable: a snappier
voice yields a shorter cut, and every scene/chapter/bubble/GSAP position moves with it.

Usage: retime.py <project_dir>

Assumes the standard composition structure (templates/composition.html): ids root/bg/bgm/title/
frame/a-roll/brandmark/ch1/ch2/ch3/cta and optional avatar/avatar-cta; the fixed GSAP offsets below
mirror that template. If you fork the composition's structure, update the maps here too.
"""
import sys, os, re, json

proj = sys.argv[1].rstrip("/")
T = json.load(open(os.path.join(proj, "timing.json")))
html_path = os.path.join(proj, "index.html")
html = open(html_path).read()

def fmt(v):                                   # 0.4, 27.23, 6 — trailing-zero-free like the template
    return ("%.2f" % round(v, 2)).rstrip("0").rstrip(".")

total, td = T["total"], T["title_dur"]
fs, fd = T["footage_start"], T["footage_dur"]
cs, cd = T["cta_start"], T["cta_dur"]
vo, ld = T["vo_starts"], T["line_durs"]
ch1, ch2, ch3 = T["ch1"], T["ch2"], T["ch3"]

# id -> (data-start, data-duration). None = leave that attribute alone. avatar* are optional.
ELEMENTS = {
    "root":       (None, total),
    "bg":         (0,    total),
    "bgm":        (0,    total),
    "title":      (0,    td),
    "frame":      (fs,   fd),
    "a-roll":     (fs,   fd),
    "brandmark":  (fs,   fd),
    "ch1":        (ch1[0], ch1[1] - ch1[0]),
    "ch2":        (ch2[0], ch2[1] - ch2[0]),
    "ch3":        (ch3[0], ch3[1] - ch3[0]),
    "cta":        (cs,   cd),
    "avatar":     (vo[0], ld[0]),     # optional: says the first line
    "avatar-cta": (vo[-1], ld[-1]),   # optional: says the last (CTA) line
}
OPTIONAL = {"avatar", "avatar-cta"}

def id_re(elem_id):
    """Match an id attribute exactly — not data-id="…" or other *-id attributes."""
    return r'(?<![\w-])id="%s"' % re.escape(elem_id)

def set_attr(html, elem_id, attr, val):
    """Replace attr="NUM" inside the opening tag that carries id="elem_id". Returns (html, hits)."""
    hits = [0]
    tag_re = re.compile(r'<[^>]*%s[^>]*>' % id_re(elem_id))
    def fix_tag(m):
        tag = m.group(0)
        new, n = re.subn(r'((?<![\w-])%s=")[0-9.]+(")' % re.escape(attr),
                         lambda a: a.group(1) + fmt(val) + a.group(2), tag, count=1)
        hits[0] += n            # count the attribute MATCH (not whether the value changed — idempotent-safe)
        return new
    return tag_re.sub(fix_tag, html), hits[0]

for eid, (start, dur) in ELEMENTS.items():
    present = re.search(id_re(eid), html) is not None
    if not present:
        if eid in OPTIONAL:
            continue
        sys.exit("retime: required element #%s not found in index.html" % eid)
    for attr, val in (("data-start", start), ("data-duration", dur)):
        if val is None:
            continue
        html, hits = set_attr(html, eid, attr, val)
        if hits != 1:
            sys.exit("retime: #%s %s matched %d times (expected 1)" % (eid, attr, hits))

# GSAP tween positions: (method, selector) -> absolute time. Offsets mirror composition.html.
# #title tweens stay relative to 0 (title always starts at 0), so they're intentionally omitted.
GSAP = {
    ("from", "#frame"):        fs,
    ("from", "#a-roll"):       fs,
    ("from", "#brandmark"):    fs + 0.3,
    ("from", "#ch1"):          ch1[0] + 0.1,
    ("from", "#ch2"):          ch2[0] + 0.1,
    ("from", "#ch3"):          ch3[0] + 0.1,
    ("from", "#cta .wordmark"): cs + 0.1,
    ("from", "#cta .cta-title"): cs + 0.23,
    ("from", "#cta .cta-url"):  cs + 0.48,
    ("from", "#avatar"):       vo[0],                       # optional
    ("to",   "#avatar"):       vo[0] + ld[0] - 0.28,        # optional
    ("from", "#avatar-cta"):   vo[-1],                      # optional
    ("to",   "#avatar-cta"):   vo[-1] + ld[-1] - 0.28,      # optional
}
GSAP_OPTIONAL = {"#avatar", "#avatar-cta"}

# tl.from("SEL", { ...vars, no nested {} ... }, POS) where POS is a number or a template-style
# "NUM+NUM" / "NUM-NUM" expression (e.g. 21.27+0.15). The vars object may contain ")" (an ease such as
# "cubic-bezier(...)"). POS is rewritten to the absolute time.
POS = r'[0-9.]+(?:\s*[-+]\s*[0-9.]+)?'
for (method, sel), val in GSAP.items():
    pat = re.compile(r'(tl\.%s\(\s*"%s"\s*,\s*\{[^{}]*\}\s*,\s*)%s(\s*\))' % (method, re.escape(sel), POS))
    html, n = pat.subn(lambda m: m.group(1) + fmt(val) + m.group(2), html)
    if n == 1:
        continue
    # An optional bubble may be absent; but if its element exists, its tweens must be retimed too.
    if sel in GSAP_OPTIONAL and re.search(id_re(sel[1:]), html) is None and n == 0:
        continue
    sys.exit("retime: GSAP %s %s matched %d times (expected 1)" % (method, sel, n))

open(html_path, "w").write(html)
print("retime: %s -> %ss (title %s, footage@%s, cta@%s)" % (proj, fmt(total), fmt(td), fmt(fs), fmt(cs)))
