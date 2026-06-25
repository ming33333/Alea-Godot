extends Control

const PICK_COUNT := 3

@onready var options_box: VBoxContainer = %OptionsBox
@onready var confirm_btn: Button = %ConfirmBtn
@onready var status_label: Label = %StatusLabel
@onready var bracket_section: Control = %BracketSection
@onready var bracket_list: VBoxContainer = %BracketList

var _selected: Array[String] = []
var _checkboxes: Dictionary = {}
var _unchecked_icon: ImageTexture
var _checked_icon: ImageTexture


func _ready() -> void:
	_ensure_checkbox_icons()
	options_box.add_theme_constant_override("separation", 10)
	for t in GameData.tournament_pickable:
		var def: Dictionary = GameData.get_power_def(str(t))
		var cb := CheckBox.new()
		cb.text = "%s - %s" % [
			def.get("label", t),
			PowerLogic.format_power_short(def),
		]
		cb.toggled.connect(_on_toggle.bind(str(t)))
		_style_power_checkbox(cb)
		options_box.add_child(cb)
		_checkboxes[str(t)] = cb
	confirm_btn.disabled = true
	_roll_and_show_bracket()


func _ensure_checkbox_icons() -> void:
	if _unchecked_icon != null and _checked_icon != null:
		return
	_unchecked_icon = _make_checkbox_icon(false)
	_checked_icon = _make_checkbox_icon(true)


func _make_checkbox_icon(checked: bool) -> ImageTexture:
	var size_px := 22
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := Color(0.94, 0.96, 1.0, 1.0)
	var inner := Color(0.95, 0.82, 0.38, 1.0) if checked else Color(0.24, 0.26, 0.34, 1.0)
	for x in size_px:
		for y in size_px:
			var edge: bool = x <= 1 or y <= 1 or x >= size_px - 2 or y >= size_px - 2
			var inner_rect: bool = x >= 3 and y >= 3 and x < size_px - 3 and y < size_px - 3
			if edge:
				img.set_pixel(x, y, border)
			elif inner_rect:
				img.set_pixel(x, y, inner)
	if checked:
		var mark := Color(0.1, 0.12, 0.16, 1.0)
		for i in 5:
			img.set_pixel(5 + i, 11 + i, mark)
			img.set_pixel(6 + i, 11 + i, mark)
		for i in 7:
			img.set_pixel(10 + i, 16 - i, mark)
			img.set_pixel(11 + i, 16 - i, mark)
	return ImageTexture.create_from_image(img)


func _style_power_checkbox(cb: CheckBox) -> void:
	cb.custom_minimum_size.y = 38
	cb.add_theme_icon_override("unchecked", _unchecked_icon)
	cb.add_theme_icon_override("checked", _checked_icon)
	cb.add_theme_color_override("font_color", Color(0.94, 0.96, 0.99))
	cb.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78))
	cb.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.62))
	cb.add_theme_color_override("font_focus_color", Color(0.94, 0.96, 0.99))
	cb.add_theme_font_size_override("font_size", 14)
	cb.add_theme_constant_override("h_separation", 12)
	cb.add_theme_constant_override("outline_size", 0)
	var row_normal := StyleBoxFlat.new()
	row_normal.bg_color = Color(0.18, 0.2, 0.28, 0.72)
	row_normal.border_color = Color(0.55, 0.6, 0.72, 0.55)
	row_normal.set_border_width_all(1)
	row_normal.set_corner_radius_all(6)
	row_normal.content_margin_left = 10.0
	row_normal.content_margin_top = 8.0
	row_normal.content_margin_right = 10.0
	row_normal.content_margin_bottom = 8.0
	var row_hover := row_normal.duplicate() as StyleBoxFlat
	row_hover.bg_color = Color(0.24, 0.26, 0.36, 0.88)
	row_hover.border_color = Color(0.82, 0.86, 0.95, 0.9)
	var row_pressed := row_hover.duplicate() as StyleBoxFlat
	row_pressed.bg_color = Color(0.3, 0.28, 0.2, 0.95)
	row_pressed.border_color = Color(0.95, 0.82, 0.38, 1.0)
	cb.add_theme_stylebox_override("normal", row_normal)
	cb.add_theme_stylebox_override("hover", row_hover)
	cb.add_theme_stylebox_override("pressed", row_pressed)
	cb.add_theme_stylebox_override("focus", row_hover)
	cb.add_theme_stylebox_override("disabled", row_normal)


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
