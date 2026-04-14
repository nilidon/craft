extends Control
class_name WorldsPreviewCornerOverlay

## Paints the square corners of the thumbnail; use the same rgba as the card panel bg.
@export var corner_fill: Color = Color(0.08, 0.1, 0.14, 0.9)

const _ARC_STEPS := 16


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 8
	resized.connect(queue_redraw)
	call_deferred(&"queue_redraw")


func _draw() -> void:
	var sz := size
	if sz.x < 4.0 or sz.y < 4.0:
		return
	var r := clampf(minf(sz.x, sz.y) * 0.088, 5.0, 14.0)
	_draw_corner_tl(r)
	_draw_corner_tr(sz.x, r)
	_draw_corner_br(sz.x, sz.y, r)
	_draw_corner_bl(sz.y, r)


func _draw_corner_tl(r: float) -> void:
	## Center (r,r). Short arc from (r,0) [θ=-π/2] to (0,r) [θ=π]; was PI+u·π/2 (wrong way / long arc).
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 0))
	pts.append(Vector2(r, 0))
	for i in range(_ARC_STEPS + 1):
		var u := float(i) / float(_ARC_STEPS)
		var ang := -PI * 0.5 - u * (PI * 0.5)
		pts.append(Vector2(r, r) + Vector2(cos(ang), sin(ang)) * r)
	pts.append(Vector2(0, r))
	draw_colored_polygon(pts, corner_fill)


func _draw_corner_tr(w: float, r: float) -> void:
	var cx := w - r
	var pts := PackedVector2Array()
	pts.append(Vector2(w, 0))
	pts.append(Vector2(w - r, 0))
	for i in range(_ARC_STEPS + 1):
		var u := float(i) / float(_ARC_STEPS)
		var ang := -PI * 0.5 + u * (PI * 0.5)
		pts.append(Vector2(cx, r) + Vector2(cos(ang), sin(ang)) * r)
	pts.append(Vector2(w, r))
	draw_colored_polygon(pts, corner_fill)


func _draw_corner_br(w: float, h: float, r: float) -> void:
	var cx := w - r
	var cy := h - r
	var pts := PackedVector2Array()
	pts.append(Vector2(w, h))
	pts.append(Vector2(w, h - r))
	for i in range(_ARC_STEPS + 1):
		var u := float(i) / float(_ARC_STEPS)
		var ang := u * (PI * 0.5)
		pts.append(Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r)
	pts.append(Vector2(w - r, h))
	draw_colored_polygon(pts, corner_fill)


func _draw_corner_bl(h: float, r: float) -> void:
	## Center (r, h-r). Short arc from (0,h-r) [θ=π] to (r,h) [θ=π/2].
	var cy := h - r
	var pts := PackedVector2Array()
	pts.append(Vector2(0, h))
	pts.append(Vector2(0, h - r))
	for i in range(_ARC_STEPS + 1):
		var u := float(i) / float(_ARC_STEPS)
		var ang := PI - u * (PI * 0.5)
		pts.append(Vector2(r, cy) + Vector2(cos(ang), sin(ang)) * r)
	pts.append(Vector2(r, h))
	draw_colored_polygon(pts, corner_fill)
