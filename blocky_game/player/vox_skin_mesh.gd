extends RefCounted
## Builds an ArrayMesh from a MagicaVoxel .vox (SIZE + XYZI; RGBA optional). Used when editor import yields an empty mesh.
## If `res://.../skins/palettes/<VoxStem>_rgba.bin` exists (1024 bytes), it overrides the RGBA chunk inside the .vox for vertex colors.
## Voxel positions match godot_voxel `magica_to_opengl`: MagicaVoxel (x,y,z) → engine (y,z,x).

static var _cached_default_palette: PackedByteArray = PackedByteArray()


static func _magica_xyz_to_engine(p: Vector3i) -> Vector3i:
	return Vector3i(p.y, p.z, p.x)


static func _chunk_is(bytes: PackedByteArray, i: int, a: int, b: int, c: int, d: int) -> bool:
	return bytes[i] == a and bytes[i + 1] == b and bytes[i + 2] == c and bytes[i + 3] == d


static func build_mesh_from_file(path: String, voxel_scale: float = 0.0625) -> ArrayMesh:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return build_mesh_from_bytes(bytes, voxel_scale, path)


static func build_mesh_from_bytes(bytes: PackedByteArray, voxel_scale: float, vox_res_path: String = "") -> ArrayMesh:
	if bytes.size() < 20:
		return null
	if bytes[0] != 86 or bytes[1] != 79 or bytes[2] != 88 or bytes[3] != 32:
		return null
	var data: Dictionary = {}
	_parse_region(bytes, 8, bytes.size(), data)
	var voxels: Array = data.get("voxels", [])
	if voxels.is_empty():
		return null
	var embedded: PackedByteArray = data.get("palette", PackedByteArray())
	var pal: PackedByteArray = _resolve_palette_for_vox(vox_res_path, embedded)
	if pal.size() < 1024:
		pal.resize(1024)
	var occ: Dictionary = {}
	for v in voxels:
		if not v is Array:
			continue
		var a := v as Array
		if a.size() < 4:
			continue
		var p := _magica_xyz_to_engine(Vector3i(int(a[0]), int(a[1]), int(a[2])))
		occ[p] = int(a[3])
	var dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pk in occ:
		var p: Vector3i = pk as Vector3i
		var ci: int = int(occ[pk])
		var col := _palette_color(pal, ci)
		for d: Vector3i in dirs:
			var np: Vector3i = p + d
			if occ.has(np):
				continue
			_add_face(st, p, d, col, voxel_scale)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	return mesh


static func _parse_region(bytes: PackedByteArray, start: int, end: int, data: Dictionary) -> void:
	var i := start
	while i + 12 <= end:
		var cs: int = bytes.decode_u32(i + 4)
		var cn: int = bytes.decode_u32(i + 8)
		var content_i := i + 12
		var after_content := content_i + cs
		var after_children := after_content + cn
		if after_children > bytes.size():
			return
		if _chunk_is(bytes, i, 88, 89, 90, 73) and cs >= 4:
			var n: int = bytes.decode_u32(content_i)
			var need := 4 + n * 4
			if need > cs:
				n = maxi((cs - 4) / 4, 0)
			var arr: Array = data.get("voxels", [])
			var read_i := content_i + 4
			for _j in n:
				if read_i + 4 > content_i + cs:
					break
				var x := int(bytes[read_i])
				var y := int(bytes[read_i + 1])
				var z := int(bytes[read_i + 2])
				var c := int(bytes[read_i + 3])
				read_i += 4
				arr.append([x, y, z, c])
			data["voxels"] = arr
		elif _chunk_is(bytes, i, 82, 71, 66, 65) and cs >= 1024:
			data["palette"] = bytes.slice(content_i, content_i + 1024)
		if cn > 0:
			_parse_region(bytes, after_content, after_children, data)
		i = after_children


static func _read_res_file(path: String) -> PackedByteArray:
	var f2 := FileAccess.open(path, FileAccess.READ)
	if f2 == null:
		return PackedByteArray()
	var buf := f2.get_buffer(f2.get_length())
	f2.close()
	return buf


static func _sidecar_palette_path(vox_res_path: String) -> String:
	if not vox_res_path.begins_with("res://"):
		return ""
	var stem: String = vox_res_path.get_basename().get_file()
	var dir: String = vox_res_path.get_base_dir()
	return dir.path_join("palettes").path_join(stem + "_rgba.bin")


static func _resolve_palette_for_vox(vox_res_path: String, embedded_rgba: PackedByteArray) -> PackedByteArray:
	if not vox_res_path.is_empty():
		var side := _sidecar_palette_path(vox_res_path)
		if not side.is_empty():
			var from_side := _read_res_file(side)
			if from_side.size() >= 1024:
				return from_side.slice(0, 1024)
	if embedded_rgba.size() >= 1024:
		return embedded_rgba.slice(0, 1024)
	if _cached_default_palette.size() >= 1024:
		return _cached_default_palette
	var def_path := "res://blocky_game/skins/palettes/MagicaVoxel_default_rgba.bin"
	_cached_default_palette = _read_res_file(def_path)
	if _cached_default_palette.size() >= 1024:
		return _cached_default_palette.slice(0, 1024)
	return PackedByteArray()


static func _palette_color(pal: PackedByteArray, idx: int) -> Color:
	# MagicaVoxel XYZI color is 1-based (1–255); RGBA chunk is 256 entries in order (slot 0 = color 1).
	var slot: int = idx - 1
	if slot < 0 or slot > 255:
		return Color(1, 0, 1, 1)
	var b := slot * 4
	if b + 3 >= pal.size():
		return Color(1, 0, 1, 1)
	return Color(
		pal[b] / 255.0,
		pal[b + 1] / 255.0,
		pal[b + 2] / 255.0,
		pal[b + 3] / 255.0)


static func _add_face(st: SurfaceTool, p: Vector3i, dir: Vector3i, col: Color, s: float) -> void:
	var o := Vector3(p) * s
	var n := Vector3(dir)
	var base: Vector3
	var a: Vector3
	var b: Vector3
	if dir.x > 0:
		base = o + Vector3(s, 0, 0)
		a = Vector3(0, s, 0)
		b = Vector3(0, 0, s)
	elif dir.x < 0:
		base = o
		a = Vector3(0, 0, s)
		b = Vector3(0, s, 0)
	elif dir.y > 0:
		base = o + Vector3(0, s, 0)
		a = Vector3(s, 0, 0)
		b = Vector3(0, 0, s)
	elif dir.y < 0:
		base = o
		a = Vector3(0, 0, s)
		b = Vector3(s, 0, 0)
	elif dir.z > 0:
		base = o + Vector3(0, 0, s)
		a = Vector3(0, s, 0)
		b = Vector3(s, 0, 0)
	else:
		base = o
		a = Vector3(s, 0, 0)
		b = Vector3(0, s, 0)
	var c0 := base
	var c1 := base + a
	var c2 := base + a + b
	var c3 := base + b
	if dir.x < 0 or dir.y < 0 or dir.z < 0:
		_quad(st, c0, c3, c2, c1, col, n)
	else:
		_quad(st, c0, c1, c2, c3, col, n)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
