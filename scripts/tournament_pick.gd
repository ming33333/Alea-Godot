extends Control

const PICK_COUNT := 3

@onready var options_box: VBoxContainer = %OptionsBox
@onready var confirm_btn: Button = %ConfirmBtn
@onready var status_label: Label = %StatusLabel
@onready var bracket_section: Control = %BracketSection
@onready var bracket_list: VBoxContainer = %BracketList

var _selected: Array[String] = []
var _checkboxes: Dictionary = {}


func _ready() -> void:
	for t in GameData.tournament_pickable:
		var def: Dictionary = GameData.get_power_def(str(t))
		var cb := CheckBox.new()
		cb.text = "%s — %s" % [def.get("label", t), def.get("description", "")]
		cb.toggled.connect(_on_toggle.bind(str(t)))
		options_box.add_child(cb)
		_checkboxes[str(t)] = cb
	confirm_btn.disabled = true
	_roll_and_show_bracket()


func _on_toggle(checked: bool, power_type: String) -> void:
	if checked:
		if _selected.size() >= PICK_COUNT:
			_checkboxes[power_type].button_pressed = false
			return
		_selected.append(power_type)
	else:
		_selected.erase(power_type)
	status_label.text = "Selected %d / %d" % [_selected.size(), PICK_COUNT]
	confirm_btn.disabled = _selected.size() != PICK_COUNT


func _roll_and_show_bracket() -> void:
	GameState.tournament_opponents = TournamentRules.pick_opponents(PICK_COUNT)
	if GameState.tournament_opponents.is_empty():
		push_error("TournamentPick: failed to roll opponents — check data/tournament.json")
		bracket_section.visible = false
		confirm_btn.disabled = true
		status_label.text = "Tournament data missing — cannot start"
		return
	_refresh_bracket_list()
	bracket_section.visible = true


func _refresh_bracket_list() -> void:
	for child in bracket_list.get_children():
		child.queue_free()
	for i in GameState.tournament_opponents.size():
		var oid: String = str(GameState.tournament_opponents[i])
		var opp: Dictionary = GameData.get_tournament_opponent(oid)
		var label := Label.new()
		label.text = "Match %d: %s %s — %s" % [
			i + 1,
			opp.get("emoji", ""),
			opp.get("name", oid),
			opp.get("description", ""),
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bracket_list.add_child(label)


func _on_confirm() -> void:
	if _selected.size() != PICK_COUNT:
		return
	if GameState.tournament_opponents.is_empty():
		_roll_and_show_bracket()
	if GameState.tournament_opponents.is_empty():
		return
	GameState.championship_active = true
	GameState.tournament_loadout = _selected.duplicate()
	GameState.tournament_opponent_index = 0
	GameState.tournament_stolen_power = ""
	SceneNav.go_to_game()


func _on_back() -> void:
	GameState.reset_tournament()
	SceneNav.go_to_main_menu()
