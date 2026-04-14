extends CanvasLayer

@onready var _pause_center: Control = $CenterContainer
@onready var _exit_center: Control = $ExitConfirmLayer/ExitCenter
@onready var _pause_panel: PanelContainer = $CenterContainer/PanelContainer
@onready var _world_line: Label = $CenterContainer/PanelContainer/Margin/VBox/WorldLine
@onready var _btn_resume: Button = $CenterContainer/PanelContainer/Margin/VBox/Resume
@onready var _btn_save: Button = $CenterContainer/PanelContainer/Margin/VBox/SaveWorld
@onready var _btn_exit: Button = $CenterContainer/PanelContainer/Margin/VBox/ExitToMenu
@onready var _status: Label = $CenterContainer/PanelContainer/Margin/VBox/Status

@onready var _exit_layer: Control = $ExitConfirmLayer
@onready var _exit_body: Label = $ExitConfirmLayer/ExitCenter/ExitPanel/ExitMargin/ExitVBox/ExitBody
@onready var _exit_btn_save_exit: Button = $ExitConfirmLayer/ExitCenter/ExitPanel/ExitMargin/ExitVBox/ExitRowSaveExit

var _game: BlockyVoxelGame = null
var _paused := false


func _set_status(msg: String) -> void:
	if _status != null:
		_status.text = msg


func _set_world_line_display(slug: String) -> void:
	if _world_line != null:
		_world_line.text = "World: %s" % slug


## Same layer as in [character_avatar.tscn]; under [PauseMenu] (120) and [SettingsMenuLayer] (200) so only those fullscreen dims affect brightness ([main_menu._SETTINGS_DIM_OVER_GAME] matches [pause_menu.tscn] dim).
const _PAUSE_OPEN_HUD_LAYER_GAMEPLAY := 100
## Legacy node from older builds; children are merged back into [PauseOpenHud/Root].
const _PAUSE_ONLY_ABOVE_MENU_SETTINGS_NAME := "_PauseOnlyAboveMenuSettings"


func _pause_open_hud_root(hud: CanvasLayer) -> Control:
	return hud.get_node_or_null("Root") as Control


func _pause_avatar() -> Node:
	return get_parent()


func _main_node() -> Node:
	## [get_tree().root] is the root [Window]; the main scene may not be a direct child named "Main",
	## so walking up from the pause menu reliably finds the autoload scene root that owns [MainMenu] / [Game].
	var n: Node = self
	while n != null:
		if str(n.name) == "Main":
			return n
		n = n.get_parent()
	var st := get_tree()
	if st == null:
		return null
	var cs: Node = st.current_scene
	if cs != null:
		return cs
	var r: Node = st.root
	if r != null:
		return r.get_node_or_null("Main")
	return null


func _bag_under_settings_host(mn: Node) -> Node:
	var menu: Node = mn.get_node_or_null("MainMenu") as Node
	return menu if menu != null else mn


func _find_bag_layer_under_main(mn: Node) -> CanvasLayer:
	if mn == null:
		return null
	var host := _bag_under_settings_host(mn)
	var bl := host.get_node_or_null("_BagUnderMenuSettings") as CanvasLayer
	if bl != null:
		return bl
	return mn.get_node_or_null("_BagUnderMenuSettings") as CanvasLayer


## Returns bag + pause controls from legacy [_PauseOnlyAboveMenuSettings] to [PauseOpenHud/Root] after in-game settings close.
func _reparent_corner_hud_from_above_settings_layer(avatar: Node) -> void:
	if avatar == null:
		return
	var hud: CanvasLayer = avatar.get_node_or_null("PauseOpenHud") as CanvasLayer
	if hud == null:
		return
	var pause_root := _pause_open_hud_root(hud)
	var pol: CanvasLayer = avatar.get_node_or_null(_PAUSE_ONLY_ABOVE_MENU_SETTINGS_NAME) as CanvasLayer
	var pr: Control = pol.get_node_or_null("Root") as Control if pol != null else null
	if pause_root == null:
		if pol != null:
			pol.visible = false
		return
	var moved := false
	if pr != null:
		var ib_pr := pr.get_node_or_null("InventoryOpenButton") as TextureButton
		var pb_pr := pr.get_node_or_null("PauseOpenButton") as TextureButton
		if ib_pr != null:
			pause_root.add_child(ib_pr)
			moved = true
		if pb_pr != null:
			pause_root.add_child(pb_pr)
			moved = true
		var ib_home := pause_root.get_node_or_null("InventoryOpenButton") as TextureButton
		var pb_home := pause_root.get_node_or_null("PauseOpenButton") as TextureButton
		if ib_home != null and pb_home != null:
			pause_root.move_child(ib_home, 0)
			pause_root.move_child(pb_home, 1)
		pr.modulate = Color.WHITE
	if pol != null:
		pol.visible = false
	if moved:
		var poh: Node = avatar.get_node_or_null("PauseOpenHud")
		if poh != null and poh.has_method("_on_pause_hud_viewport_changed"):
			poh.call_deferred("_on_pause_hud_viewport_changed")


func _hide_bag_under_menu_settings_layers(avatar: Node) -> void:
	var mn := _main_node()
	if mn != null:
		var blm := _find_bag_layer_under_main(mn)
		if blm != null:
			blm.visible = false
	if avatar != null:
		var bla := avatar.get_node_or_null("_BagUnderMenuSettings") as CanvasLayer
		if bla != null:
			bla.visible = false


func _find_inventory_on_bag_layer(mn: Node, avatar: Node) -> TextureButton:
	if mn != null:
		var bl := _find_bag_layer_under_main(mn)
		if bl != null:
			var br := bl.get_node_or_null("Root") as Control
			if br != null:
				var ib := br.get_node_or_null("InventoryOpenButton") as TextureButton
				if ib != null:
					return ib
	if avatar != null:
		var bl := avatar.get_node_or_null("_BagUnderMenuSettings") as CanvasLayer
		if bl != null:
			var br := bl.get_node_or_null("Root") as Control
			if br != null:
				var ib := br.get_node_or_null("InventoryOpenButton") as TextureButton
				if ib != null:
					return ib
	return null


## Moves [InventoryOpenButton] back from legacy [_BagUnderMenuSettings] to [PauseOpenHud/Root] (scene default order: bag before pause).
func _reparent_inventory_btn_to_pause_open_hud_root() -> void:
	var avatar := _pause_avatar()
	var mn := _main_node()
	if avatar == null:
		return
	var hud: CanvasLayer = avatar.get_node_or_null("PauseOpenHud") as CanvasLayer
	if hud == null:
		return
	var pause_root := _pause_open_hud_root(hud)
	if pause_root == null:
		return
	if pause_root.get_node_or_null("InventoryOpenButton") != null:
		var home: TextureButton = pause_root.get_node_or_null("InventoryOpenButton") as TextureButton
		if home != null:
			home.modulate = Color.WHITE
			home.z_index = 0
			home.visible = true
		_hide_bag_under_menu_settings_layers(avatar)
		return
	var inv := _find_inventory_on_bag_layer(mn, avatar)
	if inv == null:
		return
	pause_root.add_child(inv)
	pause_root.move_child(inv, 0)
	inv.modulate = Color.WHITE
	inv.z_index = 0
	_hide_bag_under_menu_settings_layers(avatar)
	var poh: Node = avatar.get_node_or_null("PauseOpenHud")
	if poh != null and poh.has_method("_on_pause_hud_viewport_changed"):
		poh.call_deferred("_on_pause_hud_viewport_changed")


func _pause_open_hud_set_gameplay() -> void:
	_reparent_corner_hud_from_above_settings_layer(_pause_avatar())
	_reparent_inventory_btn_to_pause_open_hud_root()
	var hud: CanvasLayer = get_parent().get_node_or_null("PauseOpenHud") as CanvasLayer
	if hud == null:
		return
	hud.layer = _PAUSE_OPEN_HUD_LAYER_GAMEPLAY
	hud.visible = true
	var root := _pause_open_hud_root(hud)
	if root != null:
		root.modulate = Color.WHITE
	var pb: Control = hud.get_node_or_null("Root/PauseOpenButton") as Control
	var ib: Control = hud.get_node_or_null("Root/InventoryOpenButton") as Control
	if pb != null:
		pb.visible = true
	if ib != null:
		ib.visible = true


func _pause_open_hud_set_paused() -> void:
	_reparent_corner_hud_from_above_settings_layer(_pause_avatar())
	_reparent_inventory_btn_to_pause_open_hud_root()
	var hud: CanvasLayer = get_parent().get_node_or_null("PauseOpenHud") as CanvasLayer
	if hud == null:
		return
	hud.layer = _PAUSE_OPEN_HUD_LAYER_GAMEPLAY
	hud.visible = true
	var root := _pause_open_hud_root(hud)
	if root != null:
		root.modulate = Color.WHITE
	var pb: Control = hud.get_node_or_null("Root/PauseOpenButton") as Control
	var ib: Control = hud.get_node_or_null("Root/InventoryOpenButton") as Control
	if pb != null:
		pb.modulate = Color.WHITE
		pb.visible = true
	if ib != null:
		ib.modulate = Color.WHITE
		ib.visible = true


## In-game settings: same layer and modulate as [_pause_open_hud_set_paused]; [SettingsMenuLayer] dim matches pause dim so corner icons read like the rest of the screen.
func _pause_open_hud_with_menu_settings_overlay() -> void:
	var avatar := _pause_avatar()
	var mn := _main_node()
	var hud: CanvasLayer = avatar.get_node_or_null("PauseOpenHud") as CanvasLayer
	if hud == null:
		return
	var main_root := _pause_open_hud_root(hud)
	if main_root == null:
		return
	_reparent_corner_hud_from_above_settings_layer(avatar)
	_reparent_inventory_btn_to_pause_open_hud_root()
	var ib := main_root.get_node_or_null("InventoryOpenButton") as TextureButton
	if ib == null:
		ib = _find_inventory_on_bag_layer(mn, avatar)
	var pb := main_root.get_node_or_null("PauseOpenButton") as TextureButton
	hud.layer = _PAUSE_OPEN_HUD_LAYER_GAMEPLAY
	hud.visible = true
	main_root.modulate = Color.WHITE
	if ib != null:
		ib.modulate = Color.WHITE
		ib.visible = true
		ib.z_index = 0
	if pb != null:
		pb.modulate = Color.WHITE
		pb.visible = true
	var poh: Node = avatar.get_node_or_null("PauseOpenHud")
	if poh != null and poh.has_method("_on_pause_hud_viewport_changed"):
		poh.call_deferred("_on_pause_hud_viewport_changed")


func _wire_pause_button_audio(n: Node) -> void:
	for c in n.get_children():
		if c is TextureButton:
			_wire_pause_one_button(c as BaseButton)
		elif c is Button and not (c is CheckBox):
			_wire_pause_one_button(c as BaseButton)
		_wire_pause_button_audio(c)


func _wire_pause_one_button(b: BaseButton) -> void:
	if b.has_meta(&"cc_ui_audio"):
		return
	b.set_meta(&"cc_ui_audio", true)
	b.pressed.connect(func() -> void:
		GameAudio.play_ui_button())


func _ready() -> void:
	hide()
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _btn_resume != null:
		_btn_resume.pressed.connect(_on_resume)
	if _btn_save != null:
		_btn_save.pressed.connect(_on_save)
	if _btn_exit != null:
		_btn_exit.pressed.connect(_on_exit_to_menu_pressed)
	_wire_pause_button_audio(self)
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_refit_pause_safe_layout)
	call_deferred("_refit_pause_safe_layout")


func _refit_pause_safe_layout() -> void:
	var ins := UiSafeMargins.insets_for_viewport(get_viewport())
	var l := float(ins.x)
	var t := float(ins.y)
	var r := float(ins.z)
	var b := float(ins.w)
	if _pause_center != null:
		_pause_center.offset_left = l
		_pause_center.offset_top = t
		_pause_center.offset_right = -r
		_pause_center.offset_bottom = -b
	if _exit_center != null:
		_exit_center.offset_left = l
		_exit_center.offset_top = t
		_exit_center.offset_right = -r
		_exit_center.offset_bottom = -b
	if _pause_panel != null:
		var cw := maxf(200.0, get_viewport().get_visible_rect().size.x - l - r)
		_pause_panel.custom_minimum_size.x = clampf(cw * 0.88, 260.0, minf(420.0, cw * 0.96))


func setup_for_local_player(game: BlockyVoxelGame) -> void:
	_game = game
	_refresh_buttons()


func _refresh_buttons() -> void:
	if _btn_save != null:
		_btn_save.disabled = _game == null
	if _btn_exit != null:
		_btn_exit.disabled = false


func _is_game_settings_overlay_open() -> bool:
	var mm: Node = get_tree().root.get_node_or_null("Main/MainMenu")
	if mm == null or not mm.has_method("is_settings_overlay_open"):
		return false
	return bool(mm.call("is_settings_overlay_open"))


func toggle_pause() -> void:
	if _is_game_settings_overlay_open():
		return
	if _paused:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	if _is_game_settings_overlay_open():
		return
	var inv: Node = get_parent().get_node_or_null("Inventory")
	if inv != null and inv is Control and (inv as Control).visible:
		if inv.has_method(&"close_if_open"):
			inv.call(&"close_if_open")
		else:
			(inv as Control).visible = false
	_refresh_buttons()
	if _game != null:
		_set_world_line_display(_game.get_world_slug())
	_paused = true
	_set_status("")
	_hide_exit_confirm()
	_pause_open_hud_set_paused()
	show()
	GameAudio.play_pause_menu_toggle()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _game != null:
		_game.set_local_gameplay_paused(true)
	var mp := get_tree().get_multiplayer()
	if mp == null or not mp.has_multiplayer_peer():
		get_tree().paused = true


func close_pause() -> void:
	if not _paused:
		return
	GameAudio.play_pause_menu_toggle()
	_paused = false
	_hide_exit_confirm()
	hide()
	_pause_open_hud_set_gameplay()
	if _game != null:
		_game.set_local_gameplay_paused(false)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## After closing in-game settings (MainMenu overlay), show pause again.
func show_after_settings() -> void:
	if _paused:
		show()
		## [open_settings_from_pause] hid [PauseOpenHud]; restore corner pause / inventory buttons for paused state.
		_pause_open_hud_set_paused()


func _hide_exit_confirm() -> void:
	if _exit_layer != null:
		_exit_layer.visible = false
	if _pause_center != null:
		_pause_center.visible = true


func _show_exit_confirm_layer() -> void:
	if _pause_center != null:
		_pause_center.visible = false
	if _exit_layer != null:
		_exit_layer.visible = true


func _on_resume() -> void:
	close_pause()


func _on_save() -> void:
	if _game == null:
		return
	_set_status("Saving…")
	if _btn_save != null:
		_btn_save.disabled = true
	# Singleplayer pause freezes the whole tree; voxel save completion needs frames to advance.
	var was_tree_paused := get_tree().paused
	get_tree().paused = false
	var err: int = await _game.save_via_local_or_host_async()
	get_tree().paused = was_tree_paused
	if _btn_save != null:
		_btn_save.disabled = false
	if err != OK:
		_set_status("Could not save (error %d)." % err)
	else:
		var mp := get_tree().get_multiplayer()
		if mp != null and mp.has_multiplayer_peer() and not mp.is_server():
			_set_status("Host saved the world.")
		else:
			_set_status("Progress saved.")


func _on_settings_pressed() -> void:
	var main := _main_node()
	if main != null and main.has_method("open_settings_from_pause"):
		main.call("open_settings_from_pause")
		hide()
		_pause_open_hud_with_menu_settings_overlay()


func _on_exit_to_menu_pressed() -> void:
	if _game == null:
		return
	if _exit_body == null or _exit_layer == null:
		return
	var mp := get_tree().get_multiplayer()
	var is_net_client := mp != null and mp.has_multiplayer_peer() and not mp.is_server()
	if is_net_client:
		if _exit_btn_save_exit != null:
			_exit_btn_save_exit.visible = true
		_exit_body.text = (
			"Return to the main menu?\n\n"
			+ "Save & exit asks the host to write the world to disk, then you disconnect.")
		_show_exit_confirm_layer()
		return
	if not _game.has_unsaved_world_changes():
		_finish_exit_to_menu(false)
		return
	if _exit_btn_save_exit != null:
		_exit_btn_save_exit.visible = true
	_exit_body.text = (
		"You have unsaved changes in this world.\n\n"
		+ "Exit without saving may lose progress. Save first, or use Save & exit.")
	_show_exit_confirm_layer()


func _on_exit_confirm_cancel() -> void:
	_hide_exit_confirm()


func _on_exit_confirm_no_save() -> void:
	_hide_exit_confirm()
	_finish_exit_to_menu(false)


func _on_exit_confirm_save_exit() -> void:
	_hide_exit_confirm()
	_finish_exit_to_menu(true)


func _finish_exit_to_menu(save_first: bool) -> void:
	close_pause()
	var main := get_tree().root.get_node_or_null("Main")
	if main != null and main.has_method("exit_game_to_menu"):
		main.exit_game_to_menu(save_first)


func _unhandled_input(event: InputEvent) -> void:
	if not _paused or not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _exit_layer != null and _exit_layer.visible:
			_hide_exit_confirm()
			get_viewport().set_input_as_handled()
			return
		close_pause()
		get_viewport().set_input_as_handled()
