extends SubViewportContainer
## Renders a single imported `.vox` skin (PackedScene) for carousel cards.

const _VOX_SCALE := 0.05625

@onready var _vp: SubViewport = $SubViewport
@onready var _holder: Node3D = $SubViewport/WorldRoot/ModelHolder
@onready var _cam: Camera3D = $SubViewport/WorldRoot/Camera3D


func _ready() -> void:
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp.transparent_bg = false


func set_vox_path(path: String) -> void:
	for c in _holder.get_children():
		c.queue_free()
	var res := load(path.strip_edges())
	if res == null or not (res is PackedScene):
		return
	var inst := (res as PackedScene).instantiate()
	if inst == null or not (inst is Node3D):
		if inst != null:
			inst.free()
		return
	var node := inst as Node3D
	node.name = "SkinVox"
	_holder.add_child(node)
	node.transform = Transform3D(Basis.from_scale(Vector3(_VOX_SCALE, _VOX_SCALE, _VOX_SCALE)), Vector3.ZERO)
	call_deferred("_finish_setup", node)


func _finish_setup(inst: Node3D) -> void:
	if not is_instance_valid(inst):
		return
	_apply_vertex_albedo(inst)
	var aabb := _combined_aabb_local(inst)
	if aabb.size.length_squared() < 1e-10:
		return
	inst.position.x = -(aabb.position.x + aabb.size.x * 0.5)
	inst.position.z = -(aabb.position.z + aabb.size.z * 0.5)
	inst.position.y = -aabb.position.y
	_frame_camera(aabb)


func _combined_aabb_local(root: Node3D) -> AABB:
	var out: AABB
	var first := true
	for mi in _all_mesh_instances(root):
		var a: AABB = mi.transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


func _all_mesh_instances(n: Node) -> Array[MeshInstance3D]:
	var r: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		r.append(n as MeshInstance3D)
	for c in n.get_children():
		r.append_array(_all_mesh_instances(c))
	return r


func _apply_vertex_albedo(root: Node) -> void:
	for mi in _all_mesh_instances(root):
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.albedo_color = Color.WHITE
		mat.metallic = 0.0
		mat.roughness = 1.0
		mi.material_override = mat


func _frame_camera(model_aabb: AABB) -> void:
	var h: float = maxf(model_aabb.size.y, 0.01)
	var dist: float = maxf(1.85, h * 2.4)
	var eye := Vector3(0.0, h * 0.42, dist)
	var target := Vector3(0.0, h * 0.48, 0.0)
	_cam.position = eye
	_cam.look_at(target, Vector3.UP)
	_cam.fov = 38.0
