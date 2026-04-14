extends "res://blocky_game/player/character_visual.gd"

const _VoxSkinMesh := preload("res://blocky_game/player/vox_skin_mesh.gd")
const _InteractionCommon := preload("res://blocky_game/player/interaction_common.gd")

## If empty, uses `PlayerSettings.get_skin_vox_path()`. Set on remote puppets so they don't mirror the local player's choice.
@export var skin_vox_path: String = ""
## Fallback mesh when editor import has no geometry; matches `SkinRoot/SkinVox` uniform scale.
@export var runtime_voxel_scale: float = 1.0

@export var walk_bob_amp: float = 0.028
@export var walk_tilt_amp: float = 0.038
## Phase advance = `horiz * walk_phase_speed` (rad/s), capped by max so sprint stays readable.
@export var walk_phase_speed: float = 6.8
@export var walk_phase_speed_max: float = 34.0
@export var jump_pitch_amp: float = 0.11
@export var land_squash_sec: float = 0.14
@export var motion_smooth_hz: float = 11.0

var vox_mesh_source: String = "res://blocky_game/skins/Char000.vox"

var _prev_avatar_pos: Vector3
var _vel_smooth: Vector3 = Vector3.ZERO
var _walk_phase: float = 0.0
var _was_grounded: bool = true
var _land_squash_left: float = 0.0
var _bob_smoothed: float = 0.0
var _pitch_smoothed: float = 0.0
var _roll_smoothed: float = 0.0


func _ready() -> void:
	_prev_avatar_pos = Vector3.ZERO
	if get_parent() is Node3D:
		_prev_avatar_pos = (get_parent() as Node3D).global_position
	call_deferred("_setup_vox_visual")


func _resolve_vox_path() -> String:
	var p := skin_vox_path.strip_edges()
	if not p.is_empty():
		return p
	return PlayerSettings.get_skin_vox_path()


func _setup_vox_visual() -> void:
	vox_mesh_source = _resolve_vox_path()
	_rebuild_vox_instance()
	_ensure_vox_runtime_mesh()
	_apply_vox_vertex_color_material()
	call_deferred("_align_mesh_feet_to_mover")


func _rebuild_vox_instance() -> void:
	var path := vox_mesh_source
	var holder := get_node_or_null("SkinRoot") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "SkinRoot"
		add_child(holder)
	for ch in holder.get_children():
		holder.remove_child(ch)
		ch.free()
	var res := load(path)
	if res == null:
		push_warning("character_visual_vox: missing skin resource: ", path)
		return
	if not (res is PackedScene):
		push_warning("character_visual_vox: not a PackedScene: ", path)
		return
	var inst := (res as PackedScene).instantiate()
	if inst == null:
		return
	if not (inst is Node3D):
		inst.free()
		push_warning("character_visual_vox: skin root must be Node3D: ", path)
		return
	(inst as Node3D).name = "SkinVox"
	holder.add_child(inst as Node3D)
	(inst as Node3D).transform = Transform3D(
		Vector3(0.05625, 0, 0),
		Vector3(0, 0.05625, 0),
		Vector3(0, 0, 0.05625),
		Vector3.ZERO)


func _align_mesh_feet_to_mover() -> void:
	var mi := _find_mesh_instance(self)
	if mi == null or mi.mesh == null:
		return
	var avatar := get_parent() as Node3D
	if avatar == null:
		return
	var holder := get_node_or_null("SkinRoot/SkinVox") as Node3D
	if holder == null:
		holder = get_node_or_null("SkinRoot") as Node3D
		if holder != null and holder.get_child_count() > 0:
			holder = holder.get_child(0) as Node3D
	if holder == null:
		holder = self
	var feet_local_y: float = _InteractionCommon.player_mover_aabb_local().position.y
	var aabb := mi.get_aabb()
	if aabb.size.length_squared() < 1e-12:
		return
	var inv_avatar := avatar.global_transform.affine_inverse()
	var inv_cv := global_transform.affine_inverse()
	var mn := aabb.position
	var mx := aabb.position + aabb.size
	var min_avatar_y := 1e9
	var min_cx := 1e9
	var max_cx := -1e9
	var min_cz := 1e9
	var max_cz := -1e9
	for cx in [mn.x, mx.x]:
		for cy in [mn.y, mx.y]:
			for cz in [mn.z, mx.z]:
				var corner_local := Vector3(cx, cy, cz)
				var world := mi.global_transform * corner_local
				var in_avatar := inv_avatar * world
				min_avatar_y = minf(min_avatar_y, in_avatar.y)
				var in_cv := inv_cv * world
				min_cx = minf(min_cx, in_cv.x)
				max_cx = maxf(max_cx, in_cv.x)
				min_cz = minf(min_cz, in_cv.z)
				max_cz = maxf(max_cz, in_cv.z)
	position.y += feet_local_y - min_avatar_y
	if holder != self:
		holder.position.x -= (min_cx + max_cx) * 0.5
		holder.position.z -= (min_cz + max_cz) * 0.5
	else:
		position.x -= (min_cx + max_cx) * 0.5
		position.z -= (min_cz + max_cz) * 0.5


func _ensure_vox_runtime_mesh() -> void:
	var mi := _find_mesh_instance(self)
	if mi == null:
		return
	if mi.mesh != null:
		return
	var built: ArrayMesh = _VoxSkinMesh.build_mesh_from_file(vox_mesh_source, runtime_voxel_scale)
	if built == null:
		return
	mi.mesh = built


## VoxelVox import stores palette in mesh vertex colors (`store_colors_in_texture=false`).
## Default materials ignore that channel — without this, the whole skin reads as one flat color.
func _apply_vox_vertex_color_material() -> void:
	var mi := _find_mesh_instance(self)
	if mi == null:
		return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_color = Color.WHITE
	mat.metallic = 0.0
	mat.roughness = 1.0
	mi.material_override = mat


static func _find_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var found := _find_mesh_instance(c)
		if found != null:
			return found
	return null


func _physics_process(delta: float) -> void:
	var sr := get_node_or_null("SkinRoot") as Node3D
	if sr == null:
		return
	if not visible:
		sr.position = Vector3.ZERO
		sr.rotation = Vector3.ZERO
		sr.scale = Vector3.ONE
		_bob_smoothed = 0.0
		_pitch_smoothed = 0.0
		_roll_smoothed = 0.0
		return

	var avatar := get_parent() as Node3D
	if avatar == null:
		return

	var pos := avatar.global_position
	var vel_meas := (pos - _prev_avatar_pos) / maxf(delta, 1e-6)
	_prev_avatar_pos = pos
	_vel_smooth = _vel_smooth.lerp(vel_meas, minf(1.0, delta * 16.0))

	var grounded := true
	var flying := false
	var vel := _vel_smooth
	if avatar.has_method(&"get_character_motion_for_visual"):
		var st: Dictionary = avatar.get_character_motion_for_visual()
		grounded = st.get(&"grounded", true) as bool
		flying = st.get(&"flying", false) as bool
		vel = st.get(&"velocity", _vel_smooth) as Vector3
	else:
		var horiz_s := Vector2(_vel_smooth.x, _vel_smooth.z).length()
		var vy := _vel_smooth.y
		grounded = horiz_s > 0.2 or absf(vy) < 5.0
		if vy > 2.8:
			grounded = false
		elif vy < -3.5:
			grounded = false

	var horiz := Vector2(vel.x, vel.z).length()

	if grounded and not _was_grounded and not flying:
		_land_squash_left = land_squash_sec
	_was_grounded = grounded

	if _land_squash_left > 0.0:
		_land_squash_left = maxf(_land_squash_left - delta, 0.0)

	var bob_y := 0.0
	var rx := 0.0
	var rz := 0.0
	var sc := Vector3.ONE

	if flying:
		_walk_phase += delta * 2.0
		bob_y = sin(_walk_phase * 0.75) * walk_bob_amp * 0.28
	elif grounded:
		if horiz > 0.22:
			var dphase := delta * clampf(horiz * walk_phase_speed, 0.0, walk_phase_speed_max)
			_walk_phase += dphase
			bob_y = sin(_walk_phase) * walk_bob_amp
			rx = sin(_walk_phase * 0.5) * walk_tilt_amp
			rz = sin(_walk_phase + PI * 0.5) * walk_tilt_amp * 0.42
		else:
			_walk_phase += delta * 0.75
			bob_y = sin(_walk_phase) * walk_bob_amp * 0.06
	else:
		if vel.y > 0.45:
			rx = -jump_pitch_amp * clampf(vel.y / 9.0, 0.0, 1.0)
		elif vel.y < -0.55:
			rx = jump_pitch_amp * 0.5 * clampf(-vel.y / 14.0, 0.0, 1.0)

	if _land_squash_left > 0.0 and land_squash_sec > 1e-5:
		var u := _land_squash_left / land_squash_sec
		var k := sin((1.0 - u) * PI) * 0.09
		sc = Vector3(1.0 + k * 0.45, 1.0 - k, 1.0 + k * 0.45)

	var a := minf(1.0, delta * motion_smooth_hz)
	_bob_smoothed = lerpf(_bob_smoothed, bob_y, a)
	_pitch_smoothed = lerpf(_pitch_smoothed, rx, a)
	_roll_smoothed = lerpf(_roll_smoothed, rz, a)

	sr.position = Vector3(0.0, _bob_smoothed, 0.0)
	sr.rotation = Vector3(_pitch_smoothed, 0.0, _roll_smoothed)
	sr.scale = sc
