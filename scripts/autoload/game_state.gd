extends Node

const TAG := "GameState"

var selected_challenge_orb_id: String = "vanilla"
var championship_active: bool = false
var tournament_loadout: Array = []
var tournament_opponents: Array = []
var tournament_opponent_index: int = 0
var tournament_stolen_power: String = ""
var show_champion_celebration: bool = false


func _ready() -> void:
	DebugLog.log(TAG, "_ready")


func reset_tournament() -> void:
	championship_active = false
	tournament_loadout = []
	tournament_opponents = []
	tournament_opponent_index = 0
	tournament_stolen_power = ""


func start_championship_prep() -> void:
	reset_tournament()
	championship_active = true


func is_championship_run() -> bool:
	return championship_active and tournament_opponents.size() > 0
