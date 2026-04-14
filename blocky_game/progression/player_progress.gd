extends RefCounted
class_name PlayerProgress

const CFG_PATH := "user://blocky_player_progress.cfg"

const SEC_CORE := "core"
const KEY_COINS := "coins"
const KEY_LIFETIME_BLOCKS := "lifetime_blocks_placed"
const KEY_LIFETIME_BLOCKS_BROKEN := "lifetime_blocks_broken"
const KEY_LIFETIME_COINS_PICKED := "lifetime_world_coins"
const KEY_LIFETIME_PLAY_SEC := "lifetime_play_seconds"

const SEC_DAILY := "daily"
const KEY_DAILY_DATE := "date"
const KEY_BLOCKS_TODAY := "blocks_placed"
const KEY_BLOCKS_BROKEN_TODAY := "blocks_broken_today"
const KEY_COINS_PICKED_TODAY := "world_coins_picked_today"
const KEY_PLAY_SEC_TODAY := "play_seconds_today"
const KEY_TYPES_TODAY := "block_types_csv"
const KEY_TIME_COINS_TODAY := "passive_coin_units_today"
const KEY_PASSIVE_ACC := "passive_seconds_acc"

const SEC_ACH := "achievements"
const KEY_UNLOCKED := "unlocked_csv"

const SEC_ACH_REWARD_CLAIMED := "ach_reward_claimed"
const KEY_ACH_REWARD_IDS := "ids_csv"

const SEC_CLAIMED_DAILY := "claimed_daily"
const KEY_CLAIMED_IDS := "ids_csv"

## Purchased map terrain ids and skin ids (free defaults need not appear).
const SEC_STORE := "store_unlocks"
const KEY_UNLOCKED_MAPS := "maps_csv"
const KEY_UNLOCKED_SKINS := "skins_csv"

const _WorldCatalog = preload("res://blocky_game/world_catalog.gd")
const _SkinCat = preload("res://blocky_game/skins/skin_catalog.gd")

## Daily: toast when a challenge becomes completable (once per id per day); cleared with the day.
const KEY_DAILY_TOAST_IDS := "challenge_toast_ids_csv"

const PASSIVE_SEC_PER_COIN := 45.0
const MAX_PASSIVE_COINS_PER_DAY := 40
const PASSIVE_COIN_VALUE := 1


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	return cfg


static func _save_cfg(cfg: ConfigFile) -> void:
	cfg.save(CFG_PATH)


static func _maybe_reset_daily(cfg: ConfigFile) -> void:
	var today := DailyChallengesCatalog.today_key()
	var cur: String = str(cfg.get_value(SEC_DAILY, KEY_DAILY_DATE, ""))
	if cur != today:
		cfg.set_value(SEC_DAILY, KEY_DAILY_DATE, today)
		cfg.set_value(SEC_DAILY, KEY_BLOCKS_TODAY, 0)
		cfg.set_value(SEC_DAILY, KEY_TYPES_TODAY, "")
		cfg.set_value(SEC_DAILY, KEY_TIME_COINS_TODAY, 0)
		cfg.set_value(SEC_DAILY, KEY_PASSIVE_ACC, 0.0)
		cfg.set_value(SEC_CLAIMED_DAILY, KEY_CLAIMED_IDS, "")
		cfg.set_value(SEC_DAILY, KEY_DAILY_TOAST_IDS, "")
		_save_cfg(cfg)


static func get_coins() -> int:
	var cfg := _cfg()
	return int(cfg.get_value(SEC_CORE, KEY_COINS, 0))


## Read-only snapshot for coins / rewards UI (applies daily rollover when the date changed).
static func get_coins_ui_snapshot() -> Dictionary:
	var cfg := _cfg()
	_maybe_reset_daily(cfg)
	_ensure_ach_reward_claim_migrated(cfg)
	return {
		&"blocks_today": int(cfg.get_value(SEC_DAILY, KEY_BLOCKS_TODAY, 0)),
		&"blocks_broken_today": int(cfg.get_value(SEC_DAILY, KEY_BLOCKS_BROKEN_TODAY, 0)),
		&"coins_picked_today": int(cfg.get_value(SEC_DAILY, KEY_COINS_PICKED_TODAY, 0)),
		&"play_seconds_today": float(cfg.get_value(SEC_DAILY, KEY_PLAY_SEC_TODAY, 0.0)),
		&"types_today_count": _types_today_set(cfg).size(),
		&"claimed_daily": _claimed_daily_set(cfg),
		&"ach_unlocked": _ach_unlocked_set(cfg),
		&"ach_reward_claimed": _ach_reward_claimed_set(cfg),
		&"lifetime_blocks": int(cfg.get_value(SEC_CORE, KEY_LIFETIME_BLOCKS, 0)),
		&"lifetime_blocks_broken": int(cfg.get_value(SEC_CORE, KEY_LIFETIME_BLOCKS_BROKEN, 0)),
		&"lifetime_play_sec": float(cfg.get_value(SEC_CORE, KEY_LIFETIME_PLAY_SEC, 0.0)),
		&"lifetime_pickups": int(cfg.get_value(SEC_CORE, KEY_LIFETIME_COINS_PICKED, 0)),
		&"passive_units_today": int(cfg.get_value(SEC_DAILY, KEY_TIME_COINS_TODAY, 0)),
		&"passive_acc_sec": float(cfg.get_value(SEC_DAILY, KEY_PASSIVE_ACC, 0.0)),
	}


## HUD / coins UI: unclaimed rewards (daily claim button ready, or achievement unlocked but reward not collected).
static func claimable_reward_flags() -> Dictionary:
	var cfg := _cfg()
	_maybe_reset_daily(cfg)
	_ensure_ach_reward_claim_migrated(cfg)
	var claimed := _claimed_daily_set(cfg)
	var daily_pending := false
	for ch in DailyChallengesCatalog.active_today():
		var cid: String = str(ch.get(&"id", ""))
		if claimed.has(cid):
			continue
		if _daily_challenge_row_done(cfg, ch):
			daily_pending = true
			break
	var ach_u := _ach_unlocked_set(cfg)
	var ach_r := _ach_reward_claimed_set(cfg)
	var ach_pending := false
	for row in AchievementsCatalog.all():
		var aid: String = str(row.get(&"id", ""))
		if ach_u.has(aid) and not ach_r.has(aid):
			ach_pending = true
			break
	return {
		&"daily": daily_pending,
		&"achievements": ach_pending,
		&"any": daily_pending or ach_pending,
	}


static func add_coins(amount: int, _source: String = "") -> void:
	if amount == 0:
		return
	var cfg := _cfg()
	var v := int(cfg.get_value(SEC_CORE, KEY_COINS, 0)) + amount
	cfg.set_value(SEC_CORE, KEY_COINS, maxi(0, v))
	_save_cfg(cfg)
	if Engine.has_singleton("ProgressionBus"):
		pass
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("/root/ProgressionBus")
	if bus != null and bus.has_method("notify_coins_changed"):
		bus.notify_coins_changed()


static func _notify_coins_changed() -> void:
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("/root/ProgressionBus")
	if bus != null and bus.has_method("notify_coins_changed"):
		bus.notify_coins_changed()


static func try_spend_coins(amount: int, _source: String = "") -> bool:
	if amount <= 0:
		return true
	var cfg := _cfg()
	var c := int(cfg.get_value(SEC_CORE, KEY_COINS, 0))
	if c < amount:
		return false
	cfg.set_value(SEC_CORE, KEY_COINS, c - amount)
	_save_cfg(cfg)
	_notify_coins_changed()
	return true


static func _store_unlocked_maps_set(cfg: ConfigFile) -> Dictionary:
	var raw: String = str(cfg.get_value(SEC_STORE, KEY_UNLOCKED_MAPS, ""))
	var d := {}
	for p in raw.split(","):
		if not p.is_empty():
			d[p] = true
	return d


static func _save_store_unlocked_maps(cfg: ConfigFile, d: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append(str(k))
	cfg.set_value(SEC_STORE, KEY_UNLOCKED_MAPS, ",".join(parts))


static func _store_unlocked_skins_set(cfg: ConfigFile) -> Dictionary:
	var raw: String = str(cfg.get_value(SEC_STORE, KEY_UNLOCKED_SKINS, ""))
	var d := {}
	for p in raw.split(","):
		if not p.is_empty():
			d[p] = true
	return d


static func _save_store_unlocked_skins(cfg: ConfigFile, d: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append(str(k))
	cfg.set_value(SEC_STORE, KEY_UNLOCKED_SKINS, ",".join(parts))


static func is_map_unlocked(map_id: String) -> bool:
	if _WorldCatalog.map_unlock_coin_cost(map_id) <= 0:
		return true
	var cfg := _cfg()
	return _store_unlocked_maps_set(cfg).has(map_id)


static func try_purchase_map_unlock(map_id: String) -> Dictionary:
	if is_map_unlocked(map_id):
		return {&"ok": true, &"already": true}
	var cost: int = _WorldCatalog.map_unlock_coin_cost(map_id)
	if cost <= 0:
		return {&"ok": true}
	if get_coins() < cost:
		return {&"ok": false, &"reason": &"not_enough_coins"}
	if not try_spend_coins(cost, "unlock_map_" + map_id):
		return {&"ok": false, &"reason": &"not_enough_coins"}
	var cfg := _cfg()
	var m := _store_unlocked_maps_set(cfg)
	m[map_id] = true
	_save_store_unlocked_maps(cfg, m)
	_save_cfg(cfg)
	return {&"ok": true}


static func is_skin_unlocked(skin_id: String) -> bool:
	if _SkinCat.skin_unlock_coin_cost_for_id(skin_id) <= 0:
		return true
	var cfg := _cfg()
	return _store_unlocked_skins_set(cfg).has(skin_id)


static func try_purchase_skin_unlock(skin_id: String) -> Dictionary:
	if is_skin_unlocked(skin_id):
		return {&"ok": true, &"already": true}
	var cost: int = _SkinCat.skin_unlock_coin_cost_for_id(skin_id)
	if cost <= 0:
		return {&"ok": true}
	if get_coins() < cost:
		return {&"ok": false, &"reason": &"not_enough_coins"}
	if not try_spend_coins(cost, "unlock_skin_" + skin_id):
		return {&"ok": false, &"reason": &"not_enough_coins"}
	var cfg := _cfg()
	var s := _store_unlocked_skins_set(cfg)
	s[skin_id] = true
	_save_store_unlocked_skins(cfg, s)
	_save_cfg(cfg)
	return {&"ok": true}


static func clamp_map_id_for_unlocks(map_id: String) -> String:
	if is_map_unlocked(map_id):
		return map_id
	return _WorldCatalog.default_map_id()


static func clamp_skin_vox_path_for_unlocks(vox_path: String) -> String:
	var norm := _SkinCat.normalize_vox_path(vox_path)
	var sid := _SkinCat.skin_id_for_vox_path(norm)
	if is_skin_unlocked(sid):
		return norm
	return _SkinCat.default_vox_path()


static func _types_today_set(cfg: ConfigFile) -> Dictionary:
	var raw: String = str(cfg.get_value(SEC_DAILY, KEY_TYPES_TODAY, ""))
	var d := {}
	if raw.is_empty():
		return d
	for p in raw.split(","):
		if p.is_valid_int():
			d[int(p)] = true
	return d


static func _save_types_today(cfg: ConfigFile, d: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append(str(int(k)))
	cfg.set_value(SEC_DAILY, KEY_TYPES_TODAY, ",".join(parts))


static func _claimed_daily_set(cfg: ConfigFile) -> Dictionary:
	var raw: String = str(cfg.get_value(SEC_CLAIMED_DAILY, KEY_CLAIMED_IDS, ""))
	var d := {}
	for p in raw.split(","):
		if not p.is_empty():
			d[p] = true
	return d


static func _save_claimed_daily(cfg: ConfigFile, d: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append(str(k))
	cfg.set_value(SEC_CLAIMED_DAILY, KEY_CLAIMED_IDS, ",".join(parts))


static func _ach_unlocked_set(cfg: ConfigFile) -> Dictionary:
	var raw: String = str(cfg.get_value(SEC_ACH, KEY_UNLOCKED, ""))
	var d := {}
	for p in raw.split(","):
		if not p.is_empty():
			d[p] = true
	return d


static func _save_ach(cfg: ConfigFile, d: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append(str(k))
	cfg.set_value(SEC_ACH, KEY_UNLOCKED, ",".join(parts))


static func _ach_reward_claimed_set(cfg: ConfigFile) -> Dictionary:
	var raw: String = str(cfg.get_value(SEC_ACH_REWARD_CLAIMED, KEY_ACH_REWARD_IDS, ""))
	var d := {}
	for p in raw.split(","):
		if not p.is_empty():
			d[p] = true
	return d


static func _save_ach_reward_claimed(cfg: ConfigFile, d: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append(str(k))
	cfg.set_value(SEC_ACH_REWARD_CLAIMED, KEY_ACH_REWARD_IDS, ",".join(parts))


## Older saves only stored unlocked achievement ids (coins were auto-granted); migrate that set into reward-claimed.
static func _ensure_ach_reward_claim_migrated(cfg: ConfigFile) -> void:
	if cfg.has_section(SEC_ACH_REWARD_CLAIMED):
		return
	var unlocked := _ach_unlocked_set(cfg)
	_save_ach_reward_claimed(cfg, unlocked.duplicate())
	_save_cfg(cfg)


static func _daily_toast_sent_set(cfg: ConfigFile) -> Dictionary:
	var raw: String = str(cfg.get_value(SEC_DAILY, KEY_DAILY_TOAST_IDS, ""))
	var d := {}
	for p in raw.split(","):
		if not p.is_empty():
			d[p] = true
	return d


static func _save_daily_toast_sent(cfg: ConfigFile, d: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append(str(k))
	cfg.set_value(SEC_DAILY, KEY_DAILY_TOAST_IDS, ",".join(parts))


static func _daily_challenge_row_done(cfg: ConfigFile, ch: Dictionary) -> bool:
	var blocks_today := int(cfg.get_value(SEC_DAILY, KEY_BLOCKS_TODAY, 0))
	var broken_today := int(cfg.get_value(SEC_DAILY, KEY_BLOCKS_BROKEN_TODAY, 0))
	var coins_today := int(cfg.get_value(SEC_DAILY, KEY_COINS_PICKED_TODAY, 0))
	var play_today := float(cfg.get_value(SEC_DAILY, KEY_PLAY_SEC_TODAY, 0.0))
	var types := _types_today_set(cfg)
	var kind: String = str(ch.get(&"kind", ""))
	var goal := int(ch.get(&"goal", 0))
	match kind:
		"blocks_placed":
			return blocks_today >= goal
		"distinct_blocks":
			return types.size() >= goal
		"coins_picked_today":
			return coins_today >= goal
		"play_seconds_today":
			return play_today >= float(goal)
		"blocks_broken_today":
			return broken_today >= goal
		"blocks_and_types":
			var gb := int(ch.get(&"goal_blocks", 0))
			var gt := int(ch.get(&"goal_types", 0))
			return blocks_today >= gb and types.size() >= gt
	return false


static func claim_daily_challenge(cid: String) -> bool:
	var cfg := _cfg()
	_maybe_reset_daily(cfg)
	var claimed := _claimed_daily_set(cfg)
	if claimed.has(cid):
		return false
	var row: Dictionary = {}
	for ch in DailyChallengesCatalog.active_today():
		if str(ch.get(&"id", "")) == cid:
			row = ch
			break
	if row.is_empty():
		return false
	if not _daily_challenge_row_done(cfg, row):
		return false
	var reward := int(row.get(&"reward", 0))
	claimed[cid] = true
	_save_claimed_daily(cfg, claimed)
	_save_cfg(cfg)
	add_coins(reward, "daily_claim_" + cid)
	return true


static func claim_achievement_reward(id: String) -> bool:
	var cfg := _cfg()
	_ensure_ach_reward_claim_migrated(cfg)
	cfg = _cfg()
	var ach := _ach_unlocked_set(cfg)
	if not ach.has(id):
		return false
	var taken := _ach_reward_claimed_set(cfg)
	if taken.has(id):
		return false
	var reward := 0
	for row in AchievementsCatalog.all():
		if str(row.get(&"id", "")) == id:
			reward = int(row.get(&"reward", 0))
			break
	taken[id] = true
	_save_ach_reward_claimed(cfg, taken)
	_save_cfg(cfg)
	add_coins(reward, "achievement_claim_" + id)
	return true


static func unlock_achievement(id: String, title: String, reward: int) -> void:
	var cfg := _cfg()
	_ensure_ach_reward_claim_migrated(cfg)
	cfg = _cfg()
	var ach := _ach_unlocked_set(cfg)
	if ach.has(id):
		return
	ach[id] = true
	_save_ach(cfg, ach)
	_save_cfg(cfg)
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("/root/ProgressionBus")
	if bus != null and bus.has_method("notify_achievement"):
		bus.notify_achievement(id, title, reward)


static func _check_achievements_after_block(cfg: ConfigFile, lifetime: int) -> void:
	var ach := _ach_unlocked_set(cfg)
	for row in AchievementsCatalog.all():
		var aid: String = str(row.get(&"id", ""))
		if ach.has(aid):
			continue
		var title: String = str(row.get(&"title", aid))
		var reward := int(row.get(&"reward", 0))
		match aid:
			"first_block":
				if lifetime >= 1:
					unlock_achievement(aid, title, reward)
			"blocks_150":
				if lifetime >= 150:
					unlock_achievement(aid, title, reward)
			"blocks_500":
				if lifetime >= 500:
					unlock_achievement(aid, title, reward)
			"blocks_1000":
				if lifetime >= 1000:
					unlock_achievement(aid, title, reward)
			"blocks_2000":
				if lifetime >= 2000:
					unlock_achievement(aid, title, reward)
			"blocks_5000":
				if lifetime >= 5000:
					unlock_achievement(aid, title, reward)
			"blocks_7500":
				if lifetime >= 7500:
					unlock_achievement(aid, title, reward)
			"blocks_10000":
				if lifetime >= 10000:
					unlock_achievement(aid, title, reward)


static func _check_achievements_coins_picked(cfg: ConfigFile, picked: int) -> void:
	var ach := _ach_unlocked_set(cfg)
	for row in AchievementsCatalog.all():
		var aid: String = str(row.get(&"id", ""))
		if ach.has(aid):
			continue
		var title: String = str(row.get(&"title", aid))
		var reward := int(row.get(&"reward", 0))
		match aid:
			"coin_finder_5":
				if picked >= 5:
					unlock_achievement(aid, title, reward)
			"coin_finder_20":
				if picked >= 20:
					unlock_achievement(aid, title, reward)
			"coin_finder_50":
				if picked >= 50:
					unlock_achievement(aid, title, reward)
			"coin_finder_100":
				if picked >= 100:
					unlock_achievement(aid, title, reward)
			"coin_finder_250":
				if picked >= 250:
					unlock_achievement(aid, title, reward)
			"coin_finder_500":
				if picked >= 500:
					unlock_achievement(aid, title, reward)
			"coin_finder_750":
				if picked >= 750:
					unlock_achievement(aid, title, reward)
			"coin_finder_1000":
				if picked >= 1000:
					unlock_achievement(aid, title, reward)


static func _check_achievements_playtime(cfg: ConfigFile, play_sec: float) -> void:
	var ach := _ach_unlocked_set(cfg)
	for row in AchievementsCatalog.all():
		var aid: String = str(row.get(&"id", ""))
		if ach.has(aid):
			continue
		var title: String = str(row.get(&"title", aid))
		var reward := int(row.get(&"reward", 0))
		match aid:
			"playtime_10m":
				if play_sec >= 600.0:
					unlock_achievement(aid, title, reward)
			"playtime_45m":
				if play_sec >= 2700.0:
					unlock_achievement(aid, title, reward)
			"playtime_3h":
				if play_sec >= 10800.0:
					unlock_achievement(aid, title, reward)
			"playtime_10h":
				if play_sec >= 36000.0:
					unlock_achievement(aid, title, reward)
			"playtime_25h":
				if play_sec >= 90000.0:
					unlock_achievement(aid, title, reward)


static func record_world_coin_collected() -> void:
	var cfg := _cfg()
	_maybe_reset_daily(cfg)
	var n := int(cfg.get_value(SEC_CORE, KEY_LIFETIME_COINS_PICKED, 0)) + 1
	cfg.set_value(SEC_CORE, KEY_LIFETIME_COINS_PICKED, n)
	var ct := int(cfg.get_value(SEC_DAILY, KEY_COINS_PICKED_TODAY, 0)) + 1
	cfg.set_value(SEC_DAILY, KEY_COINS_PICKED_TODAY, ct)
	_save_cfg(cfg)
	_check_achievements_coins_picked(cfg, n)
	_evaluate_daily_challenges(cfg)


static func record_block_placed(block_id: int) -> void:
	if block_id == 0:
		return
	var cfg := _cfg()
	_maybe_reset_daily(cfg)
	var life := int(cfg.get_value(SEC_CORE, KEY_LIFETIME_BLOCKS, 0)) + 1
	cfg.set_value(SEC_CORE, KEY_LIFETIME_BLOCKS, life)
	var bt := int(cfg.get_value(SEC_DAILY, KEY_BLOCKS_TODAY, 0)) + 1
	cfg.set_value(SEC_DAILY, KEY_BLOCKS_TODAY, bt)
	var types := _types_today_set(cfg)
	types[block_id] = true
	_save_types_today(cfg, types)
	_save_cfg(cfg)
	_check_achievements_after_block(cfg, life)
	_evaluate_daily_challenges(cfg)


static func _evaluate_daily_challenges(cfg: ConfigFile) -> void:
	_maybe_reset_daily(cfg)
	var claimed := _claimed_daily_set(cfg)
	var toasted := _daily_toast_sent_set(cfg)
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("/root/ProgressionBus")
	for ch in DailyChallengesCatalog.active_today():
		var cid: String = str(ch.get(&"id", ""))
		if claimed.has(cid):
			continue
		var title: String = str(ch.get(&"title", cid))
		var reward := int(ch.get(&"reward", 0))
		if not _daily_challenge_row_done(cfg, ch):
			continue
		if not toasted.has(cid):
			toasted[cid] = true
			_save_daily_toast_sent(cfg, toasted)
			_save_cfg(cfg)
			if bus != null and bus.has_method("notify_daily"):
				bus.notify_daily(cid, title, reward)


static func record_block_broken() -> void:
	var cfg := _cfg()
	_maybe_reset_daily(cfg)
	var bk := int(cfg.get_value(SEC_DAILY, KEY_BLOCKS_BROKEN_TODAY, 0)) + 1
	cfg.set_value(SEC_DAILY, KEY_BLOCKS_BROKEN_TODAY, bk)
	var life_bk := int(cfg.get_value(SEC_CORE, KEY_LIFETIME_BLOCKS_BROKEN, 0)) + 1
	cfg.set_value(SEC_CORE, KEY_LIFETIME_BLOCKS_BROKEN, life_bk)
	_save_cfg(cfg)
	_check_achievements_blocks_broken(_cfg(), life_bk)
	_evaluate_daily_challenges(cfg)


static func _check_achievements_blocks_broken(cfg: ConfigFile, broken: int) -> void:
	var ach := _ach_unlocked_set(cfg)
	for row in AchievementsCatalog.all():
		var aid: String = str(row.get(&"id", ""))
		if ach.has(aid):
			continue
		var title: String = str(row.get(&"title", aid))
		var reward := int(row.get(&"reward", 0))
		match aid:
			"breaker_500":
				if broken >= 500:
					unlock_achievement(aid, title, reward)
			"breaker_1000":
				if broken >= 1000:
					unlock_achievement(aid, title, reward)
			"breaker_2500":
				if broken >= 2500:
					unlock_achievement(aid, title, reward)


static func add_play_time(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	# Tab out / debugger spikes can accrue huge passive chunks in one frame.
	delta_seconds = minf(delta_seconds, 0.25)
	var cfg := _cfg()
	_maybe_reset_daily(cfg)
	var day_play := float(cfg.get_value(SEC_DAILY, KEY_PLAY_SEC_TODAY, 0.0)) + delta_seconds
	cfg.set_value(SEC_DAILY, KEY_PLAY_SEC_TODAY, day_play)
	var life := float(cfg.get_value(SEC_CORE, KEY_LIFETIME_PLAY_SEC, 0.0)) + delta_seconds
	cfg.set_value(SEC_CORE, KEY_LIFETIME_PLAY_SEC, life)
	_save_cfg(cfg)
	_check_achievements_playtime(_cfg(), life)
	cfg = _cfg()
	var units_today := int(cfg.get_value(SEC_DAILY, KEY_TIME_COINS_TODAY, 0))
	var acc := float(cfg.get_value(SEC_DAILY, KEY_PASSIVE_ACC, 0.0)) + delta_seconds
	var earned := 0
	if units_today < MAX_PASSIVE_COINS_PER_DAY:
		while acc >= PASSIVE_SEC_PER_COIN and units_today + earned < MAX_PASSIVE_COINS_PER_DAY:
			acc -= PASSIVE_SEC_PER_COIN
			earned += 1
	cfg.set_value(SEC_DAILY, KEY_PASSIVE_ACC, acc)
	if earned > 0:
		cfg.set_value(SEC_DAILY, KEY_TIME_COINS_TODAY, units_today + earned)
		var c := int(cfg.get_value(SEC_CORE, KEY_COINS, 0)) + earned * PASSIVE_COIN_VALUE
		cfg.set_value(SEC_CORE, KEY_COINS, c)
	_save_cfg(cfg)
	if earned > 0:
		var bus: Node = Engine.get_main_loop().root.get_node_or_null("/root/ProgressionBus")
		if bus != null and bus.has_method("notify_coins_changed"):
			bus.notify_coins_changed()
	_evaluate_daily_challenges(_cfg())
