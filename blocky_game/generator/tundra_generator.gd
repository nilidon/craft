#tool
extends VoxelGeneratorScript
## Frozen plains: snow surface, grey permafrost below (no brown dirt stripes on cliffs).
## Scattered igloos on flat snow (see igloo_structure.gd).

const Structure = preload("./structure.gd")
const IglooStructure = preload("./igloo_structure.gd")
const VoxelLibraryResource = preload("../blocks/voxel_library.tres")

const AIR := 0
const DIRT := 1
const WATER_FULL := 14
const WATER_TOP := 13

const PACK_DEPTH := 5
const WORLD_SEED := 841927 ^ 0x7A4E02

## Gentler, open tundra (not the same rolling hills as grassland).
const PLAINS_BASE_HEIGHT := 12
const HILL_HEIGHT := 6
const DETAIL_HEIGHT := 2
const TERRAIN_MIN_Y := PLAINS_BASE_HEIGHT - HILL_HEIGHT - DETAIL_HEIGHT
const TERRAIN_MAX_Y := PLAINS_BASE_HEIGHT + HILL_HEIGHT + DETAIL_HEIGHT

const ROCK_DECO_CHANCE := 0.004
const IGLOO_CHUNK_CHANCE := 0.11

const _CHANNEL := VoxelBuffer.CHANNEL_TYPE

const _moore_dirs: Array[Vector3i] = [
	Vector3i(-1, 0, -1),
	Vector3i(0, 0, -1),
	Vector3i(1, 0, -1),
	Vector3i(-1, 0, 0),
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 1),
	Vector3i(0, 0, 1),
	Vector3i(1, 0, 1)
]

var _heightmap_min_y := TERRAIN_MIN_Y
var _heightmap_max_y := TERRAIN_MAX_Y
var _igloo_top_y := TERRAIN_MAX_Y + 8
var _macro_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _stone_type := DIRT
var _snow_type := DIRT
var _pack_type := DIRT
var _rock_type := AIR
var _igloo_structure: Structure


func _init() -> void:
	_macro_noise.seed = WORLD_SEED
	_macro_noise.frequency = 1.0 / 400.0
	_macro_noise.fractal_octaves = 2
	_macro_noise.fractal_gain = 0.36
	_detail_noise.seed = WORLD_SEED + 17031
	_detail_noise.frequency = 1.0 / 110.0
	_detail_noise.fractal_octaves = 1

	var stone_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("stone")
	if stone_idx >= 0:
		_stone_type = stone_idx
	var snow_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("white_block")
	if snow_idx >= 0:
		_snow_type = snow_idx
	var gravel_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("gravel")
	if gravel_idx >= 0:
		_pack_type = gravel_idx
	var rock_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("rock")
	if rock_idx >= 0:
		_rock_type = rock_idx

	if _snow_type != DIRT:
		_igloo_structure = IglooStructure.build(_snow_type)
	else:
		_igloo_structure = null


func _get_used_channels_mask() -> int:
	return 1 << _CHANNEL


func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, _unused_lod: int) -> void:
	var block_size := int(buffer.get_size().x)
	var oy := origin_in_voxels.y
	var chunk_pos := Vector3i(
		origin_in_voxels.x >> 4,
		origin_in_voxels.y >> 4,
		origin_in_voxels.z >> 4)

	if origin_in_voxels.y > _heightmap_max_y:
		buffer.fill(AIR, _CHANNEL)
	elif origin_in_voxels.y + block_size < _heightmap_min_y:
		buffer.fill(_pack_type, _CHANNEL)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = _get_chunk_seed_2d(chunk_pos)
		var gx: int
		var gz := origin_in_voxels.z

		for z in block_size:
			gx = origin_in_voxels.x
			for x in block_size:
				var height := _get_height_at(gx, gz)
				var relative_height := height - oy

				if relative_height > block_size:
					var depth_from_surface := relative_height - block_size
					var base_type := _pack_type
					if depth_from_surface > PACK_DEPTH:
						base_type = _stone_type
					buffer.fill_area(base_type,
						Vector3i(x, 0, z), Vector3i(x + 1, block_size, z + 1), _CHANNEL)
				elif relative_height > 0:
					var top_local_y := relative_height - 1
					var pack_start: int = maxi(0, top_local_y - PACK_DEPTH)

					if pack_start > 0:
						buffer.fill_area(_stone_type,
							Vector3i(x, 0, z), Vector3i(x + 1, pack_start, z + 1), _CHANNEL)

					if top_local_y > pack_start:
						buffer.fill_area(_pack_type,
							Vector3i(x, pack_start, z), Vector3i(x + 1, top_local_y, z + 1), _CHANNEL)

					var top_type := _pack_type
					if height >= 0:
						top_type = _snow_type
					buffer.set_voxel(top_type, x, top_local_y, z, _CHANNEL)

					if (
						height >= 0
						and relative_height < block_size
						and _rock_type != AIR
						and rng.randf() < ROCK_DECO_CHANCE
					):
						buffer.set_voxel(_rock_type, x, relative_height, z, _CHANNEL)

				if height < 0 and oy < 0:
					var start_relative_height := 0
					if relative_height > 0:
						start_relative_height = relative_height
					buffer.fill_area(WATER_FULL,
						Vector3i(x, start_relative_height, z),
						Vector3i(x + 1, block_size, z + 1), _CHANNEL)
					if oy + block_size == 0:
						buffer.set_voxel(WATER_TOP, x, block_size - 1, z, _CHANNEL)

				gx += 1
			gz += 1

		if (
			_igloo_structure != null
			and origin_in_voxels.y <= _igloo_top_y
			and origin_in_voxels.y + block_size >= _heightmap_min_y
		):
			var voxel_tool := buffer.get_voxel_tool()
			var instances: Array = []
			_collect_igloo_instances(chunk_pos, origin_in_voxels, block_size, instances)
			var block_aabb := AABB(Vector3(), buffer.get_size() + Vector3i(1, 1, 1))
			for dir in _moore_dirs:
				_collect_igloo_instances(chunk_pos + dir, origin_in_voxels, block_size, instances)
			for pair in instances:
				var pos: Vector3i = pair[0]
				var structure: Structure = pair[1]
				var lower_corner_pos := pos - structure.offset
				var aabb := AABB(lower_corner_pos, structure.voxels.get_size() + Vector3i(1, 1, 1))
				if aabb.intersects(block_aabb):
					voxel_tool.paste_masked(lower_corner_pos,
						structure.voxels, 1 << VoxelBuffer.CHANNEL_TYPE,
						VoxelBuffer.CHANNEL_TYPE, AIR)

	buffer.compress_uniform_channels()


func _get_chunk_seed_2d(cpos: Vector3i) -> int:
	var xi: int = int(cpos.x)
	var zi: int = int(cpos.z)
	return WORLD_SEED ^ (xi * 92837111) ^ (zi * 689287499)


func _collect_igloo_instances(
		cpos: Vector3i, origin_in_voxels: Vector3i, block_size: int, out_instances: Array) -> void:
	if _igloo_structure == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(cpos) ^ 0x16600
	if rng.randf() > IGLOO_CHUNK_CHANCE:
		return
	var lx := rng.randi() % maxi(1, block_size - 6)
	var lz := rng.randi() % maxi(1, block_size - 6)
	var wx := int(cpos.x) * block_size + lx
	var wz := int(cpos.z) * block_size + lz
	var h0 := _get_height_at(wx, wz)
	if h0 < 2:
		return
	var h1 := _get_height_at(wx + 3, wz)
	var h2 := _get_height_at(wx - 3, wz)
	var h3 := _get_height_at(wx, wz + 3)
	var h4 := _get_height_at(wx, wz - 3)
	var hmin := mini(mini(h0, h1), mini(h2, mini(h3, h4)))
	var hmax := maxi(maxi(h0, h1), maxi(h2, maxi(h3, h4)))
	if hmax - hmin > 1:
		return
	var pos := Vector3i(wx, h0, wz)
	pos -= origin_in_voxels
	out_instances.append([pos, _igloo_structure])


func _get_height_at(x: int, z: int) -> int:
	var macro: float = _macro_noise.get_noise_2d(x, z)
	var detail: float = _detail_noise.get_noise_2d(x, z)
	var h: int = int(PLAINS_BASE_HEIGHT + macro * HILL_HEIGHT + detail * DETAIL_HEIGHT)
	return clampi(h, _heightmap_min_y, _heightmap_max_y)
