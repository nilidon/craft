extends RefCounted
class_name PlayerSettings
## Shared player prefs (same cfg file as main menu progress).

const _SkinCat = preload("res://blocky_game/skins/skin_catalog.gd")
const _PlayerProgress = preload("res://blocky_game/progression/player_progress.gd")

const CFG_PATH := "user://blocky_player_settings.cfg"
const SEC_VIDEO := "video"
const KEY_DIRECTIONAL_SHADOWS := "directional_shadows"
const KEY_SUN_SHADOWS_LEGACY := "sun_shadows"
const KEY_CAMERA_FOV := "camera_fov"
const KEY_THIRD_PERSON := "third_person"
const SEC_AUDIO := "audio"
const KEY_MASTER_LINEAR := "master_linear"
const SEC_CONTROLS := "controls"
const KEY_MOUSE_SENS_T := "mouse_sensitivity_t"
const KEY_INVERT_MOUSE_Y := "invert_mouse_y"
const SEC_PLAYER := "player"
const KEY_SKIN_VOX_PATH := "skin_vox_path"

const MOUSE_SENS_MIN := 0.12
const MOUSE_SENS_MAX := 0.65
const FOV_MIN := 65.0
const FOV_MAX := 100.0


static func get_directional_shadows_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return true
	if cfg.has_section_key(SEC_VIDEO, KEY_DIRECTIONAL_SHADOWS):
		return bool(cfg.get_value(SEC_VIDEO, KEY_DIRECTIONAL_SHADOWS, true))
	if cfg.has_section_key(SEC_VIDEO, KEY_SUN_SHADOWS_LEGACY):
		return bool(cfg.get_value(SEC_VIDEO, KEY_SUN_SHADOWS_LEGACY, true))
	return true


static func set_directional_shadows_enabled(v: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SEC_VIDEO, KEY_DIRECTIONAL_SHADOWS, v)
	cfg.save(CFG_PATH)
	apply_directional_shadows_enabled(v)


## Toggle terrain sun shadows while playing (same pattern as FOV).
static func apply_directional_shadows_enabled(v: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("settings_directional_shadows"):
		if n is DirectionalLight3D:
			(n as DirectionalLight3D).shadow_enabled = v


## Backward-compatible alias.
static func get_sun_shadows_enabled() -> bool:
	return get_directional_shadows_enabled()


static func set_sun_shadows_enabled(v: bool) -> void:
	set_directional_shadows_enabled(v)


static func get_master_linear() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return 1.0
	return clampf(float(cfg.get_value(SEC_AUDIO, KEY_MASTER_LINEAR, 1.0)), 0.0, 1.0)


static func set_master_linear(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SEC_AUDIO, KEY_MASTER_LINEAR, v)
	cfg.save(CFG_PATH)
	apply_master_linear(v)


static func apply_master_linear(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	var bi := AudioServer.get_bus_index("Master")
	if bi >= 0:
		AudioServer.set_bus_volume_linear(bi, v)


static func sensitivity_from_slider_t(t: float) -> float:
	t = clampf(t, 1.0, 100.0)
	return MOUSE_SENS_MIN + (t - 1.0) / 99.0 * (MOUSE_SENS_MAX - MOUSE_SENS_MIN)


static func slider_t_from_sensitivity(sens: float) -> float:
	sens = clampf(sens, MOUSE_SENS_MIN, MOUSE_SENS_MAX)
	return 1.0 + (sens - MOUSE_SENS_MIN) / (MOUSE_SENS_MAX - MOUSE_SENS_MIN) * 99.0


static func get_mouse_sensitivity() -> float:
	return sensitivity_from_slider_t(get_mouse_sensitivity_slider_t())


static func get_mouse_sensitivity_slider_t() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return 41.0
	return clampf(float(cfg.get_value(SEC_CONTROLS, KEY_MOUSE_SENS_T, 41.0)), 1.0, 100.0)


static func set_mouse_sensitivity_slider_t(t: float) -> void:
	t = clampf(t, 1.0, 100.0)
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SEC_CONTROLS, KEY_MOUSE_SENS_T, t)
	cfg.save(CFG_PATH)


static func get_invert_mouse_y() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return false
	return bool(cfg.get_value(SEC_CONTROLS, KEY_INVERT_MOUSE_Y, false))


static func set_invert_mouse_y(v: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SEC_CONTROLS, KEY_INVERT_MOUSE_Y, v)
	cfg.save(CFG_PATH)


static func get_camera_fov() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return 90.0
	return clampf(float(cfg.get_value(SEC_VIDEO, KEY_CAMERA_FOV, 90.0)), FOV_MIN, FOV_MAX)


static func set_camera_fov(v: float) -> void:
	v = clampf(v, FOV_MIN, FOV_MAX)
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SEC_VIDEO, KEY_CAMERA_FOV, v)
	cfg.save(CFG_PATH)
	apply_camera_fov(v)


## Push FOV to in-world cameras (settings can change while playing).
static func apply_camera_fov(v: float) -> void:
	v = clampf(v, FOV_MIN, FOV_MAX)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("settings_player_camera_fov"):
		if n is Camera3D:
			(n as Camera3D).fov = v


static func get_third_person() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return false
	return bool(cfg.get_value(SEC_VIDEO, KEY_THIRD_PERSON, false))


static func set_third_person(v: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SEC_VIDEO, KEY_THIRD_PERSON, v)
	cfg.save(CFG_PATH)
	apply_camera_person_mode()


static func apply_camera_person_mode() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("settings_player_camera_person"):
		if n.has_method("apply_camera_person_from_settings"):
			n.call("apply_camera_person_from_settings")


static func get_skin_vox_path() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return _SkinCat.default_vox_path()
	var p := str(cfg.get_value(SEC_PLAYER, KEY_SKIN_VOX_PATH, _SkinCat.default_vox_path()))
	p = _SkinCat.normalize_vox_path(p)
	return _PlayerProgress.clamp_skin_vox_path_for_unlocks(p)


static func set_skin_vox_path(vox_path: String) -> void:
	var p := _SkinCat.normalize_vox_path(vox_path)
	p = _PlayerProgress.clamp_skin_vox_path_for_unlocks(p)
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SEC_PLAYER, KEY_SKIN_VOX_PATH, p)
	cfg.save(CFG_PATH)


## If the cfg still stores a locked skin, rewrite to the default free skin (one-time hygiene).
static func repair_skin_path_if_locked_in_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	var raw := str(cfg.get_value(SEC_PLAYER, KEY_SKIN_VOX_PATH, _SkinCat.default_vox_path()))
	var n := _SkinCat.normalize_vox_path(raw)
	var fixed := _PlayerProgress.clamp_skin_vox_path_for_unlocks(n)
	if fixed != n:
		cfg.set_value(SEC_PLAYER, KEY_SKIN_VOX_PATH, fixed)
		cfg.save(CFG_PATH)
