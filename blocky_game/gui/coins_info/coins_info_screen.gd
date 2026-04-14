extends CanvasLayer
## Coins & challenges: craft-style modal (parchment, wood, gold). Built in code — no separate .tscn.

const PlayerProgress = preload("res://blocky_game/progression/player_progress.gd")

const _DIM := Color(0.05, 0.04, 0.06, 0.62)
const _PARCHMENT := Color(0.96, 0.91, 0.82, 1.0)
const _PARCHMENT_SHADOW := Color(0.82, 0.74, 0.62, 1.0)
const _HEADER_STRIP := Color(0.9, 0.83, 0.72, 1.0)
const _INSET := Color(0.93, 0.87, 0.78, 0.55)
const _CARD_FACE := Color(0.99, 0.96, 0.9, 1.0)
const _WOOD := Color(0.42, 0.3, 0.2, 1.0)
const _WOOD_LINE := Color(0.35, 0.24, 0.16, 0.45)
const _INK := Color(0.2, 0.14, 0.1, 1.0)
const _SUB := Color(0.45, 0.36, 0.28, 1.0)
const _MUTED := Color(0.55, 0.46, 0.38, 1.0)
const _GOLD := Color(0.92, 0.7, 0.22, 1.0)
const _GOLD_DEEP := Color(0.55, 0.38, 0.12, 1.0)
const _GREEN := Color(0.38, 0.72, 0.48, 1.0)
const _GREEN_DEEP := Color(0.22, 0.48, 0.32, 1.0)
const _AMBER_BTN := Color(0.95, 0.78, 0.35, 1.0)
const _AMBER_BTN_EDGE := Color(0.72, 0.52, 0.15, 1.0)
## Fixed width for reward + status column so progress bars and badges line up on every card.
const _CHALLENGE_RAIL_W := 148
## Shared by claim button and status chips so the right rail stacks match a single CLAIM row visually.
const _CHALLENGE_CHIP_H := 38
const _REWARD_BADGE_MIN_H := 30
const _CHALLENGE_RAIL_INNER_SEP := 3
const _CHALLENGE_RAIL_STACK_MIN_H := _REWARD_BADGE_MIN_H + _CHALLENGE_RAIL_INNER_SEP + _CHALLENGE_CHIP_H
## Achievement-only: shorter cards so more rows fit under Builder/Treasure/Veteran tabs.
const _ACH_CARD_RAIL_W := 112
const _ACH_CARD_CHIP_H := 30
const _ACH_CARD_BADGE_MIN_H := 26
const _ACH_CARD_RAIL_SEP := 2
const _ACH_CARD_STACK_MIN_H := _ACH_CARD_BADGE_MIN_H + _ACH_CARD_RAIL_SEP + _ACH_CARD_CHIP_H
## Tab claim badge — same palette as [CoinsPlusButton]: amber disc, dark stroke.
const _CLAIM_PIP_FILL := Color(0.96, 0.55, 0.14, 1.0)
const _CLAIM_PIP_STROKE := Color(0.36, 0.22, 0.08, 0.9)
## Integer layout tokens are reference px at ~720px min viewport side; multiply by [_s] at runtime.
enum _ActionKind { CLAIMED, READY, PROGRESS, UNLOCKED, LOCKED, CAPPED }

const _UI_REF_MIN := 720.0
## Extra multiplier on top of [_ui_scale] for type — body text felt too small at 1:1.
const _FONT_REF_BOOST := 1.2

var _dim: ColorRect
var _shell: Control
var _panel: PanelContainer
var _close_btn: Button
var _title_label: Label
var _header_subtitle: Label
var _body: VBoxContainer
var _nav_btns: Array[Button] = []
var _nav_notify_dots: Array[Control] = []
var _page_index: int = 0
var _bus: Node
var _content_width: int = 0
var _body_min_height: int = 0
var _coin_tex: Texture2D
## Cropped to opaque pixels (same logic as [CoinsHudBadge]) so the coin fills the badge slot.
var _coin_reward_atlas: AtlasTexture = null

var _page_titles: PackedStringArray = []
var _page_builders: Array[Callable] = []

const _DAILY_PAGE_INDEX := 0
const _ACHIEVEMENTS_PAGE_INDEX := 1
const _PASSIVE_PAGE_INDEX := 2
var _passive_live_pb: ProgressBar = null
var _passive_live_next_lbl: Label = null
var _passive_live_count_lbl: Label = null
var _passive_reset_lbl: Label = null
var _passive_seen_date_key: String = ""
var _daily_reset_lbl: Label = null
var _daily_seen_date_key: String = ""
var _achievements_subpage: int = 0
var _achievements_grid: GridContainer = null
var _achievements_subtab_btns: Array[Button] = []
var _main_nav_tab_cells: Array[Control] = []
var _tab_dividers: Array[MarginContainer] = []
var _tab_h_rule: ColorRect = null
var _shell_under: PanelContainer = null
var _header_pc: PanelContainer = null
var _head_col: VBoxContainer = null
var _head_row: MarginContainer = null
var _head_h: HBoxContainer = null
var _sub_wrap: MarginContainer = null
var _content_inset: PanelContainer = null
var _body_pad: MarginContainer = null
var _tab_rail_pc: PanelContainer = null


func _ui_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var m := minf(vp.get_visible_rect().size.x, vp.get_visible_rect().size.y)
	return clampf(m / _UI_REF_MIN, 0.48, 1.75)


func _s(r: float) -> int:
	return maxi(1, int(round(r * _ui_scale())))


func _fs(r: float) -> int:
	return maxi(1, int(round(r * _ui_scale() * _FONT_REF_BOOST)))


func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280, 720)
	return vp.get_visible_rect().size


func _body_height_for_panel(panel_h: int) -> int:
	return maxi(_s(100.0), int(round(float(panel_h) * 0.72)))


func _achievement_columns() -> int:
	return 2 if _viewport_size().x >= 420.0 else 1


func _ready() -> void:
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_coin_tex = _load_coin_texture()
	_coin_reward_atlas = _make_coin_reward_atlas(_coin_tex)

	_page_titles = PackedStringArray([
		"Daily challenges",
		"Achievements",
		"Passive income",
	])
	_page_builders = [
		_make_daily_content,
		_make_achievements_content,
		_make_passive_content,
	]

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = _DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.theme = _make_theme()
	add_child(host)

	_shell = Control.new()
	_shell.clip_contents = false
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(_shell)

	## Same radius as the shell panel: fills AA gaps without a square ColorRect killing rounded corners.
	var shell_under := PanelContainer.new()
	shell_under.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell_under.offset_left = 0.0
	shell_under.offset_top = 0.0
	shell_under.offset_right = 0.0
	shell_under.offset_bottom = 0.0
	shell_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_under.add_theme_stylebox_override(&"panel", _modal_shell_underlay_style())
	_shell.add_child(shell_under)
	_shell_under = shell_under

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 0.0
	_panel.offset_top = 0.0
	_panel.offset_right = 0.0
	_panel.offset_bottom = 0.0
	## Don’t clip: rect clip is square and cuts off rounded shell + drop shadow (looks like a white band).
	_panel.clip_contents = false
	_panel.add_theme_stylebox_override(&"panel", _modal_shell_style())
	_shell.add_child(_panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## No gap between header / tab rail / content row — separation showed as a darker band (transparent controls).
	root.add_theme_constant_override(&"separation", 0)
	_panel.add_child(root)

	var header := PanelContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_theme_stylebox_override(&"panel", _header_bar_style())
	root.add_child(header)
	_header_pc = header

	## PanelContainer fits one child; stack title + subtitle inside the header strip (full width).
	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_theme_constant_override(&"separation", 4)
	header.add_child(head_col)
	_head_col = head_col

	var head_row := MarginContainer.new()
	head_row.add_theme_constant_override(&"margin_left", 16)
	head_row.add_theme_constant_override(&"margin_right", 12)
	head_row.add_theme_constant_override(&"margin_top", 8)
	head_row.add_theme_constant_override(&"margin_bottom", 4)
	head_col.add_child(head_row)
	_head_row = head_row

	var head_h := HBoxContainer.new()
	head_h.add_theme_constant_override(&"separation", 12)
	head_row.add_child(head_h)
	_head_h = head_h

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override(&"font_size", 22)
	_title_label.add_theme_color_override(&"font_color", _INK)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.custom_minimum_size = Vector2(0, 28)
	head_h.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(46, 46)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.flat = true
	_close_btn.add_theme_font_size_override(&"font_size", 22)
	_close_btn.add_theme_color_override(&"font_color", _WOOD)
	_close_btn.add_theme_color_override(&"font_hover_color", _INK)
	_close_btn.add_theme_color_override(&"font_pressed_color", _GOLD_DEEP)
	_style_close_craft(_close_btn)
	_close_btn.pressed.connect(_close)
	head_h.add_child(_close_btn)

	var sub_wrap := MarginContainer.new()
	sub_wrap.add_theme_constant_override(&"margin_left", 16)
	sub_wrap.add_theme_constant_override(&"margin_right", 16)
	sub_wrap.add_theme_constant_override(&"margin_top", 0)
	sub_wrap.add_theme_constant_override(&"margin_bottom", 8)
	head_col.add_child(sub_wrap)
	_sub_wrap = sub_wrap

	_header_subtitle = Label.new()
	_header_subtitle.text = "Earn coins by completing daily challenges, unlocking achievements, collecting gold in your world, and time spent playing."
	_header_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_subtitle.add_theme_font_size_override(&"font_size", 11)
	_header_subtitle.add_theme_color_override(&"font_color", _MUTED)
	sub_wrap.add_child(_header_subtitle)

	var tab_rail := PanelContainer.new()
	tab_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_rail.add_theme_stylebox_override(&"panel", _tab_rail_track_style())
	root.add_child(tab_rail)
	_tab_rail_pc = tab_rail

	var tab_stack := VBoxContainer.new()
	tab_stack.add_theme_constant_override(&"separation", 0)
	tab_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_rail.add_child(tab_stack)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override(&"separation", 0)
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_stack.add_child(tab_row)

	var n_tabs := _page_titles.size()
	for i in n_tabs:
		if i > 0:
			var div_mc := _make_tab_vertical_divider()
			tab_row.add_child(div_mc)
			_tab_dividers.append(div_mc)
		## Wrapper so the badge sits above the tab [Button]; children of [Button] stay under its theme draw.
		var tab_cell := Control.new()
		tab_cell.mouse_filter = Control.MOUSE_FILTER_PASS
		tab_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tab_cell.custom_minimum_size = Vector2(0, 36)
		var b := Button.new()
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.text = _nav_label(i)
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_on_main_nav_tab_pressed.bind(i))
		tab_cell.add_child(b)
		var dot := PanelContainer.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		dot.custom_minimum_size = Vector2(20, 20)
		var dsty := StyleBoxFlat.new()
		dsty.bg_color = _CLAIM_PIP_FILL
		dsty.set_corner_radius_all(10)
		dsty.set_border_width_all(2)
		dsty.border_color = _CLAIM_PIP_STROKE
		dot.add_theme_stylebox_override(&"panel", dsty)
		## Draw above the full-rect tab [Button] so multiple tabs can show pips at once.
		dot.z_index = 1
		tab_cell.add_child(dot)
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.anchor_top = 0.0
		dot.anchor_bottom = 0.0
		dot.offset_left = -23
		dot.offset_right = -3
		dot.offset_top = 2
		dot.offset_bottom = 22
		dot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		dot.grow_vertical = Control.GROW_DIRECTION_END
		tab_row.add_child(tab_cell)
		_main_nav_tab_cells.append(tab_cell)
		_nav_btns.append(b)
		_nav_notify_dots.append(dot)

	var tab_rule := _make_tab_horizontal_rule()
	tab_stack.add_child(tab_rule)
	_tab_h_rule = tab_rule

	var content_col := VBoxContainer.new()
	content_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_col.add_theme_constant_override(&"separation", 0)
	root.add_child(content_col)

	var inset := PanelContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_theme_stylebox_override(&"panel", _content_inset_style())
	content_col.add_child(inset)
	_content_inset = inset

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override(&"margin_left", 10)
	pad.add_theme_constant_override(&"margin_right", 10)
	pad.add_theme_constant_override(&"margin_top", 6)
	pad.add_theme_constant_override(&"margin_bottom", 8)
	inset.add_child(pad)
	_body_pad = pad

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 6)
	pad.add_child(_body)

	_dim.gui_input.connect(_on_dim_gui_input)
	_bus = get_node_or_null("/root/ProgressionBus")
	if _bus != null:
		_bus.coins_changed.connect(_on_coins_changed)
		_bus.daily_challenge_completed.connect(_on_progression_claim_hint)
		_bus.achievement_unlocked.connect(_on_progression_claim_hint)

	if not get_viewport().size_changed.is_connected(_on_coins_modal_viewport_changed):
		get_viewport().size_changed.connect(_on_coins_modal_viewport_changed)
	_relayout_modal_for_viewport()
	_refresh_modal_chrome_layout()
	_select_page(0)
	set_process(false)


func _process(_delta: float) -> void:
	if _page_index == _PASSIVE_PAGE_INDEX:
		_refresh_passive_live_ui()
	if _page_index == _DAILY_PAGE_INDEX:
		_refresh_daily_reset_countdown()


func _nav_label(i: int) -> String:
	match i:
		0:
			return "DAILY"
		1:
			return "ACHIEVEMENTS"
		2:
			return "PASSIVE"
	return "—"


func _tab_separator_line_color() -> Color:
	## One warm ink stroke — readable on parchment, no “double line” from gradients.
	return Color(0.5, 0.36, 0.24, 0.55)


func _make_tab_vertical_divider() -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override(&"margin_left", _s(6.0))
	wrap.add_theme_constant_override(&"margin_right", _s(6.0))
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(maxi(1, _s(1.0)), 0)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = _tab_separator_line_color()
	wrap.add_child(line)
	return wrap


func _make_tab_horizontal_rule() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, maxi(1, _s(1.0)))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = _tab_separator_line_color()
	return line


func _make_theme() -> Theme:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"])
	sf.font_weight = 500
	var th := Theme.new()
	th.default_font = sf
	return th


func _load_coin_texture() -> Texture2D:
	for path in [&"res://blocky_game/coin.png", &"res://blocky_game/coin_0.png"]:
		if ResourceLoader.exists(path):
			var t: Variant = load(path)
			if t is Texture2D:
				return t as Texture2D
	return null


func _make_coin_reward_atlas(tex: Texture2D) -> AtlasTexture:
	if tex == null:
		return null
	var r: Rect2 = CoinsHudBadge.opaque_pixel_bounds(tex)
	if r.size.x < 1.0 or r.size.y < 1.0:
		r = Rect2(0, 0, float(tex.get_width()), float(tex.get_height()))
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2i(
		int(r.position.x),
		int(r.position.y),
		maxi(1, int(r.size.x)),
		maxi(1, int(r.size.y))
	)
	return atlas


func _modal_corner_radius() -> int:
	return _s(22.0)


func _modal_shell_underlay_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = _PARCHMENT
	s.set_corner_radius_all(_modal_corner_radius())
	s.set_border_width_all(0)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	s.shadow_size = 0
	s.shadow_offset = Vector2.ZERO
	return s


func _modal_shell_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = _PARCHMENT
	s.set_corner_radius_all(_modal_corner_radius())
	s.set_border_width_all(maxi(1, _s(2.0)))
	s.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.35)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	s.shadow_size = 0
	s.shadow_offset = Vector2.ZERO
	return s


func _header_bar_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	## Same as modal shell: a darker strip + rounded-corner gaps were showing parchment on the sides.
	s.bg_color = _PARCHMENT
	s.set_corner_radius_all(0)
	s.corner_radius_top_left = _modal_corner_radius()
	s.corner_radius_top_right = _modal_corner_radius()
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.set_border_width_all(0)
	s.border_width_bottom = maxi(1, _s(1.0))
	s.border_color = _WOOD_LINE
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


func _content_inset_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	## Opaque: semi-transparent _INSET blended wrong and read as a light band at the bottom.
	s.bg_color = Color(_INSET.r, _INSET.g, _INSET.b, 1.0)
	s.set_corner_radius_all(0)
	s.corner_radius_bottom_left = maxi(_modal_corner_radius() - _s(4.0), 0)
	s.corner_radius_bottom_right = maxi(_modal_corner_radius() - _s(4.0), 0)
	s.set_border_width_all(0)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


func _style_close_craft(btn: Button) -> void:
	var r := _s(14.0)
	var n := StyleBoxFlat.new()
	n.set_corner_radius_all(r)
	n.bg_color = Color(1, 1, 1, 0.35)
	n.set_border_width_all(maxi(1, _s(2.0)))
	n.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.25)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(1, 0.95, 0.88, 0.75)
	h.border_color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.45)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.92, 0.85, 0.75, 1.0)
	btn.add_theme_stylebox_override(&"normal", n)
	btn.add_theme_stylebox_override(&"hover", h)
	btn.add_theme_stylebox_override(&"pressed", p)


func _tab_rail_track_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	## Opaque parchment + zero side margins: transparent + content_margin exposed shell/inset on the left/right.
	s.bg_color = _PARCHMENT
	s.set_corner_radius_all(0)
	s.set_border_width_all(0)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = _s(2.0)
	s.content_margin_bottom = 0
	return s


func _nav_toolbar_style(selected: bool, hover: bool, pressed: bool) -> StyleBoxFlat:
	## Flat toolbar: three real Buttons, no drop shadows — matches parchment modal, not “floating decks”.
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(_s(8.0))
	s.content_margin_left = _s(10.0)
	s.content_margin_right = _s(10.0)
	s.content_margin_top = _s(8.0)
	s.content_margin_bottom = _s(8.0)
	s.shadow_size = 0
	var bw := maxi(1, _s(1.0))
	if pressed:
		if selected:
			s.bg_color = Color(_HEADER_STRIP.r * 0.94, _HEADER_STRIP.g * 0.94, _HEADER_STRIP.b * 0.94, 1.0)
			s.set_border_width_all(bw)
			s.border_color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.55)
		else:
			s.bg_color = Color(0.88, 0.82, 0.74, 1.0)
			s.set_border_width_all(bw)
			s.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.38)
	elif selected:
		s.bg_color = Color(_HEADER_STRIP.r * 1.03, _HEADER_STRIP.g * 1.03, _HEADER_STRIP.b * 1.03, 1.0) if hover else _HEADER_STRIP
		s.set_border_width_all(bw)
		s.border_color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.55)
	elif hover:
		s.bg_color = Color(1, 1, 1, 0.28)
		s.set_border_width_all(bw)
		s.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.32)
	else:
		s.bg_color = Color(1, 1, 1, 0.14)
		s.set_border_width_all(bw)
		s.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.22)
	return s


func _achievement_subtab_stylebox(selected: bool, hover: bool, pressed: bool) -> StyleBoxFlat:
	## Tight strip under the main tabs — avoids eating height from the achievement grid like [method _nav_toolbar_style] does.
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(_s(5.0))
	s.content_margin_left = _s(5.0)
	s.content_margin_right = _s(5.0)
	s.content_margin_top = _s(2.0)
	s.content_margin_bottom = _s(2.0)
	s.shadow_size = 0
	var bw := maxi(1, _s(1.0))
	if pressed:
		if selected:
			s.bg_color = Color(_HEADER_STRIP.r * 0.95, _HEADER_STRIP.g * 0.95, _HEADER_STRIP.b * 0.95, 1.0)
			s.set_border_width_all(bw)
			s.border_color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.45)
		else:
			s.bg_color = Color(0.9, 0.84, 0.76, 1.0)
			s.set_border_width_all(bw)
			s.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.35)
	elif selected:
		s.bg_color = Color(_HEADER_STRIP.r * 1.02, _HEADER_STRIP.g * 1.02, _HEADER_STRIP.b * 1.02, 1.0) if hover else _HEADER_STRIP
		s.set_border_width_all(bw)
		s.border_color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.5)
	elif hover:
		s.bg_color = Color(1, 1, 1, 0.22)
		s.set_border_width_all(bw)
		s.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.28)
	else:
		s.bg_color = Color(1, 1, 1, 0.09)
		s.set_border_width_all(bw)
		s.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.16)
	return s


func _apply_all_nav_styles() -> void:
	for i in _nav_btns.size():
		_apply_nav_style(_nav_btns[i], i == _page_index)


func _apply_nav_style(btn: Button, selected: bool) -> void:
	btn.add_theme_stylebox_override(&"normal", _nav_toolbar_style(selected, false, false))
	btn.add_theme_stylebox_override(&"hover", _nav_toolbar_style(selected, true, false))
	btn.add_theme_stylebox_override(&"pressed", _nav_toolbar_style(selected, false, true))
	btn.add_theme_color_override(&"font_color", _INK if selected else _SUB)
	btn.add_theme_font_size_override(&"font_size", clampi(_fs(14.0), 12, 26))
	btn.custom_minimum_size = Vector2(0, _s(36.0))


func _on_main_nav_tab_pressed(i: int) -> void:
	if i != _page_index:
		GameAudio.play_ui_button()
	_select_page(i)


func _select_page(i: int) -> void:
	_passive_clear_live_refs()
	_page_index = clampi(i, 0, _page_builders.size() - 1)
	_title_label.text = _page_titles[_page_index]
	_apply_all_nav_styles()
	for c in _body.get_children():
		c.queue_free()
	var cb: Callable = _page_builders[_page_index]
	cb.call(_body)
	_sync_passive_process()
	_refresh_nav_claim_dots()


func _on_progression_claim_hint(_a = null, _b = null, _c = null) -> void:
	if visible:
		_refresh_nav_claim_dots()


func _nav_tab_has_claimable(tab_idx: int, f: Dictionary) -> bool:
	## Each tab is independent — daily + achievements can both show a pip at the same time.
	match tab_idx:
		_DAILY_PAGE_INDEX:
			return bool(f.get(&"daily", false))
		_ACHIEVEMENTS_PAGE_INDEX:
			return bool(f.get(&"achievements", false))
		_:
			return false


func _refresh_nav_claim_dots() -> void:
	var f: Dictionary = PlayerProgress.claimable_reward_flags()
	for i in _nav_notify_dots.size():
		_nav_notify_dots[i].visible = _nav_tab_has_claimable(i, f)


func _passive_clear_live_refs() -> void:
	_passive_live_pb = null
	_passive_live_next_lbl = null
	_passive_live_count_lbl = null
	_passive_reset_lbl = null
	_passive_seen_date_key = ""
	_daily_reset_lbl = null
	_daily_seen_date_key = ""
	set_process(false)


func _sync_passive_process() -> void:
	var run := false
	if (
		visible
		and _page_index == _PASSIVE_PAGE_INDEX
		and (
			(
				_passive_live_next_lbl != null
				and is_instance_valid(_passive_live_next_lbl)
			)
			or (
				_passive_reset_lbl != null
				and is_instance_valid(_passive_reset_lbl)
			)
		)
	):
		run = true
	if (
		visible
		and _page_index == _DAILY_PAGE_INDEX
		and _daily_reset_lbl != null
		and is_instance_valid(_daily_reset_lbl)
	):
		run = true
	set_process(run)


func _compact_duration_hms(total_sec: int) -> String:
	var h := total_sec / 3600
	var m := (total_sec % 3600) / 60
	var s := total_sec % 60
	var parts: PackedStringArray = []
	if h > 0:
		parts.append("%dh" % h)
	if m > 0:
		parts.append("%dm" % m)
	if s > 0 or parts.is_empty():
		parts.append("%ds" % s)
	return " ".join(parts)


func _daily_reset_countdown_phrase(total_sec: int) -> String:
	return "CHALLENGES RESET IN %s" % _compact_duration_hms(total_sec)


func _passive_limit_reset_countdown_phrase(total_sec: int) -> String:
	return "PASSIVE LIMIT RESETS IN %s" % _compact_duration_hms(total_sec)


func _refresh_daily_reset_countdown() -> void:
	if _daily_reset_lbl == null or not is_instance_valid(_daily_reset_lbl):
		_sync_passive_process()
		return
	var tk := DailyChallengesCatalog.today_key()
	if not _daily_seen_date_key.is_empty() and tk != _daily_seen_date_key:
		_daily_seen_date_key = tk
		_select_page(_DAILY_PAGE_INDEX)
		return
	var sec := DailyChallengesCatalog.seconds_until_local_midnight()
	_daily_reset_lbl.text = _daily_reset_countdown_phrase(sec)


func _passive_next_coin_phrase(sec_left: int) -> String:
	var unit := "second" if sec_left == 1 else "seconds"
	return "Next coin in %d %s." % [sec_left, unit]


func _refresh_passive_live_ui() -> void:
	if _passive_reset_lbl != null and is_instance_valid(_passive_reset_lbl):
		var tk := DailyChallengesCatalog.today_key()
		if not _passive_seen_date_key.is_empty() and tk != _passive_seen_date_key:
			_passive_seen_date_key = tk
			_select_page(_PASSIVE_PAGE_INDEX)
			return
		var mid_sec := DailyChallengesCatalog.seconds_until_local_midnight()
		_passive_reset_lbl.text = _passive_limit_reset_countdown_phrase(mid_sec)

	if _passive_live_next_lbl == null or not is_instance_valid(_passive_live_next_lbl):
		_sync_passive_process()
		return
	var snap: Dictionary = PlayerProgress.get_coins_ui_snapshot()
	var units: int = int(snap.get(&"passive_units_today", 0))
	var acc: float = float(snap.get(&"passive_acc_sec", 0.0))
	var cap: int = int(PlayerProgress.MAX_PASSIVE_COINS_PER_DAY)
	var per: float = float(PlayerProgress.PASSIVE_SEC_PER_COIN)
	if units >= cap:
		if _passive_live_next_lbl != null:
			_select_page(_PASSIVE_PAGE_INDEX)
		return
	if _passive_live_pb != null and is_instance_valid(_passive_live_pb):
		_passive_live_pb.value = clampf(acc / per, 0.0, 1.0)
	var sec_left: int = ceili(maxf(0.0, per - acc))
	_passive_live_next_lbl.text = _passive_next_coin_phrase(sec_left)
	if _passive_live_count_lbl != null and is_instance_valid(_passive_live_count_lbl):
		if cap == 1:
			_passive_live_count_lbl.text = "%d / 1 passive coin" % units
		else:
			_passive_live_count_lbl.text = "%d / %d passive coins" % [units, cap]


func _challenge_card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = _CARD_FACE
	s.set_corner_radius_all(_s(16.0))
	s.set_border_width_all(maxi(1, _s(2.0)))
	s.border_color = Color(_PARCHMENT_SHADOW.r, _PARCHMENT_SHADOW.g, _PARCHMENT_SHADOW.b, 0.85)
	s.content_margin_left = _s(14.0)
	s.content_margin_right = _s(14.0)
	s.content_margin_top = _s(12.0)
	s.content_margin_bottom = _s(12.0)
	s.shadow_size = 0
	return s


func _challenge_card_style_compact() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = _CARD_FACE
	s.set_corner_radius_all(_s(12.0))
	s.set_border_width_all(maxi(1, _s(1.0)))
	s.border_color = Color(_PARCHMENT_SHADOW.r, _PARCHMENT_SHADOW.g, _PARCHMENT_SHADOW.b, 0.7)
	s.content_margin_left = _s(9.0)
	s.content_margin_right = _s(9.0)
	s.content_margin_top = _s(7.0)
	s.content_margin_bottom = _s(7.0)
	s.shadow_size = 0
	return s


func _reward_badge(amount: int, compact: bool = false) -> PanelContainer:
	var rail_w := _s(float(_ACH_CARD_RAIL_W if compact else _CHALLENGE_RAIL_W))
	var badge_h := _s(float(_ACH_CARD_BADGE_MIN_H if compact else _REWARD_BADGE_MIN_H))
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.custom_minimum_size = Vector2(rail_w, badge_h)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.98, 0.9, 0.65, 1.0)
	st.set_corner_radius_all(_s(7.0 if compact else 9.0))
	st.set_border_width_all(maxi(1, _s(1.0 if compact else 2.0)))
	st.border_color = Color(_GOLD_DEEP.r, _GOLD_DEEP.g, _GOLD_DEEP.b, 0.55)
	st.content_margin_left = _s(4.0 if compact else 6.0)
	st.content_margin_right = _s(4.0 if compact else 6.0)
	st.content_margin_top = _s(3.0 if compact else 4.0)
	st.content_margin_bottom = _s(3.0 if compact else 4.0)
	st.shadow_size = 0
	p.add_theme_stylebox_override(&"panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", _s(3.0 if compact else 4.0))
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	var disp: Texture2D = _coin_reward_atlas if _coin_reward_atlas != null else _coin_tex
	if disp != null:
		## EXPAND_KEEP_SIZE ties minimum size to texture resolution; EXPAND_IGNORE_SIZE respects the fixed slot below.
		var coin_slot := _s(16.0 if compact else 18.0)
		var slot := Control.new()
		slot.clip_contents = true
		slot.custom_minimum_size = Vector2(coin_slot, coin_slot)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tr := TextureRect.new()
		tr.texture = disp
		tr.ignore_texture_size = true
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(tr)
		h.add_child(slot)
	var v := Label.new()
	v.text = str(amount)
	v.add_theme_font_size_override(&"font_size", clampi(_fs(15.0), 12, 26))
	v.add_theme_color_override(&"font_color", _GOLD_DEEP)
	h.add_child(v)
	return p


func _action_chip_style(kind: _ActionKind) -> Dictionary:
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(_s(10.0))
	st.content_margin_left = _s(8.0)
	st.content_margin_right = _s(8.0)
	st.content_margin_top = _s(5.0)
	st.content_margin_bottom = _s(5.0)
	var txt := ""
	var fg := Color.WHITE
	var bw2 := maxi(1, _s(2.0))
	var bw1 := maxi(1, _s(1.0))
	match kind:
		_ActionKind.CLAIMED, _ActionKind.UNLOCKED:
			txt = "COLLECTED" if kind == _ActionKind.CLAIMED else "  Unlocked  "
			st.bg_color = Color(_GREEN.r, _GREEN.g, _GREEN.b, 0.22)
			st.set_border_width_all(bw2)
			st.border_color = Color(_GREEN_DEEP.r, _GREEN_DEEP.g, _GREEN_DEEP.b, 0.45)
			fg = _GREEN_DEEP
		_ActionKind.READY:
			txt = "  CLAIM PRIZE  "
			st.bg_color = _AMBER_BTN
			st.set_border_width_all(bw2)
			st.border_color = _AMBER_BTN_EDGE
			fg = Color(0.35, 0.22, 0.08, 1.0)
			st.shadow_size = 0
		_ActionKind.PROGRESS:
			txt = "IN PROGRESS"
			st.bg_color = Color(1, 1, 1, 0.4)
			st.set_border_width_all(bw2)
			st.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.18)
			fg = _MUTED
		_ActionKind.LOCKED:
			txt = "  Locked  "
			st.bg_color = Color(0.88, 0.84, 0.78, 0.6)
			st.set_border_width_all(bw1)
			st.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.12)
			fg = _MUTED
		_ActionKind.CAPPED:
			txt = "  Full for today  "
			st.bg_color = Color(0.9, 0.86, 0.78, 0.75)
			st.set_border_width_all(bw2)
			st.border_color = Color(_WOOD.r, _WOOD.g, _WOOD.b, 0.22)
			fg = _SUB
	return {&"style": st, &"text": txt, &"fg": fg}


func _action_chip(kind: _ActionKind, compact: bool = false) -> PanelContainer:
	var d: Dictionary = _action_chip_style(kind)
	var rail_w := _s(float(_ACH_CARD_RAIL_W if compact else _CHALLENGE_RAIL_W))
	var chip_h := _s(float(_ACH_CARD_CHIP_H if compact else _CHALLENGE_CHIP_H))
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.custom_minimum_size = Vector2(rail_w, chip_h)
	var st: StyleBoxFlat = (d[&"style"] as StyleBoxFlat).duplicate() as StyleBoxFlat
	if compact:
		st.content_margin_left = maxi(_s(4.0), st.content_margin_left - _s(2.0))
		st.content_margin_right = maxi(_s(4.0), st.content_margin_right - _s(2.0))
		st.content_margin_top = maxi(_s(3.0), st.content_margin_top - _s(1.0))
		st.content_margin_bottom = maxi(_s(3.0), st.content_margin_bottom - _s(1.0))
		st.set_corner_radius_all(_s(8.0))
	p.add_theme_stylebox_override(&"panel", st)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(cc)
	var lb := Label.new()
	lb.text = str(d[&"text"]).strip_edges()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override(
		&"font_size", clampi(_fs(9.0 if compact else 11.0), 10, 22)
	)
	lb.add_theme_color_override(&"font_color", d[&"fg"] as Color)
	cc.add_child(lb)
	return p


func _action_chip_or_collect_button(kind: _ActionKind, claim_cb: Callable, compact: bool = false) -> Control:
	var chip_h := _s(float(_ACH_CARD_CHIP_H if compact else _CHALLENGE_CHIP_H))
	if kind == _ActionKind.READY and claim_cb.is_valid():
		var d: Dictionary = _action_chip_style(_ActionKind.READY)
		var st: StyleBoxFlat = (d[&"style"] as StyleBoxFlat).duplicate() as StyleBoxFlat
		if compact:
			st.content_margin_left = _s(10.0)
			st.content_margin_right = _s(10.0)
			st.content_margin_top = _s(4.0)
			st.content_margin_bottom = _s(4.0)
			st.set_corner_radius_all(_s(8.0))
		else:
			st.content_margin_left = _s(14.0)
			st.content_margin_right = _s(14.0)
			st.content_margin_top = _s(6.0)
			st.content_margin_bottom = _s(6.0)
			st.set_corner_radius_all(_s(10.0))
		var fg: Color = d[&"fg"] as Color
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = str(d[&"text"]).strip_edges()
		btn.flat = false
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(0, chip_h)
		btn.add_theme_font_size_override(
			&"font_size", clampi(_fs(12.0 if compact else 15.0), 11, 28)
		)
		btn.add_theme_color_override(&"font_color", fg)
		btn.add_theme_color_override(&"font_hover_color", fg.darkened(0.08))
		btn.add_theme_color_override(&"font_pressed_color", fg.darkened(0.15))
		btn.add_theme_stylebox_override(&"normal", st)
		var hov := st.duplicate() as StyleBoxFlat
		hov.bg_color = hov.bg_color.lightened(0.06)
		btn.add_theme_stylebox_override(&"hover", hov)
		var pr := st.duplicate() as StyleBoxFlat
		pr.bg_color = pr.bg_color.darkened(0.04)
		btn.add_theme_stylebox_override(&"pressed", pr)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(claim_cb)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return btn
	return _action_chip(kind, compact)


func _craft_progress_bar(pb: ProgressBar, filled: bool) -> void:
	var cr := _s(5.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.75, 0.68, 0.58, 0.45)
	bg.set_corner_radius_all(cr)
	var fl := StyleBoxFlat.new()
	fl.bg_color = Color(_GREEN.r, _GREEN.g, _GREEN.b, 0.9) if filled else Color(0.62, 0.55, 0.48, 1.0)
	fl.set_corner_radius_all(cr)
	pb.add_theme_stylebox_override(&"background", bg)
	pb.add_theme_stylebox_override(&"fill", fl)


func _action_kind(
	daily_claimed: bool,
	goal_done: bool,
	achievement_mode: bool,
	ach_milestone_met: bool,
	ach_reward_claimed: bool,
	cur: int,
	goal: int
) -> _ActionKind:
	if achievement_mode:
		if ach_reward_claimed:
			return _ActionKind.CLAIMED
		if ach_milestone_met:
			return _ActionKind.READY
		if goal > 0:
			return _ActionKind.PROGRESS
		return _ActionKind.LOCKED
	if daily_claimed:
		return _ActionKind.CLAIMED
	if goal_done:
		return _ActionKind.READY
	return _ActionKind.PROGRESS


func _challenge_card(
	into: Container,
	title: String,
	desc: String,
	cur: int,
	goal: int,
	reward: int,
	daily_claimed: bool,
	achievement_mode: bool,
	ach_milestone_met: bool,
	ach_reward_claimed: bool,
	claim_cb: Callable = Callable(),
	progress_caption: String = "",
	daily_dual: bool = false,
	dual_cur2: int = 0,
	dual_goal2: int = 0,
	compact: bool = false
) -> void:
	var goal_done: bool
	if daily_dual:
		goal_done = goal > 0 and dual_goal2 > 0 and cur >= goal and dual_cur2 >= dual_goal2
	else:
		goal_done = goal > 0 and cur >= goal
	var filled := (ach_reward_claimed or ach_milestone_met) if achievement_mode else (daily_claimed or goal_done)
	var rail_w := _s(float(_ACH_CARD_RAIL_W if compact else _CHALLENGE_RAIL_W))
	var rail_sep := _s(float(_ACH_CARD_RAIL_SEP if compact else _CHALLENGE_RAIL_INNER_SEP))
	var stack_min_h := _s(float(_ACH_CARD_STACK_MIN_H if compact else _CHALLENGE_RAIL_STACK_MIN_H))
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Stretch with grid row height so slack below the challenge list fills the modal.
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override(
		&"panel", _challenge_card_style_compact() if compact else _challenge_card_style()
	)
	into.add_child(wrap)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", _s(3.0 if compact else 4.0))
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(outer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", _s(5.0 if compact else 6.0))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var left_top := Control.new()
	left_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(left_top)
	var left_inner := VBoxContainer.new()
	left_inner.add_theme_constant_override(&"separation", _s(2.0 if compact else 3.0))
	left_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_inner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.add_child(left_inner)
	var left_bot := Control.new()
	left_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(left_bot)

	var tl := Label.new()
	tl.text = title
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_theme_font_size_override(
		&"font_size", clampi(_fs(14.0 if compact else 17.0), 13, 30)
	)
	tl.add_theme_color_override(&"font_color", _INK)
	if compact:
		tl.max_lines_visible = 2
	left_inner.add_child(tl)

	var dl := Label.new()
	dl.text = desc
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.add_theme_font_size_override(
		&"font_size", clampi(_fs(10.0 if compact else 12.0), 10, 22)
	)
	dl.add_theme_color_override(&"font_color", _SUB)
	if compact:
		dl.max_lines_visible = 2
	left_inner.add_child(dl)

	var prog_row := HBoxContainer.new()
	prog_row.add_theme_constant_override(&"separation", _s(5.0 if compact else 8.0))
	prog_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_inner.add_child(prog_row)
	var prog_l := Label.new()
	if daily_dual and goal > 0 and dual_goal2 > 0:
		prog_l.text = "Blocks %d/%d · Types %d/%d" % [mini(cur, goal), goal, mini(dual_cur2, dual_goal2), dual_goal2]
	elif not progress_caption.is_empty():
		prog_l.text = progress_caption
	elif goal > 0:
		prog_l.text = "%d / %d" % [mini(cur, goal), goal]
	else:
		prog_l.text = ""
	prog_l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prog_l.add_theme_font_size_override(
		&"font_size", clampi(_fs(10.0 if compact else 11.0), 10, 20)
	)
	prog_l.add_theme_color_override(&"font_color", _MUTED)
	prog_row.add_child(prog_l)
	var pb := ProgressBar.new()
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.min_value = 0.0
	pb.max_value = 1.0
	if filled:
		pb.value = 1.0
	elif daily_dual and goal > 0 and dual_goal2 > 0:
		pb.value = minf(
			clampf(float(cur) / float(goal), 0.0, 1.0),
			clampf(float(dual_cur2) / float(dual_goal2), 0.0, 1.0)
		)
	else:
		pb.value = clampf(float(cur) / float(maxi(goal, 1)), 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, _s(5.0 if compact else 8.0))
	_craft_progress_bar(pb, filled)
	prog_row.add_child(pb)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(rail_w, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var ak := _action_kind(
		daily_claimed, goal_done, achievement_mode, ach_milestone_met, ach_reward_claimed, cur, goal
	)
	var rail_top := Control.new()
	rail_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rail_top)
	var rail_inner := VBoxContainer.new()
	rail_inner.add_theme_constant_override(&"separation", rail_sep)
	rail_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_inner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rail_inner.custom_minimum_size.x = rail_w
	right.add_child(rail_inner)
	if ak == _ActionKind.READY:
		## Same min height as [badge]+[chip]; flex spacers center vertically. [CenterContainer] shrinks the button to text width.
		var ready_shell := PanelContainer.new()
		ready_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ready_shell.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		ready_shell.custom_minimum_size = Vector2(rail_w, stack_min_h)
		ready_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ready_shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var ready_col := VBoxContainer.new()
		ready_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ready_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ready_shell.add_child(ready_col)
		var ready_sp_top := Control.new()
		ready_sp_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ready_sp_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ready_col.add_child(ready_sp_top)
		var claim_btn: Control = _action_chip_or_collect_button(ak, claim_cb, compact)
		claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ready_col.add_child(claim_btn)
		var ready_sp_bot := Control.new()
		ready_sp_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ready_sp_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ready_col.add_child(ready_sp_bot)
		rail_inner.add_child(ready_shell)
	else:
		rail_inner.add_child(_reward_badge(reward, compact))
		rail_inner.add_child(_action_chip_or_collect_button(ak, claim_cb, compact))
	var rail_bot := Control.new()
	rail_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rail_bot)


func _info_card(into: Container, heading: String, body: String, fill_vertical: bool = false) -> void:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fill_vertical:
		wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override(&"panel", _challenge_card_style())
	into.add_child(wrap)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", _s(4.0))
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fill_vertical:
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(vb)
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override(&"font_size", clampi(_fs(16.0), 14, 30))
	h.add_theme_color_override(&"font_color", _INK)
	vb.add_child(h)
	var p := Label.new()
	p.text = body
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_font_size_override(&"font_size", clampi(_fs(13.0), 12, 24))
	p.add_theme_color_override(&"font_color", _SUB)
	vb.add_child(p)
	if fill_vertical:
		var sp := Control.new()
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(sp)


func _claim_daily_challenge(cid: String) -> void:
	if PlayerProgress.claim_daily_challenge(cid):
		GameAudio.play_purchase_unlock_success()
		_select_page(_page_index)


func _claim_achievement_reward(aid: String) -> void:
	if PlayerProgress.claim_achievement_reward(aid):
		GameAudio.play_purchase_unlock_success()
		_select_page(_page_index)


func _on_coins_changed(_v: int) -> void:
	if visible:
		_select_page(_page_index)


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_relayout_modal_for_viewport()
	_refresh_modal_chrome_layout()
	_page_index = clampi(_page_index, 0, _page_builders.size() - 1)
	visible = true
	_select_page(_page_index)


func _close() -> void:
	visible = false
	_sync_passive_process()


func _layout_shell_centered(w: int, h: int) -> void:
	## Size comes from offsets on _shell; min size matches so tab content cannot shrink the frame.
	var wf := float(w)
	var hf := float(h)
	_shell.custom_minimum_size = Vector2(wf, hf)
	_shell.anchor_left = 0.5
	_shell.anchor_right = 0.5
	_shell.anchor_top = 0.5
	_shell.anchor_bottom = 0.5
	_shell.offset_left = -wf * 0.5
	_shell.offset_right = wf * 0.5
	_shell.offset_top = -hf * 0.5
	_shell.offset_bottom = hf * 0.5


func _relayout_modal_for_viewport() -> void:
	if _panel == null or _shell == null:
		return
	var vs := _viewport_size()
	var vw := vs.x
	var vh := vs.y
	var panel_w := int(round(clampf(vw * 0.92, vw * 0.02, vw * 0.98)))
	var panel_h := int(round(clampf(vh * 0.90, vh * 0.02, vh * 0.96)))
	_panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_layout_shell_centered(panel_w, panel_h)
	_content_width = maxi(_s(64.0), panel_w - _s(40.0))
	_body_min_height = _body_height_for_panel(panel_h)
	if _body != null:
		_body.custom_minimum_size = Vector2(_content_width, _body_min_height)


func _refresh_modal_chrome_layout() -> void:
	if is_instance_valid(_shell_under):
		_shell_under.add_theme_stylebox_override(&"panel", _modal_shell_underlay_style())
	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override(&"panel", _modal_shell_style())
	if is_instance_valid(_header_pc):
		_header_pc.add_theme_stylebox_override(&"panel", _header_bar_style())
	if is_instance_valid(_tab_rail_pc):
		_tab_rail_pc.add_theme_stylebox_override(&"panel", _tab_rail_track_style())
	if is_instance_valid(_content_inset):
		_content_inset.add_theme_stylebox_override(&"panel", _content_inset_style())
	if is_instance_valid(_head_col):
		_head_col.add_theme_constant_override(&"separation", _s(4.0))
	if is_instance_valid(_head_row):
		_head_row.add_theme_constant_override(&"margin_left", _s(16.0))
		_head_row.add_theme_constant_override(&"margin_right", _s(12.0))
		_head_row.add_theme_constant_override(&"margin_top", _s(8.0))
		_head_row.add_theme_constant_override(&"margin_bottom", _s(4.0))
	if is_instance_valid(_head_h):
		_head_h.add_theme_constant_override(&"separation", _s(12.0))
	if is_instance_valid(_title_label):
		_title_label.add_theme_font_size_override(&"font_size", clampi(_fs(22.0), 17, 40))
		_title_label.custom_minimum_size = Vector2(0, _s(32.0))
	if is_instance_valid(_close_btn):
		var cs := _s(46.0)
		_close_btn.custom_minimum_size = Vector2(cs, cs)
		_close_btn.add_theme_font_size_override(&"font_size", clampi(_fs(22.0), 17, 34))
		_style_close_craft(_close_btn)
	if is_instance_valid(_sub_wrap):
		_sub_wrap.add_theme_constant_override(&"margin_left", _s(16.0))
		_sub_wrap.add_theme_constant_override(&"margin_right", _s(16.0))
		_sub_wrap.add_theme_constant_override(&"margin_top", 0)
		_sub_wrap.add_theme_constant_override(&"margin_bottom", _s(8.0))
	if is_instance_valid(_header_subtitle):
		_header_subtitle.add_theme_font_size_override(&"font_size", clampi(_fs(11.0), 11, 20))
	for cell in _main_nav_tab_cells:
		if is_instance_valid(cell):
			cell.custom_minimum_size = Vector2(0, _s(36.0))
	var dot_sz := _s(20.0)
	var off_l := -_s(23.0)
	var off_r := -_s(3.0)
	var off_t := _s(2.0)
	var off_b := _s(22.0)
	for dot in _nav_notify_dots:
		if not is_instance_valid(dot):
			continue
		dot.custom_minimum_size = Vector2(dot_sz, dot_sz)
		dot.offset_left = float(off_l)
		dot.offset_right = float(off_r)
		dot.offset_top = float(off_t)
		dot.offset_bottom = float(off_b)
		var dsty := StyleBoxFlat.new()
		dsty.bg_color = _CLAIM_PIP_FILL
		dsty.set_corner_radius_all(_s(10.0))
		dsty.set_border_width_all(maxi(1, _s(2.0)))
		dsty.border_color = _CLAIM_PIP_STROKE
		if dot is PanelContainer:
			(dot as PanelContainer).add_theme_stylebox_override(&"panel", dsty)
	for div in _tab_dividers:
		if not is_instance_valid(div):
			continue
		div.add_theme_constant_override(&"margin_left", _s(6.0))
		div.add_theme_constant_override(&"margin_right", _s(6.0))
		if div.get_child_count() > 0:
			var cr := div.get_child(0) as ColorRect
			if cr != null:
				cr.custom_minimum_size = Vector2(maxi(1, _s(1.0)), 0)
	if is_instance_valid(_tab_h_rule):
		_tab_h_rule.custom_minimum_size = Vector2(0, maxi(1, _s(1.0)))
	if is_instance_valid(_body_pad):
		_body_pad.add_theme_constant_override(&"margin_left", _s(10.0))
		_body_pad.add_theme_constant_override(&"margin_right", _s(10.0))
		_body_pad.add_theme_constant_override(&"margin_top", _s(6.0))
		_body_pad.add_theme_constant_override(&"margin_bottom", _s(8.0))
	if is_instance_valid(_body):
		_body.add_theme_constant_override(&"separation", _s(6.0))


func _on_coins_modal_viewport_changed() -> void:
	if not is_instance_valid(self):
		return
	if not visible:
		return
	_relayout_modal_for_viewport()
	_refresh_modal_chrome_layout()
	_select_page(_page_index)


func _make_challenge_grid_parent(
	into: VBoxContainer, column_count: int = 2, expand_vertical: bool = true
) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = column_count
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## When [param expand_vertical] is false, the grid stays short (legacy / compact layouts).
	grid.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL if expand_vertical else Control.SIZE_SHRINK_BEGIN
	)
	grid.add_theme_constant_override(&"h_separation", _s(6.0))
	grid.add_theme_constant_override(&"v_separation", _s(6.0))
	into.add_child(grid)
	return grid


func _make_daily_content(into: VBoxContainer) -> void:
	var reset_l := Label.new()
	reset_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_l.add_theme_font_size_override(&"font_size", clampi(_fs(13.0), 12, 24))
	reset_l.add_theme_color_override(&"font_color", _MUTED)
	reset_l.text = _daily_reset_countdown_phrase(DailyChallengesCatalog.seconds_until_local_midnight())
	into.add_child(reset_l)
	_daily_reset_lbl = reset_l
	_daily_seen_date_key = DailyChallengesCatalog.today_key()
	_sync_passive_process()

	var snap: Dictionary = PlayerProgress.get_coins_ui_snapshot()
	var claimed: Dictionary = snap.get(&"claimed_daily", {}) as Dictionary
	var blocks_today: int = int(snap.get(&"blocks_today", 0))
	var broken_today: int = int(snap.get(&"blocks_broken_today", 0))
	var coins_today: int = int(snap.get(&"coins_picked_today", 0))
	var play_today: int = int(floor(float(snap.get(&"play_seconds_today", 0.0))))
	var types_n: int = int(snap.get(&"types_today_count", 0))
	var grid := _make_challenge_grid_parent(into, 1, false)
	for ch in DailyChallengesCatalog.active_today():
		var cid: String = str(ch.get(&"id", ""))
		var title: String = str(ch.get(&"title", cid))
		var desc: String = str(ch.get(&"description", ""))
		var reward := int(ch.get(&"reward", 0))
		var kind: String = str(ch.get(&"kind", ""))
		var is_claimed := claimed.has(cid)
		var goal := int(ch.get(&"goal", 0))
		var cur := 0
		var cap := ""
		var dual := false
		var d_cur := 0
		var d_goal := 0
		match kind:
			"blocks_placed":
				cur = blocks_today
			"distinct_blocks":
				cur = types_n
			"coins_picked_today":
				cur = coins_today
			"play_seconds_today":
				cur = play_today
				var gm := goal / 60
				cap = "%dm / %dm" % [mini(cur / 60, gm), gm]
			"blocks_broken_today":
				cur = broken_today
			"blocks_and_types":
				dual = true
				cur = blocks_today
				goal = int(ch.get(&"goal_blocks", 0))
				d_cur = types_n
				d_goal = int(ch.get(&"goal_types", 0))
		if dual:
			_challenge_card(
				grid, title, desc, cur, goal, reward, is_claimed, false, false, false,
				_claim_daily_challenge.bind(cid), "", true, d_cur, d_goal
			)
		else:
			_challenge_card(
				grid, title, desc, cur, goal, reward, is_claimed, false, false, false,
				_claim_daily_challenge.bind(cid), cap
			)


func _ach_goal_val(aid: String) -> int:
	match aid:
		"first_block":
			return 1
		"blocks_150":
			return 150
		"blocks_500":
			return 500
		"blocks_1000":
			return 1000
		"blocks_2000":
			return 2000
		"blocks_5000":
			return 5000
		"blocks_7500":
			return 7500
		"blocks_10000":
			return 10000
		"coin_finder_5":
			return 5
		"coin_finder_20":
			return 20
		"coin_finder_50":
			return 50
		"coin_finder_100":
			return 100
		"coin_finder_250":
			return 250
		"coin_finder_500":
			return 500
		"coin_finder_750":
			return 750
		"coin_finder_1000":
			return 1000
		"playtime_10m":
			return 600
		"playtime_45m":
			return 2700
		"playtime_3h":
			return 10800
		"playtime_10h":
			return 36000
		"playtime_25h":
			return 90000
		"breaker_500":
			return 500
		"breaker_1000":
			return 1000
		"breaker_2500":
			return 2500
	return 1


func _fmt_ach_playtime_hm(sec: int) -> String:
	sec = maxi(0, sec)
	var h: int = sec / 3600
	var m: int = (sec % 3600) / 60
	if m == 0:
		return "%dh" % h
	if h == 0:
		return "0h %dm" % m
	return "%dh %dm" % [h, m]


func _fmt_ach_playtime_minutes_only(sec: int) -> String:
	sec = maxi(0, sec)
	return "%dm" % (sec / 60)


func _ach_playtime_progress_caption(aid: String, cur_sec: int, goal_sec: int) -> String:
	var cur_c := mini(cur_sec, goal_sec)
	match aid:
		"playtime_10m", "playtime_45m":
			return "%s / %s" % [_fmt_ach_playtime_minutes_only(cur_c), _fmt_ach_playtime_minutes_only(goal_sec)]
		_:
			return "%s / %s" % [_fmt_ach_playtime_hm(cur_c), _fmt_ach_playtime_hm(goal_sec)]


func _ach_cur_val(aid: String, snap: Dictionary) -> int:
	var lb: int = int(snap.get(&"lifetime_blocks", 0))
	var lbb: int = int(snap.get(&"lifetime_blocks_broken", 0))
	var pk: int = int(snap.get(&"lifetime_pickups", 0))
	var ps: float = float(snap.get(&"lifetime_play_sec", 0.0))
	match aid:
		"first_block", "blocks_150", "blocks_500", "blocks_1000", "blocks_2000", "blocks_5000", "blocks_7500", "blocks_10000":
			return lb
		"coin_finder_5", "coin_finder_20", "coin_finder_50", "coin_finder_100", "coin_finder_250", "coin_finder_500", "coin_finder_750", "coin_finder_1000":
			return pk
		"playtime_10m", "playtime_45m", "playtime_3h", "playtime_10h", "playtime_25h":
			return int(ps)
		"breaker_500", "breaker_1000", "breaker_2500":
			return lbb
	return 0


func _apply_achievement_subtab_styles() -> void:
	for i in _achievements_subtab_btns.size():
		var b: Button = _achievements_subtab_btns[i]
		if not is_instance_valid(b):
			continue
		var sel := i == _achievements_subpage
		b.add_theme_stylebox_override(&"normal", _achievement_subtab_stylebox(sel, false, false))
		b.add_theme_stylebox_override(&"hover", _achievement_subtab_stylebox(sel, true, false))
		b.add_theme_stylebox_override(&"pressed", _achievement_subtab_stylebox(sel, false, true))
		b.add_theme_color_override(&"font_color", _INK if sel else _SUB)
		b.add_theme_font_size_override(&"font_size", clampi(_fs(11.0), 10, 20))
		b.custom_minimum_size = Vector2.ZERO


func _on_achievements_subtab_pressed(p: int) -> void:
	if _achievements_subpage == p:
		return
	GameAudio.play_ui_button()
	_achievements_subpage = p
	_apply_achievement_subtab_styles()
	_fill_achievements_grid()


func _fill_achievements_grid() -> void:
	if _achievements_grid == null or not is_instance_valid(_achievements_grid):
		return
	while _achievements_grid.get_child_count() > 0:
		var c: Node = _achievements_grid.get_child(0)
		_achievements_grid.remove_child(c)
		c.free()
	var snap: Dictionary = PlayerProgress.get_coins_ui_snapshot()
	var unlocked: Dictionary = snap.get(&"ach_unlocked", {}) as Dictionary
	var reward_claimed: Dictionary = snap.get(&"ach_reward_claimed", {}) as Dictionary
	for row in AchievementsCatalog.rows_for_page(_achievements_subpage):
		var aid: String = str(row.get(&"id", ""))
		var title: String = str(row.get(&"title", aid))
		var desc: String = str(row.get(&"description", ""))
		var reward := int(row.get(&"reward", 0))
		var milestone := unlocked.has(aid)
		var collected := reward_claimed.has(aid)
		var g := _ach_goal_val(aid)
		var c := _ach_cur_val(aid, snap)
		var prog_cap := ""
		if aid.begins_with("playtime_") and g > 0:
			prog_cap = _ach_playtime_progress_caption(aid, c, g)
		## Same card scale as Daily challenges — compact mode was only for tiny panels; larger modal keeps proportions.
		_challenge_card(
			_achievements_grid,
			title,
			desc,
			c,
			g,
			reward,
			false,
			true,
			milestone,
			collected,
			_claim_achievement_reward.bind(aid),
			prog_cap
		)


func _make_achievements_content(into: VBoxContainer) -> void:
	_achievements_grid = null
	_achievements_subpage = clampi(_achievements_subpage, 0, AchievementsCatalog.page_count() - 1)
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override(&"separation", _s(4.0))
	sub_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	into.add_child(sub_row)
	_achievements_subtab_btns.clear()
	for p in AchievementsCatalog.page_count():
		var b := Button.new()
		b.text = AchievementsCatalog.page_title(p)
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_achievements_subtab_pressed.bind(p))
		sub_row.add_child(b)
		_achievements_subtab_btns.append(b)
	_apply_achievement_subtab_styles()
	_achievements_grid = _make_challenge_grid_parent(into, _achievement_columns(), true)
	_fill_achievements_grid()


func _fmt_time(sec: float) -> String:
	var s := int(sec)
	var h := s / 3600
	s %= 3600
	var m := s / 60
	s %= 60
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm %ds" % [m, s]


func _coins_phrase(n: int) -> String:
	if n == 1:
		return "1 coin"
	return "%d coins" % n


func _make_passive_content(into: VBoxContainer) -> void:
	var p_reset := Label.new()
	p_reset.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_reset.add_theme_font_size_override(&"font_size", clampi(_fs(13.0), 12, 24))
	p_reset.add_theme_color_override(&"font_color", _MUTED)
	p_reset.text = _passive_limit_reset_countdown_phrase(
		DailyChallengesCatalog.seconds_until_local_midnight()
	)
	into.add_child(p_reset)
	_passive_reset_lbl = p_reset
	_passive_seen_date_key = DailyChallengesCatalog.today_key()

	var snap: Dictionary = PlayerProgress.get_coins_ui_snapshot()
	var units: int = int(snap.get(&"passive_units_today", 0))
	var acc: float = float(snap.get(&"passive_acc_sec", 0.0))
	var life: float = float(snap.get(&"lifetime_play_sec", 0.0))
	var per := float(PlayerProgress.PASSIVE_SEC_PER_COIN)
	var cap := int(PlayerProgress.MAX_PASSIVE_COINS_PER_DAY)
	var val := int(PlayerProgress.PASSIVE_COIN_VALUE)
	var per_tick := _coins_phrase(val)
	var how := (
		"Every %.0f seconds in a running world you earn %s, up to %d times per day. "
		+ "The daily limit resets with the countdown above."
	) % [per, per_tick, cap]
	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_theme_constant_override(&"separation", _s(6.0))
	into.add_child(top)
	_info_card(top, "How it works", how, false)
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrap.add_theme_stylebox_override(&"panel", _challenge_card_style())
	top.add_child(wrap)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", _s(6.0))
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrap.add_child(vb)
	var t2 := Label.new()
	t2.text = "Today"
	t2.add_theme_font_size_override(&"font_size", clampi(_fs(16.0), 14, 30))
	t2.add_theme_color_override(&"font_color", _INK)
	vb.add_child(t2)
	var st := Label.new()
	if cap == 1:
		st.text = "%d / 1 passive coin" % units
	else:
		st.text = "%d / %d passive coins" % [units, cap]
	st.add_theme_font_size_override(&"font_size", clampi(_fs(14.0), 12, 26))
	st.add_theme_color_override(&"font_color", _GOLD_DEEP)
	vb.add_child(st)
	if units < cap:
		var pb := ProgressBar.new()
		pb.min_value = 0.0
		pb.max_value = 1.0
		pb.value = clampf(acc / per, 0.0, 1.0)
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, _s(6.0))
		_craft_progress_bar(pb, false)
		vb.add_child(pb)
		var tm := Label.new()
		var sec0 := ceili(maxf(0.0, per - acc))
		tm.text = _passive_next_coin_phrase(sec0)
		tm.add_theme_font_size_override(&"font_size", clampi(_fs(12.0), 11, 22))
		tm.add_theme_color_override(&"font_color", _MUTED)
		vb.add_child(tm)
		vb.add_child(_action_chip(_ActionKind.PROGRESS))
		_passive_live_pb = pb
		_passive_live_next_lbl = tm
		_passive_live_count_lbl = st
	else:
		var cap_l := Label.new()
		cap_l.text = "Daily cap reached — more tomorrow."
		cap_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap_l.add_theme_font_size_override(&"font_size", clampi(_fs(13.0), 12, 24))
		cap_l.add_theme_color_override(&"font_color", _SUB)
		vb.add_child(cap_l)
		vb.add_child(_action_chip(_ActionKind.CAPPED))
	_info_card(into, "Lifetime play time", _fmt_time(life) + " across worlds, total.")
