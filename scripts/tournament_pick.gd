extends Control

const PICK_COUNT := 3

@onready var options_box: VBoxContainer = %OptionsBox
@onready var confirm_btn: Button = %ConfirmBtn
@onready var status_label: Label = %StatusLabel

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


func _on_confirm() -> void:
	GameState.tournament_loadout = _selected.duplicate()
	GameState.tournament_opponents = TournamentRules.pick_opponents(3)
	GameState.tournament_opponent_index = 0
	GameState.tournament_stolen_power = ""
	SceneNav.go_to_tournament_preview()


func _on_back() -> void:
	SceneNav.go_to_main_menu()
