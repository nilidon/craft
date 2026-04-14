extends Control
class_name CoinsPlusButton
## Small circular “+” control to open the coins info screen. Matches soft HUD styling.

signal pressed

## Claim badge: same read as tab dot — amber fill, dark stroke (no light rim).
const _PIP_FILL := Color(0.96, 0.55, 0.14, 1.0)
const _PIP_STROKE := Color(0.36, 0.22, 0.08, 0.92)

var _pressed := false
var _show_claim_notification := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "How to earn coins"


func set_show_claim_notification(on: bool) -> void:
	if _show_claim_notification == on:
		return
	_show_claim_notification = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var ev := make_input_local(event)
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if Rect2(Vector2.ZERO, size).has_point(mb.position):
					_pressed = true
					queue_redraw()
					accept_event()
			else:
				if _pressed:
					_pressed = false
					queue_redraw()
					if Rect2(Vector2.ZERO, size).has_point(mb.position):
						pressed.emit()
					accept_event()
	elif ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if not Rect2(Vector2.ZERO, size).has_point(st.position):
			return
		if st.pressed:
			_pressed = true
			queue_redraw()
			accept_event()
		else:
			if _pressed:
				_pressed = false
				queue_redraw()
				pressed.emit()
				accept_event()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var fill_a := 0.22 if _pressed else 0.14
	draw_circle(c, r, Color(0.96, 0.97, 1.0, fill_a))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.28), 2.0, true)
	var arm := r * 0.38
	var w := maxf(2.0, r * 0.12)
	draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), Color(0.96, 0.97, 1.0, 0.95), w)
	draw_line(c - Vector2(0, arm), c + Vector2(0, arm), Color(0.96, 0.97, 1.0, 0.95), w)
	if _show_claim_notification:
		var br := maxf(6.5, r * 0.36)
		var half := minf(size.x, size.y) * 0.5
		# Push toward top-right; cap so the pip stays inside on small scaled buttons.
		var k := minf(0.78, (half - br - 1.5) / maxf(r, 0.001))
		var pc := c + Vector2(r * k, -r * k)
		draw_circle(pc, br, _PIP_FILL)
		draw_arc(pc, br, 0.0, TAU, 40, _PIP_STROKE, 2.0, true)
