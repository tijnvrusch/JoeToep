#!/usr/bin/env python3
"""JoeToep V15 icon generator.

* Re-renders the macOS sizes of EVERY icon set on the macOS icon grid (824 px rounded
  rectangle centred on a transparent 1024 px canvas, soft shadow). Before V15 the Mac PNGs
  were full-bleed squares, so the Dock showed a too-large square with straight corners.
* Adds 24 new icon designs (iOS alternate icons + Mac + picker preview).
Run: python3 Scripts/generate_icons_v15.py   (needs Pillow)
"""
from pathlib import Path
import json, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1] / 'JoeToep' / 'Assets.xcassets'
TEMPLATE = json.loads((ROOT / 'AppIcon.appiconset' / 'Contents.json').read_text())
S = 1024

def hexrgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def gradient(top, bottom, angle=90):
    a, b = hexrgb(top), hexrgb(bottom)
    base = Image.new('RGB', (S, S))
    px = base.load()
    rad = math.radians(angle)
    dx, dy = math.cos(rad), math.sin(rad)
    for y in range(S):
        for x in range(0, S, 4):
            t = ((x - S / 2) * dx + (y - S / 2) * dy) / (S * 0.72) + 0.5
            t = min(max(t, 0), 1)
            c = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
            for k in range(4):
                if x + k < S: px[x + k, y] = c
    return base

def rounded_triangle(d, cx, cy, r, fill):
    k = 0.9  # shrink slightly; the rounded stroke adds the rest back
    pts = [(cx - r * 0.42 * k, cy - r * 0.62 * k), (cx - r * 0.42 * k, cy + r * 0.62 * k), (cx + r * 0.66 * k, cy)]
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0], pts[1]], fill=fill, width=max(2, int(r * 0.14)), joint='curve')

def play_badge(img, box_fill, glyph_fill, scale=1.0, radius=120, outline=None):
    d = ImageDraw.Draw(img)
    w, h = 640 * scale, 452 * scale
    x0, y0 = (S - w) / 2, (S - h) / 2
    if box_fill is not None:
        d.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=radius * scale, fill=box_fill, outline=outline, width=int(14 * scale) if outline else 0)
    rounded_triangle(d, S / 2 + 12 * scale, S / 2, 170 * scale, glyph_fill)

def glow(img, color, blur=60):
    layer = Image.new('RGB', (S, S), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((212, 306, 812, 718), radius=110, fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return ImageChops.add(img, layer)

def design(name):
    random.seed(name)
    if name == 'Midnight':
        im = gradient('#0b1033', '#02030b'); d = ImageDraw.Draw(im)
        for _ in range(90):
            x, y, r = random.randint(0, S), random.randint(0, S), random.choice([2, 2, 3, 4])
            d.ellipse((x - r, y - r, x + r, y + r), fill=(220, 225, 255))
        play_badge(im, '#1d2a6b', '#ffffff')
    elif name == 'Gold':
        im = gradient('#3a2a06', '#120c02')
        play_badge(im, None, '#000000')
        d = ImageDraw.Draw(im); d.rounded_rectangle((192, 286, 832, 738), radius=120, fill='#e8b74a')
        rounded_triangle(d, S / 2 + 12, S / 2, 170, '#3a2a06')
    elif name == 'Rose':
        im = gradient('#ffd1dc', '#ff7aa2'); play_badge(im, '#ffffff', '#ff4f81')
    elif name == 'Forest':
        im = gradient('#1f4d2c', '#0a1f12'); d = ImageDraw.Draw(im)
        for i in range(7):
            x = 60 + i * 150; d.polygon([(x, 1024), (x + 90, 700 - (i % 3) * 60), (x + 180, 1024)], fill=(18, 60, 32))
        play_badge(im, '#e9f5e1', '#1f6b3a')
    elif name == 'Grape':
        im = gradient('#7b2ff7', '#2a0a5e'); play_badge(im, '#ffffff', '#6b21d8')
    elif name == 'Coral':
        im = gradient('#ff9a8b', '#ff5e62'); play_badge(im, '#fff4ef', '#ff5e62')
    elif name == 'Sky':
        im = gradient('#a1e3ff', '#3a8dff'); d = ImageDraw.Draw(im)
        for cx, cy in [(250, 230), (760, 820), (820, 200)]:
            for dx in (-60, 0, 60): d.ellipse((cx + dx - 70, cy - 50, cx + dx + 70, cy + 50), fill=(255, 255, 255))
        play_badge(im, '#1e5fd6', '#ffffff')
    elif name == 'Slate':
        im = gradient('#4b5563', '#1f2933'); play_badge(im, '#e5e7eb', '#1f2933')
    elif name == 'Carbon':
        im = Image.new('RGB', (S, S), '#141414'); d = ImageDraw.Draw(im)
        for y in range(0, S, 16):
            for x in range(0, S, 16):
                if (x // 16 + y // 16) % 2 == 0: d.rectangle((x, y, x + 15, y + 15), fill='#1d1d1d')
        play_badge(im, '#ff2d2d', '#ffffff')
    elif name == 'Paper':
        im = Image.new('RGB', (S, S), '#f4efe4'); d = ImageDraw.Draw(im)
        for y in range(120, S, 64): d.line((0, y, S, y), fill='#d9e3f0', width=3)
        d.line((170, 0, 170, S), fill='#f2a0a0', width=4)
        play_badge(im, None, '#222222', outline=None)
        d.rounded_rectangle((192, 286, 832, 738), radius=120, outline='#222222', width=18)
    elif name == 'Glass':
        im = gradient('#6ee7f9', '#8b5cf6', 45); d = ImageDraw.Draw(im, 'RGBA')
        d.rounded_rectangle((192, 286, 832, 738), radius=120, fill=(255, 255, 255, 90), outline=(255, 255, 255, 170), width=10)
        d.rounded_rectangle((212, 300, 812, 470), radius=100, fill=(255, 255, 255, 50))
        rounded_triangle(d, S / 2 + 12, S / 2, 170, (255, 255, 255, 255))
    elif name == 'Sakura':
        im = gradient('#fff0f5', '#ffc1d9'); d = ImageDraw.Draw(im)
        for _ in range(26):
            x, y, r = random.randint(0, S), random.randint(0, S), random.randint(14, 30)
            for k in range(5):
                a = k * 2 * math.pi / 5
                d.ellipse((x + math.cos(a) * r - r * 0.6, y + math.sin(a) * r - r * 0.6, x + math.cos(a) * r + r * 0.6, y + math.sin(a) * r + r * 0.6), fill='#ff9ec4')
        play_badge(im, '#ffffff', '#ff5c9d')
    elif name == 'Ice':
        im = gradient('#e0f7ff', '#7cc8f0'); d = ImageDraw.Draw(im)
        for _ in range(14):
            x, y = random.randint(0, S), random.randint(0, S)
            d.polygon([(x, y - 60), (x + 30, y), (x, y + 60), (x - 30, y)], fill='#ffffff')
        play_badge(im, '#0f5d8c', '#e8fbff')
    elif name == 'Ember':
        im = gradient('#ff8a00', '#6b0000'); im = glow(im, (255, 120, 0), 80); play_badge(im, '#1a0500', '#ff8a00')
    elif name == 'Lime':
        im = Image.new('RGB', (S, S), '#c6f432'); play_badge(im, '#111111', '#c6f432')
    elif name == 'Terminal':
        im = Image.new('RGB', (S, S), '#0a0f0a'); d = ImageDraw.Draw(im)
        for y in range(0, S, 8): d.line((0, y, S, y), fill='#0e160e')
        d.rounded_rectangle((192, 286, 832, 738), radius=40, outline='#33ff66', width=14)
        d.line((260, 380, 340, 450), fill='#33ff66', width=18); d.line((340, 450, 260, 520), fill='#33ff66', width=18)
        rounded_triangle(d, 590, 512, 130, '#33ff66')
    elif name == 'Pixel':
        im = Image.new('RGB', (S, S), '#1b1d3a'); d = ImageDraw.Draw(im)
        grid = 64
        for gy in range(S // grid):
            for gx in range(S // grid):
                if random.random() < 0.08: d.rectangle((gx * grid, gy * grid, gx * grid + grid - 4, gy * grid + grid - 4), fill='#2a2e5c')
        cells = [(r, c) for r in range(5) for c in range(5) if c <= (r if r <= 2 else 4 - r) * 2 // 1 and c <= 4]
        for r in range(7):
            span = r if r <= 3 else 6 - r
            for c in range(span + 1):
                x0 = 352 + c * grid; y0 = 288 + r * grid
                d.rectangle((x0, y0, x0 + grid - 6, y0 + grid - 6), fill='#ff3355')
    elif name == 'RetroTV':
        im = gradient('#f6d7a7', '#e8a857'); d = ImageDraw.Draw(im)
        d.line((420, 170, 510, 270), fill='#3b2a1a', width=16); d.line((640, 150, 530, 270), fill='#3b2a1a', width=16)
        d.rounded_rectangle((150, 260, 874, 850), radius=90, fill='#5b3a24')
        d.rounded_rectangle((210, 320, 700, 790), radius=70, fill='#1c2b2b')
        d.ellipse((740, 380, 820, 460), fill='#d9b27c'); d.ellipse((740, 520, 820, 600), fill='#d9b27c')
        rounded_triangle(d, 470, 555, 120, '#ff4b4b')
    elif name == 'Bubble':
        im = gradient('#7af5ff', '#3e7bff'); d = ImageDraw.Draw(im, 'RGBA')
        for _ in range(18):
            x, y, r = random.randint(0, S), random.randint(0, S), random.randint(20, 90)
            d.ellipse((x - r, y - r, x + r, y + r), outline=(255, 255, 255, 150), width=6)
        d.ellipse((222, 222, 802, 802), fill=(255, 255, 255, 235))
        rounded_triangle(d, S / 2 + 20, S / 2, 170, (62, 123, 255, 255))
    elif name == 'Synthwave':
        im = gradient('#2b0a3d', '#ff2e97'); d = ImageDraw.Draw(im)
        d.ellipse((312, 180, 712, 580), fill='#ffb000')
        for i, y in enumerate(range(240, 580, 40)): d.rectangle((300, y, 724, y + 8 + i), fill='#2b0a3d')
        d.rectangle((0, 600, S, S), fill='#1a0633')
        for x in range(-600, 1700, 110): d.line((512, 600, x, S), fill='#ff2e97', width=4)
        for k, y in enumerate([620, 650, 700, 770, 870, 1000]): d.line((0, y, S, y), fill='#ff2e97', width=4)
        rounded_triangle(d, 525, 390, 110, '#2b0a3d')
    elif name == 'Rainbow':
        im = Image.new('RGB', (S, S), '#ffffff'); d = ImageDraw.Draw(im)
        colors = ['#ff3b30', '#ff9500', '#ffcc00', '#34c759', '#0a84ff', '#5e5ce6', '#bf5af2']
        band = S / len(colors)
        for i, c in enumerate(colors): d.rectangle((0, i * band, S, (i + 1) * band + 1), fill=c)
        play_badge(im, '#ffffff', '#111111')
    elif name == 'Holo':
        im = gradient('#ff9ff3', '#48dbfb', 30); im = ImageChops.blend(im, gradient('#feca57', '#5f27cd', 120), 0.45)
        play_badge(im, '#ffffff', '#5f27cd')
    elif name == 'Heart':
        im = gradient('#ff5f6d', '#c9184a'); d = ImageDraw.Draw(im)
        d.ellipse((220, 240, 540, 560), fill='#ffffff'); d.ellipse((484, 240, 804, 560), fill='#ffffff')
        d.polygon([(236, 460), (788, 460), (512, 830)], fill='#ffffff')
        rounded_triangle(d, 528, 480, 120, '#e11d48')
    elif name == 'Noir':
        im = gradient('#262626', '#000000'); play_badge(im, '#000000', '#ffffff', outline='#ffffff')
    else:
        raise SystemExit('unknown design ' + name)
    return im.convert('RGB')

NEW = ['Midnight', 'Gold', 'Rose', 'Forest', 'Grape', 'Coral', 'Sky', 'Slate', 'Carbon', 'Paper', 'Glass', 'Sakura',
       'Ice', 'Ember', 'Lime', 'Terminal', 'Pixel', 'RetroTV', 'Bubble', 'Synthwave', 'Rainbow', 'Holo', 'Heart', 'Noir']

def mac_shape(art):
    """macOS icon grid: 824 px body with ~185 px corner radius, transparent margin, shadow."""
    canvas = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((100, 100, 924, 924), radius=185, fill=255)
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((100, 112, 924, 936), radius=185, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(shadow)
    body = art.convert('RGBA').resize((824, 824), Image.Resampling.LANCZOS)
    full = Image.new('RGBA', (S, S), (0, 0, 0, 0)); full.paste(body, (100, 100))
    full.putalpha(ImageChops.multiply(full.getchannel('A'), mask))
    canvas.alpha_composite(full)
    # Subtle inner edge like system icons.
    edge = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((100, 100, 924, 924), radius=185, outline=(0, 0, 0, 40), width=2)
    canvas.alpha_composite(edge)
    return canvas

def write_set(name, art):
    out = ROOT / f'{name}.appiconset'; out.mkdir(exist_ok=True)
    (out / 'Contents.json').write_text(json.dumps(TEMPLATE, indent=2))
    mac = mac_shape(art)
    for spec in TEMPLATE['images']:
        size = int(float(spec['size'].split('x')[0]) * float(spec.get('scale', '1x')[:-1]))
        path = out / spec['filename']
        if spec.get('platform') == 'ios' or spec.get('idiom') == 'universal':
            art.resize((size, size), Image.Resampling.LANCZOS).save(path, optimize=True)
        else:
            mac.resize((size, size), Image.Resampling.LANCZOS).save(path, optimize=True)
    preview = ROOT / f'IconPreview{name}.imageset'; preview.mkdir(exist_ok=True)
    art.resize((256, 256), Image.Resampling.LANCZOS).save(preview / 'icon.png', optimize=True)
    (preview / 'Contents.json').write_text(json.dumps({'images': [{'idiom': 'universal', 'filename': 'icon.png'}], 'info': {'author': 'xcode', 'version': 1}}))

if __name__ == '__main__':
    existing = sorted(p.name[:-len('.appiconset')] for p in ROOT.glob('*.appiconset'))
    for name in existing:
        if name in NEW: continue
        art = Image.open(ROOT / f'{name}.appiconset' / 'AppIcon-iOS-1024.png').convert('RGB')
        out = ROOT / f'{name}.appiconset'
        mac = mac_shape(art)
        for spec in TEMPLATE['images']:
            if spec.get('platform') == 'ios' or spec.get('idiom') == 'universal': continue
            size = int(float(spec['size'].split('x')[0]) * float(spec.get('scale', '1x')[:-1]))
            mac.resize((size, size), Image.Resampling.LANCZOS).save(out / spec['filename'], optimize=True)
        print('mac-shaped', name)
    for name in NEW:
        write_set(name, design(name)); print('new', name)
