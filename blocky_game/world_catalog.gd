extends RefCounted
## Registry: map_id → terrain generator resource (duplicate per terrain instance).

const MAP_GRASSLAND := "grassland"
const MAP_DESERT := "desert"
const MAP_TUNDRA := "tundra"
const MAP_HIGHLANDS := "highlands"
const MAP_FOREST := "forest"
const MAP_CITY := "city"

const _GENERATOR_GRASSLAND := preload("res://blocky_game/generator/world_generator.tres")
const _GENERATOR_DESERT := preload("res://blocky_game/generator/desert_world_generator.tres")
const _GENERATOR_TUNDRA := preload("res://blocky_game/generator/tundra_world_generator.tres")
const _GENERATOR_HIGHLANDS := preload("res://blocky_game/generator/highlands_world_generator.tres")
const _GENERATOR_FOREST := preload("res://blocky_game/generator/forest_world_generator.tres")
const _GENERATOR_CITY := preload("res://blocky_game/generator/city_world_generator.tres")


static func default_map_id() -> String:
	return MAP_GRASSLAND


## Labels and order for the create-world terrain picker (metadata = map_id string).
## `description` is the subtitle only (e.g. "Dense trees"); title uses `map_short_label`.
static func map_picker_entries() -> Array[Dictionary]:
	return [
		{"id": MAP_GRASSLAND, "description": "Rolling hills & open meadows"},
		{"id": MAP_DESERT, "description": "Dunes & cacti"},
		{"id": MAP_TUNDRA, "description": "Snow & permafrost"},
		{"id": MAP_HIGHLANDS, "description": "Rivers & snow-capped slate"},
		{"id": MAP_FOREST, "description": "Dense trees"},
		{"id": MAP_CITY, "description": "Grid streets & buildings"},
	]


static func duplicate_generator_for_map(map_id: String) -> VoxelGenerator:
	var src: VoxelGenerator = _GENERATOR_GRASSLAND
	match map_id:
		MAP_DESERT:
			src = _GENERATOR_DESERT
		MAP_TUNDRA:
			src = _GENERATOR_TUNDRA
		MAP_HIGHLANDS:
			src = _GENERATOR_HIGHLANDS
		MAP_FOREST:
			src = _GENERATOR_FOREST
		MAP_CITY:
			src = _GENERATOR_CITY
		_:
			src = _GENERATOR_GRASSLAND
	return src.duplicate() as VoxelGenerator


## Optional cover art: `res://blocky_game/worldpreview/<map_id>.png` (e.g. grassland.png).
static func map_preview_image_path(map_id: String) -> String:
	return "res://blocky_game/worldpreview/%s.png" % map_id


## Loads imported PNG previews reliably (`ResourceLoader` + disk fallback for editor quirks).
static func load_map_preview_texture(map_id: String) -> Texture2D:
	var path := map_preview_image_path(map_id)
	## Empty type hint: some builds treat "Texture2D" hint as exact class and skip CompressedTexture2D.
	var via_loader: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if via_loader is Texture2D:
		return via_loader as Texture2D
	var via_load: Variant = load(path)
	if via_load is Texture2D:
		return via_load as Texture2D
	if FileAccess.file_exists(path):
		var gp := ProjectSettings.globalize_path(path)
		var img: Image = Image.load_from_file(gp)
		if img != null and img.get_width() > 0 and img.get_height() > 0:
			return ImageTexture.create_from_image(img)
	return null


## Two colors for a diagonal gradient when no PNG exists (modern card look).
static func map_card_gradient_colors(map_id: String) -> PackedColorArray:
	match map_id:
		MAP_DESERT:
			return PackedColorArray([Color(0.96, 0.82, 0.48), Color(0.58, 0.38, 0.18)])
		MAP_TUNDRA:
			return PackedColorArray([Color(0.94, 0.96, 1.0), Color(0.42, 0.56, 0.72)])
		MAP_HIGHLANDS:
			return PackedColorArray([Color(0.45, 0.62, 0.48), Color(0.22, 0.30, 0.38)])
		MAP_FOREST:
			return PackedColorArray([Color(0.28, 0.48, 0.34), Color(0.06, 0.14, 0.09)])
		MAP_CITY:
			return PackedColorArray([Color(0.42, 0.44, 0.50), Color(0.14, 0.15, 0.18)])
		_:
			return PackedColorArray([Color(0.40, 0.74, 0.46), Color(0.16, 0.34, 0.22)])


static func map_short_label(map_id: String) -> String:
	match map_id:
		MAP_GRASSLAND:
			return "Grassland"
		MAP_DESERT:
			return "Desert"
		MAP_TUNDRA:
			return "Tundra"
		MAP_HIGHLANDS:
			return "Highlands"
		MAP_FOREST:
			return "Forest"
		MAP_CITY:
			return "City"
		_:
			return map_id.capitalize()


## Coin cost to unlock a terrain type for **new** worlds. Grassland stays free (starter).
static func map_unlock_coin_cost(map_id: String) -> int:
	match map_id:
		MAP_GRASSLAND:
			return 0
		MAP_DESERT:
			return 100
		MAP_TUNDRA:
			return 150
		MAP_HIGHLANDS:
			return 200
		MAP_FOREST:
			return 250
		MAP_CITY:
			return 300
		_:
			return 999999
