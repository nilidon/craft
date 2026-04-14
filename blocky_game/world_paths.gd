extends RefCounted
## Shared paths and helpers for VoxelStreamRegionFiles saves under user://.

const WORLDS_ROOT := "user://voxel_worlds"
const DEFAULT_SLUG := "World_1"
const SLUG_PATTERN := "^[a-zA-Z0-9][a-zA-Z0-9_-]{0,31}$"


static func directory_for_slug(slug: String) -> String:
	return "%s/%s" % [WORLDS_ROOT, slug]


static func is_valid_slug(slug: String) -> bool:
	if slug.is_empty():
		return false
	var rx := RegEx.new()
	if rx.compile(SLUG_PATTERN) != OK:
		return false
	return rx.search(slug) != null


static func ensure_world_directory(slug: String) -> Error:
	var path := directory_for_slug(slug)
	return DirAccess.make_dir_recursive_absolute(path)


static func list_world_slugs() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(WORLDS_ROOT):
		return out
	var d := DirAccess.open(WORLDS_ROOT)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not d.current_is_dir() or name.begins_with("."):
			name = d.get_next()
			continue
		if is_valid_slug(name):
			out.append(name)
		name = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


## Next unused `World_<n>` folder name (World_1, World_2, …).
static func suggest_new_world_slug() -> String:
	var taken := {}
	for s in list_world_slugs():
		taken[s] = true
	var n := 1
	while n < 100000:
		var w := "World_%d" % n
		if not taken.has(w):
			return w
		n += 1
	return "World_%d" % Time.get_ticks_msec()


static func delete_world(slug: String) -> Error:
	if not is_valid_slug(slug):
		return ERR_INVALID_PARAMETER
	var path := directory_for_slug(slug)
	if not DirAccess.dir_exists_absolute(path):
		return ERR_DOES_NOT_EXIST
	return _delete_dir_recursive(path)


static func _delete_dir_recursive(dir_path: String) -> Error:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ERR_CANT_OPEN
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if n == "." or n == "..":
			n = dir.get_next()
			continue
		var sub := dir_path.path_join(n)
		if dir.current_is_dir():
			var e := _delete_dir_recursive(sub)
			if e != OK:
				dir.list_dir_end()
				return e
		else:
			var fe := DirAccess.remove_absolute(sub)
			if fe != OK:
				dir.list_dir_end()
				return fe
		n = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(dir_path)


static func apply_stream_to_terrain(terrain: VoxelTerrain, slug: String) -> Error:
	if not is_valid_slug(slug):
		return ERR_INVALID_PARAMETER
	var err := ensure_world_directory(slug)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var stream := VoxelStreamRegionFiles.new()
	stream.directory = directory_for_slug(slug)
	terrain.stream = stream
	return OK
