extends Control

const PICK_COUNT := 3
const POWER_PICK_TILE: PackedScene = preload("res://scenes/power_pick_tile.tscn")
const GRID_COLUMNS := 4
const DETAIL_DEFAULT := "Tap a die to add it to your loadout."

@onready var options_box: GridContainer = %OptionsBox
@onready var confirm_btn: Button = %ConfirmBtn
@onready var status_label: Label = %StatusLabel
@onready var detail_label: Label = %DetailLabel
@onready var bracket_section: Control = %BracketSection
@onready var bracket_list: VBoxContainer = %BracketList

var _selected: Array[String] = []
var _tiles: Dictionary = {}
var _hover_power_type: String = ""


func _ready() -> void:
	options_box.columns = GRID_COLUMNS
	options_box.add_theme_constant_override("h_separation", 12)
	options_box.add_theme_constant_override("v_separation", 12)
	for t in GameData.tournament_pickable:
		var power_type: String = str(t)
		var def: Dictionary = GameData.get_power_def(power_type)
		var tile: PowerPickTile = POWER_PICK_TILE.instantiate() as PowerPickTile
		tile.setup(power_type, str(def.get("label", power_type)))
		tile.pressed.connect(_on_tile_pressed.bind(power_type))
		tile.hovered.connect(_on_tile_hovered)
		tile.unhovered.connect(_on_tile_unhovered)
		options_box.add_child(tile)
		_tiles[power_type] = tile
	detail_label.text = DETAIL_DEFAULT
	confirm_btn.disabled = true
	_roll_and_show_bracket()


func _on_tile_pressed(power_type: String) -> void:
	if _selected.has(power_type):
		_selected.erase(power_type)
	elif _selected.size() < PICK_COUNT:
		_selected.append(power_type)
	_refresh_tile_states()
	status_label.text = "Selected %d / %d" % [_selected.size(), PICK_COUNT]
	confirm_btn.disabled = _selected.size() != PICK_COUNT


func _refresh_tile_states() -> void:
	var full: bool = _selected.size() >= PICK_COUNT
	for power_type in _tiles:
		var tile: PowerPickTile = _tiles[power_type] as PowerPickTile
		var is_sel: bool = _selected.has(power_type)
		tile.set_tile_selected(is_sel)
		tile.set_locked_out(full and not is_sel)


func _on_tile_hovered(power_type: String) -> void:
	_hover_power_type = power_type
	var def: Dictionary = GameData.get_power_def(power_type)
	detail_label.text = "%s — %s" % [
		def.get("label", power_type),
		PowerLogic.format_power_short(def),
	]


func _on_tile_unhovered(_power_type: String) -> void:
	_hover_power_type = ""
	detail_label.text = DETAIL_DEFAULT


func _roll_and_show_bracket() -> void:
	GameState.tournament_opponents = TournamentRules.pick_opponents(PICK_COUNT)
	if GameState.tournament_opponents.is_empty():
		push_error("TournamentPick: failed to roll opponents — check data/tournament.json")
		bracket_section.visible = false
		confirm_btn.disabled = true
		status_label.text = "Test data missing - cannot start"
		return
	_refresh_bracket_list()
	bracket_section.visible = true


func _refresh_bracket_list() -> void:
	for child in bracket_list.get_children():
		child.queue_free()
	for i in GameState.tournament_opponents.size():
		var oid: String = str(GameState.tournament_opponents[i])
		var opp: Dictionary = GameData.get_tournament_opponent(oid)
		var row := IconTextRow.make(
			oid,
			"Game %d: %s - %s" % [i + 1, opp.get("name", oid), opp.get("description", "")],
			22
		)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bracket_list.add_child(row)


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
