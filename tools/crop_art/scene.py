"""The ground a crop stands on, as the game builds it (server/World/
FarmArt): a tilled tile with three rounded ridges on the lawn, and an R15
-sized figure for scale. Used only for the previews."""
import numpy as np

from meshkit import Mesh, T, R, box, mul, tube

RIDGES = (-3.2, 0.0, 3.2)  # across the tile; the ridges run along Z
ON_RIDGE = 0.42  # a ridge's top above the tile's top (the patch's base)
ROW = 9.4  # how far along a ridge plants spread

GROUND = {
    "lawn": (125, 190, 90),
    "lawnStripe": (134, 199, 99),
    "soil": (104, 70, 46),
    "ridge": (118, 80, 52),
    "skin": (234, 184, 146),
    "shirt": (58, 120, 196),
    "pants": (52, 62, 84),
    "hair": (70, 48, 34),
}


def tile(at=None):
    """A tile (top at y = 0 under `at`) with its ridges."""
    mesh = Mesh()
    mesh.add(box((11.4, 0.4, 11.4), "soil"), T(0, -0.2, 0))
    for x in RIDGES:
        path = [np.array([x, -0.35, z]) for z in np.linspace(-5.1, 5.1, 3)]
        mesh.add(tube(path, [0.8] * 3, 14, "ridge", cap0=True, cap1=True))
    return mesh.transformed(at) if at is not None else mesh


def lawn(half=30.0, step=1.5, y=-0.5):
    mesh = Mesh()
    n = int(half * 2 / step)
    for i in range(n):
        for j in range(n):
            x0, z0 = -half + i * step, -half + j * step
            col = "lawnStripe" if (i // 4) % 2 else "lawn"
            a, b, c, d = (np.array(p) for p in ((x0, y, z0), (x0 + step, y, z0), (x0 + step, y, z0 + step), (x0, y, z0 + step)))
            mesh.quad(a, b, c, d, col, out=(0, 1, 0))
    return mesh


def figure(at):
    """A plain R15-sized person (5.2 studs tall) for scale."""
    mesh = Mesh()
    parts = [
        ((0.9, 1.9, 0.9), (-0.5, 0.95, 0), "pants"), ((0.9, 1.9, 0.9), (0.5, 0.95, 0), "pants"),
        ((2.0, 1.9, 1.0), (0, 2.85, 0), "shirt"), ((0.9, 1.9, 0.9), (-1.45, 2.85, 0), "shirt"),
        ((0.9, 1.9, 0.9), (1.45, 2.85, 0), "shirt"), ((1.2, 1.2, 1.2), (0, 4.4, 0), "skin"),
        ((1.25, 0.35, 1.25), (0, 5.05, 0), "hair"),
    ]
    for size, pos, col in parts:
        mesh.add(box(size, col), T(*pos))
    return mesh.transformed(at)


def stage(items, meshes, figure_at=None, extra=None):
    """The world triangles and colour names for a patch: the lawn, a tile,
    each (mesh name, transform) in `items`, and maybe a figure."""
    world = Mesh()
    world.add(lawn())
    world.add(tile())
    if figure_at is not None:
        world.add(figure(figure_at))
    for name, m in items:
        world.add(meshes[name], m)
    if extra is not None:
        world.add(extra)
    return world


def ridge_spots(n, ridges=(0, 1, 2), row=ROW, seed=0, along=None):
    """n plants spread evenly along the given ridges, extra ones to the
    middle first; each with a turn. Returns 4x4 transforms on the ridge
    tops."""
    rng = np.random.default_rng(seed)
    use = list(ridges)
    order = sorted(use, key=lambda r: abs(r - 1))
    counts = {r: n // len(use) for r in use}
    for i in range(n % len(use)):
        counts[order[i]] += 1
    out = []
    for r in use:
        k = counts[r]
        for i in range(k):
            z = -row / 2 + (i + 0.5) * row / k
            # rows staggered from ridge to ridge so the patch doesn't read as a grid
            z += (row / k / 4) * (1 if r % 2 else -1) if k > 1 else 0
            if along is not None:
                z = along(r, i, k)
            jitter = rng.uniform(-0.12, 0.12, size=2)
            out.append(mul(T(RIDGES[r] + jitter[0], ON_RIDGE, z + jitter[1]), R("y", rng.uniform(0, 360))))
    return out
