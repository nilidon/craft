extends Node

const Blocks = preload("./blocks/blocks.gd")

const MAX_UPDATES_PER_FRAME = 64
const INTERVAL_SECONDS = 0.2
## Steps sideways (±X / ±Z). Down uses vert_left only.
const MAX_SPREAD_HORIZONTAL := 5
## Steps straight down. Does not share the horizontal budget.
const MAX_SPREAD_VERTICAL := 36

const _HORIZ_DIRS: Array[Vector3] = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
]
const _DOWN := Vector3(0, -1, 0)

@onready var _terrain : VoxelTerrain = get_node("../VoxelTerrain")
@onready var _terrain_tool := _terrain.get_voxel_tool()
@onready var _blocks : Blocks = get_node("../Blocks")
@onready var _game: BlockyVoxelGame = get_node("..") as BlockyVoxelGame

## Reuse small triple arrays [pos, h, v] to cut allocation churn.
var _job_pool: Array[Array] = []
var _update_queue: Array[Array] = []
var _process_queue: Array[Array] = []
var _process_index := 0
## Vector3i -> Array[Vector2i]: Pareto frontier of (horiz, vert) budgets already processed at this cell.
var _processed_budgets: Dictionary = {}
var _water_id := -1
var _water_top := -1
var _water_full := -1
var _time_before_next_process := 0.0


func _ready():
	_terrain_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)
	var water = _blocks.get_block_by_name("water").base_info
	_water_id = water.id
	_water_full = water.voxels[0]
	_water_top = water.voxels[1]


func reset_after_stream_change() -> void:
	_release_queue_jobs(_update_queue)
	_release_queue_jobs(_process_queue)
	_update_queue.clear()
	_process_queue.clear()
	_process_index = 0
	_processed_budgets.clear()
	_time_before_next_process = 0.0


func _alloc_job(pos: Vector3, horiz_left: int, vert_left: int) -> Array:
	var job: Array = _job_pool.pop_back() if not _job_pool.is_empty() else []
	job.resize(3)
	job[0] = pos
	job[1] = horiz_left
	job[2] = vert_left
	return job


func _release_job(job: Array) -> void:
	_job_pool.append(job)


func _release_queue_jobs(q: Array[Array]) -> void:
	for j: Array in q:
		_release_job(j)


func _cell_key(p: Vector3) -> Vector3i:
	return Vector3i(int(p.x), int(p.y), int(p.z))


func _budget_dominated(h: int, v: int, frontier: Array) -> bool:
	for p: Vector2i in frontier:
		if p.x >= h and p.y >= v:
			return true
	return false


## If not dominated, insert (h,v) and drop older states this one dominates. Returns whether to run this job.
func _budget_register(k: Vector3i, h: int, v: int) -> bool:
	var frontier: Array = _processed_budgets.get(k, [])
	if _budget_dominated(h, v, frontier):
		return false
	var new_frontier: Array[Vector2i] = []
	for p: Vector2i in frontier:
		if not (h >= p.x and v >= p.y):
			new_frontier.append(p)
	new_frontier.append(Vector2i(h, v))
	_processed_budgets[k] = new_frontier
	return true


## New placements use full horizontal + vertical budgets; propagation passes lower values.
func schedule(
		pos: Vector3,
		horiz_left: int = MAX_SPREAD_HORIZONTAL,
		vert_left: int = MAX_SPREAD_VERTICAL) -> void:
	_update_queue.append(_alloc_job(pos, horiz_left, vert_left))


func _process(delta: float):
	_time_before_next_process -= delta
	if _time_before_next_process <= 0.0:
		_time_before_next_process += INTERVAL_SECONDS
		_do_process_queue()


func _do_process_queue():
	var update_count = 0

	if _process_index >= len(_process_queue):
		_release_queue_jobs(_process_queue)
		_process_queue.clear()
		_process_index = 0
		_swap_queues()

	while update_count < MAX_UPDATES_PER_FRAME:
		if _process_index >= len(_process_queue):
			_release_queue_jobs(_process_queue)
			_process_queue.clear()
			_process_index = 0
			_swap_queues()
			break

		var job: Array = _process_queue[_process_index]
		_process_cell(job[0], job[1], job[2])
		_process_index += 1
		update_count += 1


func _swap_queues():
	var tmp := _update_queue
	_update_queue = _process_queue
	_process_queue = tmp


func _process_cell(pos: Vector3, horiz_left: int, vert_left: int) -> void:
	var vox := _terrain_tool.get_voxel(pos)
	var rm := _blocks.get_raw_mapping(vox)
	var k := _cell_key(pos)

	if rm.block_id != _water_id:
		_processed_budgets.erase(k)
		return

	if not _budget_register(k, horiz_left, vert_left):
		return

	_fill_with_water(pos)

	for d: Vector3 in _HORIZ_DIRS:
		if horiz_left <= 0:
			break
		var npos := pos + d
		var nv := _terrain_tool.get_voxel(npos)
		if nv == Blocks.AIR_ID:
			_fill_with_water(npos)
			schedule(npos, horiz_left - 1, vert_left)

	if vert_left > 0:
		var npos := pos + _DOWN
		var nv := _terrain_tool.get_voxel(npos)
		if nv == Blocks.AIR_ID:
			_fill_with_water(npos)
			schedule(npos, horiz_left, vert_left - 1)


func _fill_with_water(pos: Vector3):
	var above := pos + Vector3(0, 1, 0)
	var below := pos - Vector3(0, 1, 0)
	var above_v := _terrain_tool.get_voxel(above)
	var below_v := _terrain_tool.get_voxel(below)
	var above_rm := _blocks.get_raw_mapping(above_v)
	# Make sure the top has the surface model
	if above_rm.block_id == _water_id:
		_terrain_tool.set_voxel(pos, _water_full)
	else:
		_terrain_tool.set_voxel(pos, _water_top)
	if below_v == _water_top:
		_terrain_tool.set_voxel(below, _water_full)
	if _game != null:
		_game.mark_world_modified()
