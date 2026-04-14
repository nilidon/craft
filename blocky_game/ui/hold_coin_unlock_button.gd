extends Button
class_name HoldCoinUnlockButton
## Press and hold to confirm purchase; warm gold sweep L→R with a light shimmer (buy button).

signal hold_completed

@export var hold_duration_sec: float = 0.88

## Rich honey-gold fill — reads as “value” on top of the bronze face, not flat brown.
const _FILL_GOLD := Color(1.0, 0.82, 0.28, 0.62)

var _holding: bool = false
var _hold_t: float = 0.0
var _fill_host: Control
var _fill_panel: Panel
var _fill_style: StyleBoxFlat


func _ready() -> void:
	StoreUnlockUi.apply_coin_chip_hit_target_theme(self)
	clip_contents = false
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_hold_visuals()
	## [StoreUnlockUi.sync_coin_unlock_chip] may run before this node enters the tree (e.g. map
	## type cards). Face/chip are then added before the fill host exists, so an early
	## bring_progress_to_front could not stack the fill — restack now: face → fill → chip.
	if get_node_or_null("CoinButtonFace") != null or get_node_or_null("CoinChipRoot") != null:
		bring_progress_to_front()
		sync_face_after_chip_layout()
	## Terrain / menu: deferred sync can run before _ready finishes; build face here after fill host exists.
	if has_meta(&"sync_price_on_ready"):
		var pr: int = int(get_meta(&"sync_price_on_ready", 0))
		if pr > 0:
			var vp: Viewport = get_viewport()
			if vp != null:
				var sc: float = StoreUnlockUi.viewport_scale(vp)
				StoreUnlockUi.sync_coin_unlock_chip(self, pr, sc)
		remove_meta(&"sync_price_on_ready")


func _build_hold_visuals() -> void:
	_fill_host = Control.new()
	_fill_host.name = &"CoinHoldFillHost"
	_fill_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_host.clip_contents = true
	## Must be > 0: negative z draws under the [Button]’s own stylebox, so the L→R hold fill vanishes.
	_fill_host.z_index = 1
	add_child(_fill_host)
	_fill_panel = Panel.new()
	_fill_panel.name = &"CoinHoldFillPanel"
	_fill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_panel.anchor_left = 0.0
	_fill_panel.anchor_right = 0.0
	_fill_panel.anchor_top = 0.0
	_fill_panel.anchor_bottom = 1.0
	_fill_panel.offset_left = 0.0
	_fill_panel.offset_right = 0.0
	_fill_panel.offset_top = 0.0
	_fill_panel.offset_bottom = 0.0
	_fill_host.add_child(_fill_panel)
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = _FILL_GOLD
	_fill_style.set_border_width_all(0)
	_fill_panel.add_theme_stylebox_override(&"panel", _fill_style)


## After [StoreUnlockUi.sync_coin_unlock_chip]: optional legacy face → fill → chip.
func bring_progress_to_front() -> void:
	var face: Node = get_node_or_null("CoinButtonFace")
	var chip: Node = get_node_or_null("CoinChipRoot")
	var idx := 0
	if face != null and is_instance_valid(face):
		move_child(face, idx)
		idx += 1
	if _fill_host != null and is_instance_valid(_fill_host):
		move_child(_fill_host, idx)
		idx += 1
	if chip != null and is_instance_valid(chip):
		move_child(chip, idx)


## Called from [StoreUnlockUi.sync_coin_unlock_chip] after layout; keeps face in sync with pointer.
func sync_face_after_chip_layout() -> void:
	_refresh_face_visual_state()


func configure_hold_layout(_scale: float) -> void:
	pass


func _chip_style_scale() -> float:
	return float(get_meta(&"chip_style_scale", 1.0))


func _chip_corner_radius_px() -> int:
	var sc: float = _chip_style_scale()
	return clampi(int(round(5.0 * sc)), 4, 8)


func _apply_fill_stylebox(fraction: float) -> void:
	if _fill_style == null:
		return
	var rad: int = _chip_corner_radius_px()
	var right_rad: int = 0 if fraction < 0.998 else rad
	_fill_style.corner_radius_top_left = rad
	_fill_style.corner_radius_bottom_left = rad
	_fill_style.corner_radius_top_right = right_rad
	_fill_style.corner_radius_bottom_right = right_rad
	var c: Color = _FILL_GOLD
	c.a = lerpf(0.58, 0.84, sqrt(clampf(fraction, 0.0, 1.0)))
	_fill_style.bg_color = c
	## Bright “leading edge” while the sweep moves — extra energy on a buy CTA.
	_fill_style.set_border_width_all(0)
	if fraction > 0.04 and fraction < 0.995:
		var bw: int = clampi(int(round(2.0 * _chip_style_scale())), 2, 3)
		_fill_style.border_width_right = bw
		_fill_style.border_color = Color(1.0, 0.98, 0.72, 0.98)
	_fill_panel.queue_redraw()


func _apply_fill_shimmer() -> void:
	if _fill_panel == null:
		return
	if not _holding:
		_fill_panel.self_modulate = Color.WHITE
		return
	var ph: float = Time.get_ticks_msec() * 0.006
	var pulse: float = 1.0 + 0.085 * sin(ph)
	_fill_panel.self_modulate = Color(pulse, pulse * 0.97, pulse * 0.9, 1.0)


func _set_fill_amount(t: float) -> void:
	var p: float = clampf(t, 0.0, 1.0)
	if _fill_panel == null:
		return
	_fill_panel.anchor_left = 0.0
	_fill_panel.anchor_right = p
	_fill_panel.anchor_top = 0.0
	_fill_panel.anchor_bottom = 1.0
	_apply_fill_stylebox(p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		if not _holding:
			StoreUnlockUi.set_coin_button_face_state(self, &"hover")
	elif what == NOTIFICATION_MOUSE_EXIT:
		_cancel_hold()


func _gui_input(event: InputEvent) -> void:
	var down := false
	var up := false
	if event is InputEventScreenTouch:
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed
		up = not event.pressed
	else:
		return
	if down:
		_cancel_hold(false)
		_holding = true
		_hold_t = 0.0
		set_process(true)
		_visual_press(true)
		_update_progress_ui()
		accept_event()
	elif up:
		if _holding and _hold_t < 1.0:
			_cancel_hold(true)
		_visual_press(false)
		accept_event()


func _visual_press(pressed_now: bool) -> void:
	if pressed_now:
		StoreUnlockUi.set_coin_button_face_state(self, &"pressed")
	else:
		_refresh_face_visual_state()


func _refresh_face_visual_state() -> void:
	var r := get_global_rect()
	if r.has_point(get_global_mouse_position()):
		StoreUnlockUi.set_coin_button_face_state(self, &"hover")
	else:
		StoreUnlockUi.set_coin_button_face_state(self, &"normal")


func _process(delta: float) -> void:
	if not _holding:
		set_process(false)
		return
	_hold_t += delta / maxf(0.25, hold_duration_sec)
	_update_progress_ui()
	if _hold_t >= 1.0:
		_hold_t = 1.0
		_holding = false
		set_process(false)
		_visual_press(false)
		hold_completed.emit()
		call_deferred("_flash_complete")


func _flash_complete() -> void:
	_cancel_hold(true)


func _update_progress_ui() -> void:
	_set_fill_amount(_hold_t)
	_apply_fill_shimmer()


func _cancel_hold(reset_visual: bool = true) -> void:
	_holding = false
	_hold_t = 0.0
	set_process(false)
	if reset_visual:
		_refresh_face_visual_state()
	_set_fill_amount(0.0)
	if _fill_panel != null:
		_fill_panel.self_modulate = Color.WHITE
