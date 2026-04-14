extends Sprite2D
## Screen-centered reticle; in third person sits lower so it targets past the body (matches voxel ray).
## Position and scale follow the viewport every frame (resolution / aspect independent).

const _REF_SHORT_EDGE := 720.0

func _process(_delta: float) -> void:
	var rect := get_viewport().get_visible_rect()
	var p := rect.position + rect.size * 0.5
	if PlayerSettings.get_third_person():
		p.y += clampf(rect.size.y * 0.12, 48.0, 140.0)
	position = p
	var short_edge := minf(rect.size.x, rect.size.y)
	var s := clampf(short_edge / _REF_SHORT_EDGE, 0.55, 1.45)
	scale = Vector2(s, s)
