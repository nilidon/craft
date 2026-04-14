#tool
extends VoxelGeneratorScript

const VoxelLibraryResource = preload("../blocks/voxel_library.tres")

const AIR := 0
const WATER_FULL := 14
const WATER_TOP := 13

const WORLD_SEED := 841927 ^ 0xDE5E7

## Rolling dunes: large ridged waves + smaller ripples on the sand.
const DUNE_BASE_HEIGHT := 11
const DUNE_RIDGE_AMPLITUDE := 17
const DUNE_RIPPLE_AMPLITUDE := 3
const DUNE_MIN_Y := 1
const DUNE_MAX_Y := 38

const CACTUS_CHANCE := 0.007
const CACTUS_MIN_HEIGHT := 2
const CACTUS_HEIGHT_SPREAD := 4

## Natural rock props on the sand (large rarer than small).
const NAT_ROCK_LARGE_CHANCE := 0.0022
const NAT_ROCK_SMALL_CHANCE := 0.0055

## Very sparse dry brush — keep desert reads as open sand.
const DEAD_SHRUB_CHANCE := 0.0055

const _CHANNEL := VoxelBuffer.CHANNEL_TYPE

var _heightmap_min_y := DUNE_MIN_Y
var _heightmap_max_y := DUNE_MAX_Y
var _dune_noise := FastNoiseLite.new()
var _ripple_noise := FastNoiseLite.new()
var _sand_type := AIR
var _cactus_type := AIR
var _nat_rock_small_type := AIR
var _nat_rock_large_type := AIR
var _dead_shrub_type := AIR


func _init() -> void:
	_dune_noise.seed = WORLD_SEED
	_dune_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_dune_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_dune_noise.fractal_octaves = 4
	_dune_noise.fractal_gain = 0.52
	_dune_noise.frequency = 1.0 / 400.0

	_ripple_noise.seed = WORLD_SEED + 919
	_ripple_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ripple_noise.fractal_octaves = 2
	_ripple_noise.fractal_gain = 0.5
	_ripple_noise.frequency = 1.0 / 90.0

	var sand_idx: int = VoxelLibraryResource.get_model_index_from_resource_name("sandstone")
	if sand_idx >= 0:
		_sand_type = sand_idx
	var cac: int = VoxelLibraryResource.get_model_index_from_resource_name("cactus")
	if cac >= 0:
		_cactus_type = cac
	else:
		var leaves: int = VoxelLibraryResource.get_model_index_from_resource_name("leaves")
		if leaves >= 0:
			_cactus_type = leaves
		else:
			_cactus_type = AIR
	var nrs: int = VoxelLibraryResource.get_model_index_from_resource_name("nat_rock_small")
	if nrs >= 0:
		_nat_rock_small_type = nrs
	var nrl: int = VoxelLibraryResource.get_model_index_from_resource_name("nat_rock_large")
	if nrl >= 0:
		_nat_rock_large_type = nrl
	var shrub: int = VoxelLibraryResource.get_model_index_from_resource_name("dead_shrub")
	if shrub >= 0:
		_dead_shrub_type = shrub


func _get_used_channels_mask() -> int:
	return 1 << _CHANNEL


func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, _unused_lod: int) -> void:
	if _sand_type == AIR:
		push_error("desert_generator: sandstone block missing from voxel library")
		return
	var block_size := int(buffer.get_size().x)
	var oy := origin_in_voxels.y
	var chunk_pos := Vector3i(
		origin_in_voxels.x >> 4,
		origin_in_voxels.y >> 4,
		origin_in_voxels.z >> 4)

	if origin_in_voxels.y > _heightmap_max_y:
		buffer.fill(AIR, _CHANNEL)
	elif origin_in_voxels.y + block_size < _heightmap_min_y:
		buffer.fill(_sand_type, _CHANNEL)
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
					buffer.fill_area(_sand_type,
						Vector3i(x, 0, z), Vector3i(x + 1, block_size, z + 1), _CHANNEL)
				elif relative_height > 0:
					buffer.fill_area(_sand_type,
						Vector3i(x, 0, z), Vector3i(x + 1, relative_height, z + 1), _CHANNEL)

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

		_place_cacti(buffer, origin_in_voxels, block_size, chunk_pos)
		_place_nat_rocks(buffer, origin_in_voxels, block_size, chunk_pos)
		_place_dead_shrubs(buffer, origin_in_voxels, block_size, chunk_pos)

	buffer.compress_uniform_channels()


func _place_cacti(
		buffer: VoxelBuffer, origin_in_voxels: Vector3i, block_size: int, chunk_pos: Vector3i) -> void:
	if _cactus_type == AIR:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(chunk_pos) ^ 0xCA9E5
	var oy := origin_in_voxels.y
	for z in block_size:
		for x in block_size:
			if rng.randf() > CACTUS_CHANCE:
				continue
			var gx := origin_in_voxels.x + x
			var gz := origin_in_voxels.z + z
			var height := _get_height_at(gx, gz)
			if height <= 0:
				continue
			var rel := height - oy
			var top_local := rel - 1
			if top_local < 0 or top_local >= block_size:
				continue
			if buffer.get_voxel(x, top_local, z, _CHANNEL) != _sand_type:
				continue
			var col_h := CACTUS_MIN_HEIGHT + rng.randi() % CACTUS_HEIGHT_SPREAD
			for i in col_h:
				var ly := rel + i
				if ly < 0 or ly >= block_size:
					break
				if buffer.get_voxel(x, ly, z, _CHANNEL) != AIR:
					break
				buffer.set_voxel(_cactus_type, x, ly, z, _CHANNEL)


func _place_nat_rocks(
		buffer: VoxelBuffer, origin_in_voxels: Vector3i, block_size: int, chunk_pos: Vector3i) -> void:
	if _nat_rock_small_type == AIR and _nat_rock_large_type == AIR:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(chunk_pos) ^ 0x20C2
	var oy := origin_in_voxels.y
	for z in block_size:
		for x in block_size:
			var gx := origin_in_voxels.x + x
			var gz := origin_in_voxels.z + z
			var height := _get_height_at(gx, gz)
			if height <= 0:
				continue
			var rel := height - oy
			if rel < 0 or rel >= block_size:
				continue
			var top_local := rel - 1
			if top_local < 0 or top_local >= block_size:
				continue
			if buffer.get_voxel(x, top_local, z, _CHANNEL) != _sand_type:
				continue
			if buffer.get_voxel(x, rel, z, _CHANNEL) != AIR:
				continue
			if _nat_rock_large_type != AIR and rng.randf() < NAT_ROCK_LARGE_CHANCE:
				buffer.set_voxel(_nat_rock_large_type, x, rel, z, _CHANNEL)
				continue
			if _nat_rock_small_type != AIR and rng.randf() < NAT_ROCK_SMALL_CHANCE:
				buffer.set_voxel(_nat_rock_small_type, x, rel, z, _CHANNEL)


func _place_dead_shrubs(
		buffer: VoxelBuffer, origin_in_voxels: Vector3i, block_size: int, chunk_pos: Vector3i) -> void:
	if _dead_shrub_type == AIR:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(chunk_pos) ^ 0x5EED5EED
	var oy := origin_in_voxels.y
	for z in block_size:
		for x in block_size:
			if rng.randf() > DEAD_SHRUB_CHANCE:
				continue
			var gx := origin_in_voxels.x + x
			var gz := origin_in_voxels.z + z
			var height := _get_height_at(gx, gz)
			if height <= 0:
				continue
			var rel := height - oy
			if rel < 0 or rel >= block_size:
				continue
			var top_local := rel - 1
			if top_local < 0 or top_local >= block_size:
				continue
			if buffer.get_voxel(x, top_local, z, _CHANNEL) != _sand_type:
				continue
			if buffer.get_voxel(x, rel, z, _CHANNEL) != AIR:
				continue
			buffer.set_voxel(_dead_shrub_type, x, rel, z, _CHANNEL)


func _get_chunk_seed_2d(cpos: Vector3i) -> int:
	var xi: int = int(cpos.x)
	var zi: int = int(cpos.z)
	return WORLD_SEED ^ (xi * 92837111) ^ (zi * 689287499)


func _get_height_at(x: int, z: int) -> int:
	var ridge: float = _dune_noise.get_noise_2d(x, z)
	var ripple: float = _ripple_noise.get_noise_2d(x, z)
	var h: int = int(
		DUNE_BASE_HEIGHT
		+ ridge * DUNE_RIDGE_AMPLITUDE
		+ ripple * DUNE_RIPPLE_AMPLITUDE)
	return clampi(h, DUNE_MIN_Y, DUNE_MAX_Y)
