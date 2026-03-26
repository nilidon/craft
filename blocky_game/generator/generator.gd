#tool
extends VoxelGeneratorScript

const Structure = preload("./structure.gd")
const TreeGenerator = preload("./tree_generator.gd")
const VoxelLibraryResource = preload("../blocks/voxel_library.tres")

# TODO Don't hardcode, get by name from library somehow
const AIR = 0
const DIRT = 1
const GRASS = 2
const WATER_FULL = 14
const WATER_TOP = 13
const LOG = 4
const LEAVES = 25
const TALL_GRASS = 8
const DEAD_SHRUB = 26

const DIRT_DEPTH_UNDER_GRASS = 4
const TREE_ATTEMPTS_PER_CHUNK = 2
const TALL_GRASS_CHANCE = 0.04
const WORLD_SEED = 841927
const PLAINS_BASE_HEIGHT = 10
const HILL_HEIGHT = 12
const DETAIL_HEIGHT = 3
const TERRAIN_MIN_Y = PLAINS_BASE_HEIGHT - HILL_HEIGHT - DETAIL_HEIGHT
const TERRAIN_MAX_Y = PLAINS_BASE_HEIGHT + HILL_HEIGHT + DETAIL_HEIGHT

const _CHANNEL = VoxelBuffer.CHANNEL_TYPE

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


var _tree_structures := []

var _heightmap_min_y := TERRAIN_MIN_Y
var _heightmap_max_y := TERRAIN_MAX_Y
var _macro_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _trees_min_y := 0
var _trees_max_y := 0
var _stone_type := DIRT


func _init():
	# TODO Even this must be based on a seed, but I'm lazy
	var tree_generator = TreeGenerator.new()
	tree_generator.log_type = LOG
	tree_generator.leaves_type = LEAVES
	for i in 16:
		var s = tree_generator.generate()
		_tree_structures.append(s)

	var tallest_tree_height = 0
	for structure in _tree_structures:
		var h = int(structure.voxels.get_size().y)
		if tallest_tree_height < h:
			tallest_tree_height = h
	_trees_min_y = _heightmap_min_y
	_trees_max_y = _heightmap_max_y + tallest_tree_height

	_macro_noise.seed = WORLD_SEED
	_macro_noise.frequency = 1.0 / 320.0
	_macro_noise.fractal_octaves = 2
	_macro_noise.fractal_gain = 0.45
	_detail_noise.seed = WORLD_SEED + 1337
	_detail_noise.frequency = 1.0 / 96.0
	_detail_noise.fractal_octaves = 1

	var stone_type: int = VoxelLibraryResource.get_model_index_from_resource_name("stone")
	if stone_type >= 0:
		_stone_type = stone_type


func _get_used_channels_mask() -> int:
	return 1 << _CHANNEL


func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, _unused_lod: int):
	# TODO There is an issue doing this, need to investigate why because it should be supported
	# Saves from this demo used 8-bit, which is no longer the default
	# buffer.set_channel_depth(_CHANNEL, VoxelBuffer.DEPTH_8_BIT)
	# Assuming input is cubic in our use case (it doesn't have to be!)
	var block_size := int(buffer.get_size().x)
	var oy := origin_in_voxels.y
	# TODO This hardcodes a cubic block size of 16, find a non-ugly way...
	# Dividing is a false friend because of negative values
	var chunk_pos := Vector3i(
		origin_in_voxels.x >> 4,
		origin_in_voxels.y >> 4,
		origin_in_voxels.z >> 4)

	# Ground

	if origin_in_voxels.y > _heightmap_max_y:
		buffer.fill(AIR, _CHANNEL)

	elif origin_in_voxels.y + block_size < _heightmap_min_y:
		buffer.fill(DIRT, _CHANNEL)

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
				
				# Stone, dirt and grass layers
				if relative_height > block_size:
					var depth_from_surface := relative_height - block_size
					var base_type := DIRT
					if depth_from_surface > DIRT_DEPTH_UNDER_GRASS:
						base_type = _stone_type
					buffer.fill_area(base_type,
						Vector3i(x, 0, z), Vector3i(x + 1, block_size, z + 1), _CHANNEL)
				elif relative_height > 0:
					var top_local_y := relative_height - 1
					var dirt_start: int = maxi(0, top_local_y - DIRT_DEPTH_UNDER_GRASS)

					if dirt_start > 0:
						buffer.fill_area(_stone_type,
							Vector3i(x, 0, z), Vector3i(x + 1, dirt_start, z + 1), _CHANNEL)

					if top_local_y > dirt_start:
						buffer.fill_area(DIRT,
							Vector3i(x, dirt_start, z), Vector3i(x + 1, top_local_y, z + 1), _CHANNEL)

					var top_type := DIRT
					if height >= 0:
						top_type = GRASS
					buffer.set_voxel(top_type, x, top_local_y, z, _CHANNEL)

					if height >= 0 and relative_height < block_size and rng.randf() < TALL_GRASS_CHANCE:
						buffer.set_voxel(TALL_GRASS, x, relative_height, z, _CHANNEL)
				
				# Water
				if height < 0 and oy < 0:
					var start_relative_height := 0
					if relative_height > 0:
						start_relative_height = relative_height
					buffer.fill_area(WATER_FULL,
						Vector3i(x, start_relative_height, z),
						Vector3i(x + 1, block_size, z + 1), _CHANNEL)
					if oy + block_size == 0:
						# Surface block
						buffer.set_voxel(WATER_TOP, x, block_size - 1, z, _CHANNEL)
						
				gx += 1

			gz += 1

	# Trees

	if origin_in_voxels.y <= _trees_max_y and origin_in_voxels.y + block_size >= _trees_min_y:
		var voxel_tool := buffer.get_voxel_tool()
		var structure_instances := [] # Array of [Vector3i, Structure]
			
		_get_tree_instances_in_chunk(chunk_pos, origin_in_voxels, block_size, structure_instances)
	
		# Relative to current block
		var block_aabb := AABB(Vector3(), buffer.get_size() + Vector3i(1, 1, 1))

		for dir in _moore_dirs:
			var ncpos := chunk_pos + dir
			_get_tree_instances_in_chunk(ncpos, origin_in_voxels, block_size, structure_instances)

		for structure_instance in structure_instances:
			var pos: Vector3i = structure_instance[0]
			var structure: Structure = structure_instance[1]
			var lower_corner_pos := pos - structure.offset
			var aabb := AABB(lower_corner_pos, structure.voxels.get_size() + Vector3i(1, 1, 1))

			if aabb.intersects(block_aabb):
				voxel_tool.paste_masked(lower_corner_pos,
					structure.voxels, 1 << VoxelBuffer.CHANNEL_TYPE,
					# Masking
					VoxelBuffer.CHANNEL_TYPE, AIR)

	buffer.compress_uniform_channels()


func _get_tree_instances_in_chunk(
	cpos: Vector3i, offset: Vector3i, chunk_size: int, tree_instances: Array):
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(cpos)

	for i in TREE_ATTEMPTS_PER_CHUNK:
		var pos := Vector3i(rng.randi() % chunk_size, 0, rng.randi() % chunk_size)
		pos += cpos * chunk_size
		pos.y = _get_height_at(pos.x, pos.z)
		
		if pos.y > 0:
			pos -= offset
			var si := rng.randi() % len(_tree_structures)
			var structure: Structure = _tree_structures[si]
			tree_instances.append([pos, structure])


#static func get_chunk_seed(cpos: Vector3) -> int:
#	return cpos.x ^ (13 * int(cpos.y)) ^ (31 * int(cpos.z))


func _get_chunk_seed_2d(cpos: Vector3i) -> int:
	var x: int = int(cpos.x)
	var z: int = int(cpos.z)
	return WORLD_SEED ^ (x * 92837111) ^ (z * 689287499)


func _get_height_at(x: int, z: int) -> int:
	var macro: float = _macro_noise.get_noise_2d(x, z)
	var detail: float = _detail_noise.get_noise_2d(x, z)
	var h: int = int(PLAINS_BASE_HEIGHT + macro * HILL_HEIGHT + detail * DETAIL_HEIGHT)
	return clampi(h, _heightmap_min_y, _heightmap_max_y)
