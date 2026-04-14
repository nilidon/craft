extends Node
## Headless-friendly entry: hosts ENet on --port=, loads --world= slug. Use as main scene for a
## "Dedicated server" export (separate from the normal game). Copy saves into the server's user://
## voxel_worlds folder or create worlds once via a normal client build.
## Optional room listing: --signal-url=http://127.0.0.1:8787 --room-code=YOURCODE
## [--advertise-host=public.ip] (needed when the HTTP request would otherwise show 127.0.0.1).

const BlockyGame = preload("./blocky_game.gd")
const BlockyGameScene = preload("./blocky_game.tscn")
const RoomCodeLan = preload("./room_code_lan.gd")
const RoomCodeSignalingHost = preload("./room_code_signaling_host.gd")
const RoomCodeSignalingSettings = preload("./room_code_signaling_settings.gd")
const WorldPaths = preload("./world_paths.gd")
const WorldCatalog = preload("./world_catalog.gd")
const WorldMeta = preload("./world_meta.gd")


func _ready() -> void:
	var cfg := _parse_args()
	if not WorldPaths.is_valid_slug(cfg.world):
		push_error("Invalid or missing world slug. Use --world=YourSaveName (letters, numbers, _ -).")
		get_tree().quit(1)
		return
	if not DirAccess.dir_exists_absolute(WorldPaths.directory_for_slug(cfg.world)):
		push_error("World folder not found: %s — copy it under user://voxel_worlds/ on this machine."
			% cfg.world)
		get_tree().quit(1)
		return
	if cfg.port < 1 or cfg.port > 65535:
		push_error("Bad --port=")
		get_tree().quit(1)
		return
	if not cfg.signal_url.is_empty():
		var rc := RoomCodeLan.normalize_code(cfg.room_code)
		if not RoomCodeLan.is_valid_room_code(rc):
			push_error(
				"With --signal-url=, set --room-code= too (letters/numbers, at least %d characters)."
				% RoomCodeLan.MIN_CODE_LEN)
			get_tree().quit(1)
			return

	var game := BlockyGameScene.instantiate() as BlockyVoxelGame
	game.world_slug = cfg.world
	game.set_network_mode(BlockyGame.NETWORK_MODE_HOST)
	game.set_ip("")
	game.set_port(cfg.port)
	_apply_world_stream(game.get_node("VoxelTerrain") as VoxelTerrain, cfg.world)
	add_child(game)
	if not cfg.signal_url.is_empty():
		var sig := RoomCodeSignalingHost.new()
		add_child(sig)
		sig.start_signaling(cfg.signal_url, RoomCodeLan.normalize_code(cfg.room_code), cfg.port,
			cfg.advertise_host)
	print("Dedicated server: world=\"%s\" UDP port=%d" % [cfg.world, cfg.port])


func _parse_args() -> Dictionary:
	var port := RoomCodeSignalingSettings.DEFAULT_GAME_PORT
	var world := WorldPaths.DEFAULT_SLUG
	var signal_url := ""
	var room_code := ""
	var advertise_host := ""
	for a in OS.get_cmdline_args():
		if a.begins_with("--port="):
			port = int(a.get_slice("=", 1))
		elif a.begins_with("--world="):
			world = a.get_slice("=", 1).strip_edges()
		elif a.begins_with("--signal-url="):
			signal_url = a.get_slice("=", 1).strip_edges()
		elif a.begins_with("--room-code="):
			room_code = a.get_slice("=", 1).strip_edges()
		elif a.begins_with("--advertise-host="):
			advertise_host = a.get_slice("=", 1).strip_edges()
	return {
		"port": port,
		"world": world,
		"signal_url": signal_url,
		"room_code": room_code,
		"advertise_host": advertise_host,
	}


func _apply_world_stream(terrain: VoxelTerrain, slug: String) -> void:
	var err := WorldPaths.apply_stream_to_terrain(terrain, slug)
	if err != OK:
		push_error("Could not open world stream \"%s\" (error %d)." % [slug, err])
		get_tree().quit(1)
		return
	var map_id := WorldMeta.read_map_id(slug)
	terrain.generator = WorldCatalog.duplicate_generator_for_map(map_id)
