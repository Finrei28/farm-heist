"""Makes Farm Heist's Roblox page art from Studio screenshots: the game's
icon (512 x 512) and its thumbnails (1920 x 1080), in the Kraft & Crate
look (docs/GameDesign.md §5.1): a painted wooden sign hung on two ropes
for the title, wooden boards with cream lettering for each thumbnail's
line, Fredoka One like the game's own headers.

    python tools/page_art/compose.py            every piece whose shot is there
    python tools/page_art/compose.py icon raid  just these

Shots go in art/page/shots/<name>.png (or .jpg), taken in Studio with the
HUD hidden (docs/RobloxPage.md lists what each one shows). Writes
art/page/<name>.png, ready to upload (Creator Dashboard > the experience >
Places > Thumbnails, and the icon under Basic Settings).

The fonts are Roblox's own, from Studio's install (content/fonts).
"""
import glob
import math
import os
import sys

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


def shot(name):
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


def thumb(line, tint=WOOD, title=False, top=False):
    """top: the line's board hangs at the top (the shot's subject is low)."""
    def make(src):
        size = (1920, 1080)
        canvas = vignette(cover(src, size), 0.28).convert("RGBA")
        if title:
            hang(canvas, title_sign(820), (960, 200))
        board = banner(line, 1120, tint)
        if top:
            hang(canvas, board, (960, board.height // 2 + 90))
        else:
            hang(canvas, board, (960, 1080 - board.height // 2 - 60), rope_up=False)
        return canvas.convert("RGB")
    return make


PIECES = {
    "icon": ("raid", icon),
    "farm": ("farm", thumb("GROW CROPS · RUN YOUR FARM", GREEN, title=True)),
    "raid": ("raid", thumb("STEAL CROPS · BONK THIEVES!", RED, top=True)),
    "store": ("store", thumb("BUILD YOUR OWN STORE", WOOD)),
    "auction": ("auction", thumb("BID ON RARE SEEDS", GOLD)),
    "trucks": ("trucks", thumb("SHIP TO THE CITY", WOOD)),
}


def main(argv):
    os.makedirs(OUT, exist_ok=True)
    names = argv or list(PIECES)
    for name in names:
        if name not in PIECES:
            print("Not a piece:", name)
            continue
        shot_name, make = PIECES[name]
        src = shot(shot_name)
        if src is None:
            print(f"  {name}: no shot yet (art/page/shots/{shot_name}.png)")
            continue
        out = make(src)
        path = os.path.join(OUT, f"{name}.png")
        out.save(path)
        print(f"  {name}.png  {out.width}x{out.height}")


if __name__ == "__main__":
    main(sys.argv[1:])
