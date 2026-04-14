extends Node
## Server / single-player: spawns [code]coin.glb[/code] pickups and awards the nearby player's peer via [BlockyVoxelGame].

const COIN_SCENE := preload("res://blocky_game/coin.glb")

## ~1 voxel footprint on XZ; vertical band so walking over the cell picks up.
const _PICKUP_RADIUS_XZ := 0.62
const _PICKUP_Y_BELOW := 1.15
const _PICKUP_Y_ABOVE := 0.55
const _COIN_VALUE := 5
const _ONE_BLOCK_SIZE := 0.95
const _SPIN_SPEED := 3.8
const _MAX_ACTIVE := 28
const _SPAWN_INTERVAL_MIN := 14.0
const _SPAWN_INTERVAL_MAX := 32.0
const _SPAWN_ATTEMPTS := 24
const _SPAWN_RADIUS_MIN := 28.0
const _SPAWN_RADIUS_MAX := 72.0
const _RAYCAST_HEIGHT := 110.0

var _game: BlockyVoxelGame = null
var _terrain: VoxelTerrain = null
var _players: Node = null
var _vt: VoxelTool = null
var _coins: Dictionary = {} # int id -> Node3D
var _next_id: int = 1
var _until_spawn: float = 8.0
var _rng := RandomNumberGenerator.new()


func setup(p_game: BlockyVoxelGame, p_terrain: VoxelTerrain, p_players: Node) -> void:
	_game = p_game
	_terrain = p_terrain
	_players = p_players
	_vt = p_terrain.get_voxel_tool()
	_vt.set_channel(VoxelBuffer.CHANNEL_TYPE)
	_rng.randomize()
	_until_spawn = _rng.randf_range(6.0, 14.0)


func spawn_coin_local(pos: Vector3, coin_id: int) -> void:
	if _coins.has(coin_id):
		return
	var root := Node3D.new()
	root.name = "WorldCoin_%d" % coin_id
	root.position = pos
	var model := COIN_SCENE.instantiate()
	root.add_child(model)
	if model is Node3D:
		_fit_model_to_one_block(model as Node3D)
	var holder := _game.get_node_or_null("WorldCoins")
	if holder == null:
		holder = Node3D.new()
		holder.name = "WorldCoins"
		_game.add_child(holder)
	holder.add_child(root)
	_coins[coin_id] = root
	call_deferred("_deferred_center_coin_on_pivot", root)


func remove_coin_local(coin_id: int) -> void:
	var n: Node3D = _coins.get(coin_id, null) as Node3D
	if n != null and is_instance_valid(n):
		n.queue_free()
	_coins.erase(coin_id)


func _first_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var r := _first_mesh_instance(c)
		if r != null:
			return r
	return null


func _each_mesh_instance(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_each_mesh_instance(c))
	return out


## Move the GLB so the combined mesh AABB center sits on [param root] origin; [method Node3D.rotate_y] then spins in world place.
func _deferred_center_coin_on_pivot(root: Node3D) -> void:
	if not is_instance_valid(root) or root.get_child_count() < 1:
		return
	var model := root.get_child(0) as Node3D
	if model == null:
		return
	var inv := root.global_transform.affine_inverse()
	var acc: AABB
	var has_box := false
	for mi in _each_mesh_instance(model):
		var local_xf: Transform3D = inv * mi.global_transform
		var laabb: AABB = local_xf * mi.get_aabb()
		if not has_box:
			acc = laabb
			has_box = true
		else:
			acc = acc.merge(laabb)
	if not has_box:
		return
	model.position -= acc.get_center()


func _fit_model_to_one_block(model: Node3D) -> void:
	var mi := _first_mesh_instance(model)
	if mi == null:
		model.scale = Vector3.ONE * 0.22
		return
	var aabb := mi.get_aabb()
	var mx := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if mx < 0.0001:
		model.scale = Vector3.ONE * 0.22
		return
	model.scale = Vector3.ONE * (_ONE_BLOCK_SIZE / mx)


func _physics_process(delta: float) -> void:
	if _game == null or _terrain == null or _players == null:
		return
	for n: Node3D in _coins.values():
		if is_instance_valid(n):
			n.rotate_y(delta * _SPIN_SPEED)
	if not _is_server_side():
		return
	_until_spawn -= delta
	if _until_spawn <= 0.0 and _coins.size() < _MAX_ACTIVE:
		_until_spawn = _rng.randf_range(_SPAWN_INTERVAL_MIN, _SPAWN_INTERVAL_MAX)
		_try_spawn_one()
	_pickup_tick()


func _is_server_side() -> bool:
	var mp := get_tree().get_multiplayer()
	return mp == null or not mp.has_multiplayer_peer() or mp.is_server()


func _try_spawn_one() -> void:
	var pos := _random_ground_pos()
	if pos.y < -64.0:
		return
	_game.replicate_coin_spawn(pos, _next_id)
	_next_id += 1


func _random_ground_pos() -> Vector3:
	var center := _avg_player_pos()
	var origin_xz := Vector3(center.x, 0.0, center.z)
	for _i in _SPAWN_ATTEMPTS:
		var ang := _rng.randf() * TAU
		var rad := _rng.randf_range(_SPAWN_RADIUS_MIN, _SPAWN_RADIUS_MAX)
		var xz := origin_xz + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var ray_y := maxf(center.y + _RAYCAST_HEIGHT, 96.0)
		var o := Vector3(xz.x, ray_y, xz.z)
		var hit: VoxelRaycastResult = _vt.raycast(o, Vector3.DOWN, ray_y + 96.0)
		if hit == null:
			continue
		var p: Vector3 = hit.position
		# Solid voxel min corner [i]p[/i]; rest coin (~1 unit tall) centered in block column on top face.
		var top_y := p.y + 1.0
		var cy := top_y + _ONE_BLOCK_SIZE * 0.5
		return Vector3(p.x + 0.5, cy, p.z + 0.5)
	return Vector3.ZERO


func _avg_player_pos() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for c in _players.get_children():
		if c is Node3D:
			sum += (c as Node3D).global_position
			n += 1
	if n == 0:
		return BlockyVoxelGame.DEFAULT_SPAWN_POS
	return sum / float(n)


func _pickup_tick() -> void:
	var to_remove: Array[int] = []
	for coin_id: int in _coins.keys():
		var node: Node3D = _coins[coin_id] as Node3D
		if not is_instance_valid(node):
			to_remove.append(coin_id)
			continue
		var p := node.global_position
		for c in _players.get_children():
			if not (c is Node3D):
				continue
			var pl: Node3D = c as Node3D
			var peer_id := int(str(pl.name))
			if peer_id <= 0:
				continue
			var pg := pl.global_position
			var feet_y := pg.y - 0.9
			var dx := pg.x - p.x
			var dz := pg.z - p.z
			var dist_xz := sqrt(dx * dx + dz * dz)
			var dy := feet_y - p.y
			if dist_xz <= _PICKUP_RADIUS_XZ and dy >= -_PICKUP_Y_BELOW and dy <= _PICKUP_Y_ABOVE:
				_game.grant_world_coin_to_peer(peer_id, _COIN_VALUE)
				to_remove.append(coin_id)
				break
	for rid: int in to_remove:
		_game.replicate_coin_remove(rid)
