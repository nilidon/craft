extends Node
class_name BlockyVoxelGame

const NETWORK_MODE_SINGLEPLAYER = 0
const NETWORK_MODE_CLIENT = 1
const NETWORK_MODE_HOST = 2

const SERVER_PEER_ID = 1

const CharacterScene = preload("./player/character_avatar.tscn")
const RemoteCharacterScene = preload("./player/remote_character.tscn")
const RandomTicks = preload("./random_ticks.gd")
const WaterUpdater = preload("./water.gd")
const WorldPaths = preload("./world_paths.gd")
const CoinSpawnManager = preload("res://blocky_game/progression/coin_spawn_manager.gd")
const CoinsHudScript = preload("res://blocky_game/gui/coins_hud.gd")

# Same as upstream Zylann voxelgame (blocky_game.gd): immediate spawn at this position.
const DEFAULT_SPAWN_POS := Vector3(0, 64, 0)

@onready var _light : DirectionalLight3D = $DirectionalLight3D
@onready var _terrain : VoxelTerrain = $VoxelTerrain
@onready var _characters_container : Node = $Players

var _coin_spawn_manager: Node = null

var _network_mode := NETWORK_MODE_SINGLEPLAYER
var _ip := ""
var _port := -1
## Active save slot (VoxelStreamRegionFiles directory name under user://voxel_worlds/).
var world_slug: String = WorldPaths.DEFAULT_SLUG
var _local_gameplay_paused := false
## True after player/world systems change voxels; cleared on successful save and after load.
var _world_dirty := false
var _client_save_rpc_done := false
var _client_save_rpc_err := OK

## Emitted on **clients** when the host finishes [method save_current_world_async] after [method request_save_world_from_client].
signal multiplayer_client_save_finished(err: int)

# Initially needed because when running multiple instances in the editor, Godot is mixing up the
# outputs of server and clients in the same output console...
# 2025/05/01: had to prefix because Godot now has a Logger class
class BG_Logger:
	var prefix := ""
	
	func debug(msg: String):
		print(prefix, msg)

	func error(msg: String):
		push_error(prefix, msg)


var _logger := BG_Logger.new()


func get_terrain() -> VoxelTerrain:
	return _terrain


## VoxelTool edits are dropped if data blocks are not loaded yet (streaming / viewers). Waits until the area is editable,
## using a short-lived [VoxelViewer] at the edit center when needed (fixes distant builds and server-side RPC places).
func ensure_voxel_area_editable_for_edit(
		terrain_tool: VoxelTool,
		edit_area: AABB,
		network_peer_id: int = 0,
		max_frames: int = 240,
) -> bool:
	if terrain_tool.is_area_editable(edit_area):
		return true
	var center := edit_area.get_center()
	var holder := Node3D.new()
	holder.name = "VoxelEditLoadProbe"
	holder.position = center
	_terrain.add_child(holder)
	var viewer := VoxelViewer.new()
	var half_extent := maxf(edit_area.size.x, maxf(edit_area.size.y, edit_area.size.z)) * 0.5
	var vd := int(clampf(ceil(half_extent) + 12.0, 16.0, float(_terrain.max_view_distance)))
	viewer.view_distance = vd
	viewer.requires_visuals = false
	viewer.requires_collisions = false
	viewer.set_requires_data_block_notifications(true)
	if network_peer_id > 0:
		viewer.set_network_peer_id(network_peer_id)
	holder.add_child(viewer)
	var tree := get_tree()
	for _i in max_frames:
		if terrain_tool.is_area_editable(edit_area):
			holder.queue_free()
			return true
		await tree.process_frame
	holder.queue_free()
	return false


func get_network_mode() -> int:
	return _network_mode


func set_network_mode(mode: int):
	_network_mode = mode


func set_ip(ip: String):
	_ip = ip


func set_port(port: int):
	_port = port


func get_world_slug() -> String:
	return world_slug


func set_local_gameplay_paused(v: bool) -> void:
	_local_gameplay_paused = v


func is_local_gameplay_paused() -> bool:
	return _local_gameplay_paused


func can_save_world() -> bool:
	return _network_mode != NETWORK_MODE_CLIENT


func mark_world_modified() -> void:
	_world_dirty = true


func has_unsaved_world_changes() -> bool:
	return _world_dirty


func can_load_world() -> bool:
	return _network_mode == NETWORK_MODE_SINGLEPLAYER


const _VOXEL_SAVE_MAX_FRAMES := 2400
const _VOXEL_SAVE_BLOCKING_MS := 120000


func _flush_voxel_stream_to_disk() -> void:
	var st: Variant = _terrain.stream
	if st != null and st.has_method(&"flush"):
		st.flush()


func _await_voxel_save_tracker(tracker: Variant, max_frames: int) -> bool:
	if tracker == null:
		return true
	var tree := get_tree()
	var n := 0
	while not tracker.is_complete() and not tracker.is_aborted() and n < max_frames:
		await tree.process_frame
		n += 1
	return tracker.is_complete()


func _block_until_voxel_save_tracker(tracker: Variant, max_ms: int) -> bool:
	if tracker == null:
		return true
	var deadline_ms := Time.get_ticks_msec() + max_ms
	while not tracker.is_complete() and not tracker.is_aborted():
		if Time.get_ticks_msec() >= deadline_ms:
			return false
		OS.delay_usec(500)
	return tracker.is_complete()


## Waits until async voxel save tasks finish, then [method VoxelStream.flush]es. Use from menus (unpause tree first if [code]get_tree().paused[/code]).
func save_current_world_async() -> int:
	if not can_save_world():
		return ERR_UNAUTHORIZED
	var tracker: Variant = _terrain.save_modified_blocks()
	var ok := await _await_voxel_save_tracker(tracker, _VOXEL_SAVE_MAX_FRAMES)
	if not ok:
		push_error("Timed out waiting for voxel terrain save.")
		return ERR_TIMEOUT
	_flush_voxel_stream_to_disk()
	_world_dirty = false
	return OK


## Single-player / host: same as [method save_current_world_async]. Multiplayer **client**: RPCs the host to run that save, then waits for the result.
func save_via_local_or_host_async() -> int:
	if can_save_world():
		return await save_current_world_async()
	var mp := get_tree().get_multiplayer()
	if mp != null and mp.has_multiplayer_peer() and not mp.is_server():
		return await _client_await_host_save_rpc()
	return ERR_UNAUTHORIZED


func _client_await_host_save_rpc() -> int:
	_client_save_rpc_done = false
	_client_save_rpc_err = ERR_UNAVAILABLE
	if multiplayer_client_save_finished.is_connected(_on_multiplayer_client_save_finished_one_shot):
		multiplayer_client_save_finished.disconnect(_on_multiplayer_client_save_finished_one_shot)
	multiplayer_client_save_finished.connect(_on_multiplayer_client_save_finished_one_shot)
	request_save_world_from_client.rpc_id(SERVER_PEER_ID)
	var n := 0
	while not _client_save_rpc_done and n < _VOXEL_SAVE_MAX_FRAMES:
		await get_tree().process_frame
		n += 1
	if multiplayer_client_save_finished.is_connected(_on_multiplayer_client_save_finished_one_shot):
		multiplayer_client_save_finished.disconnect(_on_multiplayer_client_save_finished_one_shot)
	return _client_save_rpc_err if _client_save_rpc_done else ERR_TIMEOUT


func _on_multiplayer_client_save_finished_one_shot(err: int) -> void:
	_client_save_rpc_err = err
	_client_save_rpc_done = true
	multiplayer_client_save_finished.disconnect(_on_multiplayer_client_save_finished_one_shot)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_save_world_from_client() -> void:
	var mp := get_tree().get_multiplayer()
	if mp == null or not mp.is_server():
		return
	var reply_peer := mp.get_remote_sender_id()
	if reply_peer <= 0:
		return
	_host_save_after_client_request(reply_peer)


func _host_save_after_client_request(reply_peer: int) -> void:
	_host_save_after_client_request_async(reply_peer)


func _host_save_after_client_request_async(reply_peer: int) -> void:
	var err := await save_current_world_async()
	notify_save_world_result_to_client.rpc_id(reply_peer, err)


@rpc("authority", "call_remote", "reliable", 0)
func notify_save_world_result_to_client(err: int) -> void:
	multiplayer_client_save_finished.emit(err)


## Blocks the main thread until saves finish (window close, switching world stream). Avoid during gameplay.
func save_current_world_blocking() -> int:
	if not can_save_world():
		return ERR_UNAUTHORIZED
	var tracker: Variant = _terrain.save_modified_blocks()
	if not _block_until_voxel_save_tracker(tracker, _VOXEL_SAVE_BLOCKING_MS):
		push_error("Timed out waiting for voxel terrain save (blocking).")
		return ERR_TIMEOUT
	_flush_voxel_stream_to_disk()
	_world_dirty = false
	return OK


func load_world_from_slug(slug: String) -> int:
	if not can_load_world():
		return ERR_UNAUTHORIZED
	if not WorldPaths.is_valid_slug(slug):
		return ERR_INVALID_PARAMETER
	var err_mk := WorldPaths.ensure_world_directory(slug)
	if err_mk != OK:
		return err_mk
	var tracker: Variant = _terrain.save_modified_blocks()
	if not _block_until_voxel_save_tracker(tracker, _VOXEL_SAVE_BLOCKING_MS):
		push_error("Previous world did not finish saving before load; aborting.")
		return ERR_TIMEOUT
	_flush_voxel_stream_to_disk()
	var w := get_node_or_null("Water")
	if w != null and w.has_method("reset_after_stream_change"):
		w.reset_after_stream_change()
	var err := WorldPaths.apply_stream_to_terrain(_terrain, slug)
	if err == OK:
		world_slug = slug
		_world_dirty = false
	return err


func _ready():
	if _light != null:
		_light.add_to_group("settings_directional_shadows")
		_light.shadow_enabled = PlayerSettings.get_directional_shadows_enabled()
	if _network_mode == NETWORK_MODE_HOST:
		_logger.prefix = "Server: "
		
		# Configure multiplayer API as server
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(_port, 32, 0, 0, 0)
		if err != OK:
			_logger.error(str("Failed to create server peer, error ", err))
			return
		var mp := get_tree().get_multiplayer()
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
		mp.multiplayer_peer = peer

		# Configure VoxelTerrain as server
		var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
		_terrain.add_child(synchronizer)

	elif _network_mode == NETWORK_MODE_CLIENT:
		_logger.prefix = "Client: "
		
		# Configure multiplayer API as client
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(_ip, _port, 0, 0, 0, 0)
		if err != OK:
			_logger.error(str("Failed to create client peer, error ", err))
			return
		var mp := get_tree().get_multiplayer()
		mp.connected_to_server.connect(_on_connected_to_server)
		mp.connection_failed.connect(_on_connection_failed)
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
		mp.server_disconnected.connect(_on_server_disconnected)
		mp.multiplayer_peer = peer

		# Configure VoxelTerrain as client
		var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
		_terrain.add_child(synchronizer)
		_terrain.stream = null

	if _network_mode == NETWORK_MODE_HOST or _network_mode == NETWORK_MODE_SINGLEPLAYER:
		add_child(RandomTicks.new())
		
		var water_updater := WaterUpdater.new()
		# Current code grabs this node by name, so must be named for now...
		water_updater.name = "Water"
		add_child(water_updater)
		_spawn_character(SERVER_PEER_ID, DEFAULT_SPAWN_POS)

	_coin_spawn_manager = CoinSpawnManager.new()
	_coin_spawn_manager.name = "CoinSpawnManager"
	add_child(_coin_spawn_manager)
	_coin_spawn_manager.setup(self, _terrain, _characters_container)

	var coins_hud: CanvasLayer = CoinsHudScript.new()
	coins_hud.name = "CoinsHud"
	add_child(coins_hud)


func _process(delta: float) -> void:
	if is_local_gameplay_paused():
		return
	if get_tree().paused:
		return
	PlayerProgress.add_play_time(delta)


func _on_connected_to_server():
	_logger.debug("connected to server")
	if _network_mode == NETWORK_MODE_CLIENT:
		GameAudio.play_multiplayer_connect_success()


func _on_connection_failed():
	_logger.debug("Connection failed")
	_return_to_main_menu_deferred()


func _on_peer_connected(new_peer_id: int):
	_logger.debug(str("peer ", new_peer_id, " connected"))
	
	if _network_mode == NETWORK_MODE_HOST:
		# Spawn own character
		var new_character = _spawn_remote_character(new_peer_id, DEFAULT_SPAWN_POS)
		_logger.debug(str("Sending own character to ", new_peer_id))
		rpc_id(new_peer_id, &"receive_own_character", new_peer_id, new_character.position)
		
		# Send existing characters to the new peer
		for i in _characters_container.get_child_count():
			var character := _characters_container.get_child(i)
			if character != new_character:
				var peer_id := character.name.to_int()
				_logger.debug(str("Sending remote character ", peer_id, " to ", new_peer_id))
				rpc_id(new_peer_id, &"receive_remote_character", peer_id, character.position)
		
		# Send new character to other clients
		var peers := get_tree().get_multiplayer().get_peers()
		for peer_id in peers:
			if peer_id != new_peer_id:
				_logger.debug(str("Sending remote character ", peer_id, " to other ", new_peer_id))
				rpc_id(peer_id, &"receive_remote_character", new_peer_id, new_character.position)


func _on_peer_disconnected(peer_id: int):
	_logger.debug(str("Peer ", peer_id, " disconnected"))
	# Remove character
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		var character = _characters_container.get_node(node_name)
		character.queue_free()
	else:
		_logger.debug(str("Character ", peer_id, " not found"))


func _on_server_disconnected():
	_logger.debug("Server disconnected")
	_return_to_main_menu_deferred()


func _return_to_main_menu_deferred() -> void:
	var main := get_parent()
	if main != null and main.has_method("exit_game_to_menu"):
		main.call_deferred("exit_game_to_menu", false)


func _notification(what: int):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if _network_mode == NETWORK_MODE_HOST or _network_mode == NETWORK_MODE_SINGLEPLAYER:
				# Save game when the user closes the window
				_save_world()


func _save_world() -> void:
	if can_save_world():
		save_current_world_blocking()


func _spawn_character(peer_id: int, pos: Vector3) -> Node3D:
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		_logger.error(str("Character ", peer_id, " already created"))
		return null
	var character : Node3D = CharacterScene.instantiate()
	character.name = node_name
	character.position = pos
	character.terrain = get_terrain().get_path()
	_characters_container.add_child(character)
	return character


func _spawn_remote_character(peer_id: int, pos: Vector3) -> Node3D:
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		_logger.debug(str("Remote character ", peer_id, " already created"))
		return null
	var character := RemoteCharacterScene.instantiate()
	character.position = pos
	character.name = str(peer_id)
	if _network_mode == NETWORK_MODE_HOST:
		# The server is authoritative on voxel terrain, so it needs a viewer to load terrain
		# around each character. We'll also tell which peer ID it uses, so the terrain knows which
		# peer to send the voxels to.
		# TODO Make a specific scene?
		var viewer := VoxelViewer.new()
		viewer.view_distance = 128
		viewer.requires_visuals = false
		viewer.requires_collisions = false
		viewer.set_network_peer_id(peer_id)
		viewer.set_requires_data_block_notifications(true)
		#viewer.requires_data_block_notifications = true
		character.add_child(viewer)
	_characters_container.add_child(character)
	return character


func replicate_coin_spawn(pos: Vector3, coin_id: int) -> void:
	if _coin_spawn_manager == null:
		return
	_coin_spawn_manager.spawn_coin_local(pos, coin_id)
	var mp := get_tree().get_multiplayer()
	if mp != null and mp.has_multiplayer_peer() and mp.is_server():
		sync_world_coin_spawn.rpc(pos, coin_id)


func replicate_coin_remove(coin_id: int) -> void:
	if _coin_spawn_manager == null:
		return
	_coin_spawn_manager.remove_coin_local(coin_id)
	var mp := get_tree().get_multiplayer()
	if mp != null and mp.has_multiplayer_peer() and mp.is_server():
		sync_world_coin_remove.rpc(coin_id)


@rpc("authority", "call_remote", "reliable", 0)
func sync_world_coin_spawn(pos: Vector3, coin_id: int) -> void:
	if _coin_spawn_manager != null:
		_coin_spawn_manager.spawn_coin_local(pos, coin_id)


@rpc("authority", "call_remote", "reliable", 0)
func sync_world_coin_remove(coin_id: int) -> void:
	if _coin_spawn_manager != null:
		_coin_spawn_manager.remove_coin_local(coin_id)


func grant_world_coin_to_peer(peer_id: int, amount: int) -> void:
	var mp := get_tree().get_multiplayer()
	if mp == null or not mp.has_multiplayer_peer():
		client_grant_world_coin_pickup(amount)
		return
	if not mp.is_server():
		return
	if peer_id == mp.get_unique_id():
		client_grant_world_coin_pickup(amount)
	else:
		client_grant_world_coin_pickup.rpc_id(peer_id, amount)


@rpc("authority", "call_remote", "reliable", 0)
func client_grant_world_coin_pickup(amount: int) -> void:
	GameAudio.play_coin_pickup()
	PlayerProgress.add_coins(amount, "world_pickup")
	PlayerProgress.record_world_coin_collected()


@rpc("authority", "call_remote", "reliable", 0)
func receive_remote_character(peer_id: int, pos: Vector3):
	_logger.debug(str("receive_remote_character ", peer_id, " at ", pos))
	_spawn_remote_character(peer_id, pos)


@rpc("authority", "call_remote", "reliable", 0)
func receive_own_character(peer_id: int, pos: Vector3):
	_logger.debug(str("receive_own_character ", peer_id, " at ", pos))
	_spawn_character(peer_id, pos)
