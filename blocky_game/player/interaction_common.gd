const Blocks = preload("../blocks/blocks.gd")
const Util = preload("res://common/util.gd")
const WaterUpdater = preload("./../water.gd")

const BUILD_HEIGHT_LIMIT := 128


## Slightly padded AABB so edits that touch neighbor voxels (meshing / tools) only run once data is present.
static func edit_aabb_for_single_block(pos: Vector3) -> AABB:
	var o := Vector3(floor(pos.x), floor(pos.y), floor(pos.z))
	return AABB(o - Vector3.ONE, Vector3(3, 3, 3))


## VoxelBoxMover / block-placement checks: torso + legs to the ground only. Feet at y = -0.9 from avatar origin.
## Top is below the camera (~0.7) so head / hair / hat do not use voxel collision.
static func player_mover_aabb_local() -> AABB:
	return AABB(Vector3(-0.35, -0.9, -0.35), Vector3(0.7, 1.32, 0.7))


static func player_mover_aabb_at(origin: Vector3) -> AABB:
	var a := player_mover_aabb_local()
	return AABB(a.position + origin, a.size)


static func place_single_block(terrain_tool: VoxelTool, pos: Vector3, look_dir: Vector3,
	block_id: int, block_types: Blocks, water_updater: WaterUpdater,
	game: BlockyVoxelGame = null) -> bool:  # class_name from blocky_game.gd

	# Air = break/dig; must work at any Y. All other placements cap at Y 0..127.
	if block_id != Blocks.AIR_ID and pos.y >= BUILD_HEIGHT_LIMIT:
		return false

	var block := block_types.get_block(block_id)
	var voxel_id := 0

	match block.base_info.rotation_type:
		Blocks.ROTATION_TYPE_NONE:
			voxel_id = block.base_info.voxels[0]
		
		Blocks.ROTATION_TYPE_AXIAL:
			var axis := Util.get_longest_axis(look_dir)
			voxel_id = block.base_info.voxels[axis]
		
		Blocks.ROTATION_TYPE_Y:
			var rot := Blocks.get_y_rotation_from_look_dir(look_dir)
			voxel_id = block.base_info.voxels[rot]

		Blocks.ROTATION_TYPE_CUSTOM_BEHAVIOR:
			block.place(terrain_tool, pos, look_dir)
		_:
			# Unknown value
			assert(false)
	
	if block.base_info.rotation_type != Blocks.ROTATION_TYPE_CUSTOM_BEHAVIOR:
		terrain_tool.mode = VoxelTool.MODE_SET
		terrain_tool.value = voxel_id
		terrain_tool.do_point(pos)
	
	water_updater.schedule(pos)
	if game != null:
		game.mark_world_modified()
	return true

