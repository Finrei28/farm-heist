"""Makes Farm Heist's Roblox page art: the game's icon (512 x 512), its
thumbnails (1920 x 1080) and its passes' pictures (512 x 512) from the
scenes stage.py renders, and the community's emblem (512 x 512, drawn) and
cover photo (1440 x 456, from a Studio shot), in the Kraft & Crate look
(docs/GameDesign.md §5.1): a
painted wooden sign hung on two ropes for the title, wooden boards with
cream lettering for each thumbnail's line, Fredoka One like the game's own
headers.

    python tools/page_art/compose.py            every piece whose picture is there
    python tools/page_art/compose.py icon raid  just these

Renders come from `python tools/page_art/stage.py` (art/page/renders/);
Studio shots go in art/page/shots/<name>.png (or .jpg), taken with the HUD
hidden (docs/RobloxPage.md lists what each one shows). Writes
art/page/<name>.png, ready to upload (Creator Dashboard > the experience >
Places > Thumbnails, and the icon under Basic Settings).

The fonts are Roblox's own, from Studio's install (content/fonts).
"""
import glob
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
SHOTS = os.path.join(ROOT, "art", "page", "shots")
OUT = os.path.join(ROOT, "art", "page")

CREAM = (255, 244, 220)
SEAM = (72, 48, 30)
WOOD = (128, 88, 55)
RED = (200, 69, 45)
GOLD = (242, 179, 61)
GREEN = (78, 159, 61)
ROPE = (206, 170, 112)
NAIL = (200, 200, 190)


def font_path(name):
    """A font file from Roblox Studio's install (any version)."""
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    found = sorted(glob.glob(os.path.join(base, "*", "content", "fonts", name)), key=os.path.getmtime)
    if not found:
        sys.exit(f"Couldn't find {name} in Roblox Studio's fonts ({base}).")
    return found[-1]


HEAD = font_path("FredokaOne-Regular.ttf")
HAND = font_path("PatrickHand-Regular.ttf")


TRIM = 6  # px off every edge of a shot (Studio's blue viewport border)


RENDERS = os.path.join(ROOT, "art", "page", "renders")


def shot(name):
    """A picture to build on: "renders/<name>" (tools/page_art/stage.py,
    used whole) or a Studio shot "<name>" (art/page/shots, its border
    trimmed)."""
    if name.startswith("renders/"):
        path = os.path.join(RENDERS, name[len("renders/"):] + ".png")
        return Image.open(path).convert("RGB") if os.path.exists(path) else None
    for ext in ("png", "jpg", "jpeg"):
        path = os.path.join(SHOTS, f"{name}.{ext}")
        if os.path.exists(path):
            image = Image.open(path).convert("RGB")
            return image.crop((TRIM, TRIM, image.width - TRIM, image.height - TRIM))
    return None


def cover(image, size):
    """Scales and crops to fill `size` (the middle kept)."""
    w, h = size
    scale = max(w / image.width, h / image.height)
    image = image.resize((math.ceil(image.width * scale), math.ceil(image.height * scale)), Image.LANCZOS)
    left, top = (image.width - w) // 2, (image.height - h) // 2
    return image.crop((left, top, left + w, top + h))


def shade(rgb, by):
    return tuple(max(0, min(255, int(c * by))) for c in rgb)


def wood_board(size, tint=WOOD, planks=2, radius=14, edge=6):
    """A board of `planks` planks with dark seams, a little grain, a
    darker outline: the game's UI.wood."""
    w, h = size
    board = Image.new("RGBA", size, (0, 0, 0, 0))
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    body = Image.new("RGBA", size, tint + (255,))
    d = ImageDraw.Draw(body)
    for i in range(planks):
        top, bottom = round(i * h / planks), round((i + 1) * h / planks)
        d.rectangle((0, top, w, bottom), fill=shade(tint, 1.0 if i % 2 == 0 else 0.93) + (255,))
        for k in range(5):  # grain
            y = top + (bottom - top) * (k + 1) / 6
            d.line((w * 0.04 + k * 37 % 60, y, w * (0.55 + 0.08 * (k % 3)), y + (k % 2) * 2), fill=shade(tint, 0.86) + (255,), width=2)
        if i > 0:
            d.line((0, top, w, top), fill=SEAM + (255,), width=max(2, h // 40))
    board.paste(body, (0, 0), mask)
    # (the outline's outer edge is the board's: nothing pokes out past it)
    ImageDraw.Draw(board).rounded_rectangle((0, 0, w - 1, h - 1), radius, outline=SEAM + (255,), width=edge)
    return board


def text_size(draw, text, font):
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1], box


def lettered(board, text, font_file, max_size, color=CREAM, stroke=SEAM, pad=0.12):
    """Writes `text` as big as fits on the board, outlined."""
    w, h = board.size
    d = ImageDraw.Draw(board)
    size = max_size
    while size > 10:
        font = ImageFont.truetype(font_file, size)
        sw = max(2, size // 12)
        tw, th, box = text_size(d, text, font)
        if tw + 2 * sw <= w * (1 - 2 * pad) and th + 2 * sw <= h * (1 - 2 * pad):
            break
        size -= 2
    x = (w - tw) / 2 - box[0]
    y = (h - th) / 2 - box[1]
    d.text((x, y), text, font=font, fill=color, stroke_width=sw, stroke_fill=stroke)
    return board


def drop_shadow(layer, offset=(0, 10), blur=14, alpha=110):
    """A soft shadow of the layer's shape, with room round it to blur into
    (returns the shadow and where its corner goes relative to the layer)."""
    pad = blur * 3
    alpha_mask = Image.new("L", (layer.width + 2 * pad, layer.height + 2 * pad), 0)
    alpha_mask.paste(layer.getchannel("A").point(lambda a: a * alpha // 255), (pad, pad))
    alpha_mask = alpha_mask.filter(ImageFilter.GaussianBlur(blur))
    shadow = Image.new("RGBA", alpha_mask.size, (20, 12, 6, 0))
    shadow.putalpha(alpha_mask)
    return shadow, (offset[0] - pad, offset[1] - pad)


def hang(canvas, sign, centre, rope_up=True):
    """Pastes a sign with a soft shadow, hung on two ropes from above with
    nails (the game's window header)."""
    x, y = centre[0] - sign.width // 2, centre[1] - sign.height // 2
    d = ImageDraw.Draw(canvas)
    if rope_up:
        for fx in (0.14, 0.86):
            nx = x + sign.width * fx
            top_x = nx + (-1 if fx < 0.5 else 1) * sign.height * 0.35
            d.line((nx, y + sign.height * 0.18, top_x, 0), fill=ROPE, width=max(4, sign.height // 22))
    shadow, offset = drop_shadow(sign)
    canvas.paste(shadow, (x + offset[0], y + offset[1]), shadow)
    canvas.paste(sign, (x, y), sign)
    if rope_up:
        r = max(5, sign.height // 18)
        for fx in (0.14, 0.86):
            nx, ny = x + sign.width * fx, y + sign.height * 0.18
            d.ellipse((nx - r, ny - r, nx + r, ny + r), fill=NAIL, outline=SEAM, width=2)


def title_sign(width, tint=RED):
    height = round(width * 0.27)
    sign = wood_board((width, height), tint, planks=3, radius=height // 8, edge=max(6, height // 18))
    return lettered(sign, "FARM HEIST", HEAD, height)


def banner(text, width, tint=WOOD):
    height = round(width * 0.17)
    board = wood_board((width, height), tint, planks=1, radius=height // 6, edge=max(5, height // 16))  # (one plank: no seam through the words)
    return lettered(board, text, HEAD, height)


def vignette(image, strength=0.35):
    w, h = image.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((-w * 0.25, -h * 0.25, w * 1.25, h * 1.25), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) // 6))
    dark = Image.new("RGB", (w, h), (20, 14, 8))
    return Image.composite(image, Image.blend(image, dark, strength), mask)


# ---------------------------------------------------------------------------
# The pieces: (shot, how to make it)

def focus(src, box):
    """The part of a shot a piece is about: box = (left, top, right, bottom)
    as shares of the shot's width and height."""
    w, h = src.size
    return src.crop((round(box[0] * w), round(box[1] * h), round(box[2] * w), round(box[3] * h)))


def icon(src):
    """512 x 512: the raid's two characters filling it (the thief with the
    stolen crop and the red !, the farmer with the bat), the title sign
    across the bottom."""
    size = (512, 512)
    src = focus(src, (0.396, 0.377, 0.635, 0.985))
    canvas = vignette(cover(src, size), 0.3).convert("RGBA")
    sign = title_sign(470)
    hang(canvas, sign, (256, 512 - sign.height // 2 - 22), rope_up=False)
    return canvas.convert("RGB")


# ---------------------------------------------------------------------------
# The community's emblem: drawn, not a shot (a mark that still reads at the
# 40-odd pixels Roblox shows it at in lists)

ORANGE = (240, 128, 38)
BAT_WOOD = (222, 176, 112)  # (CrimeArt's plain bat: wood, its darker knob, barn red grip tape)
BAT_DARK = (184, 136, 80)
LEAF = (78, 159, 61)


def lathe(size, centre_x, profile, colors, bands=(-0.38, 0.42)):
    """A round thing standing upright, cel-shaded like the game's meshes:
    profile = [(y, half width)] down its length; colors(y) gives (light,
    base, shade) for that height. Returns an RGBA layer."""
    w, h = size
    ys, half = zip(*profile)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    hw = np.interp(yy, ys, half, left=0, right=0)
    u = np.where(hw > 0, (xx - centre_x) / np.maximum(hw, 1e-3), 9)
    inside = np.abs(u) <= 1
    out = np.zeros((h, w, 4), np.uint8)
    for y0 in range(int(min(ys)), int(max(ys)) + 1):
        light, base, dark = colors(y0)
        row = inside[y0]
        ur = u[y0]
        for mask, rgb in ((row & (ur < bands[0]), light), (row & (ur >= bands[0]) & (ur <= bands[1]), base), (row & (ur > bands[1]), dark)):
            out[y0, mask, :3] = rgb
            out[y0, mask, 3] = 255
    return Image.fromarray(out, "RGBA"), u


def round_end(y_end, radius, toward, steps=24):
    """Profile points for a rounded end: a half circle of `radius` whose
    tip is at y_end (toward: +1 if the shape goes on downward from it)."""
    pts = []
    for k in range(steps + 1):
        a = math.pi / 2 * k / steps
        pts.append((y_end + toward * radius * (1 - math.cos(a)), radius * math.sin(a)))
    return pts


def bat_layer(n):
    """The plain bat, upright on an n x n layer, the barrel up."""
    cx, top, bottom = n / 2, n * 0.11, n * 0.89
    barrel_r = n * 0.052
    taper_top, taper_bottom, knob = n * 0.42, n * 0.62, n * 0.855
    profile = round_end(top, barrel_r, +1)
    profile += [(taper_top, barrel_r * 0.96), (taper_bottom - n * 0.06, n * 0.024), (taper_bottom, n * 0.018), (knob - n * 0.012, n * 0.018)]
    profile += [(knob, n * 0.036), (bottom - n * 0.012, n * 0.038), (bottom, n * 0.02)]

    def colors(y):
        if y >= knob - n * 0.012:
            return shade(BAT_DARK, 1.12), BAT_DARK, shade(BAT_DARK, 0.8)
        if y >= taper_bottom - n * 0.02:  # the taped grip
            return shade(RED, 1.18), RED, shade(RED, 0.78)
        return shade(BAT_WOOD, 1.1), BAT_WOOD, BAT_DARK

    layer, u = lathe((n, n), cx, profile, colors)
    d = ImageDraw.Draw(layer)
    # the tape's wraps: dark diagonal lines across the grip
    y = taper_bottom + n * 0.01
    while y < knob - n * 0.03:
        d.line((cx - n * 0.02, y + n * 0.012, cx + n * 0.02, y - n * 0.004), fill=shade(RED, 0.62) + (255,), width=max(2, n // 220))
        y += n * 0.03
    return layer


def carrot_layer(n):
    """A carrot, upright on an n x n layer: the leaves up, the tip down."""
    cx, top, tip = n / 2, n * 0.33, n * 0.92
    r = n * 0.076
    profile = round_end(top, r, +1, steps=20)
    for k in range(1, 21):
        t = k / 20
        profile.append((top + r + (tip - top - r) * t, r * (1 - t) ** 0.85 + n * 0.006 * (1 - t)))
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # leaves behind the body: three blades fanned out, each with a midrib
    for angle, length, width in ((-28, 0.25, 0.07), (28, 0.25, 0.07), (0, 0.29, 0.075)):
        a = math.radians(angle)
        base = (cx, top + r * 0.5)
        ux, uy = math.sin(a), -math.cos(a)  # along the blade
        px, py = -uy, ux  # across it
        pts_l, pts_r = [], []
        for k in range(21):
            t = k / 20
            along, across = length * n * t, width * n * math.sin(math.pi * t ** 0.8) * 0.5
            pts_l.append((base[0] + ux * along + px * across, base[1] + uy * along + py * across))
            pts_r.append((base[0] + ux * along - px * across, base[1] + uy * along - py * across))
        d.polygon(pts_l + pts_r[::-1], fill=LEAF + (255,))
        d.polygon(pts_l + [(base[0] + ux * length * n, base[1] + uy * length * n)] + [base], fill=shade(LEAF, 1.18) + (255,))
        d.line((base, (base[0] + ux * length * n * 0.92, base[1] + uy * length * n * 0.92)), fill=shade(LEAF, 0.7) + (255,), width=max(2, n // 160))
    body, u = lathe((n, n), cx, profile, lambda y: (shade(ORANGE, 1.12), ORANGE, shade(ORANGE, 0.8)))
    # its rings: short dark bows, left and right in turn
    bd = ImageDraw.Draw(body)
    ys = np.linspace(top + r * 1.1, tip - n * 0.1, 7)
    for i, y in enumerate(ys):
        hw = np.interp(y, [p[0] for p in profile], [p[1] for p in profile])
        x0, x1 = (cx - hw * 0.8, cx - hw * 0.1) if i % 2 == 0 else (cx + hw * 0.05, cx + hw * 0.75)
        bd.arc((x0, y - hw * 0.25, x1, y + hw * 0.25), 20, 160, fill=shade(ORANGE, 0.66) + (255,), width=max(2, n // 150))
    layer.alpha_composite(body)
    return layer


def sticker(layer, width, color=SEAM):
    """The layer with a thick outline round its whole shape (the game's
    cartoon edge), drawn under it."""
    alpha = layer.getchannel("A").filter(ImageFilter.GaussianBlur(width / 1.9))
    alpha = alpha.point(lambda v: 255 if v > 10 else 0).filter(ImageFilter.GaussianBlur(1.2))
    out = Image.new("RGBA", layer.size, color + (0,))
    out.putalpha(alpha)
    out.alpha_composite(layer)
    return out


def sparkle(draw, cx, cy, r, color=GOLD, edge=SEAM, edge_w=0):
    pts = []
    for k in range(8):
        a = math.pi / 4 * k - math.pi / 2
        rr = r if k % 2 == 0 else r * 0.3
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    if edge_w:
        draw.polygon(pts, fill=color, outline=edge, width=edge_w)
    else:
        draw.polygon(pts, fill=color)


def stitched(draw, box, radius, color, dash, gap, width):
    """A dashed line round a rounded box: Kraft & Crate's stitched edge."""
    x0, y0, x1, y1 = box
    turns = []  # the corners' arcs, in order round the box
    corners = ((x1 - radius, y0 + radius, -90), (x1 - radius, y1 - radius, 0), (x0 + radius, y1 - radius, 90), (x0 + radius, y0 + radius, 180))
    for (cx, cy, start) in corners:
        steps = max(1, int(radius * math.pi / 2))
        for k in range(steps + 1):
            a = math.radians(start + 90 * k / steps)
            turns.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    turns.append(turns[0])
    path = [turns[0]]  # every pixel or so, the straight sides too
    for a, b in zip(turns, turns[1:]):
        parts = max(1, int(math.dist(a, b)))
        path += [(a[0] + (b[0] - a[0]) * k / parts, a[1] + (b[1] - a[1]) * k / parts) for k in range(1, parts + 1)]
    run, on, seg = 0.0, True, [path[0]]
    for a, b in zip(path, path[1:]):
        step = math.dist(a, b)
        run += step
        seg.append(b)
        if run >= (dash if on else gap):
            if on and len(seg) > 1:
                draw.line(seg, fill=color, width=width, joint="curve")
            on, run, seg = not on, 0.0, [b]
    if on and len(seg) > 1:
        draw.line(seg, fill=color, width=width, joint="curve")


def emblem(_src=None, tint=RED, size=512, s=4):
    """512 x 512: the plain bat and a carrot crossed, outlined like a
    sticker, on a board of planks with a stitched cream edge, a gold
    sparkle in the gap at the top (a stolen crop's). Drawn s times bigger,
    then scaled down."""
    n = size * s
    canvas = Image.new("RGBA", (n, n), tint + (255,))
    d = ImageDraw.Draw(canvas)
    planks = 4
    for i in range(planks):  # upright planks, like the barn's door
        left, right = round(i * n / planks), round((i + 1) * n / planks)
        d.rectangle((left, 0, right, n), fill=shade(tint, 1.0 if i % 2 == 0 else 0.93))
        for k in range(4):
            x = left + (right - left) * (k + 1) / 5
            d.line((x, n * (0.05 + 0.1 * (k % 3)), x + 3 * s, n * (0.5 + 0.12 * (k % 2))), fill=shade(tint, 0.88), width=2 * s)
        if i:
            d.line((left, 0, left, n), fill=shade(tint, 0.55), width=3 * s)
    glow = Image.new("L", (n, n), 0)
    ImageDraw.Draw(glow).ellipse((n * 0.12, n * 0.12, n * 0.88, n * 0.88), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.1))
    canvas = Image.composite(Image.new("RGBA", (n, n), shade(tint, 1.35) + (255,)), canvas, glow)
    d = ImageDraw.Draw(canvas)
    inset = round(n * 0.055)
    stitched(d, (inset, inset, n - inset, n - inset), round(n * 0.09), CREAM, 9 * s, 7 * s, 4 * s)

    edge = 9 * s
    bat = sticker(bat_layer(n), edge).rotate(-40, resample=Image.BICUBIC, center=(n / 2, n / 2))
    carrot = sticker(carrot_layer(n), edge).rotate(40, resample=Image.BICUBIC, center=(n / 2, n * 0.56), translate=(0, -n * 0.06))
    mark = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    mark.alpha_composite(bat)
    mark.alpha_composite(carrot)
    shadow, offset = drop_shadow(mark, offset=(0, 6 * s), blur=8 * s, alpha=120)
    ox, oy = offset
    canvas.alpha_composite(shadow, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
    canvas.alpha_composite(mark)
    d = ImageDraw.Draw(canvas)
    sparkle(d, n * 0.5, n * 0.2, n * 0.075, GOLD, SEAM, 3 * s)
    sparkle(d, n * 0.62, n * 0.13, n * 0.03, CREAM)
    sparkle(d, n * 0.38, n * 0.86, n * 0.028, CREAM)
    return canvas.resize((size, size), Image.LANCZOS).convert("RGB")


def community_cover(src):
    """1440 x 456 (the community page's cover photo, 60:19): the farm at
    Golden Hour, the barn and farmhouse in the top half on the left, the
    FARM HEIST sign hung on the right over the warehouse. Roblox fades the
    bottom of the cover into the page and puts the emblem and the
    community's name over its lower left, so nothing that matters is down
    there. The shot's right three quarters, about 1:1 (no scaling up)."""
    size = (1440, 456)
    left, top = 0.25, 0.22
    src = focus(src, (left, top, 1, top + ((1 - left) * src.width * 19 / 60) / src.height))
    canvas = vignette(cover(src, size), 0.2).convert("RGBA")
    sign = title_sign(640)
    hang(canvas, sign, (1040, 60 + sign.height // 2))
    return canvas.convert("RGB")


def rendered_icon(src):
    """512 x 512 from the staged render (stage.py's icon): no words, like
    the top games' icons; the characters say what the game is."""
    return vignette(cover(src, (512, 512)), 0.22)


def star(draw, cx, cy, r, fill, edge, edge_w):
    pts = []
    for k in range(10):
        a = math.pi / 5 * k - math.pi / 2
        rr = r if k % 2 == 0 else r * 0.46
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    draw.polygon(pts, fill=fill)
    draw.line(pts + pts[:2], fill=edge, width=edge_w, joint="curve")


def vip_tag(width):
    """The gold tag over a VIP's head, as in the game (MonetizationService):
    a dark pill with a gold edge, a gold star and VIP."""
    height = round(width * 0.36)
    s = 3  # (drawn large, for smooth edges)
    w, h = width * s, height * s
    tag = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(tag)
    d.rounded_rectangle((0, 0, w - 1, h - 1), h // 2, fill=(74, 50, 32, 255), outline=GOLD + (255,), width=round(h * 0.075))
    font = ImageFont.truetype(HEAD, round(h * 0.68))
    tw, th, box = text_size(d, "VIP", font)
    r = h * 0.3
    gap = h * 0.08
    left = (w - (2 * r + gap + tw)) / 2
    star(d, left + r, h / 2, r, GOLD + (255,), shade(GOLD, 0.7) + (255,), max(3, round(h * 0.02)))
    d.text((left + 2 * r + gap - box[0], (h - th) / 2 - box[1]), "VIP", font=font, fill=GOLD + (255,))
    return tag.resize((width, height), Image.LANCZOS)


def pass_vip(src):
    """Roblox shows a pass as a circle (up to 512 x 512): the tag sits
    inside it, over Hank's head."""
    canvas = vignette(cover(src, (1024, 1024)), 0.16).convert("RGBA")
    tag = vip_tag(560)
    hang(canvas, tag, (512, 150), rope_up=False)
    return canvas.convert("RGB").resize((512, 512), Image.LANCZOS)


def pass_barn(src):
    canvas = vignette(cover(src, (1024, 1024)), 0.16).convert("RGBA")
    height = 190
    board = wood_board((540, height), GOLD, planks=1, radius=height // 6, edge=max(5, height // 16))
    lettered(board, "×2.5", HEAD, height)
    hang(canvas, board, (512, 810), rope_up=False)
    return canvas.convert("RGB").resize((512, 512), Image.LANCZOS)


def thumb(line, tint=WOOD, title=False, top=False, title_w=820, board_w=1120):
    """top: the line's board hangs at the top (the shot's subject is low)."""
    def make(src):
        size = (1920, 1080)
        canvas = vignette(cover(src, size), 0.28).convert("RGBA")
        if title:
            sign = title_sign(title_w)
            hang(canvas, sign, (960, 50 + sign.height // 2))
        board = banner(line, board_w, tint)
        if top:
            hang(canvas, board, (960, board.height // 2 + 90))
        else:
            hang(canvas, board, (960, 1080 - board.height // 2 - 60), rope_up=False)
        return canvas.convert("RGB")
    return make


PIECES = {
    # the game's icon and thumbnails: staged renders (stage.py) of Sly the
    # thief and Farmer Hank, made up for the page
    "icon": ("renders/icon", rendered_icon),
    "farm": ("renders/farm", thumb("GROW CROPS · RUN YOUR FARM", GREEN, title=True, title_w=700, board_w=1000)),
    "raid": ("renders/raid", thumb("STEAL CROPS · BONK THIEVES!", RED, top=True)),
    "store": ("renders/store", thumb("BUILD YOUR OWN STORE", WOOD)),
    "auction": ("renders/auction", thumb("BID ON RARE SEEDS", GOLD)),
    "trucks": ("renders/trucks", thumb("SHIP TO THE CITY", WOOD)),
    # the game passes' pictures
    "pass_vip": ("renders/pass_vip", pass_vip),
    "pass_barn": ("renders/pass_barn", pass_barn),
    # the community (Roblox's Communities > Configure > Information)
    "community_emblem": (None, emblem),
    "community_cover": ("farm", community_cover),
}


def main(argv):
    os.makedirs(OUT, exist_ok=True)
    names = argv or list(PIECES)
    for name in names:
        if name not in PIECES:
            print("Not a piece:", name)
            continue
        shot_name, make = PIECES[name]
        src = shot(shot_name) if shot_name else None
        if shot_name and src is None:
            print(f"  {name}: no shot yet (art/page/shots/{shot_name}.png)")
            continue
        out = make(src)
        path = os.path.join(OUT, f"{name}.png")
        out.save(path)
        print(f"  {name}.png  {out.width}x{out.height}")


if __name__ == "__main__":
    main(sys.argv[1:])
