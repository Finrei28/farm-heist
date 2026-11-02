"""Produce as it sits on a store's displays and on top of a packed crate
(server/World/StoreArt, World/YardArt): one piece of each crop, posed to
lie or stand on a shelf. A piece is the crop's own mesh (a filled punnet
for berries), so the store shows what the field grows. Pieces sit on
their bottom middle, the long way along X, `size` studs at their longest;
a crop with variants (potatoes) cycles through them.
"""
import math

import numpy as np

import carried  # noqa: F401  (registers the punnet)
from crops import built, mesh, on, seed_of
from meshkit import Mesh, R, T, apply, blob, frame, lathe, leaf, mul

# ===========================================================================
# Filled punnets: one mesh each, with lighter berries (a shelf holds many)


def punnet(m):
    m.add(built("Punnet"), np.diag([0.95, 0.45, 0.8, 1.0]))


def berry():
    """A plain strawberry, point down, for a punnet: red, no seeds (at shelf
    size they'd only turn it pink), a green star of a calyx on top."""
    m = lathe([(-0.42, 0.0), (-0.3, 0.17), (-0.12, 0.26), (0.02, 0.25), (0.1, 0.16), (0.12, 0.0)], 7,
              lambda i, k, n: "berryLight" if n[1] > 0.5 else ("berry", "berryDark")[(i + k) % 2])
    for k in range(5):
        a = 2 * math.pi * k / 5
        tip = np.array([math.cos(a) * 0.24, 0.1, math.sin(a) * 0.24])
        side = np.array([-math.sin(a), 0, math.cos(a)]) * 0.06
        m.tri(np.array([0, 0.14, 0]) - side, np.array([0, 0.14, 0]) + side, tip, "calyx", double=True)
    return m


@mesh("StrawberryPunnet")
def strawberry_punnet():
    """A green punnet heaped with strawberries."""
    m = Mesh()
    punnet(m)
    rng = np.random.default_rng(seed_of("StrawberryPunnet"))
    b = berry()
    for x, y, z in [(-0.2, 0.36, -0.15), (0.21, 0.36, -0.13), (-0.19, 0.36, 0.16), (0.22, 0.36, 0.16), (0.01, 0.48, 0.0)]:
        m.add(b, mul(T(x, y, z), R("y", rng.uniform(0, 360)), R("x", rng.uniform(40, 70))))
    return m


@mesh("BlueberryPunnet")
def blueberry_punnet():
    """A green punnet heaped with blueberries."""
    m = Mesh()
    punnet(m)
    rng = np.random.default_rng(seed_of("BlueberryPunnet"))
    spots = [(x, 0.36, z) for x in (-0.27, -0.09, 0.09, 0.27) for z in (-0.2, 0.0, 0.2)]
    spots += [(x, 0.47, z) for x in (-0.17, 0.0, 0.17) for z in (-0.1, 0.1)]
    for x, y, z in spots:
        j = rng.uniform(-0.03, 0.03, 3)
        m.add(blob((0.12, 0.11, 0.12), lambda n: "blueDusty" if n[1] > 0.7 else ("blue", "blueDark")[int(n[0] > 0)], sub=0),
              T(x + j[0], y + j[1], z + j[2]))
    return m


@mesh("CarrotBunch")
def carrot_bunch():
    """Three carrots lying in a bunch (the middle one on top), their tops
    cut short: a shelf of single carrots looked bare."""
    m = Mesh()
    carrot = built("Carrot")
    for z, y, a, s in ((-0.62, 0.0, -7, 0.95), (0.62, 0.0, 6, 0.92), (0.0, 0.62, 0, 1.0)):
        # (lying along +X, the root pointing away from the crown at x = 0)
        m.add(carrot, mul(T(0, y, z), R("y", a), R("z", -90)) @ np.diag([s, s, s, 1.0]))
    for k in range(7):
        a = -60 + k * 20
        d = np.array([math.cos(math.radians(a)), 0.25, math.sin(math.radians(a))])  # (out past the crowns)
        m.add(leaf(1.3 + 0.2 * (k % 2), 0.36, ("frond", "frondDark"), segs=2, curl=-10, rise=8, fold=0.3),
              frame(np.array([0.05, 0.35, 0.0]), [0, 1, 0], d))
    return m


# ===========================================================================
# Each crop's piece: [variants of [(mesh, transform, scale)]], and how big


def one(name, pose=None):
    return [[(name, pose if pose is not None else np.eye(4), 1.0)]]


def rose():
    at = np.eye(4)
    items = [("CrystalRoseCut", at, 1.0)]
    for key, name in (("Bloom", "CrystalRoseBloom"), ("Bloom", "CrystalRoseCore")):
        m, sc = on(at, 1.0, built("CrystalRoseCut").points[key][0])
        items.append((name, m, sc))
    return [[(name, R("z", 90) @ m, s) for name, m, s in items]]


SHELF = {
    "Carrot": (one("CarrotBunch"), 1.35),
    "Wheat": (one("WheatSheaf", R("z", 90)), 1.45),
    "Potato": ([one(f"Potato{i}")[0] for i in (1, 2, 3)], 0.78),
    "Lettuce": (one("Lettuce"), 1.05),
    "Corn": (one("CornCob", R("z", 90)), 1.25),
    "Onion": (one("OnionBulb"), 0.8),
    "Strawberry": (one("StrawberryPunnet"), 1.0),
    "Tomato": (one("Tomato"), 0.8),
    "BellPepper": (one("BellPepper"), 0.85),
    "Pumpkin": (one("Pumpkin"), 1.35),
    "Watermelon": (one("Watermelon", R("y", 90)), 1.55),
    "Blueberry": (one("BlueberryPunnet"), 1.0),
    "Pineapple": (one("Pineapple"), 1.4),
    "CocoaPod": (one("CocoaPod", R("z", 90)), 1.2),
    "Dragonfruit": (one("Dragonfruit"), 1.05),
    "GrapeVine": (one("GrapeBunch", R("y", 90) @ R("x", 90)), 1.25),
    "Moonmelon": ([[("Moonmelon", R("y", 90), 1.0), ("MoonmelonGlow", R("y", 90), 1.0)]], 1.45),
    "Starfruit": (one("Starfruit", R("y", 90) @ R("x", -90)), 1.0),
    "GoldenApple": (one("GoldenApple"), 1.0),
    "CrystalRose": (rose(), 1.25),
    "PhoenixPepper": ([[("PhoenixPepper", R("y", 90), 1.0), ("PhoenixTip", R("y", 90), 1.0)]], 1.3),
    "DragonsEyePumpkin": ([[("DragonsEyePumpkin", np.eye(4), 1.0), ("DragonsEyeIris", np.eye(4), 1.0)]], 1.25),
}


def _points(items):
    pts = []
    for name, m, s in items:
        pts.append(apply(m, built(name).array().reshape(-1, 3) * s))
    return np.concatenate(pts)


def piece(crop):
    """(variants, size): each variant's items scaled and moved to stand on
    its bottom middle; size is the biggest variant's box (x, y, z)."""
    variants, longest = SHELF[crop]
    spans = [(_points(v).min(0), _points(v).max(0)) for v in variants]
    k = longest / max(max(hi - lo) for lo, hi in spans)
    out, size = [], np.zeros(3)
    for v, (lo, hi) in zip(variants, spans):
        shift = np.array([-(lo[0] + hi[0]) / 2, -lo[1], -(lo[2] + hi[2]) / 2]) * k
        items = []
        for name, m, s in v:
            moved = m.copy()
            moved[:3, 3] = m[:3, 3] * k + shift
            items.append((name, moved, s * k))
        out.append(items)
        size = np.maximum(size, (hi - lo) * k)
    return out, size
