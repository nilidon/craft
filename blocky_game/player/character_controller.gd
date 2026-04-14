extends Node3D

const _VOXEL_LIBRARY := preload("res://blocky_game/blocks/voxel_library.tres")
const _InteractionCommon := preload("res://blocky_game/player/interaction_common.gd")

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
@export var head : NodePath
@export var fly_speed := 12.0

@export var terrain : NodePath

@export var water_gravity_scale := 0.2
@export var water_speed_scale := 0.45
@export var water_swim_up_accel := 28.0
@export var water_max_sink_speed := -7.0
@export var water_max_rise_speed := 5.0

var _velocity := Vector3()
var _grounded := false
var _head : Node3D = null
var _box_mover := VoxelBoxMover.new()
var _flying := false
var _last_space_time := 0.0
const DOUBLE_TAP_WINDOW := 0.35
var _water_full_id := -1
var _water_top_id := -1
var _was_in_water := false
var _footstep_cd := 0.0
## Min seconds between footstep SFX while walking (lower = faster cadence).
const _FOOTSTEP_INTERVAL_SEC := 0.26


func _ready():
	# Mask 1 = solid blocks. Mask 2 = pass-through for mover (water, rails) but still hit by voxel raycasts.
	_box_mover.set_collision_mask(1)
	_box_mover.set_step_climbing_enabled(true)
	_box_mover.set_max_step_height(0.5)
	_head = get_node(head)
	_water_full_id = _VOXEL_LIBRARY.get_model_index_from_resource_name("water_full")
	_water_top_id = _VOXEL_LIBRARY.get_model_index_from_resource_name("water_top")


func _is_water_voxel(v: int) -> bool:
	return v == _water_full_id or v == _water_top_id


func _body_in_water(vt: VoxelTool, world_pos: Vector3) -> bool:
	# Match mover AABB vertical span (torso + legs; see interaction_common.player_mover_aabb_local).
	var samples: Array[Vector3] = [
		Vector3(0, -0.75, 0),
		Vector3(0, 0, 0),
		Vector3(0, 0.65, 0),
	]
	for o: Vector3 in samples:
		var p: Vector3 = world_pos + o
		var bx := int(floor(p.x))
		var by := int(floor(p.y))
		var bz := int(floor(p.z))
		var v: int = vt.get_voxel(Vector3(bx, by, bz))
		if _is_water_voxel(v):
			return true
	return false


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_space_time < DOUBLE_TAP_WINDOW:
			_flying = not _flying
			_velocity.y = 0.0
			_last_space_time = 0.0
		else:
			_last_space_time = now


func mobile_toggle_fly() -> void:
	_flying = not _flying
	_velocity.y = 0.0
	GameAudio.play_fly_mode_toggle()


func is_character_flying() -> bool:
	return _flying


func _planar_axes_keyboard() -> Vector2:
	var wy := 0.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		wy += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		wy -= 1.0
	var wx := 0.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		wx += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		wx -= 1.0
	return Vector2(wx, wy)


func _planar_wish(forward_flat: Vector3, right_flat: Vector3) -> Vector3:
	var ax := _planar_axes_keyboard() + MobileControls.get_move_vector()
	if ax.length_squared() > 1.0:
		ax = ax.normalized()
	var w := -forward_flat * ax.y + right_flat * ax.x
	if w.length_squared() < 1e-8:
		return Vector3.ZERO
	return w.normalized()


func _want_jump_input() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or MobileControls.is_jump_held()


func _want_fly_descend() -> bool:
	return (
		Input.is_key_pressed(KEY_SHIFT)
		or Input.is_key_pressed(KEY_CTRL)
		or MobileControls.is_fly_down_held()
	)


func _physics_process(delta: float):
	if has_node(terrain):
		var game := get_node(terrain).get_parent() as BlockyVoxelGame
		if game != null and game.is_local_gameplay_paused():
			return
	var forward := _head.get_transform().basis.z.normalized()
	var right := _head.get_transform().basis.x.normalized()

	var in_water := false
	if has_node(terrain):
		var terrain_node_w: VoxelTerrain = get_node(terrain)
		var vt_w := terrain_node_w.get_voxel_tool()
		vt_w.set_channel(VoxelBuffer.CHANNEL_TYPE)
		in_water = _body_in_water(vt_w, position)
	var was_in_water_prev := _was_in_water

	if _flying:
		var flat_forward := Plane(Vector3(0, 1, 0), 0).project(forward)
		var wish := _planar_wish(flat_forward, right)
		var flat_motor := wish * fly_speed

		var vert := 0.0
		if _want_jump_input():
			vert += fly_speed
		if _want_fly_descend():
			vert -= fly_speed

		_velocity.x = flat_motor.x
		_velocity.z = flat_motor.z
		_velocity.y = vert

		var motion := _velocity * delta
		global_translate(motion)

	else:
		forward = Plane(Vector3(0, 1, 0), 0).project(forward)
		var wish := _planar_wish(forward, right)
		var motor := wish

		var move_speed := speed

		if in_water:
			move_speed *= water_speed_scale

		if motor.length_squared() > 1e-8:
			motor = motor.normalized() * move_speed
		else:
			motor = Vector3.ZERO

		_velocity.x = motor.x
		_velocity.z = motor.z

		if in_water:
			_velocity.y -= gravity * water_gravity_scale * delta
			if _want_jump_input():
				_velocity.y += water_swim_up_accel * delta
			_velocity.y = clampf(_velocity.y, water_max_sink_speed, water_max_rise_speed)
		else:
			_velocity.y -= gravity * delta
			if _grounded and _want_jump_input():
				_velocity.y = jump_force
				_grounded = false
				GameAudio.play_jump()

		var was_grounded := _grounded
		var motion := _velocity * delta
		var vy_before_resolve := _velocity.y
		var stepped_up := false
		var hit_ground_from_air := false

		if has_node(terrain):
			var aabb := _InteractionCommon.player_mover_aabb_local()
			var terrain_node : VoxelTerrain = get_node(terrain)

			var vt := terrain_node.get_voxel_tool()
			vt.set_channel(VoxelBuffer.CHANNEL_TYPE)
			if vt.is_area_editable(AABB(aabb.position + position, aabb.size)):
				var prev_motion := motion
				motion = _box_mover.get_motion(position, motion, aabb, terrain_node)
				global_translate(motion)

				if absf(motion.y) < 0.001 and prev_motion.y < -0.001:
					_grounded = true
					# Per-frame motion is tiny; use pre-resolve vertical speed (not displacement threshold).
					hit_ground_from_air = not was_grounded and vy_before_resolve < -1.8

				if _box_mover.has_stepped_up():
					stepped_up = true
					motion.y = 0
					_grounded = true

				elif absf(motion.y) > 0.001:
					_grounded = false

			else:
				motion = Vector3()

		assert(delta > 0)
		_velocity = motion / delta

		if not in_water and hit_ground_from_air and not stepped_up:
			GameAudio.play_soft_land()
		var h_speed := Vector2(_velocity.x, _velocity.z).length()
		if _grounded and not in_water and h_speed > 0.35:
			_footstep_cd -= delta
			if _footstep_cd <= 0.0:
				GameAudio.play_footstep()
				_footstep_cd = _FOOTSTEP_INTERVAL_SEC
		else:
			_footstep_cd = minf(_footstep_cd, 0.08)

	GameAudio.set_underwater_loop(not _flying and in_water)
	if not _flying and in_water and not was_in_water_prev:
		GameAudio.play_water_splash()
	_was_in_water = in_water

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		rpc(&"receive_position", position)


func get_character_motion_for_visual() -> Dictionary:
	return {
		&"grounded": _grounded,
		&"velocity": _velocity,
		&"flying": _flying,
	}


@rpc("authority", "call_remote", "unreliable")
func receive_position(_unused_pos: Vector3):
	push_error("Didn't expect to receive RPC position")
