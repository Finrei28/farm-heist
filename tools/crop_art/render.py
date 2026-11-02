"""A small software renderer for checking crop meshes by eye before Studio:
perspective camera, back faces culled (as Roblox culls them), the sun with
shadows (a shadow map), sky light, supersampled edges. Close enough to
Studio's daytime look to judge shapes, colours and what hides what."""
import math

import numpy as np
from PIL import Image

SUN = np.array([0.42, 0.78, 0.46])  # (towards the sun)
SKY_TOP = np.array([120, 172, 226]) / 255
SKY_LOW = np.array([196, 222, 242]) / 255


def _unit(v):
    v = np.asarray(v, dtype=float)
    return v / (np.linalg.norm(v) + 1e-12)


def _raster(xs, ys, inv_z, width, height, depth, ids, tri_index, keep_max=True):
    """Draws one triangle (screen xs, ys; inv_z per vertex: bigger is
    nearer) into depth/ids. Returns (mask, rows, cols, barycentrics) for
    the pixels it won, or None."""
    x0, x1 = int(max(0, math.floor(xs.min()))), int(min(width - 1, math.ceil(xs.max())))
    y0, y1 = int(max(0, math.floor(ys.min()))), int(min(height - 1, math.ceil(ys.max())))
    if x1 < x0 or y1 < y0:
        return None
    area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
    if abs(area) < 1e-12:
        return None
    px, py = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    w0 = ((xs[1] - px) * (ys[2] - py) - (xs[2] - px) * (ys[1] - py)) / area
    w1 = ((xs[2] - px) * (ys[0] - py) - (xs[0] - px) * (ys[2] - py)) / area
    w2 = 1 - w0 - w1
    inside = (w0 >= -1e-9) & (w1 >= -1e-9) & (w2 >= -1e-9)
    if not inside.any():
        return None
    z = w0 * inv_z[0] + w1 * inv_z[1] + w2 * inv_z[2]
    region = depth[y0:y1 + 1, x0:x1 + 1]
    won = inside & (z > region)
    if not won.any():
        return None
    region[won] = z[won]
    if ids is not None:
        ids[y0:y1 + 1, x0:x1 + 1][won] = tri_index
    return won, (y0, y1, x0, x1), (w0, w1, w2)


def render(tris, colours, eye, target, size=(960, 600), fov=36.0, ss=2, shadows=True, sun=SUN, ground_y=None):
    """tris: (N, 3, 3) world triangles (counter-clockwise from the front, as
    Roblox draws them); colours: (N, 3) in 0..1. Returns a PIL image."""
    tris = np.asarray(tris, dtype=float)
    colours = np.asarray(colours, dtype=float)
    width, height = size[0] * ss, size[1] * ss
    eye, target = np.asarray(eye, dtype=float), np.asarray(target, dtype=float)
    forward = _unit(target - eye)
    right = _unit(np.cross(forward, [0, 1, 0]))
    up = np.cross(right, forward)
    focal = (height / 2) / math.tan(math.radians(fov) / 2)

    normals = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    normals /= np.linalg.norm(normals, axis=1, keepdims=True) + 1e-12
    centres = tris.mean(axis=1)
    facing = np.einsum("ij,ij->i", normals, eye - centres) > 0

    rel = tris - eye
    cx = rel @ right
    cy = rel @ up
    cz = rel @ forward
    sx = width / 2 + cx / np.maximum(cz, 1e-6) * focal
    sy = height / 2 - cy / np.maximum(cz, 1e-6) * focal

    depth = np.full((height, width), -np.inf)
    ids = np.full((height, width), -1, dtype=np.int64)
    order = np.where(facing & (cz.min(axis=1) > 0.05))[0]
    for t in order:
        _raster(sx[t], sy[t], 1 / cz[t], width, height, depth, ids, t)

    # Per pixel: the world point (from depth along the view ray).
    hit = ids >= 0
    py, px = np.nonzero(hit)
    dz = 1 / depth[py, px]
    ray_x = (px + 0.5 - width / 2) / focal
    ray_y = -(py + 0.5 - height / 2) / focal
    world = eye + (right[None] * ray_x[:, None] + up[None] * ray_y[:, None] + forward[None]) * dz[:, None]
    tid = ids[py, px]
    n = normals[tid]

    sun = _unit(sun)
    lit = np.ones(len(tid))
    if shadows:
        lit = _shadow(tris, world, sun, n)
    diffuse = np.clip(n @ sun, 0, 1) * lit
    sky = 0.5 + 0.5 * n[:, 1]
    shade = 0.46 + 0.12 * sky + 0.62 * diffuse
    rgb = colours[tid] * shade[:, None]

    image = np.empty((height, width, 3))
    grad = np.linspace(0, 1, height)[:, None]
    image[:] = (SKY_TOP[None] * (1 - grad) + SKY_LOW[None] * grad)[:, None, :]
    image[py, px] = np.clip(rgb, 0, 1)
    out = Image.fromarray((image * 255).astype(np.uint8))
    return out.resize(size, Image.LANCZOS) if ss > 1 else out


def _shadow(tris, points, sun, normals, res=2048):
    """1 where `points` see the sun, 0 in shadow (a 3x3-filtered map)."""
    lr = _unit(np.cross(sun, [0, 0, 1]) if abs(sun[2]) < 0.9 else np.cross(sun, [1, 0, 0]))
    lu = np.cross(lr, sun)
    flat = tris.reshape(-1, 3)
    lx, ly = flat @ lr, flat @ lu
    lo = np.array([lx.min(), ly.min()]) - 0.5
    hi = np.array([lx.max(), ly.max()]) + 0.5
    scale = (res - 1) / max(hi - lo)
    sx = ((tris @ lr) - lo[0]) * scale
    sy = ((tris @ lu) - lo[1]) * scale
    sd = tris @ sun
    offset = sd.min() - 1
    depth = np.full((res, res), -np.inf)
    for t in range(len(tris)):
        # (orthographic: depth itself is linear across the triangle)
        _raster(sx[t], sy[t], sd[t] - offset, res, res, depth, None, t)
    qx = ((points @ lr) - lo[0]) * scale
    qy = ((points @ lu) - lo[1]) * scale
    qd = points @ sun - offset
    bias = 0.06 + 0.12 * (1 - np.clip(np.abs(normals @ sun), 0, 1))
    seen = np.zeros(len(points))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            ix = np.clip((qx + dx).astype(int), 0, res - 1)
            iy = np.clip((qy + dy).astype(int), 0, res - 1)
            seen += depth[iy, ix] <= qd + bias
    return seen / 9
