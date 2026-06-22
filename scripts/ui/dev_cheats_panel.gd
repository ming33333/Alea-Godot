class_name DevCheatsPanel
extends PanelContainer

var session: RunSession
var _status_label: Label
var _power_picker: OptionButton
var _remove_power_btn: Button
var _complete_battle_btn: Button
var _power_type_ids: Array[String] = []


func _ready() -> void:
	_build_ui()
	_populate_power_picker()
	if session != null:
		_update_badge_button()
	if not SaveService.badges_changed.is_connected(_on_badges_changed):
		SaveService.badges_changed.connect(_on_badges_changed)


func setup(run_session: RunSession) -> void:
	session = run_session
	if _power_picker != null:
		_populate_power_picker()
	refresh_for_session()


func refresh_for_session() -> void:
	if _complete_battle_btn != null:
		_complete_battle_btn.visible = session != null and session.is_tournament
	_populate_power_picker()
	_update_badge_button()


func _build_power_grant_row(parent: VBoxContainer) -> void:
	var cap := Label.new()
	cap.text = "Add / remove power"
	cap.add_theme_font_size_override("font_size", 9)
	cap.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	parent.add_child(cap)
	_power_picker = OptionButton.new()
	_power_picker.custom_minimum_size = Vector2(0, 28)
	_power_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_picker.clip_text = false
	_power_picker.add_theme_font_size_override("font_size", 10)
	_power_picker.item_selected.connect(_on_power_picker_changed)
	parent.add_child(_power_picker)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	parent.add_child(btn_row)
	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.custom_minimum_size = Vector2(0, 28)
	add_btn.add_theme_font_size_override("font_size", 10)
	add_btn.pressed.connect(_on_grant_power)
	btn_row.add_child(add_btn)
	_remove_power_btn = Button.new()
	_remove_power_btn.text = "Remove"
	_remove_power_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remove_power_btn.custom_minimum_size = Vector2(0, 28)
	_remove_power_btn.add_theme_font_size_override("font_size", 10)
	_remove_power_btn.pressed.connect(_on_remove_power)
	btn_row.add_child(_remove_power_btn)


func _populate_power_picker() -> void:
	if _power_picker == null:
		return
	var selected_type: String = _selected_power_type()
	_power_picker.clear()
	_power_type_ids.clear()
	for p in GameData.powers:
		var t: String = str(p.get("type", ""))
		if t.is_empty():
			continue
		_power_type_ids.append(t)
		var label: String = str(p.get("label", t))
		if session != null and session.unlocked_powers.has(t):
			label += " ✓"
		_power_picker.add_item(label)
	if _power_type_ids.is_empty():
		_power_picker.add_item("(no powers)")
		_update_power_action_buttons()
		return
	var restore_idx: int = _power_type_ids.find(selected_type)
	_power_picker.selected = restore_idx if restore_idx >= 0 else 0
	_update_power_action_buttons()


func _selected_power_type() -> String:
	if _power_type_ids.is_empty():
		return ""
	var idx: int = _power_picker.selected
	if idx < 0 or idx >= _power_type_ids.size():
		return ""
	return _power_type_ids[idx]


func _power_is_owned(power_type: String) -> bool:
	return session != null and session.unlocked_powers.has(power_type)


func _update_power_action_buttons() -> void:
	if _remove_power_btn == null:
		return
	var power_type: String = _selected_power_type()
	_remove_power_btn.disabled = power_type.is_empty() or not _power_is_owned(power_type)


func _on_power_picker_changed(_idx: int) -> void:
	_update_power_action_buttons()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -184.0
	offset_right = -8.0
	offset_top = -280.0
	offset_bottom = 280.0
	grow_vertical = 2
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	box.border_color = Color(0.45, 0.48, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", box)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "DEV CHEATS"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	header.add_child(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var min_btn := Button.new()
	min_btn.text = "−"
	min_btn.custom_minimum_size = Vector2(28, 24)
	min_btn.pressed.connect(_on_minimize)
	header.add_child(min_btn)
	_build_power_grant_row(vbox)
	_add_btn(vbox, "Complete level", _on_complete_level)
	_complete_battle_btn = _add_btn(vbox, "Complete test game", _on_complete_championship_battle)
	_complete_battle_btn.visible = false
	_add_btn(vbox, "Refill switch + reroll", _on_refill)
	_add_btn(vbox, "+1 heart", _on_add_heart)
	_add_btn(vbox, "Award challenge orb badge", _on_award_badge)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(156, 0)
	_status_label.add_theme_font_size_override("font_size", 9)
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.55))
	vbox.add_child(_status_label)
	var codes := Label.new()
	codes.text = "Codes: edit data/dev_cheats.json"
	codes.add_theme_font_size_override("font_size", 9)
	codes.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))
	codes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(codes)


func _add_btn(parent: Node, label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _show_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
	DebugLog.log("DevCheats", msg)


func _update_badge_button() -> void:
	if session == null:
		return
	if session.is_tournament:
		_show_status("Badge cheat: challenge orb runs only")
		return
	var challenge_orb: Dictionary = GameData.get_challenge_orb(session.challenge_orb_id)
	if SaveService.has_badge(session.challenge_orb_id):
		_show_status("Badge earned: %s" % challenge_orb.get("badge_name", ""))
	else:
		_show_status("Tap to award: %s" % challenge_orb.get("badge_name", ""))


func _on_badges_changed() -> void:
	_update_badge_button()


func _on_minimize() -> void:
	visible = false
	DevCheats.menu_minimized = true
	var game := get_parent()
	if game and game.has_method("_on_dev_panel_minimized"):
		game._on_dev_panel_minimized()


func _on_complete_level() -> void:
	if session == null:
		_show_status("No active run")
		return
	session.dev_complete_level()
	if session.is_tournament:
		_show_status("Test game advanced (same opponent)")


func _on_complete_championship_battle() -> void:
	if session == null:
		_show_status("No active run")
		return
	if not session.is_tournament:
		_show_status("Dice Master Test runs only")
		return
	session.dev_complete_championship_battle()
	_show_status("Battle won — next opponent")


func _on_refill() -> void:
	if session:
		session.dev_refill_resources()


func _on_grant_power() -> void:
	if session == null:
		_show_status("No active run")
		return
	if _power_type_ids.is_empty():
		_show_status("No powers in data/powers.json")
		return
	var power_type: String = _selected_power_type()
	if power_type.is_empty():
		_show_status("Pick a power")
		return
	var msg: String = session.dev_grant_power(power_type)
	_show_status(msg)
	_populate_power_picker()


func _on_remove_power() -> void:
	if session == null:
		_show_status("No active run")
		return
	if _power_type_ids.is_empty():
		_show_status("No powers in data/powers.json")
		return
	var power_type: String = _selected_power_type()
	if power_type.is_empty():
		_show_status("Pick a power")
		return
	if not _power_is_owned(power_type):
		var def: Dictionary = GameData.get_power_def(power_type)
		_show_status("Not in loadout: %s" % str(def.get("label", power_type)))
		_update_power_action_buttons()
		return
	var msg: String = session.dev_remove_power(power_type)
	_show_status(msg)
	_populate_power_picker()


func _on_add_heart() -> void:
	if session:
		session.dev_add_heart()


func _on_award_badge() -> void:
	if session == null:
		_show_status("No active run")
		return
	if session.is_tournament:
		_show_status("Use this in a challenge orb, not the Dice Master Test")
		return
	var challenge_orb: Dictionary = GameData.get_challenge_orb(session.challenge_orb_id)
	var challenge_orb_name: String = str(challenge_orb.get("name", session.challenge_orb_id))
	var badge_name: String = str(challenge_orb.get("badge_name", "Badge"))
	if not SaveService.force_award_badge(session.challenge_orb_id):
		_show_status("Could not award (%s)" % challenge_orb_name)
		return
	if SaveService.has_badge(session.challenge_orb_id):
		_show_status("Awarded: %s (%s)" % [badge_name, challenge_orb_name])
	else:
		_show_status("Save failed — check Output")
