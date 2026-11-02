"""What a thief carries off a patch (server/World/ProduceArt, held up by
CrimeArt.showCarried): the crop's own meshes, smaller, tied in bunches or in
baskets, crates and punnets. Each layout stands on its bottom middle, faces
-Z, and returns (items, width, height, hold): hold is how high up its sides
the hands go. Items are (mesh, rigid transform, scale); containers scale on
each axis (a 3-tuple).
"""
import math

import numpy as np

from crops import built, mesh, on, seed_of
from meshkit import Mesh, R, T, apply, box, frame, lathe, mul, tube, unit

# ===========================================================================
# Containers (each 1 stud a side at scale 1, standing on the origin)


@mesh("Basket")
def basket():
    """A round wicker basket: woven sides, a thick rim, a floor."""
    sides = 16
    prof = [(0.0, 0.42), (0.25, 0.47), (0.5, 0.5), (0.75, 0.5), (1.0, 0.5)]
    m = lathe(prof, sides, lambda i, k, n: ("wicker", "wickerDark")[(i + k) % 2] if i < 4 else "wickerDark", cap=False)
    inner = [(1.0, 0.46), (0.75, 0.46), (0.5, 0.46), (0.25, 0.43), (0.08, 0.38)]
    m.add(lathe(inner, sides, "wickerDark", cap=False))  # (the inside, facing in)
    m.add(lathe([(0.0, 0.0), (0.0, 0.42)], sides, "wickerDark", cap=False).transformed(R("x", 180)))  # (under the bottom)
    m.add(lathe([(0.08, 0.0), (0.08, 0.38)], sides, "wicker", cap=False))  # (the floor inside, facing up)
    ring = [np.array([math.cos(a) * 0.48, 1.0, math.sin(a) * 0.48]) for a in np.linspace(0, 2 * math.pi, 17)]
    m.add(tube(ring, [0.05] * 17, 5, "wickerLight"))
    return m


@mesh("Crate")
def crate():
    """An open slatted crate: four corner posts, two slats a side with gaps,
    a floor."""
    m = Mesh()
    m.add(box((1.0, 0.08, 1.0), lambda n: "crateDark"), T(0, 0.04, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(box((0.1, 1.0, 0.1), lambda n: "crateDark"), T(sx * 0.45, 0.5, sz * 0.45))
    for y in (0.27, 0.73):
        for sx in (-1, 1):
            m.add(box((0.06, 0.36, 0.86), lambda n: "crate" if n[1] < 0.5 else "woodLight"), T(sx * 0.47, y, 0))
        for sz in (-1, 1):
            m.add(box((0.86, 0.36, 0.06), lambda n: "crate" if n[1] < 0.5 else "woodLight"), T(0, y, sz * 0.47))
    return m


@mesh("Punnet")
def punnet():
    """A green punnet: an open box flaring to its rim."""
    m = Mesh()
    lo, hi, h = 0.42, 0.5, 1.0
    bottom = [np.array(p) for p in ((-lo, 0, -lo), (lo, 0, -lo), (lo, 0, lo), (-lo, 0, lo))]
    top = [np.array(p) for p in ((-hi, h, -hi), (hi, h, -hi), (hi, h, hi), (-hi, h, hi))]
    for i in range(4):
        j = (i + 1) % 4
        m.quad(bottom[i], bottom[j], top[j], top[i], "punnet", double=True)
    m.quad(*bottom, "punnetDark", double=True)
    for i in range(4):
        j = (i + 1) % 4
        m.add(tube([top[i], top[j]], [0.04, 0.04], 4, "punnetDark"))
    return m


@mesh("Tray")
def tray():
    """A flat wooden tray with a low lip."""
    m = Mesh()
    m.add(box((1.0, 0.5, 1.0), lambda n: "wood" if n[1] < 0.5 else "woodLight"), T(0, 0.25, 0))
    for sx in (-1, 1):
        m.add(box((0.06, 1.0, 1.0), lambda n: "woodDark"), T(sx * 0.5, 0.5, 0))
        m.add(box((1.0, 1.0, 0.06), lambda n: "woodDark"), T(0, 0.5, sx * 0.5))
    return m


@mesh("Twine")
def twine():
    """A band of twine 1 across, 1 high (scaled to what it ties)."""
    return lathe([(0.0, 0.5), (1.0, 0.5)], 12, lambda i, k, n: ("twine", "twineDark")[k % 2], cap=False)


# ===========================================================================
# Helpers


def pile(top, count, size, width, depth=None, seed=0):
    """Spots for `count` pieces `size` across heaped on `top` (y) within
    `width` by `depth`: a full layer on the bottom, then smaller layers in
    its hollows; each piece tumbled a little."""
    rng = np.random.default_rng(seed + count)
    depth = depth or width
    step_z = size * 0.85
    cols0 = max(1, round(width / size))
    rows0 = max(1, round(depth / step_z))
    spots = []
    layer = 0
    while len(spots) < count:
        cols, rows = max(1, cols0 - layer), max(1, rows0 - layer)
        if cols * rows == 1 and count - len(spots) > 1:
            cols, rows = max(1, cols0 - 1), rows0
        y = top + size * 0.32 + layer * size * 0.6
        cells = [((c - (cols - 1) / 2) * size, (r - (rows - 1) / 2) * step_z) for r in range(rows) for c in range(cols)]
        if layer:
            cells.sort(key=lambda xz: xz[0] ** 2 + xz[1] ** 2)
        for x, z in cells:
            if len(spots) >= count:
                break
            j = rng.uniform(-0.08, 0.08, size=2) * size
            spots.append(mul(T(x + j[0], y, z + j[1]), R("y", rng.uniform(0, 360)), R("x", rng.uniform(-25, 25))))
        layer += 1
    return spots


def grid(count, cols, step_x, step_z, y=0.0):
    rows = math.ceil(count / cols)
    out = []
    for i in range(count):
        col, row = i % cols, i // cols
        in_row = count - row * cols if row == rows - 1 else cols
        out.append(T((col - (in_row - 1) / 2) * step_x, y, (row - (rows - 1) / 2) * step_z))
    return out


def height_of(items):
    """How high the items reach (their meshes' tops)."""
    top = 0.0
    for name, m, s in items:
        mesh_ = built(name)
        tris = mesh_.array().reshape(-1, 3)
        sc = np.array(s if isinstance(s, tuple) else (s, s, s))
        pts = apply(m, tris * sc)
        top = max(top, pts[:, 1].max())
    return top


def in_basket(items, d, h, n, size, fruit, fruit_s, turn=None):
    items.append(("Basket", T(0, 0, 0), (d, h, d)))
    for at in pile(h * 0.55, n, size, d * 0.85):
        if turn is not None:
            at = at @ turn
        items.append((fruit, at, fruit_s))
    return items


# ===========================================================================
# What a thief holds, crop by crop


def carrot(n):
    items = []
    ring = n - 1 if n >= 6 else n
    r = 0.16 if n <= 2 else (0.28 if n <= 5 else 0.38)
    spots = [(math.cos(i / ring * 2 * math.pi + 0.4) * r, math.sin(i / ring * 2 * math.pi + 0.4) * r) for i in range(ring)]
    if ring < n:
        spots.append((0.0, 0.0))
    for i, (x, z) in enumerate(spots):
        lean = mul(R("x", -z * 30), R("z", x * 30))
        crown = mul(T(x * 0.8, 1.45, z * 0.8), lean, R("y", i * 70))
        items.append(("Carrot", crown, 0.52))
        items.append(("CarrotTop", crown, 0.5))
    items.append(("Twine", T(0, 1.5, 0), (2 * r + 0.25, 0.16, 2 * r + 0.25)))
    return items, 2 * r + 0.7, 2.65, 0.95


def wheat(n):
    items = []
    if n == 1:
        items.append(("WheatSheaf", T(0, 0.1, 0), 0.72))
        return items, 1.3, 2.85, 0.75
    r = 0.4 if n <= 3 else 0.55
    for i in range(n):
        a = i / n * 2 * math.pi + 0.3
        items.append(("WheatSheaf", mul(T(math.cos(a) * r, 0.1, math.sin(a) * r), R("z", -math.cos(a) * 6), R("x", math.sin(a) * 6), R("y", i * 80)), 0.62))
    items.append(("Twine", T(0, 0.75, 0), (2 * r + 0.7, 0.22, 2 * r + 0.7)))
    return items, 2 * r + 1.2, 2.6, 0.72


def potato(n):
    size = (1.45, 0.7, 1.05) if n <= 6 else ((1.8, 0.75, 1.3) if n <= 12 else (2.1, 0.8, 1.55))
    items = [("Crate", T(0, 0, 0), size)]
    for i, at in enumerate(pile(size[1] - 0.3, n, 0.5, size[0] - 0.15, size[2] - 0.15)):
        items.append((f"Potato{i % 3 + 1}", at, 0.5))
    return items, size[0] + 0.05, max(size[1], height_of(items)), 0.4


def lettuce(n):
    if n == 1:
        return [("Lettuce", T(0, 0, 0), 0.5)], 1.6, 0.6, 0.3
    cols = 2 if n <= 4 else 3
    rows = math.ceil(n / cols)
    size = (cols * 1.1 + 0.12, 0.45, rows * 1.1 + 0.12)
    items = [("Crate", T(0, 0, 0), size)]
    for i, at in enumerate(grid(n, cols, 1.1, 1.1, y=0.12)):
        items.append(("Lettuce", at @ R("y", i * 70), 0.36))
    return items, size[0] + 0.05, 0.85, 0.3


def corn(n):
    items = []
    front = math.ceil(n / 2)
    back = n - front
    for row, count in ((0, front), (1, back)):
        for c in range(count):
            x = (c - (count - 1) / 2) * 0.42
            z = -0.15 if row == 0 else 0.15
            items.append(("CornCob", mul(T(x, 0.05, z), R("z", -x * 22), R("y", c * 70 + row * 35)), 0.7))
    items.append(("Twine", T(0, 0.22, 0), (front * 0.42 + 0.35, 0.16, 0.7)))
    return items, front * 0.42 + 0.66, 1.65, 0.7


def onion(n):
    items = []
    knot = np.array([0, 1.25, 0.04])
    lower = n if n <= 3 else math.ceil(n * 0.6)
    for i in range(n):
        upper = i >= lower
        count = n - lower if upper else lower
        j = i - lower if upper else i
        a = j / max(1, count) * 2 * math.pi + (0.5 if upper else 0)
        r = 0.32 if upper else 0.5
        y = 0.55 if upper else 0.05
        out = np.array([math.cos(a), 0, math.sin(a)])
        base = np.array([0, y, 0]) + out * r
        up = unit(knot - base)
        items.append(("OnionBulb", frame(base, up, out), 0.5))
    items.append(("Twine", T(*(knot - [0, 0.05, 0])), (0.3, 0.24, 0.3)))
    return items, 1.4, 1.75, 0.45


def berries_on_tray(n, fruit, per, fruit_s):
    """Punnets heaped with berries on a tray (one punnet's worth each)."""
    cols = 1 if n == 1 else (2 if n <= 4 else 3)
    rows = math.ceil(n / cols)
    tray_size = (cols * 1.1 + 0.15, 0.14, rows * 0.95 + 0.15)
    items = [("Tray", T(0, 0, 0), tray_size)]
    for i, at in enumerate(grid(n, cols, 1.1, 0.95, y=0.12)):
        items.append(("Punnet", at, (0.95, 0.45, 0.8)))
        for j, spot in enumerate(pile(0.18, per, 0.36, 0.78, 0.62, seed=i)):
            lie = R("x", 90) @ T(0, 0.18, 0) if fruit == "Strawberry" else T(0, 0.2, 0)
            items.append((fruit, at @ spot @ lie, fruit_s))
    return items, tray_size[0], 0.95, 0.25


def strawberry(n):
    return berries_on_tray(n, "Strawberry", 5, 0.45)


def blueberry(n):
    return berries_on_tray(n, "BlueberryCluster", 4, 0.4)


def tomato(n):
    d = 1.6 if n <= 6 else 1.9
    items = in_basket([], d, 0.6, n, 0.62, "Tomato", 0.62, turn=T(0, 0.5, 0))
    return items, d + 0.1, height_of(items), 0.4


def bell_pepper(n):
    d = 1.7 if n <= 4 else 2.0
    items = [("Basket", T(0, 0, 0), (d, 0.6, d))]
    for i, at in enumerate(pile(0.35, n, 0.7, d * 0.8)):
        # (standing up, stems up: they hang from their stem, so lift them by it)
        pos = at[:3, 3]
        items.append(("BellPepper", mul(T(*pos), R("y", i * 65), T(0, 0.85 * 0.6, 0)), 0.6))
    return items, d + 0.1, height_of(items), 0.4


def big(fruit, s, glow=None):
    def build(n):
        items = []
        if n == 1:
            items.append((fruit, T(0, 0, 0), s))
            if glow:
                items.append((glow, T(0, 0, 0), s))
        else:
            w = built(fruit).bounds()[1][0] - built(fruit).bounds()[0][0]
            for i in range(n):
                at = T((i - (n - 1) / 2) * w * s * 0.85, 0, 0)
                items.append((fruit, at, s * 0.8))
                if glow:
                    items.append((glow, at, s * 0.8))
        lo, hi = built(fruit).bounds()
        width = (hi[0] - lo[0]) * s * (1 if n == 1 else 0.85 * n)
        height = height_of(items)
        return items, width, height, height * 0.4
    return build


def pineapple(n):
    items = [("Pineapple", at @ R("y", i * 50), 0.68) for i, at in enumerate(grid(n, n, 1.0, 0))]
    return items, n * 1.0, height_of(items), 0.6


def cocoa(n):
    if n == 1:
        return [("CocoaPod", mul(T(0, 1.55, 0), R("z", 8)), 0.95)], 1.0, 1.6, 0.75
    d = 2.0 if n <= 4 else 2.3
    items = [("Basket", T(0, 0, 0), (d, 0.4, d))]
    for i in range(n):
        a = i / n * 2 * math.pi + 0.4
        out = np.array([math.cos(a), 0, math.sin(a)])
        # (lying like spokes, stalks to the middle)
        items.append(("CocoaPod", frame(out * 0.12 + [0, 0.62 + (i % 2) * 0.08, 0], -out, (0, 1, 0)), 0.62))
    return items, d + 0.1, height_of(items), 0.3


def dragonfruit(n):
    if n == 1:
        return [("Dragonfruit", T(0, 0, 0), 0.85)], 1.4, 1.45, 0.55
    d = 1.7 if n <= 3 else 2.0
    items = [("Basket", T(0, 0, 0), (d, 0.55, d))]
    for i in range(n):
        a = i / n * 2 * math.pi + 0.5
        out = np.array([math.cos(a), 0, math.sin(a)])
        items.append(("Dragonfruit", frame(out * 0.3 + [0, 0.3, 0], unit(out * 0.4 + [0, 1, 0])), 0.62))
    return items, d + 0.1, height_of(items), 0.4


def grapes(n):
    if n == 1:
        return [("GrapeBunch", T(0, 1.95, 0), 1.05)], 1.2, 2.0, 1.0
    d = max(1.8, n * 0.62 + 0.3)
    items = [("Basket", T(0, 0, 0), (d, 0.4, d))]
    for i, at in enumerate(grid(n, n, 0.62, 0, y=0.55)):
        # (lying down, stalks to the back)
        items.append(("GrapeBunch", at @ T(0, 0.1, 0.5) @ R("x", 80), 0.62))
    return items, d + 0.1, height_of(items), 0.3


def starfruit(n):
    if n == 1:
        return [("Starfruit", mul(T(0, 1.55, 0), R("z", 10)), 0.9)], 1.0, 1.6, 0.75
    d = max(1.6, n * 0.6 + 0.4)
    items = [("Basket", T(0, 0, 0), (d, 0.5, d))]
    for i, at in enumerate(grid(n, n, 0.6, 0, y=0.55)):
        items.append(("Starfruit", at @ R("y", i * 25) @ T(0, 0, -0.65) @ R("x", -90), 0.66))
    return items, d + 0.1, height_of(items), 0.4


def golden_apple(n):
    if n == 1:
        return [("GoldenApple", T(0, 1.2, 0), 1.0)], 1.2, 1.4, 0.55
    d = 1.7 if n <= 5 else (2.0 if n <= 8 else 2.3)
    items = in_basket([], d, 0.6, n, 0.75, "GoldenApple", 0.65, turn=T(0, 0.7, 0))
    return items, d + 0.1, height_of(items), 0.42


def crystal_rose(n):
    items = []
    for i in range(n):
        lean = 0 if n == 1 else (i - (n - 1) / 2) * 18
        at = mul(T(0, 0, 0), R("z", -lean))
        items.append(("CrystalRoseCut", at, 0.42))
        for key, name in (("Bloom", "CrystalRoseBloom"), ("Bloom", "CrystalRoseCore")):
            m, sc = on(at, 0.42, built("CrystalRoseCut").points[key][0])
            items.append((name, m, sc))
    if n > 1:
        items.append(("Twine", T(0, 0.45, 0), (0.45, 0.18, 0.45)))
    width = 1.6 + (n - 1) * 0.8
    return items, width, height_of(items), 1.2


def phoenix_pepper(n):
    items = []
    for i, at in enumerate(grid(n, 1, 0, 0.8)):
        # (lying on its side, the curl up)
        pose = at @ T(-1.0, 0.95, 0) @ R("y", 90)
        items.append(("PhoenixPepper", pose, 0.62))
        items.append(("PhoenixTip", pose, 0.62))
    lo = min(0.0, 0.0)
    del lo
    return items, 2.2, height_of(items), 0.4


def measured(build):
    """A load as laid out, then lifted to stand on its bottom and measured:
    its height is where its top really is (the width stays where the
    hands go)."""
    def load(n):
        items, width, height, hold = build(n)
        lo = min(_reach(items)[:, 1].min(), 0.0)
        if lo < 0:
            items = [(name, T(0, -lo, 0) @ m, s) for name, m, s in items]
        return items, width, float(_reach(items)[:, 1].max()), hold - lo
    return load


def _reach(items):
    pts = []
    for name, m, s in items:
        sc = np.array(s if isinstance(s, tuple) else (s, s, s))
        pts.append(apply(m, built(name).array().reshape(-1, 3) * sc))
    return np.concatenate(pts)


CARRIED = {
    "Carrot": carrot, "Wheat": wheat, "Potato": potato, "Lettuce": lettuce, "Corn": corn, "Onion": onion,
    "Strawberry": strawberry, "Tomato": tomato, "BellPepper": bell_pepper,
    "Pumpkin": big("Pumpkin", 0.55), "Watermelon": big("Watermelon", 0.5), "Blueberry": blueberry,
    "Pineapple": pineapple, "CocoaPod": cocoa, "Dragonfruit": dragonfruit, "GrapeVine": grapes,
    "Moonmelon": big("Moonmelon", 0.5, glow="MoonmelonGlow"), "Starfruit": starfruit, "GoldenApple": golden_apple,
    "CrystalRose": crystal_rose, "PhoenixPepper": phoenix_pepper,
    "DragonsEyePumpkin": big("DragonsEyePumpkin", 0.5, glow="DragonsEyeIris"),
}
CARRIED = {crop: measured(build) for crop, build in CARRIED.items()}
