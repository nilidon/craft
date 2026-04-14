extends Control
## Three fixed slots (prev / current / next). No scrolling strip — nothing exists left/right to peek through the clip rect.

signal shop_message(text: String)

const SkinCat: Script = preload("res://blocky_game/skins/skin_catalog.gd")
const PlayerProgress = preload("res://blocky_game/progression/player_progress.gd")
const StoreUnlockUi = preload("res://blocky_game/ui/store_unlock_ui.gd")
const HoldCoinUnlockButton = preload("res://blocky_game/ui/hold_coin_unlock_button.gd")
const _CARD_NORMAL: StyleBoxFlat = preload("res://blocky_game/ui/character_select/character_select_card_normal.tres")
const _CARD_SELECTED: StyleBoxFlat = preload("res://blocky_game/ui/character_select/character_select_card_selected.tres")
const _CARD_INNER_VIGNETTE_SHADER: Shader = preload("res://blocky_game/ui/character_select/card_inner_vignette.gdshader")

const _BASE_CARD_W := 204
## Design-time card height; runtime `_card_h` scales from viewport.
const _BASE_CARD_H := 336
## Must match `character_select_card_*.tres` corner_radius and border_width.
const _CARD_CORNER_RADIUS := 12
## Thickest card border (selected / gold frame); must match `character_select_card_selected.tres`.
const _CARD_FRAME_W := 3
## Inner margin so preview / gray panel sit inside the thickest frame.
const _FRAME_INSET_PX := 3
## Bottom radii on the gray band panel — lines up with the selected frame’s inner curve.
const _BAND_BOTTOM_CORNER_RADIUS := _CARD_CORNER_RADIUS - _CARD_FRAME_W
## Center card: gray strip fits name + select lane (fraction derived from card height below).
const _GRAY_BAND_HEIGHT_PX := 88.0
## Side cards: shorter strip — label only, no button (common carousel “peek” pattern).
const _SIDE_GRAY_BAND_HEIGHT_PX := 46.0
## Wide enough that a scaled center card (~1.32×) does not overlap side panels (transparent borders stay hidden).
const _BASE_CARD_SEP := 48
const _SLOT_COUNT := 3
const _FOCUS_CARD_SCALE: float = 1.32
const _BASE_SWIPE_DRAG_PX := 48.0
const _BUMP_SHRINK_SEC := 0.085
const _BUMP_GROW_SEC := 0.16
const _NAME_BAND_COLOR := Color(0.2, 0.21, 0.23, 0.88)
## Center slot only: reserved height for the Select button row.
const _BAND_SELECT_LANE_MIN_H := 52.0
const _SELECT_LANE_MARGIN_MIN := 2.0
const _SELECT_LANE_MARGIN_MAX := 10.0
const _TEXTURE_BTN_MARGIN_RATIO := 0.09
const _TEXTURE_BTN_MARGIN_MAX := 12.0
## Keeps TextureButton art inside the gray ColorRect (floating node is not clipped by the card).
const _TEXTURE_BTN_BAND_INSET := 2.0

## Override in the inspector if needed. Both must be set for image buttons; clear both to use the flat text button.
@export_group("Skin select button textures")
@export var skin_select_texture: Texture2D = preload("res://blocky_game/select.png")
@export var skin_selected_texture: Texture2D = preload("res://blocky_game/selected.png")

var _card_w: int = _BASE_CARD_W
var _card_h: int = _BASE_CARD_H
var _card_sep: int = _BASE_CARD_SEP
var _layout_scale: float = 1.0
var _last_built_w: int = -1
var _last_built_h: int = -1


func refit_layout() -> void:
	call_deferred("_deferred_refit_carousel")


func _carousel_viewport_width() -> int:
	return _SLOT_COUNT * _card_w + (_SLOT_COUNT - 1) * _card_sep


func _scaled_gray_band_h() -> float:
	return _GRAY_BAND_HEIGHT_PX * (float(_card_h) / float(_BASE_CARD_H))


func _scaled_side_gray_band_h() -> float:
	return _SIDE_GRAY_BAND_HEIGHT_PX * (float(_card_h) / float(_BASE_CARD_H))


func _swipe_drag_px() -> float:
	return maxf(22.0, _BASE_SWIPE_DRAG_PX * _layout_scale)


func _compute_layout_metrics() -> void:
	var vw: float
	var vh: float
	if size.x > 8.0 and size.y > 8.0:
		vw = size.x
		vh = size.y
	else:
		var vr: Vector2 = get_viewport().get_visible_rect().size
		var ins := UiSafeMargins.insets_for_viewport(get_viewport())
		vw = maxf(16.0, vr.x - float(ins.x + ins.z))
		vh = maxf(16.0, vr.y - float(ins.y + ins.w))
	if vw < 16.0 or vh < 16.0:
		return
	var title_h: float = 0.0
	if _title_block != null:
		title_h = _title_block.get_combined_minimum_size().y
	var sep_v: float = 14.0
	var vb: VBoxContainer = get_node_or_null("VBox") as VBoxContainer
	if vb != null:
		var sv: int = vb.get_theme_constant(&"separation")
		if sv > 0:
			sep_v = float(sv)
	var row_avail_h: float = maxf(88.0, vh - title_h - sep_v)
	var arrow_guess: float = clampf(vw * 0.078, 38.0, 78.0)
	var inner_w: float = maxf(176.0, vw - 2.0 * arrow_guess - 22.0)
	var max_h: int = maxi(108, int((row_avail_h - 12.0) / _FOCUS_CARD_SCALE))
	var base_row: float = float(3 * _BASE_CARD_W + 2 * _BASE_CARD_SEP)
	var s: float = clampf(inner_w / base_row, 0.34, 1.25)
	_card_w = maxi(84, int(round(float(_BASE_CARD_W) * s)))
	_card_h = maxi(124, int(round(float(_BASE_CARD_H) * s)))
	_card_sep = clampi(int(round(float(_BASE_CARD_SEP) * (float(_card_w) / float(_BASE_CARD_W)))), 6, 72)
	while _carousel_viewport_width() > int(inner_w) and _card_w > 80:
		_card_w -= 1
		_card_sep = maxi(6, int(round(float(_BASE_CARD_SEP) * (float(_card_w) / float(_BASE_CARD_W)))))
	_card_h = clampi(int(round(float(_card_w) * float(_BASE_CARD_H) / float(_BASE_CARD_W))), 110, 400)
	if _card_h > max_h:
		var hf: float = float(max_h) / float(_card_h)
		_card_h = max_h
		_card_w = maxi(80, int(round(float(_card_w) * hf)))
		_card_sep = clampi(int(round(float(_BASE_CARD_SEP) * (float(_card_w) / float(_BASE_CARD_W)))), 6, 72)
		while _carousel_viewport_width() > int(inner_w) and _card_w > 80:
			_card_w -= 1
			_card_sep = maxi(6, int(round(float(_BASE_CARD_SEP) * (float(_card_w) / float(_BASE_CARD_W)))))
		_card_h = mini(max_h, int(round(float(_card_w) * float(_BASE_CARD_H) / float(_BASE_CARD_W))))
	_layout_scale = float(_card_h) / float(_BASE_CARD_H)


func _refit_skins_header_typography() -> void:
	var vw: float = get_viewport().get_visible_rect().size.x
	if vw < 1.0:
		return
	if _title_label != null:
		var title_px: int = clampi(int(round(vw * 0.042)), 30, 72)
		_title_label.add_theme_font_size_override(&"font_size", title_px)
		_title_label.add_theme_constant_override(&"outline_size", clampi(int(round(float(title_px) / 10.0)), 4, 10))
		_title_label.custom_minimum_size.x = clampf(vw * 0.90, 260.0, minf(980.0, vw * 0.96))
	if _subtitle_label != null:
		var sub_px: int = clampi(int(round(vw * 0.016)), 11, 22)
		_subtitle_label.add_theme_font_size_override(&"font_size", sub_px)
		_subtitle_label.add_theme_constant_override(&"outline_size", clampi(int(round(float(sub_px) / 3.0)), 3, 8))
		var sh: int = clampi(int(round(2.0 * sqrt(float(sub_px) * 0.5))), 1, 4)
		_subtitle_label.add_theme_constant_override(&"shadow_offset_x", sh)
		_subtitle_label.add_theme_constant_override(&"shadow_offset_y", sh)
		_subtitle_label.custom_minimum_size.x = clampf(vw * 0.86, 240.0, minf(820.0, vw * 0.94))


func _apply_swipe_and_row_mins() -> void:
	var cvw: float = float(_carousel_viewport_width())
	var min_h: float = maxf(float(_card_h) * _FOCUS_CARD_SCALE + 28.0, 120.0)
	_swipe_area.custom_minimum_size = Vector2(cvw, min_h)
	_card_row.custom_minimum_size = Vector2(cvw, float(_card_h))
	_card_row.add_theme_constant_override(&"separation", _card_sep)
	var aw: int = clampi(int(round(44.0 + 20.0 * _layout_scale)), 32, 74)
	var ah: int = clampi(int(round(float(_card_h) * 0.92)), 64, 260)
	_arrow_prev.custom_minimum_size = Vector2(aw, ah)
	_arrow_next.custom_minimum_size = Vector2(aw, ah)


func _deferred_refit_carousel() -> void:
	if not is_inside_tree():
		return
	_compute_layout_metrics()
	_refit_skins_header_typography()
	_style_carousel_arrow_button()
	var need_build: bool = _slot_cards.is_empty() or _card_w != _last_built_w or _card_h != _last_built_h
	if need_build and not _entries.is_empty():
		_kill_scale_tween()
		_card_vignette_material = null
		var idx: int = _selected_idx
		_build_slots()
		_last_built_w = _card_w
		_last_built_h = _card_h
		_selected_idx = idx
		_refresh_slot_contents()
		_apply_slot_styles()
		_update_carousel_arrows()
		_update_center_select_button()
		## Do not call sync_from_settings here: it re-centers on the saved equipped skin and wipes
		## browse position after resize/refit. Opening the skins screen already syncs from settings once.
	else:
		_last_built_w = _card_w
		_last_built_h = _card_h
	_apply_swipe_and_row_mins()
	_update_inner_min_height()
	if not _slot_cards.is_empty():
		_schedule_focus_visual_after_layout()


func _uses_texture_select_button() -> bool:
	return skin_select_texture != null and skin_selected_texture != null


func _xf_rect_to_global_bbox(xf: Transform2D, local_rect: Rect2) -> Rect2:
	var p0: Vector2 = xf * local_rect.position
	var p1: Vector2 = xf * Vector2(local_rect.end.x, local_rect.position.y)
	var p2: Vector2 = xf * local_rect.end
	var p3: Vector2 = xf * Vector2(local_rect.position.x, local_rect.end.y)
	var min_x: float = minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var max_x: float = maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _panel_gray_band_global_rect(panel: Control, panel_size: Vector2) -> Rect2:
	var gh: float = _scaled_gray_band_h()
	var frac: float = gh / maxf(1.0, panel_size.y)
	var top_l: float = panel_size.y * (1.0 - frac)
	var inset: float = float(_FRAME_INSET_PX)
	var local_band: Rect2 = Rect2(
		inset,
		top_l,
		maxf(4.0, panel_size.x - 2.0 * inset),
		maxf(4.0, panel_size.y - top_l - inset))
	return _xf_rect_to_global_bbox(panel.get_global_transform_with_canvas(), local_band)


func _deflate_rect(r: Rect2, pad: float) -> Rect2:
	if pad <= 0.0:
		return r
	var inner: Vector2 = Vector2(maxf(2.0, r.size.x - 2.0 * pad), maxf(2.0, r.size.y - 2.0 * pad))
	if inner.x < 2.0 or inner.y < 2.0:
		return r
	return Rect2(r.position + Vector2(pad, pad), inner)


func _apply_flat_select_button_theme(btn: Button) -> void:
	var fs: int = clampi(int(round(17.0 * _layout_scale)), 11, 22)
	btn.add_theme_font_size_override(&"font_size", fs)
	btn.add_theme_color_override("font_color", Color(1, 1, 0.95, 1))
	btn.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06, 1))
	btn.add_theme_constant_override(&"outline_size", clampi(int(round(2.0 * sqrt(_layout_scale))), 1, 4))
	btn.add_theme_stylebox_override("normal", _style_select_button(Color(0.34, 0.34, 0.4, 0.96)))
	btn.add_theme_stylebox_override("hover", _style_select_button(Color(0.44, 0.44, 0.52, 0.98)))
	btn.add_theme_stylebox_override("pressed", _style_select_button(Color(0.26, 0.26, 0.32, 1.0)))
	btn.add_theme_stylebox_override("disabled", _style_select_button(Color(0.3, 0.3, 0.34, 0.65)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _skin_lock_visual_scale() -> float:
	var vp: Viewport = get_viewport()
	var vs: float = StoreUnlockUi.viewport_scale(vp)
	return vs * clampf(_layout_scale, 0.92, 1.42)


func _make_skin_preview_lock_layer(band_top: float) -> Control:
	var root := Control.new()
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = band_top
	root.offset_left = float(_FRAME_INSET_PX)
	root.offset_top = float(_FRAME_INSET_PX)
	root.offset_right = -float(_FRAME_INSET_PX)
	root.offset_bottom = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 5
	var dim := Panel.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	## Light tint only — skin must stay readable; compact badge carries the “locked” read.
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.28)
	sb.set_border_width_all(0)
	## Match inner preview corners (same basis as gray band bottom radii); flat bottom edge meets the name band.
	var cr := maxi(1, int(round(float(_BAND_BOTTOM_CORNER_RADIUS) * _layout_scale)))
	sb.corner_radius_top_left = cr
	sb.corner_radius_top_right = cr
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.anti_aliasing = true
	dim.add_theme_stylebox_override(&"panel", sb)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var badge := StoreUnlockUi.make_lock_badge(_skin_lock_visual_scale(), true)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(badge)
	return root


func _style_carousel_arrow_button() -> void:
	var fz: int = clampi(int(round(48.0 * sqrt(_layout_scale))), 22, 58)
	var ol: int = clampi(int(round(4.0 + 3.0 * _layout_scale)), 4, 9)
	for btn: Button in [_arrow_prev, _arrow_next]:
		if btn == null:
			continue
		btn.focus_mode = Control.FOCUS_ALL
		btn.flat = true
		btn.add_theme_font_size_override(&"font_size", fz)
		btn.add_theme_constant_override(&"outline_size", ol)
		var fill: Color = Color(0.96, 0.97, 1.0, 1.0)
		btn.add_theme_color_override("font_color", fill)
		btn.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_hover_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.82, 0.86, 0.94, 1.0))
		btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.64, 0.55))
		# Match normal fill so keyboard/gamepad focus does not tint gold (global theme default).
		btn.add_theme_color_override("font_focus_color", fill)
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for st: StringName in [
			&"normal",
			&"hover",
			&"pressed",
			&"hover_pressed",
			&"disabled",
			&"focus",
		]:
			btn.add_theme_stylebox_override(st, empty)


func _update_carousel_arrows() -> void:
	if _arrow_prev == null or _arrow_next == null:
		return
	var locked: bool = _entries.size() <= 1
	_arrow_prev.disabled = locked
	_arrow_next.disabled = locked


func _style_select_button(bg: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	var cm: int = clampi(int(round(10.0 * sqrt(_layout_scale))), 6, 14)
	sb.set_content_margin_all(cm)
	return sb


@onready var _title_block: VBoxContainer = $VBox/TitleBlock
@onready var _title_label: Label = $VBox/TitleBlock/TitleLabel
@onready var _subtitle_label: Label = $VBox/TitleBlock/SubtitleLabel
@onready var _swipe_area: Control = $VBox/CarouselRow/SwipeArea
@onready var _card_row: HBoxContainer = $VBox/CarouselRow/SwipeArea/StripColumn/CardRow
@onready var _arrow_prev: Button = $VBox/CarouselRow/ArrowPrev
@onready var _arrow_next: Button = $VBox/CarouselRow/ArrowNext

var _entries: Array[Dictionary] = []
var _slot_cards: Array[Panel] = []
var _slot_names: Array[Label] = []
var _slot_previews: Array[TextureRect] = []
var _slot_lock_layers: Array[Control] = []
## Sibling under SwipeArea (not under scaled center Panel) — rect synced to _center_select_lane each frame.
var _center_select_button: BaseButton
var _center_unlock_button: Button
var _center_select_lane: Control
var _last_unlock_cost_shown: int = -1
var _last_unlock_btn_scale: float = -1.0
var _selected_idx: int = 0
var _drag_start_x: float = 0.0
var _drag_armed: bool = false
var _scale_tween: Tween
var _band_panel_style: StyleBoxFlat
var _card_vignette_material: ShaderMaterial


func _card_inner_vignette_material() -> ShaderMaterial:
	if _card_vignette_material == null:
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.shader = _CARD_INNER_VIGNETTE_SHADER
		var aw: float = float(_card_w - 2 * _FRAME_INSET_PX)
		var ah: float = float(_card_h - 2 * _FRAME_INSET_PX)
		sm.set_shader_parameter("box_aspect", aw / maxf(1.0, ah))
		sm.set_shader_parameter("inner_h", ah)
		sm.set_shader_parameter("corner_px", float(_BAND_BOTTOM_CORNER_RADIUS))
		_card_vignette_material = sm
	return _card_vignette_material


func _band_panel_stylebox() -> StyleBoxFlat:
	if _band_panel_style == null:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = _NAME_BAND_COLOR
		sb.border_width_top = 1
		sb.border_color = Color(0.38, 0.4, 0.44, 0.55)
		sb.corner_radius_top_left = 0
		sb.corner_radius_top_right = 0
		sb.corner_radius_bottom_left = _BAND_BOTTOM_CORNER_RADIUS
		sb.corner_radius_bottom_right = _BAND_BOTTOM_CORNER_RADIUS
		sb.anti_aliasing = true
		_band_panel_style = sb
	return _band_panel_style


func _on_carousel_viewport_changed() -> void:
	call_deferred("_deferred_refit_carousel")


func _ready() -> void:
	_entries.assign(SkinCat.entries())
	_swipe_area.clip_contents = true
	_swipe_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_arrow_prev.pressed.connect(_on_carousel_arrow_prev_pressed)
	_arrow_next.pressed.connect(_on_carousel_arrow_next_pressed)
	_swipe_area.resized.connect(_update_inner_min_height)
	_swipe_area.resized.connect(_sync_center_select_button_rect)
	get_viewport().size_changed.connect(_on_carousel_viewport_changed)
	resized.connect(_on_carousel_viewport_changed)
	call_deferred("_deferred_refit_carousel")


func _update_inner_min_height() -> void:
	var col: VBoxContainer = _swipe_area.get_node_or_null("StripColumn") as VBoxContainer
	if col == null:
		return
	var h: float = maxf(float(_swipe_area.size.y), float(_card_h) * _FOCUS_CARD_SCALE + 44.0)
	col.custom_minimum_size.y = h


func sync_from_settings() -> void:
	_update_carousel_arrows()
	if _slot_cards.is_empty() or _entries.is_empty():
		return
	var current: String = PlayerSettings.get_skin_vox_path()
	_selected_idx = 0
	for i in range(_entries.size()):
		if str(_entries[i].get("vox_path", "")) == current:
			_selected_idx = i
			break
	_refresh_slot_contents()
	_apply_slot_styles()
	_schedule_focus_visual_after_layout()


func _schedule_focus_visual_after_layout() -> void:
	call_deferred("_reapply_focus_visual_deferred")


func _reapply_focus_visual_deferred() -> void:
	if _slot_cards.is_empty():
		return
	_apply_slot_styles()
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.process_frame.connect(_reapply_focus_visual_next_frame, CONNECT_ONE_SHOT)


func _reapply_focus_visual_next_frame() -> void:
	if _slot_cards.is_empty():
		return
	_apply_slot_styles()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		refit_layout()
		if not _slot_cards.is_empty():
			_schedule_focus_visual_after_layout()


func _wrapped_idx(i: int) -> int:
	var n: int = _entries.size()
	return ((i % n) + n) % n


func _build_slots() -> void:
	for c: Node in _card_row.get_children():
		c.free()
	_slot_cards.clear()
	_slot_names.clear()
	_slot_previews.clear()
	_slot_lock_layers.clear()
	if _center_select_button != null and is_instance_valid(_center_select_button):
		_center_select_button.queue_free()
	_center_select_button = null
	if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
		_center_unlock_button.queue_free()
	_center_unlock_button = null
	_center_select_lane = null
	for s in range(_SLOT_COUNT):
		var card: Panel = Panel.new()
		card.custom_minimum_size = Vector2(_card_w, _card_h)
		card.pivot_offset = Vector2(float(_card_w) * 0.5, float(_card_h) * 0.5)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.clip_contents = true
		var is_center: bool = s == 1
		var band_frac: float = (_scaled_gray_band_h() / float(_card_h)) if is_center else (_scaled_side_gray_band_h() / float(_card_h))
		var band_top: float = 1.0 - band_frac
		var preview_tr: TextureRect = TextureRect.new()
		preview_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_tr.clip_contents = true
		preview_tr.anchor_left = 0.0
		preview_tr.anchor_top = 0.0
		preview_tr.anchor_right = 1.0
		preview_tr.anchor_bottom = band_top
		preview_tr.offset_left = float(_FRAME_INSET_PX)
		preview_tr.offset_top = float(_FRAME_INSET_PX)
		preview_tr.offset_right = -float(_FRAME_INSET_PX)
		preview_tr.offset_bottom = 0.0
		card.add_child(preview_tr)
		var lock_layer: Control = _make_skin_preview_lock_layer(band_top)
		lock_layer.visible = false
		var band_panel: Panel = Panel.new()
		band_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		band_panel.clip_contents = false
		band_panel.anchor_left = 0.0
		band_panel.anchor_top = band_top
		band_panel.anchor_right = 1.0
		band_panel.anchor_bottom = 1.0
		band_panel.offset_left = float(_FRAME_INSET_PX)
		band_panel.offset_top = 0.0
		band_panel.offset_right = -float(_FRAME_INSET_PX)
		band_panel.offset_bottom = -float(_FRAME_INSET_PX)
		band_panel.add_theme_stylebox_override("panel", _band_panel_stylebox())
		var band_ui: CenterContainer = CenterContainer.new()
		band_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		band_ui.anchor_left = 0.0
		band_ui.anchor_top = 0.0
		band_ui.anchor_right = 1.0
		band_ui.anchor_bottom = 1.0
		band_ui.offset_left = 4.0
		band_ui.offset_top = 3.0
		band_ui.offset_right = -4.0
		band_ui.offset_bottom = -3.0
		var name_btn_col: VBoxContainer = VBoxContainer.new()
		name_btn_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_btn_col.custom_minimum_size.x = float(_card_w - 2 * _FRAME_INSET_PX - 8)
		name_btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
		name_btn_col.add_theme_constant_override("separation", 0)
		var nm: Label = Label.new()
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override(&"font_size", clampi(int(round(22.0 * _layout_scale)), 10, 30))
		nm.add_theme_color_override("font_color", Color(1, 1, 0.92, 1))
		nm.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1))
		nm.add_theme_constant_override(&"outline_size", clampi(int(round(3.0 * sqrt(_layout_scale))), 2, 5))
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size.x = _card_w - 2 * _FRAME_INSET_PX - 16
		nm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		nm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		name_btn_col.add_child(nm)
		if is_center:
			var select_lane: Control = Control.new()
			select_lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
			select_lane.custom_minimum_size = Vector2(0.0, maxf(24.0, _BAND_SELECT_LANE_MIN_H * _layout_scale))
			select_lane.size_flags_horizontal = Control.SIZE_FILL
			select_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			name_btn_col.add_child(select_lane)
			_center_select_lane = select_lane
		band_ui.add_child(name_btn_col)
		band_panel.add_child(band_ui)
		card.add_child(band_panel)
		var vignette: ColorRect = ColorRect.new()
		vignette.name = "InnerVignette"
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vignette.color = Color(1, 1, 1, 1)
		vignette.material = _card_inner_vignette_material()
		vignette.anchor_left = 0.0
		vignette.anchor_top = 0.0
		vignette.anchor_right = 1.0
		vignette.anchor_bottom = 1.0
		vignette.offset_left = float(_FRAME_INSET_PX)
		vignette.offset_top = float(_FRAME_INSET_PX)
		vignette.offset_right = -float(_FRAME_INSET_PX)
		vignette.offset_bottom = -float(_FRAME_INSET_PX)
		card.add_child(vignette)
		card.add_child(lock_layer)
		_slot_lock_layers.append(lock_layer)
		card.add_theme_stylebox_override("panel", _CARD_NORMAL)
		var slot_i: int = s
		card.gui_input.connect(func(ev: InputEvent) -> void:
			_on_slot_gui(ev, slot_i))
		_card_row.add_child(card)
		_slot_cards.append(card)
		_slot_names.append(nm)
		_slot_previews.append(preview_tr)
	_create_floating_center_select_button()


func _create_floating_center_select_button() -> void:
	var bb: BaseButton
	if _uses_texture_select_button():
		var tb: TextureButton = TextureButton.new()
		tb.texture_normal = skin_select_texture
		tb.texture_disabled = skin_selected_texture
		tb.texture_pressed = skin_select_texture
		tb.texture_hover = skin_select_texture
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.ignore_texture_size = true
		tb.clip_contents = true
		## Engine / project theme can draw opaque panels behind TextureButton; that reads as white in transparent PNG areas.
		tb.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		tb.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		tb.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		tb.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		bb = tb
	else:
		var btn: Button = Button.new()
		_apply_flat_select_button_theme(btn)
		bb = btn
	bb.name = "CenterSkinSelectButton"
	bb.z_index = 8
	bb.mouse_filter = Control.MOUSE_FILTER_STOP
	bb.focus_mode = Control.FOCUS_NONE
	bb.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	bb.pressed.connect(_on_center_select_pressed)
	_swipe_area.add_child(bb)
	_center_select_button = bb
	var ubtn: HoldCoinUnlockButton = HoldCoinUnlockButton.new()
	ubtn.name = "CenterSkinUnlockButton"
	ubtn.z_index = 9
	ubtn.mouse_filter = Control.MOUSE_FILTER_STOP
	ubtn.visible = false
	ubtn.hold_completed.connect(_on_center_unlock_pressed)
	_swipe_area.add_child(ubtn)
	_center_unlock_button = ubtn
	_update_center_select_button()
	call_deferred("_sync_center_select_button_rect")


func _sync_center_select_button_rect() -> void:
	if _slot_cards.size() < 3 or not is_visible_in_tree():
		if _center_select_button != null and is_instance_valid(_center_select_button):
			_center_select_button.visible = false
		if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
			_center_unlock_button.visible = false
		return
	if _center_select_button == null or not is_instance_valid(_center_select_button):
		if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
			_center_unlock_button.visible = false
		return
	if _center_unlock_button == null or not is_instance_valid(_center_unlock_button):
		return
	var panel: Control = _slot_cards[1]
	if not panel.is_visible_in_tree():
		if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
			_center_unlock_button.visible = false
		_center_select_button.visible = false
		return
	var sz: Vector2 = panel.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
			_center_unlock_button.visible = false
		_center_select_button.visible = false
		return
	if _center_select_lane == null or not is_instance_valid(_center_select_lane):
		if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
			_center_unlock_button.visible = false
		_center_select_button.visible = false
		return
	var lane_gr: Rect2 = _center_select_lane.get_global_rect()
	var short_side: float = minf(lane_gr.size.x, lane_gr.size.y)
	var use_tex: bool = _uses_texture_select_button()
	var ratio: float = _TEXTURE_BTN_MARGIN_RATIO if use_tex else 0.055
	var mmax: float = _TEXTURE_BTN_MARGIN_MAX if use_tex else _SELECT_LANE_MARGIN_MAX
	var m: float = clampf(short_side * ratio, _SELECT_LANE_MARGIN_MIN, mmax)
	var inner: Rect2 = Rect2(
		lane_gr.position.x + m,
		lane_gr.position.y + m,
		maxf(4.0, lane_gr.size.x - 2.0 * m),
		maxf(4.0, lane_gr.size.y - 2.0 * m))
	var band_gr: Rect2 = _panel_gray_band_global_rect(panel, sz)
	if use_tex:
		band_gr = _deflate_rect(band_gr, 2.0)
	var grect: Rect2 = inner.intersection(band_gr)
	if grect.size.x < 4.0 or grect.size.y < 4.0:
		grect = inner
	if use_tex:
		grect = _deflate_rect(grect, _TEXTURE_BTN_BAND_INSET)
	var inv_swipe: Transform2D = _swipe_area.get_global_transform_with_canvas().affine_inverse()
	var q0: Vector2 = inv_swipe * grect.position
	var q1: Vector2 = inv_swipe * Vector2(grect.end.x, grect.position.y)
	var q2: Vector2 = inv_swipe * grect.end
	var q3: Vector2 = inv_swipe * Vector2(grect.position.x, grect.end.y)
	var lx: float = minf(minf(q0.x, q1.x), minf(q2.x, q3.x))
	var rx: float = maxf(maxf(q0.x, q1.x), maxf(q2.x, q3.x))
	var ty: float = minf(minf(q0.y, q1.y), minf(q2.y, q3.y))
	var by: float = maxf(maxf(q0.y, q1.y), maxf(q2.y, q3.y))
	var local_in_swipe: Rect2 = Rect2(lx, ty, rx - lx, by - ty)
	if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
		_center_unlock_button.position = local_in_swipe.position
		_center_unlock_button.size = local_in_swipe.size
	_center_select_button.position = local_in_swipe.position
	_center_select_button.size = local_in_swipe.size
	_update_center_select_button()


func _process(_delta: float) -> void:
	if _center_select_button == null:
		return
	if not is_visible_in_tree():
		_center_select_button.visible = false
		if _center_unlock_button != null and is_instance_valid(_center_unlock_button):
			_center_unlock_button.visible = false
		return
	_sync_center_select_button_rect()


func _refresh_slot_contents() -> void:
	if _entries.is_empty():
		return
	var n: int = _entries.size()
	var idx_l: int = _wrapped_idx(_selected_idx - 1)
	var idx_c: int = _selected_idx
	var idx_r: int = _wrapped_idx(_selected_idx + 1)
	_fill_slot(0, idx_l)
	_fill_slot(1, idx_c)
	_fill_slot(2, idx_r)
	_update_center_select_button()


func _center_entry_skin_id() -> String:
	return str(_entries[_selected_idx].get(&"id", ""))


func _update_center_select_button() -> void:
	if _center_select_button == null or _entries.is_empty():
		return
	if _center_unlock_button == null or not is_instance_valid(_center_unlock_button):
		return
	var sid := _center_entry_skin_id()
	var cost: int = SkinCat.skin_unlock_coin_cost_for_id(sid)
	var unlocked := PlayerProgress.is_skin_unlocked(sid)
	var shown: String = SkinCat.normalize_vox_path(str(_entries[_selected_idx].get(&"vox_path", "")))
	var saved: String = PlayerSettings.get_skin_vox_path()
	if not unlocked:
		_center_unlock_button.visible = true
		_center_unlock_button.disabled = false
		var scl: float = StoreUnlockUi.viewport_scale(get_viewport()) * clampf(_layout_scale, 0.9, 1.28)
		if cost != _last_unlock_cost_shown or absf(scl - _last_unlock_btn_scale) > 0.07:
			StoreUnlockUi.sync_coin_unlock_chip(_center_unlock_button, cost, scl)
			_last_unlock_cost_shown = cost
			_last_unlock_btn_scale = scl
		_center_unlock_button.custom_minimum_size.y = clampi(int(round(30.0 * scl)), 24, 38)
		var nm := str(_entries[_selected_idx].get(&"label", sid))
		_center_unlock_button.tooltip_text = (
			"%s is locked — hold the price (%d) until the button fills." % [nm, cost])
		_center_select_button.visible = false
		return
	_last_unlock_cost_shown = -1
	_last_unlock_btn_scale = -1.0
	_center_unlock_button.visible = false
	_center_select_button.visible = true
	_center_select_button.tooltip_text = ""
	if saved == shown:
		_center_select_button.disabled = true
	else:
		_center_select_button.disabled = false
	var as_label_btn: Button = _center_select_button as Button
	if as_label_btn != null:
		as_label_btn.text = "Selected" if _center_select_button.disabled else "Select"


func _on_center_unlock_pressed() -> void:
	if _center_unlock_button == null or _entries.is_empty():
		return
	var sid := _center_entry_skin_id()
	if PlayerProgress.is_skin_unlocked(sid):
		return
	var r: Dictionary = PlayerProgress.try_purchase_skin_unlock(sid)
	if not bool(r.get(&"ok", false)):
		if str(r.get(&"reason", "")) == "not_enough_coins":
			shop_message.emit("NOT ENOUGH COINS!")
		else:
			shop_message.emit("Could not unlock this skin.")
		return
	shop_message.emit("%s unlocked!" % str(_entries[_selected_idx].get(&"label", sid)))
	_persist_selected_skin()
	_refresh_slot_contents()
	_update_center_select_button()


func _on_center_select_pressed() -> void:
	if _center_select_button == null or _entries.is_empty():
		return
	if _center_select_button.disabled:
		return
	if not PlayerProgress.is_skin_unlocked(_center_entry_skin_id()):
		return
	GameAudio.play_ui_button()
	_persist_selected_skin()
	_update_center_select_button()


func _fill_slot(slot: int, entry_i: int) -> void:
	var e: Dictionary = _entries[entry_i]
	var path: String = str(e.get("vox_path", ""))
	var label: String = str(e.get("label", path.get_file()))
	var skin_id := str(e.get(&"id", ""))
	var locked := not PlayerProgress.is_skin_unlocked(skin_id)
	_slot_names[slot].text = label
	if slot >= 0 and slot < _slot_lock_layers.size():
		_slot_lock_layers[slot].visible = locked
	if slot >= 0 and slot < _slot_previews.size():
		var tr: TextureRect = _slot_previews[slot]
		var prev_path: String = SkinCat.resolve_preview_path(e)
		if prev_path.is_empty():
			tr.texture = null
		else:
			var res: Resource = ResourceLoader.load(prev_path)
			if res is Texture2D:
				tr.texture = res as Texture2D
			else:
				tr.texture = null
		tr.modulate = Color(0.52, 0.55, 0.62, 1.0) if locked else Color.WHITE


func _kill_scale_tween() -> void:
	if _scale_tween != null and is_instance_valid(_scale_tween):
		_scale_tween.kill()
	_scale_tween = null


func _apply_panel_look_only() -> void:
	for s in range(_SLOT_COUNT):
		var card: Panel = _slot_cards[s]
		var st: StyleBoxFlat = _CARD_SELECTED if s == 1 else _CARD_NORMAL
		card.z_index = 2 if s == 1 else 0
		card.add_theme_stylebox_override("panel", st)


func _persist_selected_skin() -> void:
	if _selected_idx >= 0 and _selected_idx < _entries.size():
		PlayerSettings.set_skin_vox_path(str(_entries[_selected_idx].get("vox_path", "")))


func _apply_slot_styles() -> void:
	_kill_scale_tween()
	_apply_panel_look_only()
	var fs: Vector2 = Vector2(_FOCUS_CARD_SCALE, _FOCUS_CARD_SCALE)
	for s in range(_SLOT_COUNT):
		_slot_cards[s].scale = fs if s == 1 else Vector2.ONE


func _on_carousel_arrow_prev_pressed() -> void:
	_bump_selection(-1)


func _on_carousel_arrow_next_pressed() -> void:
	_bump_selection(1)


func _bump_selection(delta: int) -> void:
	if _entries.is_empty():
		return
	if _entries.size() > 1:
		GameAudio.play_swipe()
	_kill_scale_tween()
	_apply_slot_styles()
	var center: Panel = _slot_cards[1]
	var tw: Tween = create_tween()
	_scale_tween = tw
	tw.tween_property(center, "scale", Vector2.ONE, _BUMP_SHRINK_SEC).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_bump_shrink_finished.bind(delta))


func _on_bump_shrink_finished(delta: int) -> void:
	_selected_idx = _wrapped_idx(_selected_idx + delta)
	_refresh_slot_contents()
	_apply_panel_look_only()
	_slot_cards[0].scale = Vector2.ONE
	_slot_cards[1].scale = Vector2.ONE
	_slot_cards[2].scale = Vector2.ONE
	_update_center_select_button()
	var grow_to: Vector2 = Vector2(_FOCUS_CARD_SCALE, _FOCUS_CARD_SCALE)
	var tw2: Tween = create_tween()
	_scale_tween = tw2
	tw2.tween_property(_slot_cards[1], "scale", grow_to, _BUMP_GROW_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _entries.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		_bump_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_bump_selection(1)
		get_viewport().set_input_as_handled()


func _on_slot_gui(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_armed = true
			_drag_start_x = event.global_position.x
		else:
			if _drag_armed:
				var dx: float = event.global_position.x - _drag_start_x
				if dx > _swipe_drag_px():
					_bump_selection(-1)
				elif dx < -_swipe_drag_px():
					_bump_selection(1)
				else:
					_on_slot_tap(slot)
			_drag_armed = false


func _on_slot_tap(slot: int) -> void:
	match slot:
		0:
			_bump_selection(-1)
		1:
			pass
		2:
			_bump_selection(1)
