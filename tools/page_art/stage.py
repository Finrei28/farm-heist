"""Farm Heist's page art, staged and rendered: two made-up characters (Sly,
a thief running off with a pumpkin held up over his head, and Farmer Hank
chasing him with the bat) on the real farm (tools/partdump.luau's parts and
the crop meshes), drawn by a small software renderer in the game's
low-poly look, with what a Roblox icon needs on top: faces and patterned
clothes, dark outlines round the characters, a rim light, the background
softly out of focus, and sparkles, a glow and motion lines.

    python tools/page_art/stage.py            every scene
    python tools/page_art/stage.py icon raid  just these

Writes art/page/renders/<scene>.png; compose.py hangs the signs on them.
The farm comes from `lune run tools/partdump <json> 5 16` (run for you,
into art/page/renders/farm.json, if it isn't there).
"""
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "crop_art"))

import partview  # noqa: E402  (the farm's parts as triangles; registers every mesh)
from crops import built as built_crop  # noqa: E402
from meshkit import Mesh, R, T, lathe, mul  # noqa: E402
from palette import PROP_COLOURS  # noqa: E402
from render import _raster  # noqa: E402

OUT = os.path.join(ROOT, "art", "page", "renders")
OUTLINE = np.array([46, 30, 22]) / 255  # (the page art's seam brown)


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / (np.linalg.norm(v) + 1e-12)


def rgb(c):
    if isinstance(c, str):
        c = PROP_COLOURS.get(c, (255, 0, 255))
    return np.array(c[:3], dtype=float) / 255


# ---------------------------------------------------------------------------
# The scene and its renderer


class Scene:
    """Triangles in world space, each belonging to a part. A part can have
    an outline, a rim light, a glow, and pictures on its faces (`tex`:
    {"+z": RGBA array, ...} in the part's own frame, `frame` its
    local-to-world matrix, `half` its half size)."""

    def __init__(self):
        self.tris, self.cols, self.pid, self.parts = [], [], [], []

    def add(self, tris, cols, **part):
        tris = np.asarray(tris, dtype=float).reshape(-1, 3, 3)
        if len(tris) == 0:
            return None
        pid = len(self.parts)
        self.parts.append(part)
        self.tris.append(tris)
        self.cols.append(np.asarray(cols, dtype=float).reshape(-1, 3))
        self.pid.append(np.full(len(tris), pid))
        return pid

    def add_mesh(self, mesh, m, **part):
        world = mesh.transformed(m)
        cols = [rgb(c) for c in world.cols]
        if "frame" not in part and part.get("tex"):
            part["frame"] = m
        return self.add(world.array(), cols, **part)


def _shadows(casters, points, sun, normals, res=3072):
    """1 where `points` see the sun, 0 in shadow; points outside the
    casters' map are lit."""
    lr = unit(np.cross(sun, [0, 0, 1]) if abs(sun[2]) < 0.9 else np.cross(sun, [1, 0, 0]))
    lu = np.cross(lr, sun)
    flat = casters.reshape(-1, 3)
    lx, ly = flat @ lr, flat @ lu
    lo = np.array([lx.min(), ly.min()]) - 0.5
    hi = np.array([lx.max(), ly.max()]) + 0.5
    scale = (res - 1) / max(hi - lo)
    sx = ((casters @ lr) - lo[0]) * scale
    sy = ((casters @ lu) - lo[1]) * scale
    sd = casters @ sun
    offset = sd.min() - 1
    depth = np.full((res, res), -np.inf)
    for t in range(len(casters)):
        _raster(sx[t], sy[t], sd[t] - offset, res, res, depth, None, t)
    qx = ((points @ lr) - lo[0]) * scale
    qy = ((points @ lu) - lo[1]) * scale
    qd = points @ sun - offset
    inside = (qx >= 0) & (qx < res) & (qy >= 0) & (qy < res)
    bias = 0.05 + 0.1 * (1 - np.clip(np.abs(normals @ sun), 0, 1))
    seen = np.zeros(len(points))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            ix = np.clip((qx + dx).astype(int), 0, res - 1)
            iy = np.clip((qy + dy).astype(int), 0, res - 1)
            seen += depth[iy, ix] <= qd + bias
    return np.where(inside, seen / 9, 1.0)


def _sample(tex, u, v):
    h, w = tex.shape[:2]
    x = np.clip(u * (w - 1), 0, w - 1)
    y = np.clip(v * (h - 1), 0, h - 1)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    x1, y1 = np.minimum(x0 + 1, w - 1), np.minimum(y0 + 1, h - 1)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    top = tex[y0, x0] * (1 - fx) + tex[y0, x1] * fx
    bottom = tex[y1, x0] * (1 - fx) + tex[y1, x1] * fx
    return top * (1 - fy) + bottom * fy


FACES = {(0, 1): "+x", (0, -1): "-x", (1, 1): "+y", (1, -1): "-y", (2, 1): "+z", (2, -1): "-z"}


def _uv(face, p, half):
    x, y, z = (p[:, i] / half[i] for i in range(3))
    if face == "+z":
        return (x + 1) / 2, (1 - y) / 2
    if face == "-z":
        return (1 - x) / 2, (1 - y) / 2
    if face == "+x":
        return (1 - z) / 2, (1 - y) / 2
    if face == "-x":
        return (z + 1) / 2, (1 - y) / 2
    if face == "+y":
        return (x + 1) / 2, (z + 1) / 2
    return (x + 1) / 2, (1 - z) / 2


class Shot:
    """A rendered picture and its camera, to find where 3D points land."""

    def __init__(self, image, eye, right, up, forward, focal, size):
        self.image, self.eye, self.right, self.up, self.forward = image, eye, right, up, forward
        self.focal, self.size = focal, size

    def at(self, p):
        rel = np.asarray(p, dtype=float) - self.eye
        z = rel @ self.forward
        return (self.size[0] / 2 + (rel @ self.right) / z * self.focal, self.size[1] / 2 - (rel @ self.up) / z * self.focal)


def render(scene, eye, target, size, fov=40.0, ss=2, sun=(-0.35, 0.8, 0.5), sky=None, shadow_at=None,
           shadow_radius=30.0, outline=3.0, dof=None, light=1.0):
    """Draws the scene. sky(w, h) gives the backdrop (RGB array 0..1);
    shadows are cast by what's within shadow_radius of shadow_at; outline:
    its width in output pixels round parts that have one; dof: (near, far)
    studs from the eye, the background going softly out of focus between
    them (outlined parts stay sharp)."""
    tris = np.concatenate(scene.tris)
    cols = np.concatenate(scene.cols)
    pid = np.concatenate(scene.pid)
    parts = scene.parts
    width, height = size[0] * ss, size[1] * ss
    eye, target = np.asarray(eye, dtype=float), np.asarray(target, dtype=float)
    forward = unit(target - eye)
    right = unit(np.cross(forward, [0, 1, 0]))
    up = np.cross(right, forward)
    focal = (height / 2) / math.tan(math.radians(fov) / 2)

    normals = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    normals /= np.linalg.norm(normals, axis=1, keepdims=True) + 1e-12
    centres = tris.mean(axis=1)
    facing = np.einsum("ij,ij->i", normals, eye - centres) > 0
    rel = tris - eye
    cx, cy, cz = rel @ right, rel @ up, rel @ forward
    sx = width / 2 + cx / np.maximum(cz, 1e-6) * focal
    sy = height / 2 - cy / np.maximum(cz, 1e-6) * focal
    onscreen = (sx.max(axis=1) >= 0) & (sx.min(axis=1) < width) & (sy.max(axis=1) >= 0) & (sy.min(axis=1) < height)
    depth = np.full((height, width), -np.inf)
    ids = np.full((height, width), -1, dtype=np.int64)
    for t in np.where(facing & onscreen & (cz.min(axis=1) > 0.05))[0]:
        _raster(sx[t], sy[t], 1 / cz[t], width, height, depth, ids, t)

    hit = ids >= 0
    py, px = np.nonzero(hit)
    dz = 1 / depth[py, px]
    ray_x = (px + 0.5 - width / 2) / focal
    ray_y = -(py + 0.5 - height / 2) / focal
    world = eye + (right[None] * ray_x[:, None] + up[None] * ray_y[:, None] + forward[None]) * dz[:, None]
    tid = ids[py, px]
    n = normals[tid]
    part_of = pid[tid]
    base = cols[tid].copy()

    # pictures on faces
    for p, part in enumerate(parts):
        tex = part.get("tex")
        if not tex:
            continue
        mask = part_of == p
        if not mask.any():
            continue
        inv = np.linalg.inv(part["frame"])
        local = world[mask] @ inv[:3, :3].T + inv[:3, 3]
        nl = n[mask] @ inv[:3, :3].T
        axis = np.argmax(np.abs(nl), axis=1)
        sign = np.where(nl[np.arange(len(nl)), axis] >= 0, 1, -1)
        rows = np.where(mask)[0]
        for (ax, sg), face in FACES.items():
            if face not in tex:
                continue
            sel = (axis == ax) & (sign == sg)
            if not sel.any():
                continue
            u, v = _uv(face, local[sel], np.asarray(part["half"], dtype=float))
            texel = _sample(tex[face], u, v)
            a = texel[:, 3:4]
            base[rows[sel]] = base[rows[sel]] * (1 - a) + texel[:, :3] * a

    sun = unit(sun)
    lit = np.ones(len(tid))
    if shadow_at is not None:
        near = np.linalg.norm(centres - np.asarray(shadow_at, dtype=float), axis=1) < shadow_radius
        near &= ~np.array([bool(part.get("no_shadow")) for part in parts])[pid]
        lit = _shadows(tris[near], world, sun, n)
    # (a fill light on the characters: a shadow only half darkens them, so
    # a face under a held-up pumpkin still reads)
    fill = np.array([0.5 if part.get("outline") else 0.0 for part in parts])[part_of]
    lit = fill + (1 - fill) * lit
    diffuse = np.clip(n @ sun, 0, 1) * lit
    skyterm = 0.5 + 0.5 * n[:, 1]
    shade = (0.5 + 0.14 * skyterm + 0.56 * diffuse) * light
    view = unit_rows(eye - world)
    rim_k = np.array([part.get("rim", 0.0) for part in parts])[part_of]
    glow_k = np.array([part.get("glow", 0.0) for part in parts])[part_of]
    fres = np.clip(1 - np.einsum("ij,ij->i", n, view), 0, 1) ** 2
    colour = base * (shade + glow_k)[:, None] + (rim_k * fres)[:, None] * np.array([1.0, 0.95, 0.85])

    image = sky(width, height) if sky else np.ones((height, width, 3)) * 0.8
    image[py, px] = np.clip(colour, 0, 1)

    # the part each pixel shows, and whether it's outlined
    pimg = np.full((height, width), -1, dtype=np.int64)
    pimg[py, px] = part_of
    outlined = np.array([bool(part.get("outline")) for part in parts] + [False])
    fimg = outlined[pimg]  # (-1 indexes the trailing False)

    if dof:
        dist = np.full((height, width), 1e9)
        dist[py, px] = np.linalg.norm(world - eye, axis=1)
        k = np.clip((dist - dof[0]) / (dof[1] - dof[0]), 0, 1)
        k = k * k * (3 - 2 * k)
        if len(dof) > 3:  # (and close in front of the camera too)
            near = np.clip((dof[3] - dist) / 2.5, 0, 1)
            k = np.maximum(k, near * near * (3 - 2 * near))
        k[fimg] = 0
        blurred = np.asarray(Image.fromarray((image * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(dof[2] * ss if len(dof) > 2 else 5 * ss)), dtype=float) / 255
        image = image * (1 - k[..., None]) + blurred * k[..., None]

    if outline and fimg.any():
        ys, xs = np.nonzero(fimg)
        r = max(1, round(outline * ss / 2))
        y0, y1 = max(0, ys.min() - r), min(height, ys.max() + r + 1)
        x0, x1 = max(0, xs.min() - r), min(width, xs.max() + r + 1)
        P = pimg[y0:y1, x0:x1]
        D = depth[y0:y1, x0:x1]
        F = fimg[y0:y1, x0:x1]
        pad = r
        Pp = np.pad(P, pad, constant_values=-1)
        Dp = np.pad(D, pad, constant_values=-np.inf)
        edge = np.zeros_like(F)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy > r * r:
                    continue
                Pn = Pp[pad + dy:pad + dy + P.shape[0], pad + dx:pad + dx + P.shape[1]]
                Dn = Dp[pad + dy:pad + dy + P.shape[0], pad + dx:pad + dx + P.shape[1]]
                edge |= F & (Pn != P) & (Dn < D * 0.985)
        region = image[y0:y1, x0:x1]
        region[edge] = OUTLINE
    out = Image.fromarray((np.clip(image, 0, 1) * 255).astype(np.uint8))
    shot = Shot(out.resize(size, Image.LANCZOS), eye, right, up, forward, focal / ss, size)
    return shot


def unit_rows(v):
    return v / (np.linalg.norm(v, axis=1, keepdims=True) + 1e-12)


def sky_gradient(top=(70, 150, 235), low=(196, 228, 252), clouds=()):
    """A sky from `top` down to `low` at the horizon, with soft clouds:
    (x, y, width) as shares of the picture."""
    def make(w, h):
        g = np.linspace(0, 1, h)[:, None, None] ** 0.9
        img = np.array(top)[None, None] / 255 * (1 - g) + np.array(low)[None, None] / 255 * g
        img = np.repeat(img, w, axis=1)
        if clouds:
            layer = Image.new("L", (w, h), 0)
            d = ImageDraw.Draw(layer)
            for (cx, cy, cw) in clouds:
                bw = cw * w
                for k, (ox, oy, rr) in enumerate(((0, 0, 0.32), (-0.28, 0.08, 0.24), (0.3, 0.07, 0.26), (0.12, -0.12, 0.25), (-0.12, -0.08, 0.22))):
                    x, y, r = cx * w + ox * bw, cy * h + oy * bw, rr * bw
                    d.ellipse((x - r, y - r * 0.8, x + r, y + r * 0.8), fill=235)
            layer = layer.filter(ImageFilter.GaussianBlur(w / 300))
            a = np.asarray(layer, dtype=float)[..., None] / 255
            img = img * (1 - a) + a * np.array([1.0, 1.0, 1.0])
        return img
    return make


# ---------------------------------------------------------------------------
# Shapes


def rounded_box(size, col, radius, steps=4):
    """A box with its edges and corners rounded off (radius in studs)."""
    h = np.array(size, dtype=float) / 2
    r = min(radius, h.min() * 0.95)

    def coords(hh):
        ts = [-hh + r * (1 - math.cos(math.pi / 2 * k / steps)) for k in range(steps + 1)]
        return ts + [-t for t in reversed(ts)]

    def shape(p):
        inner = np.clip(p, -(h - r), h - r)
        d = p - inner
        L = np.linalg.norm(d)
        return inner + r * d / L if L > 1e-9 else p

    mesh = Mesh()
    for axis in range(3):
        a, b = [i for i in range(3) if i != axis]
        ca, cb = coords(h[a]), coords(h[b])
        for sign in (-1, 1):
            for i in range(len(ca) - 1):
                for j in range(len(cb) - 1):
                    quad = []
                    for (u, v) in ((ca[i], cb[j]), (ca[i + 1], cb[j]), (ca[i + 1], cb[j + 1]), (ca[i], cb[j + 1])):
                        p = np.zeros(3)
                        p[axis], p[a], p[b] = sign * h[axis], u, v
                        quad.append(shape(p))
                    mesh.quad(*quad, col, inside=np.zeros(3))
    return mesh


def cylinder(length, radius, col, sides=16):
    return lathe([(-length / 2, radius), (length / 2, radius)], sides, col)


# ---------------------------------------------------------------------------
# Pictures for faces and clothes (RGBA, 0..1)


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def as_tex(img):
    return np.asarray(img, dtype=float) / 255


def stripes(w, h, a, b, bands, upto=1.0):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    end = round(h * upto)
    for k in range(bands):
        y0, y1 = round(k * end / bands), round((k + 1) * end / bands)
        d.rectangle((0, y0, w, y1), fill=a if k % 2 == 0 else b)
    return img


def plaid(w, h, upto=1.0, base=(196, 52, 44), dark=(128, 28, 30), line=(250, 214, 120), step=64):
    img = canvas(w, h)
    end = round(h * upto)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, end), fill=base + (255,))
    for x in range(0, w + step, step):
        d.rectangle((x, 0, x + step // 3, end), fill=dark + (150,))
    for y in range(0, end + step, step):
        d.rectangle((0, y, w, min(end, y + step // 3)), fill=dark + (150,))
    for x in range(step // 2, w + step, step):
        d.line((x, 0, x, end), fill=line + (200,), width=3)
    for y in range(step // 2, end, step):
        d.line((0, y, w, y), fill=line + (200,), width=3)
    return img


DENIM = (62, 104, 170)
DENIM_DARK = (44, 76, 130)
SKIN_THIEF = (232, 178, 132)
SKIN_FARMER = (246, 198, 160)
CHARCOAL = (44, 44, 54)
BROWN = (110, 70, 40)


def eye(d, cx, cy, rx, ry, look=(0.0, 0.0), lid=0.0, white=(255, 255, 255)):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=white + (255,), outline=(30, 22, 18, 255), width=max(3, round(rx * 0.12)))
    pr = rx * 0.55
    px, py = cx + look[0] * rx * 0.42, cy + look[1] * ry * 0.35
    d.ellipse((px - pr, py - pr * 1.1, px + pr, py + pr * 1.1), fill=(30, 22, 18, 255))
    d.ellipse((px - pr * 0.15 - pr * 0.35, py - pr * 0.6 - pr * 0.3, px - pr * 0.15 + pr * 0.35, py - pr * 0.6 + pr * 0.3), fill=(255, 255, 255, 255))
    if lid:
        d.rectangle((cx - rx - 4, cy - ry - 4, cx + rx + 4, cy - ry + lid * 2 * ry), fill=(0, 0, 0, 0))


def thief_face(look=(0.8, -0.1), mood="grin", w=640, h=576):
    """Sly: a black mask across the eyes, his eyes on `look` (-1..1 across,
    down), and a cheeky grin (mood "grin") or a sly closed smirk ("smirk")."""
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    band = (0.18 * h, 0.52 * h)
    d.rectangle((0, band[0], w, band[1]), fill=CHARCOAL + (255,))
    d.line((0, band[0], w, band[0]), fill=(20, 20, 26, 255), width=6)
    d.line((0, band[1], w, band[1]), fill=(20, 20, 26, 255), width=6)
    for cx in (0.3 * w, 0.7 * w):
        eye(d, cx, 0.355 * h, 0.155 * w, 0.135 * h, look=look)
    if mood == "smirk":
        # half-lidded eyes (the mask's top edge drops over them) and a lopsided smile
        for cx in (0.3 * w, 0.7 * w):
            d.chord((cx - 0.17 * w, 0.2 * h, cx + 0.17 * w, 0.42 * h), 180, 360, fill=CHARCOAL + (255,))
            d.line((cx - 0.16 * w, 0.31 * h, cx + 0.16 * w, 0.31 * h), fill=(20, 20, 26, 255), width=8)
        # a lopsided smile: down from the left corner, up high on the right
        a, b, c = np.array([0.3 * w, 0.66 * h]), np.array([0.5 * w, 0.8 * h]), np.array([0.76 * w, 0.58 * h])
        pts = [tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c) for t in np.linspace(0, 1, 16)]
        d.line(pts, fill=(40, 20, 18, 255), width=18, joint="curve")
        d.line((0.74 * w, 0.54 * h, 0.79 * w, 0.62 * h), fill=(40, 20, 18, 255), width=10)  # (the dimple)
        for x in (0.16 * w, 0.86 * w):
            d.ellipse((x - 0.06 * w, 0.58 * h, x + 0.06 * w, 0.66 * h), fill=(240, 120, 110, 120))
        return as_tex(img)
    # the grin: wide, lopsided, teeth showing
    mouth = [(0.24 * w, 0.6 * h), (0.8 * w, 0.56 * h), (0.72 * w, 0.8 * h), (0.52 * w, 0.88 * h), (0.32 * w, 0.78 * h)]
    d.polygon(mouth, fill=(120, 30, 36, 255), outline=(40, 20, 18, 255), width=10)
    d.polygon([(0.27 * w, 0.607 * h), (0.77 * w, 0.567 * h), (0.75 * w, 0.65 * h), (0.3 * w, 0.68 * h)], fill=(255, 252, 240, 255))
    d.ellipse((0.42 * w, 0.73 * h, 0.62 * w, 0.85 * h), fill=(226, 92, 96, 255))
    for x in (0.16 * w, 0.86 * w):
        d.ellipse((x - 0.06 * w, 0.58 * h, x + 0.06 * w, 0.66 * h), fill=(240, 120, 110, 120))
    return as_tex(img)


def thief_head_side(w=576, h=576):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0.22 * h, w, 0.5 * h), fill=CHARCOAL + (255,))
    return img


def thief_head_back(w=640, h=576):
    img = thief_head_side(w, h)
    d = ImageDraw.Draw(img)
    # the mask's knot and its two tails
    cx = w / 2
    d.ellipse((cx - 40, 0.28 * h, cx + 40, 0.44 * h), fill=(30, 30, 38, 255))
    d.polygon([(cx - 20, 0.4 * h), (cx - 90, 0.72 * h), (cx - 40, 0.74 * h)], fill=(30, 30, 38, 255))
    d.polygon([(cx + 20, 0.4 * h), (cx + 80, 0.7 * h), (cx + 30, 0.74 * h)], fill=(30, 30, 38, 255))
    return img


def beanie_side(w=640, h=300):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0.58 * h, w, h), fill=(58, 58, 70, 255))
    for x in range(0, w, 24):
        d.line((x, 0.6 * h, x, h), fill=(34, 34, 42, 255), width=6)
    return img


def farmer_face(look=(-0.7, 0.1), mood="angry", w=640, h=576):
    """Farmer Hank: a big moustache, his eyes on `look`; mood "angry" (cross
    brows, shouting), "grit" (cross brows, teeth set) or "happy" (brows up,
    a big smile)."""
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    for cx in (0.31 * w, 0.69 * w):
        eye(d, cx, 0.37 * h, 0.13 * w, 0.13 * h, look=look)
    if mood == "happy":
        for sx in (-1, 1):  # brows arched up
            cx = w / 2 + sx * 0.19 * w
            d.arc((cx - 0.13 * w, 0.12 * h, cx + 0.13 * w, 0.3 * h), 200, 340, fill=(92, 56, 32, 255), width=22)
        d.chord((0.32 * w, 0.52 * h, 0.68 * w, 0.92 * h), 0, 180, fill=(110, 26, 32, 255), outline=(40, 20, 18, 255), width=8)
        d.rectangle((0.36 * w, 0.72 * h, 0.64 * w, 0.77 * h), fill=(255, 252, 240, 255))
        d.ellipse((0.43 * w, 0.8 * h, 0.57 * w, 0.9 * h), fill=(226, 92, 96, 255))
    else:
        # angry brows, down toward the middle
        d.polygon([(0.16 * w, 0.17 * h), (0.44 * w, 0.25 * h), (0.43 * w, 0.31 * h), (0.15 * w, 0.24 * h)], fill=(92, 56, 32, 255))
        d.polygon([(0.84 * w, 0.17 * h), (0.56 * w, 0.25 * h), (0.57 * w, 0.31 * h), (0.85 * w, 0.24 * h)], fill=(92, 56, 32, 255))
        if mood == "grit":
            d.rounded_rectangle((0.34 * w, 0.68 * h, 0.66 * w, 0.84 * h), 18, fill=(255, 252, 240, 255), outline=(40, 20, 18, 255), width=8)
            d.line((0.36 * w, 0.76 * h, 0.64 * w, 0.76 * h), fill=(40, 20, 18, 255), width=5)
            for x in (0.42, 0.5, 0.58):
                d.line((x * w, 0.69 * h, x * w, 0.83 * h), fill=(40, 20, 18, 255), width=4)
        else:
            # shouting mouth under the moustache
            d.ellipse((0.37 * w, 0.6 * h, 0.63 * w, 0.9 * h), fill=(110, 26, 32, 255), outline=(40, 20, 18, 255), width=8)
            d.ellipse((0.42 * w, 0.75 * h, 0.58 * w, 0.88 * h), fill=(226, 92, 96, 255))
    # the moustache: two bushy wings
    for sx in (-1, 1):
        pts = []
        for k in range(13):
            a = math.pi * k / 12
            pts.append((w / 2 + sx * (0.02 * w + 0.22 * w * (k / 12)), 0.58 * h - 0.07 * h * math.sin(a) + 0.04 * h * (k / 12) ** 2))
        pts += [(w / 2 + sx * 0.26 * w, 0.66 * h), (w / 2 + sx * 0.12 * w, 0.68 * h), (w / 2, 0.64 * h)]
        d.polygon(pts, fill=(120, 74, 40, 255), outline=(60, 36, 20, 255))
    d.ellipse((0.4 * w, 0.44 * h, 0.6 * w, 0.58 * h), fill=(236, 170, 140, 255))  # (the nose)
    for x in (0.2 * w, 0.8 * w):
        d.ellipse((x - 0.06 * w, 0.5 * h, x + 0.06 * w, 0.58 * h), fill=(240, 110, 100, 120))
    return as_tex(img)


def farmer_head_back(w=640, h=576):
    img = canvas(w, h)
    ImageDraw.Draw(img).rectangle((0, 0.3 * h, w, 0.72 * h), fill=(120, 80, 48, 255))
    return img


def farmer_head_side(back_at_right, w=576, h=576):
    """Hair at the back of the head and an ear in the middle. On the +x
    face the back is at the picture's right, on the -x face its left."""
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    hair = [(0.52 * w, 0.28 * h), (w, 0.28 * h), (w, 0.74 * h), (0.68 * w, 0.66 * h), (0.6 * w, 0.42 * h)]
    d.polygon(hair, fill=(120, 80, 48, 255))
    d.ellipse((0.36 * w, 0.4 * h, 0.54 * w, 0.66 * h), fill=(232, 176, 140, 255), outline=(190, 130, 100, 255), width=6)  # (the ear)
    return img if back_at_right else img.transpose(Image.FLIP_LEFT_RIGHT)


def overalls_front(w=640, h=640):
    img = plaid(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0.18 * w, 0.42 * h, 0.82 * w, h), fill=DENIM + (255,))
    d.rectangle((0, 0.82 * h, w, h), fill=DENIM + (255,))
    d.rectangle((0.32 * w, 0.55 * h, 0.68 * w, 0.72 * h), outline=DENIM_DARK + (255,), width=6)  # (the bib pocket)
    for x in (0.2 * w, 0.68 * w):
        d.rectangle((x, 0, x + 0.12 * w, 0.44 * h), fill=DENIM + (255,))
        d.ellipse((x + 0.01 * w, 0.4 * h, x + 0.11 * w, 0.5 * h), fill=(240, 196, 80, 255), outline=(150, 110, 40, 255), width=4)
    for y in (0.44 * h, 0.82 * h):
        d.line((0, y, w, y), fill=DENIM_DARK + (255,), width=4)
    return img


def overalls_back(w=640, h=640):
    img = plaid(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0.7 * h, w, h), fill=DENIM + (255,))
    d.polygon([(0.2 * w, 0), (0.34 * w, 0), (0.62 * w, 0.72 * h), (0.48 * w, 0.72 * h)], fill=DENIM + (255,))
    d.polygon([(0.8 * w, 0), (0.66 * w, 0), (0.38 * w, 0.72 * h), (0.52 * w, 0.72 * h)], fill=DENIM + (255,))
    return img


def overalls_side(w=320, h=640):
    img = plaid(w, h)
    ImageDraw.Draw(img).rectangle((0, 0.8 * h, w, h), fill=DENIM + (255,))
    return img


def sleeve(w, h, upto, kind):
    if kind == "stripes":
        return stripes(w, h, (250, 250, 246, 255), (34, 34, 42, 255), 6, upto)
    if isinstance(kind, tuple):  # (a plain shirt's)
        img = canvas(w, h)
        d = ImageDraw.Draw(img)
        d.rectangle((0, 0, w, h * upto), fill=kind + (255,))
        d.rectangle((0, h * upto - 0.07 * h, w, h * upto), fill=tuple(int(c * 0.78) for c in kind) + (255,))
        return img
    img = plaid(w, h, upto)
    d = ImageDraw.Draw(img)
    end = round(h * upto)
    d.rectangle((0, end - 0.12 * h, w, end), fill=(170, 40, 36, 255))  # (rolled up)
    return img


def jeans(w=320, h=640, colour=DENIM, dark=DENIM_DARK):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, h), fill=colour + (255,))
    d.line((w / 2, 0, w / 2, h), fill=dark + (255,), width=5)
    return img


def shopper_face(hair, look=(0.0, 0.0), mood="happy", w=640, h=576):
    """A shopper: hair across the top, round eyes on `look`, a smile (mood
    "happy") or a big open one ("delighted")."""
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, 0.16 * h), fill=hair + (255,))
    for cx in (0.31 * w, 0.69 * w):
        eye(d, cx, 0.42 * h, 0.125 * w, 0.135 * h, look=look)
    dark = tuple(int(c * 0.72) for c in hair) + (255,)
    for sx in (-1, 1):
        cx = w / 2 + sx * 0.19 * w
        d.arc((cx - 0.13 * w, 0.17 * h, cx + 0.13 * w, 0.34 * h), 205, 335, fill=dark, width=20)
    if mood == "delighted":
        d.chord((0.3 * w, 0.5 * h, 0.7 * w, 0.92 * h), 0, 180, fill=(110, 26, 32, 255), outline=(40, 20, 18, 255), width=8)
        d.rectangle((0.35 * w, 0.71 * h, 0.65 * w, 0.76 * h), fill=(255, 252, 240, 255))
        d.ellipse((0.42 * w, 0.8 * h, 0.58 * w, 0.9 * h), fill=(226, 92, 96, 255))
    else:
        d.arc((0.33 * w, 0.52 * h, 0.67 * w, 0.84 * h), 20, 160, fill=(40, 20, 18, 255), width=16)
    for x in (0.17 * w, 0.83 * w):
        d.ellipse((x - 0.07 * w, 0.58 * h, x + 0.07 * w, 0.67 * h), fill=(240, 110, 100, 120))
    return as_tex(img)


def shopper_head_back(hair, w=640, h=576):
    img = canvas(w, h)
    ImageDraw.Draw(img).rectangle((0, 0, w, 0.72 * h), fill=hair + (255,))
    return img


def shopper_head_side(hair, back_at_right, w=576, h=576):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (w, 0), (w, 0.74 * h), (0.68 * w, 0.68 * h), (0.6 * w, 0.3 * h), (0, 0.18 * h)], fill=hair + (255,))
    return img if back_at_right else img.transpose(Image.FLIP_LEFT_RIGHT)


def shirt(colour, side=False, w=640, h=640):
    """A plain shirt: a darker hem, and on the front a collar and a pocket."""
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    dark = tuple(int(c * 0.78) for c in colour) + (255,)
    d.rectangle((0, 0, w, h), fill=colour + (255,))
    d.rectangle((0, 0.88 * h, w, h), fill=dark)
    if not side:
        d.polygon([(0.32 * w, 0), (0.5 * w, 0.2 * h), (0.68 * w, 0)], fill=(250, 244, 230, 255), outline=dark, width=6)
        d.rectangle((0.6 * w, 0.42 * h, 0.82 * w, 0.62 * h), outline=dark, width=8)
    return img


# ---------------------------------------------------------------------------
# The characters


LOOKS = {
    "thief": dict(skin=SKIN_THIEF, legs=(52, 56, 72), shoes=(30, 30, 36), arms="stripes", arm_upto=0.72),
    "farmer": dict(skin=SKIN_FARMER, legs=DENIM, shoes=(108, 66, 36), arms="plaid", arm_upto=0.5),
}


def bat():
    """The plain bat (CrimeArt): a knob, the grip taped barn red, a long
    wooden barrel with a rounded end; along +Y from the knob."""
    wood, dark, tape = (222, 176, 112), (184, 136, 80), (200, 69, 45)
    m = Mesh()
    m.add(lathe([(-0.12, 0.0), (-0.1, 0.22), (0.05, 0.3), (0.16, 0.18)], 14, dark))
    m.add(lathe([(0.12, 0.16), (1.2, 0.16)], 14, tape))
    profile = [(1.2, 0.17), (1.9, 0.27), (2.6, 0.36), (3.3, 0.39)]
    for k in range(1, 6):
        a = math.pi / 2 * k / 5
        profile.append((3.3 + 0.39 * math.sin(a), 0.39 * math.cos(a)))
    m.add(lathe(profile, 16, wood))
    return m


def paddle(number):
    """A bidding paddle: a cream disc with a red number on a wooden handle,
    along +Y from the end of the handle, the number facing +Z. Returns the
    handle's mesh, the disc's mesh, the disc's frame and its picture."""
    handle = lathe([(0.0, 0.14), (1.5, 0.14)], 10, (150, 102, 58))
    disc = lathe([(-0.07, 0.95), (0.07, 0.95)], 28, (250, 240, 214))
    frame = mul(T(0, 2.3, 0), R("x", 90))  # (the disc's flat faces along ±Z)
    from PIL import ImageFont
    img = canvas(400, 400)
    d = ImageDraw.Draw(img)
    d.ellipse((6, 6, 394, 394), outline=(200, 69, 45, 255), width=26)
    font = ImageFont.truetype(_font("FredokaOne-Regular.ttf"), 230 if len(str(number)) < 2 else 190)
    box = d.textbbox((0, 0), str(number), font=font)
    d.text((200 - (box[0] + box[2]) / 2, 205 - (box[1] + box[3]) / 2), str(number), font=font, fill=(200, 69, 45, 255))
    tex = as_tex(img)
    return handle, disc, frame, {"+y": tex, "-y": tex[:, ::-1]}


def _font(name):
    import glob
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    return sorted(glob.glob(os.path.join(base, "*", "content", "fonts", name)), key=os.path.getmtime)[-1]


def crate_mesh():
    """A wooden crate of produce (the warehouse's), about 2.6 x 1.8 x 2."""
    m = Mesh()
    m.add(rounded_box((2.6, 1.6, 2.0), (196, 150, 96), 0.08, steps=2), T(0, 0.8, 0))
    for y in (0.35, 0.85, 1.35):  # slats
        m.add(rounded_box((2.66, 0.12, 2.06), (150, 104, 60), 0.04, steps=1), T(0, y, 0))
    for x in (-1.25, 1.25):
        for z in (-0.95, 0.95):
            m.add(rounded_box((0.18, 1.62, 0.18), (130, 88, 50), 0.05, steps=1), T(x, 0.8, z))
    return m


def basket_mesh():
    """A shopper's wicker basket: woven, oval, narrower at the foot, dark
    inside, its handle arching over; about 3 x 1.3 x 2.2, standing on y = 0."""
    light, dark, rim = (222, 176, 112), (176, 126, 72), (150, 104, 60)

    def weave(i, k, normal):
        return light if (i + k // 2) % 2 == 0 else dark

    squash = (1.0, 0.72)
    m = Mesh()
    wall = [(0.0, 1.05), (0.2, 1.14), (0.4, 1.22), (0.6, 1.3), (0.8, 1.36), (1.0, 1.42), (1.2, 1.47)]
    m.add(lathe(wall, 28, weave, squash=squash, cap=False))
    m.add(lathe([(1.14, 1.53), (1.32, 1.53), (1.33, 1.36)], 28, rim, squash=squash, cap=False))
    m.add(lathe([(1.0, 1.36), (1.25, 1.36)], 24, (84, 56, 34), squash=squash))
    for k in range(14):  # (the handle, in short lengths)
        a0, a1 = math.pi * k / 14, math.pi * (k + 1) / 14
        p0 = np.array([1.46 * math.cos(a0), 1.25 + 1.5 * math.sin(a0)])
        p1 = np.array([1.46 * math.cos(a1), 1.25 + 1.5 * math.sin(a1)])
        mid, along = (p0 + p1) / 2, p1 - p0
        turn = math.degrees(math.atan2(along[1], along[0]))
        m.add(rounded_box((np.linalg.norm(along) + 0.08, 0.17, 0.2), rim, 0.06, steps=1), mul(T(mid[0], mid[1], 0), R("z", turn)))
    return m


def piece(scene, name, m, longest, **part):
    """A crop's mesh standing on `m`, scaled to `longest` studs at its longest."""
    mesh = built_crop(name)
    lo, hi = mesh.bounds()
    k = longest / max(hi - lo)
    return scene.add_mesh(mesh, mul(m, np.diag([k] * 3 + [1]), T(-(lo[0] + hi[0]) / 2, -lo[1], -(lo[2] + hi[2]) / 2)), **part)


def coin_face(size=256):
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2
    d.ellipse((0, 0, size, size), fill=(250, 196, 62, 255))
    d.ellipse((size * 0.11, size * 0.11, size * 0.89, size * 0.89), outline=(198, 130, 30, 255), width=round(size * 0.05))
    pts = []
    for k in range(10):
        a = math.pi / 5 * k - math.pi / 2
        r = size * (0.27 if k % 2 == 0 else 0.12)
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=(255, 232, 140, 255), outline=(198, 130, 30, 255))
    return as_tex(img)


def coin(scene, at, tilt, turn, radius=0.8, **part):
    """A gold coin in the air, turned and tilted."""
    frame = mul(T(*at), R("y", turn), R("x", tilt), np.diag([radius] * 3 + [1]))
    disc = lathe([(-0.13, 1.0), (0.13, 1.0)], 28, (232, 164, 44))
    tex = coin_face()
    return scene.add_mesh(disc, frame, tex={"+y": tex, "-y": tex}, half=(1.0, 0.13, 1.0), **part)


def character(scene, kind, at, yaw, pose, held=None, face=None, paddle_no=7, hand="r", outfit=None, contents=()):
    """Adds a character to the scene; returns where things are (head top,
    hands, the bat's tip). pose: lean, head (yaw, pitch), arms
    (left, right): (swing, splay), legs (left, right): swing; degrees.
    face: the face's options (look, mood). held: "bat" or "paddle" (in
    `hand`), "crate" or "basket" (both hands, in front; a basket's
    `contents`: (crop mesh, x, y, z, longest, turn, roll), ...). A "shopper" wears
    `outfit`: skin, shirt, legs, shoes, hair and style ("short", "bun", "cap")."""
    look = LOOKS[kind] if kind != "shopper" else dict(outfit, arms=outfit["shirt"], arm_upto=0.42)
    anchors = {}
    face = face or {}
    lean = pose.get("lean", 0)
    lift = 2.0 * (1 - math.cos(math.radians(max(abs(s) for s in pose.get("legs", (0, 0))))))
    root = mul(T(*at), R("y", yaw), T(0, 2.0 - lift * 0.6, 0))
    torso = mul(root, R("x", lean), T(0, 1.0, 0))
    common = dict(outline=True, rim=0.32)

    # legs and shoes
    for side, swing in zip((-1, 1), pose.get("legs", (0, 0))):
        leg = mul(root, T(side * 0.5, 0, 0), R("x", swing), T(0, -1.0, 0))
        tex = {f: as_tex(jeans(colour=look["legs"], dark=tuple(int(c * 0.72) for c in look["legs"]))) for f in ("+z", "-z", "+x", "-x")}
        scene.add_mesh(rounded_box((0.96, 2.0, 0.96), look["legs"], 0.16), leg, tex=tex, half=(0.48, 1.0, 0.48), **common)
        scene.add_mesh(rounded_box((1.04, 0.42, 1.24), look["shoes"], 0.16), mul(leg, T(0, -0.86, 0.12)), **common)

    # the torso
    if kind == "thief":
        st = as_tex(stripes(640, 640, (250, 250, 246, 255), (34, 34, 42, 255), 7))
        tex = {"+z": st, "-z": st, "+x": st, "-x": st}
        colour = (250, 250, 246)
    elif kind == "shopper":
        plain = as_tex(shirt(look["shirt"], side=True))
        tex = {"+z": as_tex(shirt(look["shirt"])), "-z": plain, "+x": plain, "-x": plain}
        colour = look["shirt"]
    else:
        tex = {"+z": as_tex(overalls_front()), "-z": as_tex(overalls_back()), "+x": as_tex(overalls_side()), "-x": as_tex(overalls_side())}
        colour = (196, 52, 44)
    scene.add_mesh(rounded_box((2.0, 2.0, 1.05), colour, 0.16), torso, tex=tex, half=(1.0, 1.0, 0.525), **common)

    # arms
    hands = []
    for side, (swing, splay) in zip((-1, 1), pose.get("arms", ((0, 0), (0, 0)))):
        arm = mul(torso, T(side * 1.5, 0.75, 0), R("z", -side * splay), R("x", swing), T(0, -0.75, 0))
        sl = as_tex(sleeve(320, 640, look["arm_upto"], look["arms"]))
        tex = {"+z": sl, "-z": sl, "+x": sl, "-x": sl}
        scene.add_mesh(rounded_box((0.96, 2.0, 0.96), look["skin"], 0.2), arm, tex=tex, half=(0.48, 1.0, 0.48), **common)
        hands.append(arm)
        anchors["hand_l" if side < 0 else "hand_r"] = (arm @ np.array([0, -1.0, 0, 1]))[:3]

    # the head
    hy, hp = pose.get("head", (0, 0))
    head = mul(torso, T(0, 1.0, 0), R("y", hy), R("x", hp), T(0, 0.95, 0))
    if kind == "thief":
        side = as_tex(thief_head_side())
        tex = {"+z": thief_face(**face), "-z": as_tex(thief_head_back()), "+x": side, "-x": side}
    elif kind == "shopper":
        hair = look["hair"]
        tex = {"+z": shopper_face(hair, **face), "-z": as_tex(shopper_head_back(hair)),
               "+x": as_tex(shopper_head_side(hair, True)), "-x": as_tex(shopper_head_side(hair, False))}
    else:
        tex = {"+z": farmer_face(**face), "-z": as_tex(farmer_head_back()),
               "+x": as_tex(farmer_head_side(True)), "-x": as_tex(farmer_head_side(False))}
    scene.add_mesh(rounded_box((2.0, 1.8, 1.8), look["skin"], 0.42, steps=5), head, tex=tex, half=(1.0, 0.9, 0.9), **common)
    anchors["head"] = (head @ np.array([0, 0, 0, 1.0]))[:3]
    anchors["head_top"] = (head @ np.array([0, 0.9, 0, 1.0]))[:3]

    if kind == "thief":
        bs = as_tex(beanie_side())
        scene.add_mesh(rounded_box((2.12, 0.98, 1.92), CHARCOAL, 0.4), mul(head, T(0, 0.58, -0.02)),
                       tex={"+z": bs, "-z": bs, "+x": bs, "-x": bs}, half=(1.06, 0.49, 0.96), **common)
        anchors["head_top"] = (head @ np.array([0, 1.07, 0, 1.0]))[:3]
    elif kind == "shopper":
        scene.add_mesh(rounded_box((2.06, 0.44, 1.86), look["hair"], 0.2), mul(head, T(0, 0.74, -0.02)), **common)
        if look["style"] == "bun":
            ball = [(0.46 * -math.cos(math.pi * k / 10), 0.46 * math.sin(math.pi * k / 10)) for k in range(11)]
            scene.add_mesh(lathe(ball, 18, look["hair"]), mul(head, T(0, 1.26, -0.25)), **common)
        elif look["style"] == "cap":
            scene.add_mesh(rounded_box((2.2, 0.7, 2.0), look["cap"], 0.3), mul(head, T(0, 0.86, -0.02)), **common)
            scene.add_mesh(rounded_box((1.7, 0.14, 1.0), look["cap"], 0.06), mul(head, T(0, 0.62, 1.2), R("x", 8)), **common)
        anchors["head_top"] = (head @ np.array([0, 1.1, 0, 1.0]))[:3]
    else:
        hat = mul(head, T(0, 0.78, -0.05), R("x", -8))
        scene.add_mesh(lathe([(0.0, 0.0), (0.02, 1.95), (0.14, 2.0), (0.2, 1.7), (0.16, 0.0)], 28, (232, 192, 96)), hat, **common)
        scene.add_mesh(lathe([(0.1, 1.08), (0.6, 1.02), (0.9, 0.86), (1.02, 0.5), (1.06, 0.0)], 24, (226, 184, 86)), hat, **common)
        scene.add_mesh(lathe([(0.12, 1.1), (0.36, 1.08)], 24, (190, 48, 40)), hat, outline=True, rim=0.2)
        anchors["head_top"] = (hat @ np.array([0, 1.06, 0, 1.0]))[:3]

    arm = hands[1 if hand == "r" else 0]
    if held == "bat":
        grip = mul(arm, T(0, -1.0, 0), R("z", pose.get("bat_out", 0)), R("x", 180 + pose.get("bat", 0)), T(0, -0.7, 0))
        b = bat()
        scene.add_mesh(b, grip, **common)
        anchors["bat_tip"] = (grip @ np.array([0, 3.69, 0, 1.0]))[:3]
        anchors["bat_mid"] = (grip @ np.array([0, 2.6, 0, 1.0]))[:3]
    elif held == "paddle":
        grip = mul(arm, T(0, -1.0, 0), R("z", pose.get("paddle_out", 0)), R("x", 180 + pose.get("paddle", 0)), T(0, -0.5, 0))
        handle, disc, frame, tex = paddle(paddle_no)
        scene.add_mesh(handle, grip, **common)
        scene.add_mesh(disc, mul(grip, frame), tex=tex, half=(0.95, 0.07, 0.95), **common)
        anchors["paddle"] = (grip @ np.array([0, 2.3, 0, 1.0]))[:3]
    elif held == "crate":
        mid = (anchors["hand_l"] + anchors["hand_r"]) / 2
        place = mul(T(*mid), R("y", yaw), T(0, -0.6, -0.3))
        scene.add_mesh(crate_mesh(), place, **common)
        for dx, dz, turn in ((-0.6, -0.2, 20), (0.5, 0.3, 80), (0.0, -0.4, 140)):
            crop(scene, "CarrotTop", mul(place, T(dx, 1.3, dz), R("y", turn), np.diag([0.42] * 3 + [1])), outline=True, rim=0.2)
        anchors["crate"] = (place @ np.array([0, 0.8, 0, 1.0]))[:3]
    elif held == "basket":
        mid = (anchors["hand_l"] + anchors["hand_r"]) / 2
        place = mul(T(*mid), R("y", yaw), T(0, -0.8, 0.45))
        scene.add_mesh(basket_mesh(), place, **common)
        for name, x, y, z, longest, turn, roll in contents:
            at = mul(place, T(x, 1.15 + y, z), R("y", turn), R("z", roll))
            if name == "Carrot":  # (a whole one, standing in it, its leaves on)
                whole = mul(at, np.diag([longest] * 3 + [1]), T(0, 1.25, 0))
                crop(scene, "Carrot", whole, outline=True, rim=0.2)
                crop(scene, "CarrotTop", whole, outline=True, rim=0.2)
            else:
                piece(scene, name, at, longest, outline=True, rim=0.2)
    return anchors


def crop(scene, name, m, **part):
    return scene.add_mesh(built_crop(name), m, **part)


# ---------------------------------------------------------------------------
# The farm


def farm_parts():
    path = os.path.join(OUT, "farm.json")
    if not os.path.exists(path):
        os.makedirs(OUT, exist_ok=True)
        subprocess.run(["lune", "run", "tools/partdump", path, "5", "16"], cwd=ROOT, check=True)
    return partview.load(path)


def plant_field(scene, parts, rng, clear=()):
    """Ripe crops on the field's tiles: pumpkins, corn, carrots. Tiles
    within `clear` ((x, z, radius), ...) are left bare (where the
    characters run, and the camera)."""
    tiles = [p for p in parts if p["name"] == "Furrows"]
    for p in tiles:
        x, y, z = p["cframe"][:3]
        if any(math.dist((x, z), (cx, cz)) < r for cx, cz, r in clear):
            continue
        top = y + p["size"][1] / 2
        kind = ("pumpkin", "corn", "pumpkin", "carrot")[(int(x // 12) + int(z // 12)) % 4]
        if kind == "pumpkin":
            crop(scene, "PumpkinVine", mul(T(x, top, z), R("y", rng.uniform(0, 360))))
            for dx, dz in ((-1.8, -2.4), (1.9, 2.2)):
                crop(scene, "Pumpkin", mul(T(x + dx, top, z + dz), R("y", rng.uniform(0, 360)), np.diag([0.8] * 3 + [1])))
        elif kind == "corn":
            for dx, dz in ((-1.6, -2.4), (1.6, 0.0), (-1.4, 2.6)):
                crop(scene, "CornStalk", mul(T(x + dx, top, z + dz), R("y", rng.uniform(0, 360))))
        else:
            for dx in (-2.4, 0, 2.4):
                for dz in (-3.0, 0, 3.0):
                    crop(scene, "CarrotTop", mul(T(x + dx, top, z + dz), R("y", rng.uniform(0, 360))))


def add_farm(scene, parts, centre, radius):
    near = partview.clip(parts, (centre[0] - radius, -5, centre[1] - radius), (centre[0] + radius, 80, centre[1] + radius))
    tris, cols = partview.world_of(near)
    scene.add(tris, cols)
    # lawn out to the horizon round the farm
    ground = Mesh()
    for i in range(-12, 12):
        for j in range(-12, 12):
            x0, z0 = centre[0] + i * 20, centre[1] + j * 20
            ground.quad((x0, 0.0, z0), (x0 + 20, 0.0, z0), (x0 + 20, 0.0, z0 + 20), (x0, 0.0, z0 + 20), (118, 186, 84), out=(0, 1, 0))
    scene.add_mesh(ground, np.eye(4))


def lettered(p):
    """A part with its words on (partdump's `text`), for the scene: price
    tags and signs. Its mesh, its frame, its picture."""
    from PIL import ImageFont
    size = np.array(p["size"], dtype=float)
    frame = np.eye(4)
    frame[:3, :3] = np.array(p["cframe"][3:]).reshape(3, 3)
    frame[:3, 3] = p["cframe"][:3]
    w, h = max(64, round(size[0] * 120)), max(32, round(size[1] * 120))
    img = Image.new("RGBA", (w, h), tuple(round(c * 255) for c in p["color"]) + (255,))
    d = ImageDraw.Draw(img)
    ink = tuple(round(c * 255) for c in p["textColor"]) + (255,)
    font_file = "PatrickHand-Regular.ttf" if p.get("textFont") == "PatrickHand" else "FredokaOne-Regular.ttf"
    text = p["text"]
    icon = None
    if ord(text[0]) > 0x2000:  # (a price tag: its crop's emoji, then the price)
        icon, _, text = text.partition(" ")
    room_w, room_h = w * 0.88, h * 0.8
    if icon:
        room_w -= h * 0.95
    size_px = h
    while size_px > 8:
        font = ImageFont.truetype(_font(font_file), size_px)
        box = d.multiline_textbbox((0, 0), text, font=font, align="center")
        if box[2] - box[0] <= room_w and box[3] - box[1] <= room_h:
            break
        size_px -= 2
    tw = box[2] - box[0]
    left = (w - tw - (h * 0.95 if icon else 0)) / 2
    if icon:
        emoji = Image.new("RGBA", (136, 136), (0, 0, 0, 0))
        ImageDraw.Draw(emoji).text((0, 0), icon, font=ImageFont.truetype(r"C:\Windows\Fonts\seguiemj.ttf", 109), embedded_color=True)
        side = round(h * 0.84)
        emoji = emoji.resize((side, side), Image.LANCZOS)
        img.alpha_composite(emoji, (round(left), round((h - side) / 2)))
        left += h * 0.95
    d.multiline_text((left - box[0], (h - box[3] - box[1]) / 2), text, font=font, fill=ink, align="center")
    mesh = rounded_box(tuple(size), tuple(round(c * 255) for c in p["color"]), 0.01, steps=1)
    return mesh, frame, {"-z": as_tex(img)}


# ---------------------------------------------------------------------------
# 2D touches


def glow(img, centre, radius, colour=(255, 214, 90), strength=0.55):
    w, h = img.size
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    d.ellipse((centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius), fill=round(255 * strength))
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.45))
    add = Image.new("RGB", (w, h), colour)
    return Image.composite(add, img, layer)


def sparkle(d, cx, cy, r, colour=(255, 240, 170), edge=None):
    pts = []
    for k in range(8):
        a = math.pi / 4 * k - math.pi / 2
        rr = r if k % 2 == 0 else r * 0.28
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=colour, outline=edge)


def swoosh(img, points, width, colour=(255, 255, 255), alpha=200):
    """A curved motion streak through `points`, thick at the start, thin at the end."""
    w, h = img.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    n = len(points)
    for i in range(n - 1):
        t = i / (n - 1)
        d.line((points[i], points[i + 1]), fill=colour + (round(alpha * (1 - t * 0.7)),), width=max(1, round(width * (1 - t))))
    layer = layer.filter(ImageFilter.GaussianBlur(0.8))
    img.paste(layer, (0, 0), layer)


def drops(d, cx, cy, r, angle):
    """A sweat drop flying off: a teardrop whose point trails back toward
    the head (`angle`: the way it flies, degrees, 0 = right, 90 = up)."""
    a = math.radians(angle + 180)  # (the point trails behind)
    pts = []
    for k in range(25):
        t = 2 * math.pi * k / 24
        # a circle pulled out to a point on one side
        pull = max(0.0, math.cos(t)) ** 6 * 1.4
        rr = r * (1 + pull)
        x, y = rr * math.cos(t), rr * math.sin(t) * (1 - 0.35 * pull / 1.4)
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy - (x * math.sin(a) + y * math.cos(a))))
    d.polygon(pts, fill=(160, 216, 255), outline=(46, 30, 22), width=max(2, round(r * 0.22)))
    d.ellipse((cx - r * 0.45, cy - r * 0.55, cx - r * 0.05, cy - r * 0.15), fill=(240, 250, 255))


def grade(img, saturation=1.15, contrast=1.05, warm=0.04):
    from PIL import ImageEnhance
    img = ImageEnhance.Color(img).enhance(saturation)
    img = ImageEnhance.Contrast(img).enhance(contrast)
    a = np.asarray(img, dtype=float)
    a[..., 0] *= 1 + warm
    a[..., 2] *= 1 - warm
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


# ---------------------------------------------------------------------------
# The scenes


def chase(size, fov, eye, target, thief_at, farmer_at, dof=(26, 60, 4), seed=3, outline=3.0, thief_yaw=-30, farmer_yaw=-35, extras=(), bat_out=38):
    """The raid: Sly running at the camera with a pumpkin held up, Hank
    behind him with the bat raised, in the field with the barn and the
    farmhouse behind them."""
    rng = np.random.default_rng(seed)
    parts = farm_parts()
    scene = Scene()
    add_farm(scene, parts, (eye[0], eye[2] - 60), 110)
    plant_field(scene, parts, rng, clear=((eye[0], eye[2], 9.5), (thief_at[0], thief_at[2], 5), (farmer_at[0], farmer_at[2], 7)))
    thief = character(scene, "thief", thief_at, yaw=thief_yaw, held="pumpkin", pose=dict(
        lean=8, head=(22, 2), arms=((-178, 9), (-178, 9)), legs=(-38, 34)))
    # held up on his head, his hands at its sides (a Roblox character's
    # arms don't reach past the top of its head)
    hold = thief["head_top"]
    pumpkin_scale = 1.3
    base = hold[1] - 0.2
    crop(scene, "Pumpkin", mul(T(hold[0], base, hold[2]), R("y", 30), np.diag([pumpkin_scale] * 3 + [1])),
         outline=True, rim=0.35, glow=0.12)
    farmer = character(scene, "farmer", farmer_at, yaw=farmer_yaw, held="bat", pose=dict(
        lean=16, head=(16, 2), arms=((-70, 16), (-160, 12)), legs=(34, -36), bat=-35, bat_out=bat_out))
    for name, (x, y, z), turn, s in extras:  # (out-of-focus crops in front, framing the shot)
        crop(scene, name, mul(T(x, y, z), R("y", turn), np.diag([s] * 3 + [1])))
    shot = render(scene, eye, target, size, fov=fov, ss=2, sun=(-0.45, 0.78, 0.55),
                  sky=sky_gradient(clouds=((0.18, 0.16, 0.22), (0.78, 0.1, 0.18))),
                  shadow_at=thief_at, shadow_radius=24, outline=outline, dof=dof)
    img = grade(shot.image)
    w = img.size[0]
    middle = np.array([hold[0], base + 3.25 * pumpkin_scale * 0.5, hold[2]])
    pc = shot.at(middle)
    size_px = abs(shot.at(middle + shot.right * 1.85 * pumpkin_scale)[0] - pc[0])  # (its radius on screen)
    img = glow(img, pc, size_px * 1.5, strength=0.42)
    d = ImageDraw.Draw(img)
    for (ox, oy, s) in ((-0.95, -0.75, 0.24), (0.9, -0.6, 0.18), (1.12, 0.35, 0.14), (-1.1, 0.25, 0.15), (0.2, -1.05, 0.13)):
        sparkle(d, pc[0] + ox * size_px, pc[1] + oy * size_px, size_px * s, edge=(200, 150, 40))
    # Sly's sweat, flying off the sides of his head
    head, top = shot.at(thief["head"]), shot.at(thief["head_top"])
    hr = abs(top[1] - head[1])
    for dx, dy, a in ((-2.3, -1.0, 150), (2.35, -1.2, 30)):
        drops(d, head[0] + dx * hr, head[1] + dy * hr, hr * 0.14, a)
    # Hank's swing: two arcs round his hand, trailing the bat as it winds up
    hand, tip = np.array(shot.at(farmer["hand_r"])), np.array(shot.at(farmer["bat_tip"]))
    reach = np.linalg.norm(tip - hand)
    a0 = math.atan2(tip[1] - hand[1], tip[0] - hand[0])
    for scale, alpha in ((1.08, 210), (0.86, 150)):
        pts = []
        for k in range(12):
            a = a0 - math.radians(9 + 40 * k / 11)
            pts.append((hand[0] + math.cos(a) * reach * scale, hand[1] + math.sin(a) * reach * scale))
        swoosh(img, pts, max(3, reach * 0.07), alpha=alpha)
    return img, shot, dict(thief=thief, farmer=farmer, pumpkin=middle)


def prize(img, shot, centre, radius_studs, colour=(255, 214, 90), edge=(200, 150, 40), sparkles=None):
    """A glow behind something precious and sparkles round it."""
    pc = shot.at(centre)
    r = abs(shot.at(np.asarray(centre) + shot.right * radius_studs)[0] - pc[0])
    img = glow(img, pc, r * 1.5, colour=colour, strength=0.42)
    d = ImageDraw.Draw(img)
    for (ox, oy, s) in sparkles or ((-0.95, -0.75, 0.24), (0.9, -0.6, 0.18), (1.12, 0.35, 0.14), (-1.1, 0.25, 0.15), (0.2, -1.05, 0.13)):
        sparkle(d, pc[0] + ox * r, pc[1] + oy * r, r * s, edge=edge)
    return img


def farm_scene():
    """The farm: Hank in his field hoisting a giant carrot, proud, the barn
    and farmhouse behind him, and Sly peeking out of the corn."""
    rng = np.random.default_rng(5)
    parts = farm_parts()
    eye, target = (-33.6, 4.0, 182.0), (-40.0, 9.3, 140.0)  # (aimed up: the carrot clear of the title sign)
    hank_at, sly_at = (-38.0, 0.99, 162.0), (-27.6, 0.99, 150.0)
    scene = Scene()
    add_farm(scene, parts, (eye[0], eye[2] - 60), 110)
    plant_field(scene, parts, rng, clear=((eye[0], eye[2], 9.5), (hank_at[0], hank_at[2], 6)))
    hank = character(scene, "farmer", hank_at, yaw=-8, face=dict(look=(0.0, 0.0), mood="happy"), pose=dict(
        lean=-4, head=(0, 6), arms=((-178, 10), (-178, 10)), legs=(-10, 12)))
    # the carrot across his hands, over his head (leaves to his right)
    top = hank["head_top"]
    carrot = mul(T(top[0], top[1] + 0.95, top[2]), R("y", -8), R("z", 90), np.diag([2.4] * 3 + [1]), T(0, 1.25, 0))
    crop(scene, "Carrot", carrot, outline=True, rim=0.3, glow=0.1)
    crop(scene, "CarrotTop", carrot, outline=True, rim=0.3)
    sly = character(scene, "thief", sly_at, yaw=-30, face=dict(look=(-0.85, 0.05), mood="smirk"), pose=dict(
        lean=6, head=(-14, -4), arms=((-30, 4), (10, 4)), legs=(0, 0)))
    for x, z, turn in ((-28.8, 152.6, 40), (-26.0, 152.9, 160)):  # (the corn he's hiding in)
        crop(scene, "CornStalk", mul(T(x, 0.99, z), R("y", turn)))
    shot = render(scene, eye, target, (1920, 1080), fov=40, ss=2, sun=(-0.45, 0.78, 0.55),
                  sky=sky_gradient(clouds=((0.12, 0.12, 0.13), (0.86, 0.2, 0.11), (0.55, 0.06, 0.09))),
                  shadow_at=hank_at, shadow_radius=24, outline=3.0, dof=(30, 70, 4))
    img = grade(shot.image)
    middle = (carrot @ np.array([0, -1.25, 0, 1.0]))[:3]
    return prize(img, shot, middle, 3.2, sparkles=((-1.0, -0.6, 0.16), (1.05, -0.5, 0.13), (0.15, -0.95, 0.12), (-0.6, 0.55, 0.1)))


def auction_scene():
    """The Auction House: Sly and Hank bidding against each other for a
    Mythic pumpkin glowing on the pedestal, Goldie Gavel at the podium."""
    path = os.path.join(OUT, "auction.json")
    if not os.path.exists(path):
        subprocess.run(["lune", "run", "tools/partdump", path, "1", "4", "1", "auction"], cwd=ROOT, check=True)
    parts = [p for p in partview.load(path) if not p["name"].startswith("Lamp")]  # (the hanging lamps poke into the top corners)
    scene = Scene()
    tris, cols = partview.world_of(parts)
    scene.add(tris, cols)
    eye, target = (-1.8, 7.4, -3.5), (-0.8, 5.9, -26.0)  # (left and high: Goldie clear of Hank's hat)
    sly_at, hank_at = (-6.4, 0.8, -16.6), (4.9, 0.8, -16.6)
    sly = character(scene, "thief", sly_at, yaw=32, held="paddle", paddle_no=13, hand="r",
                    face=dict(look=(0.85, 0.0), mood="smirk"), pose=dict(
                        lean=-4, head=(18, 4), arms=((8, 6), (-168, 12)), legs=(4, -4), paddle=-8, paddle_out=-6))
    hank = character(scene, "farmer", hank_at, yaw=-32, held="paddle", paddle_no=7, hand="r",
                     face=dict(look=(-0.85, 0.0), mood="grit"), pose=dict(
                         lean=6, head=(-18, 2), arms=((8, 6), (-168, 12)), legs=(-4, 4), paddle=-8, paddle_out=-16))
    lot = (0.0, 5.75, -25.6)
    crop(scene, "DragonsEyePumpkin", mul(T(*lot), R("y", 200), np.diag([0.95] * 3 + [1])), outline=True, rim=0.4, glow=0.25)
    shot = render(scene, eye, target, (1920, 1080), fov=46, ss=2, sun=(0.25, 0.75, 0.6), light=1.05,
                  sky=lambda w, h: np.ones((h, w, 3)) * np.array([0.32, 0.2, 0.14]), shadow_at=None,
                  outline=3.0, dof=(19, 34, 3, 7.5))
    img = grade(shot.image)
    centre = np.array(lot) + np.array([0, 1.6, 0])
    img = prize(img, shot, centre, 2.2, colour=(200, 120, 255), edge=(120, 60, 170))
    return img


def trucks_scene():
    """The warehouse yard: Hank carrying a crate of carrots out between the
    semis, the Distribution Center's dock behind him."""
    path = os.path.join(OUT, "warehouse.json")
    if not os.path.exists(path):
        subprocess.run(["lune", "run", "tools/partdump", path, "5", "16", "1", "warehouse"], cwd=ROOT, check=True)
    parts = partview.load(path)
    eye, target = (12.0, 4.6, 1.5), (40.0, 6.2, 24.0)  # (the front corner: the red cabs in a row)
    hank_at = (21.3, 0.2, 16.8)
    scene = Scene()
    near = partview.clip(parts, (-60, -5, -60), (160, 80, 200))
    tris, cols = partview.world_of(near)
    scene.add(tris, cols)
    ground = Mesh()
    for i in range(-10, 12):
        for j in range(-6, 14):
            x0, z0 = i * 20, j * 20
            ground.quad((x0, 0.0, z0), (x0 + 20, 0.0, z0), (x0 + 20, 0.0, z0 + 20), (x0, 0.0, z0 + 20), (118, 186, 84), out=(0, 1, 0))
    scene.add_mesh(ground, np.eye(4))
    character(scene, "farmer", hank_at, yaw=-150, held="crate", face=dict(look=(0.0, 0.0), mood="happy"), pose=dict(
        lean=-3, head=(0, 2), arms=((-36, -6), (-36, -6)), legs=(26, -26)))
    for (x, z, y, turn) in ((38.0, 43.4, 0.8, 4), (40.9, 43.6, 0.8, -6), (39.4, 43.5, 2.45, 10), (49.5, 43.4, 0.8, 0)):
        place = mul(T(x, y, z), R("y", turn))
        scene.add_mesh(crate_mesh(), place)
        crop(scene, "CarrotTop", mul(place, T(0, 1.45, 0), np.diag([0.6] * 3 + [1])))
    shot = render(scene, eye, target, (1920, 1080), fov=44, ss=2, sun=(0.35, 0.8, -0.5),
                  sky=sky_gradient(clouds=((0.2, 0.1, 0.14), (0.75, 0.16, 0.12))),
                  shadow_at=hank_at, shadow_radius=40, outline=3.0, dof=(22, 60, 4))
    return grade(shot.image)


def store_scene(size=(1920, 1080), ss=2):
    """The Market Hall on a busy day: Hank beaming at the till, coins flying
    out of it, shoppers queueing along the belt with full baskets (Sly among
    them, buying like anyone else: only a farm's fields can be raided), the
    displays rising behind them to the chillers on the back wall. The
    camera's out past the front wall, on a long lens, so the produce fills
    the picture."""
    path = os.path.join(OUT, "store.json")
    if not os.path.exists(path):
        subprocess.run(["lune", "run", "tools/partdump", path, "5", "16", "1", "store"], cwd=ROOT, check=True)
    # (no roof: inside, the game fades it and the room's lit by the open sky)
    gone = {"Roof", "CeilingLamp", "StockroomRoof", "LanePole", "LaneLight"}
    parts = [p for p in partview.load(path) if p["name"] not in gone and p["cframe"][2] > 0.5 and p["transparency"] < 0.5]
    scene = Scene()
    walled = ("Wall", "Timber", "Glass", "Frame", "Sill", "Door", "Mullion")
    tris, cols = partview.world_of([p for p in parts if p["name"].startswith(walled) and not p.get("text")])
    scene.add(tris, cols, no_shadow=True)
    tris, cols = partview.world_of([p for p in parts if not p["name"].startswith(walled) and not p.get("text")])
    scene.add(tris, cols)
    for p in parts:
        if p.get("text"):
            mesh, frame, tex = lettered(p)
            scene.add_mesh(mesh, frame, tex=tex, half=tuple(np.array(p["size"]) / 2))

    floor = 0.6
    eye, target = (-54.5, 10.5, -8.0), (-53.6, 2.9, 22.0)
    character(scene, "farmer", (-48.9, floor, 13.4), yaw=-150, face=dict(look=(0.25, 0.1), mood="happy"), pose=dict(
        lean=-3, head=(10, 3), arms=((-150, 16), (-150, 16)), legs=(0, 0)))
    first = dict(skin=(240, 192, 150), shirt=(226, 84, 130), legs=(70, 66, 92), shoes=(90, 60, 40), hair=(84, 52, 38), style="bun")
    second = dict(skin=(150, 100, 70), shirt=(236, 176, 60), legs=(62, 84, 130), shoes=(50, 46, 50), hair=(40, 30, 26), style="cap", cap=(58, 112, 196))
    character(scene, "shopper", (-57.0, floor, 14.6), yaw=160, held="basket", outfit=first, face=dict(look=(-0.55, 0.0), mood="delighted"),
              contents=(("Watermelon", 0.45, -0.1, -0.28, 1.9, 75, 0), ("Lettuce", -0.62, 0.0, -0.3, 1.6, 60, 0),
                        ("Tomato", 0.72, -0.08, 0.28, 0.86, 80, 0), ("Tomato", 0.02, -0.06, 0.32, 0.9, 20, 0), ("BellPepper", -0.72, -0.05, 0.26, 0.9, 30, 0)),
              pose=dict(lean=2, head=(-16, 2), arms=((-46, -6), (-46, -6)), legs=(6, -6)))
    character(scene, "shopper", (-59.8, floor, 20.2), yaw=170, held="basket", outfit=second, face=dict(look=(-0.35, 0.0), mood="happy"),
              contents=(("Pumpkin", 0.0, -0.1, 0.0, 1.7, 30, 0),),
              pose=dict(lean=0, head=(-8, 2), arms=((-46, -6), (-46, -6)), legs=(0, 0)))
    character(scene, "thief", (-54.9, floor, 25.6), yaw=176, held="basket", face=dict(look=(-0.75, 0.1), mood="smirk"),
              contents=(("Carrot", 0.62, 0.12, -0.05, 0.5, 40, -18),),
              pose=dict(lean=0, head=(-22, 2), arms=((-46, -6), (-46, -6)), legs=(0, 0)))
    till = np.array([-52.4, floor + 4.6, 13.8])
    coins = ((0.0, 0.8, 0.0, 62, 200, 0.46), (0.6, 1.5, 0.3, 40, 150, 0.48), (-0.5, 1.9, -0.5, 50, 215, 0.5), (1.0, 2.2, -0.4, 28, 190, 0.54), (0.2, 2.8, 0.2, 58, 150, 0.5),
             (1.75, 3.45, 0.2, 34, 220, 0.54), (-0.8, 3.2, 0.4, 46, 170, 0.56), (1.0, 3.5, -0.6, 62, 205, 0.58), (2.7, 3.6, -0.4, 44, 160, 0.54))
    for right, up, near, tilt, turn, r in coins:  # (out of the till, up between Hank and the queue)
        coin(scene, till + np.array([-right, up, near]), tilt, turn, radius=r, outline=True, rim=0.3, glow=0.12)
    shot = render(scene, eye, target, size, fov=25, ss=ss, sun=(0.32, 0.74, -0.55), sky=sky_gradient(),
                  shadow_at=(-53.0, 3.0, 16.0), shadow_radius=26, outline=3.0 * size[0] / 1920, dof=(30, 54, 2.5 * size[0] / 1920))
    img = grade(shot.image)
    d = ImageDraw.Draw(img)
    k = size[0] / 1920
    for x, y, r in ((655, 235, 34), (1215, 150, 28), (780, 85, 22), (1010, 60, 20)):
        sparkle(d, x * k, y * k, r * k, edge=(200, 150, 40))
    return img


def lawn(scene, centre, size=20, count=12):
    """Grass out to the horizon round `centre` (x, z)."""
    ground = Mesh()
    for i in range(-count, count):
        for j in range(-count, count):
            x0, z0 = centre[0] + i * size, centre[1] + j * size
            ground.quad((x0, 0.0, z0), (x0 + size, 0.0, z0), (x0 + size, 0.0, z0 + size), (x0, 0.0, z0 + size), (118, 186, 84), out=(0, 1, 0))
    scene.add_mesh(ground, np.eye(4))


def pass_vip_scene(size=(1024, 1024), ss=2):
    """The VIP pass: Hank with his arms out in front of his VIP Gold semi,
    coins coming down round him (compose.py puts the gold VIP tag over his
    head, as in the game). Roblox shows a pass as a circle: everything that
    matters stays inside it."""
    path = os.path.join(OUT, "warehouse.json")
    if not os.path.exists(path):
        subprocess.run(["lune", "run", "tools/partdump", path, "5", "16", "1", "warehouse"], cwd=ROOT, check=True)
    fence = ("Picket", "PicketTip", "Rail", "Post", "PostCap", "GatePost", "Gate", "Lever", "Knob")
    parts = [p for p in partview.clip(partview.load(path), (-60, -5, -30), (160, 80, 200)) if not (p["name"].startswith(fence) and p["cframe"][2] < 3) and p["name"] != "Stripe"]
    farm_paint, vip_gold = np.array([232, 83, 63]) / 255, [236 / 255, 168 / 255, 36 / 255]  # (Cosmetics' VIPGold)
    for p in parts:
        if np.abs(np.array(p["color"]) - farm_paint).max() < 0.01:
            p["color"] = vip_gold
    scene = Scene()
    tris, cols = partview.world_of(parts)
    scene.add(tris, cols)
    lawn(scene, (40, 20))
    eye, target = np.array([20.5, 3.4, -10.5]), np.array([30.2, 5.8, 8.0])
    hank_at = (26.3, 0.2, 0.6)
    character(scene, "farmer", hank_at, yaw=-152, face=dict(look=(0.0, 0.0), mood="happy"), pose=dict(
        lean=-3, head=(0, 3), arms=((-128, 26), (-128, 26)), legs=(0, 0)))
    forward = unit(target - eye)
    right = unit(np.cross(forward, [0, 1, 0]))
    head = np.array([hank_at[0], 6.0, hank_at[2]])
    for dx, dy, near, tilt, turn, r in ((-3.3, 0.8, 1.2, 66, -176, 0.52), (3.5, 1.0, 1.0, 58, -120, 0.54), (-3.0, -1.5, 2.0, 54, -130, 0.46), (3.2, -1.3, 2.0, 70, -168, 0.46)):
        coin(scene, head + right * dx + np.array([0, dy, 0]) - forward * near, tilt, turn, radius=r, outline=True, rim=0.3, glow=0.12)
    shot = render(scene, tuple(eye), tuple(target), size, fov=38, ss=ss, sun=(-0.34, 0.76, -0.55), sky=sky_gradient(clouds=((0.14, 0.26, 0.18),)),
                  shadow_at=hank_at, shadow_radius=30, outline=4.0 * size[0] / 1024, dof=(17, 44, 3 * size[0] / 1024))
    img = grade(shot.image, saturation=1.2, warm=0.05)
    d = ImageDraw.Draw(img)
    k = size[0] / 1024
    for x, y, r in ((838, 300, 40), (196, 330, 32), (790, 430, 24)):  # (the paint's shine)
        sparkle(d, x * k, y * k, r * k, edge=(200, 150, 40))
    return img


def pass_barn_scene(size=(1024, 1024), ss=2):
    """The Bigger Barn pass: the barn's doors slid open on more crops than
    it can hold, heaped out of the doorway and the hayloft. Roblox shows a
    pass as a circle: everything that matters stays inside it."""
    parts = partview.clip(farm_parts(), (-110, -5, 60), (-51.8, 80, 125))
    parts = [p for p in parts if p["name"] not in ("LoftDoor", "HayBale", "Wheelbarrow", "SteppingStone")]
    for p in parts:  # (the doors, slid along their track)
        if p["name"] in ("DoorLeaf", "DoorBrace"):
            p["cframe"][0] += 5.0 if p["cframe"][0] > -61 else -5.0
    scene = Scene()
    tris, cols = partview.world_of(parts)
    scene.add(tris, cols)
    lawn(scene, (-61, 130))
    dark = (46, 30, 22)
    scene.add_mesh(rounded_box((10.2, 7.9, 0.1), dark, 0.02, steps=1), T(-61.0, 4.75, 112.16))
    scene.add_mesh(rounded_box((3.8, 3.4, 0.1), dark, 0.02, steps=1), T(-61.0, 12.7, 112.16))

    rng = np.random.default_rng(11)
    big = (("Pumpkin", 3.3), ("Watermelon", 3.5), ("Pumpkin", 3.0), ("Watermelon", 3.2), ("Pumpkin", 3.4))
    kinds = big + (("CornCob", 2.6), ("Tomato", 1.9), ("BellPepper", 1.9), ("Lettuce", 2.6), ("Tomato", 2.0))
    sticker = dict(outline=True, rim=0.2)
    # a mound against the doors: each layer sits inside the one under it, and
    # the top ones fill the doorway to the lintel
    layers = ((0.0, 12.5, 10.5), (1.6, 10.0, 7.5), (3.2, 7.0, 5.0), (4.8, 5.2, 3.0), (6.2, 3.6, 1.6))
    for y, half, depth in layers:
        across = max(2, round(2 * half / 2.9))
        out = max(1, round(depth / 2.9))
        for i in range(across + 1):
            for j in range(out):
                t = i / across * 2 - 1
                x = -61.0 + t * half + rng.uniform(-0.4, 0.4)
                z = 112.7 + (j + rng.uniform(0.1, 0.7)) / out * depth * (1 - 0.55 * t * t)
                some = kinds if y < 3 else big
                name, longest = some[int(rng.integers(0, len(some)))]
                piece(scene, name, mul(T(x, y, z), R("y", rng.uniform(0, 360))), longest, **sticker)
    # the hayloft, full to its sill (half in the opening)
    for x, y, name, longest in ((-62.3, 11.0, "Pumpkin", 2.3), (-59.7, 11.0, "Watermelon", 2.5), (-61.0, 11.0, "Tomato", 1.7), (-61.0, 12.7, "Pumpkin", 2.0)):
        piece(scene, name, mul(T(x, y, 112.5), R("y", rng.uniform(0, 360))), longest, **sticker)
    eye, target = (-61.0, 5.0, 150.0), (-61.0, 9.6, 104.0)
    shot = render(scene, eye, target, size, fov=33, ss=ss, sun=(-0.4, 0.74, 0.54), sky=sky_gradient(clouds=((0.12, 0.2, 0.2), (0.86, 0.14, 0.17))),
                  shadow_at=(-61.0, 4.0, 116.0), shadow_radius=30, outline=4.0 * size[0] / 1024, dof=None)
    return grade(shot.image, saturation=1.2)


SCENES = {
    # the icon: close and low, the two of them filling the square
    # (all inside one block of the field, so no frame beam crosses the front)
    "icon": lambda: chase((1024, 1024), 40, eye=(-14.0, 3.0, 236.0), target=(-14.0, 6.9, 216.0),
                          thief_at=(-16.1, 0.99, 222.0), farmer_at=(-9.6, 0.99, 214.5), dof=(16, 42, 5), outline=4.0,
                          bat_out=28)[0],
    # the raid thumbnail: wider, the farmhouse behind; room at the top for its board
    # (the camera just inside the field's back beam, the two of them in the same block)
    "raid": lambda: chase((1920, 1080), 48, eye=(-12.5, 3.3, 233.5), target=(-12.5, 8.9, 213.5),
                          thief_at=(-15.0, 0.99, 218.0), farmer_at=(-6.8, 0.99, 211.0), dof=(22, 50, 5), bat_out=30)[0],
    "farm": farm_scene,
    "store": store_scene,
    "auction": auction_scene,
    "trucks": trucks_scene,
    # the game passes' pictures
    "pass_vip": pass_vip_scene,
    "pass_barn": pass_barn_scene,
}


def main(argv):
    os.makedirs(OUT, exist_ok=True)
    for name in argv or list(SCENES):
        if name not in SCENES:
            print("Not a scene:", name)
            continue
        img = SCENES[name]()
        path = os.path.join(OUT, f"{name}.png")
        img.save(path)
        print(f"  {name}.png  {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main(sys.argv[1:])
