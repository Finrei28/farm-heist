"""Farm Heist's town (docs/ArtDirection.md §6, §11 step 6) as low-poly
meshes, in the props file: the fountain's basin, the park's trees, bushes
and flowerbeds, and two plain shapes the buildings' roofs are cut from (a
square pyramid and a cone: untextured, the game tints them). The
clocktower, the shop fronts, benches, lamps and signposts are parts
(server/World/PlazaArt, TownArt). Each stands on y = 0.
"""
import math

import numpy as np

from crops import leafy
from meshkit import Mesh, T, frame, lathe, leaf, tube, unit
from props import daisy, prop, rng_of


# ===========================================================================
# Plain shapes for roofs (tinted by the game: slate, the farm colours)


@prop("Pyramid", textured=False)
def pyramid():
    """A square pyramid 1 stud a side and 1 tall, its faces to ±X and ±Z:
    the clocktower's spire, the elevator's cupola."""
    return lathe([(0.0, math.sqrt(0.5)), (1.0, 0.0)], 4, "white", spin=math.pi / 4)


@prop("Cone", textured=False)
def cone():
    """A cone 1 stud across and 1 tall: the silos' caps."""
    return lathe([(0.0, 0.5), (1.0, 0.0)], 16, "white")


# ===========================================================================
# The fountain


@prop("FountainBasin")
def fountain_basin():
    """The fountain's round stone basin, 20 studs across (the clocktower
    rises from its middle): a plinth step, a wall with a rolled lip, and
    inside a blue-tiled floor under the water (a part the game lays in at
    1.9). Drawn at its size."""
    profile = [
        (0.0, 10.0), (0.6, 10.0), (0.6, 9.55), (1.75, 9.4), (1.8, 9.85), (2.25, 9.95), (2.45, 9.7),
        (2.5, 9.2), (2.45, 8.75), (2.3, 8.55), (0.7, 8.4), (0.7, 0.0),
    ]
    inner = 8  # (rings from here down are the pool's side and floor)

    def col(i, k, n):
        if i >= inner:
            return "poolDeep" if i >= inner + 1 else "pool"
        if n[1] > 0.5:
            return "stoneLight"
        if n[1] < -0.3:
            return "stoneDark"
        return "stone" if k % 2 else "stoneShade"
    return lathe(profile, 40, col)


# ===========================================================================
# Trees and bushes (the park and the green; the valley's woods in week 8)

OAK_LEAVES = ["leafDark", "leaf", "leafLight", "leafSun"]


@prop("OakTree")
def oak_tree():
    """A broad park tree about 17 studs tall: a stout trunk with roots
    gripping the ground, forking into boughs, a round crown of leafy clumps
    (a darker core with leaves sticking out, never one ball)."""
    rng = rng_of("OakTree")
    m = Mesh()
    bark = lambda i, k: ("bark", "barkDark", "barkLight")[k % 3]  # noqa: E731
    trunk = [(0, -0.2, 0), (0.1, 2.5, 0.05), (-0.1, 5.0, 0.0), (0.0, 6.6, 0.1)]
    m.add(tube(trunk, [1.2, 0.95, 0.8, 0.65], 7, bark, cap1=True))
    for j in range(5):  # roots
        a = j * 2 * math.pi / 5 + 0.4
        out = np.array([math.cos(a), 0, math.sin(a)])
        m.add(tube([out * 0.5 + [0, 0.9, 0], out * 1.3 + [0, 0.25, 0], out * 1.9 + [0, -0.05, 0]], [0.38, 0.26, 0.1], 5, "barkDark"))
    # boughs out to the clumps round the crown
    clumps = [((0.0, 11.6, 0.0), (4.4, 3.6, 4.4))]
    for j in range(6):
        a = j * 2 * math.pi / 6 + rng.uniform(-0.25, 0.25)
        r = rng.uniform(3.6, 4.2)
        y = rng.uniform(9.0, 10.6)
        c = (math.cos(a) * r, y, math.sin(a) * r)
        clumps.append((c, (3.0, 2.6, 3.0)))
        bough = [np.array([0, 6.2, 0]), np.array([c[0] * 0.45, 7.6, c[2] * 0.45]), np.array([c[0] * 0.75, y - 0.6, c[2] * 0.75])]
        m.add(tube(bough, [0.45, 0.32, 0.18], 5, bark))
    for c, radii in clumps:
        leafy(m, rng, c, radii, 22, 2.0, ["leafDark", "leaf", "leafDark"], OAK_LEAVES)
    return m


@prop("PineTree")
def pine_tree():
    """A tall fir about 21 studs: a straight trunk, tiers of drooping
    boughs, each a ragged skirt, smaller and higher to the tip."""
    rng = rng_of("PineTree")
    m = Mesh()
    m.add(tube([(0, -0.2, 0), (0, 4.0, 0), (0, 18.0, 0)], [0.7, 0.55, 0.15], 6, lambda i, k: "bark" if k % 2 else "barkDark"))
    tiers = 6
    for t in range(tiers):
        f = t / (tiers - 1)
        base = 3.2 + t * 2.75
        r = 5.4 * (1 - f) + 1.3 * f
        h = 4.6 - 1.1 * f
        spin = rng.uniform(0, 1)

        def lobe(th, spin=spin):
            # a ragged edge: bough tips
            return 1.0 + 0.16 * math.cos(9 * th + spin * 6) + 0.06 * math.cos(17 * th + spin * 3)

        cols = ("firDeep", "firDark", "fir", "firLight")
        skirt = lathe([(0.0, r * 0.25), (-0.45, r), (h * 0.55, r * 0.45), (h, 0.0)], 18, lambda i, k, n, t=t: cols[min(3, (1 if n[1] > 0.2 else 0) + (k + t) % 3)],
                      lobe=lobe, spin=spin)
        m.add(skirt, T(0, base, 0))
    return m


@prop("Bush")
def bush():
    """A rounded leafy bush about 4 studs across and 3 tall."""
    rng = rng_of("Bush")
    m = Mesh()
    for c, radii in (((0.0, 1.5, 0.0), (1.9, 1.5, 1.9)), ((1.0, 1.1, 0.6), (1.2, 1.0, 1.2)), ((-0.9, 1.0, -0.5), (1.1, 0.9, 1.1))):
        leafy(m, rng, c, radii, 16, 0.9, ["leafDark", "leaf", "leafDark"], ["leafDark", "leaf", "leafLight", "leafSun"])
    return m


# ===========================================================================
# Flowerbeds (round, edged with stone; the park and the shops' fronts)


def tulip(m, at, h, cols, rng):
    """A tulip: a stem, two strap leaves, a cupped head of petals."""
    at = np.asarray(at, dtype=float)
    top = at + np.array([rng.uniform(-0.08, 0.08), h, rng.uniform(-0.08, 0.08)])
    m.add(tube([at, top], [0.05, 0.04], 3, "stem"))
    a = rng.uniform(0, 2 * math.pi)
    out = np.array([math.cos(a), 0, math.sin(a)])
    m.add(leaf(h * 0.75, 0.24, "leaf", segs=2, curl=20, rise=70, fold=0.4), frame(at + [0, 0.05, 0], unit(out * 0.5 + [0, 1, 0]), out))
    head = lathe([(0.0, 0.08), (0.14, 0.21), (0.46, 0.13)], 5, lambda i, k, n: cols[(k + i) % 2], cap=True)
    m.add(head, T(*top))


@prop("FlowerBed")
def flower_bed():
    """A round bed 7 studs across: a stone edging round a mound of soil, red
    tulips round the outside, yellow ones inside them, white daisies on
    the crown, leaves between."""
    rng = rng_of("FlowerBed")
    m = Mesh()
    m.add(lathe([(0.0, 3.5), (0.55, 3.5), (0.65, 3.35), (0.6, 3.05), (0.4, 2.95)], 28, lambda i, k, n: "stoneLight" if n[1] > 0.5 else ("stone" if k % 2 else "stoneShade"), cap=False))
    m.add(lathe([(0.35, 3.0), (0.55, 2.4), (0.8, 1.2), (0.85, 0.0)], 18, lambda i, k, n: "bedSoil" if (i + k) % 3 else "bedSoilDark"))
    for ring, (radius, count, cols, h) in enumerate(((2.55, 16, ("tulipRed", "tulipRedDark"), 1.25), (1.6, 10, ("flowerYellow", "flowerYellowDark"), 1.35))):
        for j in range(count):
            a = 2 * math.pi * (j + 0.5 * ring) / count + rng.uniform(-0.08, 0.08)
            y = 0.55 if ring == 0 else 0.72
            tulip(m, (math.cos(a) * radius, y, math.sin(a) * radius), h * rng.uniform(0.9, 1.1), cols, rng)
    for j in range(6):  # daisies on the crown
        a = 2 * math.pi * j / 6 + 0.3
        r = 0.7 if j else 0.0
        at = np.array([math.cos(a) * r, 0.85, math.sin(a) * r])
        top = at + [0, 0.75, 0]
        m.add(tube([at, top], [0.04, 0.035], 4, "stem"))
        daisy(m, top, (0.15, 1, 0.1), 0.32, "flowerWhite", "flowerYellow", petals=8)
    for j in range(12):  # leaves among the flowers
        a = 2 * math.pi * j / 12 + 0.2
        at = np.array([math.cos(a) * 2.1, 0.68, math.sin(a) * 2.1])
        out = np.array([math.cos(a), 0, math.sin(a)])
        m.add(leaf(0.8, 0.4, ("leafDark", "leaf")[j % 2], segs=2, curl=25, rise=25, fold=0.3), frame(at, unit(out * 0.6 + [0, 1, 0]), out))
    return m
