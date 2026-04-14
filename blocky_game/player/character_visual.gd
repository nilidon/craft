extends Node3D
## When visible (third person), rotate around Y so the block figure faces the camera look direction.

@export var yaw_offset_radians: float = 0.0

func _process(_delta: float) -> void:
	if not visible:
		return
	var cam: Camera3D = get_parent().get_node_or_null("Camera") as Camera3D
	if cam == null:
		# RemoteCharacter (multiplayer) has no Camera; use the active view camera so skins face the viewer.
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var look_flat := -cam.global_transform.basis.z
	look_flat.y = 0.0
	if look_flat.length_squared() < 1e-6:
		return
	look_flat = look_flat.normalized()
	rotation.y = atan2(look_flat.x, look_flat.z) + yaw_offset_radians
