extends Control

@onready var list: VBoxContainer = %List


func _ready() -> void:
	for i in GameState.tournament_opponents.size():
		var oid: String = GameState.tournament_opponents[i]
		var opp: Dictionary = GameData.get_tournament_opponent(oid)
		var row := IconTextRow.make(
			oid,
			"Game %d: %s - %s" % [i + 1, opp.get("name", ""), opp.get("description", "")],
			22
		)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(row)


func _on_start() -> void:
	SceneNav.go_to_game()


func _on_back() -> void:
	SceneNav.go_to_tournament_pick()
