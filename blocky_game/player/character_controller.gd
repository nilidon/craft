extends Node3D

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
@export var head : NodePath
@export var fly_speed := 12.0

@export var terrain : NodePath

var _velocity := Vector3()
var _grounded := false
var _head : Node3D = null
var _box_mover := VoxelBoxMover.new()
var _flying := false
var _last_space_time := 0.0
const DOUBLE_TAP_WINDOW := 0.35


func _ready():
	_box_mover.set_collision_mask(1)
	_box_mover.set_step_climbing_enabled(true)
	_box_mover.set_max_step_height(0.5)
	_head = get_node(head)


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_space_time < DOUBLE_TAP_WINDOW:
			_flying = not _flying
			_velocity.y = 0.0
			_last_space_time = 0.0
		else:
			_last_space_time = now


func _physics_process(delta: float):
	var forward := _head.get_transform().basis.z.normalized()
	var right := _head.get_transform().basis.x.normalized()
	var motor := Vector3()

	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		motor -= forward
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		motor += forward
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		motor -= right
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		motor += right

	if _flying:
		var flat_forward := Plane(Vector3(0, 1, 0), 0).project(forward)
		var flat_motor := Vector3()
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
			flat_motor -= flat_forward
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			flat_motor += flat_forward
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
			flat_motor -= right
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			flat_motor += right

		flat_motor = flat_motor.normalized() * fly_speed

		var vert := 0.0
		if Input.is_key_pressed(KEY_SPACE):
			vert += fly_speed
		if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
			vert -= fly_speed

		_velocity.x = flat_motor.x
		_velocity.z = flat_motor.z
		_velocity.y = vert

		var motion := _velocity * delta
		global_translate(motion)

	else:
		forward = Plane(Vector3(0, 1, 0), 0).project(forward)
		motor = Vector3()

		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
			motor -= forward
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			motor += forward
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
			motor -= right
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			motor += right

		motor = motor.normalized() * speed

		_velocity.x = motor.x
		_velocity.z = motor.z
		_velocity.y -= gravity * delta

		if _grounded and Input.is_key_pressed(KEY_SPACE):
			_velocity.y = jump_force
			_grounded = false

		var motion := _velocity * delta

		if has_node(terrain):
			var aabb := AABB(Vector3(-0.4, -0.9, -0.4), Vector3(0.8, 1.8, 0.8))
			var terrain_node : VoxelTerrain = get_node(terrain)

			var vt := terrain_node.get_voxel_tool()
			if vt.is_area_editable(AABB(aabb.position + position, aabb.size)):
				var prev_motion := motion
				motion = _box_mover.get_motion(position, motion, aabb, terrain_node)
				global_translate(motion)

				if absf(motion.y) < 0.001 and prev_motion.y < -0.001:
					_grounded = true

				if _box_mover.has_stepped_up():
					motion.y = 0
					_grounded = true

				elif absf(motion.y) > 0.001:
					_grounded = false

			else:
				motion = Vector3()

		assert(delta > 0)
		_velocity = motion / delta

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		rpc(&"receive_position", position)


@rpc("authority", "call_remote", "unreliable")
func receive_position(_unused_pos: Vector3):
	push_error("Didn't expect to receive RPC position")
