from pathlib import Path
from PIL import Image


def main() -> None:
    root = Path(__file__).resolve().parent
    template_path = root / "atlas_template.png"
    tiles_dir = root / "tiles_unique_cells"
    output_path = root / "terrain_brand_custom.png"

    atlas = Image.open(template_path).convert("RGBA")
    width, height = atlas.size
    grid = 16
    tile_size = width // grid

    for tile_path in sorted(tiles_dir.glob("tile_x*_y*.png")):
        stem = tile_path.stem
        # Expected: tile_x00_y00
        parts = stem.split("_")
        if len(parts) != 3:
            continue
        x = int(parts[1][1:])
        y = int(parts[2][1:])
        tile = Image.open(tile_path).convert("RGBA")
        if tile.size != (tile_size, tile_size):
            tile = tile.resize((tile_size, tile_size), Image.Resampling.NEAREST)
        atlas.paste(tile, (x * tile_size, y * tile_size))

    atlas.save(output_path)
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
