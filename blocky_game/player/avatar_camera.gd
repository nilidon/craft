extends Camera3D

@export var sensitivity = 0.4
@export var min_angle = -90
@export var max_angle = 90
@export var capture_mouse = true
@export var distance = 0.0
@export var touch_look_scale: float = 0.38

const _THIRD_PERSON_DEFAULT_DISTANCE := 4.85
## Extra height above first-person eye (parent Y). The screen-center ray is horizontal at this height; it must sit
## *above* the block head (~0.8m top). Lower values pull the ray *down through* the body (crosshair on torso).
const _THIRD_PERSON_PIVOT_ABOVE_EYE := 0.26
## Third person only: max degrees *above* horizon (stored pitch is negative when looking up).
## Caps steep look-up; positive pitch (look down) still uses full max_angle.
const _THIRD_PERSON_MAX_LOOK_UP_DEG := 68.0

var _yaw = 0
var _pitch = 0
var _offset = Vector3()
## Scene eye offset (first person); third person uses a lower pivot on the same look direction.
var _base_eye_offset := Vector3()
var _third_person_mode := false
var _invert_pitch := false


func _ready():
	add_to_group("settings_player_camera_fov")
	add_to_group("settings_player_camera_person")
	_base_eye_offset = position
	_offset = _base_eye_offset
	_apply_saved_look_settings()
	if DisplayServer.is_touchscreen_available():
		capture_mouse = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_activate_when_spawn_chunk_meshed()


func release_mouse_for_mobile_ui() -> void:
	capture_mouse = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func apply_touch_look_pixels(relative: Vector2) -> void:
	var mul: float = float(touch_look_scale) * float(sensitivity)
	_yaw -= relative.x * mul
	var pitch_mul: float = -1.0 if _invert_pitch else 1.0
	_pitch += relative.y * mul * pitch_mul
	var p_lo: float = min_angle + 0.001
	var p_hi: float = max_angle - 0.001
	if _third_person_mode:
		p_lo = maxf(p_lo, -_THIRD_PERSON_MAX_LOOK_UP_DEG)
	_pitch = clampf(_pitch, p_lo, p_hi)
	update_rotations()


func _apply_saved_look_settings() -> void:
	sensitivity = PlayerSettings.get_mouse_sensitivity()
	_invert_pitch = PlayerSettings.get_invert_mouse_y()
	fov = PlayerSettings.get_camera_fov()
	apply_camera_person_from_settings()


func apply_camera_person_from_settings() -> void:
	var tp := PlayerSettings.get_third_person()
	_third_person_mode = tp
	if tp:
		if distance <= 0.001:
			distance = _THIRD_PERSON_DEFAULT_DISTANCE
	else:
		distance = 0.0
	var avatar := get_parent()
	if avatar != null:
		var vis: Node3D = avatar.get_node_or_null("CharacterVisual") as Node3D
		if vis != null:
			vis.visible = tp
	update_rotations()


func _activate_when_spawn_chunk_meshed() -> void:
	# First frames often show procedural sky through unloaded voxels; wait until this area has
	# finished meshing (VoxelTerrain.is_area_meshed — see godot_voxel docs).
	var avatar: Node3D = get_parent()
	var tp: Variant = avatar.get("terrain")
	if tp == null or not (tp is NodePath) or (tp as NodePath).is_empty():
		current = true
		return
	if not avatar.has_node(tp as NodePath):
		current = true
		return
	var terrain := avatar.get_node(tp as NodePath) as VoxelTerrain
	if terrain == null:
		current = true
		return
	var frames := 0
	const MAX_FRAMES := 240
	var aabb := _spawn_column_meshed_aabb(terrain, avatar.global_position)
	while frames < MAX_FRAMES and not terrain.is_area_meshed(aabb):
		frames += 1
		await get_tree().process_frame
	current = true


func _spawn_column_meshed_aabb(terrain: VoxelTerrain, world_pos: Vector3) -> AABB:
	# Column from below surface to above spawn so "empty" air near the player isn't enough:
	# ground blocks must have been meshed too (covers high spawn Y).
	var c := terrain.to_local(world_pos)
	var half := Vector3(24.0, 88.0, 24.0)
	return AABB(c - half, half * 2.0)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			if capture_mouse:
				# Capture the mouse
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	elif event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED || not capture_mouse:
			# Get mouse delta
			var motion = event.relative
			
			# Add to rotations
			_yaw -= motion.x * sensitivity
			var pitch_mul := -1.0 if _invert_pitch else 1.0
			_pitch += motion.y * sensitivity * pitch_mul
			
			var p_lo: float = min_angle + 0.001
			var p_hi: float = max_angle - 0.001
			if _third_person_mode:
				p_lo = maxf(p_lo, -_THIRD_PERSON_MAX_LOOK_UP_DEG)
			_pitch = clampf(_pitch, p_lo, p_hi)
			update_rotations()
	
	elif event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_ESCAPE:
				# Get the mouse back
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
			elif event.keycode == KEY_I:
				var pos = position
				var fw = -transform.basis.z
				print("Position: ", pos, ", Forward: ", fw)


func update_rotations():
	if _third_person_mode:
		var tp_y: float = _base_eye_offset.y + _THIRD_PERSON_PIVOT_ABOVE_EYE
		tp_y = maxf(tp_y, 0.92)
		_offset = Vector3(_base_eye_offset.x, tp_y, _base_eye_offset.z)
	else:
		_offset = _base_eye_offset
	set_position(Vector3.ZERO)
	# Yaw around world up, then pitch around camera-right (identical behavior 1st/3rd person).
	# Avoid euler `set_rotation` + `rotate`: at steep pitch it can twist and feel like vertical 360°.
	var yaw_rad := deg_to_rad(_yaw)
	var pitch_rad := deg_to_rad(_pitch)
	var xf := Transform3D.IDENTITY.rotated(Vector3.UP, yaw_rad)
	xf = xf.rotated(xf.basis.x, -pitch_rad)
	transform.basis = xf.basis.orthonormalized()
	set_position(transform.basis.z * distance + _offset)
