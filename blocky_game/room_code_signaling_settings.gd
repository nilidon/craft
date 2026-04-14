extends RefCounted
class_name RoomCodeSignalingSettings

## Fixed UDP port for ENet (must match signaling registrations and firewall rules).
const DEFAULT_GAME_PORT := 25000


## HTTP signaling base URL — set in Project Settings → `creative_craft/signaling_url` before export.
## Players never see this; only room codes are shown in the UI.
static func get_base_url() -> String:
	if ProjectSettings.has_setting("creative_craft/signaling_url"):
		var p := str(ProjectSettings.get_setting("creative_craft/signaling_url")).strip_edges()
		if not p.is_empty():
			return _trim_slash(p)
	return ""


static func _trim_slash(s: String) -> String:
	while s.ends_with("/"):
		s = s.substr(0, s.length() - 1)
	return s
