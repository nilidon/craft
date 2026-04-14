extends RefCounted
class_name AchievementsCatalog

## Sub-pages inside the Achievements tab (see [method rows_for_page]).
const PAGE_BUILDER := 0
const PAGE_TREASURE := 1
const PAGE_VETERAN := 2

## Goals tuned to how players actually play: world coins are sparse vs blocks placed;
## playtime tiers ramp smoothly; break counts match casual→regular mining (not thousands per session).


static func page_count() -> int:
	return 3


static func page_title(page: int) -> String:
	match page:
		PAGE_BUILDER:
			return "Builder"
		PAGE_TREASURE:
			return "Treasure"
		PAGE_VETERAN:
			return "Veteran"
	return "—"


static func all() -> Array[Dictionary]:
	return [
		{
			&"id": &"first_block",
			&"page": PAGE_BUILDER,
			&"title": "First block",
			&"reward": 5,
			&"description": "Place your first block in any world.",
		},
		{
			&"id": &"blocks_150",
			&"page": PAGE_BUILDER,
			&"title": "Getting started",
			&"reward": 25,
			&"description": "Place 150 blocks lifetime.",
		},
		{
			&"id": &"blocks_500",
			&"page": PAGE_BUILDER,
			&"title": "Constructor",
			&"reward": 50,
			&"description": "Place 500 blocks lifetime.",
		},
		{
			&"id": &"blocks_1000",
			&"page": PAGE_BUILDER,
			&"title": "Architect",
			&"reward": 80,
			&"description": "Place 1,000 blocks lifetime.",
		},
		{
			&"id": &"blocks_2000",
			&"page": PAGE_BUILDER,
			&"title": "City works",
			&"reward": 100,
			&"description": "Place 2,000 blocks lifetime.",
		},
		{
			&"id": &"blocks_5000",
			&"page": PAGE_BUILDER,
			&"title": "Skyline",
			&"reward": 150,
			&"description": "Place 5,000 blocks lifetime.",
		},
		{
			&"id": &"blocks_7500",
			&"page": PAGE_BUILDER,
			&"title": "Megastructure",
			&"reward": 200,
			&"description": "Place 7,500 blocks lifetime.",
		},
		{
			&"id": &"blocks_10000",
			&"page": PAGE_BUILDER,
			&"title": "Continent",
			&"reward": 300,
			&"description": "Place 10,000 blocks lifetime.",
		},
		{
			&"id": &"coin_finder_5",
			&"page": PAGE_TREASURE,
			&"title": "First finds",
			&"reward": 10,
			&"description": "Pick up 5 world gold coins.",
		},
		{
			&"id": &"coin_finder_20",
			&"page": PAGE_TREASURE,
			&"title": "Shiny things",
			&"reward": 30,
			&"description": "Pick up 20 world gold coins.",
		},
		{
			&"id": &"coin_finder_50",
			&"page": PAGE_TREASURE,
			&"title": "Pocket change",
			&"reward": 50,
			&"description": "Pick up 50 world gold coins.",
		},
		{
			&"id": &"coin_finder_100",
			&"page": PAGE_TREASURE,
			&"title": "Treasure scout",
			&"reward": 80,
			&"description": "Pick up 100 world gold coins.",
		},
		{
			&"id": &"coin_finder_250",
			&"page": PAGE_TREASURE,
			&"title": "Treasure hunter",
			&"reward": 100,
			&"description": "Pick up 250 world gold coins.",
		},
		{
			&"id": &"coin_finder_500",
			&"page": PAGE_TREASURE,
			&"title": "Gold rush",
			&"reward": 150,
			&"description": "Pick up 500 world gold coins.",
		},
		{
			&"id": &"coin_finder_750",
			&"page": PAGE_TREASURE,
			&"title": "Serious collector",
			&"reward": 250,
			&"description": "Pick up 750 world gold coins.",
		},
		{
			&"id": &"coin_finder_1000",
			&"page": PAGE_TREASURE,
			&"title": "Dragon's tally",
			&"reward": 350,
			&"description": "Pick up 1,000 world gold coins.",
		},
		{
			&"id": &"playtime_10m",
			&"page": PAGE_VETERAN,
			&"title": "Settling in",
			&"reward": 10,
			&"description": "Spend 10 minutes playing (lifetime).",
		},
		{
			&"id": &"playtime_45m",
			&"page": PAGE_VETERAN,
			&"title": "Regular visitor",
			&"reward": 25,
			&"description": "Spend 45 minutes playing (lifetime).",
		},
		{
			&"id": &"playtime_3h",
			&"page": PAGE_VETERAN,
			&"title": "Dedicated",
			&"reward": 50,
			&"description": "Spend 3 hours playing (lifetime).",
		},
		{
			&"id": &"playtime_10h",
			&"page": PAGE_VETERAN,
			&"title": "Marathon builder",
			&"reward": 100,
			&"description": "Spend 10 hours playing (lifetime).",
		},
		{
			&"id": &"playtime_25h",
			&"page": PAGE_VETERAN,
			&"title": "Lives here",
			&"reward": 200,
			&"description": "Spend 25 hours playing (lifetime).",
		},
		{
			&"id": &"breaker_500",
			&"page": PAGE_VETERAN,
			&"title": "Demolition practice",
			&"reward": 100,
			&"description": "Break 500 blocks lifetime.",
		},
		{
			&"id": &"breaker_1000",
			&"page": PAGE_VETERAN,
			&"title": "Wrecking ball",
			&"reward": 200,
			&"description": "Break 1,000 blocks lifetime.",
		},
		{
			&"id": &"breaker_2500",
			&"page": PAGE_VETERAN,
			&"title": "Total teardown",
			&"reward": 250,
			&"description": "Break 2,500 blocks lifetime.",
		},
	]


static func rows_for_page(page: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in all():
		if int(r.get(&"page", PAGE_BUILDER)) == page:
			out.append(r)
	return out
