"""Generates Farm Heist's meshes: low-poly, flat-shaded plants, fruit and
containers sharing one palette texture, packed into one GLB for Roblox
Studio's 3D importer; the patch layouts, carried loads and shelf pieces the
game places them in; the props (wild land, the yard) in a second GLB with
the obstacles and grass an overgrown block is laid out with; and previews
to check every one by eye.

    python tools/crop_art/generate.py                 everything
    python tools/crop_art/generate.py Carrot Wheat    just these crops' previews
    python tools/crop_art/generate.py --carried       the carried loads' sheet
    python tools/crop_art/generate.py --shelf         the shelf pieces' sheet
    python tools/crop_art/generate.py --props         the props' previews

Outputs:
    art/crops/FarmHeistCrops.glb        import in Studio (Home > Import 3D),
                                        rename the model CropModels and put it
                                        in ReplicatedStorage
    art/props/FarmHeistProps.glb        the same, as PropModels
    art/crops/previews/<Crop>.png       each crop's patch, growing and ripe
    art/crops/previews/carried.png      what a thief holds, crop by crop
    art/crops/previews/shelf.png        a piece of each crop on a shelf
    art/props/previews/*.png            each prop, an overgrown block
    art/crops/contact_sheet.png         every mesh at a glance (and props')
    src/server/World/CropMeshData.luau  sizes, centres, patch layouts, carried
                                        loads, shelf pieces (the game reads it)
    src/server/World/PropMeshData.luau  the props' sizes and the wild land
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from carried import CARRIED  # noqa: E402
from crops import MESHES, PATCHES, built  # noqa: E402
from meshkit import Mesh, Palette, T, box, mul, write_glb  # noqa: E402
from palette import COLOURS, PROP_COLOURS  # noqa: E402
from props import PROPS, built as built_prop  # noqa: E402
from render import render  # noqa: E402
from scene import lawn, stage  # noqa: E402
from shelves import SHELF, piece  # noqa: E402
from wild import GRASS, OBSTACLES  # noqa: E402
import props_preview  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art", "crops")
PROPS_OUT = os.path.join(ROOT, "art", "props")
DATA = os.path.join(ROOT, "src", "server", "World", "CropMeshData.luau")
PROP_DATA = os.path.join(ROOT, "src", "server", "World", "PropMeshData.luau")
PALETTE = Palette(COLOURS)
PROP_PALETTE = Palette(PROP_COLOURS)


def colours_of(world, palette=PALETTE):
    return np.array([np.array(palette.rgb(c)) / 255 for c in world.cols])


def scale_matrix(s):
    sx, sy, sz = s if isinstance(s, tuple) else (s, s, s)
    return np.diag([sx, sy, sz, 1.0])


def place(items):
    return [(name, m @ scale_matrix(s)) for name, m, s in items]


def shot(world, eye, target, size=(720, 450), ss=2):
    return render(world.array(), colours_of(world), eye, target, size=size, ss=ss)


def most_of(spec):
    return spec.get("most", math.ceil(spec["per"] * 1.5))


# ---------------------------------------------------------------------------
# Previews


def preview(crop, meshes, out_dir):
    spec = PATCHES[crop]
    per = spec["per"]
    shots = []
    for stage_name, n in (("Growing", per), ("Ripe", per), ("Ripe", most_of(spec))):
        world = stage(place(spec["build"](stage_name, n)), meshes, figure_at=T(8.6, -0.5, 1.5))
        shots.append((f"{stage_name} {n}", shot(world, (16, 13, -19), (0, 1.6, 0))))
    items = place(spec["build"]("Ripe", per))
    world = stage(items, meshes)
    shots.append(("close", shot(world, (5.5, 4.2, -8.5), (0, 1.2, 0))))
    shots.append(("from the farmhouse", shot(world, (0, 18, -46), (0, 1, 0))))
    shots.append(("above", shot(world, (0.01, 22, -6), (0, 0, 0))))
    w, h = shots[0][1].size
    sheet = Image.new("RGB", (w * 3, (h + 20) * 2), (240, 240, 240))
    draw = ImageDraw.Draw(sheet)
    for i, (label, image) in enumerate(shots):
        x, y = (i % 3) * w, (i // 3) * (h + 20)
        sheet.paste(image, (x, y))
        draw.text((x + 6, y + h + 3), f"{crop}: {label}", fill=(30, 30, 30))
    path = os.path.join(out_dir, f"{crop}.png")
    sheet.save(path)
    return path


def carried_sheet(meshes, path, crops=None):
    crops = crops or list(CARRIED)
    cell = (360, 300)
    cols = 6
    rows = math.ceil(len(crops) / cols)
    sheet = Image.new("RGB", (cell[0] * cols, (cell[1] + 18) * rows), (240, 240, 240))
    draw = ImageDraw.Draw(sheet)
    for i, crop in enumerate(crops):
        n = PATCHES[crop]["per"]
        items, width, height, hold = CARRIED[crop](n)
        world = Mesh()
        world.add(lawn(half=6, step=1.0, y=0))
        for name, m in place(items):
            world.add(meshes[name], m)
        # (the hands: two little blocks where they'd hold it)
        for sx in (-1, 1):
            world.add(Mesh().add(_hand()), T(sx * (width / 2 + 0.15), hold, 0))
        d = max(width, height) * 1.6 + 2
        image = shot(world, (d * 0.55, height * 0.6 + d * 0.35, -d * 0.8), (0, height * 0.45, 0), size=cell)
        x, y = (i % cols) * cell[0], (i // cols) * (cell[1] + 18)
        sheet.paste(image, (x, y))
        draw.text((x + 6, y + cell[1] + 2), f"{crop} x{n}  w {width:.2f} h {height:.2f} hold {hold:.2f}", fill=(30, 30, 30))
    sheet.save(path)
    return path


def _hand():
    from meshkit import box
    return box((0.3, 0.3, 0.3), "skin")


def shelf_sheet(meshes, path):
    """A piece of each crop as a display shows it: a row of them on a plank,
    and one on a crate's top, beside a figure's hand for scale."""
    crops = list(SHELF)
    cell, cols = (300, 220), 6
    rows = math.ceil(len(crops) / cols)
    sheet = Image.new("RGB", (cell[0] * cols, (cell[1] + 18) * rows), (240, 240, 240))
    draw = ImageDraw.Draw(sheet)
    for i, crop in enumerate(crops):
        variants, size = piece(crop)
        world = Mesh()
        world.add(box((4.0, 0.2, 1.6), "wood"), T(0, -0.1, 0))
        for j in range(3):
            x = (j - 1) * max(size[0], 0.85) * 1.05
            for name, m, s in variants[j % len(variants)]:
                turn = np.eye(4) if j % 2 == 0 else np.diag([-1.0, 1.0, -1.0, 1.0])
                world.add(meshes[name], T(x, 0, 0) @ turn @ m @ np.diag([s, s, s, 1.0]))
        d = 4.2
        image = shot(world, (d * 0.35, d * 0.55, -d * 0.9), (0, size[1] * 0.4, 0), size=cell)
        x, y = (i % cols) * cell[0], (i // cols) * (cell[1] + 18)
        sheet.paste(image, (x, y))
        draw.text((x + 6, y + cell[1] + 2), f"{crop} {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}", fill=(30, 30, 30))
    sheet.save(path)
    return path


def contact_sheet(meshes, path, palette=PALETTE):
    names = list(meshes)
    cell, cols = 200, 9
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cell * cols, (cell + 16) * rows), (232, 238, 244))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        m = meshes[name]
        lo, hi = m.bounds()
        c = (lo + hi) / 2
        d = max(hi - lo) * 1.5 + 0.5
        world = Mesh().add(m)
        image = render(world.array(), colours_of(world, palette), c + np.array([d * 0.6, d * 0.45, -d * 0.75]), c, size=(cell, cell), ss=2, shadows=False)
        x, y = (i % cols) * cell, (i // cols) * (cell + 16)
        sheet.paste(image, (x, y))
        draw.text((x + 4, y + cell + 1), f"{name} {len(m)}", fill=(30, 30, 30))
    sheet.save(path)
    return path


# ---------------------------------------------------------------------------
# The game's data


def euler_xyz(r):
    """Angles (rx, ry, rz) with R = Rx Ry Rz, as CFrame.fromEulerAnglesXYZ
    (CFrame.Angles) builds it."""
    cb = math.hypot(r[0, 0], r[0, 1])
    b = math.atan2(r[0, 2], cb)
    if cb > 1e-6:
        a = math.atan2(-r[1, 2], r[2, 2])
        c = math.atan2(-r[0, 1], r[0, 0])
    else:
        a = math.atan2(r[2, 1], r[1, 1])
        c = 0.0
    return a, b, c


def _rot(a, b, c):
    ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    rx = np.array([[1, 0, 0], [0, ca, -sa], [0, sa, ca]])
    ry = np.array([[cb, 0, sb], [0, 1, 0], [-sb, 0, cb]])
    rz = np.array([[cc, -sc, 0], [sc, cc, 0], [0, 0, 1]])
    return rx @ ry @ rz


def num(v, places=3):
    text = f"{v:.{places}f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def item_lua(name, m, s):
    rot = m[:3, :3]
    a, b, c = euler_xyz(rot)
    assert np.allclose(_rot(a, b, c), rot, atol=1e-4), (name, rot)
    parts = [f'"{name}"'] + [num(v) for v in m[:3, 3]] + [num(v, 4) for v in (a, b, c)]
    parts += [num(v) for v in (s if isinstance(s, tuple) else (s,))]
    return "{" + ", ".join(parts) + "}"


def write_data(meshes):
    lines = [
        "-- Generated by tools/crop_art/generate.py: don't edit it by hand.",
        "--",
        "-- meshes[name]: size and centre (its bounding box, in studs, from the",
        "-- point it stands on), and for the glowing ones the material and colour.",
        "-- patches[crop].Growing / .Ripe[count], carried[crop][count]: items",
        "-- { mesh, x, y, z, rx, ry, rz, scale } (or sx, sy, sz) from the tile's",
        "-- top middle or the load's bottom middle, CFrame.new(x, y, z) *",
        "-- CFrame.fromEulerAnglesXYZ(rx, ry, rz). See server/World/Meshes.",
        "return {",
        "\tmeshes = {",
    ]
    for name, m in meshes.items():
        lo, hi = m.bounds()
        size, centre = hi - lo, (lo + hi) / 2
        spec = MESHES[name]
        extra = ""
        if not spec["textured"]:
            r, g, b = spec["colour"]
            extra = f', material = "{spec["material"]}", colour = Color3.fromRGB({r}, {g}, {b})'
        lines.append(f"\t\t{name} = {{ size = Vector3.new({', '.join(num(v) for v in size)}), "
                     f"centre = Vector3.new({', '.join(num(v) for v in centre)}){extra} }},")
    lines += ["\t},", "\tpatches = {"]
    for crop, spec in PATCHES.items():
        lines.append(f"\t\t{crop} = {{")
        lines.append("\t\t\tGrowing = { " + ", ".join(item_lua(*it) for it in spec["build"]("Growing", spec["per"])) + " },")
        lines.append("\t\t\tRipe = {")
        for n in range(1, most_of(spec) + 1):
            lines.append("\t\t\t\t{ " + ", ".join(item_lua(*it) for it in spec["build"]("Ripe", n)) + " },")
        lines.append("\t\t\t},")
        lines.append("\t\t},")
    lines += ["\t},", "\tcarried = {"]
    for crop, build in CARRIED.items():
        lines.append(f"\t\t{crop} = {{")
        for n in range(1, most_of(PATCHES[crop]) + 1):
            items, width, height, hold = build(n)
            lines.append(f"\t\t\t{{ width = {num(width)}, height = {num(height)}, hold = {num(hold)}, items = {{ "
                         + ", ".join(item_lua(*it) for it in items) + " } },")
        lines.append("\t\t},")
    lines += ["\t},", "\tshelf = {"]
    for crop in SHELF:
        variants, size = piece(crop)
        lines.append(f"\t\t{crop} = {{ size = Vector3.new({', '.join(num(v) for v in size)}), pieces = {{")
        for items in variants:
            lines.append("\t\t\t{ " + ", ".join(item_lua(*it) for it in items) + " },")
        lines.append("\t\t} },")
    lines += ["\t},", "}", ""]
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return DATA


def write_props(meshes):
    lines = [
        "-- Generated by tools/crop_art/generate.py: don't edit it by hand.",
        "--",
        "-- meshes[name]: size and centre (its bounding box, in studs, from the",
        "-- point it stands on). wild.obstacles[kind]: items from an overgrown",
        "-- tile's top middle; wild.grass: items from an overgrown block's top",
        "-- middle. Items as in CropMeshData. See server/World/Meshes.",
        "return {",
        "\tmeshes = {",
    ]
    for name, m in meshes.items():
        lo, hi = m.bounds()
        size, centre = hi - lo, (lo + hi) / 2
        lines.append(f"\t\t{name} = {{ size = Vector3.new({', '.join(num(v) for v in size)}), "
                     f"centre = Vector3.new({', '.join(num(v) for v in centre)}) }},")
    lines += ["\t},", "\twild = {", "\t\tobstacles = {"]
    for kind, items in OBSTACLES.items():
        lines.append(f"\t\t\t{kind} = {{ " + ", ".join(item_lua(*it) for it in items) + " },")
    lines += ["\t\t},", "\t\tgrass = { " + ", ".join(item_lua(*it) for it in GRASS) + " },", "\t},", "}", ""]
    with open(PROP_DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return PROP_DATA


def check_props(meshes):
    """Every obstacle stays on its tile and the grass on its block, from
    any turn (the game turns them)."""
    problems = []

    def reach(items):
        pts = []
        for name, m, s in items:
            sc = np.array(s if isinstance(s, tuple) else (s, s, s))
            tris = meshes[name].array().reshape(-1, 3) * sc
            pts.append(tris @ m[:3, :3].T + m[:3, 3])
        return np.concatenate(pts)
    for kind, items in OBSTACLES.items():
        p = reach(items)
        r = np.hypot(p[:, 0], p[:, 2]).max()
        if r > 5.9:
            problems.append(f"obstacle {kind}: reaches {r:.2f} from its tile's middle (the tile's edge is 5.7)")
    p = reach(GRASS)
    side = max(np.abs(p[:, 0]).max(), np.abs(p[:, 2]).max())
    if side > 11.9:
        problems.append(f"grass: reaches {side:.2f} from the block's middle (its edge is 11.7)")
    for (dx, dz) in ((-6, -6), (6, -6), (-6, 6), (6, 6)):
        for name, m, s in GRASS:
            if math.hypot(m[0, 3] - dx, m[2, 3] - dz) < 3.6:
                problems.append(f"grass {name} at ({m[0, 3]:.1f}, {m[2, 3]:.1f}) is on the obstacle at ({dx}, {dz})")
    return problems


def check(meshes):
    """Every patch stays on its tile (11.4 studs a side) and above its
    soil; every carried load within the width and height it says."""
    problems = []

    def reach(items):
        pts = []
        for name, m in place(items):
            tris = meshes[name].array().reshape(-1, 3)
            pts.append(tris @ m[:3, :3].T + m[:3, 3])
        return np.concatenate(pts)
    for crop, spec in PATCHES.items():
        layouts = [("Growing", spec["build"]("Growing", spec["per"]))]
        layouts += [(f"Ripe {n}", spec["build"]("Ripe", n)) for n in range(1, most_of(spec) + 1)]
        for label, items in layouts:
            p = reach(items)
            side = max(np.abs(p[:, 0]).max(), np.abs(p[:, 2]).max())
            # (leaves may lean a little past the tile's edge, 5.7, not as far
            # as the next tile's, 6.3; roots go down into the soil)
            if side > 5.95:
                problems.append(f"{crop} {label}: reaches {side:.2f} from the middle (the tile's edge is 5.7)")
            deepest = -2.3 if crop == "Carrot" else -0.9
            if p[:, 1].min() < deepest:
                problems.append(f"{crop} {label}: goes {p[:, 1].min():.2f} down, through the tile")
    for crop, build in CARRIED.items():
        for n in range(1, most_of(PATCHES[crop]) + 1):
            items, width, height, hold = build(n)
            p = reach(items)
            # (the width is where the hands go: ears and leaves may reach past it)
            if np.abs(p[:, 0]).max() > width / 2 + 0.6 or p[:, 1].max() > height + 0.01 or p[:, 1].min() < -0.01:
                problems.append(f"{crop} carried {n}: x {np.abs(p[:, 0]).max():.2f}, y {p[:, 1].min():.2f}..{p[:, 1].max():.2f} "
                                f"(says {width:.2f} wide, {height:.2f} high)")
    return problems


# ---------------------------------------------------------------------------


def main(argv):
    os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)
    meshes = {name: built(name) for name in MESHES}
    if argv == ["--carried"]:
        print("carried", carried_sheet(meshes, os.path.join(OUT, "previews", "carried.png")))
        return
    if argv == ["--shelf"]:
        print("shelf", shelf_sheet(meshes, os.path.join(OUT, "previews", "shelf.png")))
        return
    os.makedirs(os.path.join(PROPS_OUT, "previews"), exist_ok=True)
    if argv == ["--props"]:
        print("props", props_preview.prop_sheet(os.path.join(PROPS_OUT, "previews", "props.png")))
        print("wild", props_preview.overgrowth_preview(os.path.join(PROPS_OUT, "previews", "overgrowth.png")))
        return
    if argv:
        for crop in argv:
            print("preview", preview(crop, meshes, os.path.join(OUT, "previews")))
        return
    total = 0
    for name, m in meshes.items():
        lo, hi = m.bounds()
        total += len(m)
        print(f"  {name:<20} {len(m):5d} tris  {hi[0]-lo[0]:5.2f} x {hi[1]-lo[1]:5.2f} x {hi[2]-lo[2]:5.2f}")
    print(f"  {len(meshes)} meshes, {total} tris")
    props = {name: built_prop(name) for name in PROPS}
    for name, m in props.items():
        lo, hi = m.bounds()
        total += len(m)
        print(f"  {name:<20} {len(m):5d} tris  {hi[0]-lo[0]:5.2f} x {hi[1]-lo[1]:5.2f} x {hi[2]-lo[2]:5.2f}  (prop)")
    problems = check(meshes) + check_props(props)
    for problem in problems:
        print("PROBLEM", problem)
    if problems:
        sys.exit(1)
    glb = os.path.join(OUT, "FarmHeistCrops.glb")
    write_glb(glb, [(m, MESHES[name]["textured"]) for name, m in meshes.items()], PALETTE)
    print("wrote", glb, os.path.getsize(glb), "bytes")
    print("wrote", write_data(meshes), os.path.getsize(DATA), "bytes")
    props_glb = os.path.join(PROPS_OUT, "FarmHeistProps.glb")
    write_glb(props_glb, [(m, PROPS[name]["textured"]) for name, m in props.items()], PROP_PALETTE, scene="PropModels", material="Prop")
    print("wrote", props_glb, os.path.getsize(props_glb), "bytes")
    print("wrote", write_props(props), os.path.getsize(PROP_DATA), "bytes")
    print("wrote", contact_sheet(meshes, os.path.join(OUT, "contact_sheet.png")))
    print("wrote", contact_sheet(props, os.path.join(PROPS_OUT, "contact_sheet.png"), PROP_PALETTE))
    print("wrote", shelf_sheet(meshes, os.path.join(OUT, "previews", "shelf.png")))
    print("wrote", props_preview.prop_sheet(os.path.join(PROPS_OUT, "previews", "props.png")))
    print("wrote", props_preview.overgrowth_preview(os.path.join(PROPS_OUT, "previews", "overgrowth.png")))
    print("wrote", carried_sheet(meshes, os.path.join(OUT, "previews", "carried.png")))
    for crop in PATCHES:
        print("preview", preview(crop, meshes, os.path.join(OUT, "previews")))


if __name__ == "__main__":
    main(sys.argv[1:])
