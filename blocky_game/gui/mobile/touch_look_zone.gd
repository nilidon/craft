extends Control
## Invisible drag area; forwards motion to the avatar camera for touch look.

var _mouse_look_drag := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var cam := get_node_or_null("../Camera") as Camera3D
	if cam == null or not cam.has_method(&"apply_touch_look_pixels"):
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		cam.call(&"apply_touch_look_pixels", sd.relative)
	elif MobileControls.is_desktop_preview():
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_mouse_look_drag = mb.pressed
		elif event is InputEventMouseMotion and _mouse_look_drag:
			var mm := event as InputEventMouseMotion
			cam.call(&"apply_touch_look_pixels", mm.relative)
