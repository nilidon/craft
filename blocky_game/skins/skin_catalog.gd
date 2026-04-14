extends RefCounted
## Authoritative list of playable .vox skins. Add entries here when you drop new files under `skins/`.
## Load via `preload("res://blocky_game/skins/skin_catalog.gd")` (static methods).
## Optional 2D previews: `res://blocky_game/skinspreviews/<id>.png` (or .webp / .jpg), or same basename as the .vox file.

const _PREVIEW_DIR := "res://blocky_game/skinspreviews"

const _ENTRIES: Array[Dictionary] = [
	{"id": "char000", "label": "Alex", "vox_path": "res://blocky_game/skins/Char000.vox"},
	{"id": "char001", "label": "Mia", "vox_path": "res://blocky_game/skins/Char001.vox"},
	{"id": "char002", "label": "Linda", "vox_path": "res://blocky_game/skins/Char002.vox"},
	{"id": "char003", "label": "Ethan", "vox_path": "res://blocky_game/skins/Char003.vox"},
	{"id": "char004", "label": "Chloe", "vox_path": "res://blocky_game/skins/Char004.vox"},
	{"id": "char005", "label": "Marcus", "vox_path": "res://blocky_game/skins/Char005.vox"},
	{"id": "char006", "label": "Ben", "vox_path": "res://blocky_game/skins/Char006.vox"},
	{"id": "char007", "label": "Tyler", "vox_path": "res://blocky_game/skins/Char007.vox"},
	{"id": "char008", "label": "Joelie Rae", "vox_path": "res://blocky_game/skins/Char008.vox"},
]


static func entries() -> Array[Dictionary]:
	return _ENTRIES.duplicate()


static func default_vox_path() -> String:
	return _ENTRIES[0]["vox_path"]


## Coin cost to unlock a skin (`id` from `_ENTRIES`). Alex (`char000`) is free.
static func skin_unlock_coin_cost_for_id(skin_id: String) -> int:
	match skin_id:
		"char000":
			return 0
		"char001":
			return 200
		"char002":
			return 350
		"char003":
			return 500
		"char004":
			return 750
		"char005":
			return 1000
		"char006":
			return 1250
		"char007":
			return 1500
		"char008":
			return 2000
		_:
			return 999999


static func skin_id_for_vox_path(path: String) -> String:
	var p := path.strip_edges()
	for e in _ENTRIES:
		if e["vox_path"] == p:
			return str(e["id"])
	return "char000"


static func normalize_vox_path(path: String) -> String:
	var p := path.strip_edges()
	if p.is_empty():
		return default_vox_path()
	for e in _ENTRIES:
		if e["vox_path"] == p:
			return p
	return default_vox_path()


## First existing path under `skinspreviews/`, or "" if none (carousel shows empty preview area).
static func resolve_preview_path(entry: Dictionary) -> String:
	var id: String = str(entry.get("id", "")).strip_edges()
	if not id.is_empty():
		for ext: String in [".png", ".webp", ".jpg", ".jpeg"]:
			var p: String = _PREVIEW_DIR + "/" + id + ext
			if ResourceLoader.exists(p):
				return p
	var vox: String = str(entry.get("vox_path", "")).strip_edges()
	var stem: String = vox.get_file().get_basename()
	if stem.is_empty():
		return ""
	for ext: String in [".png", ".webp", ".jpg", ".jpeg"]:
		var p2: String = _PREVIEW_DIR + "/" + stem + ext
		if ResourceLoader.exists(p2):
			return p2
	return ""
