"""Previews of the props to judge by eye before Studio: each prop beside a
figure for scale, and an overgrown block as the game lays it out beside a
tilled tile of ripe crops, from close by, from the farmhouse and above."""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

from crops import PATCHES, built as built_crop
from meshkit import Mesh, Palette, T, box, mul
from palette import PROP_COLOURS
from props import PROPS, built
from render import render
from scene import figure, lawn, tile
from wild import GRASS, OBSTACLES

PALETTE = Palette(dict(PROP_COLOURS, overgrown=(108, 154, 68)))


def mesh_of(name):
    return built(name) if name in PROPS else built_crop(name)


def scaled(m, s):
    sx, sy, sz = s if isinstance(s, tuple) else (s, s, s)
    return m @ np.diag([sx, sy, sz, 1.0])


def shot(world, eye, target, size=(720, 450), ss=2):
    cols = np.array([np.array(PALETTE.rgb(c)) / 255 for c in world.cols])
    return render(world.array(), cols, eye, target, size=size, ss=ss)


def sheet(images, cols, path, labels=None):
    w, h = images[0].size
    rows = math.ceil(len(images) / cols)
    out = Image.new("RGB", (w * cols, h * rows), (255, 255, 255))
    draw = ImageDraw.Draw(out)
    for i, im in enumerate(images):
        x, y = (i % cols) * w, (i // cols) * h
        out.paste(im, (x, y))
        if labels:
            draw.text((x + 8, y + 6), labels[i], fill=(20, 20, 20))
    out.save(path)
    return path


def prop_sheet(path, names=None):
    names = names or list(PROPS)
    images = []
    for name in names:
        m = built(name)
        lo, hi = m.bounds()
        span = max(hi - lo)
        world = Mesh()
        world.add(lawn(half=max(8.0, span * 2), step=1.0))
        world.add(m)
        world.add(figure(T(lo[0] - 2.2, 0, 0)))
        eye = np.array([span * 0.9 + 3, max(hi[1], 5.2) * 0.9 + 1.5, -(span * 1.4 + 4)])
        images.append(shot(world, eye, np.array([0, hi[1] * 0.45, 0]), size=(480, 340)))
    return sheet(images, 4, path, names)


def overgrown_block(at, block=1):
    """An overgrown block (2 x 2 tiles) as FarmArt lays it out, centred on `at`."""
    world = Mesh()
    kinds = list(OBSTACLES)
    for k, (dx, dz) in enumerate(((-6, -6), (6, -6), (-6, 6), (6, 6))):
        world.add(box((11.4, 0.4, 11.4), "overgrown"), mul(at, T(dx, 0.3, dz)))
        turn = mul(at, T(dx, 0.5, dz), np.array(rot_y(block * 0.9 + k + 1)))
        for name, m, s in OBSTACLES[kinds[k]]:
            world.add(mesh_of(name), turn @ scaled(m, s))
    spin = np.array(rot_y(block * math.pi / 2))
    for name, m, s in GRASS:
        world.add(mesh_of(name), mul(at, T(0, 0.5, 0), spin) @ scaled(m, s))
    return world


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]


def overgrowth_preview(path):
    world = Mesh()
    world.add(lawn(half=40.0, step=2.0, y=0.0))
    world.add(overgrown_block(T(0, 0, 0)))
    world.add(overgrown_block(T(24, 0, 0), block=2))
    # a tilled tile of ripe tomatoes next to them, for contrast
    spec = PATCHES["Tomato"]
    for dx, dz in ((-6, -18), (6, -18)):
        world.add(tile(), T(dx, 0.5, dz))
        for name, m, s in spec["build"]("Ripe", spec["per"]):
            world.add(built_crop(name), T(dx, 0.5, dz) @ scaled(m, s))
    world.add(figure(T(-2, 0.5, -10)))
    shots = [
        shot(world, np.array([-14, 9, -26]), np.array([2, 1.5, 0]), size=(720, 450)),
        shot(world, np.array([-40, 16, -70]), np.array([8, 1, 0]), size=(720, 450)),
        shot(world, np.array([10, 60, -24]), np.array([10, 0, 0]), size=(720, 450)),
        shot(world, np.array([-5, 5, -9]), np.array([-4, 1.5, -2]), size=(720, 450)),
    ]
    return sheet(shots, 2, path, ["close", "from the farmhouse", "above", "at the stump"])


if __name__ == "__main__":
    import sys
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "props", "previews")
    os.makedirs(out, exist_ok=True)
    if "--wild" in sys.argv or len(sys.argv) == 1:
        print(overgrowth_preview(os.path.join(out, "overgrowth.png")))
    if "--sheet" in sys.argv or len(sys.argv) == 1:
        print(prop_sheet(os.path.join(out, "props.png")))
