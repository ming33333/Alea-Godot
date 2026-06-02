extends Control

@onready var list: VBoxContainer = %List


func _ready() -> void:
	for i in GameState.tournament_opponents.size():
		var oid: String = GameState.tournament_opponents[i]
		var opp: Dictionary = GameData.get_tournament_opponent(oid)
		var l := Label.new()
		l.text = "Match %d: %s %s — %s" % [
			i + 1, opp.get("emoji", ""), opp.get("name", ""), opp.get("description", "")
		]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(l)


func _on_start() -> void:
	SceneNav.go_to_game()


func _on_back() -> void:
	SceneNav.go_to_tournament_pick()
