extends Node

const TAG := "GameState"

var selected_gym_id: String = "vanilla"
var tournament_loadout: Array = []
var tournament_opponents: Array = []
var tournament_opponent_index: int = 0
var tournament_stolen_power: String = ""
var show_champion_celebration: bool = false


func _ready() -> void:
	DebugLog.log(TAG, "_ready")


func reset_tournament() -> void:
	tournament_loadout = []
	tournament_opponents = []
	tournament_opponent_index = 0
	tournament_stolen_power = ""
