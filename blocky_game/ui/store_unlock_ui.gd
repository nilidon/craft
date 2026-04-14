extends RefCounted
class_name StoreUnlockUi
## Shared “locked” badge + unlock CTA layout for main menu maps and skin carousel (viewport-scaled).

const _CoinsHudBadge = preload("res://blocky_game/gui/coins_hud_badge.gd")
const _COIN_PATH_PRIMARY := "res://blocky_game/coin.png"
const _COIN_PATH_FALLBACK := "res://blocky_game/coin_0.png"

static var _coin_atlas: AtlasTexture


static func viewport_scale(vp: Viewport) -> float:
	if vp == null:
		return 1.0
	var s: Vector2 = vp.get_visible_rect().size
	return clampf(sqrt(s.x * s.y) / 440.0, 0.98, 1.82)


static func coin_atlas() -> AtlasTexture:
	if _coin_atlas != null:
		return _coin_atlas
	var tex: Texture2D = null
	for p: String in [_COIN_PATH_PRIMARY, _COIN_PATH_FALLBACK]:
		if not ResourceLoader.exists(p):
			continue
		var v: Variant = load(p)
		if v is Texture2D:
			tex = v as Texture2D
			break
	if tex == null:
		return null
	var r: Rect2 = _CoinsHudBadge.opaque_pixel_bounds(tex)
	if r.size.x < 1.0 or r.size.y < 1.0:
		r = Rect2(0, 0, float(tex.get_width()), float(tex.get_height()))
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = r
	_coin_atlas = at
	return _coin_atlas


## Gold bar on the [Button]; hold fill + chip use positive z_index so they draw above this bg.
static func apply_coin_chip_hit_target_theme(btn: Button) -> void:
	btn.text = ""
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	var sc: float = _chip_scale_from_btn(btn)
	btn.add_theme_stylebox_override(&"normal", coin_button_face_stylebox(&"normal", sc))
	btn.add_theme_stylebox_override(&"hover", coin_button_face_stylebox(&"hover", sc))
	btn.add_theme_stylebox_override(&"pressed", coin_button_face_stylebox(&"pressed", sc))
	btn.add_theme_stylebox_override(&"disabled", coin_button_face_stylebox(&"normal", sc))
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override(&"focus", empty)


static func _chip_scale_from_btn(btn: Button) -> float:
	return float(btn.get_meta(&"chip_style_scale", 1.0))


## Raised gold “buy” panel — saturated idle color + crisp bevel so it reads alive without interaction.
static func coin_button_face_stylebox(state: StringName, scale: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var rad: int = clampi(int(round(5.0 * scale)), 4, 8)
	sb.set_corner_radius_all(rad)
	## Idle: rich coin gold (avoid muddy brown). Hover/press: brighter / deeper but still warm.
	var base := Color(0.78, 0.52, 0.1, 1.0)
	var rim := Color(1.0, 0.94, 0.58, 0.82)
	var sh_col := Color(0.22, 0.12, 0.04, 0.52)
	match state:
		&"hover":
			base = Color(0.9, 0.64, 0.14, 1.0)
			rim = Color(1.0, 0.97, 0.72, 0.9)
			sh_col = Color(0.18, 0.1, 0.03, 0.45)
		&"pressed":
			base = Color(0.52, 0.34, 0.06, 1.0)
			rim = Color(0.95, 0.82, 0.4, 0.65)
			sh_col = Color(0.12, 0.06, 0.02, 0.55)
		_:
			pass
	sb.bg_color = base
	sb.set_border_width_all(0)
	sb.border_width_top = clampi(int(round(2.0 * scale)), 2, 3)
	sb.border_width_left = sb.border_width_top
	sb.border_width_bottom = clampi(int(round(2.5 * scale)), 2, 4)
	sb.border_width_right = sb.border_width_bottom
	sb.border_color = rim
	sb.shadow_color = sh_col
	if state == &"pressed":
		sb.shadow_size = clampi(int(round(2.0 * scale)), 1, 4)
		sb.shadow_offset = Vector2(0, 1)
	else:
		sb.shadow_size = clampi(int(round(6.0 * scale)), 4, 12)
		sb.shadow_offset = Vector2(0, clampi(int(round(3.0 * scale)), 2, 6))
	sb.anti_aliasing = true
	return sb


static func set_coin_button_face_state(btn: Button, state: StringName) -> void:
	var sc: float = _chip_scale_from_btn(btn)
	var sb: StyleBoxFlat = coin_button_face_stylebox(state, sc)
	var face: Node = btn.get_node_or_null("CoinButtonFace")
	if face is PanelContainer:
		(face as PanelContainer).add_theme_stylebox_override(&"panel", sb)
		return
	## Gold is the Button’s own stylebox — keep all slots in sync for hold / scripted hover.
	btn.add_theme_stylebox_override(&"normal", sb)
	btn.add_theme_stylebox_override(&"hover", sb)
	btn.add_theme_stylebox_override(&"pressed", sb)


static func _free_coin_chip_content_only(btn: Button) -> void:
	var chip: Node = btn.get_node_or_null("CoinChipRoot")
	if chip != null and is_instance_valid(chip):
		chip.free()
	var bg: Node = btn.get_node_or_null("CoinButtonBg")
	if bg != null and is_instance_valid(bg):
		bg.free()
	var face: Node = btn.get_node_or_null("CoinButtonFace")
	if face != null and is_instance_valid(face):
		face.free()


## Coin + price over hold fill over the Button’s gold stylebox (fill/chip z > 0 so they’re not hidden).
static func sync_coin_unlock_chip(btn: Button, price: int, scale: float) -> void:
	btn.set_meta(&"chip_style_scale", scale)
	_free_coin_chip_content_only(btn)
	apply_coin_chip_hit_target_theme(btn)
	var mc := MarginContainer.new()
	mc.name = &"CoinChipRoot"
	mc.z_index = 2
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mg: int = clampi(int(round(2.0 * scale)), 2, 6)
	mc.add_theme_constant_override(&"margin_left", mg)
	mc.add_theme_constant_override(&"margin_top", mg)
	mc.add_theme_constant_override(&"margin_right", mg)
	mc.add_theme_constant_override(&"margin_bottom", mg)
	var row := HBoxContainer.new()
	row.name = &"PriceRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", clampi(int(round(3.5 * scale)), 2, 7))
	var tr := TextureRect.new()
	tr.name = &"CoinTex"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = coin_atlas()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var coin_px: int = clampi(int(round(13.0 * scale)), 11, 20)
	tr.custom_minimum_size = Vector2(coin_px, coin_px)
	var pl := Label.new()
	pl.name = &"PriceLbl"
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pl.text = str(price)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.add_theme_font_size_override(&"font_size", clampi(int(round(16.0 * scale)), 14, 24))
	pl.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.68, 1.0))
	pl.add_theme_color_override(&"font_outline_color", Color(0.35, 0.2, 0.04, 1.0))
	pl.add_theme_constant_override(&"outline_size", clampi(int(round(1.5 * scale)), 1, 3))
	row.add_child(tr)
	row.add_child(pl)
	mc.add_child(row)
	btn.add_child(mc)
	## After bring_progress: fill (z=1) then chip (z=2) above the Button’s drawn bg.
	if btn.has_method(&"bring_progress_to_front"):
		btn.call(&"bring_progress_to_front")
	if btn.has_method(&"configure_hold_layout"):
		btn.call(&"configure_hold_layout", scale)
	if btn.has_method(&"sync_face_after_chip_layout"):
		btn.call(&"sync_face_after_chip_layout")


## Lock badge for previews. `compact` = small corner-style read so portraits (skins) stay visible.
static func make_lock_badge(scale: float, compact: bool = false) -> Control:
	var badge := PanelContainer.new()
	var badge_bg := StyleBoxFlat.new()
	if compact:
		badge_bg.bg_color = Color(0.06, 0.07, 0.1, 0.82)
		badge_bg.set_corner_radius_all(clampi(int(round(6.0 * scale)), 5, 9))
		badge_bg.set_content_margin_all(clampi(int(round(6.0 * scale)), 5, 10))
	else:
		badge_bg.bg_color = Color(0.05, 0.06, 0.09, 0.9)
		badge_bg.set_corner_radius_all(clampi(int(round(10.0 * scale)), 8, 16))
		badge_bg.set_content_margin_all(clampi(int(round(14.0 * scale)), 12, 24))
	badge_bg.set_border_width_all(1)
	badge_bg.border_color = Color(0.62, 0.66, 0.74, 0.55)
	badge.add_theme_stylebox_override(&"panel", badge_bg)
	var v := VBoxContainer.new()
	if compact:
		v.add_theme_constant_override(&"separation", 1)
	else:
		v.add_theme_constant_override(&"separation", clampi(int(round(4.0 * scale)), 2, 8))
	var ic := Label.new()
	ic.text = "🔒"
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ic_sz: int
	var lb_sz: int
	var ol_sz: int
	if compact:
		ic_sz = clampi(int(round(20.0 * scale)), 16, 26)
		lb_sz = clampi(int(round(10.0 * scale)), 9, 13)
		ol_sz = 1
	else:
		ic_sz = clampi(int(round(44.0 * scale)), 34, 72)
		lb_sz = clampi(int(round(19.0 * scale)), 15, 30)
		ol_sz = clampi(int(round(2.0 * scale)), 1, 4)
	ic.add_theme_font_size_override(&"font_size", ic_sz)
	var lb := Label.new()
	lb.text = "LOCKED"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override(&"font_size", lb_sz)
	lb.add_theme_color_override(&"font_color", Color(0.9, 0.92, 0.97, 1.0))
	lb.add_theme_constant_override(&"outline_size", ol_sz)
	lb.add_theme_color_override(&"font_outline_color", Color(0.04, 0.05, 0.08, 1.0))
	v.add_child(ic)
	v.add_child(lb)
	badge.add_child(v)
	return badge
