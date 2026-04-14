extends Node
## Autoload: virtual joystick + touch buttons write here; `character_controller` reads each physics tick.

var move_vector: Vector2 = Vector2.ZERO
var jump_held: bool = false
var fly_down_held: bool = false
var _break_pending: bool = false
var _place_pending: bool = false

var _ui_active: bool = false
var _player: Node = null
var _desktop_preview: bool = false


func set_desktop_preview(on: bool) -> void:
	_desktop_preview = on


func is_desktop_preview() -> bool:
	return _desktop_preview


func set_ui_active(active: bool) -> void:
	_ui_active = active
	if not active:
		clear_touch_inputs()


func is_ui_active() -> bool:
	return _ui_active


func set_move_vector(v: Vector2) -> void:
	move_vector = v


func request_place_block() -> void:
	if _ui_active:
		_place_pending = true


func consume_place_block() -> bool:
	if not _ui_active:
		return false
	var p := _place_pending
	_place_pending = false
	return p


func request_break_block() -> void:
	if _ui_active:
		_break_pending = true


func consume_break_block() -> bool:
	if not _ui_active:
		return false
	var b := _break_pending
	_break_pending = false
	return b


func clear_touch_inputs() -> void:
	move_vector = Vector2.ZERO
	jump_held = false
	fly_down_held = false
	_break_pending = false
	_place_pending = false


func register_player(player: Node) -> void:
	_player = player


func unregister_player() -> void:
	_player = null


func get_move_vector() -> Vector2:
	return move_vector if _ui_active else Vector2.ZERO


func is_jump_held() -> bool:
	return jump_held if _ui_active else false


func is_fly_down_held() -> bool:
	return fly_down_held if _ui_active else false


func is_player_flying() -> bool:
	if _player != null and _player.has_method(&"is_character_flying"):
		return bool(_player.call(&"is_character_flying"))
	return false


func toggle_player_fly() -> void:
	if _player != null and _player.has_method(&"mobile_toggle_fly"):
		_player.call(&"mobile_toggle_fly")
