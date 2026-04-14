extends CanvasLayer

@onready var _btn: TextureButton = $Root/PauseOpenButton
@onready var _inventory_btn: TextureButton = $Root/InventoryOpenButton

var _inventory_press_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _btn != null:
		_btn.pressed.connect(_on_pause_pressed)
	if _inventory_btn != null:
		_prep_inventory_open_button_texture()
		_inventory_btn.pressed.connect(_on_inventory_pressed)
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_pause_hud_viewport_changed)
	call_deferred("_on_pause_hud_viewport_changed")


func _on_pause_hud_viewport_changed() -> void:
	_apply_safe_corner_insets()
	_layout_inventory_button_by_hotbar()


func _apply_safe_corner_insets() -> void:
	var ins := UiSafeMargins.insets_for_viewport(get_viewport())
	if _btn != null:
		_btn.offset_left = -56.0 - float(ins.z)
		_btn.offset_top = 12.0 + float(ins.y)
		_btn.offset_right = -12.0 - float(ins.z)
		_btn.offset_bottom = 56.0 + float(ins.y)
	if _inventory_btn != null:
		_inventory_btn.offset_top = -97.0 - float(ins.w)
		_inventory_btn.offset_bottom = -8.0 - float(ins.w)


func _prep_inventory_open_button_texture() -> void:
	var t := _inventory_btn.texture_normal as Texture2D
	if t != null:
		var trimmed := _texture_trim_transparent_edges(t)
		if trimmed != null:
			_inventory_btn.texture_normal = trimmed
	# TextureButton has no horizontal_icon_alignment on all builds; match control aspect to texture so
	# KEEP_ASPECT does not letterbox empty space on the sides after transparent trim.
	_inventory_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT


func _texture_trim_transparent_edges(src: Texture2D) -> Texture2D:
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		return src
	var used := _image_nontransparent_rect(img)
	if used.size.x < 1 or used.size.y < 1:
		return src
	if used.position == Vector2i.ZERO and used.size.x == img.get_width() and used.size.y == img.get_height():
		return src
	var cropped: Image = img.get_region(used)
	if cropped == null:
		return src
	return ImageTexture.create_from_image(cropped)


func _image_nontransparent_rect(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.02:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i(0, 0, w, h)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Place the bag immediately after the last hotbar slot: one `HBoxContainer` separation, using real layout
## rects (minimum-size math did not match on-screen positions).
func _layout_inventory_button_by_hotbar() -> void:
	var avatar := get_parent()
	if avatar == null or _inventory_btn == null:
		return
	var hb: Control = avatar.get_node_or_null("HotBar") as Control
	if hb == null:
		return
	var hbox: HBoxContainer = hb.get_node_or_null("HBoxContainer") as HBoxContainer
	if hbox == null or hbox.get_child_count() < 1:
		return
	var last_slot: Control = hbox.get_child(hbox.get_child_count() - 1) as Control
	if last_slot == null:
		return
	var sep: int = int(hbox.get_theme_constant("separation", "HBoxContainer"))
	if sep <= 0:
		sep = 10
	var gr := last_slot.get_global_rect()
	if gr.size.x < 1.0:
		call_deferred("_layout_inventory_button_by_hotbar")
		return
	## Must match the button's immediate parent ([PauseOpenHud/Root] or [_BagUnderMenuSettings/Root]); using [$Root] after reparent breaks X placement (bag can move off-screen).
	var root: Control = _inventory_btn.get_parent() as Control
	if root == null:
		return
	var rcx := root.size.x * 0.5
	var bag_left_global := gr.position.x + gr.size.x + float(sep)
	var bag_left_in_root := bag_left_global - root.get_global_rect().position.x
	var band_h: float = absf(_inventory_btn.offset_bottom - _inventory_btn.offset_top)
	if band_h < 4.0:
		band_h = 89.0
	var btn_w := 112.0
	var tex := _inventory_btn.texture_normal as Texture2D
	if tex != null:
		var th := float(tex.get_height())
		if th > 0.5:
			btn_w = maxf(40.0, band_h * float(tex.get_width()) / th)
	_inventory_btn.offset_left = bag_left_in_root - rcx
	_inventory_btn.offset_right = _inventory_btn.offset_left + btn_w


func _on_pause_pressed() -> void:
	GameAudio.play_ui_button()
	var avatar := get_parent()
	if avatar == null:
		return
	var mm: Node = avatar.get_tree().root.get_node_or_null("Main/MainMenu")
	if mm != null and mm.has_method("is_settings_overlay_open") and bool(mm.call("is_settings_overlay_open")):
		return
	var pm := avatar.get_node_or_null("PauseMenu")
	if pm != null and pm.has_method("toggle_pause"):
		pm.call("toggle_pause")


func _on_inventory_pressed() -> void:
	GameAudio.play_ui_button()
	var avatar := get_parent()
	if avatar == null:
		return
	var inv := avatar.get_node_or_null("Inventory")
	if inv != null and inv.has_method("toggle_open"):
		inv.call("toggle_open")


## Called from `Inventory.toggle_open()` when opening (E key or bag button) so feedback is shared.
func play_inventory_open_press_feedback() -> void:
	_play_inventory_open_press_feedback()


func _play_inventory_open_press_feedback() -> void:
	var b := _inventory_btn as Control
	if b == null:
		return
	if _inventory_press_tween != null and is_instance_valid(_inventory_press_tween):
		_inventory_press_tween.kill()
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2.ONE
	_inventory_press_tween = create_tween()
	_inventory_press_tween.tween_property(b, "scale", Vector2(0.9, 0.9), 0.07).set_ease(Tween.EASE_IN)
	_inventory_press_tween.tween_property(b, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_BACK)
