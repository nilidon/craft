extends Control

const BlockyGame = preload("./blocky_game.gd")
const BlockyGameScene = preload("./blocky_game.tscn")
const MainMenu = preload("./main_menu.gd")
const UPNPHelper = preload("./upnp_helper.gd")
const RoomCodeSignalingHost = preload("./room_code_signaling_host.gd")
const RoomCodeSignalingSettings = preload("./room_code_signaling_settings.gd")
const WorldPaths = preload("./world_paths.gd")
const WorldCatalog = preload("./world_catalog.gd")
const WorldMeta = preload("./world_meta.gd")
const CoinsHudScript = preload("res://blocky_game/gui/coins_hud.gd")

@onready var _main_menu: MainMenu = $MainMenu

var _game: BlockyVoxelGame = null
var _menu_coins_hud: CanvasLayer = null
var _upnp_helper: UPNPHelper
var _room_signaling: RoomCodeSignalingHost


func _ready() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_disable_input = false
	call_deferred("_apply_mobile_root_window_gui_scale")
	PlayerSettings.apply_master_linear(PlayerSettings.get_master_linear())
	_menu_coins_hud = CoinsHudScript.new()
	_menu_coins_hud.name = "MenuCoinsHud"
	add_child(_menu_coins_hud)
	## [CoinsHud._ready] sets 105 for in-game (above DDD). On the main menu keep a modest layer so stacking
	## matches the implicit root canvas and touch routing stays predictable on handhelds.
	_menu_coins_hud.layer = 24
	if _main_menu != null and _main_menu.has_method(&"set_menu_coins_hud"):
		_main_menu.set_menu_coins_hud(_menu_coins_hud)


func _apply_mobile_root_window_gui_scale() -> void:
	if Engine.is_editor_hint():
		return
	var n := OS.get_name()
	if n != &"Android" and n != &"iOS":
		return
	var w := get_window()
	if w == null:
		return
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_size = Vector2i(1920, 1080)


func _pause_menu_would_freeze_tree() -> bool:
	var mp := get_tree().get_multiplayer()
	return mp == null or not mp.has_multiplayer_peer()


func open_settings_from_pause() -> void:
	# Draw MainMenu above the running game (Game node is normally after MainMenu in the tree).
	if _main_menu != null and _main_menu.get_parent() == self:
		move_child(_main_menu, -1)
	# Singleplayer: resume world sim while settings are open. Multiplayer: keep same pause rules as pause menu.
	if _pause_menu_would_freeze_tree():
		get_tree().paused = false
		if _game != null:
			_game.set_local_gameplay_paused(false)
	if _main_menu != null and _main_menu.has_method(&"show_settings_from_pause_game"):
		_main_menu.show_settings_from_pause_game()


func restore_pause_after_settings_overlay() -> void:
	if _pause_menu_would_freeze_tree():
		get_tree().paused = true
	if _game != null:
		_game.set_local_gameplay_paused(true)


func exit_game_to_menu(save_world: bool = false) -> void:
	_exit_game_to_menu_async(save_world)


func _exit_game_to_menu_async(save_world: bool) -> void:
	if save_world and _game != null:
		await _game.save_via_local_or_host_async()
	if _room_signaling != null:
		_room_signaling.stop_signaling()
		_room_signaling.queue_free()
		_room_signaling = null
	if _game != null:
		_game.queue_free()
		_game = null
	var mp := get_tree().get_multiplayer()
	if mp.multiplayer_peer != null:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	if _main_menu != null:
		_main_menu.show()
	GameAudio.enter_menu()
	if _menu_coins_hud != null:
		_menu_coins_hud.visible = true
	if _main_menu != null and _main_menu.has_method(&"refresh_world_list"):
		_main_menu.refresh_world_list()
	get_viewport().get_window().title = "Creative Craft 3D: Building Game"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _apply_world_stream(terrain: VoxelTerrain, slug: String) -> void:
	var err := WorldPaths.apply_stream_to_terrain(terrain, slug)
	if err != OK:
		push_error("Could not open world stream \"%s\" (error %d)." % [slug, err])
		return
	var map_id := WorldMeta.read_map_id(slug)
	terrain.generator = WorldCatalog.duplicate_generator_for_map(map_id)


func _spawn_game(mode: int, connect_ip: String, network_port: int, world_slug: String) -> void:
	if _menu_coins_hud != null:
		_menu_coins_hud.visible = false
	_game = BlockyGameScene.instantiate() as BlockyVoxelGame
	_game.world_slug = world_slug
	_game.set_network_mode(mode)
	_game.set_ip(connect_ip)
	_game.set_port(network_port)
	if mode != BlockyGame.NETWORK_MODE_CLIENT:
		_apply_world_stream(_game.get_node("VoxelTerrain") as VoxelTerrain, world_slug)
	add_child(_game)
	if _main_menu != null:
		_main_menu.hide()
	GameAudio.enter_gameplay()


func _on_main_menu_singleplayer_requested(world_slug: String) -> void:
	if _main_menu != null and _main_menu.has_method(&"remember_last_played_world"):
		_main_menu.remember_last_played_world(world_slug)
	_spawn_game(BlockyGame.NETWORK_MODE_SINGLEPLAYER, "", -1, world_slug)
	get_viewport().get_window().title = "Singleplayer"


func _on_main_menu_connect_to_server_requested(ip: String, port: int) -> void:
	_spawn_game(BlockyGame.NETWORK_MODE_CLIENT, ip, port, WorldPaths.DEFAULT_SLUG)
	get_viewport().get_window().title = "Client"


func _on_main_menu_host_server_requested(room_code: String, port: int, world_slug: String) -> void:
	if _main_menu != null and _main_menu.has_method(&"remember_last_played_world"):
		_main_menu.remember_last_played_world(world_slug)
	if _upnp_helper == null:
		_upnp_helper = UPNPHelper.new()
		add_child(_upnp_helper)
	if not _upnp_helper.is_setup():
		_upnp_helper.setup(port, PackedStringArray(["UDP"]), "Creative Craft 3D", 20 * 60)
	_spawn_game(BlockyGame.NETWORK_MODE_HOST, "", port, world_slug)
	if _room_signaling != null:
		_room_signaling.stop_signaling()
		_room_signaling.queue_free()
		_room_signaling = null
	var sig := RoomCodeSignalingHost.new()
	add_child(sig)
	var base := RoomCodeSignalingSettings.get_base_url()
	sig.start_signaling(base, room_code, port, "")
	_room_signaling = sig
	get_viewport().get_window().title = "Server"
