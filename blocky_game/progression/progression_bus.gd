extends Node
## Autoload: UI and gameplay hooks for [PlayerProgress].

const PlayerProgress = preload("res://blocky_game/progression/player_progress.gd")

signal coins_changed(new_balance: int)
signal achievement_unlocked(id: String, title: String, coin_reward: int)
signal daily_challenge_completed(id: String, title: String, coin_reward: int)


func notify_coins_changed() -> void:
	coins_changed.emit(PlayerProgress.get_coins())


func notify_achievement(id: String, title: String, coin_reward: int) -> void:
	achievement_unlocked.emit(id, title, coin_reward)


func notify_daily(id: String, title: String, coin_reward: int) -> void:
	daily_challenge_completed.emit(id, title, coin_reward)
