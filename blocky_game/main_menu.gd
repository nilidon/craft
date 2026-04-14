extends Control

const NetworkAddress = preload("./network_address.gd")
const RoomCodeSignalingSettings = preload("./room_code_signaling_settings.gd")
const WorldPaths = preload("./world_paths.gd")
const WorldCatalog = preload("./world_catalog.gd")
const WorldMeta = preload("./world_meta.gd")
const PlayerProgress = preload("res://blocky_game/progression/player_progress.gd")
const StoreUnlockUi = preload("res://blocky_game/ui/store_unlock_ui.gd")
const HoldCoinUnlockButton = preload("res://blocky_game/ui/hold_coin_unlock_button.gd")
const _WorldsPreviewCornerOverlay = preload("res://blocky_game/ui/worlds_preview_corner_overlay.gd")
## Match `_map_card_style` / `_world_card_style` panel `bg_color` (corners sit on card fill).
const _MAP_CARD_PREVIEW_CORNER_FILL := Color(0.08, 0.1, 0.14, 0.9)
const _SAVE_CARD_PREVIEW_CORNER_FILL := Color(0.09, 0.11, 0.16, 0.94)

const SETTINGS_PATH := "user://blocky_player_settings.cfg"
const SETTINGS_SECTION := "progress"
const KEY_LAST_WORLD := "last_world_slug"

## Menu button textures are 1200×200; height/width for layout scaling.
const _MENU_BTN_ASPECT := 200.0 / 1200.0
## Must match MainButtons VBox separation in main.tscn (4 gaps between 5 buttons).
const _MENU_BTN_STACK_SEP := 14
const _SETTINGS_DIM_MENU := Color(0.02, 0.04, 0.09, 0.65)
## Must match `pause_menu.tscn` root `Dim` so settings-from-pause matches the pause overlay.
const _SETTINGS_DIM_OVER_GAME := Color(0.02, 0.04, 0.08, 0.72)
## Short shop flash when a coin purchase fails; must match character carousel emit string.
const COIN_WARN_TEXT := "NOT ENOUGH COINS!"

var _coin_warn_timer: Timer

@onready var _menu_background: TextureRect = $Background
@onready var _settings_dim: ColorRect = $SettingsMenuLayer/SettingsOverlay/Dim
@onready var _worlds_menu_dim: ColorRect = $MenuRoot/WorldsMenuDim
@onready var _screen_center: Control = $MenuRoot/ScreenCenter
@onready var _main_margin: MarginContainer = $MenuRoot/ScreenCenter/MarginContainer
@onready var _screen_main: Control = $MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/ScreenMain
@onready var _screen_worlds: Control = $MenuRoot/ScreenWorlds
@onready var _worlds_back_button: TextureButton = $MenuRoot/ScreenWorlds/WorldsBackButton
@onready var _worlds_vbox: VBoxContainer = $MenuRoot/ScreenWorlds/WorldsVBox
@onready var _worlds_header_band: Control = $MenuRoot/ScreenWorlds/WorldsVBox/WorldsHeaderBand
@onready var _screen_skins: Control = $MenuRoot/ScreenSkins
@onready var _character_carousel: Node = $MenuRoot/ScreenSkins/SkinsVBox/SkinsCarouselMargin/CharacterSelectCarousel
@onready var _screen_multiplayer: Control = $MenuRoot/ScreenMultiplayer
@onready var _settings_overlay: Control = $SettingsMenuLayer/SettingsOverlay
@onready var _settings_panel: PanelContainer = $SettingsMenuLayer/SettingsOverlay/Center/Panel
@onready var _message: Label = $MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/MessageLabel
@onready var _worlds_message: Label = $MenuRoot/ScreenWorlds/WorldsMessageLabel
@onready var _skins_shop_message: Label = $MenuRoot/ScreenSkins/SkinsVBox/SkinsShopMessageSlot/SkinsShopMessageLabel
@onready var _settings_button: TextureButton = $SettingsButton
@onready var _shadows_option_row: PanelContainer = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/ShadowsOptionRow
@onready var _camera_person_option_row: PanelContainer = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/CameraPersonOptionRow
@onready var _invert_option_row: PanelContainer = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/InvertOptionRow
@onready var _settings_shadows: CheckBox = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/ShadowsOptionRow/HBox/TerrainShadowsCheck
@onready var _settings_fov_slider: HSlider = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/FovRow/FovSlider
@onready var _settings_fov_value: Label = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/FovRow/FovValue
@onready var _settings_third_person: CheckBox = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/CameraPersonOptionRow/HBox/ThirdPersonCheck
@onready var _settings_volume_slider: HSlider = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/VolRow/MasterVolumeSlider
@onready var _settings_vol_value: Label = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/VolRow/VolValue
@onready var _settings_sens_slider: HSlider = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/SensRow/MouseSensSlider
@onready var _settings_sens_value: Label = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/SensRow/SensValue
@onready var _settings_invert_look: CheckBox = \
	$SettingsMenuLayer/SettingsOverlay/Center/Panel/Margin/VBox/InvertOptionRow/HBox/InvertLookCheck
@onready var _game_title: Label = $MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/ScreenMain/GameTitle
@onready var _worlds_title: Label = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsHeaderBand/WorldsTitleCenter/WorldsTitle
@onready var _multi_title: Label = $MenuRoot/ScreenMultiplayer/MultiOuter/MultiOuterVBox/MultiTitleRow/MultiTitle
@onready var _multi_subtitle: Label = $MenuRoot/ScreenMultiplayer/MultiOuter/MultiOuterVBox/MultiSubtitle

@onready var _multi_host_popup: Control = $MenuRoot/ScreenMultiplayer/MultiHostPopup
@onready var _multi_join_popup: Control = $MenuRoot/ScreenMultiplayer/MultiJoinPopup
@onready var _host_popup_dim: ColorRect = $MenuRoot/ScreenMultiplayer/MultiHostPopup/HostPopupDim
@onready var _join_popup_dim: ColorRect = $MenuRoot/ScreenMultiplayer/MultiJoinPopup/JoinPopupDim
@onready var _join_room_code_edit: LineEdit = \
	$MenuRoot/ScreenMultiplayer/MultiJoinPopup/JoinPopupCenter/JoinPopupPanel/JoinMargin/JoinVBox/JoinRoomCode
@onready var _host_room_code_edit: LineEdit = \
	$MenuRoot/ScreenMultiplayer/MultiHostPopup/HostPopupCenter/HostPopupPanel/HostMargin/HostVBox/HostRoomCode
@onready var _host_feedback_label: Label = \
	$MenuRoot/ScreenMultiplayer/MultiHostPopup/HostPopupCenter/HostPopupPanel/HostMargin/HostVBox/HostFeedbackLabel
@onready var _join_feedback_label: Label = \
	$MenuRoot/ScreenMultiplayer/MultiJoinPopup/JoinPopupCenter/JoinPopupPanel/JoinMargin/JoinVBox/JoinFeedbackLabel
@onready var _host_world_label: Label = \
	$MenuRoot/ScreenMultiplayer/MultiHostPopup/HostPopupCenter/HostPopupPanel/HostMargin/HostVBox/HostWorldLabel
@onready var _multiplayer_message: Label = \
	$MenuRoot/ScreenMultiplayer/MultiOuter/MultiOuterVBox/MultiMessageLabel
@onready var _connect_server_button: Button = \
	$MenuRoot/ScreenMultiplayer/MultiJoinPopup/JoinPopupCenter/JoinPopupPanel/JoinMargin/JoinVBox/ConnectToServerButton
@onready var _host_server_button: Button = \
	$MenuRoot/ScreenMultiplayer/MultiHostPopup/HostPopupCenter/HostPopupPanel/HostMargin/HostVBox/HostServerButton
@onready var _world_cards_row: HFlowContainer = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/SavedWorldsSection/SavedVBox/WorldScroll/WorldScrollGutter/WorldCardsRow
@onready var _world_search_edit: LineEdit = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/SavedWorldsSection/SavedVBox/WorldSearchEdit
@onready var _world_scroll: ScrollContainer = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/SavedWorldsSection/SavedVBox/WorldScroll
@onready var _world_empty_hint: Label = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/SavedWorldsSection/SavedVBox/WorldEmptyHint
@onready var _map_cards_row: VBoxContainer = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/NewWorldSection/NewVBox/MapScroll/MapScrollGutter/MapCardsRow
@onready var _worlds_map_scroll: ScrollContainer = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/NewWorldSection/NewVBox/MapScroll
@onready var _new_world_edit: LineEdit = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/NewWorldSection/NewVBox/NewWorldEdit
@onready var _play_world_button: Button = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/SavedWorldsSection/SavedVBox/SavedActionsRow/PlayWorldButton
@onready var _delete_world_button: Button = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/SavedWorldsSection/SavedVBox/SavedActionsRow/DeleteWorldButton
@onready var _create_play_button: Button = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/NewWorldSection/NewVBox/CreatePlayButton
@onready var _worlds_tab_segment: PanelContainer = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabLeftColumn/WorldsTabSegment
@onready var _tab_saved_worlds_btn: Button = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabLeftColumn/WorldsTabSegment/TabSegmentMargin/TabSegmentRow/TabSavedWorldsButton
@onready var _tab_new_world_btn: Button = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabLeftColumn/WorldsTabSegment/TabSegmentMargin/TabSegmentRow/TabNewWorldButton
@onready var _saved_worlds_section_panel: PanelContainer = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/SavedWorldsSection
@onready var _new_world_section_panel: PanelContainer = \
	$MenuRoot/ScreenWorlds/WorldsVBox/WorldsTabBody/WorldsTabContent/NewWorldSection

@onready var _menu_texture_buttons: Array[TextureButton] = [
	$MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/ScreenMain/MainButtons/PlayButton,
	$MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/ScreenMain/MainButtons/WorldsButton,
	$MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/ScreenMain/MainButtons/SkinsButton,
	$MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/ScreenMain/MainButtons/MultiplayerToggle,
	$MenuRoot/ScreenCenter/MarginContainer/VBoxRoot/ScreenMain/MainButtons/QuitButton,
]

@onready var _multiplayer_launch_texture_buttons: Array[TextureButton] = [
	$MenuRoot/ScreenMultiplayer/MultiLaunchCenter/MultiLaunchVBox/MultiHostLaunchButton,
	$MenuRoot/ScreenMultiplayer/MultiLaunchCenter/MultiLaunchVBox/MultiJoinLaunchButton,
]

var _settings_back_to_worlds := false
var _settings_back_to_multiplayer := false
var _settings_from_pause := false
var _ui_selected_world_slug := ""
var _creation_map_id_choice: String = WorldCatalog.MAP_GRASSLAND
var _delete_world_dialog: ConfirmationDialog
var _pending_delete_slug: String = ""
var _map_card_panels: Dictionary = {}
## Filled in _refit_main_menu_layout — 16:9 thumbs for terrain list + save rows.
var _worlds_new_map_preview_size: Vector2 = Vector2(152, 85)
var _worlds_save_preview_size: Vector2 = Vector2(128, 72)

const _WORLDS_TAB_SAVED := 0
const _WORLDS_TAB_NEW := 1
var _worlds_tab: int = _WORLDS_TAB_SAVED

var _signaling_http: HTTPRequest = null
var _join_lookup_pending := false

signal singleplayer_requested(world_slug: String)
signal connect_to_server_requested(ip: String, port: int)
signal host_server_requested(room_code: String, port: int, world_slug: String)

var _menu_coins_hud: CoinsHud = null


func set_menu_coins_hud(hud: Variant) -> void:
	_menu_coins_hud = hud as CoinsHud
	_sync_menu_coins_hud()


func _sync_menu_coins_hud() -> void:
	if _menu_coins_hud == null:
		return
	if not visible:
		return
	## Hide only for pause→settings; main-menu settings uses [SettingsMenuLayer] above [MenuCoinsHud] so the dim covers the HUD.
	if is_settings_overlay_open() and _settings_from_pause:
		_menu_coins_hud.visible = false
		return
	_menu_coins_hud.visible = true
	if _screen_multiplayer != null and _screen_multiplayer.visible:
		_menu_coins_hud.set_corner(CoinsHud.CoinsHudCorner.TOP_RIGHT)
	elif _screen_skins != null and _screen_skins.visible:
		_menu_coins_hud.set_corner(CoinsHud.CoinsHudCorner.TOP_RIGHT)
	elif _screen_worlds != null and _screen_worlds.visible:
		_menu_coins_hud.set_corner(CoinsHud.CoinsHudCorner.TOP_RIGHT)
	else:
		_menu_coins_hud.set_corner(CoinsHud.CoinsHudCorner.TOP_LEFT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_refit_main_menu_layout")


func _wire_menu_texture_and_button_audio(n: Node) -> void:
	for c in n.get_children():
		if c is TextureButton:
			_wire_one_shot_button_audio(c as BaseButton)
		elif c is Button and not (c is CheckBox):
			_wire_one_shot_button_audio(c as BaseButton)
		_wire_menu_texture_and_button_audio(c)


func _wire_one_shot_button_audio(b: BaseButton) -> void:
	if b.has_meta(&"cc_ui_audio"):
		return
	b.set_meta(&"cc_ui_audio", true)
	b.pressed.connect(func() -> void:
		GameAudio.play_ui_button())


func _ready() -> void:
	_setup_delete_world_dialog()
	PlayerSettings.repair_skin_path_if_locked_in_file()
	if _character_carousel != null:
		if not _character_carousel.shop_message.is_connected(_on_skin_shop_message):
			_character_carousel.shop_message.connect(_on_skin_shop_message)
	_coin_warn_timer = Timer.new()
	_coin_warn_timer.one_shot = true
	_coin_warn_timer.wait_time = 3.0
	_coin_warn_timer.timeout.connect(_on_coin_warn_timer_timeout)
	add_child(_coin_warn_timer)
	## Float above content so “NOT ENOUGH COINS!” does not steal [WorldsVBox] height from scroll rows.
	if _worlds_message != null and _screen_worlds != null and _worlds_vbox != null:
		if _worlds_message.get_parent() == _worlds_vbox:
			_screen_worlds.add_child(_worlds_message)
		_worlds_message.z_index = 2
		_worlds_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## After first frame so imported textures are registered; avoids blank map previews.
	call_deferred("_build_map_type_cards")
	_show_main_screen()
	_repopulate_world_list()
	_wire_settings_toggle_rows()
	_apply_worlds_tab()
	_apply_worlds_action_button_styles()
	_apply_multiplayer_action_button_styles()
	_wire_multiplayer_popup_dims()
	_wire_menu_texture_and_button_audio(self)
	call_deferred("_refit_main_menu_layout")


func _refit_main_menu_layout() -> void:
	var vis := get_viewport().get_visible_rect().size
	var vw := vis.x
	var vh := vis.y
	if vw < 1.0 or vh < 1.0:
		return
	var ins := UiSafeMargins.insets_for_viewport(get_viewport())
	var cw := maxf(80.0, vw - float(ins.x + ins.z))
	var ch := maxf(80.0, vh - float(ins.y + ins.w))
	if _main_margin != null:
		_main_margin.add_theme_constant_override(&"margin_left", 24 + ins.x)
		_main_margin.add_theme_constant_override(&"margin_top", 20 + ins.y)
		_main_margin.add_theme_constant_override(&"margin_right", 24 + ins.z)
		_main_margin.add_theme_constant_override(&"margin_bottom", 20 + ins.w)
	## Full-screen overlay roots (_settings_overlay, _screen_*) stay scene default full-rect; safe-area is
	## only applied on [_main_margin] so stretch + manual offsets cannot desync draw vs input on mobile.
	var worlds_edge := clampf(cw * 0.016, 10.0, 22.0)
	## Match legacy 150×100 minimum; scale up on wide screens (same aspect as menu art).
	var back_w := clampf(cw * 0.112, 150.0, 200.0)
	var back_h_for_layout := clampf(back_w * (100.0 / 150.0), 100.0, 136.0)
	if _worlds_back_button != null:
		_worlds_back_button.offset_left = worlds_edge
		_worlds_back_button.offset_top = worlds_edge
		_worlds_back_button.offset_right = worlds_edge + back_w
		_worlds_back_button.offset_bottom = worlds_edge + back_h_for_layout
	if _worlds_vbox != null:
		var wm := clampf(cw * 0.014, 6.0, 20.0)
		_worlds_vbox.offset_left = wm
		_worlds_vbox.offset_right = -wm
		_worlds_vbox.offset_top = worlds_edge
		_worlds_vbox.offset_bottom = -clampf(ch * 0.012, 8.0, 18.0)
	if _worlds_header_band != null:
		const worlds_v_sep := 10
		var h_band := clampi(int(round(clampf(ch * 0.088, 50.0, 88.0))), 46, 94)
		var min_clear := int(ceil(back_h_for_layout)) - worlds_v_sep
		if min_clear > h_band:
			h_band = min_clear
		_worlds_header_band.custom_minimum_size.y = float(h_band)
	if _worlds_title != null:
		var w_title_px := clampi(int(round(cw * 0.038)), 32, 58)
		_worlds_title.add_theme_font_size_override(&"font_size", w_title_px)
		_worlds_title.add_theme_constant_override(&"outline_size", clampi(int(round(float(w_title_px) / 8.0)), 4, 9))
	## Worlds: terrain = vertical list (thumb left, text right); saves unchanged.
	var map_thumb_w := clampi(int(round(cw * 0.17)), 118, 172)
	var map_thumb_h := int(round(float(map_thumb_w) * 9.0 / 16.0))
	_worlds_new_map_preview_size = Vector2(map_thumb_w, map_thumb_h)
	var save_thumb_w := clampi(int(round(cw * 0.13)), 108, 152)
	_worlds_save_preview_size = Vector2(save_thumb_w, int(round(float(save_thumb_w) * 9.0 / 16.0)))
	if _world_scroll != null:
		_world_scroll.custom_minimum_size.x = 0
		_world_scroll.custom_minimum_size.y = clampi(int(round(ch * 0.17 + 96.0)), 120, 280)
	if _world_cards_row != null:
		_world_cards_row.custom_minimum_size.x = 0
	if _worlds_map_scroll != null:
		_worlds_map_scroll.custom_minimum_size.y = clampi(int(round(ch * 0.22 + 104.0)), 150, 300)
	_apply_worlds_preview_layout_sizes()
	var w_rail_tab_h := clampi(int(round(30.0 + ch * 0.028)), 32, 42)
	var w_rail_w := float(clampi(int(round(cw * 0.11)), 132, 196))
	if _worlds_tab_segment != null:
		_worlds_tab_segment.custom_minimum_size.x = w_rail_w
	if _tab_saved_worlds_btn != null:
		_tab_saved_worlds_btn.custom_minimum_size.y = w_rail_tab_h
	if _tab_new_world_btn != null:
		_tab_new_world_btn.custom_minimum_size.y = w_rail_tab_h
	var w_line_h := clampi(int(round(30.0 + ch * 0.034)), 32, 46)
	if _world_search_edit != null:
		_world_search_edit.custom_minimum_size.y = w_line_h
		_world_search_edit.add_theme_font_size_override(&"font_size", clampi(int(round(cw * 0.014)), 13, 18))
	if _new_world_edit != null:
		_new_world_edit.custom_minimum_size.y = w_line_h
		_new_world_edit.add_theme_font_size_override(&"font_size", clampi(int(round(cw * 0.014)), 13, 18))
	var w_act_h := clampi(int(round(36.0 + ch * 0.038)), 40, 54)
	if _play_world_button != null:
		_play_world_button.custom_minimum_size.y = w_act_h
	if _delete_world_button != null:
		_delete_world_button.custom_minimum_size.y = w_act_h
	if _create_play_button != null:
		_create_play_button.custom_minimum_size.y = clampi(int(round(38.0 + ch * 0.04)), 42, 56)
	_apply_worlds_tab()
	if _settings_button != null:
		var side := float(clampi(int(round(cw * 0.042)), 44, 76))
		_settings_button.custom_minimum_size = Vector2(side, side)
		## Cap safe inset so a bad [DisplayServer] safe rect cannot shove the control off-screen.
		var pad_r := 12.0 + minf(float(ins.z), minf(40.0, vw * 0.035))
		var pad_t := 12.0 + minf(float(ins.y), minf(36.0, vh * 0.06))
		_settings_button.offset_left = -side - pad_r
		_settings_button.offset_top = pad_t
		_settings_button.offset_right = -pad_r
		_settings_button.offset_bottom = pad_t + side
	if _settings_panel != null:
		var pw := clampf(cw * 0.44, 260.0, minf(560.0, cw * 0.94))
		_settings_panel.custom_minimum_size.x = pw
	if _multi_title != null:
		var m_title_px := clampi(int(round(cw * 0.042)), 34, 76)
		_multi_title.add_theme_font_size_override(&"font_size", m_title_px)
		_multi_title.add_theme_constant_override(&"outline_size", clampi(int(round(float(m_title_px) / 10.0)), 4, 10))
		_multi_title.custom_minimum_size.x = clampf(cw * 0.90, 300.0, minf(980.0, cw * 0.97))
	if _multi_subtitle != null:
		var m_sub_px := clampi(int(round(cw * 0.016)), 12, 22)
		_multi_subtitle.add_theme_font_size_override(&"font_size", m_sub_px)
		_multi_subtitle.add_theme_constant_override(&"outline_size", clampi(int(round(float(m_sub_px) / 3.0)), 3, 8))
		var m_sh := clampi(int(round(2.0 * sqrt(float(m_sub_px) * 0.5))), 1, 4)
		_multi_subtitle.add_theme_constant_override(&"shadow_offset_x", m_sh)
		_multi_subtitle.add_theme_constant_override(&"shadow_offset_y", m_sh)
		_multi_subtitle.custom_minimum_size.x = clampf(cw * 0.86, 260.0, minf(820.0, cw * 0.94))
	if _multiplayer_message != null:
		var m_msg_px := clampi(int(round(cw * 0.015)), 11, 20)
		_multiplayer_message.add_theme_font_size_override(&"font_size", m_msg_px)
		_multiplayer_message.add_theme_constant_override(&"outline_size", clampi(int(round(float(m_msg_px) / 3.0)), 3, 7))
		_multiplayer_message.custom_minimum_size.x = clampf(cw * 0.86, 240.0, minf(760.0, cw * 0.94))
	if _skins_shop_message != null:
		var sk_px := clampi(int(round(cw * 0.017)), 14, 20)
		_skins_shop_message.add_theme_font_size_override(&"font_size", sk_px)
		_skins_shop_message.add_theme_constant_override(
			&"outline_size", clampi(int(round(float(sk_px) / 3.5)), 3, 6))
	if _worlds_message != null:
		var wm_px := clampi(int(round(cw * 0.016)), 13, 18)
		_worlds_message.add_theme_font_size_override(&"font_size", wm_px)
		_worlds_message.add_theme_constant_override(
			&"outline_size", clampi(int(round(float(wm_px) / 3.0)), 3, 6))
	call_deferred("_layout_worlds_message_overlay")
	if _character_carousel != null and _character_carousel.has_method(&"refit_layout"):
		_character_carousel.refit_layout()
	call_deferred("_sync_menu_coins_hud")


func _wire_settings_toggle_rows() -> void:
	if _shadows_option_row != null and _settings_shadows != null:
		var sh := _settings_shadows
		_shadows_option_row.gui_input.connect(func(ev: InputEvent) -> void:
			_on_settings_option_row_gui_input(ev, sh))
	if _camera_person_option_row != null and _settings_third_person != null:
		var tp := _settings_third_person
		_camera_person_option_row.gui_input.connect(func(ev: InputEvent) -> void:
			_on_settings_option_row_gui_input(ev, tp))
	if _invert_option_row != null and _settings_invert_look != null:
		var inv := _settings_invert_look
		_invert_option_row.gui_input.connect(func(ev: InputEvent) -> void:
			_on_settings_option_row_gui_input(ev, inv))


func _on_settings_option_row_gui_input(event: InputEvent, check: CheckBox) -> void:
	if check == null:
		return
	var down := false
	if event is InputEventScreenTouch:
		down = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed
	if not down:
		return
	check.button_pressed = not check.button_pressed
	get_viewport().set_input_as_handled()


func _sync_settings_ui() -> void:
	if _settings_shadows != null:
		_settings_shadows.set_block_signals(true)
		_settings_shadows.button_pressed = PlayerSettings.get_directional_shadows_enabled()
		_settings_shadows.set_block_signals(false)
	if _settings_fov_slider != null:
		_settings_fov_slider.set_block_signals(true)
		_settings_fov_slider.value = PlayerSettings.get_camera_fov()
		_settings_fov_slider.set_block_signals(false)
	if _settings_fov_value != null:
		_settings_fov_value.text = str(int(round(PlayerSettings.get_camera_fov())))
	if _settings_third_person != null:
		_settings_third_person.set_block_signals(true)
		_settings_third_person.button_pressed = PlayerSettings.get_third_person()
		_settings_third_person.set_block_signals(false)
	if _settings_volume_slider != null:
		_settings_volume_slider.set_block_signals(true)
		_settings_volume_slider.value = round(PlayerSettings.get_master_linear() * 100.0)
		_settings_volume_slider.set_block_signals(false)
	if _settings_vol_value != null:
		_settings_vol_value.text = "%d%%" % int(round(PlayerSettings.get_master_linear() * 100.0))
	if _settings_sens_slider != null:
		_settings_sens_slider.set_block_signals(true)
		_settings_sens_slider.value = PlayerSettings.get_mouse_sensitivity_slider_t()
		_settings_sens_slider.set_block_signals(false)
	if _settings_sens_value != null:
		_settings_sens_value.text = "%.2f" % PlayerSettings.get_mouse_sensitivity()
	if _settings_invert_look != null:
		_settings_invert_look.set_block_signals(true)
		_settings_invert_look.button_pressed = PlayerSettings.get_invert_mouse_y()
		_settings_invert_look.set_block_signals(false)


func _creation_map_id() -> String:
	return _creation_map_id_choice


func _ensure_creation_map_unlocked() -> void:
	if not PlayerProgress.is_map_unlocked(_creation_map_id_choice):
		_creation_map_id_choice = WorldCatalog.default_map_id()


func _on_skin_shop_message(msg: String) -> void:
	## Skins screen hides ScreenCenter — feedback must live on ScreenSkins.
	_set_skins_shop_feedback(msg)
	_sync_menu_coins_hud()


func _restore_main_menu_chrome() -> void:
	if _menu_background != null:
		_menu_background.visible = true
	if _settings_button != null:
		_settings_button.visible = true
	if _settings_dim != null:
		_settings_dim.color = _SETTINGS_DIM_MENU


func _cancel_room_code_search() -> void:
	_join_lookup_pending = false
	if _signaling_http != null and is_instance_valid(_signaling_http):
		_signaling_http.cancel_request()
	if _connect_server_button != null:
		_connect_server_button.disabled = false


func _ensure_signaling_http() -> HTTPRequest:
	if _signaling_http == null or not is_instance_valid(_signaling_http):
		_signaling_http = HTTPRequest.new()
		add_child(_signaling_http)
		_signaling_http.request_completed.connect(_on_signaling_lookup_completed)
	return _signaling_http


func _show_main_screen() -> void:
	_cancel_room_code_search()
	_restore_main_menu_chrome()
	if _worlds_menu_dim != null:
		_worlds_menu_dim.visible = false
	if _screen_center != null:
		_screen_center.visible = true
	if _screen_main != null:
		_screen_main.visible = true
	if _screen_worlds != null:
		_screen_worlds.visible = false
	if _screen_skins != null:
		_screen_skins.visible = false
	if _screen_multiplayer != null:
		_screen_multiplayer.visible = false
	if _settings_overlay != null:
		_settings_overlay.visible = false
	_sync_menu_coins_hud()
	call_deferred("_sync_menu_coins_hud")


func _show_skins_screen() -> void:
	_cancel_room_code_search()
	if _worlds_menu_dim != null:
		_worlds_menu_dim.visible = true
	if _screen_center != null:
		_screen_center.visible = false
	if _screen_main != null:
		_screen_main.visible = false
	if _screen_worlds != null:
		_screen_worlds.visible = false
	if _screen_skins != null:
		_screen_skins.visible = true
	if _screen_multiplayer != null:
		_screen_multiplayer.visible = false
	if _settings_overlay != null:
		_settings_overlay.visible = false
	if _settings_button != null:
		_settings_button.visible = false
	if _character_carousel != null and _character_carousel.has_method(&"sync_from_settings"):
		_character_carousel.sync_from_settings()
	_sync_menu_coins_hud()


func _on_skins_screen_pressed() -> void:
	_set_message("")
	_show_skins_screen()


func _on_skins_back_pressed() -> void:
	_set_skins_shop_feedback("")
	_show_main_screen()


func _show_worlds_screen(clear_world_search: bool = true) -> void:
	_cancel_room_code_search()
	if _worlds_menu_dim != null:
		_worlds_menu_dim.visible = true
	if _screen_center != null:
		_screen_center.visible = false
	if _screen_main != null:
		_screen_main.visible = false
	if _screen_worlds != null:
		_screen_worlds.visible = true
	if _screen_skins != null:
		_screen_skins.visible = false
	if _screen_multiplayer != null:
		_screen_multiplayer.visible = false
	if _settings_overlay != null:
		_settings_overlay.visible = false
	if _settings_button != null:
		_settings_button.visible = false
	if clear_world_search and _world_search_edit != null:
		_world_search_edit.text = ""
	if clear_world_search:
		_worlds_tab = (
			_WORLDS_TAB_NEW
			if WorldPaths.list_world_slugs().is_empty()
			else _WORLDS_TAB_SAVED
		)
	_ensure_creation_map_unlocked()
	_apply_worlds_tab()
	_repopulate_world_list()
	_build_map_type_cards()
	_apply_worlds_preview_layout_sizes()
	_apply_map_card_selection_styles()
	call_deferred("_layout_worlds_message_overlay")
	_sync_menu_coins_hud()


func _show_multiplayer_screen(clear_message: bool = true) -> void:
	_cancel_room_code_search()
	_close_multiplayer_popups()
	if _worlds_menu_dim != null:
		_worlds_menu_dim.visible = false
	if _screen_center != null:
		_screen_center.visible = false
	if _screen_main != null:
		_screen_main.visible = false
	if _screen_worlds != null:
		_screen_worlds.visible = false
	if _screen_skins != null:
		_screen_skins.visible = false
	if _screen_multiplayer != null:
		_screen_multiplayer.visible = true
	if _settings_overlay != null:
		_settings_overlay.visible = false
	if _settings_button != null:
		_settings_button.visible = false
	if clear_message:
		_set_message("")
	_refresh_multiplayer_host_summary()
	_sync_menu_coins_hud()


func _wire_multiplayer_popup_dims() -> void:
	if _host_popup_dim != null:
		_host_popup_dim.gui_input.connect(_on_host_popup_dim_gui_input)
	if _join_popup_dim != null:
		_join_popup_dim.gui_input.connect(_on_join_popup_dim_gui_input)
	_wire_popup_close_buttons()


func _wire_popup_close_buttons() -> void:
	var host_close := get_node_or_null(
		"MenuRoot/ScreenMultiplayer/MultiHostPopup/HostPopupCenter/HostPopupPanel/HostMargin/HostVBox/HostHeaderRow/HostPopupCloseButton"
	) as Button
	if host_close != null:
		var hcb := Callable(self, "_on_multiplayer_host_popup_close_pressed")
		if not host_close.pressed.is_connected(hcb):
			host_close.pressed.connect(hcb)
	var join_close := get_node_or_null(
		"MenuRoot/ScreenMultiplayer/MultiJoinPopup/JoinPopupCenter/JoinPopupPanel/JoinMargin/JoinVBox/JoinHeaderRow/JoinPopupCloseButton"
	) as Button
	if join_close != null:
		var jcb := Callable(self, "_on_multiplayer_join_popup_close_pressed")
		if not join_close.pressed.is_connected(jcb):
			join_close.pressed.connect(jcb)


func _on_host_popup_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_multiplayer_host_popup()


func _on_join_popup_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_multiplayer_join_popup()


func _close_multiplayer_host_popup() -> void:
	if _host_feedback_label != null:
		_host_feedback_label.text = ""
		_host_feedback_label.visible = false
	if _multi_host_popup != null:
		_multi_host_popup.visible = false


func _close_multiplayer_join_popup() -> void:
	_cancel_room_code_search()
	if _join_feedback_label != null:
		_join_feedback_label.text = ""
		_join_feedback_label.visible = false
	if _multi_join_popup != null:
		_multi_join_popup.visible = false


func _close_multiplayer_popups() -> void:
	_close_multiplayer_host_popup()
	_close_multiplayer_join_popup()


func _on_multiplayer_host_launch_pressed() -> void:
	_cancel_room_code_search()
	_set_message("")
	_close_multiplayer_join_popup()
	if _multi_host_popup != null:
		_multi_host_popup.visible = true
	_refresh_multiplayer_host_summary()
	if _host_room_code_edit != null:
		_host_room_code_edit.grab_focus()


func _on_multiplayer_join_launch_pressed() -> void:
	_set_message("")
	_close_multiplayer_host_popup()
	if _multi_join_popup != null:
		_multi_join_popup.visible = true
	if _join_room_code_edit != null:
		_join_room_code_edit.grab_focus()


func _on_multiplayer_host_popup_close_pressed() -> void:
	_close_multiplayer_host_popup()


func _on_multiplayer_join_popup_close_pressed() -> void:
	_close_multiplayer_join_popup()


func _refresh_multiplayer_host_summary() -> void:
	if _host_world_label == null or _host_server_button == null:
		return
	var slugs := WorldPaths.list_world_slugs()
	if slugs.is_empty():
		_host_world_label.text = "No saved worlds yet. Create one in Worlds, then host here."
		_host_server_button.disabled = true
	else:
		var slug := resolve_resume_world_slug()
		_host_world_label.text = (
			"Everyone joins this world with you: \"%s\" (same save as single-player Play when possible)."
			% slug)
		_host_server_button.disabled = false


func _on_worlds_tab_saved_pressed() -> void:
	_worlds_tab = _WORLDS_TAB_SAVED
	_apply_worlds_tab()


func _on_worlds_tab_new_pressed() -> void:
	_worlds_tab = _WORLDS_TAB_NEW
	_apply_worlds_tab()


## Left rail: top button = rounded top; bottom = rounded bottom.
func _worlds_tab_btn_style(selected: bool, hover_dim: float, top_segment: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.content_margin_left = 8
	s.content_margin_top = 8
	s.content_margin_right = 8
	s.content_margin_bottom = 8
	if top_segment:
		s.corner_radius_top_left = 8
		s.corner_radius_top_right = 8
		s.corner_radius_bottom_left = 0
		s.corner_radius_bottom_right = 0
		s.border_width_bottom = 1
		s.border_color = Color(1, 1, 1, 0.12)
	else:
		s.corner_radius_bottom_left = 8
		s.corner_radius_bottom_right = 8
		s.corner_radius_top_left = 0
		s.corner_radius_top_right = 0
	if selected:
		var base := Color(0.2, 0.45, 0.82, 1.0)
		var hi := Color(0.32, 0.58, 0.98, 1.0)
		s.bg_color = base.lerp(hi, hover_dim)
		s.set_border_width_all(0)
		if top_segment:
			s.border_width_bottom = 1
			s.border_color = Color(0.12, 0.2, 0.4, 0.5)
		s.shadow_color = Color(0.25, 0.5, 1.0, 0.22)
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 1)
	else:
		var dim := Color(0.12, 0.14, 0.2, 1.0)
		var dim_hi := Color(0.18, 0.21, 0.3, 1.0)
		s.bg_color = dim.lerp(dim_hi, hover_dim)
		if top_segment:
			s.border_width_bottom = 1
			s.border_color = Color(1, 1, 1, 0.08)
	return s


func _apply_worlds_tab() -> void:
	if _saved_worlds_section_panel != null:
		_saved_worlds_section_panel.visible = _worlds_tab == _WORLDS_TAB_SAVED
	if _new_world_section_panel != null:
		_new_world_section_panel.visible = _worlds_tab == _WORLDS_TAB_NEW
	var saved_sel := _worlds_tab == _WORLDS_TAB_SAVED
	var new_sel := _worlds_tab == _WORLDS_TAB_NEW
	var on := Color(1, 1, 1, 1)
	var off := Color(0.78, 0.84, 0.95, 1.0)
	if _tab_saved_worlds_btn != null:
		_tab_saved_worlds_btn.text = "Your worlds"
		var st0 := _worlds_tab_btn_style(saved_sel, 0.0, true)
		var st_h := _worlds_tab_btn_style(saved_sel, 0.2, true)
		_tab_saved_worlds_btn.add_theme_stylebox_override(&"normal", st0)
		_tab_saved_worlds_btn.add_theme_stylebox_override(&"hover", st_h)
		_tab_saved_worlds_btn.add_theme_stylebox_override(&"pressed", st0)
		_tab_saved_worlds_btn.add_theme_stylebox_override(&"focus", st0)
		_tab_saved_worlds_btn.add_theme_font_size_override(&"font_size", 16 if saved_sel else 15)
		_tab_saved_worlds_btn.add_theme_constant_override(&"outline_size", 0)
		_tab_saved_worlds_btn.add_theme_color_override(&"font_color", on if saved_sel else off)
		_tab_saved_worlds_btn.add_theme_color_override(&"font_hover_color", on)
		_tab_saved_worlds_btn.add_theme_color_override(&"font_pressed_color", on)
	if _tab_new_world_btn != null:
		_tab_new_world_btn.text = "New world"
		var nt0 := _worlds_tab_btn_style(new_sel, 0.0, false)
		var nt_h := _worlds_tab_btn_style(new_sel, 0.2, false)
		_tab_new_world_btn.add_theme_stylebox_override(&"normal", nt0)
		_tab_new_world_btn.add_theme_stylebox_override(&"hover", nt_h)
		_tab_new_world_btn.add_theme_stylebox_override(&"pressed", nt0)
		_tab_new_world_btn.add_theme_stylebox_override(&"focus", nt0)
		_tab_new_world_btn.add_theme_font_size_override(&"font_size", 16 if new_sel else 15)
		_tab_new_world_btn.add_theme_constant_override(&"outline_size", 0)
		_tab_new_world_btn.add_theme_color_override(&"font_color", on if new_sel else off)
		_tab_new_world_btn.add_theme_color_override(&"font_hover_color", on)
		_tab_new_world_btn.add_theme_color_override(&"font_pressed_color", on)
	call_deferred("_layout_worlds_message_overlay")


func _worlds_filled_btn_box(bg: Color, border: Color, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_right = 10
	s.corner_radius_bottom_left = 10
	s.content_margin_left = 16
	s.content_margin_top = 12
	s.content_margin_right = 16
	s.content_margin_bottom = 12
	return s


func _apply_worlds_action_button_styles() -> void:
	if _delete_world_button != null:
		_delete_world_button.flat = false
		var d_bg := Color(0.38, 0.14, 0.17, 1.0)
		var d_br := Color(0.92, 0.4, 0.45, 1.0)
		_delete_world_button.add_theme_stylebox_override(
			"normal", _worlds_filled_btn_box(d_bg, d_br))
		_delete_world_button.add_theme_stylebox_override(
			"hover", _worlds_filled_btn_box(d_bg.lightened(0.12), d_br.lightened(0.08)))
		_delete_world_button.add_theme_stylebox_override(
			"pressed", _worlds_filled_btn_box(d_bg.darkened(0.18), d_br.darkened(0.1)))
		_delete_world_button.add_theme_stylebox_override(
			"disabled", _worlds_filled_btn_box(Color(0.22, 0.22, 0.26, 0.75), Color(0.4, 0.42, 0.48, 0.8)))
		_delete_world_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.88, 1.0))
		_delete_world_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		_delete_world_button.add_theme_color_override("font_pressed_color", Color(0.95, 0.85, 0.85, 1))
		_delete_world_button.add_theme_color_override("font_disabled_color", Color(0.55, 0.56, 0.62, 1.0))
	if _play_world_button != null:
		_play_world_button.flat = false
		var p_bg := Color(0.16, 0.28, 0.48, 1.0)
		var p_br := Color(0.48, 0.72, 1.0, 1.0)
		_play_world_button.add_theme_stylebox_override(
			"normal", _worlds_filled_btn_box(p_bg, p_br))
		_play_world_button.add_theme_stylebox_override(
			"hover", _worlds_filled_btn_box(p_bg.lightened(0.14), p_br.lightened(0.06)))
		_play_world_button.add_theme_stylebox_override(
			"pressed", _worlds_filled_btn_box(p_bg.darkened(0.15), p_br.darkened(0.08)))
		_play_world_button.add_theme_stylebox_override(
			"disabled", _worlds_filled_btn_box(Color(0.22, 0.24, 0.3, 0.75), Color(0.38, 0.44, 0.55, 0.85)))
		_play_world_button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
		_play_world_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		_play_world_button.add_theme_color_override("font_pressed_color", Color(0.88, 0.92, 1.0, 1))
		_play_world_button.add_theme_color_override("font_disabled_color", Color(0.52, 0.55, 0.62, 1.0))
	if _create_play_button != null:
		_create_play_button.flat = false
		var c_bg := Color(0.12, 0.42, 0.36, 1.0)
		var c_br := Color(0.35, 0.88, 0.72, 1.0)
		_create_play_button.add_theme_stylebox_override(
			"normal", _worlds_filled_btn_box(c_bg, c_br))
		_create_play_button.add_theme_stylebox_override(
			"hover", _worlds_filled_btn_box(c_bg.lightened(0.12), c_br.lightened(0.08)))
		_create_play_button.add_theme_stylebox_override(
			"pressed", _worlds_filled_btn_box(c_bg.darkened(0.16), c_br.darkened(0.1)))
		_create_play_button.add_theme_stylebox_override(
			"disabled", _worlds_filled_btn_box(Color(0.22, 0.26, 0.25, 0.75), Color(0.4, 0.5, 0.48, 0.8)))
		_create_play_button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.96, 1.0))
		_create_play_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		_create_play_button.add_theme_color_override("font_pressed_color", Color(0.88, 0.98, 0.94, 1))
		_create_play_button.add_theme_color_override("font_disabled_color", Color(0.52, 0.58, 0.56, 1.0))


func _apply_multiplayer_action_button_styles() -> void:
	if _connect_server_button != null:
		_connect_server_button.flat = false
		var j_bg := Color(0.16, 0.28, 0.48, 1.0)
		var j_br := Color(0.48, 0.72, 1.0, 1.0)
		_connect_server_button.add_theme_stylebox_override(
			"normal", _worlds_filled_btn_box(j_bg, j_br))
		_connect_server_button.add_theme_stylebox_override(
			"hover", _worlds_filled_btn_box(j_bg.lightened(0.14), j_br.lightened(0.06)))
		_connect_server_button.add_theme_stylebox_override(
			"pressed", _worlds_filled_btn_box(j_bg.darkened(0.15), j_br.darkened(0.08)))
		_connect_server_button.add_theme_stylebox_override(
			"disabled", _worlds_filled_btn_box(Color(0.22, 0.24, 0.3, 0.75), Color(0.38, 0.44, 0.55, 0.85)))
		_connect_server_button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
		_connect_server_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		_connect_server_button.add_theme_color_override("font_pressed_color", Color(0.88, 0.92, 1.0, 1))
		_connect_server_button.add_theme_color_override("font_disabled_color", Color(0.52, 0.55, 0.62, 1.0))
	if _host_server_button != null:
		_host_server_button.flat = false
		var h_bg := Color(0.22, 0.38, 0.22, 1.0)
		var h_br := Color(0.45, 0.82, 0.48, 1.0)
		_host_server_button.add_theme_stylebox_override(
			"normal", _worlds_filled_btn_box(h_bg, h_br))
		_host_server_button.add_theme_stylebox_override(
			"hover", _worlds_filled_btn_box(h_bg.lightened(0.12), h_br.lightened(0.08)))
		_host_server_button.add_theme_stylebox_override(
			"pressed", _worlds_filled_btn_box(h_bg.darkened(0.16), h_br.darkened(0.1)))
		_host_server_button.add_theme_stylebox_override(
			"disabled", _worlds_filled_btn_box(Color(0.22, 0.26, 0.24, 0.75), Color(0.4, 0.5, 0.44, 0.8)))
		_host_server_button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.93, 1.0))
		_host_server_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		_host_server_button.add_theme_color_override("font_pressed_color", Color(0.88, 0.98, 0.9, 1))
		_host_server_button.add_theme_color_override("font_disabled_color", Color(0.52, 0.58, 0.54, 1.0))


func _show_settings_screen() -> void:
	_restore_main_menu_chrome()
	if _worlds_menu_dim != null:
		_worlds_menu_dim.visible = false
	## Leave the current menu screen on the canvas so it shows through the dim; [SettingsMenuLayer] draws above it.
	if _settings_back_to_worlds:
		if _screen_center != null:
			_screen_center.visible = false
	elif _settings_back_to_multiplayer:
		if _screen_center != null:
			_screen_center.visible = false
	else:
		if _screen_center != null:
			_screen_center.visible = true
	if _screen_skins != null:
		_screen_skins.visible = false
	if _settings_overlay != null:
		_settings_overlay.visible = true
	_sync_settings_ui()
	_sync_menu_coins_hud()
	call_deferred("_sync_menu_coins_hud")


func remember_last_played_world(slug: String) -> void:
	if slug.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, KEY_LAST_WORLD, slug)
	cfg.save(SETTINGS_PATH)


func _load_last_played_slug() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return WorldPaths.DEFAULT_SLUG
	return str(cfg.get_value(SETTINGS_SECTION, KEY_LAST_WORLD, WorldPaths.DEFAULT_SLUG))


func _slug_exists(slugs: PackedStringArray, slug: String) -> bool:
	for s in slugs:
		if s == slug:
			return true
	return false


func _filtered_world_slugs(all_slugs: PackedStringArray) -> PackedStringArray:
	var q := ""
	if _world_search_edit != null:
		q = _world_search_edit.text.strip_edges().to_lower()
	if q.is_empty():
		return all_slugs
	var out: PackedStringArray = []
	for s in all_slugs:
		if String(s).to_lower().contains(q):
			out.append(s)
	return out


func _on_world_search_text_changed(_new_text: String) -> void:
	_refresh_world_cards()


## Slug used when the player hits Play (must only be called when saves exist).
func resolve_resume_world_slug() -> String:
	var slugs := WorldPaths.list_world_slugs()
	if slugs.is_empty():
		return WorldPaths.DEFAULT_SLUG
	var last := _load_last_played_slug()
	if _slug_exists(slugs, last):
		return last
	return slugs[0]


func _set_skins_shop_feedback(msg: String) -> void:
	if _skins_shop_message == null:
		return
	if _coin_warn_timer != null:
		_coin_warn_timer.stop()
	var s := msg.strip_edges()
	_skins_shop_message.text = msg
	_skins_shop_message.visible = not s.is_empty()
	if s.is_empty():
		return
	var is_err: bool = s == COIN_WARN_TEXT or s.contains("Could not")
	if is_err:
		_skins_shop_message.add_theme_color_override(&"font_color", Color(1.0, 0.42, 0.38, 1.0))
	else:
		_skins_shop_message.add_theme_color_override(&"font_color", Color(0.72, 0.98, 0.62, 1.0))
	if s == COIN_WARN_TEXT:
		_coin_warn_timer.start()
	if is_err:
		GameAudio.play_error_soft()
	elif s.to_lower().contains("unlocked"):
		GameAudio.play_purchase_unlock_success()


func _on_coin_warn_timer_timeout() -> void:
	_clear_coin_warn_flash()


func _schedule_coin_warn_clear() -> void:
	if _coin_warn_timer == null:
		return
	_coin_warn_timer.stop()
	_coin_warn_timer.start()


## Removes the short “not enough coins” line from every place [method _set_message] copied it.
func _clear_coin_warn_flash() -> void:
	if _skins_shop_message != null and _skins_shop_message.text == COIN_WARN_TEXT:
		_set_skins_shop_feedback("")
	if _message != null and _message.text == COIN_WARN_TEXT:
		_message.text = ""
	if _worlds_message != null and _worlds_message.text == COIN_WARN_TEXT:
		_worlds_message.text = ""
		_worlds_message.visible = false
		_layout_worlds_message_overlay()
		call_deferred("_layout_worlds_message_overlay")
	if _multiplayer_message != null and _multiplayer_message.text == COIN_WARN_TEXT:
		_multiplayer_message.text = ""
		_multiplayer_message.visible = false
		_multiplayer_message.custom_minimum_size.y = 0


func _layout_worlds_message_overlay() -> void:
	if _worlds_message == null or _worlds_vbox == null or _screen_worlds == null:
		return
	if not _screen_worlds.visible:
		return
	var panel: Control = null
	if _new_world_section_panel != null and _new_world_section_panel.visible:
		panel = _new_world_section_panel
	elif _saved_worlds_section_panel != null and _saved_worlds_section_panel.visible:
		panel = _saved_worlds_section_panel
	if panel == null:
		return
	var vp := get_viewport()
	var cw: float = vp.get_visible_rect().size.x if vp != null else 440.0
	var wm_px := clampi(int(round(cw * 0.016)), 13, 18)
	var strip_h := float(clampi(wm_px + 10, 26, 40))
	## Full-width strip (same horizontal inset as [WorldsVBox] / title); Y from panel top in [ScreenWorlds] space so it sits just above the box and draws above [WorldsVBox] (z_index < WorldsBackButton).
	const gap_above_panel_px := 4.0
	var gr := panel.get_global_rect()
	var inv_sw := _screen_worlds.get_global_transform().affine_inverse()
	var panel_top_sw := (inv_sw * Vector2(gr.position.x + gr.size.x * 0.5, gr.position.y)).y
	var top_y := panel_top_sw - strip_h - gap_above_panel_px
	_worlds_message.anchor_left = 0.0
	_worlds_message.anchor_right = 1.0
	_worlds_message.anchor_top = 0.0
	_worlds_message.anchor_bottom = 0.0
	_worlds_message.offset_left = _worlds_vbox.offset_left
	_worlds_message.offset_right = _worlds_vbox.offset_right
	_worlds_message.offset_top = top_y
	_worlds_message.offset_bottom = top_y + strip_h
	_worlds_message.custom_minimum_size = Vector2(0.0, strip_h)


func _set_message(msg: String) -> void:
	if _message != null:
		_message.text = msg
	if _worlds_message != null:
		var s := msg.strip_edges()
		var on_worlds: bool = _screen_worlds != null and _screen_worlds.visible
		if not on_worlds:
			_worlds_message.text = ""
			_worlds_message.visible = false
		else:
			_worlds_message.text = msg
			_worlds_message.visible = not s.is_empty()
			if not s.is_empty():
				var sl := s.to_lower()
				if sl.contains("not enough") or sl.contains("could not"):
					_worlds_message.add_theme_color_override(&"font_color", Color(1.0, 0.42, 0.38, 1.0))
				elif sl.contains("unlocked"):
					_worlds_message.add_theme_color_override(&"font_color", Color(0.72, 0.98, 0.62, 1.0))
				else:
					_worlds_message.add_theme_color_override(&"font_color", Color(1.0, 0.42, 0.38, 1.0))
			if not s.is_empty():
				var sl2 := s.to_lower()
				if sl2.contains("not enough") or sl2.contains("could not"):
					GameAudio.play_error_soft()
				elif sl2.contains("unlocked"):
					GameAudio.play_purchase_unlock_success()
		_layout_worlds_message_overlay()
		if on_worlds:
			call_deferred("_layout_worlds_message_overlay")

	var host_open := _multi_host_popup != null and _multi_host_popup.visible
	var join_open := _multi_join_popup != null and _multi_join_popup.visible
	var mp_popup_open := host_open or join_open

	# Background multiplayer line: only when no host/join popup (avoid duplicate with popup labels).
	if _multiplayer_message != null:
		if mp_popup_open:
			_multiplayer_message.text = ""
			_multiplayer_message.visible = false
			_multiplayer_message.custom_minimum_size.y = 0
		else:
			_multiplayer_message.text = msg
			if msg.is_empty():
				_multiplayer_message.visible = false
				_multiplayer_message.custom_minimum_size.y = 0
			else:
				_multiplayer_message.visible = true
				_multiplayer_message.custom_minimum_size.y = 52

	if _host_feedback_label != null:
		var hf := msg if host_open else ""
		_host_feedback_label.text = hf
		_host_feedback_label.visible = not hf.is_empty()
	if _join_feedback_label != null:
		var jf := msg if join_open else ""
		_join_feedback_label.text = jf
		_join_feedback_label.visible = not jf.is_empty()


func _repopulate_world_list() -> void:
	_refresh_world_cards()
	_prefill_new_world_name()
	_refresh_multiplayer_host_summary()


## Returning from gameplay: main screen + fresh list.
func refresh_world_list() -> void:
	_show_main_screen()
	_repopulate_world_list()


func _prefill_new_world_name() -> void:
	if _new_world_edit != null:
		_new_world_edit.text = WorldPaths.suggest_new_world_slug()


func _setup_delete_world_dialog() -> void:
	_delete_world_dialog = ConfirmationDialog.new()
	_delete_world_dialog.title = "Delete world"
	_delete_world_dialog.ok_button_text = "Delete"
	_delete_world_dialog.dialog_hide_on_ok = true
	add_child(_delete_world_dialog)
	_delete_world_dialog.confirmed.connect(_on_delete_world_dialog_confirmed)


func _add_world_preview_corner_overlay(holder: Control, fill: Color) -> void:
	var ov: Control = _WorldsPreviewCornerOverlay.new()
	ov.corner_fill = fill
	holder.add_child(ov)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.call_deferred(&"queue_redraw")


func _queue_redraw_preview_corner_overlays(root: Control) -> void:
	for ch in root.get_children():
		if ch is WorldsPreviewCornerOverlay:
			(ch as WorldsPreviewCornerOverlay).queue_redraw()
		elif ch is Control:
			_queue_redraw_preview_corner_overlays(ch as Control)


func _setup_map_preview_texture_rect(tr: TextureRect, min_draw: Vector2 = Vector2(112, 63)) -> void:
	## No material — same draw path as a plain TextureRect; rounding is a sibling overlay.
	tr.material = null
	tr.custom_minimum_size = min_draw
	## Parent uses anchor full-rect; avoid EXPAND flags (confuses HFlow + AspectRatio sizing).
	tr.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.clip_contents = true


func _apply_worlds_preview_layout_sizes() -> void:
	if _map_cards_row != null:
		var mh := _worlds_new_map_preview_size
		var map_min_h := float(int(mh.y) + 24)
		for c in _map_cards_row.get_children():
			if not c is PanelContainer:
				continue
			var p: PanelContainer = c
			if not p.has_meta(&"worlds_preview_aspect"):
				continue
			var ar: Variant = p.get_meta(&"worlds_preview_aspect")
			if ar is Control and is_instance_valid(ar):
				(ar as Control).custom_minimum_size = _worlds_new_map_preview_size
				_queue_redraw_preview_corner_overlays(ar as Control)
			if p.has_meta(&"worlds_preview_tr"):
				var tr: Variant = p.get_meta(&"worlds_preview_tr")
				if tr is TextureRect and is_instance_valid(tr):
					var trn := tr as TextureRect
					trn.custom_minimum_size = _worlds_new_map_preview_size
			p.custom_minimum_size = Vector2(0, map_min_h)
		call_deferred(&"_sync_map_terrain_unlock_chips")
	if _world_cards_row != null:
		for c2 in _world_cards_row.get_children():
			if not c2 is PanelContainer:
				continue
			var wp: PanelContainer = c2
			if not wp.has_meta(&"worlds_preview_aspect"):
				continue
			var ar2: Variant = wp.get_meta(&"worlds_preview_aspect")
			if ar2 is Control and is_instance_valid(ar2):
				var shell2 := ar2 as Control
				shell2.custom_minimum_size = _worlds_save_preview_size
				_queue_redraw_preview_corner_overlays(shell2)
			if wp.has_meta(&"worlds_preview_tr"):
				var tr2: Variant = wp.get_meta(&"worlds_preview_tr")
				if tr2 is TextureRect and is_instance_valid(tr2):
					var trs := tr2 as TextureRect
					trs.custom_minimum_size = _worlds_save_preview_size
			var sp := _worlds_save_preview_size
			var pw := int(sp.x) + 12 + 148 + 24
			var ph := maxi(int(sp.y) + 24, 68)
			wp.custom_minimum_size = Vector2(pw, ph)
	_apply_worlds_cards_typography()


func _apply_worlds_cards_typography() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var us: float = StoreUnlockUi.viewport_scale(vp)
	var title_px := clampi(int(round(13.0 * us)), 11, 18)
	var sub_px := clampi(int(round(9.0 * us)), 8, 13)
	if _map_cards_row != null:
		for c in _map_cards_row.get_children():
			if not c is PanelContainer:
				continue
			if not (c as Node).has_meta(&"map_id"):
				continue
			var t: Node = (c as Node).find_child("MapCardTitleLabel", true, false)
			var d: Node = (c as Node).find_child("MapCardDescLabel", true, false)
			if t is Label:
				(t as Label).add_theme_font_size_override(&"font_size", title_px)
			if d is Label:
				(d as Label).add_theme_font_size_override(&"font_size", sub_px)
	if _world_cards_row != null:
		for c in _world_cards_row.get_children():
			if not c is PanelContainer:
				continue
			if not (c as Node).has_meta(&"slug"):
				continue
			var nm: Node = (c as Node).find_child("WorldSaveNameLabel", true, false)
			var mp: Node = (c as Node).find_child("WorldSaveMapLabel", true, false)
			if nm is Label:
				(nm as Label).add_theme_font_size_override(&"font_size", title_px)
			if mp is Label:
				(mp as Label).add_theme_font_size_override(&"font_size", sub_px)


func _texture_for_map_preview(map_id: String) -> Texture2D:
	var tex: Texture2D = WorldCatalog.load_map_preview_texture(map_id)
	if tex != null:
		return tex
	var cols := WorldCatalog.map_card_gradient_colors(map_id)
	var g := Gradient.new()
	g.add_point(0.0, cols[0])
	g.add_point(1.0, cols[1])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 400
	gt.height = 225
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.08, 0.0)
	gt.fill_to = Vector2(0.92, 1.0)
	return gt


func _world_card_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.11, 0.16, 0.94)
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	if selected:
		s.border_color = Color(0.42, 0.68, 0.98, 0.95)
		s.set_border_width_all(2)
	else:
		s.border_color = Color(0.26, 0.34, 0.46, 0.75)
		s.set_border_width_all(1)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 3)
	return s


## Dark dim over the preview + centered lock + LOCKED (no pill panel).
func _make_map_lock_overlay() -> Control:
	var us: float = StoreUnlockUi.viewport_scale(get_viewport())
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", clampi(int(round(2.0 * us)), 1, 4))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := Label.new()
	ic.text = "🔒"
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.add_theme_font_size_override(&"font_size", clampi(int(round(22.0 * us)), 16, 32))
	ic.add_theme_color_override(&"font_color", Color(0.98, 0.96, 0.92, 1.0))
	ic.add_theme_color_override(&"font_outline_color", Color(0.02, 0.03, 0.06, 0.92))
	ic.add_theme_constant_override(&"outline_size", clampi(int(round(2.0 * us)), 2, 4))
	var lb := Label.new()
	lb.text = "LOCKED"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override(&"font_size", clampi(int(round(10.0 * us)), 8, 13))
	lb.add_theme_color_override(&"font_color", Color(0.96, 0.94, 0.9, 1.0))
	lb.add_theme_color_override(&"font_outline_color", Color(0.02, 0.03, 0.06, 0.92))
	lb.add_theme_constant_override(&"outline_size", clampi(int(round(2.0 * us)), 1, 3))
	col.add_child(ic)
	col.add_child(lb)
	cc.add_child(col)
	return root


func _map_card_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_right = 12
	s.corner_radius_bottom_left = 12
	if selected:
		s.border_color = Color(0.45, 0.72, 1.0, 0.95)
		s.set_border_width_all(2)
	else:
		s.border_color = Color(0.22, 0.28, 0.38, 0.65)
		s.set_border_width_all(1)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 2)
	return s


func _make_world_save_card(slug: String, map_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var us_ws: float = StoreUnlockUi.viewport_scale(get_viewport())
	var save_title_px := clampi(int(round(13.0 * us_ws)), 11, 18)
	var save_sub_px := clampi(int(round(9.0 * us_ws)), 8, 13)
	var sp := _worlds_save_preview_size
	var pw := int(sp.x) + 12 + 148 + 24
	var ph := maxi(int(sp.y) + 24, 68)
	panel.custom_minimum_size = Vector2(pw, ph)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta(&"slug", slug)
	panel.add_theme_stylebox_override("panel", _world_card_style(slug == _ui_selected_world_slug))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	## Fixed 16:9 shell (sp is already 16:9). AspectRatioContainer + HFlow often leaves inner size at 0.
	var thumb_shell := Control.new()
	thumb_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_shell.custom_minimum_size = sp
	thumb_shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tr := TextureRect.new()
	tr.texture = _texture_for_map_preview(map_id)
	tr.z_index = 0
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb_shell.add_child(tr)
	_setup_map_preview_texture_rect(tr, sp)
	_add_world_preview_corner_overlay(thumb_shell, _SAVE_CARD_PREVIEW_CORNER_FILL)
	panel.set_meta(&"worlds_preview_aspect", thumb_shell)
	panel.set_meta(&"worlds_preview_tr", tr)
	row.add_child(thumb_shell)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 6)
	var name_l := Label.new()
	name_l.name = "WorldSaveNameLabel"
	name_l.text = slug
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override(&"font_size", save_title_px)
	name_l.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	var map_l := Label.new()
	map_l.name = "WorldSaveMapLabel"
	map_l.text = WorldCatalog.map_short_label(map_id)
	map_l.add_theme_font_size_override(&"font_size", save_sub_px)
	map_l.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78))
	texts.add_child(name_l)
	texts.add_child(map_l)
	row.add_child(texts)
	margin.add_child(row)
	panel.add_child(margin)
	panel.gui_input.connect(func(ev: InputEvent) -> void: _on_world_card_gui(ev, slug))
	return panel


func _on_world_card_gui(event: InputEvent, slug: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_world_selection(slug)


func _set_world_selection(slug: String) -> void:
	_ui_selected_world_slug = slug
	_apply_world_card_selection_styles()
	_refresh_world_action_buttons()


func _apply_world_card_selection_styles() -> void:
	if _world_cards_row == null:
		return
	for c in _world_cards_row.get_children():
		if not c is PanelContainer:
			continue
		var s: String = str(c.get_meta(&"slug", ""))
		c.add_theme_stylebox_override("panel", _world_card_style(s == _ui_selected_world_slug))


func _refresh_world_cards() -> void:
	if _world_cards_row == null:
		return
	for ch in _world_cards_row.get_children():
		ch.queue_free()
	var all_slugs := WorldPaths.list_world_slugs()
	var slugs := _filtered_world_slugs(all_slugs)
	if _world_empty_hint != null:
		if all_slugs.is_empty():
			_world_empty_hint.visible = true
			_world_empty_hint.text = "No saves yet — pick New world on the left to create one."
		elif slugs.is_empty():
			_world_empty_hint.visible = true
			_world_empty_hint.text = "No worlds match your search."
		else:
			_world_empty_hint.visible = false
	if all_slugs.is_empty():
		_ui_selected_world_slug = ""
		_apply_world_card_selection_styles()
		_refresh_world_action_buttons()
		return
	if slugs.is_empty():
		_ui_selected_world_slug = ""
		_apply_world_card_selection_styles()
		_refresh_world_action_buttons()
		return
	for s in slugs:
		var mid := WorldMeta.read_map_id(s)
		_world_cards_row.add_child(_make_world_save_card(s, mid))
	_select_slug_in_list(_load_last_played_slug())
	_apply_worlds_preview_layout_sizes()


func _build_map_type_cards() -> void:
	if _map_cards_row == null:
		return
	for ch in _map_cards_row.get_children():
		ch.queue_free()
	_map_card_panels.clear()
	for e in WorldCatalog.map_picker_entries():
		var id := str(e.get("id", WorldCatalog.MAP_GRASSLAND))
		var desc := str(e.get("description", ""))
		var card := _make_map_type_card(id, desc)
		_map_cards_row.add_child(card)
		_map_card_panels[id] = card
	_apply_map_card_selection_styles()
	call_deferred(&"_sync_map_terrain_unlock_chips")


func _sync_map_terrain_unlock_chips() -> void:
	if _map_cards_row == null:
		return
	var sc: float = StoreUnlockUi.viewport_scale(get_viewport())
	for c in _map_cards_row.get_children():
		if not c is PanelContainer:
			continue
		var p: PanelContainer = c as PanelContainer
		var btn: Node = p.find_child("TerrainCoinUnlockButton", true, false)
		if btn == null or not (btn is HoldCoinUnlockButton):
			continue
		var ubtn: HoldCoinUnlockButton = btn as HoldCoinUnlockButton
		if not ubtn.visible:
			continue
		var mid := str(p.get_meta(&"map_id", ""))
		if mid.is_empty() or PlayerProgress.is_map_unlocked(mid):
			continue
		var cost: int = WorldCatalog.map_unlock_coin_cost(mid)
		if cost <= 0:
			continue
		StoreUnlockUi.sync_coin_unlock_chip(ubtn, cost, sc)
		ubtn.custom_minimum_size = Vector2(
			clampi(int(round(96.0 * sc)), 72, 156),
			clampi(int(round(30.0 * sc)), 24, 38))


func _make_map_type_card(map_id: String, description: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prev := _worlds_new_map_preview_size
	var mc: int = WorldCatalog.map_unlock_coin_cost(map_id)
	var map_unlocked := PlayerProgress.is_map_unlocked(map_id)
	var needs_lock_ui: bool = (not map_unlocked) and mc > 0
	var us_lo: float = StoreUnlockUi.viewport_scale(get_viewport())
	panel.custom_minimum_size = Vector2(0, float(int(prev.y) + 24))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta(&"map_id", map_id)
	var title := WorldCatalog.map_short_label(map_id)
	panel.tooltip_text = ("%s — %s" % [title, description]) if description != "" else title
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 12)
	var ar := AspectRatioContainer.new()
	ar.custom_minimum_size = prev
	ar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ar.ratio = 16.0 / 9.0
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ar.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tr := TextureRect.new()
	tr.texture = _texture_for_map_preview(map_id)
	tr.z_index = 0
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(tr)
	_setup_map_preview_texture_rect(tr, prev)
	if needs_lock_ui:
		tr.modulate = Color.WHITE
		holder.add_child(_make_map_lock_overlay())
	_add_world_preview_corner_overlay(holder, _MAP_CARD_PREVIEW_CORNER_FILL)
	panel.set_meta(&"worlds_preview_aspect", ar)
	panel.set_meta(&"worlds_preview_tr", tr)
	row.add_child(ar)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	texts.add_theme_constant_override("separation", 4)
	var map_title_px := clampi(int(round(13.0 * us_lo)), 11, 18)
	var map_sub_px := clampi(int(round(9.0 * us_lo)), 8, 13)
	var short := Label.new()
	short.name = "MapCardTitleLabel"
	short.text = title
	short.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	short.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	short.add_theme_font_size_override(&"font_size", map_title_px)
	short.add_theme_color_override("font_color", Color(0.92, 0.94, 0.99))
	var sub := Label.new()
	sub.name = "MapCardDescLabel"
	sub.text = description
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override(&"font_size", map_sub_px)
	sub.add_theme_color_override("font_color", Color(0.55, 0.62, 0.74))
	texts.add_child(short)
	texts.add_child(sub)
	if needs_lock_ui:
		var desc_btn_gap := Control.new()
		desc_btn_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_btn_gap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		desc_btn_gap.custom_minimum_size = Vector2(
			0, float(clampi(int(round(5.0 * us_lo)), 4, 9)))
		texts.add_child(desc_btn_gap)
		var ubtn: HoldCoinUnlockButton = HoldCoinUnlockButton.new()
		ubtn.name = "TerrainCoinUnlockButton"
		ubtn.set_meta(&"sync_price_on_ready", mc)
		ubtn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ubtn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ubtn.custom_minimum_size = Vector2(
			clampi(int(round(96.0 * us_lo)), 72, 156),
			clampi(int(round(30.0 * us_lo)), 24, 38))
		ubtn.tooltip_text = "Hold (%d coins) until the fill completes." % mc
		var mid := map_id
		ubtn.hold_completed.connect(func() -> void: _on_map_unlock_button_pressed(mid))
		var chip_row := HBoxContainer.new()
		chip_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chip_row.add_theme_constant_override(&"separation", 0)
		chip_row.add_child(ubtn)
		texts.add_child(chip_row)
	row.add_child(texts)
	margin.add_child(row)
	panel.add_child(margin)
	panel.gui_input.connect(func(ev: InputEvent) -> void: _on_map_card_gui(ev, map_id))
	return panel


func _on_map_unlock_button_pressed(map_id: String) -> void:
	var r: Dictionary = PlayerProgress.try_purchase_map_unlock(map_id)
	if bool(r.get(&"ok", false)):
		_set_message("%s unlocked!" % WorldCatalog.map_short_label(map_id))
		_creation_map_id_choice = map_id
		_build_map_type_cards()
		_apply_worlds_preview_layout_sizes()
		_apply_map_card_selection_styles()
		_sync_menu_coins_hud()
		return
	if str(r.get(&"reason", "")) == "not_enough_coins":
		_set_message(COIN_WARN_TEXT)
		_schedule_coin_warn_clear()
	else:
		_set_message("Could not unlock this terrain.")


func _on_map_card_gui(event: InputEvent, map_id: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not PlayerProgress.is_map_unlocked(map_id):
		return
	_creation_map_id_choice = map_id
	_apply_map_card_selection_styles()


func _apply_map_card_selection_styles() -> void:
	for id in _map_card_panels.keys():
		var p: Node = _map_card_panels[id]
		if p is PanelContainer:
			(p as PanelContainer).add_theme_stylebox_override(
				"panel", _map_card_style(id == _creation_map_id_choice))


func _refresh_world_action_buttons() -> void:
	var all_slugs := WorldPaths.list_world_slugs()
	var slugs := _filtered_world_slugs(all_slugs)
	var has_worlds := not slugs.is_empty()
	if _play_world_button != null:
		_play_world_button.disabled = not has_worlds
	if _delete_world_button != null:
		_delete_world_button.disabled = not has_worlds


func _select_slug_in_list(slug: String) -> void:
	var all_slugs := WorldPaths.list_world_slugs()
	var slugs := _filtered_world_slugs(all_slugs)
	if slugs.is_empty():
		_ui_selected_world_slug = ""
		_apply_world_card_selection_styles()
		_refresh_world_action_buttons()
		return
	var pick := slug
	if not _slug_exists(slugs, pick):
		pick = slugs[0]
	_ui_selected_world_slug = pick
	_apply_world_card_selection_styles()
	_refresh_world_action_buttons()


func get_selected_world_slug() -> String:
	var all_slugs := WorldPaths.list_world_slugs()
	if all_slugs.is_empty():
		return WorldPaths.DEFAULT_SLUG
	var slugs := _filtered_world_slugs(all_slugs)
	if slugs.is_empty():
		return WorldPaths.DEFAULT_SLUG
	if _ui_selected_world_slug != "" and _slug_exists(slugs, _ui_selected_world_slug):
		return _ui_selected_world_slug
	return slugs[0]


func _on_delete_world_pressed() -> void:
	_set_message("")
	var slug := get_selected_world_slug()
	var slugs := WorldPaths.list_world_slugs()
	if slugs.is_empty() or not _slug_exists(slugs, slug):
		return
	if _delete_world_dialog == null:
		return
	_pending_delete_slug = slug
	_delete_world_dialog.dialog_text = (
		"Permanently delete \"%s\"?\nAll terrain data in this slot will be removed." % slug)
	_delete_world_dialog.popup_centered()


func _on_delete_world_dialog_confirmed() -> void:
	var slug := _pending_delete_slug
	_pending_delete_slug = ""
	if slug.is_empty() or not WorldPaths.is_valid_slug(slug):
		return
	var err := WorldPaths.delete_world(slug)
	if err != OK:
		_set_message("Could not delete world (error %d)." % err)
		return
	if _load_last_played_slug() == slug:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value(SETTINGS_SECTION, KEY_LAST_WORLD, WorldPaths.DEFAULT_SLUG)
		cfg.save(SETTINGS_PATH)
	_repopulate_world_list()
	_set_message("")


func _on_main_play_pressed() -> void:
	_set_message("")
	if WorldPaths.list_world_slugs().is_empty():
		_show_worlds_screen()
		return
	singleplayer_requested.emit(resolve_resume_world_slug())


func _on_worlds_screen_pressed() -> void:
	_set_message("")
	_show_worlds_screen()


func _on_multiplayer_toggle_pressed() -> void:
	_show_multiplayer_screen()


func _on_multiplayer_back_pressed() -> void:
	_set_message("")
	_show_main_screen()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_worlds_back_pressed() -> void:
	_set_message("")
	_show_main_screen()


func is_settings_overlay_open() -> bool:
	return _settings_overlay != null and _settings_overlay.visible


## Escape while playing: close settings if open (same as Back), so pause menu is not stacked on top.
func try_escape_close_settings_overlay() -> bool:
	if not is_settings_overlay_open():
		return false
	_on_settings_back_pressed()
	return true


func _on_settings_pressed() -> void:
	_set_message("")
	_settings_from_pause = false
	_settings_back_to_worlds = _screen_worlds != null and _screen_worlds.visible
	_settings_back_to_multiplayer = _screen_multiplayer != null and _screen_multiplayer.visible
	if _settings_back_to_multiplayer:
		_close_multiplayer_popups()
	_show_settings_screen()


## Called from Main while the game is paused (pause menu opens the same settings overlay).
func show_settings_from_pause_game() -> void:
	_settings_from_pause = true
	_settings_back_to_worlds = false
	_settings_back_to_multiplayer = false
	visible = true
	_close_multiplayer_popups()
	# Whole MainMenu was hidden for gameplay; nested screens keep their last visibility.
	# Force off menu chrome so worlds / multiplayer UI does not sit above the dim (game view).
	if _worlds_menu_dim != null:
		_worlds_menu_dim.visible = false
	if _screen_worlds != null:
		_screen_worlds.visible = false
	if _screen_skins != null:
		_screen_skins.visible = false
	if _screen_multiplayer != null:
		_screen_multiplayer.visible = false
	if _menu_background != null:
		_menu_background.visible = false
	if _settings_button != null:
		_settings_button.visible = false
	if _settings_dim != null:
		_settings_dim.color = _SETTINGS_DIM_OVER_GAME
	if _screen_center != null:
		_screen_center.visible = false
	if _settings_overlay != null:
		_settings_overlay.visible = true
	_sync_settings_ui()
	_sync_menu_coins_hud()
	call_deferred("_sync_menu_coins_hud")


func _on_settings_back_pressed() -> void:
	if _settings_from_pause:
		_settings_from_pause = false
		if _settings_overlay != null:
			_settings_overlay.visible = false
		_restore_main_menu_chrome()
		hide()
		var main_root: Node = get_tree().root.get_node_or_null("Main")
		if main_root != null and main_root.has_method("restore_pause_after_settings_overlay"):
			main_root.restore_pause_after_settings_overlay()
		var pm: Node = get_tree().get_first_node_in_group("pause_menu")
		if pm != null and pm.has_method("show_after_settings"):
			pm.show_after_settings()
		return
	_set_message("")
	if _settings_back_to_multiplayer:
		_show_multiplayer_screen(false)
	elif _settings_back_to_worlds:
		_show_worlds_screen(false)
	else:
		_show_main_screen()


func _on_settings_shadows_toggled(pressed: bool) -> void:
	PlayerSettings.set_directional_shadows_enabled(pressed)


func _on_settings_fov_changed(value: float) -> void:
	PlayerSettings.set_camera_fov(value)
	if _settings_fov_value != null:
		_settings_fov_value.text = str(int(round(value)))


func _on_settings_third_person_toggled(pressed: bool) -> void:
	PlayerSettings.set_third_person(pressed)


func _on_settings_master_volume_changed(value: float) -> void:
	PlayerSettings.set_master_linear(value / 100.0)
	if _settings_vol_value != null:
		_settings_vol_value.text = "%d%%" % int(round(value))


func _on_settings_mouse_sens_changed(value: float) -> void:
	PlayerSettings.set_mouse_sensitivity_slider_t(value)
	if _settings_sens_value != null:
		_settings_sens_value.text = "%.2f" % PlayerSettings.get_mouse_sensitivity()


func _on_settings_invert_look_toggled(pressed: bool) -> void:
	PlayerSettings.set_invert_mouse_y(pressed)


func _on_play_world_pressed() -> void:
	_set_message("")
	singleplayer_requested.emit(get_selected_world_slug())


func _on_create_and_play_pressed() -> void:
	_set_message("")
	_ensure_creation_map_unlocked()
	if not PlayerProgress.is_map_unlocked(_creation_map_id()):
		_set_message(
			"Unlock this terrain above with coins, or select Grassland (free).")
		return
	var slug := _new_world_edit.text.strip_edges() if _new_world_edit != null else ""
	if slug.is_empty():
		slug = WorldPaths.suggest_new_world_slug()
	if not WorldPaths.is_valid_slug(slug):
		_set_message(
			"World name: letters/numbers, may include _ or -, 1–32 characters (e.g. my_world_2).")
		return
	var err := WorldPaths.ensure_world_directory(slug)
	if err != OK:
		_set_message("Could not create world folder (error %d)." % err)
		return
	var werr := WorldMeta.write(slug, _creation_map_id())
	if werr != OK:
		_set_message("Could not save world settings (error %d)." % werr)
		return
	_repopulate_world_list()
	_select_slug_in_list(slug)
	singleplayer_requested.emit(slug)


func _on_connect_to_server_button_pressed() -> void:
	var base := RoomCodeSignalingSettings.get_base_url()
	var raw := _join_room_code_edit.text if _join_room_code_edit != null else ""
	var code := RoomCodeLan.normalize_code(raw)
	_set_message("")
	if base.is_empty():
		_set_message("Online multiplayer is not configured for this build.")
		return
	if not RoomCodeLan.is_valid_room_code(code):
		_set_message(
			"Ask the host for the code. Use letters and numbers only — at least %d characters."
			% RoomCodeLan.MIN_CODE_LEN)
		return
	if _connect_server_button != null:
		_connect_server_button.disabled = true
	_set_message("Looking up room code…")
	var http := _ensure_signaling_http()
	http.cancel_request()
	_join_lookup_pending = true
	var url := "%s/lookup/%s" % [base.trim_suffix("/"), code]
	var err := http.request(url)
	if err != OK:
		_join_lookup_pending = false
		if _connect_server_button != null:
			_connect_server_button.disabled = false
		_set_message(
			"Could not contact the matchmaking server. Check your internet connection and try again.")


func _on_signaling_lookup_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if not _join_lookup_pending:
		return
	_join_lookup_pending = false
	if _connect_server_button != null:
		_connect_server_button.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_message(
			"Could not reach the matchmaking server. Check your internet or VPN, then try again.")
		return
	if response_code != 200:
		if response_code == 404:
			_set_message(
				"No game found for that code. Check spelling with the host, or ask them to start hosting again.")
		else:
			_set_message(
				"The matchmaking server had a problem. Wait a moment and try again, or contact support.")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.get("ok", false):
		_set_message("Bad response from matchmaking server.")
		return
	var host := str(data.get("host", ""))
	var port := int(data.get("port", 0))
	if host.is_empty() or port < 1:
		_set_message("Bad address from matchmaking server.")
		return
	if not NetworkAddress.is_valid_client_address(host):
		_set_message(NetworkAddress.validation_error_hint())
		return
	_set_message("")
	connect_to_server_requested.emit(host, port)


func _on_host_server_button_pressed() -> void:
	_set_message("")
	if RoomCodeSignalingSettings.get_base_url().is_empty():
		_set_message("Online multiplayer is not configured for this build.")
		return
	var raw := _host_room_code_edit.text if _host_room_code_edit != null else ""
	var code := RoomCodeLan.normalize_code(raw)
	if not RoomCodeLan.is_valid_room_code(code):
		_set_message(
			"Choose a room code using letters and numbers — at least %d characters."
			% RoomCodeLan.MIN_CODE_LEN)
		return
	if WorldPaths.list_world_slugs().is_empty():
		_set_message("Create a world first.")
		return
	var port := RoomCodeSignalingSettings.DEFAULT_GAME_PORT
	host_server_requested.emit(code, port, resolve_resume_world_slug())
