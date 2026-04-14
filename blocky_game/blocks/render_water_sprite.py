"""
Hotbar sprite for water_v2: same triplanar sampling + tint as water_triplanar.gdshader,
then dirt_sprite bright rim only. Keeps z-fight tie-break from prior version.

Run from project root:
  python blocky_game/blocks/render_water_sprite.py
"""
from __future__ import annotations

import math
import os
from typing import List, Optional, Tuple

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))

# Must match water_v2/water_triplanar.gdshader
UV_SCALE = 0.22
TINT_R = 1.0
TINT_G = 1.0
TINT_B = 1.0
TINT_A = 0.55

Vec3 = Tuple[float, float, float]
Vec2 = Tuple[float, float]


def _lum(p: Tuple[int, ...]) -> float:
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def _norm(v: Vec3) -> Vec3:
    L = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if L < 1e-9:
        return (0.0, 0.0, 0.0)
    return (v[0] / L, v[1] / L, v[2] / L)


def _sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def parse_obj(path: str) -> tuple[List[Vec3], List[Vec3], List[List[tuple[int, int, int]]]]:
    verts: List[Vec3] = []
    normals: List[Vec3] = []
    faces: List[List[tuple[int, int, int]]] = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if parts[0] == "v":
                verts.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == "vn":
                normals.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == "f":
                face: List[tuple[int, int, int]] = []
                for corner in parts[1:]:
                    inds = corner.split("/")
                    vi = int(inds[0]) - 1
                    vni = int(inds[2]) - 1 if len(inds) > 2 and inds[2] else -1
                    face.append((vi, 0, vni))
                faces.append(face)
    return verts, normals, faces


def triangulate(face: List[tuple[int, int, int]]) -> List[List[tuple[int, int, int]]]:
    return [[face[0], face[i], face[i + 1]] for i in range(1, len(face) - 1)]


def edge(ax: float, ay: float, bx: float, by: float, px: float, py: float) -> float:
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax)


def _fract(x: float) -> float:
    return x - math.floor(x)


def sample_tex_nearest(tex: Image.Image, u: float, v: float) -> tuple[int, int, int, int]:
    """repeat_enable + filter_nearest, Godot-style UV (v up)."""
    u = _fract(u)
    v = _fract(v)
    w, h = tex.size
    x = min(w - 1, max(0, int(u * w)))
    y = min(h - 1, max(0, int((1.0 - v) * h)))
    p = tex.getpixel((x, y))
    if len(p) == 4:
        return int(p[0]), int(p[1]), int(p[2]), int(p[3])
    return int(p[0]), int(p[1]), int(p[2]), 255


def triplanar_rgba(tex: Image.Image, wpos: Vec3, wnorm: Vec3, scale: float) -> tuple[int, int, int, int]:
    """Mirror water_triplanar.gdshader fragment(). wpos = model position for one block at origin."""
    nx, ny, nz = wnorm[0], wnorm[1], wnorm[2]
    bx = abs(nx)
    by = abs(ny)
    bz = abs(nz)
    s = bx + by + bz + 1e-5
    bx /= s
    by /= s
    bz /= s
    x, y, z = wpos[0], wpos[1], wpos[2]
    uv_x = (z * scale, y * scale)
    uv_y = (x * scale, z * scale)
    uv_z = (x * scale, y * scale)
    cx = sample_tex_nearest(tex, uv_x[0], uv_x[1])
    cy = sample_tex_nearest(tex, uv_y[0], uv_y[1])
    cz = sample_tex_nearest(tex, uv_z[0], uv_z[1])
    r = int(cx[0] * bx + cy[0] * by + cz[0] * bz)
    g = int(cx[1] * bx + cy[1] * by + cz[1] * bz)
    b = int(cx[2] * bx + cy[2] * by + cz[2] * bz)
    a = int(cx[3] * bx + cy[3] * by + cz[3] * bz)
    # albedo_tint
    r = max(0, min(255, int(r * TINT_R)))
    g = max(0, min(255, int(g * TINT_G)))
    b = max(0, min(255, int(b * TINT_B)))
    a = max(0, min(255, int(a * TINT_A)))
    return r, g, b, a


# Plate behind translucent sample for opaque UI (same family as in-world over depth).
_ICON_BG = (14, 52, 108)


def flatten_for_icon(r: int, g: int, b: int, a: int) -> tuple[int, int, int, int]:
    af = a / 255.0
    br, bg_, bb = _ICON_BG
    return (
        max(0, min(255, int(r * af + br * (1.0 - af)))),
        max(0, min(255, int(g * af + bg_ * (1.0 - af)))),
        max(0, min(255, int(b * af + bb * (1.0 - af)))),
        255,
    )


def texture_edge_colors(tex: Image.Image) -> tuple[int, int, int, int]:
    """Bright rim RGBA from water_albedo edges (matches block palette)."""
    w, h = tex.size
    rim_px: List[tuple[int, int, int, int]] = []
    for y in range(h):
        for x in range(w):
            p = tex.getpixel((x, y))
            if len(p) < 4 or p[3] < 30:
                continue
            on_edge = x <= 1 or y <= 1 or x >= w - 2 or y >= h - 2
            if on_edge and _lum(p) > 145:
                rim_px.append((int(p[0]), int(p[1]), int(p[2]), int(p[3])))
    if not rim_px:
        p = tex.getpixel((w // 2, h - 2))
        rim_px = [(int(p[0]), int(p[1]), int(p[2]), min(255, int(p[3]) if len(p) > 3 else 255))]
    ar = sum(p[0] for p in rim_px) // len(rim_px)
    ag = sum(p[1] for p in rim_px) // len(rim_px)
    ab = sum(p[2] for p in rim_px) // len(rim_px)
    aa = min(255, sum(p[3] for p in rim_px) // len(rim_px))
    return ar, ag, ab, aa


def raster_water_triplanar(tex: Image.Image, dirt: Image.Image, obj_path: str) -> Image.Image:
    verts, normals, faces = parse_obj(obj_path)
    dirt_bbox = dirt.getbbox()
    if dirt_bbox is None:
        dirt_bbox = (0, 0, 64, 64)
    dl, dt, dr, db = dirt_bbox
    tw, th = dirt.size

    center: Vec3 = (0.5, 0.5, 0.5)
    eye: Vec3 = (1.15, 0.82, 1.12)
    view_to_cam = _norm(_sub(eye, center))
    forward = _norm(_sub(center, eye))
    world_up: Vec3 = (0.0, 1.0, 0.0)
    right = _norm(_cross(world_up, forward))
    up = _cross(forward, right)

    proj: List[Tuple[float, float, float]] = []
    for v in verts:
        pc = _sub(v, center)
        sx = _dot(pc, right)
        sy = _dot(pc, up)
        sz = _dot(pc, forward)
        proj.append((sx, sy, sz))

    xs = [p[0] for p in proj]
    ys = [p[1] for p in proj]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    pad = 0.08 * max(max_x - min_x, max_y - min_y, 1e-3)
    min_x -= pad
    max_x += pad
    min_y -= pad
    max_y += pad
    span_x = max(max_x - min_x, 1e-6)
    span_y = max(max_y - min_y, 1e-6)

    def to_pixel(sx: float, sy: float) -> Tuple[float, float]:
        nx = (sx - min_x) / span_x
        ny = (sy - min_y) / span_y
        px_ = dl + nx * (dr - dl)
        py_ = dt + ny * (db - dt)
        return px_, py_

    screen: List[Tuple[float, float, float]] = []
    for sx, sy, sz in proj:
        px_, py_ = to_pixel(sx, sy)
        screen.append((px_, py_, sz))

    tris: List[Tuple[Vec2, Vec2, Vec2, Vec3, Vec3, Vec3, float, float, float, Vec3]] = []
    for face in faces:
        for tri in triangulate(face):
            (i0, _ti0, ni0), (i1, _ti1, ni1), (i2, _ti2, ni2) = tri
            if ni0 < 0 or ni1 < 0 or ni2 < 0:
                continue
            fn = normals[ni0]
            if _dot(fn, view_to_cam) <= 0.02:
                continue
            p0s = (screen[i0][0], screen[i0][1])
            p1s = (screen[i1][0], screen[i1][1])
            p2s = (screen[i2][0], screen[i2][1])
            z0, z1, z2 = screen[i0][2], screen[i1][2], screen[i2][2]
            v0, v1, v2 = verts[i0], verts[i1], verts[i2]
            tris.append((p0s, p1s, p2s, v0, v1, v2, z0, z1, z2, fn))

    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    out_px = out.load()
    z_eps = 4e-4

    for y in range(th):
        for x in range(tw):
            px_, py_ = x + 0.5, y + 0.5
            best_z: Optional[float] = None
            best_pri: float = -1e9
            best_col: Optional[Tuple[int, int, int, int]] = None
            for p0s, p1s, p2s, v0, v1, v2, z0, z1, z2, fn in tris:
                w0 = edge(p1s[0], p1s[1], p2s[0], p2s[1], px_, py_)
                w1 = edge(p2s[0], p2s[1], p0s[0], p0s[1], px_, py_)
                w2 = edge(p0s[0], p0s[1], p1s[0], p1s[1], px_, py_)
                if w0 < 0 or w1 < 0 or w2 < 0:
                    continue
                area = edge(p0s[0], p0s[1], p1s[0], p1s[1], p2s[0], p2s[1])
                if abs(area) < 1e-9:
                    continue
                w0 /= area
                w1 /= area
                w2 /= area
                z = w0 * z0 + w1 * z1 + w2 * z2
                wp = (
                    w0 * v0[0] + w1 * v1[0] + w2 * v2[0],
                    w0 * v0[1] + w1 * v1[1] + w2 * v2[1],
                    w0 * v0[2] + w1 * v1[2] + w2 * v2[2],
                )
                tr, tg, tb, ta = triplanar_rgba(tex, wp, fn, UV_SCALE)
                pri = _dot(fn, view_to_cam)
                if best_z is None or z < best_z - z_eps:
                    best_z = z
                    best_pri = pri
                    best_col = flatten_for_icon(tr, tg, tb, ta)
                elif best_z is not None and abs(z - best_z) <= z_eps and pri > best_pri:
                    best_pri = pri
                    best_col = flatten_for_icon(tr, tg, tb, ta)
            if best_col is not None:
                out_px[x, y] = best_col
    return out


def main() -> None:
    tex_path = os.path.join(ROOT, "water_v2", "water_albedo.png")
    obj_path = os.path.join(ROOT, "water_v2", "water_full.obj")
    dirt_path = os.path.join(ROOT, "dirt", "dirt_sprite.png")
    out_path = os.path.join(ROOT, "water_v2", "water_sprite.png")

    tex = Image.open(tex_path).convert("RGBA")
    dirt = Image.open(dirt_path).convert("RGBA")
    rend = raster_water_triplanar(tex, dirt, obj_path)
    rim_r, rim_g, rim_b, rim_a = texture_edge_colors(tex)

    w, h = dirt.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()
    rpx = rend.load()

    for y in range(h):
        for x in range(w):
            d = dirt.getpixel((x, y))
            if len(d) < 4 or d[3] < 20:
                continue
            L = _lum(d)
            a = d[3]
            if L >= 198:
                out_px[x, y] = (rim_r, rim_g, rim_b, min(255, int(a * rim_a / 255)))
            else:
                out_px[x, y] = rpx[x, y]

    out.save(out_path, "PNG")
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
