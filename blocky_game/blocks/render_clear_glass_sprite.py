"""
Rasterize glass_v2/glass.obj: each visible face maps the *entire* clear_glass/clear_glass.png
(UV 0..1 from world position on that face), not the mesh's baked atlas UVs.

Composite dirt_sprite rim/outline pixels for matching line weight.

Run: python blocky_game/blocks/render_clear_glass_sprite.py
"""
from __future__ import annotations

import math
import os
from typing import List, Optional, Tuple

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))

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
                    vti = int(inds[1]) - 1 if len(inds) > 1 and inds[1] else -1
                    vni = int(inds[2]) - 1 if len(inds) > 2 and inds[2] else -1
                    face.append((vi, vti, vni))
                faces.append(face)
    return verts, normals, faces


def world_full_texture_uv(p: Vec3, vn: Vec3) -> Vec2:
    """Map whole clear_glass.png (u,v in 0..1) onto this face from vertex position."""
    x, y, z = p[0], p[1], p[2]
    nx, ny, nz = vn[0], vn[1], vn[2]
    eps = 0.35
    if ny > eps:
        return (x, 1.0 - z)
    if ny < -eps:
        return (x, z)
    if nx > eps:
        return (1.0 - z, y)
    if nx < -eps:
        return (z, y)
    if nz > eps:
        return (x, y)
    if nz < -eps:
        return (1.0 - x, y)
    return (0.5, 0.5)


def triangulate(face: List[tuple[int, int, int]]) -> List[List[tuple[int, int, int]]]:
    return [[face[0], face[i], face[i + 1]] for i in range(1, len(face) - 1)]


def sample_tex(tex: Image.Image, u: float, v: float) -> tuple[int, int, int, int]:
    u = max(0.0, min(1.0, u))
    v = max(0.0, min(1.0, v))
    w, h = tex.size
    px = u * (w - 1)
    py = (1.0 - v) * (h - 1)
    x0, y0 = int(px), int(py)
    x1, y1 = min(x0 + 1, w - 1), min(y0 + 1, h - 1)
    fx, fy = px - x0, py - y0

    def g(x: int, y: int) -> tuple[int, int, int, int]:
        p = tex.getpixel((x, y))
        if len(p) == 4:
            return int(p[0]), int(p[1]), int(p[2]), int(p[3])
        return int(p[0]), int(p[1]), int(p[2]), 255

    c00, c10, c01, c11 = g(x0, y0), g(x1, y0), g(x0, y1), g(x1, y1)

    def lerp(a: float, b: float, t: float) -> float:
        return a + (b - a) * t

    r = int(lerp(lerp(c00[0], c10[0], fx), lerp(c01[0], c11[0], fx), fy))
    g_ = int(lerp(lerp(c00[1], c10[1], fx), lerp(c01[1], c11[1], fx), fy))
    b = int(lerp(lerp(c00[2], c10[2], fx), lerp(c01[2], c11[2], fx), fy))
    a = int(lerp(lerp(c00[3], c10[3], fx), lerp(c01[3], c11[3], fx), fy))
    return r, g_, b, a


def edge(ax: float, ay: float, bx: float, by: float, px: float, py: float) -> float:
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax)


# RGBA premultiplied onto this dark plate so low-alpha cyan edges read correctly (no multi-layer over()).
_ICON_BG = (52, 58, 64)


def flatten_tex_for_icon(r: int, g: int, b: int, a: int) -> tuple[int, int, int, int]:
    af = a / 255.0
    br, bg_, bb = _ICON_BG
    return (
        max(0, min(255, int(r * af + br * (1.0 - af)))),
        max(0, min(255, int(g * af + bg_ * (1.0 - af)))),
        max(0, min(255, int(b * af + bb * (1.0 - af)))),
        255,
    )


def raster_uv_glass(
    tex: Image.Image,
    dirt: Image.Image,
    obj_path: str,
) -> Image.Image:
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

    tris: List[Tuple[Vec2, Vec2, Vec2, Vec2, Vec2, Vec2, float, float, float]] = []
    for face in faces:
        for tri in triangulate(face):
            (i0, _ti0, ni0), (i1, _ti1, ni1), (i2, _ti2, ni2) = tri
            if ni0 < 0 or ni1 < 0 or ni2 < 0:
                continue
            fn = normals[ni0]
            if _dot(fn, view_to_cam) <= 0.02:
                continue
            p0 = (screen[i0][0], screen[i0][1])
            p1 = (screen[i1][0], screen[i1][1])
            p2 = (screen[i2][0], screen[i2][1])
            uv0 = world_full_texture_uv(verts[i0], normals[ni0])
            uv1 = world_full_texture_uv(verts[i1], normals[ni1])
            uv2 = world_full_texture_uv(verts[i2], normals[ni2])
            z0, z1, z2 = screen[i0][2], screen[i1][2], screen[i2][2]
            tris.append((p0, p1, p2, uv0, uv1, uv2, z0, z1, z2))

    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    out_px = out.load()

    for y in range(th):
        for x in range(tw):
            px_, py_ = x + 0.5, y + 0.5
            # One sample only: smallest screen-space z is the face closest to the camera (see forward = center - eye).
            best_z: Optional[float] = None
            best_col: Optional[Tuple[int, int, int, int]] = None
            for p0, p1, p2, uv0, uv1, uv2, z0, z1, z2 in tris:
                w0 = edge(p1[0], p1[1], p2[0], p2[1], px_, py_)
                w1 = edge(p2[0], p2[1], p0[0], p0[1], px_, py_)
                w2 = edge(p0[0], p0[1], p1[0], p1[1], px_, py_)
                if w0 < 0 or w1 < 0 or w2 < 0:
                    continue
                area = edge(p0[0], p0[1], p1[0], p1[1], p2[0], p2[1])
                if abs(area) < 1e-9:
                    continue
                w0 /= area
                w1 /= area
                w2 /= area
                u = w0 * uv0[0] + w1 * uv1[0] + w2 * uv2[0]
                v = w0 * uv0[1] + w1 * uv1[1] + w2 * uv2[1]
                z = w0 * z0 + w1 * z1 + w2 * z2
                col = sample_tex(tex, u, v)
                if col[3] < 2:
                    continue
                if best_z is None or z < best_z:
                    best_z = z
                    best_col = col
            if best_col is not None:
                out_px[x, y] = flatten_tex_for_icon(*best_col)
    return out


def texture_edge_colors(tex: Image.Image) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    """Rim (bright) and outline (dark) RGBA sampled from clear_glass.png edges."""
    w, h = tex.size
    rim_px: List[tuple[int, int, int, int]] = []
    dark_px: List[tuple[int, int, int, int]] = []
    for y in range(h):
        for x in range(w):
            p = tex.getpixel((x, y))
            if len(p) < 4 or p[3] < 30:
                continue
            on_edge = x <= 1 or y <= 1 or x >= w - 2 or y >= h - 2
            L = _lum(p)
            if on_edge and L > 160:
                rim_px.append((int(p[0]), int(p[1]), int(p[2]), int(p[3])))
            elif on_edge and L < 140:
                dark_px.append((int(p[0]), int(p[1]), int(p[2]), int(p[3])))
    if not rim_px:
        rim_px = [sample_tex(tex, 0.5, 0.08)]
    if not dark_px:
        dark_px = [sample_tex(tex, 0.02, 0.5)]
    ar = sum(p[0] for p in rim_px) // len(rim_px)
    ag = sum(p[1] for p in rim_px) // len(rim_px)
    ab = sum(p[2] for p in rim_px) // len(rim_px)
    aa = min(255, sum(p[3] for p in rim_px) // len(rim_px))
    dr = sum(p[0] for p in dark_px) // len(dark_px)
    dg = sum(p[1] for p in dark_px) // len(dark_px)
    db = sum(p[2] for p in dark_px) // len(dark_px)
    da = min(255, sum(p[3] for p in dark_px) // len(dark_px))
    return (ar, ag, ab, aa), (dr, dg, db, da)


def main() -> None:
    obj_path = os.path.join(ROOT, "glass_v2", "glass.obj")
    tex_path = os.path.join(ROOT, "clear_glass", "clear_glass.png")
    dirt_path = os.path.join(ROOT, "dirt", "dirt_sprite.png")
    out_path = os.path.join(ROOT, "glass_v2", "clear_glass_sprite.png")

    tex = Image.open(tex_path).convert("RGBA")
    dirt = Image.open(dirt_path).convert("RGBA")
    rend = raster_uv_glass(tex, dirt, obj_path)
    rim_rgba, out_rgba = texture_edge_colors(tex)

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
                rr, gg, bb, aa = rim_rgba
                out_px[x, y] = (rr, gg, bb, min(255, int(a * aa / 255)))
            elif L <= 86:
                rr, gg, bb, aa = out_rgba
                out_px[x, y] = (rr, gg, bb, min(255, a))
            else:
                rv = rpx[x, y]
                out_px[x, y] = rv

    out.save(out_path, "PNG")
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
