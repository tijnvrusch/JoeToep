#!/usr/bin/env python3
"""JoeToep V20 — 40 nieuwe app-iconen in twee series (iPhone, iPad én Mac).

  • Outline (20) — lijn-iconen: het speel-symbool als dunne tot stevige omlijning, op rustige
                   effen of zachte verloop-achtergronden.            (namen "Outline…")
  • Minimal (20) — extra clean en minimalistisch: één kleur, veel ruimte, een klein symbool
                   (driehoek, stip, streep of ring).                   (namen "Minimal…")

Elk ontwerp is deterministisch. De Mac-versie krijgt de afgeronde macOS-vorm (generate_icons_v15).
Run: python3 Scripts/generate_icons_v20.py      (Pillow nodig)
"""
import math, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_icons_v15 as base

S = base.S
hexrgb = base.hexrgb
SS = 2  # supersampling voor strakke lijnen

def canvas(bg):
    return Image.new('RGB', (S * SS, S * SS), hexrgb(bg))

def vgradient(top, bottom):
    return base.gradient(top, bottom, 90).resize((S * SS, S * SS))

def tri_points(cx, cy, r):
    return [(cx - r * 0.42, cy - r * 0.62), (cx - r * 0.42, cy + r * 0.62), (cx + r * 0.66, cy)]

def outline_triangle(d, cx, cy, r, color, width):
    pts = tri_points(cx, cy, r)
    d.line(pts + [pts[0], pts[1]], fill=hexrgb(color), width=int(width), joint='curve')
    for p in pts:  # ronde hoeken
        d.ellipse((p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2), fill=hexrgb(color))

def filled_triangle(d, cx, cy, r, color):
    pts = tri_points(cx, cy, r)
    d.polygon(pts, fill=hexrgb(color))
    d.line(pts + [pts[0], pts[1]], fill=hexrgb(color), width=max(2, int(r * 0.14)), joint='curve')

def finish(im):
    return im.resize((S, S), Image.Resampling.LANCZOS)

C = S * SS / 2  # midden (supersampled)
U = SS          # eenheid

# ── Outline ────────────────────────────────────────────────────────────────────────────
# (naam, achtergrond(en), lijnkleur, lijndikte, vorm)
OUTLINE = [
    ('Classic',   ('#0E0E10',), '#FFFFFF', 30, 'badge'),
    ('Red',       ('#0E0E10',), '#FF0033', 30, 'badge'),
    ('Paper',     ('#F4F1EA',), '#1A1A1A', 26, 'badge'),
    ('Hairline',  ('#111111',), '#EDEDED', 12, 'badge'),
    ('Bold',      ('#FF0033',), '#FFFFFF', 48, 'badge'),
    ('Circle',    ('#101418',), '#FFFFFF', 28, 'circle'),
    ('RedCircle', ('#FFFFFF',), '#FF0033', 30, 'circle'),
    ('Square',    ('#1B1B1F',), '#F2F2F2', 26, 'square'),
    ('Triangle',  ('#0B0B0C',), '#FFFFFF', 30, 'triangle'),
    ('Ocean',     ('#0F2A44', '#1E5A8A'), '#E8F4FF', 26, 'badge'),
    ('Mint',      ('#E9F7F1',), '#1F8A64', 28, 'badge'),
    ('Sunset',    ('#FF7A59', '#FF3D71'), '#FFFFFF', 30, 'badge'),
    ('Lavender',  ('#EEE9FB',), '#5B45C7', 26, 'circle'),
    ('Night',     ('#0A0F24', '#1B2350'), '#9FB4FF', 22, 'badge'),
    ('Gold',      ('#141210',), '#E8C27A', 24, 'badge'),
    ('Double',    ('#101010',), '#FFFFFF', 18, 'double'),
    ('Neon',      ('#07070A',), '#39FF88', 22, 'glow'),
    ('Pink',      ('#FFE9F1',), '#E0356E', 28, 'badge'),
    ('Sky',       ('#DFF1FF', '#BFE2FF'), '#0B5CAD', 26, 'circle'),
    ('Slate',     ('#2A3038',), '#C9D3DE', 24, 'square'),
]

def outline_icon(bgs, color, width, shape):
    im = vgradient(*bgs) if len(bgs) == 2 else canvas(bgs[0])
    d = ImageDraw.Draw(im)
    w = width * U
    if shape in ('badge', 'glow', 'double'):
        bw, bh = 600 * U, 424 * U
        box = (C - bw / 2, C - bh / 2, C + bw / 2, C + bh / 2)
        if shape == 'glow':
            glow = Image.new('RGB', im.size, (0, 0, 0)); gd = ImageDraw.Draw(glow)
            gd.rounded_rectangle(box, radius=112 * U, outline=hexrgb(color), width=int(w * 2.2))
            outline_triangle(gd, C + 12 * U, C, 160 * U, color, w * 2)
            im = Image.blend(im, Image.eval(glow.filter(ImageFilter.GaussianBlur(28 * U)), lambda v: v), 0.55)
            d = ImageDraw.Draw(im)
        d.rounded_rectangle(box, radius=112 * U, outline=hexrgb(color), width=int(w))
        if shape == 'double':
            inset = 46 * U
            d.rounded_rectangle((box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset), radius=76 * U, outline=hexrgb(color), width=int(w * 0.6))
        outline_triangle(d, C + 12 * U, C, 150 * U, color, w)
    elif shape == 'circle':
        r = 300 * U
        d.ellipse((C - r, C - r, C + r, C + r), outline=hexrgb(color), width=int(w))
        outline_triangle(d, C + 16 * U, C, 200 * U, color, w)
    elif shape == 'square':
        r = 290 * U
        d.rounded_rectangle((C - r, C - r, C + r, C + r), radius=70 * U, outline=hexrgb(color), width=int(w))
        outline_triangle(d, C + 16 * U, C, 200 * U, color, w)
    elif shape == 'triangle':
        outline_triangle(d, C + 30 * U, C, 420 * U, color, w)
    return finish(im)

# ── Minimal ────────────────────────────────────────────────────────────────────────────
# (naam, achtergrond, voorgrond, vorm, grootte)
MINIMAL = [
    ('White',     '#FFFFFF', '#111111', 'tri', 150),
    ('Black',     '#0A0A0A', '#FFFFFF', 'tri', 150),
    ('Red',       '#FF0033', '#FFFFFF', 'tri', 150),
    ('RedDot',    '#FFFFFF', '#FF0033', 'dot', 90),
    ('Ink',       '#111111', '#FF0033', 'dot', 70),
    ('Sand',      '#EFE6D8', '#3A332B', 'tri', 120),
    ('Stone',     '#D9D9D6', '#2B2B2B', 'line', 0),
    ('Fog',       '#F2F4F7', '#8A94A6', 'ring', 0),
    ('Graphite',  '#2E3136', '#E6E8EB', 'ring', 0),
    ('Blush',     '#FBE3E4', '#C23B4E', 'tri', 120),
    ('Sage',      '#DCE6DA', '#3F5A45', 'tri', 120),
    ('Navy',      '#13213A', '#F4F6FA', 'tri', 120),
    ('Butter',    '#FFF3C4', '#2C2A20', 'dot', 80),
    ('Lilac',     '#E7E1F7', '#4A3C8C', 'line', 0),
    ('Ocean',     '#E3F1FA', '#1B6CA8', 'ring', 0),
    ('Mono',      '#FFFFFF', '#000000', 'corner', 0),
    ('Night',     '#000000', '#3A3A3A', 'tri', 170),
    ('Clay',      '#E7D3C7', '#8B4A32', 'dot', 90),
    ('Mint',      '#E4F6EE', '#19805A', 'corner', 0),
    ('Cream',     '#FAF7F0', '#FF0033', 'line', 0),
]

def minimal_icon(bg, fg, shape, size):
    im = canvas(bg); d = ImageDraw.Draw(im)
    if shape == 'tri':
        filled_triangle(d, C + size * 0.12 * U, C, size * U, fg)
    elif shape == 'dot':
        r = size * U
        d.ellipse((C - r, C - r, C + r, C + r), fill=hexrgb(fg))
    elif shape == 'line':
        w, h = 300 * U, 22 * U
        d.rounded_rectangle((C - w / 2, C - h / 2, C + w / 2, C + h / 2), radius=h / 2, fill=hexrgb(fg))
        filled_triangle(d, C + 190 * U, C, 46 * U, fg)
    elif shape == 'ring':
        r = 170 * U
        d.ellipse((C - r, C - r, C + r, C + r), outline=hexrgb(fg), width=int(14 * U))
        filled_triangle(d, C + 12 * U, C, 70 * U, fg)
    elif shape == 'corner':
        filled_triangle(d, S * SS * 0.70, S * SS * 0.70, 110 * U, fg)
    return finish(im)

NAMES = ['Outline' + n for n, *_ in OUTLINE] + ['Minimal' + n for n, *_ in MINIMAL]

if __name__ == '__main__':
    only_sheet = '--sheet' in sys.argv
    thumbs = []
    for n, bgs, color, width, shape in OUTLINE:
        art = outline_icon(bgs, color, width, shape); name = 'Outline' + n
        thumbs.append(art.resize((128, 128)))
        if not only_sheet: base.write_set(name, art)
    for n, bg, fg, shape, size in MINIMAL:
        art = minimal_icon(bg, fg, shape, size); name = 'Minimal' + n
        thumbs.append(art.resize((128, 128)))
        if not only_sheet: base.write_set(name, art)
    cols = 10; rows = math.ceil(len(thumbs) / cols)
    sheet = Image.new('RGB', (cols * 132, rows * 132), (60, 60, 60))
    for k, t in enumerate(thumbs): sheet.paste(t, ((k % cols) * 132 + 2, (k // cols) * 132 + 2))
    sheet.save('/tmp/claude-0/icons_v20.png')
    print(len(thumbs), 'icons:', ' '.join(NAMES))
