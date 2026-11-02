"""Farm Heist's crops as low-poly meshes, and how a patch of each is laid
out at each stage (the game places exactly these: server/World/
CropMeshes.luau reads the generated CropMeshData).

A mesh builder returns a Mesh in its own "foot" space. A patch layout
returns [(mesh name, 4x4 rigid transform from the tile's top centre, uniform
scale)]. Ridges run along Z at x = -3.2, 0, 3.2, their tops 0.42 up.
"""
import math

import numpy as np

from meshkit import Mesh, R, S, T, apply, blob, box, frame, gem, lathe, leaf, mul, palm_leaf, perpendicular, tube, unit
from scene import ON_RIDGE, RIDGES, ROW, ridge_spots

MESHES = {}  # name -> dict(build=fn, textured=bool, material=?, colour=?)


def mesh(name, textured=True, **props):
    def register(fn):
        MESHES[name] = dict(build=fn, textured=textured, **props)
        return fn
    return register


def tones(rng, names, weights=None):
    """A colour picker for faces: a random tone each time."""
    def col(*_):
        return str(rng.choice(names, p=weights))
    return col


def by_light(shades, under=None, rng=None, spread=0.12):
    """Faces turned to the sky take the lighter shades."""
    def col(n, *_):
        n = np.asarray(n if np.ndim(n) else (0, 1, 0), dtype=float)
        if under is not None and n[1] < -0.4:
            return under
        v = (n[1] + 1) / 2 + (rng.uniform(-spread, spread) if rng is not None else 0)
        return shades[int(np.clip(v * len(shades), 0, len(shades) - 1))]
    return col


def curve(points, n=8):
    """A smooth path through `points` (Catmull-Rom), n steps a span."""
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


def feather(path, col, start=0.3, pairs=5, size=0.45, lift=0.35, rng=None):
    """Leaflets in pairs along the upper part of a stalk `path` (a carrot
    frond, a fern): each a small double-sided triangle pointing outward
    and forward, smaller toward the tip."""
    mesh = Mesh()
    n = len(path)
    for j in range(pairs):
        t = start + (1 - start) * (j / pairs)
        i = min(n - 2, int(t * (n - 1)))
        p = path[i]
        d = unit(path[i + 1] - path[i])
        side, up = perpendicular(d)
        # keep `side` level so leaflets spread sideways, not up and down
        side = unit(np.cross(d, [0, 1, 0])) if abs(d[1]) < 0.97 else side
        s = size * (1 - 0.6 * j / pairs)
        for sign in (-1, 1):
            tip = p + side * sign * s + d * s * 0.55 + np.array([0, lift * s, 0])
            back = p - d * s * 0.18
            fwd = p + d * s * 0.45
            mesh.tri(back, tip, fwd, col(j, sign), double=True)
    tip = path[-1]
    d = unit(path[-1] - path[-2])
    side = unit(np.cross(d, [0, 1, 0]))
    mesh.tri(tip - d * size * 0.3 - side * size * 0.18, tip + d * size * 0.35, tip - d * size * 0.3 + side * size * 0.18, col(pairs, 0), double=True)
    return mesh


def leafy(m, rng, centre, radii, leaves, length, core, cols, droop=25):
    """A clump of foliage: a lumpy core in darker greens with `leaves`
    leaves sticking out of its surface (so it reads as leaves, not a ball)."""
    centre = np.asarray(centre, dtype=float)
    radii = np.asarray(radii, dtype=float)
    m.add(blob(radii * 0.86, by_light(core, under=core[0], rng=rng), rng=rng, sub=1, jitter=0.15), T(*centre))
    for j in range(leaves):
        # (spread over the clump, fewer underneath)
        u = rng.uniform(-0.55, 1.0)
        a = rng.uniform(0, 2 * math.pi)
        ring = math.sqrt(max(0.0, 1 - u * u))
        n = unit(np.array([math.cos(a) * ring / radii[0], u / radii[1], math.sin(a) * ring / radii[2]]))
        p = centre + np.array([math.cos(a) * ring, u, math.sin(a) * ring]) * radii * 0.82
        d = unit(n + np.array([0, -0.01 * droop, 0]))
        up = np.array([0.0, 1.0, 0.0]) - d * d[1]
        up = unit(up) if np.linalg.norm(up) > 1e-3 else np.array([1.0, 0, 0])
        size = length * rng.uniform(0.8, 1.15)
        m.add(leaf(size, size * 0.55, cols[j % len(cols)], segs=2, curl=rng.uniform(15, 45), rise=10, fold=0.3), frame(p, up, d))


def seed_of(name):
    return sum(ord(c) * (i + 1) for i, c in enumerate(name)) % 10007


_built = {}


def built(name):
    """A mesh, built once (layouts read their points)."""
    if name not in _built:
        _built[name] = MESHES[name]["build"]()
        _built[name].name = name
    return _built[name]


def on(at, s, point, fruit_s=1.0):
    """Where something hangs from a plant's point when the plant stands at
    `at` scaled by `s`: (rigid transform, scale)."""
    p = at @ np.diag([s, s, s, 1.0]) @ point
    m = np.eye(4)
    m[:3, :3] = p[:3, :3] / s
    m[:3, 3] = p[:3, 3]
    return m, s * fruit_s


def hang_frame(origin, out, droop=0.0):
    """A point frame at `origin` whose -Y points out along `out` and down
    by `droop` (0..1): something hung there (built hanging down -Y from
    its own origin) dangles that way."""
    out = unit(np.asarray(out, dtype=float) * [1, 0, 1])
    down = unit(out * (1 - droop) + np.array([0, -1.0, 0]) * (0.25 + droop))
    return frame(origin, -down, out)


def fruit_on(items, plant, at, s, fruit, count, fruit_s=1.0, key="Fruit", order=None):
    pts = built(plant).points.get(key, [])
    idx = order or range(len(pts))
    for j in list(idx)[:count]:
        m, sc = on(at, s, pts[j], fruit_s)
        items.append((fruit, m, sc))
    return max(0, count - len(pts))


# ===========================================================================
# Shared pieces


@mesh("Seedling")
def seedling():
    """Two seed leaves and a first true leaf on a short stem."""
    m = Mesh()
    m.add(tube([(0, -0.1, 0), (0, 0.5, 0), (0.02, 0.75, 0)], [0.06, 0.05, 0.045], 4, "stem"))
    for yaw, col in ((0, ("sprout", "sproutDark")), (180, ("sproutDark", "sprout"))):
        m.add(leaf(0.62, 0.42, col, segs=3, curl=40, rise=25, fold=0.25), mul(T(0, 0.72, 0), R("y", yaw)))
    m.add(leaf(0.5, 0.3, ("leaf", "leafDark"), segs=3, curl=10, rise=60, fold=0.3), mul(T(0, 0.74, 0), R("y", 90)))
    return m


# ===========================================================================
# Carrot: an orange shoulder out of the ridge under a feathery plume


@mesh("Carrot")
def carrot():
    """A whole carrot, its crown at the origin, the root down -Y."""
    profile = [(-2.5, 0.0), (-2.2, 0.09), (-1.8, 0.19), (-1.35, 0.29), (-0.9, 0.37), (-0.5, 0.43), (-0.18, 0.47), (0.0, 0.44),
               (0.1, 0.32), (0.15, 0.12)]

    def col(i, k, n):
        if i >= 8:
            return "carrotCrown"
        if i % 3 == 1:
            return "carrotDark"
        return "carrotLight" if n[0] + n[2] > 0.9 else "carrot"
    m = lathe(profile, 7, col, spin=0.3)
    return m


@mesh("CarrotTop")
def carrot_top():
    """The plume of fronds, from the crown at the origin: a full fan of
    finely cut leaves, the outer ones arching over."""
    rng = np.random.default_rng(seed_of("CarrotTop"))
    m = Mesh()
    fronds = 9
    shade = ("frond", "frondLight", "frondDark", "frond")
    for f in range(fronds):
        inner = f % 3 == 0  # (a few stand up in the middle)
        yaw = f / fronds * 2 * math.pi + rng.uniform(-0.25, 0.25)
        out = np.array([math.cos(yaw), 0, math.sin(yaw)])
        tall = rng.uniform(1.9, 2.3) if inner else rng.uniform(1.4, 1.8)
        reach = rng.uniform(0.3, 0.55) if inner else rng.uniform(0.9, 1.3)
        path = curve([(0, 0, 0), out * reach * 0.2 + [0, tall * 0.5, 0], out * reach * 0.75 + [0, tall * 0.9, 0],
                      out * reach * 1.2 + [0, tall * (0.92 if inner else 0.7), 0]], n=2)
        m.add(tube(path, np.linspace(0.06, 0.025, len(path)), 3, "stem"))
        m.add(feather(path, lambda j, sg, f=f: shade[(j + f + (sg > 0)) % 4], start=0.28, pairs=5, size=0.62, lift=0.25))
    return m


def carrot_patch(stage, n):
    items = []
    if stage == "Growing":
        for at in ridge_spots(6, seed=3):
            items.append(("CarrotTop", mul(at, T(0, -0.05, 0)), 0.72))
        return items
    for at in ridge_spots(n, seed=n):
        crown = mul(at, T(0, 0.55, 0))
        items.append(("Carrot", crown, 1.2))
        items.append(("CarrotTop", crown, 1.2))
    return items


# ===========================================================================
# Wheat: golden sheaves standing in the stubble (one per sheaf it gives);
# growing, rows of green wheat in ear


def ear(m, base, direction, length, col, awns="wheatLight"):
    """An ear of grain from `base` along `direction`: a long four-sided
    spindle and a few whiskers (awns) off its tip."""
    f = frame(base, direction)
    spindle = lathe([(0, 0.0), (length * 0.22, length * 0.15), (length * 0.7, length * 0.16), (length, 0.0)], 4, col, spin=0.4)
    m.add(spindle, f)
    tip = apply(f, [(0, length * 0.92, 0)])[0]
    side, _ = perpendicular(direction)
    for s in (-1, 1):
        a = tip + side * s * 0.03
        m.tri(a, a + unit(direction) * length * 0.45 + side * s * 0.12, a + side * s * 0.06, awns, double=True)


@mesh("WheatSheaf")
def wheat_sheaf():
    """Stalks gathered and tied with twine at the waist: an hourglass of
    straight stalks crossing at the tie, the ears splaying out of the top
    and nodding over."""
    rng = np.random.default_rng(seed_of("WheatSheaf"))
    m = Mesh()
    waist = 1.25
    stalks = 20
    for k in range(stalks):
        a = k / stalks * 2 * math.pi + rng.uniform(-0.15, 0.15)
        r_foot = rng.uniform(0.45, 0.68)
        r_head = rng.uniform(0.55, 0.85)
        foot = np.array([math.cos(a) * r_foot, -0.1, math.sin(a) * r_foot])
        tie = np.array([math.cos(a) * 0.16, waist, math.sin(a) * 0.16])
        # (through the tie and out the other side: they cross)
        head = np.array([-math.cos(a) * r_head, rng.uniform(2.75, 3.15), -math.sin(a) * r_head])
        col = "wheatStalk" if k % 3 else "wheatDark"
        m.add(tube([foot, tie, head], [0.065, 0.05, 0.04], 3, col))
        nod = unit(unit(head - tie) + np.array([-math.cos(a), -0.35, -math.sin(a)]) * 0.55)
        ear(m, head, nod, rng.uniform(0.6, 0.75), "wheat" if k % 2 else "wheatLight")
    m.add(lathe([(waist - 0.12, 0.22), (waist + 0.12, 0.22)], 8, lambda i, k, n: "twine" if k % 2 else "twineDark", cap=False))
    return m


def stubble_row(seed, count=46, colour=("stubble", "wheatDark", "wheatStalk")):
    rng = np.random.default_rng(seed)
    m = Mesh()
    for i in range(count):
        z = -ROW / 2 - 0.2 + (i + rng.uniform(0, 1)) * (ROW + 0.4) / count
        x = rng.uniform(-0.55, 0.55)
        h = rng.uniform(0.25, 0.5)
        a = rng.uniform(0, math.pi)
        d = np.array([math.cos(a), 0, math.sin(a)]) * 0.05
        lean = rng.uniform(-0.08, 0.08, size=3) * np.array([1, 0, 1])
        base = np.array([x, -0.05 - 0.15 * abs(x), z])
        m.tri(base - d, base + d, base + lean + [0, h, 0], str(rng.choice(colour)), double=True)
    return m


@mesh("WheatStubble")
def wheat_stubble():
    """Cut stalks along a ridge's top, where the sheaves came from."""
    return stubble_row(seed_of("WheatStubble"))


@mesh("WheatRow")
def wheat_row():
    """A ridge of green wheat in ear: blades and stalks, green ears on top."""
    rng = np.random.default_rng(seed_of("WheatRow"))
    m = Mesh()
    blades = ("leaf", "leafDark", "leafLight", "stem")
    for i in range(44):  # (blades: tall thin triangles)
        z = -ROW / 2 + (i + rng.uniform(0, 1)) * ROW / 44
        x = rng.uniform(-0.5, 0.5)
        base = np.array([x, -0.1 - 0.12 * abs(x), z])
        a = rng.uniform(0, math.pi)
        d = np.array([math.cos(a), 0, math.sin(a)]) * 0.09
        top = base + [rng.uniform(-0.35, 0.35), rng.uniform(1.2, 1.7), rng.uniform(-0.35, 0.35)]
        m.tri(base - d, base + d, top, blades[i % 4], double=True)
    for i in range(16):  # (stalks with green ears)
        z = -ROW / 2 + (i + rng.uniform(0.2, 0.8)) * ROW / 16
        base = np.array([rng.uniform(-0.35, 0.35), -0.1, z])
        top = base + [rng.uniform(-0.12, 0.12), rng.uniform(1.75, 2.0), rng.uniform(-0.12, 0.12)]
        m.add(tube([base, top], [0.04, 0.03], 3, "stem"))
        ear(m, top, unit(top - base + [0, 0.4, 0]), 0.5, "leafLight" if i % 2 else "sprout", awns="sprout")
    return m


def wheat_patch(stage, n):
    items = []
    if stage == "Growing":
        for x in RIDGES:
            items.append(("WheatRow", T(x, ON_RIDGE, 0), 1.0))
        return items
    for x in RIDGES:
        items.append(("WheatStubble", T(x, ON_RIDGE, 0), 1.0))
    ridges = (1,) if n == 1 else ((0, 2) if n == 2 else (0, 1, 2))
    for at in ridge_spots(n, ridges=ridges, seed=n + 40):
        items.append(("WheatSheaf", at, 1.05))
    return items


# ===========================================================================
# Potato: three bushy plants, yellowing when ready, the potatoes dug up in
# the furrows beside them


def potato_leaves(rng, cols):
    m = Mesh()
    m.add(tube([(0, -0.1, 0), (0, 0.6, 0)], [0.12, 0.08], 4, "stemDark"))
    count = 14
    for k in range(count):
        yaw = k / count * 360 + rng.uniform(-12, 12)
        high = k % 3 == 0
        y = rng.uniform(0.5, 0.9) if high else rng.uniform(0.15, 0.5)
        length = rng.uniform(0.95, 1.25)
        stalk_out = rng.uniform(0.15, 0.5)
        f = mul(T(0, y, 0), R("y", yaw), T(0, 0, stalk_out))
        m.add(leaf(length, length * 0.62, cols[k % len(cols)], segs=3, curl=rng.uniform(45, 75),
                   rise=rng.uniform(40, 70) if high else rng.uniform(15, 35), fold=0.3), f)
        m.add(tube([(0, 0.4, 0), apply(f, [(0, 0, 0)])[0]], [0.04, 0.035], 3, "stem"))
    return m


@mesh("PotatoPlant")
def potato_plant():
    rng = np.random.default_rng(seed_of("PotatoPlant"))
    return potato_leaves(rng, [("leaf", "leafDark"), ("leafLight", "leaf"), ("leafDark", "leafDeep")])


@mesh("PotatoPlantRipe")
def potato_plant_ripe():
    rng = np.random.default_rng(seed_of("PotatoPlant"))
    return potato_leaves(rng, [("yellowing", "olive"), ("yellowingLight", "yellowing"), ("olive", "yellowing")])


def potato(seed, radii):
    rng = np.random.default_rng(seed)

    def col(n):
        v = rng.random()
        if v < 0.07:
            return "potatoEye"
        if n[1] < -0.2 or v < 0.3:
            return "potatoDark"
        return "potatoLight" if n[1] > 0.5 else "potato"
    return blob(radii, col, rng=rng, sub=1, jitter=0.1).transformed(T(0, radii[1] * 0.9, 0))


@mesh("Potato1")
def potato1():
    return potato(11, (0.55, 0.36, 0.42))


@mesh("Potato2")
def potato2():
    return potato(12, (0.48, 0.34, 0.4))


@mesh("Potato3")
def potato3():
    return potato(13, (0.6, 0.38, 0.38))


def potato_patch(stage, n):
    ripe = stage == "Ripe"
    plant = "PotatoPlantRipe" if ripe else "PotatoPlant"
    rng = np.random.default_rng(70 + n)
    items = []
    for i, (x, z) in enumerate([(-3.2, -2.6), (0.0, 2.3), (3.2, -1.2)]):
        items.append((plant, mul(T(x, ON_RIDGE - 0.05, z), R("y", i * 97)), 1.3 if ripe else 1.0))
    if not ripe:
        return items
    # in the four furrows: the two between the ridges (fullest) and the two outside
    furrows = (-4.85, -1.6, 1.6, 4.85)
    order = (1, 2, 0, 3)
    per = [n // 4] * 4
    for k in range(n % 4):
        per[order[k]] += 1
    for f, x in enumerate(furrows):
        k = per[f]
        for i in range(k):
            z = -4.3 + (i + 0.5) * 8.6 / k + rng.uniform(-0.3, 0.3)
            items.append((f"Potato{(f + i) % 3 + 1}", mul(T(x + rng.uniform(-0.25, 0.25), -0.12, z), R("y", rng.uniform(0, 360)),
                                                         R("z", rng.uniform(-8, 8))), 1.15))
    return items


# ===========================================================================
# Lettuce: big rosettes, a pale heart wrapped in ruffled leaves


def ruffle(t):
    return math.sin(math.pi * min(t, 1.0)) ** 0.5 * (1 + 0.12 * math.sin(t * 14))


@mesh("Lettuce")
def lettuce():
    rng = np.random.default_rng(seed_of("Lettuce"))
    m = Mesh()
    m.add(blob((0.62, 0.55, 0.62), by_light(["lettuceDark", "lettuce", "lettuceHeart"], rng=rng), rng=rng, sub=1, jitter=0.08), T(0, 0.55, 0))
    for k in range(6):  # (cupped round the heart)
        yaw = k * 60 + rng.uniform(-10, 10)
        m.add(leaf(1.0, 1.0, ("lettuceHeart", "lettuce"), segs=3, shape=ruffle, curl=80, rise=78, fold=0.35), mul(T(0, 0.12, 0), R("y", yaw), T(0, 0, 0.3)))
    for k in range(8):  # (spreading out, ruffled)
        yaw = k * 45 + 22 + rng.uniform(-12, 12)
        cols = ("lettuce", "lettuceDark") if k % 2 else ("lettuceDark", "lettuceDeep")
        m.add(leaf(1.45, 1.35, cols, segs=4, shape=ruffle, curl=95, rise=50, fold=0.25), mul(T(0, 0.05, 0), R("y", yaw), T(0, 0, 0.35)))
    return m


def lettuce_patch(stage, n):
    ripe = stage == "Ripe"
    items = []
    for at in diamond(n if ripe else 4, seed=20 + n):
        items.append(("Lettuce", mul(at, T(0, -0.1, 0)), 1.1 if ripe else 0.6))
    return items


def diamond(n, seed=0):
    """n plants staggered over the three ridges: the middle ridge takes the
    most, the outer ones sit between its plants."""
    mid = (n + 1) // 2
    outer = n - mid
    left, right = (outer + 1) // 2, outer // 2
    zs = [-ROW / 2 + (i + 0.5) * ROW / mid for i in range(mid)]
    between = [(zs[i] + zs[i + 1]) / 2 for i in range(mid - 1)] or [0.0]

    def outer_z(k, order):
        if k <= len(between):
            return [order[i] for i in range(k)]
        return [-ROW / 2 + (i + 0.5) * ROW / k for i in range(k)]
    rng = np.random.default_rng(seed)
    out = []
    for r, row in ((1, zs), (0, outer_z(left, between)), (2, outer_z(right, between[::-1]))):
        for z in row:
            jitter = rng.uniform(-0.12, 0.12, size=2)
            out.append(mul(T(RIDGES[r] + jitter[0], ON_RIDGE, z + jitter[1]), R("y", rng.uniform(0, 360))))
    return out


# ===========================================================================
# Corn: tall stalks with arching strap leaves and a tassel, cobs standing
# out of their husks


def strap(t):
    return (1 - t) ** 0.6 * min(1.0, 0.45 + t * 4)


def corn_plant(height, leaves, tassel, seed):
    rng = np.random.default_rng(seed)
    m = Mesh()
    path = [(0, -0.2, 0), (0.04, height * 0.5, -0.02), (0, height, 0)]
    m.add(tube(path, [0.2, 0.15, 0.07], 5, lambda i, k: "cornStalk" if k % 2 else "stem"))
    for j in range(leaves):
        y = 0.5 + j * (height * 0.8 - 0.5) / (leaves - 1)
        yaw = (j % 2) * 180 + j * 23 + rng.uniform(-15, 15)
        length = (2.9 if height > 5 else 2.0) * (1 - 0.35 * j / leaves)
        cols = ("leaf", "leafDark") if j % 2 else ("leafLight", "leaf")
        m.add(leaf(length, 0.6, cols, segs=5, shape=strap, curl=110, rise=48, fold=0.3), mul(T(0, y, 0), R("y", yaw), T(0, 0, 0.1)))
    if tassel:
        top = np.array([0, height, 0])
        m.add(tube([top - [0, 0.1, 0], top + [0, 0.9, 0]], [0.06, 0.02], 3, "tassel"))
        for k in range(6):
            a = k / 6 * 2 * math.pi + 0.3
            out = np.array([math.cos(a), 0, math.sin(a)])
            base = top + [0, 0.25 + 0.08 * k, 0]
            m.add(tube(curve([base, base + out * 0.35 + [0, 0.25, 0], base + out * 0.75 + [0, 0.05, 0]], n=2), [0.04, 0.03, 0.025, 0.02, 0.01],
                       3, "tassel" if k % 2 else "tasselDark"))
    for j, (h, yaw) in enumerate(((0.36, 20), (0.5, 200), (0.62, 300))):
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        origin = np.array([0, height * h, 0]) + out * 0.12
        m.point("Fruit", frame(origin, unit(out * 0.45 + [0, 1, 0]), out))
    return m


@mesh("CornStalk")
def corn_stalk():
    return corn_plant(7.0, 9, True, seed_of("CornStalk"))


@mesh("CornYoung")
def corn_young():
    return corn_plant(3.6, 6, False, seed_of("CornYoung"))


@mesh("CornCob")
def corn_cob():
    """A cob from its base (+Y): kernels in rows, the husk folded back
    round its lower half, a tuft of silk."""
    m = Mesh()
    m.add(tube([(0, -0.05, 0), (0, 0.3, 0)], [0.11, 0.12], 5, "husk"))
    rings = [(0.2, 0.18)] + [(0.3 + i * 0.16, 0.3 - 0.012 * max(0, i - 4) ** 1.6) for i in range(10)] + [(1.95, 0.0)]
    m.add(lathe(rings, 8, lambda i, k, n: ("kernel", "kernelDark", "kernelLight")[(i + k) % 2 + (1 if n[1] > 0.6 else 0)]))
    for k in range(5):
        cols = ("husk", "huskLight") if k % 2 else ("huskLight", "husk")
        m.add(leaf(1.3, 0.55, cols, segs=3, curl=30, rise=82, fold=0.55), mul(T(0, 0.2, 0), R("y", k * 72 + 10), T(0, 0, 0.2)))
    top = np.array([0, 1.95, 0])
    for k in range(4):
        a = k * math.pi / 2
        d = np.array([math.cos(a), 0, math.sin(a)])
        m.tri(top - d * 0.04, top + d * 0.04, top + d * 0.28 + [0, 0.3, 0], "silk", double=True)
    return m


def corn_patch(stage, n):
    items = []
    if stage == "Growing":
        for at in ridge_spots(3, seed=5):
            items.append(("CornYoung", at, 1.0))
        return items
    stalks = max(1, math.ceil(n / 2))
    left = n
    for i, at in enumerate(ridge_spots(stalks, seed=50 + n)):
        cobs = left if i == stalks - 1 else min(2, left)
        left -= cobs
        items.append(("CornStalk", at, 1.0))
        fruit_on(items, "CornStalk", at, 1.0, "CornCob", cobs, 1.35)
    return items


# ===========================================================================
# Onion: golden bulbs half out of the ridge, their tops flopped over


@mesh("OnionBulb")
def onion_bulb():
    profile = [(0.0, 0.0), (0.04, 0.2), (0.16, 0.4), (0.36, 0.53), (0.58, 0.52), (0.78, 0.4), (0.95, 0.22), (1.08, 0.11), (1.24, 0.07)]

    def col(i, k, n):
        if i >= 6:
            return "onionNeck"
        if i == 0:
            return "onionDark"
        return ("onion", "onionLight", "onion", "onionDark")[k % 4] if i > 1 else "onionDark"
    m = lathe(profile, 8, col, spin=0.2)
    for k in range(6):
        a = k / 6 * 2 * math.pi
        d = np.array([math.cos(a), 0, math.sin(a)])
        m.tri(d * 0.04 + [0, 0.02, 0], -d * 0.04 + [0, 0.02, 0], d * 0.22 + [0, -0.25, 0], "onionRoot", double=True)
    return m


def onion_leaves(seed, flop, cols):
    rng = np.random.default_rng(seed)
    m = Mesh()
    count = 3 if flop else 5
    for k in range(count):
        a = k / count * 2 * math.pi + rng.uniform(-0.3, 0.3)
        out = np.array([math.cos(a), 0, math.sin(a)])
        if flop:
            pts = [(0, 0, 0), out * 0.08 + [0, 0.45, 0], out * 0.55 + [0, 0.7, 0], out * 1.2 + [0, 0.35, 0], out * 1.65 + [0, 0.02, 0]]
        else:
            h = rng.uniform(1.5, 2.0)
            pts = [(0, 0, 0), out * 0.08 + [0, h * 0.5, 0], out * 0.35 + [0, h * 0.9, 0], out * 0.6 + [0, h * 0.95, 0]]
        path = curve(pts, n=2)
        m.add(tube(path, np.linspace(0.1, 0.035, len(path)), 4, cols[k % len(cols)]))
    return m


@mesh("OnionTops")
def onion_tops():
    return onion_leaves(seed_of("OnionTops"), True, ("yellowing", "olive", "yellowingLight"))


@mesh("OnionLeaves")
def onion_green():
    return onion_leaves(seed_of("OnionLeaves"), False, ("leaf", "stem", "leafLight"))


def onion_patch(stage, n):
    items = []
    if stage == "Growing":
        for at in ridge_spots(7, seed=9):
            items.append(("OnionLeaves", mul(at, T(0, -0.05, 0)), 1.3))
        return items
    for at in ridge_spots(n, seed=30 + n):
        bulb = mul(at, T(0, -0.4, 0))
        items.append(("OnionBulb", bulb, 1.25))
        items.append(("OnionTops", mul(bulb, T(0, 1.24 * 1.25, 0)), 1.0))
    return items


# ===========================================================================
# Strawberry: low plants of three-part leaves, berries hanging over the edge
# (a punnet's worth a plant); white flowers between pickings


@mesh("StrawberryPlant")
def strawberry_plant():
    rng = np.random.default_rng(seed_of("StrawberryPlant"))
    m = Mesh()
    stalks = 7
    for k in range(stalks):
        a = k / stalks * 2 * math.pi + rng.uniform(-0.2, 0.2)
        out = np.array([math.cos(a), 0, math.sin(a)])
        reach, high = rng.uniform(0.45, 0.75), rng.uniform(0.55, 0.85)
        end = out * reach + [0, high, 0]
        m.add(tube(curve([(0, 0, 0), out * reach * 0.3 + [0, high * 0.8, 0], end], n=2), [0.05, 0.045, 0.04, 0.035, 0.03], 3, "stem"))
        yaw = math.degrees(math.atan2(out[0], out[2]))
        for j, turn in enumerate((-50, 0, 50)):
            cols = ("leaf", "leafDark") if (j + k) % 2 else ("leafLight", "leaf")
            m.add(leaf(0.62, 0.5, cols, segs=2, shape=lambda t: math.sin(math.pi * min(t, 1)) ** 0.6, curl=35, rise=12, fold=0.3),
                  mul(T(*end), R("y", yaw + turn)))
    for j, yaw in enumerate((40, 160, 280)):
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        tip = out * 0.95 + [0, 0.32, 0]
        m.add(tube(curve([(0, 0, 0), out * 0.4 + [0, 0.5, 0], tip], n=2), [0.035] * 5, 3, "stem"))
        m.point("Fruit", hang_frame(tip, out, droop=0.3))
    return m


@mesh("Strawberry")
def strawberry():
    """A berry hanging from its calyx (the origin) down -Y."""
    rng = np.random.default_rng(seed_of("Strawberry"))
    profile = [(-0.82, 0.0), (-0.7, 0.13), (-0.5, 0.26), (-0.28, 0.34), (-0.1, 0.33), (0.0, 0.22), (0.02, 0.0)]

    def col(i, k, n):
        if rng.random() < 0.14 and i < 5:
            return "seed"
        return "berryLight" if n[0] > 0.3 else ("berryDark" if n[0] < -0.4 else "berry")
    m = lathe(profile, 8, col)
    for k in range(5):
        a = k / 5 * 2 * math.pi
        d = np.array([math.cos(a), 0, math.sin(a)])
        side = np.array([-d[2], 0, d[0]])
        m.tri(side * 0.07 + [0, 0.03, 0], -side * 0.07 + [0, 0.03, 0], d * 0.34 + [0, -0.08, 0], "calyx", double=True)
    m.add(tube([(0, 0.0, 0), (0, 0.14, 0)], [0.04, 0.035], 3, "stem"))
    return m


@mesh("StrawberryFlower")
def strawberry_flower():
    m = Mesh()
    for k in range(5):
        m.add(leaf(0.22, 0.2, ("petal", "petalShade"), segs=2, shape=lambda t: math.sin(math.pi * min(t, 1)) ** 0.4, fold=0.1),
              mul(R("y", k * 72), T(0, 0, 0.04)))
    m.add(gem(0.07, "flowerEye", h=0.04))
    return m.transformed(mul(T(0, -0.05, 0), R("x", -30)))


def strawberry_patch(stage, n):
    ripe = stage == "Ripe"
    items = []
    for at in diamond(n if ripe else 4, seed=60 + n):
        plant = mul(at, T(0, -0.05, 0))
        items.append(("StrawberryPlant", plant, 1.2))
        fruit_on(items, "StrawberryPlant", plant, 1.2, "Strawberry" if ripe else "StrawberryFlower", 3, 1.1 if ripe else 1.6)
    return items


# ===========================================================================
# Tomato: leafy plants tied to stakes, tomatoes hanging off them in the open


@mesh("TomatoPlant")
def tomato_plant():
    rng = np.random.default_rng(seed_of("TomatoPlant"))
    m = Mesh()
    m.add(box((0.2, 5.0, 0.2), lambda n: "woodLight" if n[0] > 0.5 else "wood"), T(0.28, 2.2, 0))
    stem = [(0, -0.1, 0), (0.06, 1.2, -0.05), (-0.04, 2.4, 0.06), (0.05, 3.6, -0.04), (0.02, 4.4, 0)]
    m.add(tube(curve(stem, n=2), np.linspace(0.13, 0.06, 9), 5, "stem"))
    for y in (1.3, 2.7, 3.9):
        m.add(lathe([(y - 0.06, 0.26), (y + 0.06, 0.26)], 6, "twine", cap=False), T(0.14, 0, 0))
    fruit = ((1.3, 30), (2.1, 150), (2.9, 270), (3.6, 80))
    yaws = [y for _, y in fruit]
    k = 0
    for j in range(15):
        h = 0.55 + j * 0.27
        yaw = j * 137.5 % 360
        if min(abs((yaw - f + 180) % 360 - 180) for f in yaws) < 24:
            yaw += 48
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        base = np.array([0, h, 0])
        reach = 0.75 - 0.3 * (j / 15)
        end = base + out * reach + [0, 0.2, 0]
        m.add(tube([base, end], [0.05, 0.035], 3, "stem"))
        size = 1.3 - 0.45 * (j / 15)
        for t, turn in enumerate((-60, 0, 60)):
            cols = ("leaf", "leafDark") if (j + t) % 2 else ("leafLight", "leaf")
            m.add(leaf(size if turn == 0 else size * 0.75, size * 0.62, cols, segs=3, shape=ruffle, curl=60, rise=25, fold=0.3),
                  mul(T(*end), R("y", 90 - yaw + turn)))
        k += 1
    for h, yaw in fruit:
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        start = np.array([0, h + 0.2, 0])
        tip = start + out * 1.6 + [0, -0.2, 0]
        m.add(tube(curve([start, start + out * 0.6 + [0, 0.1, 0], tip], n=2), [0.04] * 5, 3, "stem"))
        m.point("Fruit", hang_frame(tip, out, droop=0.9))
    return m


@mesh("Tomato")
def tomato():
    """A tomato hanging from its calyx (the origin) down -Y."""
    profile = [(-0.84, 0.0), (-0.8, 0.2), (-0.66, 0.38), (-0.44, 0.46), (-0.22, 0.44), (-0.06, 0.34), (0.0, 0.16), (0.0, 0.0)]

    def col(i, k, n):
        return "tomatoLight" if n[1] > 0.3 or n[0] > 0.55 else ("tomatoDark" if n[1] < -0.5 else "tomato")
    m = lathe(profile, 12, col, lobe=lambda th: 1 - 0.07 * (1 - abs(math.cos(3 * th))))
    for k in range(5):
        a = k / 5 * 2 * math.pi
        d = np.array([math.cos(a), 0, math.sin(a)])
        side = np.array([-d[2], 0, d[0]])
        m.tri(side * 0.06 + [0, 0.02, 0], -side * 0.06 + [0, 0.02, 0], d * 0.3 + [0, -0.06, 0], "calyx", double=True)
    m.add(tube([(0, 0.0, 0), (0, 0.16, 0)], [0.045, 0.04], 3, "stem"))
    return m


@mesh("TomatoFlower")
def tomato_flower():
    m = Mesh()
    for k in range(5):
        m.add(leaf(0.3, 0.14, ("flowerEye", "pepper"), segs=2, fold=0.0, rise=-25), mul(R("y", k * 72)))
    m.add(gem(0.07, "pepperDark", h=0.08))
    return m


def tomato_patch(stage, n):
    ripe = stage == "Ripe"
    items = []
    left = n
    spots = [mul(T(RIDGES[r], ON_RIDGE - 0.05, z), R("y", yaw)) for r, z, yaw in ((0, -2.4, 10), (1, 2.2, 130), (2, -1.0, 250))]
    for p, at in enumerate(spots):
        count = (math.ceil(left / (3 - p))) if ripe else 3
        left -= count if ripe else 0
        items.append(("TomatoPlant", at, 1.0))
        fruit_on(items, "TomatoPlant", at, 1.0, "Tomato" if ripe else "TomatoFlower", count, 1.05 if ripe else 1.6)
    return items


# ===========================================================================
# Bell pepper: compact bushes of glossy leaves, big blocky yellow peppers
# hanging off their edges


@mesh("PepperPlant")
def pepper_plant():
    rng = np.random.default_rng(seed_of("PepperPlant"))
    m = Mesh()
    fork = np.array([0, 0.9, 0])
    m.add(tube([(0, -0.1, 0), fork], [0.14, 0.11], 5, "stemDark"))
    tips = []
    for b in range(4):
        a = b / 4 * 2 * math.pi + 0.4
        out = np.array([math.cos(a), 0, math.sin(a)])
        tip = fork + out * 0.7 + [0, 1.3, 0]
        m.add(tube([fork, fork + out * 0.35 + [0, 0.7, 0], tip], [0.09, 0.07, 0.04], 4, "stem"))
        tips.append((tip, out))
    for j in range(34):
        tip, out = tips[j % 4]
        t = rng.uniform(-0.55, 1.0)
        base = fork + (tip - fork) * t if t > 0 else np.array([0, 0.35 + (t + 0.55) * 1.0, 0])
        yaw = rng.uniform(0, 360)
        cols = ("leaf", "leafDark") if j % 3 else ("leafLight", "leaf")
        m.add(leaf(rng.uniform(0.85, 1.1), 0.55, cols, segs=3, curl=rng.uniform(30, 60), rise=rng.uniform(5, 45), fold=0.25),
              mul(T(*base), R("y", yaw)))
    for j, yaw in enumerate((20, 140, 260)):
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        start = fork + [0, 0.3, 0]
        tip = start + out * 1.25 + [0, 0.1, 0]
        m.add(tube(curve([start, start + out * 0.7 + [0, 0.25, 0], tip], n=2), [0.05] * 5, 3, "stem"))
        m.point("Fruit", hang_frame(tip, out, droop=1.0))
    return m


@mesh("BellPepper")
def bell_pepper():
    """A bell pepper hanging from its stem (the origin) down -Y: four lobes,
    a flat shoulder, a thick curved stem."""
    profile = [(-1.18, 0.0), (-1.14, 0.22), (-1.0, 0.42), (-0.7, 0.52), (-0.35, 0.53), (-0.12, 0.47), (-0.02, 0.3), (0.0, 0.0)]

    def col(i, k, n):
        if n[1] > 0.35 or n[0] > 0.55:
            return "pepperLight"
        return "pepperDark" if n[1] < -0.45 or n[0] < -0.6 else "pepper"
    m = lathe(profile, 16, col, lobe=lambda th: 1 - 0.16 * (1 - abs(math.cos(2 * th))) ** 1.5)
    m.add(lathe([(-0.02, 0.2), (0.06, 0.16), (0.08, 0.0)], 6, "pepperStem"))
    m.add(tube(curve([(0, 0.0, 0), (0.02, 0.22, 0), (0.12, 0.38, 0)], n=2), [0.09, 0.085, 0.08, 0.075, 0.07], 5, "pepperStem", cap1=True))
    return m


def pepper_patch(stage, n):
    ripe = stage == "Ripe"
    items = []
    left = n
    spots = [mul(T(RIDGES[r], ON_RIDGE - 0.05, z), R("y", yaw)) for r, z, yaw in ((0, -2.5, 15), (1, 2.3, 140), (2, -0.9, 260))]
    for p, at in enumerate(spots):
        count = math.ceil(left / (3 - p)) if ripe else 0
        left -= count
        items.append(("PepperPlant", at, 1.15))
        fruit_on(items, "PepperPlant", at, 1.15, "BellPepper", count, 1.1)
    return items


# ===========================================================================
# Pumpkin and watermelon: sprawling vines of big leaves round the fruit


def vine(seed, cols, leaf_len=2.4, lobes=5, sinus=0.55, leaves=8, runner="vine", reach=4.6):
    """Runners snaking out over the ground from the middle, big leaves on
    stalks along them (kept off the middle and the ±Z line, where the
    fruit lies)."""
    rng = np.random.default_rng(seed)
    m = Mesh()
    for r in range(4):
        a = r / 4 * 2 * math.pi + 0.5 + rng.uniform(-0.2, 0.2)
        pts = []
        for t in np.linspace(0, 1, 6):
            wig = math.sin(t * 7 + r) * 0.5
            ang = a + wig * 0.35
            pts.append(np.array([math.cos(ang) * (0.6 + reach * t), 0.12, math.sin(ang) * (0.6 + reach * t)]))
        m.add(tube(curve(pts, n=2), [0.1] * 11, 4, runner))
        # a curly tendril near its end
        end = pts[-2]
        coil = [end + [math.cos(t) * 0.18, 0.12 + t * 0.03, math.sin(t) * 0.18] for t in np.linspace(0, 4 * math.pi, 12)]
        m.add(tube(coil, [0.03] * 12, 3, runner))
    for j in range(leaves):
        a = j / leaves * 2 * math.pi + rng.uniform(-0.15, 0.15)
        # (away from the ±Z line the fruit lies along)
        if abs(math.cos(a - math.pi / 2)) > 0.93:
            a += 0.45
        d = rng.uniform(2.7, reach)
        base = np.array([math.cos(a) * d, 0.1, math.sin(a) * d])
        high = rng.uniform(0.7, 1.2)
        top = base + [0, high, 0]
        m.add(tube([base, base + [0, high * 0.6, 0], top], [0.07, 0.06, 0.05], 3, runner))
        yaw = rng.uniform(0, 360)
        size = leaf_len * rng.uniform(0.85, 1.1)
        c = cols[j % len(cols)]
        m.add(palm_leaf(size, size * 1.05, c, lobes=lobes, sinus=sinus, cup=0.25),
              mul(T(*top), R("y", yaw), R("x", rng.uniform(-18, -6)), T(0, 0, -size * 0.15)))
    return m


@mesh("PumpkinVine")
def pumpkin_vine():
    return vine(seed_of("PumpkinVine"), [("leaf", "leafDark"), ("leafLight", "leaf"), ("leafDark", "leafDeep")], sinus=0.7)


@mesh("MelonVine")
def melon_vine():
    return vine(seed_of("MelonVine"), [("leaf", "leafDark"), ("leafDark", "leafDeep")], leaf_len=2.0, lobes=5, sinus=0.45, leaves=10)


def pumpkin_body(width, height, cols, ribs=10, sides=40):
    """A ribbed pumpkin standing on the origin, `width` across."""
    r = width / 2
    h = height
    profile = [(0.0, 0.0), (h * 0.03, r * 0.3), (h * 0.1, r * 0.62), (h * 0.24, r * 0.88), (h * 0.42, r), (h * 0.62, r * 0.96),
               (h * 0.8, r * 0.8), (h * 0.93, r * 0.5), (h, r * 0.24), (h * 0.96, r * 0.08), (h * 0.92, 0.0)]
    light, base, dark = cols
    per = sides // ribs

    def col(i, k, n):
        if k % per == per // 2:
            return dark
        return light if (n[1] > 0.45 or k % per == 0) else base
    return lathe(profile, sides, col, lobe=lambda th: 1 - 0.12 * (1 - abs(math.cos(ribs * th / 2))) ** 0.8, cap=False)


def pumpkin_stem(m, top, cols, curl=1.0):
    path = curve([top - [0, 0.12, 0], top + [0.05, 0.35, 0], top + [0.25 * curl, 0.7, 0.05], top + [0.5 * curl, 0.78, 0.1]], n=2)
    m.add(tube(path, np.linspace(0.22, 0.12, len(path)), 5, lambda i, k: cols[k % 2], cap1=True))


@mesh("Pumpkin")
def pumpkin():
    m = pumpkin_body(3.7, 2.55, ("pumpkinLight", "pumpkin", "pumpkinDark"))
    pumpkin_stem(m, np.array([0, 2.35, 0]), ("pumpkinStem", "pumpkinStemDark"))
    return m


@mesh("PumpkinYoung")
def pumpkin_young():
    m = pumpkin_body(3.7, 2.55, ("leafLight", "leaf", "leafDark"))
    pumpkin_stem(m, np.array([0, 2.35, 0]), ("stem", "stemDark"))
    return m


@mesh("Watermelon")
def watermelon():
    """A long striped melon lying along Z on the origin."""
    L, r = 4.5, 1.5
    profile = [(-L / 2, 0.0), (-L * 0.46, r * 0.45), (-L * 0.38, r * 0.78), (-L * 0.24, r * 0.95), (-L * 0.08, r), (L * 0.08, r),
               (L * 0.24, r * 0.95), (L * 0.38, r * 0.78), (L * 0.46, r * 0.45), (L / 2, 0.0)]

    def col(i, k, n):
        if i in (0, len(profile) - 2):
            return "melonLight"
        band = k % 3
        if band == 0 or (band == 1 and i % 2):
            return "melonStripe" if n[1] > 0.3 else "melonStripeDark"
        return "melonLight" if n[1] > 0.5 else "melon"
    m = lathe(profile, 24, col, squash=(1.0, 0.92))
    return m.transformed(mul(T(0, r * 0.92 - 0.12, 0), R("x", 90)))


def big_patch(vine_name, fruit, gap, s=1.0, young=None):
    def build(stage, n):
        items = [(vine_name, T(0, 0, 0), 1.0)]
        if stage != "Ripe":
            items.append((young or fruit, mul(T(0.4, 0, 0.3), R("y", 30)), 0.4 * s))
            return items
        if n == 1:
            items.append((fruit, mul(T(0, -0.1, 0), R("y", 25)), s))
        else:
            for i in range(n):
                items.append((fruit, mul(T(0.3 * (1 if i % 2 else -1), -0.1, (i - (n - 1) / 2) * gap), R("y", 25 + i * 60)), s * 0.85))
        return items
    return build


# ===========================================================================
# Blueberry: a leafy bush with clusters of berries all over the outside (a
# punnet's worth each)


@mesh("BlueberryBush")
def blueberry_bush():
    rng = np.random.default_rng(seed_of("BlueberryBush"))
    m = Mesh()
    for k in range(5):
        a = k / 5 * 2 * math.pi
        out = np.array([math.cos(a), 0, math.sin(a)])
        m.add(tube([(0, -0.1, 0), out * 0.4 + [0, 0.9, 0], out * 0.9 + [0, 1.8, 0]], [0.1, 0.07, 0.05], 4, "bark"))
    clumps = [((0, 2.0, 0), (1.6, 1.3, 1.6))]
    for k in range(6):
        a = k / 6 * 2 * math.pi + 0.3
        clumps.append(((math.cos(a) * 1.15, rng.uniform(1.1, 1.8), math.sin(a) * 1.15), (1.05, 0.95, 1.05)))
    for k in range(4):
        a = k / 4 * 2 * math.pi + 0.8
        clumps.append(((math.cos(a) * 0.9, 0.6, math.sin(a) * 0.9), (0.75, 0.6, 0.75)))
    clumps.append(((0.2, 3.0, -0.1), (1.0, 0.8, 1.0)))
    for c, r in clumps:
        leafy(m, rng, c, r, int(10 * r[0]), 0.7, ["blueLeafDark", "blueLeafDark", "blueLeaf"],
              [("blueLeaf", "blueLeafDark"), ("leaf", "blueLeaf"), ("blueLeafDark", "leafDark")])
    for j in range(6):
        a = j / 6 * 2 * math.pi + 0.55
        out = np.array([math.cos(a), 0, math.sin(a)])
        y = (1.2, 2.3, 1.6, 2.6, 1.3, 2.0)[j]
        r = 2.3 if y < 2.4 else 2.0
        m.point("Fruit", hang_frame(out * r + [0, y + 0.3, 0], out, droop=0.5))
    return m


@mesh("BlueberryCluster")
def blueberry_cluster():
    """Six berries hanging in a bunch from a short stalk (the origin)."""
    rng = np.random.default_rng(seed_of("BlueberryCluster"))
    m = Mesh()
    spots = [(0, -0.3, 0), (0.3, -0.42, 0.1), (-0.25, -0.45, 0.15), (0.05, -0.5, -0.3), (0.15, -0.75, 0.05), (-0.18, -0.72, -0.1)]
    m.add(tube([(0, 0.05, 0), (0, -0.3, 0)], [0.03, 0.03], 3, "bark"))
    for i, (x, y, z) in enumerate(spots):
        r = 0.22 + 0.02 * (i % 2)
        m.add(blob((r, r * 0.92, r), by_light(["blueDark", "blue", "blueDusty"], under="blueDark", rng=rng), rng=rng, sub=0, jitter=0.0), T(x, y, z))
        m.add(lathe([(-0.02, 0.0), (0.0, 0.08), (0.02, 0.0)], 5, "blueCrown"), T(x, y - r * 0.9, z))
    return m


def blueberry_patch(stage, n):
    ripe = stage == "Ripe"
    items = [("BlueberryBush", T(0, 0, 0), 1.25)]
    if ripe:
        fruit_on(items, "BlueberryBush", items[0][1], 1.25, "BlueberryCluster", n, 1.35)
    return items


# ===========================================================================
# Pineapple: a rosette of stiff sword leaves, the fruit standing in it under
# its own crown


def sword(t):
    return (1 - t) ** 0.8 * min(1.0, 0.6 + t * 5)


@mesh("PineapplePlant")
def pineapple_plant():
    rng = np.random.default_rng(seed_of("PineapplePlant"))
    m = Mesh()
    for k in range(26):
        yaw = k * 137.5 % 360 + rng.uniform(-8, 8)
        inner = k % 3 == 0
        cols = [("pineLeaf", "pineLeafDark"), ("pineLeafDark", "pineLeaf"), ("pineLeaf", "pineLeafRed")][k % 3]
        m.add(leaf(rng.uniform(2.0, 2.6) if not inner else rng.uniform(1.6, 2.0), 0.36, cols, segs=4, shape=sword,
                   curl=rng.uniform(25, 45), rise=rng.uniform(55, 70) if inner else rng.uniform(25, 45), fold=0.5),
              mul(T(0, 0.15, 0), R("y", yaw), T(0, 0, 0.15)))
    m.add(tube([(0, 0, 0), (0, 0.85, 0)], [0.16, 0.14], 5, "pineLeafDark"))
    m.point("Fruit", T(0, 0.8, 0))
    return m


@mesh("Pineapple")
def pineapple():
    """The fruit standing on the origin: a spindle of diamond-shaped eyes in
    spirals, a crown of stiff leaves."""
    rng = np.random.default_rng(seed_of("Pineapple"))
    rings = 9
    profile = [(0.0, 0.0)] + [(0.08 + 1.8 * (i / (rings - 1)), 0.66 * math.sin(math.pi * (0.12 + 0.8 * i / (rings - 1))) ** 0.6) for i in range(rings)] + [(1.95, 0.0)]
    sides = 10

    def col(i, k, n):
        if i == 0 or i == len(profile) - 2:
            return "pineDark"
        return ("pine", "pineDark")[(i + k) % 2] if rng.random() > 0.12 else "pineBrown"
    m = lathe(profile, sides, col, ring_spin=lambda i: (i % 2) * math.pi / sides)
    top = np.array([0, 1.88, 0])
    for k in range(14):
        yaw = k * 137.5 % 360
        h = 1 - k / 14
        cols = ("pineLeaf", "pineLeafDark") if k % 2 else ("pineLeafDark", "pineLeaf")
        m.add(leaf(0.7 + 0.55 * h, 0.26, cols, segs=3, shape=sword, curl=20 + 30 * (1 - h), rise=85 - 45 * (1 - h), fold=0.5),
              mul(T(*top), R("y", yaw), T(0, 0, 0.05)))
    return m


def pineapple_patch(stage, n):
    ripe = stage == "Ripe"
    items = []
    count = n if ripe else 2
    spots = {1: [(1, 0.0)], 2: [(0, -2.2), (2, 2.2)], 3: [(0, -2.4), (1, 1.9), (2, -1.0)]}.get(count) or [(r % 3, -3.5 + i * 7 / (count - 1)) for i, r in enumerate(range(count))]
    for i, (r, z) in enumerate(spots):
        # (the rosettes are wide: the outer two sit in from their ridges)
        at = mul(T(RIDGES[r] * 0.72, ON_RIDGE - 0.05, z), R("y", i * 70 + 15))
        items.append(("PineapplePlant", at, 1.4 if ripe else 1.0))
        if ripe:
            fruit_on(items, "PineapplePlant", at, 1.4, "Pineapple", 1, 0.95)
    return items


# ===========================================================================
# Cocoa: a small tree of big drooping leaves, the pods hanging off its trunk


@mesh("CocoaTree")
def cocoa_tree():
    """A short trunk forking into three, a dome of big drooping leaves (a few
    young red ones), pod stalks on the trunk below the fork."""
    rng = np.random.default_rng(seed_of("CocoaTree"))
    m = Mesh()
    fork = np.array([0.1, 2.7, -0.05])
    m.add(tube(curve([(0, -0.2, 0), (0.08, 1.4, 0.05), fork], n=2), np.linspace(0.5, 0.36, 5), 6,
               lambda i, k: ("bark", "barkDark", "barkLight")[(i + k) % 3]))
    for b in range(3):
        a = b / 3 * 2 * math.pi + 0.4
        out = np.array([math.cos(a), 0, math.sin(a)])
        end = fork + out * 1.5 + [0, 2.0, 0]
        m.add(tube(curve([fork, fork + out * 0.6 + [0, 1.0, 0], end], n=2), np.linspace(0.3, 0.1, 5), 5, "bark"))
    centre = np.array([0.1, 4.4, 0.0])
    for j in range(78):
        # (on a dome round the crown, each leaf pointing out and drooping)
        u = rng.uniform(0.0, 1.0)
        a = rng.uniform(0, 2 * math.pi)
        up = 1 - u * 1.25
        ring = math.sqrt(max(0.0, 1 - min(1.0, up) ** 2))
        out = np.array([math.cos(a), 0, math.sin(a)])
        base = centre + out * ring * 1.9 + [0, up * 1.3, 0]
        young = j % 11 == 0
        cols = ("cocoaLeafRed", "cocoaLeafRed") if young else (("cocoaLeaf", "leafDark") if j % 2 else ("cocoaLeafLight", "cocoaLeaf"))
        yaw = math.degrees(math.atan2(out[0], out[2]))
        m.add(leaf(rng.uniform(1.35, 1.8), 0.6, cols, segs=4, curl=rng.uniform(55, 95), rise=rng.uniform(-5, 35), fold=0.25),
              mul(T(*base), R("y", yaw + rng.uniform(-35, 35))))
    for j, (h, yaw) in enumerate(((1.6, 20), (2.2, 140), (1.3, 260), (2.4, 330), (1.9, 200), (1.1, 80))):
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        trunk_r = 0.5 - 0.14 * (h / 2.7)
        stalk = np.array([0.04 * h, h, 0.02 * h]) + out * (trunk_r - 0.04)
        m.add(tube([stalk - out * 0.1, stalk + out * 0.16], [0.06, 0.05], 4, "bark"))
        m.point("Fruit", hang_frame(stalk + out * 0.16, out, droop=1.0))
    return m


@mesh("CocoaPod")
def cocoa_pod():
    """A ridged pod hanging from its stalk (the origin) down -Y."""
    L, r = 1.6, 0.46
    profile = [(-L, 0.0), (-L * 0.9, r * 0.45), (-L * 0.72, r * 0.85), (-L * 0.5, r), (-L * 0.28, r * 0.92), (-L * 0.1, r * 0.6), (0.0, 0.1)]

    def col(i, k, n):
        if i >= 5:
            return "cocoaYellow"
        return ("cocoa", "cocoaDark")[k % 2] if i > 1 else ("cocoaRed", "cocoaDark")[k % 2]
    return lathe(profile, 10, col, lobe=lambda th: 1 - 0.1 * (1 - abs(math.cos(5 * th))))


def cocoa_patch(stage, n):
    at = mul(T(0, ON_RIDGE - 0.1, 0), R("y", 20))
    items = [("CocoaTree", at, 1.15)]
    if stage == "Ripe":
        fruit_on(items, "CocoaTree", at, 1.15, "CocoaPod", n, 0.92)
    return items


# ===========================================================================
# Dragonfruit: a climbing cactus up a post, its three-winged stems arching
# over the top and hanging down all round, pink fruit at their bends


def wings(path, width, col):
    """A cactus stem with three wings along `path` (star cross-section)."""
    radii = []
    m = Mesh()
    pts = [np.asarray(p, dtype=float) for p in path]
    t0 = unit(pts[1] - pts[0])
    side, up = perpendicular(t0)
    rings = []
    for i, p in enumerate(pts):
        t = unit(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        side = unit(side - t * np.dot(side, t))
        up = np.cross(side, t)
        w = width * (1 - 0.6 * (i / (len(pts) - 1)) ** 2)
        ring = []
        for k in range(6):
            a = 2 * math.pi * k / 6
            r = w if k % 2 == 0 else w * 0.32
            ring.append(p + (side * math.cos(a) + up * math.sin(a)) * r)
        rings.append(ring)
    for i in range(len(pts) - 1):
        inside = (pts[i] + pts[i + 1]) / 2
        for k in range(6):
            k2 = (k + 1) % 6
            m.quad(rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k], col(i, k), inside=inside)
    end = pts[-1] + unit(pts[-1] - pts[-2]) * 0.1
    for k in range(6):
        m.tri(rings[-1][k], rings[-1][(k + 1) % 6], end, col(len(pts) - 1, k), inside=pts[-1])
    del radii
    return m


@mesh("DragonfruitCactus")
def dragonfruit_cactus():
    rng = np.random.default_rng(seed_of("DragonfruitCactus"))
    m = Mesh()
    h = 3.9
    m.add(box((0.45, h + 0.4, 0.45), lambda n: "woodLight" if n[0] > 0.5 else ("woodDark" if n[2] > 0.5 else "wood")), T(0, h / 2 - 0.2, 0))
    m.add(lathe([(h - 0.05, 0.95), (h + 0.15, 0.95), (h + 0.15, 0.75), (h - 0.05, 0.75)], 10, "woodDark"))
    shade = lambda i, k: ("cactus", "cactusLight", "cactusDark")[(k // 2 + i) % 3]  # noqa: E731
    m.add(wings(curve([(0.38, 0, 0), (0.45, 1.4, 0.25), (0.36, 2.8, -0.12), (0.2, h + 0.1, 0.1)], n=2), 0.38, shade))
    m.add(wings(curve([(-0.34, 0, 0.22), (-0.42, 1.6, 0.05), (-0.25, h + 0.05, -0.15)], n=2), 0.36, shade))
    m.add(wings(curve([(0.05, 0, -0.4), (-0.1, 1.2, -0.45), (0.1, 2.6, -0.42), (0.0, h, -0.2)], n=2), 0.34, shade))
    stems = 10
    for k in range(stems):
        a = k / stems * 2 * math.pi + rng.uniform(-0.15, 0.15)
        out = np.array([math.cos(a), 0, math.sin(a)])
        top = np.array([0, h + 0.25, 0]) + out * 0.5
        drop = rng.uniform(1.4, 2.3)
        arc = [top, top + out * 0.8 + [0, 0.45, 0], top + out * 1.6 + [0, 0.2, 0], top + out * 2.0 + [0, -0.6, 0], top + out * 2.2 + [0, -drop, 0]]
        m.add(wings(curve(arc, n=2), 0.38, shade))
        m.point("Fruit", frame(top + out * 1.62 + [0, 0.35, 0], unit(out * 0.6 + [0, 1, 0]), out))
    return m


@mesh("Dragonfruit")
def dragonfruit():
    """The fruit standing on its base (the origin) along +Y: a pink oval with
    green-tipped scales curling out of it."""
    rng = np.random.default_rng(seed_of("Dragonfruit"))
    L, r = 1.35, 0.5
    profile = [(0.0, 0.1), (L * 0.1, r * 0.6), (L * 0.3, r * 0.95), (L * 0.55, r), (L * 0.78, r * 0.82), (L * 0.94, r * 0.45), (L, 0.0)]
    m = lathe(profile, 10, lambda i, k, n: "dragonLight" if n[1] > 0.4 or n[0] > 0.6 else ("dragonDark" if n[0] < -0.5 else "dragon"))
    for j in range(13):
        t = 0.2 + 0.75 * (j / 13)
        y = L * t
        rr = np.interp(y, [p[0] for p in profile], [p[1] for p in profile])
        a = j * 2.4
        out = np.array([math.cos(a), 0, math.sin(a)])
        yaw = math.degrees(math.atan2(out[0], out[2]))
        m.add(leaf(0.5, 0.3, ("dragon", "dragonDark") if j % 2 else ("dragonLight", "dragon"), segs=2, curl=-35, rise=50, fold=0.3),
              mul(T(*(out * rr * 0.85 + [0, y, 0])), R("y", yaw)))
        tip_base = out * (rr + 0.3) + [0, y + 0.33, 0]
        m.add(gem(0.07, "bract", h=0.12), T(*tip_base))
    return m


def dragonfruit_patch(stage, n):
    at = mul(T(0, ON_RIDGE - 0.1, 0), R("y", 10))
    items = [("DragonfruitCactus", at, 1.2)]
    if stage == "Ripe":
        fruit_on(items, "DragonfruitCactus", at, 1.2, "Dragonfruit", n, 1.0, order=(0, 4, 2, 6, 1, 5, 3, 7))
    return items


# ===========================================================================
# Grapes: a vine trained along a trellis, broad leaves along the top wire,
# bunches hanging under them


@mesh("GrapeTrellis")
def grape_trellis():
    rng = np.random.default_rng(seed_of("GrapeTrellis"))
    m = Mesh()
    for z in (-4.5, 4.5):
        m.add(box((0.4, 4.9, 0.4), lambda n: "woodLight" if n[0] > 0.5 else "wood"), T(0, 2.25, z))
    for y in (2.4, 4.2):
        m.add(tube([(0, y, -4.5), (0, y, 4.5)], [0.04, 0.04], 4, "wire"))
    trunk = curve([(0, -0.2, 0.3), (0.15, 1.3, -0.1), (-0.1, 2.6, 0.2), (0, 3.95, 0)], n=2)
    m.add(tube(trunk, np.linspace(0.22, 0.13, len(trunk)), 5, lambda i, k: ("bark", "barkDark")[(i + k) % 2]))
    for sign in (-1, 1):
        arm = curve([(0, 3.95, 0), (0.1, 4.15, sign * 1.5), (-0.05, 4.2, sign * 3.0), (0.05, 4.25, sign * 4.3)], n=2)
        m.add(tube(arm, np.linspace(0.13, 0.06, len(arm)), 5, "bark"))
    for j in range(30):
        z = -4.2 + (j + rng.uniform(0, 1)) * 8.4 / 30
        x = rng.uniform(-1.0, 1.0)
        base = np.array([x, 4.25 - 0.15 * abs(x), z])
        size = rng.uniform(1.3, 1.65)
        cols = [("vineLeaf", "vineLeafDark"), ("vineLeafLight", "vineLeaf"), ("vineLeafDark", "vineLeaf")][j % 3]
        m.add(palm_leaf(size, size * 1.05, cols, lobes=5, sinus=0.6, cup=0.2),
              mul(T(*base), R("y", rng.uniform(0, 360)), R("x", rng.uniform(-35, 35)), R("z", rng.uniform(-25, 25)), T(0, 0.12, -size * 0.3)))
    for j, z in enumerate((-2.9, 0.4, 3.0, -1.3, 1.9)):
        side = 1 if j % 2 else -1
        origin = np.array([0.6 * side, 3.95, z])
        m.add(tube([(0, 4.2, z), origin], [0.04, 0.04], 3, "bark"))
        m.point("Fruit", frame(origin, (0, 1, 0), (side, 0, 0)))
    return m


@mesh("GrapeBunch")
def grape_bunch():
    """A bunch hanging from its stalk (the origin): grapes in a cone, a
    curl of tendril."""
    rng = np.random.default_rng(seed_of("GrapeBunch"))
    m = Mesh()
    m.add(tube([(0, 0.05, 0), (0, -0.3, 0)], [0.04, 0.035], 3, "bark"))
    layers = [(5, 0.42, -0.35), (5, 0.36, -0.62), (4, 0.3, -0.88), (3, 0.22, -1.12), (2, 0.14, -1.34), (1, 0.0, -1.52)]
    r = 0.19
    for li, (count, ring, y) in enumerate(layers):
        for q in range(count):
            a = q / count * 2 * math.pi + li * 0.6
            m.add(blob((r, r * 1.08, r), by_light(["grapeDark", "grape", "grapeLight", "grapeBloom"], under="grapeDark", rng=rng), rng=rng, sub=0),
                  T(math.cos(a) * ring, y, math.sin(a) * ring))
        if li == 0:
            m.add(blob((r, r * 1.08, r), by_light(["grapeDark", "grape", "grapeLight"], rng=rng), rng=rng, sub=0), T(0, y + 0.05, 0))
    coil = [np.array([0.12 + math.cos(t) * 0.12, -0.05 - t * 0.02, math.sin(t) * 0.12]) for t in np.linspace(0, 3.5 * math.pi, 10)]
    m.add(tube(coil, [0.025] * 10, 3, "vineLeaf"))
    return m


def grape_patch(stage, n):
    at = T(0, ON_RIDGE - 0.15, 0)
    items = [("GrapeTrellis", at, 1.1)]
    if stage == "Ripe":
        fruit_on(items, "GrapeTrellis", at, 1.1, "GrapeBunch", n, 1.15)
    return items


# ===========================================================================
# Moonmelon: a pale round melon with glowing stripes among silvery leaves


def moon_profile(L=3.8, r=1.65):
    return [(-L / 2, 0.0), (-L * 0.46, r * 0.5), (-L * 0.36, r * 0.82), (-L * 0.2, r * 0.97), (0.0, r), (L * 0.2, r * 0.97),
            (L * 0.36, r * 0.82), (L * 0.46, r * 0.5), (L / 2, 0.0)]


MOON_SIDES = 24


@mesh("MoonVine")
def moon_vine():
    return vine(seed_of("MoonVine"), [("silver", "silverDark"), ("silverLight", "silver")], sinus=0.65, runner="silverDark")


@mesh("Moonmelon")
def moonmelon():
    def col(i, k, n):
        if k % 4 == 0:
            return "moonDark"
        return "moonLight" if n[1] > 0.45 else "moon"
    m = lathe(moon_profile(), MOON_SIDES, col, squash=(1.0, 0.94))
    m = m.transformed(mul(T(0, 1.65 * 0.94 - 0.15, 0), R("x", 90)))
    end = np.array([0, 1.65 * 0.94 - 0.15 + 0.35, 1.85])
    m.add(tube(curve([end - [0, 0, 0.2], end + [0, 0.25, 0.15], end + [0.15, 0.45, 0.4], end + [0.35, 0.35, 0.55]], n=2),
               np.linspace(0.16, 0.08, 7), 5, lambda i, k: ("silverDark", "silver")[k % 2], cap1=True))
    return m


@mesh("MoonmelonGlow", textured=False, material="Neon", colour=(214, 232, 255))
def moonmelon_glow():
    """The glowing stripes: bands just proud of the melon's dark stripes."""
    prof = [(y, r * 1.025) for y, r in moon_profile()]
    m = Mesh()
    sides = MOON_SIDES
    for k in range(0, sides, 4):
        for i in range(1, len(prof) - 2):
            (y0, r0), (y1, r1) = prof[i], prof[i + 1]
            pts = []
            for y, r in ((y0, r0), (y1, r1)):
                for dk in (-0.32, 0.32):
                    th = 2 * math.pi * (k + dk) / sides
                    pts.append(np.array([math.cos(th) * r, y, math.sin(th) * r * 0.94]))
            m.quad(pts[0], pts[1], pts[3], pts[2], "moonStripe", inside=np.array([0, (y0 + y1) / 2, 0]))
    return m.transformed(mul(T(0, 1.65 * 0.94 - 0.15, 0), R("x", 90)))


def moonmelon_patch(stage, n):
    items = [("MoonVine", T(0, 0, 0), 1.0)]
    if stage != "Ripe":
        items.append(("Moonmelon", mul(T(0.4, 0, 0.3), R("y", 30)), 0.4))
        return items
    for i in range(n):
        z = 0.0 if n == 1 else (i - (n - 1) / 2) * 3.6
        at = mul(T(0.3 * (1 if i % 2 else -1) if n > 1 else 0, -0.1, z), R("y", 90 + 20 + i * 40))
        s = 1.0 if n == 1 else 0.8
        items.append(("Moonmelon", at, s))
        items.append(("MoonmelonGlow", at, s))
    return items


# ===========================================================================
# Starfruit and golden apple: small fruit trees


def fruit_tree(seed, trunk_h, crown, shades, under, bark=("bark", "barkDark", "barkLight"), flat=0.78, spread=1.0):
    """A trunk, a few branches and a lumpy crown of leaf clumps; returns the
    mesh and the crown's clumps (centre, radii) for hanging fruit."""
    rng = np.random.default_rng(seed)
    m = Mesh()
    top = np.array([rng.uniform(-0.15, 0.15), trunk_h, rng.uniform(-0.15, 0.15)])
    m.add(tube(curve([(0, -0.2, 0), (0.08, trunk_h * 0.5, -0.05), top], n=2), np.linspace(0.42, 0.26, 5), 6,
               lambda i, k: bark[(i + k) % 3]))
    clumps = [(top + [0, crown * 0.7 * flat / 0.78, 0], np.array([crown, crown * flat, crown]))]
    for k in range(7):
        a = k / 7 * 2 * math.pi + rng.uniform(-0.2, 0.2)
        d = crown * rng.uniform(0.75, 0.95) * spread
        r = crown * rng.uniform(0.55, 0.68)
        c = top + [math.cos(a) * d, crown * rng.uniform(0.25, 0.75) * flat / 0.78, math.sin(a) * d]
        clumps.append((c, np.array([r, r * 0.82 * flat / 0.78, r])))
        m.add(tube([top, top + (c - top) * 0.75], [0.16, 0.06], 4, bark[0]))
    clumps.append((top + [rng.uniform(-0.3, 0.3), crown * 1.35, rng.uniform(-0.3, 0.3)], np.array([crown * 0.62, crown * 0.5, crown * 0.62])))
    for c, r in clumps:
        leafy(m, rng, c, r, int(6 * r[0]), 0.75, shades[:3], [(shades[1], shades[0]), (shades[2], shades[1]), (shades[3], shades[2])])
    return m, clumps


@mesh("StarfruitTree")
def starfruit_tree():
    m, clumps = fruit_tree(seed_of("StarfruitTree"), 3.1, 1.75, ["leafDeep", "leafDark", "leaf", "leafLight"], "leafDeep", flat=0.62, spread=1.25)
    for j in range(5):
        c, r = clumps[1 + (j * 3) % 7]
        out = unit((c - [0, c[1], 0]) + [1e-3, 0, 0])
        edge = c + out * r[0] * 0.92 - [0, r[1] * 0.45, 0]
        m.point("Fruit", hang_frame(edge, out, droop=0.05))
    return m


@mesh("Starfruit")
def starfruit():
    """A five-ribbed star fruit hanging from its stalk (the origin) down -Y."""
    L, r = 1.55, 0.55
    profile = [(-L, 0.0), (-L * 0.9, r * 0.5), (-L * 0.7, r * 0.88), (-L * 0.45, r), (-L * 0.2, r * 0.85), (-L * 0.06, r * 0.45), (0.0, 0.0)]

    def col(i, k, n):
        if i == 0 or i == len(profile) - 2:
            return "starEdge"
        return "starLight" if (k % 2 == 0 or n[1] > 0.3) else "star"
    m = lathe(profile, 10, col, lobe=lambda th: 0.42 + 0.58 * abs(math.cos(5 * th / 2)) ** 2)
    m.add(tube([(0, 0.0, 0), (0, 0.22, 0)], [0.05, 0.04], 3, "appleStem"))
    return m


@mesh("AppleTree")
def apple_tree():
    m, clumps = fruit_tree(seed_of("AppleTree"), 3.0, 2.05, ["leafDeep", "leafDark", "leaf", "leafLight"], "leafDeep")
    rng = np.random.default_rng(5)
    spots = []
    for j in range(8):
        c, r = clumps[1 + j % 7]
        out = unit((c - [0, c[1], 0]) + [1e-3, 0, 0])
        up = (0.35, -0.2, 0.1, -0.35, 0.25, -0.1, 0.0, -0.3)[j]
        p = c + out * r[0] * math.sqrt(1 - up * up) * 0.86 + [0, up * r[1] * 0.9, 0]
        spots.append(p)
        m.point("Fruit", hang_frame(p, out, droop=0.25))
    del rng, spots
    return m


@mesh("GoldenApple")
def golden_apple():
    """An apple hanging from its stem (the origin) down -Y: a dimple top and
    bottom, a stem and one leaf."""
    profile = [(-0.98, 0.0), (-0.95, 0.16), (-0.85, 0.4), (-0.62, 0.55), (-0.36, 0.57), (-0.14, 0.48), (-0.04, 0.3), (-0.1, 0.1), (-0.16, 0.0)]
    m = lathe(profile, 12, lambda i, k, n: "goldLight" if n[1] > 0.3 or n[0] > 0.55 else ("goldDark" if n[1] < -0.5 else "gold"))
    m.add(tube([(0, -0.16, 0), (0.03, 0.1, 0), (0.08, 0.22, 0)], [0.04, 0.035, 0.03], 4, "appleStem"))
    m.add(leaf(0.42, 0.22, ("leaf", "leafDark"), segs=3, curl=30, rise=25, fold=0.3), mul(T(0.04, 0.1, 0), R("y", 60)))
    return m


def tree_patch(tree, fruit, s=1.0, fruit_s=1.0):
    def build(stage, n):
        at = mul(T(0, ON_RIDGE - 0.1, 0), R("y", 25))
        items = [(tree, at, s)]
        if stage == "Ripe":
            fruit_on(items, tree, at, s, fruit, n, fruit_s)
        return items
    return build


# ===========================================================================
# Crystal Rose: one great rose of faceted crystal petals round a glowing
# heart, on a thorny stem, crystal shards at its foot


@mesh("CrystalRoseStem")
def crystal_rose_stem():
    return rose_stem(True)


@mesh("CrystalRoseCut")
def crystal_rose_cut():
    """The stem as a thief carries it: cut, no crystals round its foot."""
    return rose_stem(False)


def rose_stem(shards):
    rng = np.random.default_rng(seed_of("CrystalRoseStem"))
    m = Mesh()
    path = curve([(0, -0.2, 0), (0.25, 1.4, 0.1), (-0.15, 2.9, -0.1), (0.05, 4.3, 0.0)], n=3)
    m.add(tube(path, np.linspace(0.2, 0.15, len(path)), 6, lambda i, k: "roseLeaf" if k % 2 else "stemDark"))
    for j in range(7):  # thorns
        i = 1 + j * (len(path) - 3) // 7
        p = path[i]
        a = j * 2.3
        out = np.array([math.cos(a), 0, math.sin(a)])
        m.add(lathe([(0, 0.07), (0.22, 0.0)], 4, "thorn"), frame(p + out * 0.14, unit(out + [0, 0.5, 0])))
    for j, (t, yaw) in enumerate(((0.3, 30), (0.45, 200), (0.62, 110), (0.75, 290))):
        i = int(t * (len(path) - 1))
        base = path[i]
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        end = base + out * 0.6 + [0, 0.25, 0]
        m.add(tube([base, end], [0.06, 0.04], 4, "stemDark"))
        for q, turn in enumerate((-45, 0, 45)):
            cols = ("roseLeafLight", "roseLeaf") if q % 2 else ("roseLeaf", "leafDeep")
            m.add(leaf(0.85 if turn == 0 else 0.65, 0.5, cols, segs=3, curl=40, rise=10, fold=0.3), mul(T(*end), R("y", 90 - yaw + turn)))
    for j in range(6 if shards else 0):  # crystal shards round the foot
        a = j / 6 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        out = np.array([math.cos(a), 0, math.sin(a)])
        h = rng.uniform(0.6, 1.2)
        shard = lathe([(0, 0.18), (h * 0.75, 0.16), (h, 0.0)], 5, lambda i, k, n: ("crystal", "crystalLight", "crystalDark")[(k + i) % 3])
        m.add(shard, frame(out * rng.uniform(0.7, 1.1) + [0, -0.1, 0], unit(out * 0.5 + [0, 1, 0])))
    m.point("Bloom", frame(path[-1] + [0, -0.05, 0], unit(path[-1] - path[-3])))
    return m


def petal(m, centre, yaw, out, rise, length, width, cols, curl, cup):
    m.add(leaf(length, width, cols, segs=3, shape=lambda t: math.sin(math.pi * min(t * 0.85 + 0.08, 1)) ** 0.5, curl=curl, rise=rise, fold=cup),
          mul(T(*centre), R("y", yaw), T(0, 0, out)))


@mesh("CrystalRoseBloom")
def crystal_rose_bloom():
    """The bloom on the stem's top (the origin): rings of cupped crystal
    petals opening wider and lower ring by ring round a tight bud."""
    m = Mesh()
    m.add(lathe([(-0.4, 0.0), (-0.25, 0.32), (0.05, 0.4)], 6, "roseLeaf"))
    for k in range(5):  # green sepals under it
        m.add(leaf(0.75, 0.3, ("roseLeaf", "leafDeep"), segs=2, curl=50, rise=-10, fold=0.2), mul(T(0, -0.15, 0), R("y", k * 72 + 36), T(0, 0, 0.3)))
    rings = [(4, 0.05, 88, 0.85, 0.75, -25, 0.7), (5, 0.18, 82, 1.05, 0.85, -8, 0.6), (6, 0.36, 72, 1.25, 0.95, 12, 0.55),
             (7, 0.55, 56, 1.4, 1.05, 35, 0.5), (8, 0.72, 34, 1.5, 1.05, 65, 0.4)]
    shades = [("crystalLight", "crystal"), ("crystal", "crystalDark"), ("crystalLight", "crystalDark"), ("crystal", "crystalDeep")]
    for ri, (count, out, rise, length, width, curl, cup) in enumerate(rings):
        for k in range(count):
            yaw = k / count * 360 + ri * 23
            petal(m, (0, 0.05 + ri * 0.02, 0), yaw, out, rise, length, width, shades[(k + ri) % 4], curl, cup)
    return m


@mesh("CrystalRoseCore", textured=False, material="Neon", colour=(196, 240, 255))
def crystal_rose_core():
    return lathe([(0.0, 0.0), (0.25, 0.3), (0.65, 0.26), (0.95, 0.0)], 6, "crystalLight")


def crystal_rose_patch(stage, n):
    items = []
    count = n if stage == "Ripe" else 1
    for i in range(count):
        z = 0.0 if count == 1 else (i - (count - 1) / 2) * 4.6
        at = mul(T(0.4 if i % 2 else -0.4, ON_RIDGE - 0.1, z), R("y", 30 + i * 100))
        s = 1.35 if count == 1 else 1.15
        if stage != "Ripe":
            s *= 0.7
        items.append(("CrystalRoseStem", at, s))
        if stage == "Ripe":
            fruit_on(items, "CrystalRoseStem", at, s, "CrystalRoseBloom", 1, 1.0, key="Bloom")
            fruit_on(items, "CrystalRoseStem", at, s, "CrystalRoseCore", 1, 1.0, key="Bloom")
    return items


# ===========================================================================
# Phoenix Pepper: a dark bush with ember-red leaves, one great chilli curling
# out of its side from red at the stem to a glowing tip


@mesh("PhoenixBush")
def phoenix_bush():
    rng = np.random.default_rng(seed_of("PhoenixBush"))
    m = Mesh()
    fork = np.array([0, 0.9, 0])
    m.add(tube([(0, -0.1, 0), fork], [0.18, 0.14], 5, "barkDark"))
    tips = []
    for b in range(5):
        a = b / 5 * 2 * math.pi + 0.2
        out = np.array([math.cos(a), 0, math.sin(a)])
        tip = fork + out * 1.4 + [0, 1.4, 0]
        m.add(tube([fork, fork + out * 0.5 + [0, 0.9, 0], tip], [0.11, 0.08, 0.04], 4, "barkDark"))
        tips.append(tip)
    for j in range(46):
        tip = tips[j % 5]
        t = rng.uniform(-0.4, 1.0)
        base = fork + (tip - fork) * t if t > 0 else np.array([0, 0.4 + (t + 0.4) * 1.2, 0])
        cols = [("emberLeaf", "emberLeafDark"), ("emberLeafDark", "emberLeaf"), ("emberLeafRed", "emberLeaf"), ("emberLeaf", "leafDark")][j % 4]
        m.add(leaf(rng.uniform(1.0, 1.3), 0.5, cols, segs=3, curl=rng.uniform(25, 60), rise=rng.uniform(10, 50), fold=0.3),
              mul(T(*base), R("y", rng.uniform(0, 360))))
    for yaw in (25, 205):
        a = math.radians(yaw)
        out = np.array([math.cos(a), 0, math.sin(a)])
        start = fork + [0, 1.1, 0]
        tip = start + out * 1.7 + [0, 0.3, 0]
        m.add(tube(curve([start, start + out * 0.8 + [0, 0.25, 0], tip], n=2), [0.07] * 5, 4, "emberLeafDark"))
        m.point("Fruit", frame(tip, (0, 1, 0), out))
    return m


def phoenix_path():
    # from the calyx out and down, the tip curling up (in the fruit's frame: +Z out)
    return curve([(0, 0, 0), (0, -0.3, 0.5), (0, -0.75, 1.1), (0, -1.0, 1.8), (0, -0.85, 2.45), (0, -0.4, 2.85), (0, 0.15, 2.95)], n=3)


@mesh("PhoenixPepper")
def phoenix_pepper():
    path = phoenix_path()
    n = len(path)
    radii = [0.5 * (1 - (i / (n - 1)) ** 1.6) + 0.06 for i in range(n)]
    cut = n - 4  # (the last bit is the glowing tip)
    fire = ["fire1", "fire2", "fire3", "fire4", "fire5", "fire6"]
    m = tube(path[:cut + 1], radii[:cut + 1], 8, lambda i, k: fire[min(5, int(i / cut * 6))] if k % 3 else fire[max(0, min(5, int(i / cut * 6)) - 1)],
             cap0=True)
    m.add(lathe([(-0.05, 0.56), (0.1, 0.45), (0.2, 0.0)], 8, "emberLeafDark"), frame(path[0], unit(path[0] - path[1])))
    m.add(tube([(0, 0.15, 0), (0, 0.5, 0)], [0.1, 0.08], 5, "emberLeafDark"))
    return m


@mesh("PhoenixTip", textured=False, material="Neon", colour=(255, 196, 64))
def phoenix_tip():
    path = phoenix_path()
    n = len(path)
    radii = [0.5 * (1 - (i / (n - 1)) ** 1.6) + 0.06 for i in range(n)]
    cut = n - 4
    radii[-1] = 0.0
    return tube(path[cut:], radii[cut:], 8, "fire6")


def phoenix_patch(stage, n):
    items = []
    at = mul(T(0, ON_RIDGE - 0.1, 0), R("y", 40))
    items.append(("PhoenixBush", at, 1.55))
    if stage == "Ripe":
        fruit_on(items, "PhoenixBush", at, 1.55, "PhoenixPepper", n, 0.72)
        fruit_on(items, "PhoenixBush", at, 1.55, "PhoenixTip", n, 0.72)
    return items


# ===========================================================================
# Dragon's Eye Pumpkin: a great purple pumpkin with one glowing golden eye
# and a horned stem, on dark thorny vines


@mesh("DragonVine")
def dragon_vine():
    return vine(seed_of("DragonVine"), [("dragonVine", "dragonVineDark"), ("dragonVineDark", "leafDeep")], sinus=0.38, runner="dragonStem")


EYE_AT = (0.0, 1.35, -2.0)  # (on the front rib, -Z)


@mesh("DragonsEyePumpkin")
def dragons_eye_pumpkin():
    m = pumpkin_body(4.1, 2.9, ("dragonEyeLight", "dragonEye", "dragonEyeDark"), ribs=8, sides=32)
    path = curve([(0, 2.6, 0), (0.05, 3.1, 0), (0.35, 3.6, 0.1), (0.75, 3.75, 0.25), (1.0, 3.55, 0.35)], n=2)
    m.add(tube(path, np.linspace(0.28, 0.0, len(path)), 5, lambda i, k: ("dragonStem", "pupil")[k % 2]))
    for sx in (-1, 1):  # little horns
        m.add(lathe([(0, 0.13), (0.35, 0.06), (0.5, 0.0)], 5, "horn"), frame((sx * 0.9, 2.5, -0.6), unit((sx * 0.6, 1, -0.3))))
    # an eye each side (like a dragon's head): a dark rim round the glowing
    # eye, and its slit pupil
    rim = lathe([(-0.05, 0.0), (0.0, 1.0), (0.1, 0.84), (0.06, 0.0)], 12, "dragonEyeDark", squash=(1.0, 0.55))
    pupil = lathe([(0.0, 0.0), (0.06, 0.14), (0.12, 0.0)], 6, "pupil", squash=(0.24, 1.0))
    for side in (0, 180):
        turn = R("y", side)
        eye = np.array(EYE_AT)
        m.add(rim, mul(turn, T(*eye), R("x", -90)))
        m.add(pupil.transformed(S(1, 1, 3.4)), mul(turn, T(*(eye + [0, 0, -0.16])), R("x", -90)))
    return m


@mesh("DragonsEyeIris", textured=False, material="Neon", colour=(255, 206, 60))
def dragons_eye_iris():
    iris = lathe([(-0.02, 0.0), (0.0, 0.84), (0.1, 0.0)], 12, "pepper", squash=(1.0, 0.5))
    m = Mesh()
    for side in (0, 180):
        m.add(iris, mul(R("y", side), T(*(np.array(EYE_AT) + [0, 0, -0.04])), R("x", -90)))
    return m


def dragons_eye_patch(stage, n):
    items = [("DragonVine", T(0, 0, 0), 1.0)]
    if stage != "Ripe":
        items.append(("PumpkinYoung", mul(T(0.4, 0, 0.3), R("y", 30)), 0.42))
        return items
    for i in range(n):
        z = 0.0 if n == 1 else (i - (n - 1) / 2) * 5.0
        at = mul(T(0.3 * (1 if i % 2 else -1) if n > 1 else 0, -0.1, z), R("y", 180 * i))
        s = 1.0 if n == 1 else 0.85
        items.append(("DragonsEyePumpkin", at, s))
        items.append(("DragonsEyeIris", at, s))
    return items


# ===========================================================================

PATCHES = {
    "Carrot": dict(build=carrot_patch, per=6),
    "Wheat": dict(build=wheat_patch, per=3),
    "Potato": dict(build=potato_patch, per=10),
    "Lettuce": dict(build=lettuce_patch, per=4),
    "Corn": dict(build=corn_patch, per=6),
    "Onion": dict(build=onion_patch, per=7),
    "Strawberry": dict(build=strawberry_patch, per=4),
    "Tomato": dict(build=tomato_patch, per=6),
    "BellPepper": dict(build=pepper_patch, per=4),
    "Pumpkin": dict(build=big_patch("PumpkinVine", "Pumpkin", 5.0, young="PumpkinYoung"), per=1, most=2),
    "Watermelon": dict(build=big_patch("MelonVine", "Watermelon", 3.4), per=1, most=2),
    "Blueberry": dict(build=blueberry_patch, per=4),
    "Pineapple": dict(build=pineapple_patch, per=2),
    "CocoaPod": dict(build=cocoa_patch, per=4),
    "Dragonfruit": dict(build=dragonfruit_patch, per=3),
    "GrapeVine": dict(build=grape_patch, per=3),
    "Moonmelon": dict(build=moonmelon_patch, per=1, most=2),
    "Starfruit": dict(build=tree_patch("StarfruitTree", "Starfruit", 1.25, 0.8), per=3),
    "GoldenApple": dict(build=tree_patch("AppleTree", "GoldenApple", 1.3, 1.0), per=5),
    "CrystalRose": dict(build=crystal_rose_patch, per=1, most=2),
    "PhoenixPepper": dict(build=phoenix_patch, per=1, most=2),
    "DragonsEyePumpkin": dict(build=dragons_eye_patch, per=1, most=2),
}
