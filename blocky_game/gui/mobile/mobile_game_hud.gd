extends Control
## On-screen movement + actions when a touchscreen is available. Drag empty areas (touch look zone) to steer the camera.
## Enable **Preview On Desktop** on this node to test the HUD in the editor on PC (mouse drives joystick + look).
## Layout is recomputed on resize: touch-look bottom margin scales with height; top-right stack avoids overlap and notches.

const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
const Hotbar = preload("res://blocky_game/gui/hotbar/hotbar.gd")
const Block = preload("res://blocky_game/blocks/block.gd")
const Item = preload("res://blocky_game/items/item.gd")
@export var show_fly_toggle: bool = true
@export var preview_on_desktop: bool = false

@onready var _touch_look: Control = $TouchLookZone
@onready var _joystick: Control = $Joystick
@onready var _right_column: Control = $RightColumn
@onready var _top_right_stack: Control = $TopRightStack
@onready var _jump_circle: MobileCircleAction = $RightColumn/JumpCircle
@onready var _up_circle: MobileCircleAction = $RightColumn/UpCircle
@onready var _down_circle: MobileCircleAction = $RightColumn/DownCircle
@onready var _fly_corner: MobileFlyButton = $TopRightStack/FlyCorner
@onready var _place_build: MobileFlyButton = $TopRightStack/PlaceBlock
@onready var _break_build: MobileFlyButton = $TopRightStack/BreakBlock
@onready var _hotbar: Hotbar = get_node("../HotBar")
@onready var _blocks: Node = get_node("/root/Main/Game/Blocks")
@onready var _item_db: Node = get_node("/root/Main/Game/Items")

var _was_flying: bool = false
var _last_place_preview_key: int = -999999

## Top-right stack: ideal geometry from the base design (scaled down on short viewports).
const _TOP_STACK_TOP := 64.0
const _TOP_STACK_IDEAL_BOTTOM := 372.0
const _TOP_STACK_SEP := 4
const _TOP_STACK_ROW_IDEAL := 100
const _TOP_STACK_ROW_MIN := 72
const _JOYSTICK_CLEAR_RIGHT := 196.0
const _JOYSTICK_GAP := 14.0
## Flying: Up circle top ≈ H − 246; keep this margin below that band.
const _FLY_UPDOWN_RESERVE := 258.0
## Touch-look: exclude bottom band so it does not steal HUD touches (right column top ≈ H − 286).
const _TOUCH_LOOK_EXCLUDE_MIN := 286
const _TOUCH_LOOK_EXCLUDE_MAX := 380
const _TOUCH_LOOK_MIN_ABOVE := 120.0


func _ready() -> void:
	var use := DisplayServer.is_touchscreen_available() or preview_on_desktop
	MobileControls.set_desktop_preview(preview_on_desktop)
	visible = use
	MobileControls.set_ui_active(use)
	if not use:
		return
	MobileControls.register_player(get_parent())
	_down_circle.kind = MobileCircleAction.Kind.FLY_DOWN
	_fly_corner.visible = show_fly_toggle
	get_viewport().size_changed.connect(_layout_mobile_hud)
	call_deferred("_release_mouse_for_mobile_ui")
	call_deferred("_layout_mobile_hud")
	_sync_fly_ui(false)
	# Inventory._ready runs after this node; defer so _slots is initialized.
	call_deferred("_sync_place_build_preview", true)


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_layout_mobile_hud):
		get_viewport().size_changed.disconnect(_layout_mobile_hud)
	MobileControls.unregister_player()
	MobileControls.set_ui_active(false)
	MobileControls.set_desktop_preview(false)


func _release_mouse_for_mobile_ui() -> void:
	if not visible:
		return
	var cam := get_parent().get_node_or_null("Camera") as Camera3D
	if cam != null and cam.has_method(&"release_mouse_for_mobile_ui"):
		cam.call(&"release_mouse_for_mobile_ui")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_mobile_hud()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		MobileControls.clear_touch_inputs()
		_jump_circle.release_hold()
		_up_circle.release_hold()
		_down_circle.release_hold()
		_break_build.release_break_hold()


func _process(_delta: float) -> void:
	if not visible:
		return
	var flying := MobileControls.is_player_flying()
	if flying != _was_flying:
		if flying:
			_jump_circle.release_hold()
		else:
			_up_circle.release_hold()
			_down_circle.release_hold()
		_was_flying = flying
		_sync_fly_ui(flying)
	_sync_place_build_preview(false)


func _layout_mobile_hud() -> void:
	if not visible:
		return
	var sz := get_viewport().get_visible_rect().size
	var h := sz.y
	var w := sz.x
	var ins := UiSafeMargins.insets_for_viewport(get_viewport())
	_layout_touch_look(h, ins)
	_layout_bottom_hud_controls(ins)
	_layout_top_right_stack(w, h, ins)


func _layout_touch_look(viewport_h: float, ins: Vector4i) -> void:
	if _touch_look == null:
		return
	var vi := maxi(int(ceil(viewport_h)), 1)
	var target := clampi(int(round(viewport_h * 0.455)), _TOUCH_LOOK_EXCLUDE_MIN, _TOUCH_LOOK_EXCLUDE_MAX)
	var max_exclude := maxi(vi - int(_TOUCH_LOOK_MIN_ABOVE) - ins.w, 0)
	var bot := mini(target, max_exclude)
	_touch_look.offset_top = float(ins.y)
	_touch_look.offset_bottom = -float(bot)


func _layout_bottom_hud_controls(ins: Vector4i) -> void:
	var bx := float(ins.x)
	var bz := float(ins.z)
	var bw := float(ins.w)
	if _joystick != null:
		_joystick.offset_left = 16.0 + bx
		_joystick.offset_right = 196.0 + bx
		_joystick.offset_top = -174.0 - bw
		_joystick.offset_bottom = -24.0 - bw
	if _right_column != null:
		_right_column.offset_left = -176.0 - bz
		_right_column.offset_right = -16.0 - bz
		_right_column.offset_top = -286.0 - bw
		_right_column.offset_bottom = -24.0 - bw


func _layout_top_right_stack(w: float, h: float, ins: Vector4i) -> void:
	if _top_right_stack == null:
		return
	var top_pad := float(ins.y)
	var stack_top := _TOP_STACK_TOP + top_pad
	var want_left := _JOYSTICK_CLEAR_RIGHT + _JOYSTICK_GAP
	var default_left := w - 112.0
	if default_left < want_left:
		_top_right_stack.offset_left = want_left - w
	else:
		_top_right_stack.offset_left = -112.0
	_top_right_stack.offset_right = -12.0 - float(ins.z)
	var h_eff := maxf(80.0, h - float(ins.w))
	var max_bottom := h_eff - _FLY_UPDOWN_RESERVE
	var target_bottom := minf(_TOP_STACK_IDEAL_BOTTOM + top_pad, max_bottom)
	target_bottom = maxf(target_bottom, stack_top + 48.0)
	_top_right_stack.offset_top = stack_top
	_top_right_stack.offset_bottom = target_bottom
	var avail_h := target_bottom - stack_top
	var need := _TOP_STACK_ROW_IDEAL * 3 + _TOP_STACK_SEP * 2
	var row_h := _TOP_STACK_ROW_IDEAL
	if avail_h < float(need):
		row_h = int((avail_h - float(_TOP_STACK_SEP * 2)) / 3.0)
		var row_min := 56
		if avail_h < float(_TOP_STACK_ROW_MIN * 3 + _TOP_STACK_SEP * 2):
			row_min = 48
		row_h = clampi(row_h, row_min, _TOP_STACK_ROW_IDEAL)
	var row_size := Vector2(100, row_h)
	for c in _top_right_stack.get_children():
		if c is Control:
			(c as Control).custom_minimum_size = row_size


func _sync_fly_ui(flying: bool) -> void:
	_jump_circle.visible = not flying
	_up_circle.visible = flying
	_down_circle.visible = flying
	_fly_corner.set_display_label("Land" if flying else "Fly")


func _sync_place_build_preview(force: bool) -> void:
	var item := _hotbar.get_selected_item()
	var key := _place_preview_key(item)
	if not force and key == _last_place_preview_key:
		return
	_last_place_preview_key = key
	var tex: Texture2D = null
	if item != null:
		if item.type == InventoryItem.TYPE_BLOCK:
			var b: Block = _blocks.get_block(item.id)
			tex = b.base_info.sprite_texture
		elif item.type == InventoryItem.TYPE_ITEM:
			var it: Item = _item_db.get_item(item.id)
			tex = it.base_info.sprite
	_place_build.set_preview_texture(tex)


func _place_preview_key(item: InventoryItem) -> int:
	if item == null:
		return -1
	return item.type * 1_000_003 + item.id
