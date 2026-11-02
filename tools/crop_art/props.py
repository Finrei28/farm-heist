"""Farm Heist's props as low-poly meshes: what grows wild on locked land
(the four obstacles you clear and the tall grass round them), things in a
farm's yard, and produce as it sits on a store's shelves (a filled punnet).
They go in their own file, art/props/FarmHeistProps.glb, so a change here
never means importing the crops again. Same rules as the crops: each mesh
stands on its "foot" (y = 0 is the ground), one palette, flat shaded.
"""
import math

import numpy as np

from crops import built as built_crop, by_light, leafy, seed_of, tones
from meshkit import Mesh, R, T, apply, blob, box, frame, gem, lathe, leaf, mul, perpendicular, tube, unit

PROPS = {}  # name -> dict(build=fn, textured=bool, material=?, colour=?)


def prop(name, textured=True, **props):
    def register(fn):
        PROPS[name] = dict(build=fn, textured=textured, **props)
        return fn
    return register


_built = {}


def built(name):
    if name not in _built:
        _built[name] = PROPS[name]["build"]()
        _built[name].name = name
    return _built[name]


def rng_of(name):
    return np.random.default_rng(seed_of(name))


# ===========================================================================
# Wild land (server/World/FarmArt: an overgrown block's obstacles and grass)


def blade(m, base, out, height, width, col, bend=0.5, segs=3, twist=0.0):
    """One grass blade from `base`, leaning out along `out` and arching over
    by `bend` (0 straight up .. 1 flopped), tapering to a point. Two-sided."""
    out = unit(np.asarray(out, dtype=float) * [1, 0, 1] + 1e-9)
    side = unit(np.cross(out, [0, 1, 0]))
    if twist:
        side = unit(side * math.cos(twist) + np.array([0, 1.0, 0]) * math.sin(twist) * 0.3)
    pts = []
    for i in range(segs + 1):
        t = i / segs
        lean = bend * t * t
        p = np.asarray(base, dtype=float) + out * height * (0.15 * t + 0.85 * lean) * 0.8 + np.array([0, 1.0, 0]) * height * t * (1 - 0.45 * lean)
        pts.append(p)
    for i in range(segs):
        w0 = width * (1 - i / segs)
        w1 = width * (1 - (i + 1) / segs)
        a, b = pts[i] - side * w0 / 2, pts[i] + side * w0 / 2
        c, d = pts[i + 1] + side * w1 / 2, pts[i + 1] - side * w1 / 2
        if w1 < 1e-6:
            m.tri(a, b, c, col, double=True)
        else:
            m.quad(a, b, c, d, col, double=True)
    return pts[-1]


def tuft(m, rng, count, height, width, cols, radius=0.35, spread=1.0, bend=0.55):
    """A clump of grass blades fanning out from a small base."""
    tips = []
    for j in range(count):
        a = j / count * 2 * math.pi + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0, radius)
        out = np.array([math.cos(a), 0, math.sin(a)])
        base = out * r
        h = height * rng.uniform(0.7, 1.08)
        tips.append(blade(m, base, out * spread + rng.uniform(-0.2, 0.2, 3) * [1, 0, 1], h, width * rng.uniform(0.8, 1.2),
                          cols[j % len(cols)], bend=bend * rng.uniform(0.6, 1.3)))
    return tips


def seed_head(m, base, top, col, stalk="grassDark", spikes=5):
    """A grass stalk arching over at the top, oat-like seeds dangling from
    its last part."""
    bend = top + np.array([0.0, -0.35, 0.0]) + unit((top - base) * [1, 0, 1] + 1e-9) * 0.45
    path = curve3(base, base + (top - base) * 0.6, bend)
    m.add(tube(path, [0.04, 0.035, 0.03, 0.02], 3, stalk))
    for i in range(spikes):
        t = 0.45 + 0.55 * i / max(1, spikes - 1)
        k = min(len(path) - 2, int(t * (len(path) - 1)))
        p = path[k] + (path[k + 1] - path[k]) * (t * (len(path) - 1) - k)
        side = unit(np.cross(path[-1] - path[0], [0, 1, 0]) + 1e-9) * (-1) ** i
        m.add(gem(0.06, col, h=0.16), frame(p + side * 0.1 - np.array([0, 0.12, 0]), [0, 1, 0], side))


def daisy(m, at, up, r, petal, eye, petals=8):
    """A flat flower: petals round an eye, facing `up`."""
    f = frame(at, up)
    for k in range(petals):
        a = 2 * math.pi * k / petals
        c, s = math.cos(a), math.sin(a)
        p0 = apply(f, np.array([[c * r * 0.25, 0.02, s * r * 0.25]]))[0]
        p1 = apply(f, np.array([[c * r + s * r * 0.22, 0.0, s * r - c * r * 0.22]]))[0]
        p2 = apply(f, np.array([[c * r - s * r * 0.22, 0.0, s * r + c * r * 0.22]]))[0]
        m.tri(p0, p1, p2, petal, double=True)
    m.add(gem(r * 0.3, eye, h=r * 0.16, sides=5), f)


@prop("GrassTuft1")
def grass_tuft_1():
    """Tall wild grass, arching over."""
    m = Mesh()
    rng = rng_of("GrassTuft1")
    tuft(m, rng, 16, 2.6, 0.26, ["grass", "grassDark", "grassLight", "grass"])
    return m


@prop("GrassTuft2")
def grass_tuft_2():
    """Tall wild grass gone to seed: oat-like heads arching over."""
    m = Mesh()
    rng = rng_of("GrassTuft2")
    tuft(m, rng, 14, 2.2, 0.24, ["grassDark", "grass", "olive", "grassLight"])
    for j in range(3):
        a = j * 2.1 + 0.4
        base = np.array([math.cos(a) * 0.15, 0, math.sin(a) * 0.15])
        top = np.array([math.cos(a) * 0.6, 2.8 + 0.25 * (j % 2), math.sin(a) * 0.6])
        seed_head(m, base, top, "seedHead", spikes=5)
    return m


@prop("GrassPatch")
def grass_patch():
    """A wide patch of rough grass, knee high, thick enough that wild land
    reads as wild from the farmhouse."""
    m = Mesh()
    rng = rng_of("GrassPatch")
    cols = ["grass", "grassLight", "grass", "grassDark", "grassLight"]
    for j in range(40):
        r = 2.1 * math.sqrt(rng.uniform(0, 1))
        a = rng.uniform(0, 2 * math.pi)
        base = np.array([math.cos(a) * r, 0, math.sin(a) * r])
        out = np.array([math.cos(a), 0, math.sin(a)]) + rng.uniform(-0.5, 0.5, 3) * [1, 0, 1]
        h = rng.uniform(1.3, 2.2) * (1.1 - 0.2 * r / 2.1)
        blade(m, base, out, h, rng.uniform(0.15, 0.21), cols[j % len(cols)], bend=rng.uniform(0.55, 0.95), segs=2)
    return m


@prop("GrassTuft3")
def grass_tuft_3():
    """A low spreading clump with buttercups."""
    m = Mesh()
    rng = rng_of("GrassTuft3")
    tuft(m, rng, 14, 1.6, 0.28, ["grassLight", "grass", "grassDark"], radius=0.5, spread=1.4, bend=0.7)
    for j in range(4):
        a = j * 1.6 + 0.9
        top = np.array([math.cos(a) * 0.55, 1.5 + 0.2 * (j % 2), math.sin(a) * 0.55])
        m.add(tube([np.array([math.cos(a) * 0.1, 0, math.sin(a) * 0.1]), top], [0.035, 0.025], 3, "grassDark"))
        daisy(m, top, np.array([0, 1.0, 0]) + np.array([math.cos(a), 0, math.sin(a)]) * 0.4, 0.2, "flowerYellow", "flowerYellowDark", petals=5)
    return m


@prop("Stump")
def stump():
    """An old tree stump: a flared trunk of furrowed bark, the cut showing
    its rings, roots gripping the ground, a couple of toadstools."""
    m = Mesh()
    rng = rng_of("Stump")
    sides = 11
    lumps = rng.uniform(-0.07, 0.07, sides)

    def lobe(th):
        k = int(round(th / (2 * math.pi) * sides)) % sides
        return 1 + 0.05 * math.sin(th * 4) + lumps[k]
    prof = [(-0.2, 1.9), (0.2, 1.75), (0.7, 1.55), (1.4, 1.45), (2.0, 1.42)]
    m.add(lathe(prof, sides, lambda i, k, n: ("bark", "barkDark", "barkLight")[(k + i) % 3 if k % 2 else 1], lobe=lobe, cap=False))
    # the cut: a jagged bark rim, then rings of wood to the heart
    top = 2.0
    ring_r = [1.42, 1.3, 1.0, 0.68, 0.36, 0.0]
    ring_y = [top, top + 0.04, top + 0.06, top + 0.08, top + 0.09, top + 0.1]
    ring_col = ["barkLight", "stumpTop", "stumpRing", "stumpTop", "stumpRing"]
    for i in range(len(ring_r) - 1):
        m.add(lathe([(ring_y[i], ring_r[i]), (ring_y[i + 1], ring_r[i + 1])], sides, ring_col[i], lobe=lobe, cap=False))
    # a few splinters standing up from the rim
    for k in (1, 4, 8):
        a = 2 * math.pi * k / sides
        base = np.array([math.cos(a) * 1.32, top, math.sin(a) * 1.32]) * [lobe(a), 1, lobe(a)]
        out = np.array([math.cos(a), 0, math.sin(a)])
        side = np.array([-math.sin(a), 0, math.cos(a)])
        m.tri(base - side * 0.22, base + side * 0.22, base + np.array([0, 0.35 + 0.08 * (k % 3), 0]) + out * 0.04, "barkLight", double=True)
    # roots: out and down into the soil
    for j in range(6):
        a = j / 6 * 2 * math.pi + rng.uniform(-0.25, 0.25)
        out = np.array([math.cos(a), 0, math.sin(a)])
        reach = rng.uniform(2.5, 3.2)
        path = [out * 1.2 + [0, 0.9, 0], out * 1.75 + [0, 0.5, 0], out * 2.3 + [0, 0.2, 0], out * reach + [0, -0.15, 0]]
        m.add(tube(path, [0.5, 0.38, 0.24, 0.06], 6, lambda i, k: ("bark", "barkDark")[(i + k) % 2]))
    # toadstools at the foot
    for x, z, h, r in ((1.9, 1.1, 0.7, 0.42), (-1.4, -1.7, 0.55, 0.34)):
        m.add(lathe([(0.0, 0.11), (h, 0.09)], 6, "mushroomStem", cap=True), T(x, 0, z))
        m.add(lathe([(h - 0.05, r * 0.9), (h + 0.02, r), (h + r * 0.45, r * 0.7), (h + r * 0.7, 0.0)], 8,
                    lambda i, k, n: "mushroomCapLight" if n[1] > 0.8 else "mushroomCap"), T(x, 0, z))
        m.add(lathe([(h - 0.05, r * 0.9), (h - 0.05, 0.0)], 8, "mushroomGill", cap=False).transformed(R("x", 180) @ T(0, -2 * (h - 0.05), 0)), T(x, 0, z))
    return m


@prop("Rock")
def rock():
    """A boulder with moss on top and two smaller stones by it."""
    m = Mesh()
    rng = rng_of("Rock")

    def stone(moss):
        def col(n):
            if moss and n[1] > 0.86 and rng.uniform() < 0.6:
                return "moss"
            v = (n[1] + 1) / 2 + rng.uniform(-0.15, 0.15)
            return ("rockDeep", "rockDark", "rock", "rockLight")[int(np.clip(v * 4, 0, 3))]
        return col
    m.add(blob((2.1, 1.55, 1.7), stone(True), rng=rng, sub=1, jitter=0.2, flatten_bottom=-0.45), T(0, 0.45, 0))
    m.add(blob((0.95, 0.7, 0.85), stone(True), rng=rng, sub=1, jitter=0.22, flatten_bottom=-0.25), mul(T(2.2, 0.25, 1.1), R("y", 40)))
    m.add(blob((0.55, 0.4, 0.5), stone(False), rng=rng, sub=0, jitter=0.2, flatten_bottom=-0.15), mul(T(-1.5, 0.15, 1.6), R("y", 15)))
    # grass at its foot
    for x, z in ((-1.9, -0.6), (1.2, -1.5)):
        g = Mesh()
        tuft(g, rng, 7, 1.0, 0.2, ["grass", "grassDark"], radius=0.2)
        m.add(g, T(x, 0, z))
    return m


@prop("Weeds")
def weeds():
    """A rank clump of weeds: big jagged dock and dandelion leaves, dock
    stalks gone to rusty seed, thistles with purple heads, dandelions (one
    gone to a clock). Messy and green: something you'd want gone."""
    m = Mesh()
    rng = rng_of("Weeds")

    def jagged(t):
        return (0.55 + 0.45 * abs(math.sin(t * math.pi * 3.5))) * math.sin(math.pi * min(t, 1.0)) ** 0.6
    for j in range(11):
        a = j / 11 * 2 * math.pi + rng.uniform(-0.2, 0.2)
        d = np.array([math.cos(a), 0, math.sin(a)])
        big = j % 2 == 0
        m.add(leaf(rng.uniform(2.0, 2.5) if big else rng.uniform(1.4, 1.8), 0.95 if big else 0.6, ("weed", "weedDark"), segs=4,
                   shape=None if big else jagged, curl=45, rise=50 if big else 30, fold=0.25),
              frame(np.array([0, 0.05, 0]), [0, 1, 0], d))
    # dock: tall stalks, the top third crowded with rusty seed
    for a, h in ((0.6, 3.4), (2.6, 3.0), (4.4, 3.7)):
        d = np.array([math.cos(a), 0, math.sin(a)])
        path = curve3(d * 0.15, d * 0.35 + [0, h * 0.5, 0], d * 0.7 + [0, h, 0])
        m.add(tube(path, [0.08, 0.07, 0.06, 0.04], 4, "weedDark"))
        for t in np.linspace(0.6, 1.0, 5):
            p = path[0] + (path[-1] - path[0]) * t
            for q in range(3):
                b = q * 2.1 + t * 5
                off = np.array([math.cos(b), 0, math.sin(b)]) * 0.13
                m.add(gem(0.09, "dock" if q % 2 else "dockDark", h=0.12), T(*(p + off)))
    # thistles: a stiff stalk with spiny leaves and purple brushes
    for a, h in ((1.5, 3.1), (5.3, 2.7)):
        d = np.array([math.cos(a), 0, math.sin(a)])
        base = d * 0.25
        top = d * 0.5 + [0, h, 0]
        m.add(tube([base, (base + top) / 2, top], [0.1, 0.08, 0.06], 5, "weedDark"))
        for t, s in ((0.3, 1.0), (0.55, 0.8)):
            p = base + (top - base) * t
            for sgn in (-1, 1):
                side = np.array([-d[2], 0, d[0]]) * sgn
                m.add(leaf(0.95 * s, 0.38, "weed", segs=3, shape=jagged, curl=-10, rise=25, fold=0.35), frame(p, [0, 1, 0], side))
        m.add(lathe([(-0.32, 0.06), (-0.2, 0.27), (0.0, 0.25)], 7, "thistleBulb", cap=True), T(*top))
        m.add(lathe([(0.0, 0.23), (0.26, 0.28), (0.34, 0.0)], 9, lambda i, k, n: "thistleLight" if k % 2 else "thistle"), T(*top))
    # dandelions, low among the leaves, and a clock
    for a, h, clock in ((0.1, 1.5, False), (3.6, 1.8, True), (5.9, 1.3, False)):
        d = np.array([math.cos(a), 0, math.sin(a)])
        top = d * 0.9 + [0, h, 0]
        m.add(tube(curve3(d * 0.2 + [0, 0.1, 0], d * 0.5 + [0, h * 0.6, 0], top), [0.05, 0.05, 0.045, 0.04], 4, "weedStem"))
        if clock:
            m.add(blob((0.27, 0.27, 0.27), "puff", sub=1, rng=rng, jitter=0.12), T(*top))
        else:
            m.add(lathe([(-0.12, 0.1), (-0.02, 0.2), (0.1, 0.23), (0.2, 0.17), (0.27, 0.0)], 8,
                        lambda i, k, n: "dandelionLight" if n[1] > 0.5 else "dandelion"), T(*top))
            m.add(lathe([(-0.24, 0.0), (-0.1, 0.12)], 6, "weedDark", cap=False), T(*top))
    return m


def curve3(a, b, c, n=4):
    """A gentle curve from a through b to c (quadratic)."""
    return [(1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c for t in np.linspace(0, 1, n)]


@prop("Bramble")
def bramble():
    """A tangled bramble: a dark leafy mound with thorny canes arching out
    of it, white flowers and blackberries, red and ripe."""
    m = Mesh()
    rng = rng_of("Bramble")
    leafy(m, rng, (0, 1.55, 0), (2.1, 1.5, 1.9), 30, 1.05,
          ["brambleDeep", "brambleDark", "brambleDark", "bramble"], ["bramble", "brambleLight", "brambleDark"])
    leafy(m, rng, (1.3, 1.0, 1.0), (1.2, 0.95, 1.1), 10, 0.85,
          ["brambleDeep", "brambleDark", "bramble"], ["bramble", "brambleLight"])
    for j in range(6):
        a = j / 6 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        d = np.array([math.cos(a), 0, math.sin(a)])
        reach = rng.uniform(2.9, 3.5)
        pts = [d * 1.0 + [0, 1.6, 0], d * 1.9 + [0, 2.9, 0], d * 2.8 + [0, 2.3, 0], d * reach + [0, 0.5, 0]]
        path = curve_points(pts, 3)
        m.add(tube(path, np.linspace(0.11, 0.05, len(path)), 4, lambda i, k: ("cane", "caneDark")[k % 2]))
        for i in range(2, len(path) - 1, 2):
            t = unit(path[i + 1] - path[i])
            side, up = perpendicular(t)
            m.add(leaf(0.75, 0.42, ("bramble", "brambleDark"), segs=2, curl=30, rise=15), frame(path[i], up, unit(side + t * 0.3)))
            m.add(gem(0.04, "thorn", h=0.14, sides=3), frame(path[i], up, t))
        tip = path[-2]
        if j % 3 == 0:
            daisy(m, tip + [0, 0.15, 0], [0, 1, 0], 0.28, "bloom", "flowerYellowDark", petals=5)
        else:
            for q in range(3):
                off = np.array([math.cos(q * 2.1), 0, math.sin(q * 2.1)]) * 0.2 + [0, -0.12 * q, 0]
                m.add(blob((0.18, 0.21, 0.18), "blackberry" if (j + q) % 3 else "blackberryRed", sub=0), T(*(tip + off)))
    return m


def curve_points(points, n):
    """A smooth path through `points`, n steps a span (Catmull-Rom)."""
    pts = [np.asarray(p, dtype=float) for p in points]
    pts = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-2])
    return out


@prop("Wildflowers")
def wildflowers():
    """A low clump of leaves and daisies (wild land, flower boxes)."""
    m = Mesh()
    rng = rng_of("Wildflowers")
    for j in range(7):
        a = j / 7 * 2 * math.pi
        m.add(leaf(0.75, 0.38, ("leaf", "leafDark"), segs=3, curl=50, rise=40), frame(np.zeros(3), [0, 1, 0], [math.cos(a), 0, math.sin(a)]))
    cols = [("flowerWhite", "flowerYellow"), ("flowerPink", "flowerYellowDark"), ("flowerWhite", "flowerYellow"), ("flowerBlue", "flowerWhite")]
    for j in range(6):
        a = j * 2.3 + 0.2
        r = 0.25 + 0.2 * (j % 3)
        top = np.array([math.cos(a) * r, 0.75 + 0.2 * ((j * 7) % 3), math.sin(a) * r])
        m.add(tube([np.array([math.cos(a) * 0.08, 0, math.sin(a) * 0.08]), top], [0.035, 0.025], 3, "leafDark"))
        petal, eye = cols[j % len(cols)]
        daisy(m, top, np.array([0, 1.0, 0]) + np.array([math.cos(a), 0, math.sin(a)]) * 0.35, 0.22, petal, eye)
    return m


# ===========================================================================
# The yard (server/World/FarmhouseArt)


def chamfer_box(size, e, col):
    """A box with its edges and corners bevelled by `e` (hay bales, logs):
    col(normal) or a name."""
    m = Mesh()
    hx, hy, hz = (s / 2 for s in size)
    h = np.array([hx, hy, hz])
    inner = h - e

    def corner(sx, sy, sz, axis):
        # the point of corner (sx, sy, sz) on the face across `axis`
        p = np.array([sx, sy, sz]) * inner
        p[axis] = [sx, sy, sz][axis] * h[axis]
        return p
    signs = [-1, 1]
    for axis in range(3):
        for s in signs:
            o = [(axis + 1) % 3, (axis + 2) % 3]
            pts = []
            for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                v = [0, 0, 0]
                v[axis], v[o[0]], v[o[1]] = s, a, b
                pts.append(corner(*v, axis))
            n = np.zeros(3)
            n[axis] = s
            m.quad(*pts, pick_col(col, n), out=n)
    # edges: between the faces across two axes
    for a1 in range(3):
        for a2 in range(a1 + 1, 3):
            a3 = 3 - a1 - a2
            for s1 in signs:
                for s2 in signs:
                    quad = []
                    for s3 in (-1, 1):
                        for which in (a1, a2):
                            v = [0, 0, 0]
                            v[a1], v[a2], v[a3] = s1, s2, s3
                            quad.append(corner(*v, which))
                    n = np.zeros(3)
                    n[a1], n[a2] = s1, s2
                    n = unit(n)
                    a, b, c, d = quad[0], quad[1], quad[3], quad[2]
                    m.quad(a, b, c, d, pick_col(col, n), out=n)
    # corners: a triangle each
    for sx in signs:
        for sy in signs:
            for sz in signs:
                pts = [corner(sx, sy, sz, ax) for ax in range(3)]
                n = unit(np.array([sx, sy, sz], dtype=float))
                m.tri(*pts, pick_col(col, n), out=n)
    return m


def triangulate(poly):
    """Ear clipping: triangles (index triples) covering a simple polygon."""
    pts = [np.asarray(p, dtype=float) for p in poly]
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    order = list(range(len(pts))) if area > 0 else list(range(len(pts)))[::-1]

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def inside(p, a, b, c):
        return cross(a, b, p) >= 0 and cross(b, c, p) >= 0 and cross(c, a, p) >= 0
    tris = []
    guard = 0
    while len(order) > 3 and guard < 10000:
        guard += 1
        for i in range(len(order)):
            ia, ib, ic = order[i - 1], order[i], order[(i + 1) % len(order)]
            a, b, c = pts[ia], pts[ib], pts[ic]
            if cross(a, b, c) <= 1e-12:
                continue
            if any(inside(pts[j], a, b, c) for j in order if j not in (ia, ib, ic)):
                continue
            tris.append((ia, ib, ic))
            order.pop(i)
            break
    tris.append(tuple(order))
    return tris


def flat(m, outline, thick, col):
    """A flat cut-out in the XY plane `thick` deep (a weathervane's rooster)."""
    pts = [np.array([x, y, 0.0]) for x, y in outline]
    for a, b, c in triangulate([(p[0], p[1]) for p in pts]):
        for z, out in ((thick, 1.0), (-thick, -1.0)):
            m.tri(pts[a] + [0, 0, z], pts[b] + [0, 0, z], pts[c] + [0, 0, z], col, out=[0, 0, out])
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        m.quad(a + [0, 0, thick], b + [0, 0, thick], b - [0, 0, thick], a - [0, 0, thick], col, double=True)


def pick_col(col, n):
    return col(n) if callable(col) else col


@prop("HayBale")
def hay_bale():
    """A square bale (3 x 1.6 x 1.8): bevelled edges, two bands of twine,
    loose straws poking out of its ends and top."""
    m = Mesh()
    rng = rng_of("HayBale")

    def col(n):
        if n[1] > 0.7:
            return "hayLight"
        if abs(n[0]) > 0.7:
            return "hayDark"
        return "hay"
    m.add(chamfer_box((3.0, 1.6, 1.8), 0.22, col), T(0, 0.8, 0))
    for x in (-0.75, 0.75):
        m.add(chamfer_box((0.1, 1.64, 1.84), 0.2, lambda n: "twine" if n[1] > -0.5 else "twineDark"), T(x, 0.8, 0))
    for j in range(16):
        side = (-1, 1)[j % 2]
        y = rng.uniform(0.25, 1.4)
        z = rng.uniform(-0.75, 0.75)
        base = np.array([side * 1.48, y, z])
        tip = base + np.array([side * rng.uniform(0.2, 0.45), rng.uniform(-0.15, 0.2), rng.uniform(-0.2, 0.2)])
        w = np.array([0, 0.05, 0.05])
        m.tri(base - w, base + w, tip, "hayLight" if j % 3 else "hay", double=True)
    for j in range(8):
        base = np.array([rng.uniform(-1.3, 1.3), 1.58, rng.uniform(-0.7, 0.7)])
        tip = base + np.array([rng.uniform(-0.4, 0.4), rng.uniform(0.05, 0.25), rng.uniform(-0.4, 0.4)])
        m.tri(base - [0.05, 0, 0.05], base + [0.05, 0, 0.05], tip, "hayLight", double=True)
    return m


@prop("MilkChurn")
def milk_churn():
    """An old steel milk churn: a fat body with rolled bands, a shoulder up
    to a neck, a lid with a knob, a handle each side."""
    m = Mesh()
    sides = 12

    def col(i, k, n):
        if n[1] > 0.75:
            return "steelLight"
        return ("steel", "steelDark")[k % 2] if i not in (1, 4) else "steelDark"
    prof = [(0.0, 0.52), (0.08, 0.6), (0.16, 0.6), (1.1, 0.6), (1.18, 0.63), (1.3, 0.6), (1.55, 0.42), (1.8, 0.3),
            (2.0, 0.3), (2.06, 0.4), (2.16, 0.38), (2.2, 0.0)]
    m.add(lathe(prof, sides, col))
    m.add(lathe([(2.2, 0.1), (2.32, 0.08), (2.36, 0.0)], 6, "steelDark"))
    for sgn in (-1, 1):
        path = [np.array([sgn * 0.42, 1.55, -0.18]), np.array([sgn * 0.62, 1.78, -0.14]), np.array([sgn * 0.62, 1.78, 0.14]),
                np.array([sgn * 0.42, 1.55, 0.18])]
        m.add(tube(path, [0.05] * 4, 4, "steelDark"))
    return m


@prop("Wheelbarrow")
def wheelbarrow():
    """A barn-red wheelbarrow: a tray flaring up from its floor, a fat
    wheel at the front, two handles, two legs. Front is -Z."""
    m = Mesh()
    lo = np.array([0.55, 0.0, 0.8])
    hi = np.array([0.95, 0.85, 1.25])
    y0 = 1.0

    def corners(h, y, front):
        return [np.array([-h[0], y, -h[2] - front]), np.array([h[0], y, -h[2] - front]), np.array([h[0], y, h[2]]), np.array([-h[0], y, h[2]])]
    bottom = corners(lo, y0, 0.0)
    top = corners(hi, y0 + hi[1], 0.45)
    for i in range(4):
        j = (i + 1) % 4
        m.quad(bottom[i], bottom[j], top[j], top[i], "barrow", double=True)
    m.quad(*bottom, "barrowDark", double=True)
    for i in range(4):
        j = (i + 1) % 4
        m.add(tube([top[i], top[j]], [0.06, 0.06], 4, "barrowDark"))
    # the wheel, under the front
    wheel = lathe([(-0.16, 0.0), (-0.16, 0.42), (-0.1, 0.5), (0.1, 0.5), (0.16, 0.42), (0.16, 0.0)], 12,
                  lambda i, k, n: "tyre" if abs(n[1]) < 0.9 else "steel", cap=False)
    m.add(wheel, mul(T(0, 0.5, -1.55), R("z", 90)))
    # handles from the axle back past the tray, and legs
    for sgn in (-1, 1):
        path = [np.array([sgn * 0.2, 0.5, -1.55]), np.array([sgn * 0.6, 0.95, -0.6]), np.array([sgn * 0.75, 1.0, 1.3]),
                np.array([sgn * 0.8, 1.15, 2.1])]
        m.add(tube(path, [0.06, 0.07, 0.07, 0.07], 5, "wood"))
        m.add(tube([np.array([sgn * 0.8, 1.1, 1.95]), np.array([sgn * 0.8, 1.2, 2.35])], [0.09, 0.09], 6, "barrowDark", cap1=True))
        m.add(tube([np.array([sgn * 0.62, 1.0, 0.7]), np.array([sgn * 0.66, 0.0, 0.85])], [0.06, 0.05], 4, "barrowDark"))
    return m


@prop("Weathervane")
def weathervane():
    """A barn's weathervane in black iron: a rooster over the arrow, the
    four points of the compass on arms under it. Stands on the ridge."""
    m = Mesh()
    m.add(tube([np.zeros(3), np.array([0, 3.6, 0])], [0.07, 0.05], 5, "iron", cap1=True))
    m.add(blob((0.16, 0.16, 0.16), "ironGold", sub=1), T(0, 1.3, 0))
    for a in range(4):
        d = np.array([math.cos(a * math.pi / 2), 0, math.sin(a * math.pi / 2)])
        m.add(tube([np.array([0, 1.3, 0]), d * 1.1 + [0, 1.3, 0]], [0.04, 0.04], 4, "iron"))
        m.add(gem(0.14, "ironGold", h=0.14), T(*(d * 1.15 + [0, 1.3, 0])))
    # the arrow along X: a shaft, a head, a tail of feathers (flat, two-sided)
    y = 2.6
    m.add(tube([np.array([-1.5, y, 0]), np.array([1.4, y, 0])], [0.05, 0.05], 4, "iron"))
    m.tri([1.9, y, 0], [1.35, y + 0.3, 0], [1.35, y - 0.3, 0], "iron", double=True)
    m.quad([-1.6, y - 0.05, 0], [-1.1, y - 0.05, 0], [-1.25, y + 0.5, 0], [-1.85, y + 0.5, 0], "iron", double=True)
    m.quad([-1.6, y + 0.05, 0], [-1.1, y + 0.05, 0], [-1.25, y - 0.4, 0], [-1.85, y - 0.4, 0], "iron", double=True)
    # the rooster, facing along the arrow: a body, a crowing head with its
    # comb, beak and wattle, a high curl of tail feathers, legs to the arrow
    outline = [
        (0.35, 0.5), (0.68, 0.66), (0.82, 0.95), (0.86, 1.18), (0.93, 1.22), (0.96, 1.08), (1.04, 1.12), (1.02, 1.36),
        (1.3, 1.44), (1.03, 1.55), (1.0, 1.68), (0.94, 1.86), (0.87, 1.72), (0.79, 1.9), (0.72, 1.74), (0.62, 1.84),
        (0.58, 1.62), (0.52, 1.3), (0.34, 1.05), (0.0, 1.0), (-0.22, 1.2), (-0.42, 1.72), (-0.72, 2.0), (-1.02, 1.9),
        (-0.98, 1.6), (-0.82, 1.3), (-1.0, 1.12), (-0.88, 0.82), (-0.6, 0.6), (-0.2, 0.46),
    ]
    flat(m, [(x, y + yy) for x, yy in outline], 0.05, "iron")
    for x in (0.12, -0.12):
        m.add(tube([np.array([x, y + 0.05, 0]), np.array([x + 0.05, y + 0.55, 0])], [0.05, 0.05], 4, "iron"))
    return m


# ===========================================================================
# The field (server/World/FarmArt): a tilled tile's soil


@prop("Furrows", textured=False)
def furrows():
    """A tilled tile's three ridges in one mesh (on the tile's top, the rows
    along Z at x = -3.2, 0, 3.2, their tops about 0.45 up where crops stand):
    mounds of turned soil, lumpy along their length, rounded at the ends,
    with clods in the furrows. Smooth cylinders read as a raft of logs. One
    colour, untextured: the game tints it (watered, composted)."""
    m = Mesh()
    rng = rng_of("Furrows")
    across = np.linspace(-1.0, 1.0, 6)
    along = np.linspace(-5.1, 5.1, 11)
    for cx in (-3.2, 0.0, 3.2):
        rings = []
        for i, z in enumerate(along):
            end = min(i, len(along) - 1 - i)
            taper = (0.5, 0.85, 1.0)[min(end, 2)]
            ring = []
            for j, u in enumerate(across):
                edge = j in (0, len(across) - 1)
                w = 0.9 * (1 + rng.uniform(-0.07, 0.07))
                y = -0.04 if edge else 0.46 * (1 - u * u) ** 0.55 * taper + rng.uniform(-0.075, 0.06)
                dz = 0.0 if end == 0 else rng.uniform(-0.12, 0.12)
                ring.append(np.array([cx + u * w, y, z + dz]))
            rings.append(ring)
        for i in range(len(along) - 1):
            for j in range(len(across) - 1):
                m.quad(rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j], "ridge", out=(0, 1, 0))
        for i, sign in ((0, -1.0), (len(along) - 1, 1.0)):
            ring = rings[i]
            for j in range(len(across) - 1):
                a, b = ring[j], ring[j + 1]
                m.quad(np.array([a[0], -0.04, a[2]]), np.array([b[0], -0.04, b[2]]), b, a, "ridge", out=(0, 0, sign))
    for k in range(9):
        x = (-1.6, 1.6)[k % 2] + rng.uniform(-0.35, 0.35)
        z = rng.uniform(-4.8, 4.8)
        r = rng.uniform(0.14, 0.22)
        m.add(gem(r, "ridge", h=r * 0.6, sides=4), mul(T(x, r * 0.3, z), R("y", rng.uniform(0, 90))))
    # clods on the ridges' flanks (the tops stay clear for the crops)
    for k in range(12):
        cx = (-3.2, 0.0, 3.2)[k % 3]
        side = (-1, 1)[(k // 3) % 2]
        z = rng.uniform(-4.4, 4.4)
        r = rng.uniform(0.13, 0.2)
        m.add(gem(r, "ridge", h=r * 0.7, sides=4), mul(T(cx + side * rng.uniform(0.5, 0.65), 0.2, z), R("y", rng.uniform(0, 90)), R("z", side * 30)))
    return m
