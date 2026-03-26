extends Node

const Util = preload("res://common/util.gd")
const Blocks = preload("../blocks/blocks.gd")
const ItemDB = preload("../items/item_db.gd")
const InventoryItem = preload("./inventory_item.gd")
const Hotbar = preload("../gui/hotbar/hotbar.gd")
const WaterUpdater = preload("./../water.gd")
const InteractionCommon = preload("./interaction_common.gd")

const COLLISION_LAYER_AVATAR = 2
const SERVER_PEER_ID = 1
const PLAYER_UNDERPLACE_MAX_Y_OFFSET = 0.05
const BUILD_HEIGHT_LIMIT = InteractionCommon.BUILD_HEIGHT_LIMIT
const PILLAR_LOOK_DOWN_THRESHOLD = 0.25
const PLAYER_FEET_OFFSET = 0.9
const PILLAR_CORRECTION_MAX_UPWARD_SPEED = 0.05
const MAX_PILLAR_FEET_GAP = 0.35
const BUILD_HEIGHT_HINT_DURATION_SEC := 2.5

const _hotbar_keys = {
	KEY_1: 0,
	KEY_2: 1,
	KEY_3: 2,
	KEY_4: 3,
	KEY_5: 4,
	KEY_6: 5,
	KEY_7: 6,
	KEY_8: 7
}

@export var terrain_path : NodePath
@export var cursor_material : Material

# TODO Eventually invert these dependencies
@onready var _head : Camera3D = get_parent().get_node("Camera")
@onready var _hotbar : Hotbar = get_node("../HotBar")
@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _item_db : ItemDB = get_node("/root/Main/Game/Items")
@onready var _water_updater : WaterUpdater
@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _players_container : Node = get_node_or_null("/root/Main/Game/Players")

var _terrain_tool : VoxelTool = null
var _cursor : MeshInstance3D = null
var _action_place := false
var _action_use := false
var _action_pick := false
var _prev_self_y := 0.0
var _estimated_self_vy := 0.0
var _build_limit_hint_label: Label
var _build_limit_hint_time := 0.0
var _build_hint_canvas_layer: CanvasLayer


func _ready():
	var mesh := Util.create_wirecube_mesh(Color(0,0,0))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if cursor_material != null:
		mesh_instance.material_override = cursor_material
	mesh_instance.set_scale(Vector3(1,1,1)*1.01)
	_cursor = mesh_instance
	
	_terrain.add_child(_cursor)
	_terrain_tool = _terrain.get_voxel_tool()
	_terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_prev_self_y = get_parent().position.y

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() == false or mp.is_server():
		_water_updater = get_node("/root/Main/Game/Water")

	_setup_build_height_hint()


func _setup_build_height_hint() -> void:
	# UI under Node3D (the avatar) often does not get a proper viewport rect — use a
	# CanvasLayer under the game root (plain Node) so this always draws in screen space.
	var game_root: Node = get_node_or_null("/root/Main/Game")
	if game_root == null:
		game_root = get_tree().current_scene
	if game_root == null:
		push_error("Build height hint: could not find game root")
		return

	_build_hint_canvas_layer = game_root.get_node_or_null("BuildHeightHintLayer") as CanvasLayer
	if _build_hint_canvas_layer == null:
		_build_hint_canvas_layer = CanvasLayer.new()
		_build_hint_canvas_layer.name = "BuildHeightHintLayer"
		_build_hint_canvas_layer.layer = 30
		game_root.add_child(_build_hint_canvas_layer)

		var root_ctl := Control.new()
		root_ctl.name = "Root"
		root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_build_hint_canvas_layer.add_child(root_ctl)

		_build_limit_hint_label = Label.new()
		_build_limit_hint_label.name = "HintLabel"
		# HotBar is bottom-anchored with offset_top = -97; sit just above that band.
		_build_limit_hint_label.anchor_left = 0.0
		_build_limit_hint_label.anchor_top = 1.0
		_build_limit_hint_label.anchor_right = 1.0
		_build_limit_hint_label.anchor_bottom = 1.0
		_build_limit_hint_label.offset_left = 0.0
		_build_limit_hint_label.offset_top = -122.0
		_build_limit_hint_label.offset_right = 0.0
		_build_limit_hint_label.offset_bottom = -99.0
		_build_limit_hint_label.add_theme_font_size_override("font_size", 20)
		_build_limit_hint_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_build_limit_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		_build_limit_hint_label.add_theme_constant_override("outline_size", 6)
		_build_limit_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_build_limit_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_build_limit_hint_label.visible = false
		root_ctl.add_child(_build_limit_hint_label)
	else:
		_build_limit_hint_label = _build_hint_canvas_layer.get_node("Root/HintLabel") as Label

	_build_limit_hint_label.text = "Max build height (%d)" % BUILD_HEIGHT_LIMIT


func _show_build_height_hint() -> void:
	if _build_limit_hint_label == null:
		return
	_build_limit_hint_label.visible = true
	_build_limit_hint_time = BUILD_HEIGHT_HINT_DURATION_SEC


func _get_pointed_voxel() -> VoxelRaycastResult:
	var origin := _head.get_global_transform().origin
	assert(not Util.vec3_has_nan(origin))
	var forward := -_head.get_transform().basis.z.normalized()
	var hit := _terrain_tool.raycast(origin, forward, 10)
	return hit


func _physics_process(_delta):
	if _terrain == null:
		return

	var self_player := get_parent()
	if self_player is Node3D and _delta > 0.0:
		_estimated_self_vy = (self_player.position.y - _prev_self_y) / _delta
		_prev_self_y = self_player.position.y

	if _build_limit_hint_time > 0.0:
		_build_limit_hint_time -= _delta
		if _build_limit_hint_time <= 0.0 and _build_limit_hint_label != null:
			_build_limit_hint_label.visible = false
	
	var hit := _get_pointed_voxel()
	var inv_item := _hotbar.get_selected_item()

	if hit != null:
		var cursor_pos := hit.position
		if inv_item == null or inv_item.type == InventoryItem.TYPE_BLOCK:
			var hit_raw_id := _terrain_tool.get_voxel(hit.position)
			var has_cube := hit_raw_id != 0
			cursor_pos = _get_place_target_from_hit(hit, has_cube)
		_cursor.show()
		_cursor.set_position(cursor_pos)
		pass # DDD.set_text("Pointed voxel", str(cursor_pos))
	else:
		_cursor.hide()
		pass # DDD.set_text("Pointed voxel", "---")
	
	# These inputs have to be in _fixed_process because they rely on collision queries
	if inv_item == null or inv_item.type == InventoryItem.TYPE_BLOCK:
		if hit != null:
			var hit_raw_id := _terrain_tool.get_voxel(hit.position)
			var has_cube := hit_raw_id != 0
			
			if _action_use and has_cube:
				var pos = hit.position
				_place_single_block(pos, 0)
			
			elif _action_place:
				var pos := _get_place_target_from_hit(hit, has_cube)
				var placed := false
				if _can_place_voxel_at(pos):
					if inv_item != null:
						_place_single_block(pos, inv_item.id)
						print("Place voxel at ", pos)
						placed = true
				# Fallback to pillar only if direct looked-at placement failed.
				if (
					not placed
					and inv_item != null
					and _head.global_transform.basis.z.y > PILLAR_LOOK_DOWN_THRESHOLD
					and _can_pillar_place_now()
				):
					placed = _try_pillar_place(inv_item.id)
				if not placed:
					if pos.y >= BUILD_HEIGHT_LIMIT:
						_show_build_height_hint()
					else:
						print("Can't place here!")
				
	elif inv_item.type == InventoryItem.TYPE_ITEM:
		if _action_use:
			var item = _item_db.get_item(inv_item.id)
			item.use(_head.global_transform)
	
	if _action_pick and hit != null:
		var hit_raw_id = _terrain_tool.get_voxel(hit.position)
		var rm := _block_types.get_raw_mapping(hit_raw_id)
		_hotbar.try_select_slot_by_block_id(rm.block_id)

	_action_place = false
	_action_use = false
	_action_pick = false


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_action_use = true
				MOUSE_BUTTON_RIGHT:
					_action_place = true
				MOUSE_BUTTON_MIDDLE:
					_action_pick = true
				MOUSE_BUTTON_WHEEL_DOWN:
					_hotbar.select_next_slot()
				MOUSE_BUTTON_WHEEL_UP:
					_hotbar.select_previous_slot()

	elif event is InputEventKey:
		if event.pressed:
			if _hotbar_keys.has(event.keycode):
				var slot_index = _hotbar_keys[event.keycode]
				_hotbar.select_slot(slot_index)


func _can_place_voxel_at(pos: Vector3) -> bool:
	if pos.y >= BUILD_HEIGHT_LIMIT:
		return false

	if _is_under_local_player(pos):
		return true

	var space_state := get_viewport().get_world_3d().get_direct_space_state()
	var params := PhysicsShapeQueryParameters3D.new()
	params.collision_mask = COLLISION_LAYER_AVATAR
	params.transform = Transform3D(Basis(), pos + Vector3(1,1,1)*0.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	params.set_shape(shape)
	var hits := space_state.intersect_shape(params)
	return hits.size() == 0 and not _intersects_any_player(pos)


func _get_place_target_from_hit(hit: VoxelRaycastResult, has_cube: bool) -> Vector3:
	if has_cube:
		return hit.previous_position
	return hit.position


func _is_under_local_player(pos: Vector3) -> bool:
	var self_player := get_parent()
	if not (self_player is Node3D):
		return false
	var placed_top_y := pos.y + 1.0
	return placed_top_y <= self_player.position.y + PLAYER_UNDERPLACE_MAX_Y_OFFSET


func _try_pillar_place(block_id: int) -> bool:
	var self_player := get_parent()
	if not (self_player is Node3D):
		return false
	var p: Vector3 = self_player.position
	var feet_y := p.y - PLAYER_FEET_OFFSET
	var pos := Vector3(floor(p.x), floor(feet_y + 0.001), floor(p.z))
	if pos.y >= BUILD_HEIGHT_LIMIT:
		_show_build_height_hint()
		return false
	if _terrain_tool.get_voxel(pos) != 0:
		return false
	if _intersects_other_players(pos, self_player):
		return false
	_place_single_block(pos, block_id)
	# Only apply the minimal correction needed to avoid clipping and reduce camera snapping.
	var min_safe_y := pos.y + 1.0 + PLAYER_FEET_OFFSET
	if _estimated_self_vy <= PILLAR_CORRECTION_MAX_UPWARD_SPEED and self_player.position.y < min_safe_y:
		self_player.position.y = min_safe_y
	return true


func _can_pillar_place_now() -> bool:
	var self_player: Node3D = get_parent() as Node3D
	if not (self_player is Node3D):
		return false
	if _estimated_self_vy > PILLAR_CORRECTION_MAX_UPWARD_SPEED:
		return false
	var feet_y: float = self_player.position.y - PLAYER_FEET_OFFSET
	var under_y: float = floor(feet_y + 0.001)
	var gap: float = feet_y - (under_y + 1.0)
	return gap <= MAX_PILLAR_FEET_GAP


func _intersects_other_players(pos: Vector3, ignored_player: Node3D) -> bool:
	if _players_container == null:
		return false
	var placed_aabb := AABB(pos, Vector3.ONE)
	for i in _players_container.get_child_count():
		var player := _players_container.get_child(i)
		if player == ignored_player:
			continue
		if not (player is Node3D):
			continue
		var p: Vector3 = player.position
		var player_aabb := AABB(
			p + Vector3(-0.4, -0.9, -0.4),
			Vector3(0.8, 1.8, 0.8)
		)
		if player_aabb.intersects(placed_aabb):
			return true
	return false


func _intersects_any_player(pos: Vector3) -> bool:
	if _players_container == null:
		return false

	var placed_aabb := AABB(pos, Vector3.ONE)
	var placed_top_y := pos.y + 1.0
	for i in _players_container.get_child_count():
		var player := _players_container.get_child(i)
		if not (player is Node3D):
			continue
		var p: Vector3 = player.position
		# Allow placing blocks under players (up to body center),
		# so tower-building works even when camera/player height changes.
		if placed_top_y <= p.y + PLAYER_UNDERPLACE_MAX_Y_OFFSET:
			continue
		# Keep in sync with character_controller.gd collision box dimensions.
		var player_aabb := AABB(
			p + Vector3(-0.4, -0.9, -0.4),
			Vector3(0.8, 1.8, 0.8)
		)
		if player_aabb.intersects(placed_aabb):
			return true
	return false


func _place_single_block(pos: Vector3, block_id: int):
	var look_dir := -_head.get_transform().basis.z
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_place_single_block", pos, look_dir, block_id)
	else:
		var ok := InteractionCommon.place_single_block(_terrain_tool, pos, look_dir,
			block_id, _block_types, _water_updater)
		if not ok and block_id != Blocks.AIR_ID and pos.y >= BUILD_HEIGHT_LIMIT:
			_show_build_height_hint()


# TODO Maybe use `rpc_config` so this would be less awkward?
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_single_block(
		_unused_pos: Vector3, _unused_look_dir: Vector3, _unused_block_id: int):
	# The server has a different script for remote players
	push_error("Didn't expect this method to be called")
