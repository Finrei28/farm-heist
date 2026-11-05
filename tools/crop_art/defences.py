"""Farm Heist's defences as low-poly meshes (docs/ArtDirection.md §11
step 11), in the props file: the scarecrow, the guard dog (its legs apart,
so the game can run it at a thief), the glass cloche, the security camera,
a mud patch, and the Watchman's bell and spotlight. The kennel, the
floodlights, the tall fence and the gatehouse are parts
(server/World/DefenceArt). Each stands on y = 0; its front is -Z.
"""
import math

import numpy as np

from meshkit import Mesh, R, T, blob, box, gem, lathe, mul, tube, unit
from props import chamfer_box, prop, rng_of

# The dog's hips (x, z) in its own frame, and how high they are: the game
# hangs a DogLeg from each (server/World/Meshes.dogLegs, PropMeshData.dog).
# Under the body's middle: it curves up toward its sides, so legs set any
# wider stop short of it.
DOG_LEGS = [(-0.22, -0.62), (0.22, -0.62), (-0.22, 0.66), (0.22, 0.66)]
LEG_TOP = 1.1


def straw(m, at, out, rng, n=5, length=0.4, spread=0.25):
    """A few straws poking out of a cuff or a collar along `out`."""
    out = unit(np.asarray(out, dtype=float))
    side = unit(np.cross(out, [0, 1, 0]) + np.array([1e-6, 0, 0]))
    up = np.cross(side, out)
    for j in range(n):
        a = 2 * math.pi * j / n + rng.uniform(-0.3, 0.3)
        base = np.asarray(at, dtype=float) + (side * math.cos(a) + up * math.sin(a)) * spread * 0.6
        tip = base + out * length * rng.uniform(0.7, 1.2) + (side * math.cos(a) + up * math.sin(a)) * spread * 0.5
        w = (side * math.sin(a) - up * math.cos(a)) * 0.05
        m.tri(base - w, base + w, tip, ("hayLight", "hay", "hayDark")[j % 3], double=True)


@prop("Scarecrow")
def scarecrow():
    """A scarecrow on its post, arms out along a crossbar: a plaid shirt with
    a patch, denim legs hanging, straw at the cuffs and collar, a burlap sack
    head tied at the neck with button eyes and a stitched grin, a straw hat
    tipped back. About 6.9 studs tall."""
    m = Mesh()
    rng = rng_of("Scarecrow")
    m.add(box((0.3, 6.3, 0.3), lambda n: "woodDark" if abs(n[0]) > 0.5 else "wood"), T(0, 3.15, 0))
    m.add(box((4.7, 0.24, 0.24), "wood"), T(0, 4.7, 0.05))

    def plaid(i, k, *_):
        return "scareShirtDark" if (i + k) % 3 == 0 else "scareShirt"

    # the shirt: wider than deep, stuffed round the post
    m.add(lathe([(2.95, 0.5), (3.15, 0.6), (4.3, 0.66), (4.75, 0.6), (4.98, 0.28)], 8, plaid, squash=(1.2, 0.72)))
    m.add(box((0.42, 0.38, 0.06), "patch"), mul(T(0.24, 3.75, -0.47), R("z", 8)))
    for x, y in ((0.14, 3.94), (0.33, 3.94), (0.14, 3.56), (0.33, 3.56)):
        m.add(box((0.05, 0.05, 0.03), "stitch"), T(x + 0.05, y, -0.505))
    # sleeves along the crossbar, straw out of the cuffs
    for sx in (-1, 1):
        path = [np.array([sx * 0.55, 4.62, 0.02]), np.array([sx * 1.35, 4.68, 0.05]), np.array([sx * 2.1, 4.64, 0.05])]
        m.add(tube(path, [0.36, 0.3, 0.27], 6, lambda i, k: "scareShirtDark" if k % 3 == 0 else "scareShirt"))
        straw(m, [sx * 2.12, 4.64, 0.05], [sx, -0.25, 0], rng, n=6, length=0.45, spread=0.3)
    # the legs: hanging from the shirt, a little apart, straw at the cuffs
    for sx in (-1, 1):
        path = [np.array([sx * 0.3, 3.2, 0.0]), np.array([sx * 0.36, 2.3, -0.04]), np.array([sx * 0.42, 1.5, 0.02])]
        m.add(tube(path, [0.31, 0.29, 0.27], 6, lambda i, k: "denimDark" if k % 3 == 1 else "denim"))
        straw(m, [sx * 0.42, 1.48, 0.02], [sx * 0.15, -1, 0], rng, n=6, length=0.45, spread=0.28)
    m.add(box((0.9, 0.5, 0.62), "denimDark"), T(0, 3.05, 0.0))  # (the seat, where the legs meet)
    # the head: a sack, tied at the neck with twine, straw under the knot
    m.add(blob((0.62, 0.7, 0.58), lambda n: "burlapDark" if n[1] < -0.35 or n[0] > 0.75 else "burlap", sub=2), T(0, 5.62, 0))
    neck = [np.array([math.cos(a) * 0.3, 5.0, math.sin(a) * 0.26]) for a in np.linspace(0, 2 * math.pi, 9)]
    m.add(tube(neck, [0.07] * 9, 4, "twine"))
    for a in np.linspace(0, 2 * math.pi, 7)[:-1]:
        straw(m, [math.cos(a) * 0.28, 4.98, math.sin(a) * 0.24], [math.cos(a), -0.6, math.sin(a)], rng, n=2, length=0.32, spread=0.1)
    # the face, on the front (-Z): button eyes, a stitched grin
    for sx in (-1, 1):
        m.add(lathe([(0.0, 0.1), (0.03, 0.1), (0.05, 0.0)], 6, "stitch"), mul(T(sx * 0.22, 5.78, -0.55), R("x", -90)))
    for j in range(7):
        a = math.radians(-36 + j * 12)
        x, y = math.sin(a) * 0.32, 5.46 - (1 - math.cos(a)) * 0.6
        z = -math.sqrt(max(0.0, 0.58 ** 2 * (1 - (x / 0.62) ** 2 - ((y - 5.62) / 0.7) ** 2))) - 0.01
        m.add(box((0.05, 0.16, 0.03), "stitch"), mul(T(x, y, z), R("z", 90 if j % 2 else 0)))
    m.add(box((0.5, 0.04, 0.03), "stitch"), T(0, 5.45, -0.575))
    # the hat: a wide straw brim, a crown with a band, tipped back
    hat = Mesh()
    hat.add(lathe([(0.0, 1.12), (0.05, 1.12), (0.09, 0.42)], 12, lambda i, k, n: "hayDark" if n[1] < 0 else "hayLight"))
    hat.add(lathe([(0.05, 0.46), (0.42, 0.44), (0.56, 0.32), (0.6, 0.0)], 10, lambda i, k, n: "hayLight" if n[1] > 0.6 else "hay"))
    hat.add(lathe([(0.07, 0.475), (0.2, 0.465)], 10, "scareShirt", cap=False))
    m.add(hat, mul(T(0, 6.18, 0.04), R("x", 10), R("z", -6)))
    return m


@prop("GuardDog")
def guard_dog():
    """A shepherd dog standing guard, without its legs (DogLeg, four of
    them under its hips): a tan coat with a dark saddle and a pale belly,
    a deep chest, its head up with pricked ears, a red collar with a gold
    tag, a bushy tail. Its head is toward -Z."""
    m = Mesh()

    def coat(n):
        if n[1] > 0.5:
            return "dogDark"
        if n[1] < -0.45:
            return "dogLight"
        return "dogTan"
    m.add(blob((0.46, 0.48, 0.92), coat, sub=2), T(0, 1.42, 0.12))
    m.add(blob((0.44, 0.54, 0.46), lambda n: "dogLight" if n[2] < -0.5 and n[1] < 0.3 else coat(n), sub=1), T(0, 1.55, -0.6))
    m.add(tube([np.array([0, 1.7, -0.8]), np.array([0, 2.12, -1.08])], [0.33, 0.28], 6, "dogTan"))
    # the head and muzzle, a dark nose, eyes
    m.add(blob((0.36, 0.34, 0.4), lambda n: "dogDark" if n[1] > 0.6 else "dogTan", sub=1), T(0, 2.3, -1.22))
    m.add(tube([np.array([0, 2.2, -1.48]), np.array([0, 2.13, -1.9])], [0.2, 0.13], 6, "dogLight", cap1=True))
    m.add(blob((0.09, 0.08, 0.07), "nose", sub=1), T(0, 2.17, -1.93))
    m.add(box((0.02, 0.02, 0.28), "nose"), T(0, 2.05, -1.72))  # (its mouth)
    for sx in (-1, 1):
        m.add(gem(0.055, "nose", h=0.05), T(sx * 0.15, 2.4, -1.53))
        # pricked ears: little pyramids, dark inside
        base = np.array([sx * 0.19, 2.52, -1.15])
        tip = base + np.array([sx * 0.08, 0.42, 0.06])
        a, b, c = base + [-0.12, 0, -0.06], base + [0.12, 0, -0.06], base + [0, 0, 0.12]
        m.tri(a, b, tip, "dogDark", out=[0, 0.2, -1])
        m.tri(b, c, tip, "dogTan", out=[sx, 0.2, 0.4])
        m.tri(c, a, tip, "dogTan", out=[-sx, 0.2, 0.4])
    # a red collar with a gold tag
    ring = [np.array([math.cos(a) * 0.32, 1.95 + math.sin(a) * 0.05, -0.95 + math.sin(a) * 0.22]) for a in np.linspace(0, 2 * math.pi, 10)]
    m.add(tube(ring, [0.06] * 10, 4, "collar"))
    m.add(gem(0.09, "ironGold", h=0.1), T(0, 1.7, -1.15))
    # the tail, up and curling
    path = [np.array([0, 1.62, 0.98]), np.array([0, 1.9, 1.3]), np.array([0, 2.22, 1.42]), np.array([0, 2.42, 1.32])]
    m.add(tube(path, [0.15, 0.14, 0.11, 0.03], 6, lambda i, k: "dogDark" if i < 2 else "dogTan"))
    return m


@prop("DogLeg")
def dog_leg():
    """One of the guard dog's legs, from its paw (y = 0) up to the hip
    (LEG_TOP), thicker at the top. The game swings it from the top."""
    m = Mesh()
    m.add(tube([np.array([0, 0.1, 0.0]), np.array([0, 0.55, 0.03]), np.array([0, LEG_TOP, 0.0])], [0.13, 0.15, 0.2], 6,
               lambda i, k: "dogLight" if i == 0 else "dogTan"))
    m.add(blob((0.15, 0.09, 0.2), "dogLight", sub=1), T(0, 0.09, -0.05))
    return m


@prop("Cloche", textured=False)
def cloche():
    """A glass cloche over a whole tile: a bell jar 11.2 across with a rolled
    rim, straight sides and a dome high enough for corn, a knob on top. One
    colour, untextured: the game makes it glass you see through."""
    m = Mesh()
    prof = [(0.0, 5.62), (0.25, 5.62), (0.32, 5.46), (5.5, 5.46)]
    for a in np.linspace(10, 90, 9):
        r = math.radians(a)
        prof.append((5.5 + 4.6 * math.sin(r), max(5.46 * math.cos(r), 0.42 if a == 90 else 0.0)))
    prof += [(10.25, 0.42), (10.5, 0.5), (10.78, 0.36), (10.88, 0.0)]
    m.add(lathe(prof, 18, "glass", cap=False))
    return m


@prop("SecurityCamera")
def security_camera():
    """A security camera on its knuckle (the origin, on the bracket): a
    white body reaching forward (-Z), a sun hood over it, a dark lens and a
    red light that says it's watching."""
    m = Mesh()
    m.add(blob((0.17, 0.17, 0.17), "camGrey", sub=1))
    m.add(tube([np.array([0, 0, 0]), np.array([0, 0.22, -0.3])], [0.08, 0.08], 5, "camGrey"))
    m.add(chamfer_box((0.6, 0.54, 1.45), 0.09, lambda n: "camGrey" if n[1] < -0.6 else "camWhite"), T(0, 0.34, -0.95))
    # the hood: a top and two sides, reaching past the lens
    m.add(box((0.78, 0.05, 1.62), "camWhite"), T(0, 0.66, -1.06))
    for sx in (-1, 1):
        m.add(box((0.05, 0.3, 0.5), "camWhite"), T(sx * 0.37, 0.52, -1.62))
    # the lens, facing -Z, and the light
    m.add(lathe([(0.0, 0.2), (0.08, 0.2), (0.11, 0.13), (0.12, 0.0)], 10, lambda i, k, n: "lensGlass" if n[1] > 0.9 else "lens"),
          mul(T(0, 0.34, -1.66), R("x", -90)))
    m.add(gem(0.045, "ledRed", h=0.04), T(0.21, 0.5, -1.67))
    return m


@prop("MudPatch")
def mud_patch():
    """A 12-stud patch of thick mud: a wobbly outline drying pale at the
    edge, dark wet mud inside with a brown puddle, boot prints across it,
    lumps and a few splats. Flat, a little proud of the lawn (it stands on
    the lawn's top)."""
    m = Mesh()
    rng = rng_of("MudPatch")
    n = 32
    phase = rng.uniform(0, 6, 3)

    def edge(a):
        r = 5.0 + 0.42 * math.sin(3 * a + phase[0]) + 0.26 * math.sin(5 * a + phase[1]) + 0.14 * math.sin(9 * a + phase[2])
        x, z = math.cos(a) * r, math.sin(a) * r
        k = min(1.0, 5.55 / max(abs(x), abs(z), 1e-6))  # (inside the 12-stud spot)
        return x * k, z * k
    rings = [(1.0, 0.06, "mudLight"), (0.86, 0.1, "mud"), (0.62, 0.13, "mudDark"), (0.34, 0.115, "mudWet"), (0.0, 0.115, "puddle")]
    pts = []
    for f, y, _ in rings:
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            x, z = edge(a)
            wob = 1 + (rng.uniform(-0.06, 0.06) if 0 < f < 1 else 0)
            lift = rng.uniform(-0.012, 0.012) if f > 0.5 else 0.0  # (the puddle lies flat)
            ring.append(np.array([x * f * wob + (0.6 if f < 0.5 else 0) * (1 - f), y + lift, z * f * wob]))
        pts.append(ring)
    for r in range(len(rings) - 1):
        col = rings[r + 1][2] if r >= 2 else rings[r][2]
        for i in range(n):
            j = (i + 1) % n
            a, b, c, d = pts[r][i], pts[r][j], pts[r + 1][j], pts[r + 1][i]
            if r == len(rings) - 2:
                m.tri(a, b, c, col, out=(0, 1, 0))
            else:
                m.quad(a, b, c, d, col, out=(0, 1, 0))
    # the puddle's shine: a pale streak of sky across the water
    streak = [np.array([-0.9, 0.125, -0.25]), np.array([0.5, 0.125, -0.55]), np.array([0.9, 0.125, -0.35]), np.array([-0.5, 0.125, -0.05])]
    m.quad(*streak, "puddleLight", out=(0, 1, 0))
    # boot prints: a line of them across it (someone ran through), a sole
    # and a heel each
    for k in range(8):
        x = -4.3 + k * 1.15
        if abs(x - 0.6) < 1.6:
            continue  # (not in the puddle)
        z = 2.1 + (0.4 if k % 2 else -0.4) + 0.2 * math.sin(k * 1.7)
        for dx, rx, rz in ((0.18, 0.3, 0.2), (-0.32, 0.17, 0.15)):
            oval = [np.array([x + dx + math.cos(a) * rx, 0.155, z + math.sin(a) * rz]) for a in np.linspace(0, 2 * math.pi, 8)[:-1]]
            centre = np.array([x + dx, 0.155, z])
            for i in range(len(oval)):
                m.tri(centre, oval[i], oval[(i + 1) % len(oval)], "print", out=(0, 1, 0))
    # lumps of mud, and splats round the edge
    for k in range(14):
        a = rng.uniform(0, 2 * math.pi)
        ex, ez = edge(a)
        f = rng.uniform(0.3, 0.85)
        r = rng.uniform(0.12, 0.26)
        m.add(gem(r, ("mud", "mudDark", "mudLight")[k % 3], h=r * 0.6, sides=5), mul(T(ex * f, 0.12, ez * f), R("y", rng.uniform(0, 90))))
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        ex, ez = edge(a)
        f = rng.uniform(1.02, 1.08)
        x, z = max(-5.7, min(5.7, ex * f)), max(-5.7, min(5.7, ez * f))
        r = rng.uniform(0.2, 0.32)
        blot = [np.array([x + math.cos(t) * r * rng.uniform(0.7, 1.2), 0.07, z + math.sin(t) * r * rng.uniform(0.7, 1.2)]) for t in np.linspace(0, 2 * math.pi, 7)[:-1]]
        for i in range(len(blot)):
            m.tri(np.array([x, 0.075, z]), blot[i], blot[(i + 1) % len(blot)], "mud", out=(0, 1, 0))
    return m


@prop("AlarmBell")
def alarm_bell():
    """The Watchman's brass bell, hanging from its yoke (its top at about
    1.15): a flared mouth with a lip, a band, the clapper showing under it."""
    m = Mesh()

    def col(i, k, n):
        if i in (1, 2):
            return "brassDark"
        return "brassLight" if n[0] + n[2] > 0.6 else "brass"
    m.add(lathe([(0.0, 0.56), (0.06, 0.58), (0.13, 0.52), (0.32, 0.43), (0.66, 0.36), (0.86, 0.33), (0.97, 0.21), (1.02, 0.0)], 12, col))
    m.add(box((0.46, 0.13, 0.18), "iron"), T(0, 1.07, 0))
    m.add(tube([np.array([0, 1.12, 0]), np.array([0, 1.2, 0])], [0.05, 0.05], 4, "iron"))
    m.add(blob((0.11, 0.11, 0.11), "iron", sub=1), T(0, -0.04, 0))
    return m


@prop("Spotlight")
def spotlight():
    """The Watchman's searchlight on its yoke: a dark drum with a bright
    lens on its front (-Z), a ring of fins at the back, a base. The game
    turns it to follow a thief."""
    m = Mesh()
    m.add(lathe([(0.0, 0.42), (0.1, 0.42), (0.14, 0.3), (0.16, 0.0)], 10, "lampBody"))
    m.add(tube([np.array([0, 0.14, 0]), np.array([0, 0.36, 0])], [0.09, 0.09], 6, "lampBody"))
    m.add(box((1.2, 0.08, 0.14), "lampBody"), T(0, 0.36, 0))
    for sx in (-1, 1):
        m.add(box((0.08, 0.5, 0.14), "lampBody"), T(sx * 0.56, 0.6, 0))
    drum = lathe([(-0.42, 0.34), (-0.3, 0.42), (0.3, 0.46), (0.42, 0.5), (0.46, 0.5)], 12,
                 lambda i, k, n: "lampGlass" if n[1] > 0.9 else ("lampBody" if i else "steelDark"))
    m.add(drum, mul(T(0, 0.78, 0), R("x", -90)))
    for k in range(3):
        m.add(lathe([(0.0, 0.4), (0.04, 0.4)], 12, "steelDark", cap=False), mul(T(0, 0.78, 0.18 + k * 0.08), R("x", -90)))
    return m
