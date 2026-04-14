"""
Build blocky_game/skins/palettes/<Stem>_rgba.bin (1024 bytes each).

- If a .vox contains an RGBA chunk, that palette is written for that stem.
- Otherwise MagicaVoxel's official default palette is used (replace the .bin later for custom colors).

Run from repo root or this directory:
  python build_skin_palette_bins.py
"""
from __future__ import annotations

import pathlib
import struct

import magica_default_palette_rgba as md


def _parse_vox_rgba(data: bytes) -> bytes | None:
    if len(data) < 20 or data[:4] != b"VOX ":
        return None
    return _find_rgba_in_region(data, 8, len(data))


def _find_rgba_in_region(data: bytes, start: int, end: int) -> bytes | None:
    i = start
    while i + 12 <= end:
        cs = struct.unpack_from("<I", data, i + 4)[0]
        cn = struct.unpack_from("<I", data, i + 8)[0]
        content_i = i + 12
        after_content = content_i + cs
        after_children = after_content + cn
        if after_children > len(data):
            return None
        if data[i : i + 4] == b"RGBA" and cs >= 1024:
            return bytes(data[content_i : content_i + 1024])
        if cn > 0:
            found = _find_rgba_in_region(data, after_content, after_children)
            if found is not None:
                return found
        i = after_children
    return None


def main() -> None:
    here = pathlib.Path(__file__).resolve().parent
    skins = here.parent
    default_pal = md.build_default_bytes()
    assert len(default_pal) == 1024

    for vox in sorted(skins.glob("Char*.vox")):
        stem = vox.stem
        raw = vox.read_bytes()
        rgba = _parse_vox_rgba(raw)
        if rgba is None:
            rgba = default_pal
            note = "default palette"
        else:
            note = "from RGBA chunk"
        out = here / f"{stem}_rgba.bin"
        out.write_bytes(rgba)
        print(f"{out.name}: {note} ({len(rgba)} bytes)")


if __name__ == "__main__":
    main()
