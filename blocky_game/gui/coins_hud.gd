extends CanvasLayer
class_name CoinsHud
## Coins HUD: icon + count + info button. [enum CoinsHudCorner.TOP_LEFT] in-game; menus use [enum CoinsHudCorner.TOP_RIGHT].

enum CoinsHudCorner { TOP_LEFT, TOP_RIGHT }

const PlayerProgress = preload("res://blocky_game/progression/player_progress.gd")
const CoinsInfoScreen = preload("res://blocky_game/gui/coins_info/coins_info_screen.gd")

const _COIN_TEXTURE_CANDIDATES: PackedStringArray = [
	"res://blocky_game/coin.png",
	"res://blocky_game/coin_0.png",
]

const _REF_SHORT := 720.0
## Base min size for [CoinsHudBadge]; keep in sync with badge design constants.
const _BADGE_DESIGN := Vector2(120.0, 78.0)

## Full-viewport IGNORE shell so this CanvasLayer never presents a stray STOP rect to the root GUI
## (Android + CanvasLayer children has had hit-test quirks when only an HBox sits on the layer).
var _input_passthrough: Control
var _row: HBoxContainer
var _badge: CoinsHudBadge
var _plus: CoinsPlusButton
var _info_screen: CanvasLayer
var _corner: CoinsHudCorner = CoinsHudCorner.TOP_LEFT


func _ready() -> void:
	## Above [DDD] debug CanvasLayer (100) so the HUD stays visible in dev builds on device.
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_input_passthrough = Control.new()
	_input_passthrough.name = "HudInputPassthrough"
	_input_passthrough.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_passthrough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_input_passthrough)

	_row = HBoxContainer.new()
	_row.name = "HudRow"
	_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_input_passthrough.add_child(_row)
	if not _row.resized.is_connected(_on_hud_row_resized):
		_row.resized.connect(_on_hud_row_resized)

	_badge = CoinsHudBadge.new()
	_badge.name = "CoinsHudBadge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.set_coin_texture(_resolve_coin_texture())
	_row.add_child(_badge)

	_plus = CoinsPlusButton.new()
	_plus.name = "CoinsInfoButton"
	_plus.mouse_filter = Control.MOUSE_FILTER_STOP
	_plus.pressed.connect(_on_coins_info_pressed)
	_row.add_child(_plus)

	_info_screen = CoinsInfoScreen.new()
	_info_screen.name = "CoinsInfoScreen_%d" % get_instance_id()
	add_child(_info_screen)
	## Nested CanvasLayer under another CanvasLayer can mis-route or block root GUI input on some devices;
	## keep the modal on the scene root so the menu layer stack stays normal.
	call_deferred("_reparent_coins_info_to_root")

	_apply_layout()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_apply_layout)
	var bus: Node = get_node_or_null("/root/ProgressionBus")
	if bus != null:
		bus.coins_changed.connect(_on_coins_changed)
		bus.daily_challenge_completed.connect(_on_progression_claim_hint)
		bus.achievement_unlocked.connect(_on_progression_claim_hint)
	_refresh_amount(PlayerProgress.get_coins())
	_refresh_claim_notifications()
	call_deferred("_sync_row_position")


func _reparent_coins_info_to_root() -> void:
	if _info_screen == null or not is_instance_valid(_info_screen):
		return
	var rt := get_tree().root
	if rt == null:
		return
	if _info_screen.get_parent() == self:
		rt.add_child(_info_screen)


func set_corner(corner: CoinsHudCorner) -> void:
	_corner = corner
	if is_node_ready():
		call_deferred("_sync_row_position")


func _resolve_coin_texture() -> Texture2D:
	for path in _COIN_TEXTURE_CANDIDATES:
		if ResourceLoader.exists(path):
			var t := load(path)
			if t is Texture2D:
				return t as Texture2D
	return null


func _on_hud_row_resized() -> void:
	call_deferred("_sync_row_position")


func _layout_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	# Wider clamp so small phones / large tablets don’t look identical to 720p reference.
	return clampf(minf(vp.get_visible_rect().size.x, vp.get_visible_rect().size.y) / _REF_SHORT, 0.68, 1.38)


func _on_coins_info_pressed() -> void:
	GameAudio.play_ui_button()
	if _info_screen != null and _info_screen.has_method(&"open"):
		_info_screen.open()


func _apply_layout() -> void:
	if _badge == null or _row == null:
		return
	var sc := _layout_scale()
	# Room for stroked coin + larger count text ([CoinsHudBadge] has no frame).
	_badge.custom_minimum_size = Vector2(
		int(round(_BADGE_DESIGN.x * sc)),
		int(round(_BADGE_DESIGN.y * sc))
	)
	if _plus != null:
		var ph := int(round(minf(50.0 * sc, _BADGE_DESIGN.y * sc)))
		_plus.custom_minimum_size = Vector2(ph, ph)
	_row.add_theme_constant_override(&"separation", 0)
	call_deferred("_sync_row_position")


func _sync_row_position() -> void:
	if _row == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vr: Rect2 = vp.get_visible_rect()
	var ins := UiSafeMargins.insets_for_viewport(vp)
	var sc := _layout_scale()
	var top := 12.0 * sc + float(ins.y)
	if _corner == CoinsHudCorner.TOP_LEFT:
		_row.position = Vector2(14.0 * sc + float(ins.x), vr.position.y + top)
	else:
		var margin_r := 14.0 * sc + float(ins.z)
		_row.position = Vector2(
			vr.position.x + maxf(0.0, vr.size.x - margin_r - _row.size.x),
			vr.position.y + top
		)


func _on_coins_changed(v: int) -> void:
	_refresh_amount(v)
	_refresh_claim_notifications()
	call_deferred("_sync_row_position")


func _on_progression_claim_hint(_a = null, _b = null, _c = null) -> void:
	_refresh_claim_notifications()


func _refresh_claim_notifications() -> void:
	if _plus == null:
		return
	var f: Dictionary = PlayerProgress.claimable_reward_flags()
	_plus.set_show_claim_notification(bool(f.get(&"any", false)))


func _refresh_amount(v: int) -> void:
	if _badge != null:
		_badge.set_amount_text(_format_count(v))


func _format_count(v: int) -> String:
	var neg := v < 0
	var u := str(absi(v))
	var tail := ""
	while u.length() > 3:
		tail = "," + u.right(3) + tail
		u = u.left(u.length() - 3)
	if not u.is_empty():
		tail = u + tail
	return ("-" if neg else "") + tail
