extends Control

signal changed

const BAG_COLUMNS = 6
const BAG_SLOT_COUNT = 96
const HOTBAR_SLOT_COUNT = 8
const BAG_SLOT_SIZE = Vector2(64, 64)
const HOTBAR_SLOT_SIZE = Vector2(60, 60)
const PANEL_MAX_WIDTH := 620.0
const PANEL_MAX_HEIGHT := 480.0
const CATEGORY_BLOCKS = 0
const CATEGORY_DECORATIONS = 1
const CATEGORY_COUNT = 2

const InventoryItem = preload("../../player/inventory_item.gd")
const SLOT_SCENE = preload("./inventory_slot.tscn")
const Blocks = preload("../../blocks/blocks.gd")

@onready var _bag_scroll = $Panel/VBoxContainer/ScrollWrap/ScrollContainer
@onready var _bag_content = $Panel/VBoxContainer/ScrollWrap/ScrollContainer/ScrollContent
@onready var _bag_container = $Panel/VBoxContainer/ScrollWrap/ScrollContainer/ScrollContent/GridContainer
@onready var _hotbar_container = $Panel/VBoxContainer/HotbarSection/HBoxContainer
@onready var _dragged_item_view = $DraggedItem
@onready var _panel = $Panel
@onready var _close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var _item_name_label: Label = $Panel/VBoxContainer/ItemNameLabel
@onready var _block_types: Blocks = get_node("/root/Main/Game/Blocks")
@onready var _tabs := [
	$Panel/VBoxContainer/TabBarContainer/BlocksButton,
	$Panel/VBoxContainer/TabBarContainer/DecorationsButton
]

# TODO Is it worth having the hotbar in the first indexes instead of the last ones?
var _slots := []
var _slot_views := []
var _previous_mouse_mode := 0
var _dragged_slot := -1
var _active_tab := 0
var _category_slot_sets := []
var _item_category_by_key := {}


func _ready():
	_bag_container.columns = BAG_COLUMNS
	_bag_scroll.resized.connect(_refresh_bag_grid_layout)
	_close_button.pressed.connect(_close_inventory)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_style_scrollbar()
	_ensure_slot_views(_bag_container, BAG_SLOT_COUNT, BAG_SLOT_SIZE)
	_ensure_slot_views(_hotbar_container, HOTBAR_SLOT_COUNT, HOTBAR_SLOT_SIZE)
	_slots.resize(BAG_SLOT_COUNT + HOTBAR_SLOT_COUNT)
	_init_category_slot_sets()
	_connect_tabs()
	
	# Initial contents
	var hotbar_begin_index := BAG_SLOT_COUNT
	_slots[hotbar_begin_index + 0] = _make_item(InventoryItem.TYPE_BLOCK, 1)
	_slots[hotbar_begin_index + 1] = _make_item(InventoryItem.TYPE_BLOCK, 2)
	_slots[hotbar_begin_index + 2] = _make_item(InventoryItem.TYPE_BLOCK, 3)
	_slots[hotbar_begin_index + 3] = _make_item(InventoryItem.TYPE_BLOCK, 4)
	_slots[hotbar_begin_index + 4] = _make_item(InventoryItem.TYPE_BLOCK, 5)
	_slots[hotbar_begin_index + 5] = _make_item(InventoryItem.TYPE_BLOCK, 6)
	_slots[hotbar_begin_index + 6] = _make_item(InventoryItem.TYPE_BLOCK, 7)
	_slots[hotbar_begin_index + 7] = _make_item(InventoryItem.TYPE_ITEM, 0)
	# Organized builder inventory (base + shape variants grouped together)
	_category_slot_sets[CATEGORY_BLOCKS][0] = _make_item(InventoryItem.TYPE_BLOCK, 27) # stone_bricks_stairs
	_category_slot_sets[CATEGORY_BLOCKS][1] = _make_item(InventoryItem.TYPE_BLOCK, 28) # stone_bricks_slab
	_category_slot_sets[CATEGORY_BLOCKS][2] = _make_item(InventoryItem.TYPE_BLOCK, 12) # stone_bricks
	_category_slot_sets[CATEGORY_BLOCKS][3] = _make_item(InventoryItem.TYPE_BLOCK, 29) # cobble_stairs
	_category_slot_sets[CATEGORY_BLOCKS][4] = _make_item(InventoryItem.TYPE_BLOCK, 30) # cobble_slab
	_category_slot_sets[CATEGORY_BLOCKS][5] = _make_item(InventoryItem.TYPE_BLOCK, 15) # brick_red
	_category_slot_sets[CATEGORY_BLOCKS][6] = _make_item(InventoryItem.TYPE_BLOCK, 33) # brick_red_stairs
	_category_slot_sets[CATEGORY_BLOCKS][7] = _make_item(InventoryItem.TYPE_BLOCK, 34) # brick_red_slab
	_category_slot_sets[CATEGORY_BLOCKS][8] = _make_item(InventoryItem.TYPE_BLOCK, 16) # wood_light
	_category_slot_sets[CATEGORY_BLOCKS][9] = _make_item(InventoryItem.TYPE_BLOCK, 35) # wood_light_stairs
	_category_slot_sets[CATEGORY_BLOCKS][10] = _make_item(InventoryItem.TYPE_BLOCK, 36) # wood_light_slab
	_category_slot_sets[CATEGORY_BLOCKS][11] = _make_item(InventoryItem.TYPE_BLOCK, 14) # sandstone
	_category_slot_sets[CATEGORY_BLOCKS][12] = _make_item(InventoryItem.TYPE_BLOCK, 31) # sandstone_stairs
	_category_slot_sets[CATEGORY_BLOCKS][13] = _make_item(InventoryItem.TYPE_BLOCK, 32) # sandstone_slab
	_category_slot_sets[CATEGORY_BLOCKS][14] = _make_item(InventoryItem.TYPE_BLOCK, 17) # clay
	_category_slot_sets[CATEGORY_BLOCKS][15] = _make_item(InventoryItem.TYPE_BLOCK, 18) # slate
	_category_slot_sets[CATEGORY_BLOCKS][16] = _make_item(InventoryItem.TYPE_BLOCK, 22) # path
	_category_slot_sets[CATEGORY_BLOCKS][17] = _make_item(InventoryItem.TYPE_BLOCK, 19) # stone
	_category_slot_sets[CATEGORY_BLOCKS][18] = _make_item(InventoryItem.TYPE_BLOCK, 20) # smooth_stone
	_category_slot_sets[CATEGORY_BLOCKS][19] = _make_item(InventoryItem.TYPE_BLOCK, 21) # gravel
	_category_slot_sets[CATEGORY_BLOCKS][20] = _make_item(InventoryItem.TYPE_BLOCK, 23) # white_block
	_category_slot_sets[CATEGORY_BLOCKS][21] = _make_item(InventoryItem.TYPE_BLOCK, 24) # black_block
	_category_slot_sets[CATEGORY_BLOCKS][22] = _make_item(InventoryItem.TYPE_BLOCK, 8) # water
	_category_slot_sets[CATEGORY_BLOCKS][23] = _make_item(InventoryItem.TYPE_BLOCK, 13) # cobble
	_category_slot_sets[CATEGORY_BLOCKS][24] = _make_item(InventoryItem.TYPE_BLOCK, 10) # leaves
	_category_slot_sets[CATEGORY_BLOCKS][25] = _make_item(InventoryItem.TYPE_BLOCK, 25) # blue_block
	_category_slot_sets[CATEGORY_BLOCKS][26] = _make_item(InventoryItem.TYPE_BLOCK, 26) # red_block
	_sync_decoration_blocks_to_decorations_tab()
	_refresh_item_category_map_from_category(CATEGORY_BLOCKS)
	_refresh_item_category_map_from_category(CATEGORY_DECORATIONS)
	_remove_hotbar_duplicates_from_all_categories()
	_apply_active_tab_content()

	# Init views
	_slot_views.resize(len(_slots))
	var slot_idx := 0
	for i in _bag_container.get_child_count():
		var slot = _bag_container.get_child(i)
		slot.pressed.connect(_on_slot_pressed.bind(slot_idx))
		_slot_views[slot_idx] = slot
		slot_idx += 1
	for i in _hotbar_container.get_child_count():
		var slot = _hotbar_container.get_child(i)
		slot.pressed.connect(_on_slot_pressed.bind(slot_idx))
		_slot_views[slot_idx] = slot
		slot_idx += 1
	_update_views()
	call_deferred("_refresh_bag_grid_layout")


static func _make_item(type, id):
	var i = InventoryItem.new()
	i.id = id
	i.type = type
	return i


func _update_views():
	for i in len(_slot_views):
		var slot = _slot_views[i]
		if slot != null:
			slot.get_display().set_item(_slots[i])
	_update_bag_slot_visibility()
	_refresh_bag_grid_layout()


func get_hotbar_slot_count() -> int:
	return HOTBAR_SLOT_COUNT


func get_hotbar_slot_data(i) -> InventoryItem:
	var hotbar_begin_index := BAG_SLOT_COUNT
	return _slots[hotbar_begin_index + i]


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_E:
				visible = not visible
			elif visible and event.keycode == KEY_ESCAPE:
				_close_inventory()
				get_viewport().set_input_as_handled()


func _notification(what: int):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_inside_tree():
			print("Visibility changed while not in tree? Eh?")
			return

		if visible:
			_update_views()
			_item_name_label.text = ""
			_previous_mouse_mode = Input.get_mouse_mode()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_play_open_animation()
			
		else:
			if _dragged_slot != -1:
				# Cancel drag
				_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
				_dragged_item_view.stop()
			_dragged_slot = -1
			_dragged_item_view.stop()
			
			Input.set_mouse_mode(_previous_mouse_mode)
			modulate = Color(1, 1, 1, 1)
			_panel.scale = Vector2.ONE


func _on_slot_pressed(idx: int):
	# Keep the rocket launcher permanently pinned in its hotbar slot.
	if _is_locked_hotbar_slot(idx):
		_show_item_name(_slots[idx])
		return
	if _dragged_slot != -1 and _is_locked_hotbar_slot(_dragged_slot):
		_dragged_slot = -1
		_dragged_item_view.stop()
		return

	if _dragged_slot == -1:
		if _slots[idx] == null:
			return
		_show_item_name(_slots[idx])
		if idx < BAG_SLOT_COUNT:
			_set_item_category(_slots[idx], _active_tab)
		# Start drag
		_dragged_slot = idx
		_slot_views[_dragged_slot].get_display().set_item(null)
		_dragged_item_view.start(_slots[idx])
	
	else:
		if _slots[idx] == null:
			# Move
			_slots[idx] = _slots[_dragged_slot]
			_slots[_dragged_slot] = null
			if idx < BAG_SLOT_COUNT:
				_set_item_category(_slots[idx], _active_tab)
			if _dragged_slot < BAG_SLOT_COUNT:
				_category_slot_sets[_active_tab][_dragged_slot] = null
				_compact_category_slots(_active_tab)
				for i in BAG_SLOT_COUNT:
					_slots[i] = _category_slot_sets[_active_tab][i]
			_slot_views[idx].get_display().set_item(_slots[idx])
			_dragged_item_view.stop()
			_dragged_slot = -1
			_update_views()
			emit_signal("changed")
		
		else:
			if _dragged_slot != idx:
				# Replacing bag from hotbar should also finish immediately:
				# move bag item to the now-empty hotbar slot and store dragged hotbar item
				# into the first empty slot of its category.
				if _dragged_slot >= BAG_SLOT_COUNT and idx < BAG_SLOT_COUNT:
					var dragged_hotbar_item: InventoryItem = _slots[_dragged_slot]
					var bag_item: InventoryItem = _slots[idx]
					_slots[idx] = null
					_category_slot_sets[_active_tab][idx] = null
					if _try_store_item_in_its_category(dragged_hotbar_item):
						_slots[_dragged_slot] = bag_item
						_store_current_bag_to_active_category()
						_update_views()
						_dragged_item_view.stop()
						_dragged_slot = -1
						emit_signal("changed")
						return
					# Fallback if category storage is full: restore and do normal swap behavior below.
					_slots[idx] = bag_item
					_category_slot_sets[_active_tab][idx] = bag_item

				# Replacing hotbar from bag should finish immediately:
				# send replaced hotbar item back to its own category,
				# and keep categories consistent regardless active tab.
				if idx >= BAG_SLOT_COUNT and _dragged_slot < BAG_SLOT_COUNT:
					var replaced: InventoryItem = _slots[idx]
					_slots[idx] = _slots[_dragged_slot]
					_slots[_dragged_slot] = null
					_category_slot_sets[_active_tab][_dragged_slot] = null
					if not _try_store_item_in_its_category(replaced):
						# Fallback if destination category is full.
						_slots[_dragged_slot] = replaced
						_category_slot_sets[_active_tab][_dragged_slot] = replaced
					_store_current_bag_to_active_category()
					_update_views()
					_dragged_item_view.stop()
					_dragged_slot = -1
					emit_signal("changed")
					return

				# If replacing hotbar item, auto-return replaced item to its category.
				if idx >= BAG_SLOT_COUNT and _try_store_item_in_its_category(_slots[idx]):
					_slots[idx] = _slots[_dragged_slot]
					if idx < BAG_SLOT_COUNT:
						_set_item_category(_slots[idx], _active_tab)
					_slots[_dragged_slot] = null
					_slot_views[idx].get_display().set_item(_slots[idx])
					if _dragged_slot < len(_slot_views):
						_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
					_update_views()
					_dragged_item_view.stop()
					_dragged_slot = -1
				else:
					# Swap
					var tmp = _slots[idx]
					_slots[idx] = _slots[_dragged_slot]
					_slots[_dragged_slot] = tmp
					if idx < BAG_SLOT_COUNT:
						_set_item_category(_slots[idx], _active_tab)
					_dragged_item_view.start(tmp)

			else:
				_dragged_slot = -1
				_dragged_item_view.stop()

			_slot_views[idx].get_display().set_item(_slots[idx])

			emit_signal("changed")


func _is_locked_hotbar_slot(idx: int) -> bool:
	var locked_idx := BAG_SLOT_COUNT + HOTBAR_SLOT_COUNT - 1
	if idx != locked_idx:
		return false
	var item: InventoryItem = _slots[idx]
	return item != null and item.type == InventoryItem.TYPE_ITEM and item.id == 0


func _ensure_slot_views(container: Control, count: int, slot_size: Vector2) -> void:
	for c in container.get_children():
		c.queue_free()
	for i in count:
		var slot = SLOT_SCENE.instantiate()
		slot.custom_minimum_size = slot_size
		container.add_child(slot)
	call_deferred("_refresh_bag_grid_layout")


func _update_bag_slot_visibility() -> void:
	if _bag_container == null:
		return
	for i in BAG_SLOT_COUNT:
		var slot := _bag_container.get_child(i)
		if slot != null:
			var has_item: bool = _slots[i] != null
			slot.visible = has_item
			slot.mouse_filter = Control.MOUSE_FILTER_STOP if has_item else Control.MOUSE_FILTER_IGNORE
			slot.custom_minimum_size = BAG_SLOT_SIZE if has_item else Vector2.ZERO


func _connect_tabs() -> void:
	for i in len(_tabs):
		var tab_btn: Button = _tabs[i]
		tab_btn.pressed.connect(_on_tab_pressed.bind(i))
	_set_active_tab(0, false)


func _on_tab_pressed(idx: int) -> void:
	_set_active_tab(idx, true)


func _set_active_tab(idx: int, animate_grid: bool) -> void:
	_store_current_bag_to_active_category()
	_active_tab = idx
	_apply_active_tab_content()
	for i in len(_tabs):
		var b: Button = _tabs[i]
		b.button_pressed = i == _active_tab
	if animate_grid:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_bag_container, "modulate", Color(1, 1, 1, 0.78), 0.08)
		tween.tween_property(_bag_container, "modulate", Color(1, 1, 1, 1), 0.12)


func _store_current_bag_to_active_category() -> void:
	for i in BAG_SLOT_COUNT:
		_category_slot_sets[_active_tab][i] = _slots[i]


func _apply_active_tab_content() -> void:
	_remove_hotbar_duplicates_from_all_categories()
	for i in BAG_SLOT_COUNT:
		_slots[i] = _category_slot_sets[_active_tab][i]
	_update_views()
	_refresh_bag_grid_layout()


func _is_same_item(a: InventoryItem, b: InventoryItem) -> bool:
	if a == null or b == null:
		return false
	return a.type == b.type and a.id == b.id


func _remove_hotbar_duplicates_from_all_categories() -> void:
	var hotbar_begin_index := BAG_SLOT_COUNT
	var hotbar_items: Array[InventoryItem] = []
	for i in HOTBAR_SLOT_COUNT:
		var h: InventoryItem = _slots[hotbar_begin_index + i]
		if h != null:
			hotbar_items.append(h)
	if hotbar_items.is_empty():
		return

	for ci in CATEGORY_COUNT:
		for i in BAG_SLOT_COUNT:
			var bag_item: InventoryItem = _category_slot_sets[ci][i]
			if bag_item == null:
				continue
			for h in hotbar_items:
				if _is_same_item(bag_item, h):
					_category_slot_sets[ci][i] = null
					break
		_compact_category_slots(ci)


func _compact_category_slots(category_idx: int) -> void:
	var compacted := []
	compacted.resize(BAG_SLOT_COUNT)
	var write_i := 0
	for i in BAG_SLOT_COUNT:
		var it: InventoryItem = _category_slot_sets[category_idx][i]
		if it != null:
			compacted[write_i] = it
			write_i += 1
	_category_slot_sets[category_idx] = compacted


func _init_category_slot_sets() -> void:
	_category_slot_sets.clear()
	for ci in CATEGORY_COUNT:
		var category_slots := []
		category_slots.resize(BAG_SLOT_COUNT)
		_category_slot_sets.append(category_slots)


func _item_key(item: InventoryItem) -> String:
	if item == null:
		return ""
	return str(item.type, ":", item.id)


func _set_item_category(item: InventoryItem, category_idx: int) -> void:
	if item == null:
		return
	_item_category_by_key[_item_key(item)] = category_idx


func _get_item_category(item: InventoryItem) -> int:
	if item == null:
		return CATEGORY_BLOCKS
	var key := _item_key(item)
	if _item_category_by_key.has(key):
		return int(_item_category_by_key[key])
	if item.type == InventoryItem.TYPE_BLOCK:
		if _block_types != null and item.id >= 0 and item.id < _block_types.get_block_count():
			var block = _block_types.get_block(item.id)
			if block != null:
				if block.base_info.category == "decorations":
					return CATEGORY_DECORATIONS
		return CATEGORY_BLOCKS
	return CATEGORY_DECORATIONS


func _sync_decoration_blocks_to_decorations_tab() -> void:
	if _block_types == null:
		return

	var deco_ids: Array[int] = []
	for bid in _block_types.get_block_count():
		var block = _block_types.get_block(bid)
		if block != null and block.base_info.category == "decorations":
			deco_ids.append(bid)

	if deco_ids.is_empty():
		return

	for ci in CATEGORY_COUNT:
		for i in BAG_SLOT_COUNT:
			var item: InventoryItem = _category_slot_sets[ci][i]
			if item == null or item.type != InventoryItem.TYPE_BLOCK:
				continue
			if deco_ids.has(item.id):
				_category_slot_sets[ci][i] = null
		_compact_category_slots(ci)

	var write_i := 0
	for bid in deco_ids:
		if write_i >= BAG_SLOT_COUNT:
			break
		_category_slot_sets[CATEGORY_DECORATIONS][write_i] = _make_item(InventoryItem.TYPE_BLOCK, bid)
		write_i += 1


func _refresh_item_category_map_from_category(category_idx: int) -> void:
	for i in BAG_SLOT_COUNT:
		var item: InventoryItem = _category_slot_sets[category_idx][i]
		_set_item_category(item, category_idx)


func _try_store_item_in_its_category(item: InventoryItem) -> bool:
	if item == null:
		return true
	var category_idx := _get_item_category(item)
	for i in BAG_SLOT_COUNT:
		if _category_slot_sets[category_idx][i] == null:
			_category_slot_sets[category_idx][i] = item
			_set_item_category(item, category_idx)
			if category_idx == _active_tab:
				_slots[i] = item
			return true
	return false


func _clamp_panel_size() -> void:
	var screen := get_viewport_rect().size
	var anchor_w: float = screen.x * (_panel.anchor_right - _panel.anchor_left)
	var anchor_h: float = screen.y * (_panel.anchor_bottom - _panel.anchor_top)
	if anchor_w > PANEL_MAX_WIDTH:
		var excess := anchor_w - PANEL_MAX_WIDTH
		_panel.offset_left = excess * 0.5
		_panel.offset_right = -excess * 0.5
	else:
		_panel.offset_left = 0
		_panel.offset_right = 0
	if anchor_h > PANEL_MAX_HEIGHT:
		var excess_v := anchor_h - PANEL_MAX_HEIGHT
		_panel.offset_top = excess_v * 0.5
		_panel.offset_bottom = -excess_v * 0.5
	else:
		_panel.offset_top = 0
		_panel.offset_bottom = 0


func _play_open_animation() -> void:
	_clamp_panel_size()
	_refresh_bag_grid_layout()
	modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.98, 0.98)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.2)


func _process(_delta: float) -> void:
	# Keep horizontal scroll locked so touch-drag only scrolls vertically.
	if visible and _bag_scroll != null and _bag_scroll.scroll_horizontal != 0:
		_bag_scroll.scroll_horizontal = 0
		_refresh_bag_grid_layout()


func _refresh_bag_grid_layout() -> void:
	if _bag_scroll == null or _bag_container == null or _bag_content == null:
		return
	_bag_scroll.scroll_horizontal = 0
	var visible_count := 0
	for i in BAG_SLOT_COUNT:
		if _slots[i] != null:
			visible_count = i + 1
	var cols := mini(BAG_COLUMNS, visible_count)
	var rows := int(ceil(float(visible_count) / float(BAG_COLUMNS))) if visible_count > 0 else 0
	var hsep: int = _bag_container.get_theme_constant("h_separation")
	var vsep: int = _bag_container.get_theme_constant("v_separation")
	var grid_w := cols * int(BAG_SLOT_SIZE.x) + maxi(0, cols - 1) * hsep
	var grid_h := rows * int(BAG_SLOT_SIZE.y) + maxi(0, rows - 1) * vsep
	var grid_min := Vector2(grid_w, grid_h)
	var view_w: float = _bag_scroll.size.x
	var content_w: float = maxf(view_w, grid_min.x)
	_bag_content.custom_minimum_size = Vector2(content_w, grid_min.y)
	var offset_x: int = maxi(0, int((content_w - grid_min.x) * 0.5))
	_bag_container.position = Vector2(offset_x, 0)


func _style_scrollbar() -> void:
	var vbar: VScrollBar = _bag_scroll.get_v_scroll_bar()
	if vbar == null:
		return
	vbar.custom_minimum_size = Vector2(12, 0)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0)
	track.corner_radius_top_left = 6
	track.corner_radius_top_right = 6
	track.corner_radius_bottom_right = 6
	track.corner_radius_bottom_left = 6
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = Color(0.72, 0.86, 1.0, 0.95)
	grabber.corner_radius_top_left = 6
	grabber.corner_radius_top_right = 6
	grabber.corner_radius_bottom_right = 6
	grabber.corner_radius_bottom_left = 6
	var grabber_hover: StyleBoxFlat = StyleBoxFlat.new()
	grabber_hover.bg_color = Color(0.84, 0.93, 1.0, 1.0)
	grabber_hover.corner_radius_top_left = 6
	grabber_hover.corner_radius_top_right = 6
	grabber_hover.corner_radius_bottom_right = 6
	grabber_hover.corner_radius_bottom_left = 6
	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_hover)


func _show_item_name(item: InventoryItem) -> void:
	if item == null:
		_item_name_label.text = ""
		return
	if item.type == InventoryItem.TYPE_BLOCK:
		if _block_types != null and item.id >= 0 and item.id < _block_types.get_block_count():
			var block = _block_types.get_block(item.id)
			_item_name_label.text = block.base_info.display_name
			return
	elif item.type == InventoryItem.TYPE_ITEM:
		match item.id:
			0: _item_name_label.text = "Rocket Launcher"
			_: _item_name_label.text = "Item"
		return
	_item_name_label.text = ""


func _on_viewport_resized() -> void:
	if visible:
		_clamp_panel_size()
		_refresh_bag_grid_layout()


func _close_inventory() -> void:
	visible = false
