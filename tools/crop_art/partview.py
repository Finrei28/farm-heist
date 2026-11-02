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
}


def shoot(parts, view, size=(960, 600)):
    eye, target, lo, hi = VIEWS[view]
    figure_mesh = figure(np.array([[1, 0, 0, -20], [0, 1, 0, 0.4], [0, 0, 1, 93], [0, 0, 0, 1.0]]))
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
