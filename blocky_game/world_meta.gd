extends RefCounted
## Per-save folder metadata (map type, etc.). Lives next to region files.

const WorldPaths = preload("./world_paths.gd")
const WorldCatalog = preload("./world_catalog.gd")
const PlayerProgress = preload("res://blocky_game/progression/player_progress.gd")

const SECTION := "world"
const KEY_MAP := "map_id"
const KEY_FORMAT := "format"
const FORMAT_VERSION := 1


static func _path(slug: String) -> String:
	return "%s/world_meta.cfg" % WorldPaths.directory_for_slug(slug)


static func write(slug: String, map_id: String) -> Error:
	var err := WorldPaths.ensure_world_directory(slug)
	if err != OK:
		return err
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_MAP, PlayerProgress.clamp_map_id_for_unlocks(map_id))
	cfg.set_value(SECTION, KEY_FORMAT, FORMAT_VERSION)
	return cfg.save(_path(slug))


static func read_map_id(slug: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(_path(slug)) != OK:
		return WorldCatalog.MAP_GRASSLAND
	return str(cfg.get_value(SECTION, KEY_MAP, WorldCatalog.MAP_GRASSLAND))
