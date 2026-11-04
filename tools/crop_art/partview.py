"""Renders a farm as the server builds it (tools/partdump.luau's JSON, in
plot space: x across, z from the front to the back fence) with the real
meshes in place of their stand-ins, to judge buildings by eye before
Studio.

    lune run tools/partdump scratch.json
    python tools/crop_art/partview.py scratch.json out.png [view ...]
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import shelves  # noqa: F401,E402  (registers the punnets)
import defences  # noqa: F401,E402  (registers the defences)
import town  # noqa: F401,E402  (registers the town's meshes)
import valley  # noqa: F401,E402  (registers the valley's meshes)
from crops import MESHES, built as built_crop  # noqa: E402
from meshkit import box, lathe, Mesh  # noqa: E402
from palette import PROP_COLOURS  # noqa: E402
from props import PROPS, built as built_prop  # noqa: E402
from render import render  # noqa: E402
from scene import figure  # noqa: E402

UNIT_BOX = box((1.0, 1.0, 1.0), "x").array()


def _wedge():
    # Roblox's WedgePart: a box's bottom, its back (+Z) face standing, the
    # slope down to the front (-Z) edge of the bottom
    a, b, c, d = (-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5)
    e, f = (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5)
    m = Mesh()
    m.quad(a, b, c, d, "x", out=(0, -1, 0))
    m.quad(d, c, f, e, "x", out=(0, 0, 1))
    m.quad(a, b, f, e, "x", out=(0, 1, -1))
    m.tri(a, d, e, "x", out=(-1, 0, 0))
    m.tri(b, c, f, "x", out=(1, 0, 0))
    return m.array()


UNIT_WEDGE = _wedge()
UNIT_CYL = lathe([(-0.5, 0.5), (0.5, 0.5)], 14, "x").array()[:, :, [1, 0, 2]] * [1, -1, 1]  # (turned to lie along X)
_ball = __import__("meshkit").blob((0.5, 0.5, 0.5), "x", sub=1).array()
UNIT_BALL = _ball


def mesh_of(name):
    if name in PROPS:
        return built_prop(name)
    if name in MESHES:
        return built_crop(name)
    return None


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def split(tris, longest=5.0):
    """Big triangles cut into small ones (the renderer drops a triangle that
    reaches behind the camera, so a lawn needs to be in pieces)."""
    out = []
    todo = list(tris)
    while todo:
        t = todo.pop()
        edges = [np.linalg.norm(t[1] - t[0]), np.linalg.norm(t[2] - t[1]), np.linalg.norm(t[0] - t[2])]
        if max(edges) <= longest:
            out.append(t)
            continue
        a, b, c = t
        ab, bc, ca = (a + b) / 2, (b + c) / 2, (c + a) / 2
        todo += [np.array([a, ab, ca]), np.array([ab, b, bc]), np.array([ca, bc, c]), np.array([ab, bc, ca])]
    return np.array(out)


def world_of(parts, extra=None):
    tris, cols = [], []
    for p in parts:
        size = np.array(p["size"])
        c = p["cframe"]
        pos = np.array(c[:3])
        rot = np.array(c[3:]).reshape(3, 3)
        colour = np.array(p["color"])
        if p.get("neon"):
            colour = np.minimum(1, colour * 1.25 + 0.15)
        if p["class"] == "MeshPart":
            m = mesh_of(p["name"])
            if m is None:
                continue
            t = m.array()
            lo, hi = m.bounds()
            local = (t - (lo + hi) / 2) * (size / np.maximum(hi - lo, 1e-6))
            world = local @ rot.T + pos
            tris.append(world)
            pal = np.array([np.array(PROP_COLOURS.get(cn, (255, 0, 255))) / 255 for cn in m.cols])
            if MESHES.get(p["name"], PROPS.get(p["name"], {})).get("textured") is False:
                pal[:] = colour
            cols.append(pal)
            continue
        shape = p.get("shape", "Block")
        if p["class"] == "WedgePart" or shape == "Wedge":
            unit = UNIT_WEDGE
        elif shape == "Cylinder":
            d = min(size[1], size[2])
            size = np.array([size[0], d, d])
            unit = UNIT_CYL
        elif shape == "Ball":
            size = np.array([size[0]] * 3)
            unit = UNIT_BALL
        elif shape == "Ellipsoid":
            unit = UNIT_BALL
        else:
            unit = UNIT_BOX
        world = (unit * size) @ rot.T + pos
        if size.max() > 5:
            world = split(world)
        tris.append(world)
        cols.append(np.repeat(colour[None, :], len(world), axis=0))
    if extra is not None:
        tris.append(extra.array())
        cols.append(np.array([np.array(PROP_COLOURS.get(cn, (255, 0, 255))) / 255 for cn in extra.cols]))
    return np.concatenate(tris), np.concatenate(cols)


def clip(parts, lo, hi):
    """Only parts whose middle is inside the box (plot space)."""
    lo, hi = np.array(lo), np.array(hi)
    return [p for p in parts if np.all(np.array(p["cframe"][:3]) >= lo) and np.all(np.array(p["cframe"][:3]) <= hi)]


VIEWS = {
    # name: (eye, target, region lo, region hi)
    # the bat and its skins (partdump ... bats)
    "bats": ((6.25, 4.2, -9), (6.25, 3.2, 0), (-5, -5, -5), (20, 10, 5)),
    "gate": ((-6, 6, 30), (-45, 8, 92), (-110, -2, 20), (20, 40, 170)),
    "door": ((-14, 7, 108), (-45, 7, 88), (-110, -2, 40), (20, 40, 170)),
    "field": ((-30, 8, 150), (-55, 8, 100), (-110, -2, 60), (20, 40, 200)),
    "above": ((10, 70, 40), (-48, 0, 100), (-110, -2, 40), (40, 40, 200)),
    "porch": ((-22, 6, 84), (-34, 4, 96), (-80, -2, 70), (0, 40, 125)),
    "barnend": ((-48, 10, 130), (-62, 9, 108), (-100, -2, 60), (0, 40, 160)),
    "road": ((-60, 12, -40), (-50, 6, 80), (-120, -2, -10), (20, 40, 170)),
    "fieldview": ((-20, 6, 93), (-50, 2, 170), (-110, -2, 60), (40, 40, 252)),
    # the defences (partdump ... defences)
    "gateroad": ((-14, 7, -26), (-2, 4, 4), (-60, -2, -40), (40, 40, 30)),
    "gateyard": ((-6, 8, 32), (8, 4, 6), (-18, -2, -20), (40, 40, 60)),
    "gatehouse": ((-6, 7, 26), (10, 4, 8), (-16, -2, -20), (40, 40, 60)),
    "gateopen": ((6, 9, 30), (-5, 3, 2), (-30, -2, -20), (30, 40, 60)),
    "gatetop": ((-16, 32, -18), (4, 0, 8), (-30, -2, -30), (40, 40, 60)),
    "hutroad": ((22, 7, -16), (10, 5, 8), (-16, -2, -30), (40, 40, 60)),
    "backyard": ((-70, 16, 196), (2, 1, 243), (-110, -2, 130), (110, 40, 256)),
    "kennel": ((-16, 6, 226), (-6, 2, 244), (-40, -2, 210), (30, 40, 256)),
    "scarecrow": ((-40, 7, 166), (-57, 4, 180), (-90, -2, 140), (-20, 40, 220)),
    "cloches": ((-22, 10, 128), (-36, 2, 152), (-80, -2, 120), (20, 40, 200)),
    "camera": ((-44, 10, 126), (-53, 9, 113), (-80, -2, 100), (-20, 40, 140)),
    "trail": ((-14, 7, 280), (0, 5, 250), (-60, -2, 220), (60, 40, 300)),
    # the Auction House (partdump ... auction: the hall's frame, +Z to the square)
    "hallfront": ((-14, 9, 44), (0, 11, -12), (-60, -2, -60), (60, 60, 60), (4, 0.6, 3)),
    "hallside": ((48, 14, 18), (0, 12, -17), (-60, -2, -60), (60, 60, 60), (4, 0.6, 3)),
    "hallabove": ((34, 52, 34), (0, 16, -17), (-60, -2, -60), (60, 60, 60), (4, 0.6, 3)),
    "hallin": ((-4, 7, -3), (2, 7, -30), (-25, -2, -36), (25, 15.5, 2), (-1, 0.6, -6)),
    "hallstage": ((-14, 8, -14), (6, 6, -29), (-25, -2, -36), (25, 15.5, 2), (-6, 0.6, -21)),
    "goldie": ((5, 8, -18), (9, 7, -29), (-25, -2, -36), (25, 15.5, 2), (2, 3.2, -26)),
    "belltower": ((10, 33, 6), (0, 29, -5.5), (-60, 20, -60), (60, 60, 60), (4, 0.6, 3)),
    # the town (partdump ... town: world space, north +Z, the spawn at (0, -30))
    "spawn": ((13.2, 8, -38), (0, 16, 96), (-200, -2, -60), (200, 90, 200), (12, 0.55, -26)),
    "plaza": ((-46, 34, -78), (0, 8, 10), (-170, -2, -170), (170, 90, 170), (0, 0.55, -30)),
    "townabove": ((0, 300, -230), (0, 0, 10), (-320, -2, -320), (320, 90, 320), (0, 0.55, -30)),
    "fountain": ((-13, 6, -22), (0, 4, 0), (-60, -2, -60), (60, 90, 60), (-4, 0.4, -13)),
    "tower": ((16, 24, -30), (0, 34, 0), (-60, -2, -60), (60, 90, 60), (0, 0.55, -30)),
    "seeds": ((-49, 7, 24), (-100, 9, 32), (-160, -2, -40), (-30, 60, 100), (-90, 0.3, 26)),
    "barley": ((-82, 6, 24), (-97, 5, 31), (-130, -2, 0), (-60, 40, 70), (-86, 0.3, 26)),
    "hiring": ((29, 7, -50), (61, 8, -84), (0, -2, -140), (120, 60, -20), (52, 0.3, -70)),
    "patty": ((44, 6, -66), (52, 6, -82), (20, -2, -110), (90, 40, -40), (48, 0.3, -72)),
    "exchange": ((-16, 9, 60), (0, 24, 110), (-60, -2, 30), (60, 90, 160), (-6, 0.3, 90)),
    "elevator": ((40, 30, 60), (0, 40, 120), (-60, -2, 30), (60, 90, 160), (0, 0.3, 92)),
    "signpost": ((72, 6, 126), (60, 6, 150), (20, -2, 100), (110, 40, 190), (66, 0.12, 140)),
    "green": ((0, 10, -170), (-60, 6, -260), (-200, -2, -320), (200, 60, -150), (0, 0, -180)),
    "exboards": ((0, 12, 28), (0, 8, 85), (-60, -2, 60), (60, 60, 130), (-14, 0.12, 80)),
    "exboard": ((-14, 7, 64), (-21, 8, 83), (-60, -2, 60), (60, 60, 130), (-17, 0.12, 78)),
    "policeboards": ((-17.7, 12, -24.3), (-48.8, 8, -67.2), (-110, -2, -120), (10, 60, -20), (-36, 0.12, -60)),
    # the valley (partdump ... valley: world space)
    "tunnel": ((-20, 14, 560), (0, 16, 662), (-120, -2, 520), (120, 80, 740), (0, 0.42, 640)),
    "woods": ((236.9, 14, 236.9), (339.4, 6, 339.4), (180, -2, 180), (460, 60, 460), (251, 0, 251)),
    "trail": ((620.4, 9, 109.4), (595.6, 2, -20.8), (520, -2, -120), (680, 60, 180), (598.5, 0.3, 41.9)),
    "crossing": ((48.6, 12, 275.8), (113.9, 0, 281.9), (0, -2, 200), (200, 40, 360), (109.2, 0.36, 274.4)),
    "hedge": ((233.3, 6, 314.6), (268.1, 5, 354.3), (180, -2, 260), (320, 40, 420), (240, 0.2, 330)),
    "valleyabove": ((260, 220, 120), (330, 0, 330), (100, -2, 100), (700, 80, 700), (251, 0, 251)),
}


def shoot(parts, view, size=(960, 600)):
    eye, target, lo, hi = VIEWS[view][:4]
    at = VIEWS[view][4] if len(VIEWS[view]) > 4 else (-20, 0.4, 93)  # (a figure for scale)
    figure_mesh = figure(np.array([[1, 0, 0, at[0]], [0, 1, 0, at[1]], [0, 0, 1, at[2]], [0, 0, 0, 1.0]]))
    tris, cols = world_of(clip(parts, lo, hi), figure_mesh)
    return render(tris, cols, np.array(eye, dtype=float), np.array(target, dtype=float), size=size, ss=2)


if __name__ == "__main__":
    from PIL import Image, ImageDraw
    src, out = sys.argv[1], sys.argv[2]
    views = sys.argv[3:] or ["gate", "door", "field", "above"]
    parts = load(src)
    shots = [shoot(parts, v, size=(720, 450)) for v in views]
    cols = 2 if len(shots) > 1 else 1
    rows = math.ceil(len(shots) / cols)
    w, h = shots[0].size
    sheet = Image.new("RGB", (w * cols, h * rows), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (v, im) in enumerate(zip(views, shots)):
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
        draw.text(((i % cols) * w + 8, (i // cols) * h + 6), v, fill=(20, 20, 20))
    sheet.save(out)
    print(out)
