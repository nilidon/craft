extends Node

const Util = preload("res://common/util.gd")
const Blocks = preload("../blocks/blocks.gd")
const WaterUpdater = preload("./../water.gd")
const InteractionCommon = preload("./interaction_common.gd")
const PLAYER_UNDERPLACE_MAX_Y_OFFSET = 0.05
const PLAYER_FEET_OFFSET = 0.9
const BUILD_HEIGHT_LIMIT = InteractionCommon.BUILD_HEIGHT_LIMIT

@export var terrain_path : NodePath

@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _water_updater : WaterUpdater
@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _players_container : Node = get_node_or_null("/root/Main/Game/Players")

var _terrain_tool : VoxelTool = null


func _ready():
	_terrain_tool = _terrain.get_voxel_tool()
	_terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() == false or mp.is_server():
		_water_updater = get_node("/root/Main/Game/Water")


# Actually, we only want this to be called from clients to the server! Not any peer!
# But that specification doesn't exist in the API.
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_single_block(pos: Vector3, look_dir: Vector3, block_id: int):
	if block_id != Blocks.AIR_ID and pos.y >= BUILD_HEIGHT_LIMIT:
		return
	var sender_player := _get_sender_player()
	if _intersects_any_player(pos, sender_player):
		return
	InteractionCommon.place_single_block(_terrain_tool, pos, look_dir, block_id, _block_types, 
		_water_updater)


func _get_sender_player() -> Node3D:
	var mp := get_tree().get_multiplayer()
	if mp == null:
		return null
	var sender_id := mp.get_remote_sender_id()
	if _players_container != null and _players_container.has_node(str(sender_id)):
		var node := _players_container.get_node(str(sender_id))
		if node is Node3D:
			return node
	return null


func _intersects_any_player(pos: Vector3, ignore_player: Node3D) -> bool:
	if _players_container == null:
		return false

	var placed_aabb := AABB(pos, Vector3.ONE)
	var placed_top_y := pos.y + 1.0
	for i in _players_container.get_child_count():
		var player := _players_container.get_child(i)
		if not (player is Node3D):
			continue
		var p: Vector3 = player.position
		if player == ignore_player:
			if placed_top_y <= p.y + PLAYER_UNDERPLACE_MAX_Y_OFFSET:
				# Allow the sender to place below themselves when stacking up.
				continue
			if _is_sender_pillar_place(pos, p):
				# Allow explicit self-pillar placement at sender's current body level.
				continue
		if placed_top_y <= p.y + PLAYER_UNDERPLACE_MAX_Y_OFFSET:
			continue
		var player_aabb := AABB(
			p + Vector3(-0.4, -0.9, -0.4),
			Vector3(0.8, 1.8, 0.8)
		)
		if player_aabb.intersects(placed_aabb):
			return true
	return false


func _is_sender_pillar_place(pos: Vector3, player_pos: Vector3) -> bool:
	var center_x := pos.x + 0.5
	var center_z := pos.z + 0.5
	var feet_y := player_pos.y - PLAYER_FEET_OFFSET
	return (
		absf(center_x - player_pos.x) <= 0.7
		and absf(center_z - player_pos.z) <= 0.7
		and pos.y <= feet_y
		and feet_y < pos.y + 1.001
	)
