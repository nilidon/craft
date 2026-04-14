# Implements random cellular automata behavior of the terrain,
# such as growth of grass and crops, fire etc.

extends Node

const VoxelLibraryResource = preload("./blocks/voxel_library.tres")

# Takes effect in a large radius around the player
const RADIUS = 100
# How many voxels are affected per frame
const VOXELS_PER_FRAME = 512
# Keep block placements stable in sandbox mode.
# When false, nearby player movement no longer causes dirt/grass auto-conversions.
const ENABLE_GRASS_RANDOM_TICKS = false

@onready var _terrain : VoxelTerrain = get_node("../VoxelTerrain")
@onready var _voxel_tool : VoxelToolTerrain = _terrain.get_voxel_tool()
@onready var _players_container : Node = get_node("../Players")
@onready var _game: BlockyVoxelGame = get_node("..") as BlockyVoxelGame

var _grass_dirs: Array[Vector3i] = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
	Vector3(-1, 0, -1),
	Vector3(1, 0, -1),
	Vector3(-1, 0, 1),
	Vector3(1, 0, 1),
	
	Vector3(-1, 1, 0),
	Vector3(1, 1, 0),
	Vector3(0, 1, -1),
	Vector3(0, 1, 1),
	Vector3(-1, 1, -1),
	Vector3(1, 1, -1),
	Vector3(-1, 1, 1),
	Vector3(1, 1, 1),

	Vector3(-1, -1, 0),
	Vector3(1, -1, 0),
	Vector3(0, -1, -1),
	Vector3(0, -1, 1),
	Vector3(-1, -1, -1),
	Vector3(1, -1, -1),
	Vector3(-1, -1, 1),
	Vector3(1, -1, 1)
]

var _tall_grass_type : int


func _ready():
	_tall_grass_type = VoxelLibraryResource.get_model_index_from_resource_name("tall_grass")
	_voxel_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)


func _merge_overlapping_player_regions(boxes: Array[AABB]) -> Array[AABB]:
	var out: Array[AABB] = boxes.duplicate()
	var changed := true
	while changed:
		changed = false
		var i := 0
		while i < out.size():
			var j := i + 1
			while j < out.size():
				if out[i].intersects(out[j]) or out[i].encloses(out[j]) or out[j].encloses(out[i]):
					out[i] = out[i].merge(out[j])
					out.remove_at(j)
					changed = true
				else:
					j += 1
			i += 1
	return out


func _process(_unused_delta: float) -> void:
	if not ENABLE_GRASS_RANDOM_TICKS:
		return

	_grass_dirs.shuffle()

	var regions: Array[AABB] = []
	var r := RADIUS
	for i in _players_container.get_child_count():
		var character: Node3D = _players_container.get_child(i) as Node3D
		if character == null:
			continue
		var center: Vector3 = character.position.floor()
		regions.append(AABB(center - Vector3(r, r, r), 2 * Vector3(r, r, r)))

	if regions.is_empty():
		return

	var merged := _merge_overlapping_player_regions(regions)
	var per_region: int = maxi(1, VOXELS_PER_FRAME / merged.size())
	for area: AABB in merged:
		_voxel_tool.run_blocky_random_tick(area, per_region, _random_tick_callback, 16)


func _makes_grass_die(raw_type: int) -> bool:
	return raw_type != 0 and raw_type != _tall_grass_type


func _random_tick_callback(pos: Vector3i, value: int) -> void:
	if value == 2:
		# Grass
		
		# Dying
		var above := pos + Vector3i(0, 1, 0)
		var above_v := _voxel_tool.get_voxel(above)
		if _makes_grass_die(above_v):
			# Turn to dirt
			_voxel_tool.set_voxel(pos, 1)
			if _game != null:
				_game.mark_world_modified()
		else:
			# Spread
			var attempts := 1
			var ra := randf()
			if ra < 0.15:
				attempts = 2
				if ra < 0.03:
					attempts = 3
	
			for i in attempts:
				for di in len(_grass_dirs):
					var npos := pos + _grass_dirs[di]
					var nv := _voxel_tool.get_voxel(npos)
					if nv == 1:
						var above_neighbor := _voxel_tool.get_voxel(npos + Vector3i(0, 1, 0))
						if not _makes_grass_die(above_neighbor):
							_voxel_tool.set_voxel(npos, 2)
							if _game != null:
								_game.mark_world_modified()
							break
