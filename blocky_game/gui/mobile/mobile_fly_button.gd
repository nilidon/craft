extends Control
class_name MobileFlyButton
## Rounded-rect frame matching mobile HUD style: soft fill, inner/outer rings, icon + caption.
## `FLY_TOGGLE`: tap/release toggles fly. `PLACE_BLOCK`: release after press requests place. `BREAK_BLOCK`: press requests one break.

enum HudAction { FLY_TOGGLE, PLACE_BLOCK, BREAK_BLOCK }

@export var hud_action: HudAction = HudAction.FLY_TOGGLE
@export var icon_texture: Texture2D
@export var display_label: String = "Fly"

var _pressed := false
var _touch_idx: int = -1
var _mouse_down := false
var _fill: StyleBoxFlat
var _outline_outer: StyleBoxFlat
var _outline_inner: StyleBoxFlat


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96, 118)
	_fill = StyleBoxFlat.new()
	_fill.set_border_width_all(0)
	_outline_outer = StyleBoxFlat.new()
	_outline_outer.bg_color = Color(0, 0, 0, 0)
	_outline_outer.set_border_width_all(2)
	_outline_inner = StyleBoxFlat.new()
	_outline_inner.bg_color = Color(0, 0, 0, 0)
	_outline_inner.set_border_width_all(3)


func set_display_label(s: String) -> void:
	display_label = s
	queue_redraw()


func set_fly_icon(tex: Texture2D) -> void:
	icon_texture = tex
	queue_redraw()


## Alias for hotbar preview on the place button (same as set_fly_icon).
func set_preview_texture(tex: Texture2D) -> void:
	set_fly_icon(tex)


func release_break_hold() -> void:
	_touch_idx = -1
	_mouse_down = false
	_pressed = false
	queue_redraw()


func _draw_icon_with_stroke(tex: Texture2D, rect: Rect2) -> void:
	var stroke := Color(0.08, 0.1, 0.18, 0.94)
	var dirs: Array[Vector2] = [
		Vector2(-1, -1),
		Vector2(0, -1),
		Vector2(1, -1),
		Vector2(-1, 0),
		Vector2(1, 0),
		Vector2(-1, 1),
		Vector2(0, 1),
		Vector2(1, 1),
	]
	for d in dirs:
		draw_texture_rect(tex, Rect2(rect.position + d, rect.size), false, stroke)
	draw_texture_rect(tex, rect, false, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	match hud_action:
		HudAction.FLY_TOGGLE:
			_input_fly(event)
		HudAction.PLACE_BLOCK:
			_input_place(event)
		HudAction.BREAK_BLOCK:
			_input_break(event)


func _input_fly(event: InputEvent) -> void:
	if MobileControls.is_desktop_preview():
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_down = true
					_pressed = true
					queue_redraw()
				else:
					if _mouse_down:
						_mouse_down = false
						_pressed = false
						queue_redraw()
						MobileControls.toggle_player_fly()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_idx < 0:
				_touch_idx = st.index
				_pressed = true
				queue_redraw()
		else:
			if st.index == _touch_idx:
				_touch_idx = -1
				_pressed = false
				queue_redraw()
				MobileControls.toggle_player_fly()


func _input_place(event: InputEvent) -> void:
	if MobileControls.is_desktop_preview():
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_down = true
					_pressed = true
					queue_redraw()
				elif _mouse_down:
					_mouse_down = false
					_pressed = false
					MobileControls.request_place_block()
					queue_redraw()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_idx < 0:
				_touch_idx = st.index
				_pressed = true
				queue_redraw()
		elif st.index == _touch_idx:
			_touch_idx = -1
			_pressed = false
			MobileControls.request_place_block()
			queue_redraw()


func _input_break(event: InputEvent) -> void:
	if MobileControls.is_desktop_preview():
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_down = true
					_pressed = true
					MobileControls.request_break_block()
					queue_redraw()
				elif _mouse_down:
					_mouse_down = false
					_pressed = false
					queue_redraw()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_idx < 0:
				_touch_idx = st.index
				_pressed = true
				MobileControls.request_break_block()
				queue_redraw()
		elif st.index == _touch_idx:
			_touch_idx = -1
			_pressed = false
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_pressed = false
		_touch_idx = -1
		_mouse_down = false
		queue_redraw()


func _draw() -> void:
	const top_y := 8.0
	const bottom_gap := 8.0
	const pad := 5.0
	const max_side := 86.0
	var side := minf(size.x - pad * 2.0, size.y - top_y - bottom_gap)
	side = minf(side, max_side)
	side = maxf(side, 64.0)
	var outer := Rect2((size.x - side) * 0.5, top_y, side, side)
	var cr_o := int(clampf(side * 0.14, 8.0, 14.0))
	var cr_i := maxi(cr_o - 4, 3)
	var fill_a := 0.2 if _pressed else 0.11
	_fill.bg_color = Color(0.96, 0.97, 1.0, fill_a)
	_fill.set_corner_radius_all(cr_o)
	draw_style_box(_fill, outer)
	_outline_outer.border_color = Color(1, 1, 1, 0.12)
	_outline_outer.set_corner_radius_all(cr_o)
	draw_style_box(_outline_outer, outer)
	var inner := outer.grow_individual(-5.0, -5.0, -5.0, -5.0)
	var ring_a := 0.42 if _pressed else 0.24
	_outline_inner.border_color = Color(1, 1, 1, ring_a)
	_outline_inner.set_corner_radius_all(cr_i)
	draw_style_box(_outline_inner, inner)
	const label_fs := 15
	const pad_x := 8.0
	const pad_top := 11.0
	const pad_bottom := 10.0
	var content := Rect2(
		outer.position.x + pad_x,
		outer.position.y + pad_top,
		outer.size.x - pad_x * 2.0,
		outer.size.y - pad_top - pad_bottom
	)
	var f := ThemeDB.fallback_font
	var label_h := float(label_fs) + 7.0
	var icon_band_h := maxf(content.size.y - label_h, 10.0)
	if icon_texture != null:
		var ts := icon_texture.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			var max_w := content.size.x * 0.78
			var max_h := icon_band_h
			var scl := minf(max_w / ts.x, max_h / ts.y)
			var iw := ts.x * scl
			var ih := ts.y * scl
			var ix := content.position.x + (content.size.x - iw) * 0.5
			var iy := content.position.y + (icon_band_h - ih) * 0.5
			iy = clampf(iy, content.position.y, content.position.y + maxf(icon_band_h - ih, 0.0))
			_draw_icon_with_stroke(icon_texture, Rect2(ix, iy, iw, ih))
	if f != null:
		var sz := f.get_string_size(display_label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs)
		var baseline := content.position.y + icon_band_h + f.get_ascent(label_fs) + 3.0
		var tp := Vector2(content.position.x + (content.size.x - sz.x) * 0.5, baseline)
		draw_string(
			f,
			tp,
			display_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			label_fs,
			Color(0.96, 0.97, 1.0, 0.95)
		)
