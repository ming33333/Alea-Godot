extends Control

const PICK_COUNT := 3
const POWER_PICK_TILE: PackedScene = preload("res://scenes/power_pick_tile.tscn")
const CROWN_PICK_TILE: PackedScene = preload("res://scenes/crown_pick_tile.tscn")
const GRID_COLUMNS := 4
const CROWN_GRID_COLUMNS := 2
const DETAIL_DEFAULT := "Hover a power to see what it does."
const DETAIL_PANEL_HEIGHT := 90.0

@onready var subtitle: Label = %Subtitle
@onready var options_box: GridContainer = %OptionsBox
@onready var confirm_btn: Button = %ConfirmBtn
@onready var status_label: Label = %StatusLabel
@onready var detail_label: Label = %DetailLabel
@onready var crown_section: Control = %CrownSection
@onready var crown_title: Label = %CrownTitle
@onready var crown_options_box: GridContainer = %CrownOptionsBox
@onready var bracket_section: Control = %BracketSection
@onready var bracket_title: Label = %BracketTitle
@onready var bracket_list: VBoxContainer = %BracketList
@onready var detail_wrap: PanelContainer = %DetailWrap

var _selected_powers: Array[String] = []
var _power_tiles: Dictionary = {}
var _crown_tiles: Dictionary = {}
var _selected_crown: int = 0
var _crown_pick_mode: bool = false


func _ready() -> void:
	_style_detail_wrap()
	_crown_pick_mode = SaveService.has_any_crown()
	options_box.columns = GRID_COLUMNS
	options_box.add_theme_constant_override("h_separation", 12)
	options_box.add_theme_constant_override("v_separation", 12)
	for t in GameData.tournament_pickable:
		var power_type: String = str(t)
		var def: Dictionary = GameData.get_power_def(power_type)
		var tile: PowerPickTile = POWER_PICK_TILE.instantiate() as PowerPickTile
		tile.setup(power_type, str(def.get("label", power_type)))
		tile.pressed.connect(_on_power_tile_pressed.bind(power_type))
		tile.hovered.connect(_on_power_tile_hovered)
		tile.unhovered.connect(_on_power_tile_unhovered)
		options_box.add_child(tile)
		_power_tiles[power_type] = tile
	detail_label.text = DETAIL_DEFAULT
	if _crown_pick_mode:
		_setup_crown_pick()
	else:
		_roll_random_bracket()
	_update_subtitle()
	_refresh_confirm_state()


func _style_detail_wrap() -> void:
	if detail_wrap == null:
		return
	detail_wrap.custom_minimum_size = Vector2(0.0, DETAIL_PANEL_HEIGHT)
	detail_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.12, 0.32)
	box.set_corner_radius_all(8)
	box.content_margin_left = 4.0
	box.content_margin_top = 2.0
	box.content_margin_right = 4.0
	box.content_margin_bottom = 2.0
	detail_wrap.add_theme_stylebox_override("panel", box)
	detail_wrap.clip_contents = true
	if detail_label != null:
		detail_label.clip_text = true
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.max_lines_visible = 5
		detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _setup_crown_pick() -> void:
	crown_section.visible = true
	crown_options_box.columns = CROWN_GRID_COLUMNS
	crown_options_box.add_theme_constant_override("h_separation", 12)
	crown_options_box.add_theme_constant_override("v_separation", 12)
	for crown_idx in range(1, DiceCrownArt.crown_count() + 1):
		var opponents: Array[String] = DiceCrownArt.opponents_for_crown(crown_idx)
		var tile: CrownPickTile = CROWN_PICK_TILE.instantiate() as CrownPickTile
		tile.setup(crown_idx, DiceCrownArt.format_combo_names(opponents))
		var earned: bool = SaveService.has_crown(crown_idx)
		tile.set_tile_earned(earned)
		if not earned:
			tile.pressed.connect(_on_crown_tile_pressed.bind(crown_idx))
			tile.hovered.connect(_on_crown_tile_hovered)
			tile.unhovered.connect(_on_crown_tile_unhovered)
		crown_options_box.add_child(tile)
		_crown_tiles[crown_idx] = tile
	bracket_section.visible = false
	if SaveService.has_all_crowns():
		crown_title.text = "All crowns collected"
		status_label.text = "You have every crown"
	else:
		crown_title.text = "Choose a crown challenge"
		status_label.text = "Pick a crown, then begin"


func _update_subtitle() -> void:
	if _crown_pick_mode:
		if SaveService.has_all_crowns():
			subtitle.text = "Pick 3 power dice — all crowns earned"
		else:
			subtitle.text = "Pick 3 powers, then choose a crown to pursue"
	else:
		subtitle.text = "Pick 3 power dice for your loadout"


func _on_power_tile_pressed(power_type: String) -> void:
	if _selected_powers.has(power_type):
		_selected_powers.erase(power_type)
	elif _selected_powers.size() < PICK_COUNT:
		_selected_powers.append(power_type)
	_refresh_power_tile_states()
	_refresh_confirm_state()


func _refresh_power_tile_states() -> void:
	var full: bool = _selected_powers.size() >= PICK_COUNT
	for power_type in _power_tiles:
		var tile: PowerPickTile = _power_tiles[power_type] as PowerPickTile
		var is_sel: bool = _selected_powers.has(power_type)
		tile.set_tile_selected(is_sel)
		tile.set_locked_out(full and not is_sel)


func _on_power_tile_hovered(power_type: String) -> void:
	var def: Dictionary = GameData.get_power_def(power_type)
	var label: String = str(def.get("label", power_type))
	detail_label.text = "%s\n\n%s" % [label, PowerLogic.format_power_detail(def)]


func _on_power_tile_unhovered(_power_type: String) -> void:
	detail_label.text = _detail_hint_text()


func _on_crown_tile_pressed(crown_idx: int) -> void:
	if SaveService.has_crown(crown_idx):
		return
	_selected_crown = crown_idx
	GameState.tournament_opponents = DiceCrownArt.opponents_for_crown(crown_idx)
	_refresh_crown_tile_states()
	_refresh_bracket_list()
	bracket_section.visible = true
	bracket_title.text = "Your three games"
	_refresh_confirm_state()


func _refresh_crown_tile_states() -> void:
	for crown_idx in _crown_tiles:
		var tile: CrownPickTile = _crown_tiles[crown_idx] as CrownPickTile
		if SaveService.has_crown(crown_idx):
			continue
		tile.set_tile_selected(crown_idx == _selected_crown)


func _on_crown_tile_hovered(crown_idx: int) -> void:
	var opponents: Array[String] = DiceCrownArt.opponents_for_crown(crown_idx)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"Win against %s." % DiceCrownArt.format_combo_names(opponents)
	)
	for oid in opponents:
		var opp: Dictionary = GameData.get_tournament_opponent(oid)
		lines.append(
			"%s — %s" % [opp.get("name", oid), opp.get("description", "")]
		)
	detail_label.text = "\n".join(lines)


func _on_crown_tile_unhovered(_crown_idx: int) -> void:
	detail_label.text = _detail_hint_text()


func _detail_hint_text() -> String:
	if _crown_pick_mode and not SaveService.has_all_crowns():
		if _selected_crown > 0:
			return "Ready when your loadout and crown are set."
		return "Tap a crown to see its three test games."
	return DETAIL_DEFAULT


func _refresh_confirm_state() -> void:
	var powers_ok: bool = _selected_powers.size() == PICK_COUNT
	if not _crown_pick_mode:
		status_label.text = "Selected %d / %d" % [_selected_powers.size(), PICK_COUNT]
		confirm_btn.disabled = not powers_ok
		return
	if SaveService.has_all_crowns():
		status_label.text = "All crowns collected"
		confirm_btn.disabled = true
		return
	var crown_ok: bool = _selected_crown > 0 and not SaveService.has_crown(_selected_crown)
	if not powers_ok:
		status_label.text = "Selected %d / %d powers" % [_selected_powers.size(), PICK_COUNT]
	elif not crown_ok:
		status_label.text = "Choose a crown challenge"
	else:
		status_label.text = "Ready to begin"
	confirm_btn.disabled = not (powers_ok and crown_ok)


func _roll_random_bracket() -> void:
	GameState.tournament_opponents = TournamentRules.pick_opponents(PICK_COUNT)
	if GameState.tournament_opponents.is_empty():
		push_error("TournamentPick: failed to roll opponents — check data/tournament.json")
		bracket_section.visible = false
		confirm_btn.disabled = true
		status_label.text = "Test data missing - cannot start"
		return
	_refresh_bracket_list()
	bracket_section.visible = true
	bracket_title.text = "Your three games (random)"


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
	if _selected_powers.size() != PICK_COUNT:
		return
	if _crown_pick_mode:
		if SaveService.has_all_crowns():
			return
		if _selected_crown <= 0 or SaveService.has_crown(_selected_crown):
			return
		if GameState.tournament_opponents.is_empty():
			GameState.tournament_opponents = DiceCrownArt.opponents_for_crown(_selected_crown)
	else:
		if GameState.tournament_opponents.is_empty():
			_roll_random_bracket()
	if GameState.tournament_opponents.is_empty():
		return
	GameState.championship_active = true
	GameState.tournament_loadout = _selected_powers.duplicate()
	GameState.tournament_opponent_index = 0
	GameState.tournament_stolen_power = ""
	SceneNav.go_to_game()


func _on_back() -> void:
	GameState.reset_tournament()
	SceneNav.go_to_main_menu()
