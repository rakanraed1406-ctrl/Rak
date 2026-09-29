"""Redraw the obtaizen_ui sprites in the radial-menu palette (see CLAUDE.md).

Same file names and pixel sizes as the originals, transparent background.
Everything is drawn at 4x and scaled down for smooth edges.

    python3 make_obtaizen_ui.py <output_dir> [path/to/oxanium-800.woff]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 4  # supersampling

# radial-menu palette (RadialMenu.css --rm-*)
DEEP = (5, 12, 32)
NAVY = (11, 26, 61)
CORE_HI = (16, 39, 94)
CORE_LO = (4, 10, 27)
ROYAL = (26, 75, 214)
HOT_LO = (10, 31, 92)
BLUE_HI = (58, 108, 255)
LIGHT = (140, 175, 255)
LINE = (92, 130, 255)
TEXT = (232, 238, 255)
DIM = (141, 155, 196)
GREEN = (52, 211, 153)

# the inactive sprites (circle.png, label_no.png) keep the original grey tones
G_DARK = (112, 112, 114)
G_MID = (140, 140, 142)
G_LIGHT = (180, 181, 182)
G_HI = (206, 207, 206)


# ── helpers ────────────────────────────────────────────────────────────────

def canvas(w, h):
    return Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))


def finish(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def s(v):
    return v * SS


def mask(size, draw_fn):
    m = Image.new('L', size, 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def fill(img, m, color, alpha=1.0):
    """Paint a solid color through a mask."""
    layer = Image.new('RGBA', img.size, color + (0,))
    layer.putalpha(m.point(lambda v: int(v * alpha)))
    img.alpha_composite(layer)


def gradient(size, c0, c1, direction='v', a0=1.0, a1=1.0):
    w, h = size
    t = np.linspace(0, 1, h if direction == 'v' else w)
    t = t[:, None] if direction == 'v' else t[None, :]
    t = np.broadcast_to(t, (h, w))
    rgb = np.array(c0)[None, None, :] * (1 - t[..., None]) + np.array(c1)[None, None, :] * t[..., None]
    a = (a0 * (1 - t) + a1 * t) * 255
    return Image.fromarray(np.dstack([rgb, a]).astype(np.uint8), 'RGBA')


def radial(size, center, radius, c0, c1, a0=1.0, a1=1.0):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip(np.hypot(xx - center[0], yy - center[1]) / radius, 0, 1)
    rgb = np.array(c0)[None, None, :] * (1 - t[..., None]) + np.array(c1)[None, None, :] * t[..., None]
    a = (a0 * (1 - t) + a1 * t) * 255
    return Image.fromarray(np.dstack([rgb, a]).astype(np.uint8), 'RGBA')


def paint(img, src, m):
    """Composite a gradient image through a mask (keeps the gradient's own alpha)."""
    src = src.copy()
    a = np.array(src.getchannel('A'), dtype=np.float32) * (np.array(m, dtype=np.float32) / 255)
    src.putalpha(Image.fromarray(a.astype(np.uint8)))
    img.alpha_composite(src)


def glow(img, m, color, alpha, blur):
    layer = Image.new('RGBA', img.size, color + (0,))
    layer.putalpha(m.point(lambda v: int(v * alpha)).filter(ImageFilter.GaussianBlur(s(blur))))
    img.alpha_composite(layer)


def arc_mask(size, c, r, width, start, end):
    return mask(size, lambda d: d.arc([s(c[0] - r), s(c[1] - r), s(c[0] + r), s(c[1] + r)], start, end, fill=255, width=int(s(width))))


def ring_mask(size, c, r, width):
    return arc_mask(size, c, r, width, 0, 360)


def disc_mask(size, c, r):
    return mask(size, lambda d: d.ellipse([s(c[0] - r), s(c[1] - r), s(c[0] + r), s(c[1] + r)], fill=255))


def rrect_mask(size, box, radius, width=None):
    x0, y0, x1, y1 = box
    if width:
        return mask(size, lambda d: d.rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], radius=s(radius), outline=255, width=int(s(width))))
    return mask(size, lambda d: d.rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], radius=s(radius), fill=255))


def bracket_mask(size, x, y, dx, dy, lx, ly, t):
    """L-shaped corner bracket starting at (x, y) going dx (±1) horizontally and dy (±1) vertically."""
    def draw(d):
        hx0, hx1 = sorted([x, x + dx * lx]); d.rectangle([s(hx0), s(min(y, y + dy * t)), s(hx1), s(max(y, y + dy * t))], fill=255)
        vy0, vy1 = sorted([y, y + dy * ly]); d.rectangle([s(min(x, x + dx * t)), s(vy0), s(max(x, x + dx * t)), s(vy1)], fill=255)
    return mask(size, draw)


def poly_mask(size, pts):
    return mask(size, lambda d: d.polygon([(s(x), s(y)) for x, y in pts], fill=255))


def poly_line_mask(size, pts, width):
    return mask(size, lambda d: d.line([(s(x), s(y)) for x, y in pts], fill=255, width=int(s(width)), joint='curve'))


# ── sprites ────────────────────────────────────────────────────────────────

def circle(selected):
    W = H = 60
    img = canvas(W, H); size = img.size; c = (30, 30)
    if selected:
        glow(img, disc_mask(size, c, 21), BLUE_HI, 0.55, 4)
    # outer instrument ring: faint full ring + two brighter arcs
    fill(img, ring_mask(size, c, 28, 1), LINE if selected else G_MID, 0.45 if selected else 0.4)
    for a in (200, 20):
        fill(img, arc_mask(size, c, 28, 2 if selected else 1.4, a, a + 70), BLUE_HI if selected else G_HI, 1.0 if selected else 0.85)
    # core disc
    d = disc_mask(size, c, 20)
    if selected:
        paint(img, radial(size, (s(30), s(24)), s(22), (40, 100, 240), HOT_LO), d)
        fill(img, ring_mask(size, c, 20, 1.5), BLUE_HI)
        glow(img, disc_mask(size, c, 4.5), TEXT, 0.9, 2)
        fill(img, disc_mask(size, c, 4.5), TEXT)
    else:
        paint(img, radial(size, (s(30), s(24)), s(22), G_DARK, G_MID, 0.75, 0.8), d)
        fill(img, ring_mask(size, c, 20, 1.2), G_LIGHT, 0.8)
        fill(img, disc_mask(size, c, 3), G_HI, 0.9)
    return finish(img, W, H)


def selected_confirm():
    W = H = 60
    img = canvas(W, H); size = img.size; c = (30, 30)
    glow(img, ring_mask(size, c, 26, 3), GREEN, 0.6, 3)
    paint(img, radial(size, (s(30), s(24)), s(26), CORE_HI, CORE_LO, 0.95, 0.95), disc_mask(size, c, 26))
    fill(img, ring_mask(size, c, 27, 3), GREEN, 0.95)
    fill(img, ring_mask(size, c, 21, 1), GREEN, 0.25)
    glow(img, disc_mask(size, c, 6), GREEN, 0.9, 3)
    fill(img, disc_mask(size, c, 6), (120, 240, 200))
    return finish(img, W, H)


def key(font_path):
    W = H = 72
    img = canvas(W, H); size = img.size
    box = (9, 9, 63, 63)
    body = rrect_mask(size, box, 9)
    glow(img, body, BLUE_HI, 0.45, 4)
    paint(img, gradient(size, (38, 92, 235), HOT_LO), body)
    # soft light at the top of the cap
    paint(img, radial(size, (s(36), s(9)), s(34), LIGHT, ROYAL, 0.45, 0.0), body)
    fill(img, rrect_mask(size, box, 9, 1.5), BLUE_HI)
    fill(img, mask(size, lambda d: d.line([(s(18), s(11)), (s(54), s(11))], fill=255, width=int(s(1)))), (255, 255, 255), 0.35)
    # corner brackets (top-left, bottom-right)
    fill(img, bracket_mask(size, 1.5, 1.5, 1, 1, 14, 14, 2), BLUE_HI)
    fill(img, bracket_mask(size, 70.5, 70.5, -1, -1, 14, 14, 2), BLUE_HI)
    # letter
    font = ImageFont.truetype(font_path, s(30)) if font_path else ImageFont.truetype('DejaVuSans-Bold.ttf', s(28))
    t = Image.new('RGBA', size, (0, 0, 0, 0)); d = ImageDraw.Draw(t)
    bb = d.textbbox((0, 0), 'E', font=font)
    x = s(36) - (bb[0] + bb[2]) / 2; y = s(36) - (bb[1] + bb[3]) / 2
    shadow = Image.new('RGBA', size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x, y + s(1.5)), 'E', font=font, fill=(0, 8, 40, 160))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(s(1))))
    d.text((x, y), 'E', font=font, fill=(255, 255, 255, 255))
    img.alpha_composite(t)
    return finish(img, W, H)


def label(active):
    W, H = 368, 76
    img = canvas(W, H); size = img.size
    outer = (1, 1, 367, 73); inner = (6, 6, 362, 68)
    # outer frame
    paint(img, gradient(size, DEEP, DEEP, 'h', 0.45, 0.45), rrect_mask(size, outer, 7))
    fill(img, rrect_mask(size, outer, 7, 1), LINE if active else G_MID, 0.28 if active else 0.35)
    m = rrect_mask(size, inner, 5)
    if active:
        glow(img, m, BLUE_HI, 0.25, 3)
        paint(img, gradient(size, (30, 84, 225), HOT_LO, 'h', 0.9, 0.92), m)
        paint(img, radial(size, (s(120), s(6)), s(190), LIGHT, ROYAL, 0.35, 0.0), m)
        fill(img, rrect_mask(size, inner, 5, 1), BLUE_HI, 0.85)
        fill(img, mask(size, lambda d: d.rectangle([s(6), s(10), s(9), s(64)], fill=255)), LIGHT)  # left accent
        hl = mask(size, lambda d: d.line([(s(40), s(6.5)), (s(328), s(6.5))], fill=255, width=int(s(1))))
        fill(img, hl, (200, 220, 255), 0.55)
        bc, ba = BLUE_HI, 1.0
    else:
        paint(img, gradient(size, G_MID, G_DARK, 'h', 0.75, 0.72), m)
        paint(img, radial(size, (s(120), s(6)), s(190), G_HI, G_MID, 0.3, 0.0), m)
        fill(img, rrect_mask(size, inner, 5, 1), G_LIGHT, 0.7)
        hl = mask(size, lambda d: d.line([(s(40), s(6.5)), (s(328), s(6.5))], fill=255, width=int(s(1))))
        fill(img, hl, G_HI, 0.6)
        bc, ba = G_LIGHT, 0.85
    # corner brackets (top-left, bottom-right)
    fill(img, bracket_mask(size, 1, 1, 1, 1, 26, 12, 2), bc, ba)
    fill(img, bracket_mask(size, 367, 73, -1, -1, 26, 12, 2), bc, ba)
    return finish(img, W, H)


def point():
    W, H = 52, 60
    img = canvas(W, H); size = img.size
    cx = 26
    main = [(cx, 2), (46, 22), (cx, 42), (6, 22)]
    shadow = [(cx, 12), (46, 32), (cx, 52), (6, 32)]
    inner = [(cx, 12), (36, 22), (cx, 32), (16, 22)]
    # stacked shadow diamond + chevron at the bottom
    paint(img, gradient(size, NAVY, DEEP, 'v', 0.8, 0.8), poly_mask(size, shadow))
    fill(img, poly_line_mask(size, shadow[1:] + [shadow[3]], 1.2), LINE, 0.6)
    fill(img, poly_line_mask(size, [(18, 52), (cx, 58), (34, 52)], 2), BLUE_HI, 0.9)
    # main diamond
    mm = poly_mask(size, main)
    glow(img, mm, BLUE_HI, 0.4, 3)
    paint(img, gradient(size, (34, 88, 230), HOT_LO), mm)
    fill(img, poly_line_mask(size, main + [main[0]], 1.5), BLUE_HI)
    # bright core
    im = poly_mask(size, inner)
    glow(img, im, LIGHT, 0.7, 2)
    paint(img, gradient(size, (190, 210, 255), (90, 140, 255)), im)
    return finish(img, W, H)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'obtaizen_ui'
    font = sys.argv[2] if len(sys.argv) > 2 else None
    os.makedirs(out, exist_ok=True)
    sprites = {
        'circle.png': circle(False),
        'circle_selected.png': circle(True),
        'selected.png': selected_confirm(),
        'key.png': key(font),
        'label.png': label(True),
        'label_no.png': label(False),
        'point.png': point(),
    }
    for name, im in sprites.items():
        im.save(os.path.join(out, name), optimize=True)
        print(name, im.size)


if __name__ == '__main__':
    main()
