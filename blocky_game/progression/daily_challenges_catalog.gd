extends RefCounted
class_name DailyChallengesCatalog


static func today_key() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(t.year), int(t.month), int(t.day)]


## Seconds until the next local calendar midnight (same boundary as [method today_key] rollover).
static func seconds_until_local_midnight() -> int:
	var t := Time.get_datetime_dict_from_system()
	var h := int(t.hour)
	var mi := int(t.minute)
	var s := int(t.second)
	var elapsed := h * 3600 + mi * 60 + s
	return maxi(0, 86400 - elapsed)


## Every challenge definition; [method active_today] picks 2 per calendar day (deterministic shuffle).
static func _pool() -> Array[Dictionary]:
	return [
		{
			&"id": &"scavenger_5",
			&"title": "Coin scavenger",
			&"description": "Pick up 5 gold coin pickups in the world today.",
			&"kind": &"coins_picked_today",
			&"goal": 5,
			&"reward": 25,
		},
		{
			&"id": &"play_10m",
			&"title": "Time well spent",
			&"description": "Spend 10 minutes playing today.",
			&"kind": &"play_seconds_today",
			&"goal": 600,
			&"reward": 20,
		},
		{
			&"id": &"breaker_25",
			&"title": "Demolition",
			&"description": "Break 25 blocks today.",
			&"kind": &"blocks_broken_today",
			&"goal": 25,
			&"reward": 20,
		},
		{
			&"id": &"heavy_100",
			&"title": "Heavy builder",
			&"description": "Place 100 blocks today.",
			&"kind": &"blocks_placed",
			&"goal": 100,
			&"reward": 45,
		},
		{
			&"id": &"mix_35_5",
			&"title": "Variety & volume",
			&"description": "Place 35 blocks using at least 5 different block types today.",
			&"kind": &"blocks_and_types",
			&"goal_blocks": 35,
			&"goal_types": 5,
			&"reward": 25,
		},
	]


## Two random challenges for today (same picks all day for everyone; changes at midnight).
static func active_today() -> Array[Dictionary]:
	var pool := _pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(today_key()))
	var order: Array[int] = []
	for i in range(pool.size()):
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	return [pool[order[0]], pool[order[1]]]


## Full pool (debug / tooling). Gameplay uses [method active_today].
static func all() -> Array[Dictionary]:
	return _pool()
