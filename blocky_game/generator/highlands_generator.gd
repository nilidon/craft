#tool
extends VoxelGeneratorScript
## Ridged mountains: grass valleys, one slate rock color below snowline, snow caps.
## Shallow valley rivers; sparse trees on grass only (not rock, snow, or water).

const Structure = preload("./structure.gd")
const TreeGenerator = preload("./tree_generator.gd")
const VoxelLibraryResource = preload("../blocks/voxel_library.tres")

const AIR := 0
const DIRT := 1
const GRASS := 2
const WATER_FULL := 14
const WATER_TOP := 13
const LOG := 4
const LEAVES := 25

const WORLD_SEED := 841927 ^ 0xA1A2A3

const PLAINS_BASE_HEIGHT := 10
const RIDGE_AMPLITUDE := 24
const DETAIL_AMPLITUDE := 5
const TERRAIN_MIN_Y := -8
const TERRAIN_MAX_Y := 44

## World Y (surface top) at or above this → snow cap.
const SNOWLINE_Y := 26

## Above this ridged value → slate (same rock everywhere below snowline).
const RIDGE_ROCK := 0.05

## Rivers: only in valleys; shave a few blocks toward shallow water, clamp bed depth.
const RIVER_VALLEY_RIDGE_MAX := 0.2
const RIVER_PATH_SLOT := 0.2
const RIVER_SHAVE_BLOCKS := 5
const RIVER_BED_MIN_Y := -2

const BUSH_CHANCE := 0.018
const TREE_ATTEMPTS_PER_CHUNK := 3

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

var _tree_structures: Array = []
var _trees_min_y := 0
var _trees_max_y := 0

var _heightmap_min_y := TERRAIN_MIN_Y
var _heightmap_max_y := TERRAIN_MAX_Y
var _ridge_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _river_warp := FastNoiseLite.new()
var _bush_jitter := FastNoiseLite.new()

var _bedrock_type := DIRT
var _slate_type := DIRT
var _snow_type := DIRT
var _bush_type: int = -1


func _init() -> void:
	var tree_generator := TreeGenerator.new()
	tree_generator.log_type = LOG
	tree_generator.leaves_type = LEAVES
	for i in 16:
		_tree_structures.append(tree_generator.generate())

	var tallest_tree := 0
	for structure in _tree_structures:
		var th := int(structure.voxels.get_size().y)
		if tallest_tree < th:
			tallest_tree = th
	_trees_min_y = TERRAIN_MIN_Y
	_trees_max_y = TERRAIN_MAX_Y + tallest_tree

	_ridge_noise.seed = WORLD_SEED
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_octaves = 4
	_ridge_noise.fractal_gain = 0.48
	_ridge_noise.frequency = 1.0 / 360.0

	_detail_noise.seed = WORLD_SEED + 4441
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.fractal_octaves = 2
	_detail_noise.fractal_gain = 0.5
	_detail_noise.frequency = 1.0 / 70.0

	_river_warp.seed = WORLD_SEED + 90210
	_river_warp.frequency = 1.0 / 220.0
	_river_warp.fractal_octaves = 2

	_bush_jitter.seed = WORLD_SEED + 331
	_bush_jitter.frequency = 1.0 / 55.0

	var slate_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("slate")
	if slate_idx >= 0:
		_slate_type = slate_idx
		_bedrock_type = slate_idx
	var snow_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("white_block")
	if snow_idx >= 0:
		_snow_type = snow_idx
	var bush_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("bush")
	if bush_idx >= 0:
		_bush_type = bush_idx
	if _bedrock_type == DIRT:
		var stone_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("stone")
		if stone_idx >= 0:
			_bedrock_type = stone_idx


func _get_used_channels_mask() -> int:
	return 1 << _CHANNEL


func _surface_top(gx: int, gz: int, height: int, ridge: float) -> int:
	if height < 0:
		return DIRT
	if height >= SNOWLINE_Y:
		return _snow_type
	if ridge > RIDGE_ROCK:
		return _slate_type
	return GRASS


func _dirt_depth_for_top(top: int) -> int:
	if top == GRASS:
		return 4
	return 2


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
		buffer.fill(DIRT, _CHANNEL)
	else:
		var gx: int
		var gz := origin_in_voxels.z

		for z in block_size:
			gx = origin_in_voxels.x
			for x in block_size:
				var height := _get_height_at(gx, gz)
				var ridge: float = _ridge_noise.get_noise_2d(gx, gz)
				var relative_height := height - oy
				var top_type := _surface_top(gx, gz, height, ridge)
				var dirt_depth := _dirt_depth_for_top(top_type)

				if relative_height > block_size:
					var depth_from_surface := relative_height - block_size
					var base_type := DIRT
					if depth_from_surface > dirt_depth:
						base_type = _bedrock_type
					buffer.fill_area(base_type,
						Vector3i(x, 0, z), Vector3i(x + 1, block_size, z + 1), _CHANNEL)
				elif relative_height > 0:
					var top_local_y := relative_height - 1
					var dirt_start: int = maxi(0, top_local_y - dirt_depth)

					if dirt_start > 0:
						buffer.fill_area(_bedrock_type,
							Vector3i(x, 0, z), Vector3i(x + 1, dirt_start, z + 1), _CHANNEL)

					if top_local_y > dirt_start:
						buffer.fill_area(DIRT,
							Vector3i(x, dirt_start, z), Vector3i(x + 1, top_local_y, z + 1), _CHANNEL)

					buffer.set_voxel(top_type, x, top_local_y, z, _CHANNEL)

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

		_place_valley_bushes(buffer, origin_in_voxels, block_size, chunk_pos)

		if origin_in_voxels.y <= _trees_max_y and origin_in_voxels.y + block_size >= _trees_min_y:
			var voxel_tool := buffer.get_voxel_tool()
			var structure_instances: Array = []
			_get_tree_instances_in_chunk(chunk_pos, origin_in_voxels, block_size, structure_instances)
			var block_aabb := AABB(Vector3(), buffer.get_size() + Vector3i(1, 1, 1))
			for dir in _moore_dirs:
				_get_tree_instances_in_chunk(chunk_pos + dir, origin_in_voxels, block_size, structure_instances)
			for structure_instance in structure_instances:
				var pos: Vector3i = structure_instance[0]
				var structure: Structure = structure_instance[1]
				var lower_corner_pos := pos - structure.offset
				var aabb := AABB(lower_corner_pos, structure.voxels.get_size() + Vector3i(1, 1, 1))
				if aabb.intersects(block_aabb):
					voxel_tool.paste_masked(lower_corner_pos,
						structure.voxels, 1 << VoxelBuffer.CHANNEL_TYPE,
						VoxelBuffer.CHANNEL_TYPE, AIR)

	buffer.compress_uniform_channels()


func _place_valley_bushes(
		buffer: VoxelBuffer, origin_in_voxels: Vector3i, block_size: int, chunk_pos: Vector3i) -> void:
	if _bush_type < 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(chunk_pos) ^ 0xB005
	var oy := origin_in_voxels.y
	for z in block_size:
		for x in block_size:
			if rng.randf() > BUSH_CHANCE:
				continue
			var gx := origin_in_voxels.x + x
			var gz := origin_in_voxels.z + z
			var height := _get_height_at(gx, gz)
			if height < 2 or height > 18:
				continue
			var ridge: float = _ridge_noise.get_noise_2d(gx, gz)
			if ridge > 0.1:
				continue
			var top := _surface_top(gx, gz, height, ridge)
			if top != GRASS:
				continue
			var dj := _bush_jitter.get_noise_2d(gx, gz)
			if dj < 0.15:
				continue
			var rel := height - oy
			if rel < 0 or rel >= block_size:
				continue
			var top_local := rel - 1
			if top_local < 0 or top_local >= block_size:
				continue
			if buffer.get_voxel(x, top_local, z, _CHANNEL) != GRASS:
				continue
			if buffer.get_voxel(x, rel, z, _CHANNEL) != AIR:
				continue
			buffer.set_voxel(_bush_type, x, rel, z, _CHANNEL)


func _chunk_seed(cpos: Vector3i) -> int:
	var xi: int = int(cpos.x)
	var zi: int = int(cpos.z)
	return WORLD_SEED ^ (xi * 92837111) ^ (zi * 689287499)


func _get_tree_instances_in_chunk(
		cpos: Vector3i, offset: Vector3i, chunk_size: int, tree_instances: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cpos) ^ 0x7E4E5
	for i in TREE_ATTEMPTS_PER_CHUNK:
		var pos := Vector3i(rng.randi() % chunk_size, 0, rng.randi() % chunk_size)
		pos += cpos * chunk_size
		pos.y = _get_height_at(pos.x, pos.z)
		if pos.y <= 0:
			continue
		var ridge: float = _ridge_noise.get_noise_2d(pos.x, pos.z)
		if _surface_top(pos.x, pos.z, pos.y, ridge) != GRASS:
			continue
		if pos.y >= SNOWLINE_Y - 1:
			continue
		pos -= offset
		var si := rng.randi() % len(_tree_structures)
		var structure: Structure = _tree_structures[si]
		tree_instances.append([pos, structure])


func _get_height_at(x: int, z: int) -> int:
	var ridge: float = _ridge_noise.get_noise_2d(x, z)
	var detail: float = _detail_noise.get_noise_2d(x, z)
	var h: int = int(PLAINS_BASE_HEIGHT + ridge * RIDGE_AMPLITUDE + detail * DETAIL_AMPLITUDE)
	h = clampi(h, TERRAIN_MIN_Y, TERRAIN_MAX_Y)

	if ridge < RIVER_VALLEY_RIDGE_MAX:
		var w := _river_warp.get_noise_2d(x, z) * 15.0
		var path: float = sin(float(x) * 0.042 + w) * cos(float(z) * 0.036 - w * 0.55)
		if abs(path) < RIVER_PATH_SLOT:
			var base := h
			h = maxi(base - RIVER_SHAVE_BLOCKS, RIVER_BED_MIN_Y)
			h = mini(h, base)

	return clampi(h, TERRAIN_MIN_Y, TERRAIN_MAX_Y)
