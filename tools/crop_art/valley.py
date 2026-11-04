"""Farm Heist's valley (docs/ArtDirection.md §5, §11 step 4) as low-poly
meshes, in the props file: the hedges between the farms as leafy sections
with flowers, and the stone arch of the tunnel's mouth in the north cliff.
The woods and the back trail's cover use the town's trees and bushes and
the yard's hay bales; the hills and the cliff are Terrain
(server/World/ValleyArt). Each stands on y = 0.
"""
import math

import numpy as np

from crops import by_light
from meshkit import Mesh, T, blob, frame, leaf, unit
from props import chamfer_box, daisy, prop, rng_of

HEDGE_LENGTH = 42.0  # six to a farm's side (252 studs)


@prop("HedgeSection")
def hedge_section():
    """42 studs of hedge, 3 thick and 12 tall: a core of leaves with lumps
    bulging out of both faces and along the top (so its outline is never a
    straight wall), leaves sticking out between them, a few white and
    yellow flowers. Its length runs along Z."""
    rng = rng_of("HedgeSection")
    m = Mesh()
    L = HEDGE_LENGTH
    shades = ["leafDark", "leaf", "leafLight", "leafLight"]

    def core(n):
        return "leafDeep" if n[1] < -0.5 else ("leaf" if n[1] > 0.5 else "leafDark")
    m.add(chamfer_box((2.4, 10.2, L - 0.4), 0.6, core), T(0, 5.1, 0))

    def lump(at, radii):
        m.add(blob(radii, by_light(shades, under="leafDark", rng=rng), rng=rng, sub=0, jitter=0.18), T(*at))
        for _ in range(3):
            u, a = rng.uniform(-0.2, 0.9), rng.uniform(0, 2 * math.pi)
            ring = math.sqrt(max(0.0, 1 - u * u))
            d = unit(np.array([math.cos(a) * ring, u, math.sin(a) * ring]))
            p = np.asarray(at) + d * np.asarray(radii) * 0.85
            up = unit(np.array([0, 1.0, 0]) - d * d[1]) if abs(d[1]) < 0.95 else np.array([1.0, 0, 0])
            size = rng.uniform(1.4, 2.0)
            m.add(leaf(size, size * 0.55, shades[rng.integers(0, len(shades))], segs=2, curl=rng.uniform(15, 40), rise=10, fold=0.3), frame(p, up, d))
    # along the top, a rounded crest of lumps
    for i in range(9):
        z = -L / 2 + (i + 0.5) * L / 9 + rng.uniform(-0.8, 0.8)
        lump((rng.uniform(-0.3, 0.3), 10.0 + rng.uniform(0.0, 0.6), z), (1.9, rng.uniform(1.6, 2.1), rng.uniform(2.6, 3.2)))
    for side in (-1, 1):
        # lumps bulging out of the face, at two heights
        for j in range(10):
            z = -L / 2 + (j + 0.5) * L / 10 + rng.uniform(-1.0, 1.0)
            y = (3.0 if j % 2 else 7.2) + rng.uniform(-0.8, 0.8)
            lump((side * 1.15, y, z), (0.95, rng.uniform(2.4, 3.2), rng.uniform(2.4, 3.0)))
        # leaves sticking out between them
        for j in range(26):
            y = rng.uniform(0.6, 10.0)
            z = rng.uniform(-L / 2 + 0.6, L / 2 - 0.6)
            p = np.array([side * 1.3, y, z])
            d = unit(np.array([side * 1.0, rng.uniform(-0.25, 0.45), rng.uniform(-0.35, 0.35)]))
            up = unit(np.array([0, 1.0, 0]) - d * d[1])
            size = rng.uniform(1.4, 2.0)
            m.add(leaf(size, size * 0.55, shades[j % len(shades)], segs=2, curl=rng.uniform(15, 40), rise=10, fold=0.3), frame(p, up, d))
        for j in range(5):
            y = rng.uniform(2.5, 9.0)
            z = -L / 2 + (j + 0.5) * L / 5 + rng.uniform(-2, 2)
            white = (j + (side > 0)) % 2 == 0
            daisy(m, np.array([side * 2.0, y, z]), (side, 0.25, 0), 0.4,
                  "flowerWhite" if white else "flowerYellow", "flowerYellow" if white else "hayDark", petals=7)
    return m


def prism(m, front, back, col):
    """A block between two matching outlines (lists of 3D points, the same
    count, going round the same way): its two ends and its sides."""
    n = len(front)
    centre = (np.mean(front, axis=0) + np.mean(back, axis=0)) / 2
    m.tri(front[0], front[1], front[2], col(np.array([0, 0, -1.0])), inside=centre)
    for i in range(1, n - 1):
        m.tri(front[0], front[i], front[i + 1], col(np.array([0, 0, -1.0])), inside=centre)
        m.tri(back[0], back[i], back[i + 1], col(np.array([0, 0, 1.0])), inside=centre)
    for i in range(n):
        a, b = front[i], front[(i + 1) % n]
        c, d = back[(i + 1) % n], back[i]
        mid = (a + b) / 2
        out = unit(np.array([mid[0] - centre[0], mid[1] - centre[1], 0.0]) + 1e-9)
        m.quad(a, b, c, d, col(out), inside=centre)


@prop("TunnelArch")
def tunnel_arch():
    """The tunnel's mouth in the north cliff: a stone face 52 wide, 36 tall
    and 3 deep laid in courses, round an arch 30 wide whose crown is 29 up
    (clear for any truck), with a ring of voussoirs, a keystone, a plinth
    and a cornice. Its front faces -Z (the valley)."""
    rng = rng_of("TunnelArch")
    m = Mesh()
    W, H, D = 52.0, 36.0, 3.0
    R0, SPRING = 15.0, 14.0  # the opening's radius and where the arch springs (on a course line)
    R1 = R0 + 3.2  # the voussoirs' outer edge
    shades = ("stone", "stoneShade", "stoneLight", "stone", "stoneShade")

    def colour(k):
        base = shades[k % len(shades)]

        def col(n):
            if n[1] < -0.5:
                return "stoneDark"
            if n[1] > 0.5:
                return "stoneLight"
            return base
        return col

    # the courses: blocks of 3.2-4.8, every other course offset, clipped
    # clear of the opening and the voussoirs' ring
    course = 2.0
    k = 0
    for row in range(int(H / course)):
        y0, y1 = row * course, (row + 1) * course
        if y1 <= 1.2 or y0 >= H - 2.0:
            continue  # (the plinth and the cornice)
        y0 = max(y0, 1.2)
        if y0 < SPRING:
            hole = R0 if y1 <= SPRING else R1
        else:
            dy = y0 - SPRING
            hole = math.sqrt(R1 * R1 - dy * dy) if dy < R1 else 0.0
        x = -W / 2 - (2.0 if row % 2 else 0.0)
        while x < W / 2:
            length = rng.uniform(3.2, 4.8)
            x0, x1 = max(x, -W / 2), min(x + length, W / 2)
            x += length
            for a, b in ((x0, min(x1, -hole)), (max(x0, hole), x1)):
                if b - a > 0.6:
                    k += 1
                    block = chamfer_box((b - a - 0.12, y1 - y0 - 0.12, D), 0.12, colour(k))
                    m.add(block, np.array([[1, 0, 0, (a + b) / 2], [0, 1, 0, (y0 + y1) / 2], [0, 0, 1, D / 2], [0, 0, 0, 1.0]]))

    # behind the ring: a band of stone filling the steps between it and the courses
    steps = 36
    for i in range(steps):
        a0, a1 = math.pi * i / steps, math.pi * (i + 1) / steps
        pts = []
        for r, a in ((R1 - 0.3, a0), (R1 + 2.6, a0), (R1 + 2.6, a1), (R1 - 0.3, a1)):
            pts.append(np.array([r * math.cos(a), SPRING + r * math.sin(a), 0.4]))
        m.quad(*pts, "stoneDark", out=np.array([0, 0, -1.0]))
    # the jambs' faces either side of the opening, below the spring
    for side in (-1, 1):
        x = side * R0
        m.quad(np.array([x, 0, 0.0]), np.array([x, SPRING, 0.0]), np.array([x, SPRING, D]), np.array([x, 0, D]),
               "stoneShade", out=np.array([-side, 0, 0.0]))

    # the voussoirs, proud of the face, the keystone more so
    count = 17
    for i in range(count):
        a0, a1 = math.pi * i / count, math.pi * (i + 1) / count
        key = i == count // 2
        outer = R1 + (1.3 if key else 0.0)
        z0 = -0.7 if key else -0.35
        ring = [(R0, a0), (outer, a0), (outer, a1), (R0, a1)]
        front = [np.array([r * math.cos(a), SPRING + r * math.sin(a), z0]) for r, a in ring]
        back = [np.array([r * math.cos(a), SPRING + r * math.sin(a), D]) for r, a in ring]
        prism(m, front, back, colour(i + (3 if key else 0)) if not key else (lambda n: "stoneLight" if n[1] > 0.3 else "stone"))

    # the plinth along the foot and the cornice along the top (not across the opening)
    for side in (-1, 1):
        a, b = (-W / 2 - 0.4, -R0) if side < 0 else (R0, W / 2 + 0.4)
        m.add(chamfer_box((b - a, 1.2, D + 0.9), 0.15, colour(2)), np.array([[1, 0, 0, (a + b) / 2], [0, 1, 0, 0.6], [0, 0, 1, D / 2 - 0.45], [0, 0, 0, 1.0]]))
    m.add(chamfer_box((W + 1.6, 2.0, D + 1.4), 0.2, lambda n: "stoneLight" if n[1] > 0.5 else ("stoneDark" if n[1] < -0.5 else "stone")),
          np.array([[1, 0, 0, 0], [0, 1, 0, H - 1.0], [0, 0, 1, D / 2 - 0.7], [0, 0, 0, 1.0]]))
    return m
