extends CenterContainer

const InventoryItem = preload("../../player/inventory_item.gd")
const _BASE_OFFSET_TOP := -97.0

@onready var _selected_frame = $HBoxContainer/HotbarSlot/HotbarSlotSelect
@onready var _slot_container = $HBoxContainer
@onready var _block_types = get_node(^"/root/Main/Game/Blocks")
@onready var _inventory = get_node(^"../Inventory")
@onready var _selected_label: Label = $SelectedLabel

var _hotbar_index := 0
var _label_tween: Tween
var _hotbar_slot_clicks_wired := false


func _ready():
	if _selected_label != null:
		_selected_label.modulate = Color(1, 1, 1, 0)
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_apply_safe_bottom_inset)
	call_deferred("_apply_safe_bottom_inset")
	call_deferred("_update_views")
	call_deferred("_show_selected_name")
	call_deferred("_connect_hotbar_slot_clicks")


func _connect_hotbar_slot_clicks() -> void:
	if _hotbar_slot_clicks_wired:
		return
	_hotbar_slot_clicks_wired = true
	for i in _slot_container.get_child_count():
		var slot: Control = _slot_container.get_child(i) as Control
		if slot == null:
			continue
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_hotbar_slot_gui_input.bind(i))


func _on_hotbar_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			select_slot(slot_index)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			select_slot(slot_index)


func _apply_safe_bottom_inset() -> void:
	var ins := UiSafeMargins.insets_for_viewport(get_viewport())
	offset_top = _BASE_OFFSET_TOP - float(ins.w)


func _update_views():
	for i in _inventory.get_hotbar_slot_count():
		var slot_data = _inventory.get_hotbar_slot_data(i)
		var slot_view = _slot_container.get_child(i)
		slot_view.get_display().set_item(slot_data)


func select_slot(i: int):
	if _hotbar_index == i:
		return
	assert(i >= 0 and i < _inventory.get_hotbar_slot_count())
	GameAudio.play_hotbar_slot_change()
	_hotbar_index = i
	
	var item = _inventory.get_hotbar_slot_data(_hotbar_index)
	if item != null:
		if item.type == InventoryItem.TYPE_BLOCK:
			var block = _block_types.get_block(item.id)
			print("Hotbar select block ", block.base_info.name)
			
		elif item.type == InventoryItem.TYPE_ITEM:
			# TODO Item db
			print("Hotbar select item ", item.id)
	
	_selected_frame.get_parent().remove_child(_selected_frame)
	var slot = _slot_container.get_child(i)
	slot.add_child(_selected_frame)
	_show_selected_name()


func get_selected_item() -> InventoryItem:
	return _inventory.get_hotbar_slot_data(_hotbar_index)


func try_select_slot_by_block_id(block_id: int):
	for i in _inventory.get_hotbar_slot_count():
		var item = _inventory.get_hotbar_slot_data(i)
		if item == null:
			continue
		if item.type == InventoryItem.TYPE_BLOCK:
			if item.id == block_id:
				select_slot(i)
				break


func select_next_slot():
	var i = _hotbar_index + 1
	if i >= _inventory.get_hotbar_slot_count():
		i = 0
	select_slot(i)


func select_previous_slot():
	var i = _hotbar_index - 1
	if i < 0:
		i = _inventory.get_hotbar_slot_count() - 1
	select_slot(i)


func _show_selected_name() -> void:
	if _selected_label == null:
		return
	_selected_label.text = ""
	_selected_label.modulate = Color(1, 1, 1, 0)


static func _get_item_display_name(id: int) -> String:
	match id:
		0: return "Rocket Launcher"
		_: return "Item"


func _on_Inventory_changed():
	_update_views()
	_show_selected_name()
