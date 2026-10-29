#!/usr/bin/env python3
"""JoeToep V17.1 — 110 nieuwe app-iconen in vijf series (iPhone, iPad én Mac).

  • Unique (20)    — bijzondere, unieke ontwerpen       (namen beginnen met "U")
  • Creative (20)  — creatieve, kunstzinnige ontwerpen  ("C")
  • Eccentric (20) — excentrieke, gekke ontwerpen       ("E")
  • Bold (20)      — opvallende, felle ontwerpen        ("B")
  • Red (30)       — varianten van het rode YouTube-icoon met verschillende, strakke
                     achtergronden                      ("R")

Elk ontwerp is deterministisch (dezelfde naam geeft altijd hetzelfde plaatje): een achtergrond
+ een "glyph" (het speel-symbool in een eigen stijl). De Mac-versie krijgt automatisch de
afgeronde macOS-vorm met schaduw (mac_shape uit generate_icons_v15.py).
Run: python3 Scripts/generate_icons_v171.py      (Pillow nodig)
"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_icons_v15 as base            # hergebruik: gradient, rounded_triangle, write_set …

S = base.S
hexrgb = base.hexrgb
YT = '#FF0033'                               # exact YouTube-rood (zie AccentChoice.youtubeRed)

# ── Achtergronden ───────────────────────────────────────────────────────────────────────
def solid(c):
    return Image.new('RGB', (S, S), hexrgb(c))

def radial(inner, outer):
    """Cirkelvormig verloop van binnen (inner) naar buiten (outer)."""
    im = Image.new('RGB', (S, S), hexrgb(outer))
    a, b = hexrgb(inner), hexrgb(outer)
    d = ImageDraw.Draw(im)
    for i in range(60, 0, -1):
        t = i / 60
        c = tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(3))
        r = S * 0.75 * t
        d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), fill=c)
    return im.filter(ImageFilter.GaussianBlur(8))

def stripes(c1, c2, n=8, angle=0):
    im = solid(c1); d = ImageDraw.Draw(im)
    w = S * 2 / n
    for i in range(-n, n * 2):
        x = i * w
        d.polygon([(x, 0), (x + w / 2, 0), (x + w / 2 - S * math.tan(math.radians(angle)), S), (x - S * math.tan(math.radians(angle)), S)], fill=hexrgb(c2))
    return im

def dots(bg, fg, step=96, r=18):
    im = solid(bg); d = ImageDraw.Draw(im)
    for y in range(step // 2, S, step):
        for x in range(step // 2, S, step):
            d.ellipse((x - r, y - r, x + r, y + r), fill=hexrgb(fg))
    return im

def grid(bg, fg, step=128, w=6):
    im = solid(bg); d = ImageDraw.Draw(im)
    for v in range(0, S, step):
        d.line((v, 0, v, S), fill=hexrgb(fg), width=w); d.line((0, v, S, v), fill=hexrgb(fg), width=w)
    return im

def rings(bg, fg, n=9):
    im = solid(bg); d = ImageDraw.Draw(im)
    for i in range(n, 0, -1):
        r = S * 0.72 * i / n
        d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), outline=hexrgb(fg), width=10)
    return im

def blobs(bg, colors, seed):
    rnd = random.Random(seed)
    im = solid(bg)
    layer = Image.new('RGB', (S, S), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    for c in colors:
        x, y, r = rnd.randint(0, S), rnd.randint(0, S), rnd.randint(260, 480)
        d.ellipse((x - r, y - r, x + r, y + r), fill=hexrgb(c))
    layer = layer.filter(ImageFilter.GaussianBlur(110))
    return ImageChops.screen(im, layer)

def mosaic(colors, seed, cells=8):
    rnd = random.Random(seed)
    im = Image.new('RGB', (S, S)); d = ImageDraw.Draw(im)
    c = S / cells
    for y in range(cells):
        for x in range(cells):
            d.rectangle((x * c, y * c, (x + 1) * c, (y + 1) * c), fill=hexrgb(rnd.choice(colors)))
    return im

def triangles(colors, seed, n=7):
    rnd = random.Random(seed)
    im = solid(colors[0]); d = ImageDraw.Draw(im)
    c = S / n
    for y in range(n + 1):
        for x in range(n + 1):
            p = [(x * c, y * c), ((x + 1) * c, y * c), (x * c, (y + 1) * c)] if rnd.random() < .5 else [((x + 1) * c, y * c), ((x + 1) * c, (y + 1) * c), (x * c, (y + 1) * c)]
            d.polygon(p, fill=hexrgb(rnd.choice(colors)))
    return im

def waves(bg, fg, n=7):
    im = solid(bg); d = ImageDraw.Draw(im)
    for k in range(n):
        y0 = S * (k + 0.5) / n
        pts = \
              [(x, y0 + math.sin(x / S * math.pi * 3 + k) * 34) for x in range(0, S + 16, 16)]
        d.line(pts, fill=hexrgb(fg), width=16, joint='curve')
    return im

def sunburst(c1, c2, n=18):
    im = solid(c1); d = ImageDraw.Draw(im)
    for i in range(n):
        a0 = 2 * math.pi * i / n; a1 = a0 + math.pi / n
        d.polygon([(S / 2, S / 2), (S / 2 + math.cos(a0) * S, S / 2 + math.sin(a0) * S), (S / 2 + math.cos(a1) * S, S / 2 + math.sin(a1) * S)], fill=hexrgb(c2))
    return im

# ── Glyphs (het speel-symbool) ───────────────────────────────────────────────────────────
def glyph_badge(im, box, tri, scale=1.0, radius=120, outline=None):
    base.play_badge(im, hexrgb(box) if box else None, hexrgb(tri), scale=scale, radius=radius, outline=hexrgb(outline) if outline else None)

def glyph_circle(im, fill, tri, r=300, ring=None):
    d = ImageDraw.Draw(im)
    if fill: d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), fill=hexrgb(fill))
    if ring: d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), outline=hexrgb(ring), width=28)
    base.rounded_triangle(d, S / 2 + 18, S / 2, r * 0.62, hexrgb(tri))

def glyph_triangle(im, tri, size=250, shadow=True):
    d = ImageDraw.Draw(im)
    if shadow:
        sh = Image.new('L', (S, S), 0); base.rounded_triangle(ImageDraw.Draw(sh), S / 2 + 30, S / 2 + 24, size, 150)
        im.paste((0, 0, 0), mask=sh.filter(ImageFilter.GaussianBlur(24)))
    base.rounded_triangle(d, S / 2 + 20, S / 2, size, hexrgb(tri))

def glyph_outline(im, color, width=34):
    d = ImageDraw.Draw(im)
    w, h = 640, 452
    d.rounded_rectangle(((S - w) / 2, (S - h) / 2, (S + w) / 2, (S + h) / 2), radius=120, outline=hexrgb(color), width=width)
    base.rounded_triangle(d, S / 2 + 12, S / 2, 150, hexrgb(color))

def glyph_vinyl(im, label, tri):
    d = ImageDraw.Draw(im)
    for i, c in enumerate(['#111111', '#1c1c1c', '#141414', '#202020', '#161616']):
        r = 400 - i * 40
        d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), fill=hexrgb(c))
    d.ellipse((S / 2 - 150, S / 2 - 150, S / 2 + 150, S / 2 + 150), fill=hexrgb(label))
    base.rounded_triangle(d, S / 2 + 10, S / 2, 90, hexrgb(tri))

def glyph_eq(im, color, bars=7, seed=1):
    rnd = random.Random(seed); d = ImageDraw.Draw(im)
    w = 56; gap = 26; total = bars * w + (bars - 1) * gap; x0 = (S - total) / 2
    for i in range(bars):
        h = rnd.randint(160, 560)
        d.rounded_rectangle((x0 + i * (w + gap), S / 2 + 280 - h, x0 + i * (w + gap) + w, S / 2 + 280), radius=24, fill=hexrgb(color))

def glyph_pixel(im, color, bg=None):
    d = ImageDraw.Draw(im); c = 64
    shape = ["X......", "XXX....", "XXXXX..", "XXXXXXX", "XXXXX..", "XXX....", "X......"]
    x0, y0 = S / 2 - 3.2 * c, S / 2 - 3.5 * c
    for y, row in enumerate(shape):
        for x, ch in enumerate(row):
            if ch == 'X': d.rectangle((x0 + x * c, y0 + y * c, x0 + (x + 1) * c - 6, y0 + (y + 1) * c - 6), fill=hexrgb(color))

def glyph_eye(im, white, iris, tri):
    d = ImageDraw.Draw(im)
    d.ellipse((150, 330, 874, 694), fill=hexrgb(white))
    d.ellipse((S / 2 - 170, S / 2 - 170, S / 2 + 170, S / 2 + 170), fill=hexrgb(iris))
    base.rounded_triangle(d, S / 2 + 12, S / 2, 100, hexrgb(tri))

def glyph_heart(im, color, tri):
    d = ImageDraw.Draw(im)
    d.ellipse((230, 260, 530, 560), fill=hexrgb(color)); d.ellipse((494, 260, 794, 560), fill=hexrgb(color))
    d.polygon([(250, 470), (774, 470), (512, 800)], fill=hexrgb(color))
    base.rounded_triangle(d, S / 2 + 10, 500, 110, hexrgb(tri))

def glyph_star(im, color, tri, points=5):
    d = ImageDraw.Draw(im); pts = []
    for i in range(points * 2):
        r = 400 if i % 2 == 0 else 170; a = -math.pi / 2 + math.pi * i / points
        pts.append((S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r))
    d.polygon(pts, fill=hexrgb(color))
    base.rounded_triangle(d, S / 2 + 10, S / 2 + 10, 95, hexrgb(tri))

def glyph_tape(im, body, window, tri):
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((170, 300, 854, 724), radius=48, fill=hexrgb(body))
    d.rounded_rectangle((260, 380, 764, 560), radius=36, fill=hexrgb(window))
    for cx in (360, 664): d.ellipse((cx - 56, 470 - 56, cx + 56, 470 + 56), fill=hexrgb(body))
    base.rounded_triangle(d, S / 2 + 8, 470, 60, hexrgb(tri))

def glow_layer(im, color, blur=70):
    return base.glow(im, hexrgb(color), blur)

# ── De ontwerpen ─────────────────────────────────────────────────────────────────────────
def unique(i, name):
    specs = [
        lambda: (blobs('#07051a', ['#7b2ff7', '#f107a3', '#00d4ff'], name), lambda im: glyph_triangle(im, '#ffffff')),
        lambda: (mosaic(['#1d3557', '#457b9d', '#a8dadc', '#f1faee', '#e63946'], name), lambda im: glyph_badge(im, '#e63946', '#ffffff')),
        lambda: (rings('#0d0d0d', '#ffd166'), lambda im: glyph_circle(im, '#ffd166', '#0d0d0d', 220)),
        lambda: (triangles(['#264653', '#2a9d8f', '#e9c46a', '#f4a261', '#e76f51'], name), lambda im: glyph_circle(im, '#ffffff', '#e76f51', 250)),
        lambda: (radial('#fdf6e3', '#b58900'), lambda im: glyph_vinyl(im, '#dc322f', '#fdf6e3')),
        lambda: (grid('#001219', '#0a9396', 96, 4), lambda im: glyph_outline(im, '#94d2bd')),
        lambda: (sunburst('#ff006e', '#fb5607'), lambda im: glyph_circle(im, '#ffbe0b', '#ff006e', 260)),
        lambda: (blobs('#f8f9fa', ['#ffadad', '#caffbf', '#9bf6ff', '#bdb2ff'], name), lambda im: glyph_badge(im, '#22223b', '#f8f9fa')),
        lambda: (waves('#03045e', '#00b4d8'), lambda im: glyph_circle(im, '#caf0f8', '#03045e', 240)),
        lambda: (dots('#2b2d42', '#8d99ae', 80, 10), lambda im: glyph_eye(im, '#edf2f4', '#ef233c', '#edf2f4')),
        lambda: (radial('#3a0ca3', '#10002b'), lambda im: glyph_star(im, '#f72585', '#ffffff')),
        lambda: (stripes('#faf3dd', '#c8d5b9', 10, 20), lambda im: glyph_tape(im, '#4a7c59', '#faf3dd', '#4a7c59')),
        lambda: (mosaic(['#000000', '#222222', '#444444'], name, 16), lambda im: glyph_pixel(im, '#39ff14')),
        lambda: (blobs('#1a0000', ['#ff4d00', '#ff0054', '#ffbd00'], name), lambda im: glyph_triangle(im, '#fff3e0')),
        lambda: (rings('#e0fbfc', '#98c1d9', 12), lambda im: glyph_badge(im, '#3d5a80', '#e0fbfc')),
        lambda: (triangles(['#0b090a', '#161a1d', '#660708', '#a4161a'], name, 9), lambda im: glyph_circle(im, None, '#f5f3f4', 260, ring='#f5f3f4')),
        lambda: (radial('#ffffff', '#d8e2dc'), lambda im: glyph_heart(im, '#ff595e', '#ffffff')),
        lambda: (sunburst('#240046', '#3c096c', 24), lambda im: glyph_eq(im, '#e0aaff', 9, 3)),
        lambda: (grid('#fefae0', '#dda15e', 170, 10), lambda im: glyph_circle(im, '#bc6c25', '#fefae0', 250)),
        lambda: (blobs('#000814', ['#003566', '#ffc300'], name), lambda im: glyph_outline(im, '#ffd60a', 40)),
    ]
    return specs[i]()

def creative(i, name):
    palettes = [('#ff9f1c', '#2ec4b6', '#ffffff'), ('#ef476f', '#118ab2', '#ffd166'), ('#8338ec', '#ff006e', '#ffbe0b'),
                ('#06d6a0', '#073b4c', '#ffffff'), ('#e76f51', '#264653', '#e9c46a'), ('#3a86ff', '#fb5607', '#ffffff'),
                ('#9d4edd', '#ff9e00', '#ffffff'), ('#f15bb5', '#00bbf9', '#fee440'), ('#80ffdb', '#5390d9', '#ffffff'),
                ('#ffadad', '#6d6875', '#ffffff')]
    a, b, c = palettes[i % 10]
    kind = i // 10
    if kind == 0:
        bg = [lambda: blobs('#111111', [a, b], name), lambda: triangles([a, b, '#111111'], name), lambda: waves(b, a), lambda: stripes(a, b, 6, 25), lambda: dots(b, a, 110, 30),
              lambda: sunburst(a, b, 14), lambda: mosaic([a, b, c, '#222222'], name, 6), lambda: radial(a, b), lambda: rings(b, a, 7), lambda: grid(a, b, 146, 14)][i % 10]()
        glyph = [lambda im: glyph_badge(im, c, a), lambda im: glyph_circle(im, c, b, 260), lambda im: glyph_outline(im, c),
                 lambda im: glyph_triangle(im, c), lambda im: glyph_vinyl(im, a, c)][i % 5]
    else:
        bg = [lambda: radial(c, a), lambda: blobs(a, [b, c], name), lambda: stripes(b, a, 12, 0), lambda: mosaic([a, b], name, 12), lambda: triangles([a, b, c], name, 5),
              lambda: dots(a, c, 70, 12), lambda: waves(a, c, 9), lambda: sunburst(b, a, 30), lambda: grid(b, c, 90, 5), lambda: rings(a, c, 14)][i % 10]()
        glyph = [lambda im: glyph_eq(im, c, 7, i), lambda im: glyph_tape(im, a, c, a), lambda im: glyph_eye(im, c, b, c),
                 lambda im: glyph_star(im, c, a), lambda im: glyph_heart(im, c, a)][i % 5]
    return bg, glyph

def eccentric(i, name):
    rnd = random.Random(name)
    wild = ['#ff00ff', '#00ff00', '#ffff00', '#00ffff', '#ff6600', '#ff0066', '#6600ff', '#00ff99', '#ffcc00', '#0066ff']
    a, b, c = rnd.sample(wild, 3)
    bgs = [lambda: mosaic([a, b, c], name, 5), lambda: triangles([a, b, c, '#000000'], name, 4), lambda: sunburst(a, b, 10),
           lambda: stripes(a, '#000000', 5, 35), lambda: dots(a, b, 150, 60), lambda: rings(a, b, 5), lambda: waves(a, b, 4),
           lambda: grid(a, '#000000', 200, 40), lambda: blobs(a, [b, c], name), lambda: radial(b, a)]
    glyphs = [lambda im: glyph_eye(im, '#ffffff', c, '#000000'), lambda im: glyph_pixel(im, c), lambda im: glyph_star(im, c, '#000000', 7 + i % 5),
              lambda im: glyph_heart(im, '#000000', c), lambda im: glyph_circle(im, '#000000', c, 230, ring=c),
              lambda im: glyph_tape(im, '#000000', c, '#000000'), lambda im: glyph_vinyl(im, c, '#000000'),
              lambda im: glyph_eq(im, '#000000', 5, i), lambda im: glyph_badge(im, '#000000', c, 0.8, 40), lambda im: glyph_outline(im, '#000000', 60)]
    return bgs[i % 10](), glyphs[(i * 3) % 10]

def bold(i, name):
    pairs = [('#ff0033', '#ffffff'), ('#000000', '#ffea00'), ('#00f5d4', '#000000'), ('#ff5400', '#ffffff'), ('#7209b7', '#f7ff00'),
             ('#ffffff', '#ff0033'), ('#0015ff', '#ffffff'), ('#39ff14', '#000000'), ('#ff1493', '#ffffff'), ('#111111', '#ff0033')]
    a, b = pairs[i % 10]
    if i < 10:
        bg = solid(a)
        g = [lambda im: glyph_triangle(im, b, 320, False), lambda im: glyph_circle(im, b, a, 340), lambda im: glyph_outline(im, b, 60)][i % 3]
    else:
        bg = [lambda: stripes(a, b, 4, 0), lambda: sunburst(a, b, 8), lambda: dots(a, b, 256, 70), lambda: rings(a, b, 4), lambda: grid(a, b, 256, 30)][i % 5]()
        g = lambda im: glyph_circle(im, a, b, 300, ring=b)
    return bg, g

def red(i, name):
    """30 varianten van het rode YouTube-icoon: steeds de rode knop, met andere achtergronden."""
    backgrounds = [
        lambda: solid('#ffffff'),
        lambda: solid('#000000'),
        lambda: solid('#0f0f0f'),
        lambda: solid('#f2f2f2'),
        lambda: solid('#1c1c1e'),
        lambda: base.gradient('#ffffff', '#e8e8e8'),
        lambda: base.gradient('#2b2b2b', '#000000'),
        lambda: base.gradient('#ff4e50', '#8a0012'),
        lambda: base.gradient('#ffe5ec', '#ffc2d1'),
        lambda: base.gradient('#0f2027', '#2c5364'),
        lambda: base.gradient('#141e30', '#243b55'),
        lambda: base.gradient('#fceabb', '#f8b500'),
        lambda: base.gradient('#e0eafc', '#cfdef3'),
        lambda: base.gradient('#232526', '#414345'),
        lambda: radial('#ffffff', '#dcdcdc'),
        lambda: radial('#3a3a3a', '#000000'),
        lambda: radial('#ff667f', '#b3001e'),
        lambda: dots('#ffffff', '#ffe0e6', 96, 16),
        lambda: dots('#0f0f0f', '#2a0008', 96, 16),
        lambda: grid('#ffffff', '#f0f0f0', 128, 6),
        lambda: grid('#0f0f0f', '#1f1f1f', 128, 6),
        lambda: stripes('#ffffff', '#fff0f3', 12, 30),
        lambda: stripes('#0f0f0f', '#1a1a1a', 12, 30),
        lambda: rings('#ffffff', '#ffe5ea', 10),
        lambda: rings('#0f0f0f', '#240008', 10),
        lambda: waves('#ffffff', '#ffe0e6'),
        lambda: blobs('#ffffff', ['#ffd6de', '#ffe9ee'], name),
        lambda: blobs('#0f0f0f', ['#4d0011', '#1a0006'], name),
        lambda: base.gradient('#fdfbfb', '#ebedee'),
        lambda: base.gradient('#000000', '#330008'),
    ]
    bg = backgrounds[i]()
    light = sum(bg.resize((1, 1)).getpixel((0, 0))) > 380                 # lichte of donkere achtergrond?
    styles = [lambda im: glyph_badge(im, YT, '#ffffff'),                   # klassiek
              lambda im: glyph_badge(im, YT, '#ffffff', 0.85, 150),        # kleiner, ronder
              lambda im: glyph_badge(im, YT, '#ffffff', 1.1, 90),          # groter, strakker
              lambda im: glyph_badge(im, YT, '#ffffff', 1.0, 120, outline='#ffffff' if not light else '#1a1a1a')]
    styles[i % 4](bg)
    return bg, None

SERIES = {
    'U': ['Nebula', 'Mosaic', 'Halo', 'Tangram', 'Gramophone', 'Blueprint2', 'Sunburst', 'Pastel', 'Tide', 'Watcher',
          'Supernova', 'Tape', 'Matrix', 'Inferno', 'Ripple', 'Shard', 'Valentine', 'Rave', 'Terra', 'Midas'],
    'C': ['Tropic', 'Popsicle', 'Disco', 'Lagoon', 'Desert', 'Bauhaus', 'Grape', 'Candyfloss', 'Glacier', 'Blush',
          'Studio', 'Mixtape', 'Iris', 'Starlight', 'Crush', 'Sorbet', 'Current', 'Burst', 'Graph', 'Echo'],
    'E': ['Acid', 'Glitch', 'Circus', 'Hypno', 'Bubblegum', 'Vortex', 'Wobble', 'Checker', 'Lava', 'Alien',
          'Cyclops', 'Arcade', 'Starfish', 'Punk', 'Target', 'Boombox', 'Record', 'Pulse', 'Chunky', 'Neonframe'],
    'B': ['Signal', 'Hazard', 'Mint', 'Blaze', 'Volt', 'Snow', 'Cobalt', 'Radioactive', 'Hotpink', 'Shadow',
          'Barcode', 'Burst', 'Polka', 'Bullseye', 'Tile', 'Flag', 'Beam', 'Spot', 'Orbit', 'Frame'],
    'R': [f'{n:02d}' for n in range(1, 31)],
}
MAKERS = {'U': unique, 'C': creative, 'E': eccentric, 'B': bold, 'R': red}
PREFIX = {'U': 'Unique', 'C': 'Creative', 'E': 'Eccentric', 'B': 'Bold', 'R': 'Red'}

def all_names():
    return [PREFIX[k] + n for k in SERIES for n in SERIES[k]]

def render(key, i, n):
    name = PREFIX[key] + n
    bg, glyph = MAKERS[key](i, name)
    art = bg.convert('RGB')
    if glyph: glyph(art)
    return name, art

if __name__ == '__main__':
    only_sheet = '--sheet' in sys.argv
    thumbs = []
    for key in SERIES:
        for i, n in enumerate(SERIES[key]):
            name, art = render(key, i, n)
            thumbs.append(art.resize((128, 128)))
            if not only_sheet: base.write_set(name, art)
            print('icon', name)
    cols = 20; rows = math.ceil(len(thumbs) / cols)
    sheet = Image.new('RGB', (cols * 132, rows * 132), (40, 40, 40))
    for k, t in enumerate(thumbs): sheet.paste(t, ((k % cols) * 132 + 2, (k // cols) * 132 + 2))
    sheet.save('/tmp/claude-0/icons_v171.png')
    print(len(thumbs), 'icons')
