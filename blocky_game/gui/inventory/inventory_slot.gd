extends Control

signal pressed

const InventoryItemDisplay = preload("../inventory_item_display.gd")

@onready var _select_bg = $SelectBG
@onready var _display = $TextureRect


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			emit_signal("pressed")


func _notification(what: int):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_select_bg.visible = true
			create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(self, "modulate", Color(1.08, 1.08, 1.08, 1), 0.12)
		
		NOTIFICATION_MOUSE_EXIT:
			_select_bg.visible = false
			create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(self, "modulate", Color(1, 1, 1, 1), 0.12)

		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_select_bg.visible = false
				modulate = Color(1, 1, 1, 1)


func get_display() -> InventoryItemDisplay:
	return _display

