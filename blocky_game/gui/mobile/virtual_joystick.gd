extends Control
## Stick up = forward (+y on move_vector), right = +x strafe. Coordinates match `character_controller` planar axes.

@export var outer_radius: float = 70.0
@export var knob_radius: float = 26.0

var _vec: Vector2 = Vector2.ZERO
var _touch_idx: int = -1
var _mouse_drag := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var center := size * 0.5
	if MobileControls.is_desktop_preview():
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_drag = true
					_set_from_offset(mb.position - center)
				else:
					if _mouse_drag:
						_mouse_drag = false
						_release_mouse()
		elif event is InputEventMouseMotion and _mouse_drag:
			var mm := event as InputEventMouseMotion
			_set_from_offset(mm.position - center)
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_idx < 0:
				_touch_idx = st.index
				_set_from_offset(st.position - center)
		else:
			if st.index == _touch_idx:
				_release()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_idx:
			_set_from_offset(sd.position - center)


func _release() -> void:
	_touch_idx = -1
	_release_vec()


func _release_mouse() -> void:
	_mouse_drag = false
	_release_vec()


func _release_vec() -> void:
	_vec = Vector2.ZERO
	MobileControls.set_move_vector(_vec)
	queue_redraw()


func _set_from_offset(off: Vector2) -> void:
	var n := off / maxf(outer_radius, 1.0)
	if n.length() > 1.0:
		n = n.normalized()
	_vec = Vector2(n.x, -n.y)
	MobileControls.set_move_vector(_vec)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_arc(c, outer_radius, 0.0, TAU, 72, Color(1, 1, 1, 0.12), 2.0, true)
	var knob_off := Vector2(_vec.x, -_vec.y) * outer_radius
	draw_circle(c + knob_off, knob_radius, Color(1, 1, 1, 0.28))
	draw_arc(c + knob_off, knob_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 2.0, true)
