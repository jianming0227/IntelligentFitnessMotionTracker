"""Flick mascot generator: one geometry, any pose -> SVG.
Geometry constants here are mirrored 1:1 in lib/features/progress/widgets/mascot/flick_painter.dart.
"""
import math, sys, json
ORANGE, LIME, INK, WHITE = "#FF9A2E", "#C8FF2D", "#14161B", "#FFFFFF"
BODY = ("M256 58 C 286 120 330 140 352 120 C 392 180 396 250 388 320 "
        "C 378 400 324 446 256 446 C 188 446 134 400 124 320 "
        "C 116 250 140 196 176 156 C 186 186 204 196 220 190 C 214 140 226 96 256 58 Z")
CORE = ("M256 230 C 280 262 330 280 330 340 C 330 390 296 416 256 416 "
        "C 216 416 182 390 182 340 C 182 290 230 270 256 230 Z")
BAND = "M128 228 C 190 206 322 206 384 228 L 388 262 C 322 242 190 242 124 262 Z"
BAND_TAIL = "M384 236 L 432 214 L 426 246 Z M384 246 L 424 262 L 404 282 Z"
EYES = [(216, 306), (296, 306)]
EYE_RX, EYE_RY = 17, 24
SHOULDERS = [(140, 322), (372, 322)]
ARM_LEN = 66
MOUTH_Y, MOUTH_X0, MOUTH_X1 = 352, 230, 282

POSES = {  # eyelid 0..1, smile -1..1, arm angle deg from down (outward +), droop, lift(y offset), zzz, confetti
  "idle":      dict(tilt=0.0, eyelid=0.0,  smile=0.35, arms=(35, 35),   droop=0.0,  lift=0,   zzz=False, confetti=False),
  "happy":     dict(tilt=0.0, eyelid=0.0,  smile=1.0,  arms=(70, 70),   droop=0.0,  lift=-10, zzz=False, confetti=False),
  "sleepy":    dict(tilt=0.0, eyelid=0.55, smile=0.1,  arms=(20, 20),   droop=0.03, lift=0,   zzz=True,  confetti=False),
  "sad":       dict(tilt=0.5, eyelid=0.3, smile=-0.7, arms=(12, 12),   droop=0.06, lift=0,   zzz=False, confetti=False),
  "celebrate": dict(tilt=0.0, eyelid=0.0,  smile=1.0,  arms=(140, 140), droop=0.0,  lift=-24, zzz=False, confetti=True),
}

def arm(i, a):
    sx, sy = SHOULDERS[i]; s = -1 if i == 0 else 1
    r = math.radians(a)
    hx, hy = sx + s * ARM_LEN * math.sin(r), sy + ARM_LEN * math.cos(r)
    d = f"M{sx} {sy} L {hx:.1f} {hy:.1f}"
    return (f'<path d="{d}" stroke="{INK}" stroke-width="32" stroke-linecap="round" fill="none"/>'
            f'<path d="{d}" stroke="{ORANGE}" stroke-width="16" stroke-linecap="round" fill="none"/>')

def mouth(smile):
    c = MOUTH_Y + 30 * smile
    y = MOUTH_Y - 6 * smile  # corners lift a little when smiling
    return f'<path d="M{MOUTH_X0} {y:.1f} Q 256 {c:.1f} {MOUTH_X1} {y:.1f}" fill="none" stroke="{INK}" stroke-width="12" stroke-linecap="round"/>'

def eye(i, eyelid):
    cx, cy = EYES[i]
    out = [f'<ellipse cx="{cx}" cy="{cy}" rx="{EYE_RX}" ry="{EYE_RY}" fill="{INK}"/>',
           f'<circle cx="{cx+6}" cy="{cy-9}" r="6" fill="{WHITE}"/>']
    return out

def lid(i, eyelid, tilt=0.0, show=True):
    """Upper lid in body-core colour. Bottom edge bows down (sleepy look);
    tilt > 0 lowers the outer corner and raises the inner one (sad look)."""
    cx, cy = EYES[i]
    top = cy - EYE_RY - 2
    h = 2 * EYE_RY * eyelid + 2
    outer, inner = (cx - EYE_RX - 3, cx + EYE_RX + 3) if i == 0 else (cx + EYE_RX + 3, cx - EYE_RX - 3)
    ho, hi = h + 18 * tilt, max(2, h - 14 * tilt)
    bow = 8 * eyelid
    d = (f"M{outer} {top-4} L {outer} {top+ho:.1f} Q {cx} {top+(ho+hi)/2+bow:.1f} {inner} {top+hi:.1f} L {inner} {top-4} Z")
    edge = f"M{outer} {top+ho:.1f} Q {cx} {top+(ho+hi)/2+bow:.1f} {inner} {top+hi:.1f}"
    vis = '' if show else ' display="none"'
    return (f'<g id="eyelid_{"left" if i==0 else "right"}"{vis}>'
            f'<clipPath id="clip{i}"><ellipse cx="{cx}" cy="{cy}" rx="{EYE_RX+2}" ry="{EYE_RY+2}"/></clipPath>'
            f'<g clip-path="url(#clip{i})"><path d="{d}" fill="{LIME}"/>'
            f'<path d="{edge}" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/></g></g>')

ZZZ = ''.join(f'<path d="M{x} {y} h{s} l-{s} {s} h{s}" fill="none" stroke="{INK}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'
              f'<path d="M{x} {y} h{s} l-{s} {s} h{s}" fill="none" stroke="{WHITE}" stroke-width="{w-6}" stroke-linecap="round" stroke-linejoin="round"/>'
              for x, y, s, w in [(370, 150, 22, 14), (404, 104, 28, 16), (440, 50, 34, 18)])
CONFETTI_PIECES = [  # x, y, w, h, rot, colour
  (96, 120, 18, 10, 30, ORANGE), (150, 70, 14, 14, -20, LIME), (360, 64, 18, 10, 60, LIME),
  (420, 130, 14, 14, 15, ORANGE), (70, 220, 16, 9, -45, LIME), (448, 236, 18, 10, 40, ORANGE),
  (200, 40, 10, 10, 0, "#39E08B"), (318, 30, 16, 9, -30, ORANGE), (470, 330, 12, 12, 20, LIME),
  (40, 330, 14, 8, 70, ORANGE)]
CONFETTI = ''.join(f'<rect x="{-w/2}" y="{-h/2}" width="{w}" height="{h}" rx="3" fill="{c}" stroke="{INK}" stroke-width="3" transform="translate({x} {y}) rotate({r})"/>'
                   for x, y, w, h, r, c in [(x, y, w*1.6, h*1.6, r, c) for x, y, w, h, r, c in CONFETTI_PIECES])

def svg(pose=None, layered=False):
    p = POSES[pose or "idle"]
    hide = lambda on: '' if on else ' display="none"'
    sy = 1 - p["droop"]
    t = f'translate(0 {p["lift"]}) translate(256 446) scale(1 {sy}) translate(-256 -446)'
    mouths = {"mouth_happy": 1.0, "mouth_neutral": 0.15, "mouth_sad": -0.7}
    if layered:
        mouth_svg = ''.join(f'<g id="{k}"{hide(k=="mouth_neutral")}>{mouth(v)}</g>' for k, v in mouths.items())
    else:
        mouth_svg = f'<g id="mouth">{mouth(p["smile"])}</g>'
    shadow_rx = 104 * (1 + p["lift"] / 120)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
<title>Flick, FitForm progress mascot{"" if layered else " - " + pose}</title>
<ellipse id="shadow" cx="256" cy="458" rx="{shadow_rx:.1f}" ry="14" fill="{INK}" opacity="0.18"/>
<g id="confetti"{hide(p["confetti"] and not layered)}>{CONFETTI}</g>
<g id="character" transform="{t}">
<g id="body">
<path d="{BODY}" fill="{ORANGE}" stroke="{INK}" stroke-width="14" stroke-linejoin="round"/>
<path d="{CORE}" fill="{LIME}"/>
</g>
<g id="arm_left">{arm(0, p["arms"][0])}</g>
<g id="arm_right">{arm(1, p["arms"][1])}</g>
<g id="head">
<g id="accessory"><path d="{BAND_TAIL}" fill="{LIME}" stroke="{INK}" stroke-width="10" stroke-linejoin="round"/><path d="{BAND}" fill="{LIME}" stroke="{INK}" stroke-width="12" stroke-linejoin="round"/></g>
<g id="eye_left">{''.join(eye(0, p["eyelid"]))}</g>
<g id="eye_right">{''.join(eye(1, p["eyelid"]))}</g>
{lid(0, 0.5 if layered else p["eyelid"], 0 if layered else p["tilt"], show=(layered or p["eyelid"] > 0))}
{lid(1, 0.5 if layered else p["eyelid"], 0 if layered else p["tilt"], show=(layered or p["eyelid"] > 0))}
{mouth_svg}
</g>
</g>
<g id="zzz"{hide(p["zzz"] and not layered)}>{ZZZ}</g>
</svg>'''

if __name__ == "__main__":
    import os
    os.makedirs("out", exist_ok=True)
    open("out/mascot_layers.svg", "w").write(svg(layered=True))
    for m in POSES:
        open(f"out/mascot_{m}.svg", "w").write(svg(m))
    json.dump(POSES, open("out/poses.json", "w"), indent=1)
