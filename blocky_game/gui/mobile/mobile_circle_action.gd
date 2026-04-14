extends Control
class_name MobileCircleAction
## Rounded control matching the virtual joystick look; hold to drive `MobileControls` (jump / fly up / fly down).

enum Kind { JUMP_OR_FLY_UP, FLY_DOWN }

@export var kind: Kind = Kind.JUMP_OR_FLY_UP
@export var label_text: String = "Jump"
@export var arrow_up: bool = false
@export var arrow_single_up: bool = false
@export var arrow_single_down: bool = false

var _pressed := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(152, 152)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_set_pressed(st.pressed)
	elif MobileControls.is_desktop_preview() and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_set_pressed(mb.pressed)


func _set_pressed(on: bool) -> void:
	if _pressed == on:
		return
	_pressed = on
	_apply_to_mobile(on)
	queue_redraw()


func _apply_to_mobile(on: bool) -> void:
	match kind:
		Kind.JUMP_OR_FLY_UP:
			MobileControls.jump_held = on
		Kind.FLY_DOWN:
			MobileControls.fly_down_held = on


func release_hold() -> void:
	if _pressed:
		_pressed = false
		_apply_to_mobile(false)
		queue_redraw()


func _exit_tree() -> void:
	release_hold()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	draw_arc(c, r, 0.0, TAU, 72, Color(1, 1, 1, 0.12), 2.0, true)
	var ring_a := 0.42 if _pressed else 0.24
	draw_arc(c, r * 0.88, 0.0, TAU, 72, Color(1, 1, 1, ring_a), 2.5, true)
	if arrow_up:
		_draw_up_arrow_chevron(c, r)
		return
	if arrow_single_up:
		_draw_single_arrow_chevron(c, r, true)
		return
	if arrow_single_down:
		_draw_single_arrow_chevron(c, r, false)
		return
	var f := ThemeDB.fallback_font
	if f == null:
		return
	var fs := int(clampf(minf(size.x, size.y) * 0.105, 15.0, 18.0))
	var sz := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var tp := c - Vector2(sz.x * 0.5, sz.y * 0.5)
	draw_string(f, tp, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.97, 1.0, 0.95))


## Two stacked line chevrons (double-up); group stays centered on `center`, same stroke style as the inner ring.
func _draw_up_arrow_chevron(center: Vector2, ring_r: float) -> void:
	var h := ring_r * 0.26
	var half_w := ring_r * 0.48
	var gap := -ring_r * 0.028
	var s := h + gap * 0.5
	var line_a := 0.52 if _pressed else 0.32
	_draw_chevron_strokes(center + Vector2(0.0, -s), h, half_w, line_a, true)
	_draw_chevron_strokes(center + Vector2(0.0, s), h, half_w, line_a, true)


func _draw_single_arrow_chevron(center: Vector2, ring_r: float, point_up: bool) -> void:
	var h := ring_r * 0.32
	var half_w := ring_r * 0.50
	var line_a := 0.48 if _pressed else 0.30
	_draw_chevron_strokes(center, h, half_w, line_a, point_up)


func _draw_chevron_strokes(o: Vector2, h: float, half_w: float, line_a: float, point_up: bool) -> void:
	var tip: Vector2
	var bl: Vector2
	var br: Vector2
	if point_up:
		tip = o + Vector2(0.0, -h)
		bl = o + Vector2(-half_w, h)
		br = o + Vector2(half_w, h)
	else:
		tip = o + Vector2(0.0, h)
		bl = o + Vector2(-half_w, -h)
		br = o + Vector2(half_w, -h)
	var pts := PackedVector2Array([bl, tip, br])
	draw_polyline(pts, Color(1, 1, 1, 0.14), 7.0, true)
	draw_polyline(pts, Color(1, 1, 1, line_a), 4.0, true)
