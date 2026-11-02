"""Building blocks for Farm Heist's crop meshes: a flat-shaded low-poly mesh
(one palette colour per triangle, so faces read as crisp facets), 4x4
transforms, shapes (lathes, tubes, lumpy blobs, leaves, gems), the palette
texture and a GLB writer for Roblox Studio's 3D importer.

Coordinates are Roblox's: +Y up, studs. A mesh is built round its "foot"
(the point the game stands it on); Roblox centres an imported mesh on its
bounding box, so the generator exports each mesh's box centre and size, and
the game places it from the foot (server/World/CropMeshes.luau).
"""
import json
import math
import struct
from io import BytesIO

import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# Vectors and 4x4 transforms


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / (np.linalg.norm(v) + 1e-12)


def T(x, y=0.0, z=0.0):
    m = np.eye(4)
    if np.ndim(x):
        x, y, z = x
    m[:3, 3] = (x, y, z)
    return m


def R(axis, degrees):
    """Rotation by `degrees` about 'x', 'y', 'z' or a vector (right hand)."""
    if isinstance(axis, str):
        axis = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis]
    k = unit(axis)
    a = math.radians(degrees)
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    m = np.eye(4)
    m[:3, :3] = np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * K @ K
    return m


def S(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return np.diag([x, y, z, 1.0])


def mul(*ms):
    out = np.eye(4)
    for m in ms:
        out = out @ m
    return out


def frame(origin, up, forward=None):
    """A transform at `origin` whose +Y is `up` (and +Z leans toward `forward`)."""
    up = unit(up)
    if forward is None or abs(np.dot(unit(forward), up)) > 0.98:
        forward = (0, 0, 1) if abs(up[2]) < 0.9 else (1, 0, 0)
    right = unit(np.cross(up, forward))
    back = np.cross(right, up)
    m = np.eye(4)
    m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = right, up, back, origin
    return m


def apply(m, points):
    p = np.asarray(points, dtype=float)
    return p @ m[:3, :3].T + m[:3, 3]


def perpendicular(direction):
    d = unit(direction)
    helper = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    side = unit(np.cross(d, helper))
    return side, np.cross(side, d)


# ---------------------------------------------------------------------------
# A mesh: triangles, each with a palette colour name, plus named points
# (4x4 frames) for the game, e.g. where fruit hangs.


class Mesh:
    def __init__(self, name=None):
        self.name = name
        self.tris = []
        self.cols = []
        self.points = {}

    def tri(self, a, b, c, col, out=None, inside=None, double=False):
        a, b, c = (np.asarray(p, dtype=float) for p in (a, b, c))
        normal = np.cross(b - a, c - a)
        if np.linalg.norm(normal) < 1e-10:
            return
        if inside is not None and np.dot(normal, (a + b + c) / 3 - np.asarray(inside, dtype=float)) < 0:
            b, c = c, b
        elif out is not None and np.dot(normal, out) < 0:
            b, c = c, b
        self.tris.append(np.array([a, b, c]))
        self.cols.append(col)
        if double:
            self.tris.append(np.array([a, c, b]))
            self.cols.append(col)

    def quad(self, a, b, c, d, col, **kw):
        self.tri(a, b, c, col, **kw)
        self.tri(a, c, d, col, **kw)

    def add(self, other, m=None, recolor=None):
        m = np.eye(4) if m is None else m
        for t, col in zip(other.tris, other.cols):
            self.tris.append(apply(m, t))
            self.cols.append(recolor.get(col, col) if recolor else col)
        for key, frames in other.points.items():
            self.points.setdefault(key, []).extend(m @ f for f in frames)
        return self

    def point(self, key, f):
        self.points.setdefault(key, []).append(np.asarray(f, dtype=float))

    def transformed(self, m):
        return Mesh(self.name).add(self, m)

    def array(self):
        return np.array(self.tris, dtype=float).reshape(-1, 3, 3) if self.tris else np.zeros((0, 3, 3))

    def bounds(self):
        p = self.array().reshape(-1, 3)
        return p.min(axis=0), p.max(axis=0)

    def __len__(self):
        return len(self.tris)


def pick(col, *args):
    return col(*args) if callable(col) else col


# ---------------------------------------------------------------------------
# Shapes. Each returns a Mesh in its own space (add it with a transform).


def lathe(profile, sides, col, lobe=None, spin=0.0, cap=True, squash=(1.0, 1.0), ring_spin=None):
    """A surface of revolution round +Y. profile: [(y, r)] bottom to top.
    lobe(theta) scales the radius round the axis (ribs, a star, a bell's
    lobes). An end with r = 0 closes to a point; otherwise `cap` closes it
    flat. col(i, k, normal) or a name; i counts rings from the bottom."""
    mesh = Mesh()
    rings = []
    for i, (y, r) in enumerate(profile):
        ring = []
        for k in range(sides):
            th = spin + 2 * math.pi * k / sides + (ring_spin(i) if ring_spin else 0.0)
            f = lobe(th) if lobe else 1.0
            ring.append(np.array([math.cos(th) * r * f * squash[0], y, math.sin(th) * r * f * squash[1]]))
        rings.append(ring)
    for i in range(len(rings) - 1):
        (y0, r0), (y1, r1) = profile[i], profile[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            a, b, c, d = rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]
            # (outward from the profile's direction, bottom to top, so dents
            # like an apple's dimple face the right way)
            mid = (a + b + c + d) / 4
            radial = unit(np.array([mid[0], 0.0, mid[2]]) + 1e-9)
            out = radial * (y1 - y0) + np.array([0.0, -(r1 - r0), 0.0])
            n = unit(out)
            colour = pick(col, i, k, n)
            if r0 < 1e-9:
                mesh.tri(a, c, d, colour, out=out)
            elif r1 < 1e-9:
                mesh.tri(a, b, c, colour, out=out)
            else:
                mesh.quad(a, b, c, d, colour, out=out)
    if cap:
        for end, out in ((0, -1.0), (len(profile) - 1, 1.0)):
            if profile[end][1] > 1e-9:
                y = profile[end][0]
                centre = np.array([0.0, y, 0.0])
                for k in range(sides):
                    a, b = rings[end][k], rings[end][(k + 1) % sides]
                    mesh.tri(centre, a, b, pick(col, end, k, np.array([0, out, 0])), out=np.array([0, out, 0]))
    return mesh


def tube(path, radii, sides, col, cap0=False, cap1=False, spin=0.0, flat=None):
    """A flat-sided tube along `path` (stems, stalks, vines). radii: one per
    point (0 closes to a point). col(i, k) or a name. flat=(x, y) squashes
    the cross-section (a strap)."""
    mesh = Mesh()
    path = [np.asarray(p, dtype=float) for p in path]
    # parallel-transported frames along the path (no twisting)
    t0 = unit(path[1] - path[0])
    side, up = perpendicular(t0)
    rings = []
    for i, p in enumerate(path):
        t = unit(path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)])
        side = unit(side - t * np.dot(side, t))
        up = np.cross(side, t)
        ring = []
        for k in range(sides):
            a = spin + 2 * math.pi * k / sides
            cx, cy = math.cos(a) * radii[i], math.sin(a) * radii[i]
            if flat:
                cx, cy = cx * flat[0], cy * flat[1]
            ring.append(p + side * cx + up * cy)
        rings.append(ring)
    for i in range(len(path) - 1):
        inside = (path[i] + path[i + 1]) / 2
        for k in range(sides):
            k2 = (k + 1) % sides
            a, b, c, d = rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]
            colour = pick(col, i, k)
            if radii[i] < 1e-9:
                mesh.tri(a, c, d, colour, inside=inside)
            elif radii[i + 1] < 1e-9:
                mesh.tri(a, b, c, colour, inside=inside)
            else:
                mesh.quad(a, b, c, d, colour, inside=inside)
    for end, cap, nxt in ((0, cap0, 1), (len(path) - 1, cap1, len(path) - 2)):
        if cap and radii[end] > 1e-9:
            out = path[end] - path[nxt]
            for k in range(sides):
                mesh.tri(path[end], rings[end][k], rings[end][(k + 1) % sides], pick(col, end, k), out=out)
    return mesh


def _icosphere(subdivisions):
    t = (1 + 5 ** 0.5) / 2
    verts = [unit(v) for v in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
                               (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
             (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5),
             (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(subdivisions):
        cache, new = {}, []

        def mid(i, j):
            key = (min(i, j), max(i, j))
            if key not in cache:
                verts.append(unit(verts[i] + verts[j]))
                cache[key] = len(verts) - 1
            return cache[key]

        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            new += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = new
    return np.array(verts), faces


ICO = {n: _icosphere(n) for n in (0, 1, 2)}


def blob(radii, col, rng=None, sub=1, jitter=0.0, flatten_bottom=None):
    """A faceted ball `radii` big round the origin (lumpy with `jitter`).
    col(normal) or a name. flatten_bottom: clamp y below this (sits flat)."""
    mesh = Mesh()
    verts, faces = ICO[sub]
    scale = 1 + (rng.uniform(-jitter, jitter, size=(len(verts), 1)) if jitter and rng is not None else 0)
    points = verts * np.asarray(radii, dtype=float) * scale
    if flatten_bottom is not None:
        points[:, 1] = np.maximum(points[:, 1], flatten_bottom)
    for a, b, c in faces:
        pa, pb, pc = points[a], points[b], points[c]
        n = unit(np.cross(pb - pa, pc - pa))
        mid = (pa + pb + pc) / 3
        if np.dot(n, mid) < 0:
            n = -n
        mesh.tri(pa, pb, pc, pick(col, n), inside=np.zeros(3))
    return mesh


def gem(r, col, h=None, sides=4):
    """A small bipyramid (a berry, a bud, a seed)."""
    mesh = Mesh()
    h = r if h is None else h
    ring = [np.array([math.cos(2 * math.pi * k / sides) * r, 0, math.sin(2 * math.pi * k / sides) * r]) for k in range(sides)]
    for tip, name in ((np.array([0, h, 0]), 0), (np.array([0, -h, 0]), 1)):
        for k in range(sides):
            mesh.tri(ring[k], ring[(k + 1) % sides], tip, pick(col, name, k), inside=np.zeros(3))
    return mesh


def box(size, col):
    mesh = Mesh()
    x, y, z = (s / 2 for s in size)
    c = [np.array(v) for v in [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]]
    for face, n in (((0, 1, 2, 3), (0, 0, -1)), ((4, 5, 6, 7), (0, 0, 1)), ((0, 1, 5, 4), (0, -1, 0)),
                    ((3, 2, 6, 7), (0, 1, 0)), ((0, 3, 7, 4), (-1, 0, 0)), ((1, 2, 6, 5), (1, 0, 0))):
        mesh.quad(*(c[i] for i in face), pick(col, np.array(n, dtype=float)), inside=np.zeros(3))
    return mesh


def leaf(length, width, col, segs=5, shape=None, curl=0.0, fold=0.15, rise=0.0, double=True):
    """A leaf lying along +Z from the origin, face up (+Y): its outline is
    `width` * shape(t) either side of the midrib (pointed at the tip), the
    midrib starts `rise` degrees above level and bends down by `curl`
    degrees over its length, and its halves fold up into a shallow V
    (`fold`: how far the edges lift, as a share of the half width).
    col = (left half, right half) or one name."""
    mesh = Mesh()
    shape = shape or (lambda t: math.sin(math.pi * min(t, 1.0)) ** 0.75)
    cols = col if isinstance(col, tuple) else (col, col)
    mid, left, right, normals = [], [], [], []
    p = np.zeros(3)
    angle = math.radians(rise)
    step = length / segs
    for i in range(segs + 1):
        t = i / segs
        if i:
            p = p + np.array([0, math.sin(angle), math.cos(angle)]) * step
            angle -= math.radians(curl) / segs
        half = 0.0 if i == segs else width / 2 * shape(t)
        normal = np.array([0, math.cos(angle), -math.sin(angle)])
        mid.append(p.copy())
        left.append(p + np.array([-half, 0, 0]) + normal * fold * half)
        right.append(p + np.array([half, 0, 0]) + normal * fold * half)
        normals.append(normal)
    for i in range(segs):
        out = normals[i] + normals[i + 1]
        for edge, colour in ((left, cols[0]), (right, cols[1])):
            a, b, c, d = mid[i], mid[i + 1], edge[i + 1], edge[i]
            if np.linalg.norm(c - b) < 1e-9:
                mesh.tri(a, b, d, colour, out=out, double=double)
            else:
                mesh.quad(a, b, c, d, colour, out=out, double=double)
    return mesh


def palm_leaf(length, width, col, lobes=5, spread=150.0, sinus=0.55, cup=0.0, double=True):
    """A flat palmate leaf (pumpkin, melon, grape): `lobes` pointed lobes
    fanning `spread` degrees from a centre on +Z, its stalk notch at the
    origin, face up. sinus: how deep the cuts between lobes run (share of
    the lobe length); cup lifts the rim by that many studs."""
    mesh = Mesh()
    cols = col if isinstance(col, tuple) else (col, col)
    centre = np.array([0.0, 0.0, length * 0.4])
    reach = length * 0.6
    outline = []
    n = lobes * 2
    for j in range(n + 1):
        a = math.radians(-spread + j * 2 * spread / n)
        if j in (0, n):
            r = length * 0.36
        elif j % 2:
            r = reach * (1.0 - 0.25 * abs(j - lobes) / lobes)
        else:
            r = reach * sinus
        outline.append(centre + np.array([math.sin(a) * r * width / length, cup * (r / reach), math.cos(a) * r]))
    hub = centre + np.array([0, -cup * 0.2, 0])
    notch = np.zeros(3)
    for j in range(n):
        mesh.tri(hub, outline[j], outline[j + 1], cols[(j // 2) % 2], out=(0, 1, 0), double=double)
    mesh.tri(hub, outline[n], notch, cols[0], out=(0, 1, 0), double=double)
    mesh.tri(hub, notch, outline[0], cols[1], out=(0, 1, 0), double=double)
    return mesh


# ---------------------------------------------------------------------------
# Palette texture: one 16 x 16 swatch per colour in a grid (big swatches so
# mipmaps far away don't bleed into neighbours).

SW = 16
COLS = 16


class Palette:
    def __init__(self, colours):
        self.names = list(colours)
        self.colours = colours

    def rgb(self, name):
        return self.colours[name]

    def uv(self, name):
        i = self.names.index(name)
        rows = math.ceil(len(self.names) / COLS)
        x, y = i % COLS, i // COLS
        return ((x + 0.5) / COLS, (y + 0.5) / rows)

    def image(self):
        rows = math.ceil(len(self.names) / COLS)
        image = Image.new("RGB", (SW * COLS, SW * rows), (255, 0, 255))
        for i, name in enumerate(self.names):
            x, y = i % COLS, i // COLS
            image.paste(tuple(self.colours[name]), (x * SW, y * SW, (x + 1) * SW, (y + 1) * SW))
        return image

    def png(self):
        out = BytesIO()
        self.image().save(out, format="PNG", optimize=True)
        return out.getvalue()


# ---------------------------------------------------------------------------
# GLB writer (glTF 2.0 binary): every textured mesh shares one palette
# material; untextured ones (glowing parts the game colours) share a plain
# white one.


def write_glb(path, meshes, palette, spacing=14.0, columns=10):
    """meshes: list of (Mesh, textured). Positions stay in each mesh's own
    (foot) space; the nodes are laid out on a grid so they don't overlap
    in Studio."""
    binary = bytearray()
    views, accessors, gl_meshes, nodes = [], [], [], []

    def view(data, target=None):
        while len(binary) % 4:
            binary.append(0)
        v = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(data)}
        if target:
            v["target"] = target
        binary.extend(data)
        views.append(v)
        return len(views) - 1

    def accessor(array, component, kind, target, bounds=False):
        a = {"bufferView": view(array.tobytes(), target), "componentType": component, "count": len(array), "type": kind}
        if bounds:
            a["min"] = array.min(axis=0).tolist()
            a["max"] = array.max(axis=0).tolist()
        accessors.append(a)
        return len(accessors) - 1

    png_view = view(palette.png())
    for index, (mesh, textured) in enumerate(meshes):
        # (glTF faces +Z and Studio's importer turns that to face Roblox's
        # front, -Z: turn each mesh round first so it lands as drawn)
        tris = mesh.array() * np.array([-1.0, 1.0, -1.0])
        positions = tris.reshape(-1, 3).astype(np.float32)
        a, b, c = tris[:, 0], tris[:, 1], tris[:, 2]
        normals = np.cross(b - a, c - a)
        normals /= np.linalg.norm(normals, axis=1, keepdims=True) + 1e-12
        normals = np.repeat(normals, 3, axis=0).astype(np.float32)
        uvs = np.repeat(np.array([palette.uv(col) for col in mesh.cols], dtype=np.float32), 3, axis=0)
        indices = np.arange(len(positions), dtype=np.uint32)
        attrs = {
            "POSITION": accessor(positions, 5126, "VEC3", 34962, bounds=True),
            "NORMAL": accessor(normals, 5126, "VEC3", 34962),
        }
        if textured:
            attrs["TEXCOORD_0"] = accessor(uvs, 5126, "VEC2", 34962)
        idx = accessor(indices, 5125, "SCALAR", 34963)
        gl_meshes.append({"name": mesh.name, "primitives": [{"attributes": attrs, "indices": idx, "material": 0 if textured else 1}]})
        nodes.append({"name": mesh.name, "mesh": index,
                      "translation": [float((index % columns) * spacing), 0.0, float((index // columns) * spacing)]})
    gltf = {
        "asset": {"version": "2.0", "generator": "Farm Heist crop generator"},
        "scene": 0,
        "scenes": [{"name": "CropModels", "nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": gl_meshes,
        "materials": [
            {"name": "CropPalette", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.85}},
            {"name": "CropPlain", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.85}},
        ],
        "textures": [{"sampler": 0, "source": 0}],
        "images": [{"name": "CropPalette", "bufferView": png_view, "mimeType": "image/png"}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(binary)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(binary) % 4:
        binary.append(0)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binary)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(binary), 0x004E4942))
        f.write(binary)
