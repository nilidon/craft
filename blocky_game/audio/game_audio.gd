extends Node
## Autoload: SFX pool + menu/gameplay music + underwater loop. Streams live in [code]res://blocky_game/audio/[/code].
## Menu + gameplay beds: two players, instant handoff (no volume ducking). MP3 is rarely gapless — for a truly invisible loop, use trimmed OGG/WAV.

const _DIR := "res://blocky_game/audio/"
const _FILES := {
	&"block_break": "block_break.mp3",
	&"block_place": "block_place.mp3",
	&"coin_pickup": "coin_pickup.mp3",
	&"error_soft": "error_soft.mp3",
	&"fly_mode_on_off": "fly_mode_on_off.mp3",
	&"footstep": "footstep.mp3",
	&"gameplay_music_loop": "gameplay_music_loop.mp3",
	&"hotbar_slot_change": "hotbar_slot_change.mp3",
	&"inventory_close": "inventory_close.mp3",
	&"inventory_open": "inventory_open.mp3",
	&"jump": "jump.mp3",
	&"menu_music_loop": "menu_music_loop.mp3",
	&"multiplayer_connect_success": "multiplayer_connect_success.mp3",
	&"pause_menu_open_close": "pause_menu_open_close.mp3",
	&"purchase_unlock_success": "purchase_unlock_success.mp3",
	&"rocket_hit_explosion": "rocket_hit_explosion.mp3",
	&"rocket_launch": "rocket_launch.mp3",
	&"soft_land": "soft_land.mp3",
	&"swipe": "swipe.mp3",
	&"ui_button": "ui_button.mp3",
	&"underwater_loop": "underwater_loop.mp3",
	&"water_splash": "water_splash.mp3",
}

const _ENGINE_LOOP_KEYS: Array[StringName] = [&"underwater_loop"]

const _MENU_MUSIC_KEY := &"menu_music_loop"
const _GAMEPLAY_MUSIC_KEY := &"gameplay_music_loop"

const _SFX_POOL_SIZE := 12
const _3D_MAX_DISTANCE := 96.0
## Quieter than other UI/SFX; pooled players reset volume each play.
const _SWIPE_VOLUME_DB := -10.0
const _FOOTSTEP_VOLUME_DB := -10.0
const _SOFT_LAND_VOLUME_DB := -6.0
const _JUMP_VOLUME_DB := -12.0
const _BLOCK_BREAK_VOLUME_DB := -10.0
const _UNDERWATER_LOOP_VOLUME_DB := -16.0
const _INVENTORY_OPEN_VOLUME_DB := -8.0
const _INVENTORY_CLOSE_VOLUME_DB := -8.0
const _MENU_MUSIC_VOLUME_DB := -12.0
const _GAMEPLAY_MUSIC_VOLUME_DB := -4.0
## Seconds before [method AudioStream.get_length] to start the other copy — keep small so you do not hear “double” music.
const _MUSIC_LOOP_HANDOFF_LEAD_SEC := 0.09
## If the MP3 has a short silent leader after each decode start, try 0.04–0.12. Otherwise leave 0.
const _MUSIC_LOOP_PLAY_OFFSET_SEC := 0.0

const _MODE_NONE := &"none"
const _MODE_MENU := &"menu"
const _MODE_GAMEPLAY := &"gameplay"

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _music_menu_a: AudioStreamPlayer
var _music_menu_b: AudioStreamPlayer
var _music_menu_primary: int = 0
var _music_gp_a: AudioStreamPlayer
var _music_gp_b: AudioStreamPlayer
var _music_gp_primary: int = 0
var _underwater_player: AudioStreamPlayer
var _music_mode: StringName = _MODE_NONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_all()
	for _j in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)
	_music_menu_a = _make_music_player(&"MusicMenuA", _MENU_MUSIC_VOLUME_DB)
	_music_menu_b = _make_music_player(&"MusicMenuB", _MENU_MUSIC_VOLUME_DB)
	_music_gp_a = _make_music_player(&"MusicGameplayA", _GAMEPLAY_MUSIC_VOLUME_DB)
	_music_gp_b = _make_music_player(&"MusicGameplayB", _GAMEPLAY_MUSIC_VOLUME_DB)
	_underwater_player = AudioStreamPlayer.new()
	_underwater_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_underwater_player.volume_db = _UNDERWATER_LOOP_VOLUME_DB
	add_child(_underwater_player)
	if _streams.has(_MENU_MUSIC_KEY):
		var ms: AudioStream = _streams[_MENU_MUSIC_KEY] as AudioStream
		_music_menu_a.stream = ms
		_music_menu_b.stream = ms
	if _streams.has(_GAMEPLAY_MUSIC_KEY):
		var gs: AudioStream = _streams[_GAMEPLAY_MUSIC_KEY] as AudioStream
		_music_gp_a.stream = gs
		_music_gp_b.stream = gs
	if _streams.has(&"underwater_loop"):
		_underwater_player.stream = _streams[&"underwater_loop"]
	call_deferred(&"enter_menu")


func _make_music_player(node_name: StringName, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = str(node_name)
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	p.volume_db = volume_db
	add_child(p)
	return p


func _music_volume_db_for_stream_key(stream_key: StringName) -> float:
	if stream_key == _MENU_MUSIC_KEY:
		return _MENU_MUSIC_VOLUME_DB
	return _GAMEPLAY_MUSIC_VOLUME_DB


func _load_all() -> void:
	for k: StringName in _FILES.keys():
		var path: String = _DIR + str(_FILES[k])
		if not ResourceLoader.exists(path):
			push_warning("GameAudio: missing %s" % path)
			continue
		var stream: AudioStream = load(path)
		if stream == null:
			continue
		if stream is AudioStreamMP3:
			var mp3 := stream as AudioStreamMP3
			mp3.loop = k in _ENGINE_LOOP_KEYS
		_streams[k] = stream


func _process(_delta: float) -> void:
	_tick_music_loop_handoff(_music_menu_a, _music_menu_b, _MENU_MUSIC_KEY, &"_music_menu_primary")
	_tick_music_loop_handoff(_music_gp_a, _music_gp_b, _GAMEPLAY_MUSIC_KEY, &"_music_gp_primary")


func _tick_music_loop_handoff(
	p0: AudioStreamPlayer,
	p1: AudioStreamPlayer,
	stream_key: StringName,
	primary_prop: StringName
) -> void:
	if not _streams.has(stream_key):
		return
	var want_menu: bool = _music_mode == _MODE_MENU and stream_key == _MENU_MUSIC_KEY
	var want_gp: bool = _music_mode == _MODE_GAMEPLAY and stream_key == _GAMEPLAY_MUSIC_KEY
	if want_menu or want_gp:
		if not p0.playing and not p1.playing:
			_play_looped_music_from_start(p0, p1, primary_prop, stream_key)
			return
	var pri: int = int(get(primary_prop))
	var active: AudioStreamPlayer = p0 if pri == 0 else p1
	var nxt: AudioStreamPlayer = p1 if pri == 0 else p0
	if not active.playing or nxt.playing:
		return
	var st: AudioStream = _streams[stream_key] as AudioStream
	var full_len: float = st.get_length()
	if full_len < 0.25:
		return
	var pos: float = active.get_playback_position()
	if pos < 0.2:
		return
	var lead: float = clampf(_MUSIC_LOOP_HANDOFF_LEAD_SEC, 0.04, minf(0.18, full_len * 0.2))
	if pos < full_len - lead:
		return
	_perform_music_loop_handoff(p0, p1, primary_prop, stream_key)


func _perform_music_loop_handoff(
	p0: AudioStreamPlayer,
	p1: AudioStreamPlayer,
	primary_prop: StringName,
	stream_key: StringName
) -> void:
	var v: float = _music_volume_db_for_stream_key(stream_key)
	var pri: int = int(get(primary_prop))
	var active: AudioStreamPlayer = p0 if pri == 0 else p1
	var nxt: AudioStreamPlayer = p1 if pri == 0 else p0
	nxt.volume_db = v
	if _MUSIC_LOOP_PLAY_OFFSET_SEC > 0.0:
		nxt.play(_MUSIC_LOOP_PLAY_OFFSET_SEC)
	else:
		nxt.play()
	active.stop()
	active.volume_db = v
	set(primary_prop, 1 - pri)


func _stop_looped_music_pair(p0: AudioStreamPlayer, p1: AudioStreamPlayer, volume_db: float) -> void:
	p0.stop()
	p1.stop()
	p0.volume_db = volume_db
	p1.volume_db = volume_db


func _play_looped_music_from_start(
	p0: AudioStreamPlayer,
	p1: AudioStreamPlayer,
	primary_prop: StringName,
	stream_key: StringName
) -> void:
	_stop_looped_music_pair(p0, p1, _music_volume_db_for_stream_key(stream_key))
	set(primary_prop, 0)
	if _MUSIC_LOOP_PLAY_OFFSET_SEC > 0.0:
		p0.play(_MUSIC_LOOP_PLAY_OFFSET_SEC)
	else:
		p0.play()


func _play_pooled(key: StringName) -> void:
	_play_pooled_volume(key, 0.0)


func _play_pooled_volume(key: StringName, volume_db: float) -> void:
	if not _streams.has(key):
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	if p.playing:
		p.stop()
	p.volume_db = volume_db
	p.stream = _streams[key] as AudioStream
	p.play()


func play_block_place() -> void:
	_play_pooled(&"block_place")


func play_block_break() -> void:
	_play_pooled_volume(&"block_break", _BLOCK_BREAK_VOLUME_DB)


func play_coin_pickup() -> void:
	_play_pooled(&"coin_pickup")


func play_error_soft() -> void:
	_play_pooled(&"error_soft")


func play_fly_mode_toggle() -> void:
	_play_pooled(&"fly_mode_on_off")


func play_footstep() -> void:
	_play_pooled_volume(&"footstep", _FOOTSTEP_VOLUME_DB)


func play_hotbar_slot_change() -> void:
	_play_pooled(&"hotbar_slot_change")


func play_inventory_open() -> void:
	_play_pooled_volume(&"inventory_open", _INVENTORY_OPEN_VOLUME_DB)


func play_inventory_close() -> void:
	_play_pooled_volume(&"inventory_close", _INVENTORY_CLOSE_VOLUME_DB)


func play_jump() -> void:
	_play_pooled_volume(&"jump", _JUMP_VOLUME_DB)


func play_soft_land() -> void:
	_play_pooled_volume(&"soft_land", _SOFT_LAND_VOLUME_DB)


func play_swipe() -> void:
	_play_pooled_volume(&"swipe", _SWIPE_VOLUME_DB)


func play_ui_button() -> void:
	_play_pooled(&"ui_button")


func play_pause_menu_toggle() -> void:
	_play_pooled(&"pause_menu_open_close")


func play_multiplayer_connect_success() -> void:
	_play_pooled(&"multiplayer_connect_success")


func play_purchase_unlock_success() -> void:
	_play_pooled(&"purchase_unlock_success")


func play_rocket_launch() -> void:
	_play_pooled(&"rocket_launch")


func play_water_splash() -> void:
	_play_pooled(&"water_splash")


func play_explosion_at_world(global_pos: Vector3) -> void:
	if not _streams.has(&"rocket_hit_explosion"):
		return
	var game := Engine.get_main_loop().root.get_node_or_null("Main/Game") as Node3D
	if game == null:
		_play_pooled(&"rocket_hit_explosion")
		return
	var p3 := AudioStreamPlayer3D.new()
	p3.stream = _streams[&"rocket_hit_explosion"] as AudioStream
	p3.max_distance = _3D_MAX_DISTANCE
	p3.unit_size = 12.0
	game.add_child(p3)
	p3.global_position = global_pos
	p3.finished.connect(p3.queue_free)
	p3.play()


func set_underwater_loop(on: bool) -> void:
	if _underwater_player.stream == null:
		return
	if on:
		_underwater_player.volume_db = _UNDERWATER_LOOP_VOLUME_DB
		if not _underwater_player.playing:
			_underwater_player.play()
	else:
		if _underwater_player.playing:
			_underwater_player.stop()


func enter_menu() -> void:
	_music_mode = _MODE_MENU
	_stop_looped_music_pair(_music_gp_a, _music_gp_b, _GAMEPLAY_MUSIC_VOLUME_DB)
	_music_gp_primary = 0
	if _streams.has(_MENU_MUSIC_KEY):
		if not _music_menu_a.playing and not _music_menu_b.playing:
			_play_looped_music_from_start(
				_music_menu_a, _music_menu_b, &"_music_menu_primary", _MENU_MUSIC_KEY
			)


func enter_gameplay() -> void:
	_music_mode = _MODE_GAMEPLAY
	_stop_looped_music_pair(_music_menu_a, _music_menu_b, _MENU_MUSIC_VOLUME_DB)
	_music_menu_primary = 0
	if _streams.has(_GAMEPLAY_MUSIC_KEY):
		if not _music_gp_a.playing and not _music_gp_b.playing:
			_play_looped_music_from_start(
				_music_gp_a, _music_gp_b, &"_music_gp_primary", _GAMEPLAY_MUSIC_KEY
			)


func stop_all_music() -> void:
	_music_mode = _MODE_NONE
	_stop_looped_music_pair(_music_menu_a, _music_menu_b, _MENU_MUSIC_VOLUME_DB)
	_music_menu_primary = 0
	_stop_looped_music_pair(_music_gp_a, _music_gp_b, _GAMEPLAY_MUSIC_VOLUME_DB)
	_music_gp_primary = 0
