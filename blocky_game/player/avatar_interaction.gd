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
	KEY_6: 5
}

@export var terrain_path : NodePath
@export var cursor_material : Material

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
	var pm := get_node_or_null("../PauseMenu")
	if pm != null and pm.has_method("setup_for_local_player"):
		pm.setup_for_local_player(_terrain.get_parent() as BlockyVoxelGame)


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
		_build_limit_hint_label = _build_hint_canvas_layer.get_node_or_null("Root/HintLabel") as Label
		if _build_limit_hint_label == null:
			var root_ctl := _build_hint_canvas_layer.get_node_or_null("Root") as Control
			if root_ctl == null:
				root_ctl = Control.new()
				root_ctl.name = "Root"
				root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
				root_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_build_hint_canvas_layer.add_child(root_ctl)
			_build_limit_hint_label = Label.new()
			_build_limit_hint_label.name = "HintLabel"
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

	if _build_limit_hint_label != null:
		_build_limit_hint_label.text = "Max build height (%d)" % BUILD_HEIGHT_LIMIT


func _show_build_height_hint() -> void:
	if _build_limit_hint_label == null:
		return
	_build_limit_hint_label.visible = true
	_build_limit_hint_time = BUILD_HEIGHT_HINT_DURATION_SEC


func _get_pointed_voxel() -> VoxelRaycastResult:
	# Match the viewport center ray (required for offset third-person cameras).
	var vp := _head.get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	var origin := _head.project_ray_origin(center)
	var forward := _head.project_ray_normal(center)
	assert(not Util.vec3_has_nan(origin))
	if forward.length_squared() < 1e-20:
		return null
	forward = forward.normalized()
	var hit := _terrain_tool.raycast(origin, forward, 10)
	if hit == null:
		return null
	if not _is_voxel_hit_plausible(hit, origin, forward):
		return null
	return hit


func _is_voxel_hit_plausible(hit: VoxelRaycastResult, origin: Vector3, forward: Vector3) -> bool:
	var cell := Vector3(
		float(hit.position.x),
		float(hit.position.y),
		float(hit.position.z),
	)
	var block_center := cell + Vector3(0.5, 0.5, 0.5)
	if forward.dot(block_center - origin) <= 0.02:
		return false
	# Upward view + hits far under the feet usually mean bad rays / mesh underside, not the sky target.
	if forward.y > 0.35:
		var player := get_parent() as Node3D
		if player != null:
			var feet_y := player.position.y - PLAYER_FEET_OFFSET
			if block_center.y < feet_y - 0.5:
				return false
	return true


func _physics_process(_delta):
	if _terrain == null:
		return

	var game := _terrain.get_parent() as BlockyVoxelGame
	if game != null and game.is_local_gameplay_paused():
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
	
	if MobileControls.is_ui_active():
		if MobileControls.consume_place_block():
			_action_place = true
		if MobileControls.consume_break_block():
			_action_use = true
	
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
	if not _is_local_avatar():
		return
	var game := _terrain.get_parent() as BlockyVoxelGame
	var pause_menu: CanvasLayer = get_node_or_null("../PauseMenu") as CanvasLayer
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var main_menu: Node = get_tree().root.get_node_or_null("Main/MainMenu")
		if main_menu != null and main_menu.has_method("try_escape_close_settings_overlay"):
			if bool(main_menu.call("try_escape_close_settings_overlay")):
				get_viewport().set_input_as_handled()
				return
	if game != null and game.is_local_gameplay_paused():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			if pause_menu != null and pause_menu.has_method("close_pause"):
				pause_menu.close_pause()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if pause_menu != null and pause_menu.has_method("toggle_pause"):
			pause_menu.toggle_pause()
			get_viewport().set_input_as_handled()
		return

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
		if event.pressed and _hotbar_keys.has(event.keycode):
			var slot_index = _hotbar_keys[event.keycode]
			_hotbar.select_slot(slot_index)


func _is_local_avatar() -> bool:
	var avatar := get_parent()
	var mp := get_tree().get_multiplayer()
	if mp == null or not mp.has_multiplayer_peer():
		return true
	return str(avatar.name) == str(mp.get_unique_id())


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
		var player_aabb := InteractionCommon.player_mover_aabb_at(p)
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
		var player_aabb := InteractionCommon.player_mover_aabb_at(p)
		if player_aabb.intersects(placed_aabb):
			return true
	return false


func _place_single_block(pos: Vector3, block_id: int):
	var look_dir := -_head.get_transform().basis.z
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		if _is_local_avatar():
			if block_id == Blocks.AIR_ID:
				GameAudio.play_block_break()
			else:
				GameAudio.play_block_place()
			if block_id == Blocks.AIR_ID:
				PlayerProgress.record_block_broken()
			elif block_id != Blocks.AIR_ID:
				PlayerProgress.record_block_placed(block_id)
		rpc_id(SERVER_PEER_ID, &"receive_place_single_block", pos, look_dir, block_id)
	else:
		_run_authoritative_place_single_block(pos, look_dir, block_id)


func _run_authoritative_place_single_block(pos: Vector3, look_dir: Vector3, block_id: int) -> void:
	_place_single_block_authoritative(pos, look_dir, block_id)


func _place_single_block_authoritative(pos: Vector3, look_dir: Vector3, block_id: int) -> void:
	var game := _terrain.get_parent() as BlockyVoxelGame
	var area := InteractionCommon.edit_aabb_for_single_block(pos)
	if game != null:
		if not await game.ensure_voxel_area_editable_for_edit(_terrain_tool, area):
			if block_id != Blocks.AIR_ID and pos.y >= BUILD_HEIGHT_LIMIT:
				_show_build_height_hint()
			return
	var ok := InteractionCommon.place_single_block(_terrain_tool, pos, look_dir,
		block_id, _block_types, _water_updater, game)
	if ok and _is_local_avatar():
		if block_id != Blocks.AIR_ID:
			GameAudio.play_block_place()
			PlayerProgress.record_block_placed(block_id)
		else:
			GameAudio.play_block_break()
			PlayerProgress.record_block_broken()
	if not ok and block_id != Blocks.AIR_ID and pos.y >= BUILD_HEIGHT_LIMIT:
		_show_build_height_hint()


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_single_block(
		_unused_pos: Vector3, _unused_look_dir: Vector3, _unused_block_id: int):
	push_error("receive_place_single_block should run on RemoteCharacter Interaction, not local avatar")
