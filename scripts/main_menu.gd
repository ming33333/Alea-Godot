extends Control

const ORB_SIZE := 44.0

@onready var map_area: Control = %MapArea
@onready var badges_row: HBoxContainer = %BadgesRow
@onready var championship_btn: Button = %ChampionshipBtn
@onready var champion_badge: Label = %ChampionBadge
@onready var celebration: PanelContainer = %ChampionCelebration

var _layout: Dictionary = {}
var _drag_gym_id: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_moved: bool = false


func _ready() -> void:
	_layout = SaveService.get_menu_layout()
	call_deferred("_build_orbs")
	_refresh_badges()
	championship_btn.visible = SaveService.has_all_menu_badges()
	champion_badge.visible = SaveService.is_dice_champion()
	celebration.visible = GameState.show_champion_celebration


func _build_orbs() -> void:
	for c in map_area.get_children():
		c.queue_free()
	for gym in GameData.menu_gym_modes:
		var gid: String = gym.id
		var pos: Dictionary = _layout.get(gid, {"x": 50, "y": 50})
		var orb := _make_orb(gym, float(pos.x), float(pos.y))
		map_area.add_child(orb)


func _make_orb(gym: Dictionary, px: float, py: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = _pct_to_pos(px, py)
	root.custom_minimum_size = Vector2(ORB_SIZE, ORB_SIZE)
	root.tooltip_text = "%s\n%s\n%s" % [
		gym.get("name", ""),
		gym.get("subtitle", ""),
		gym.get("description", "")
	]
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.text = gym.get("badge_emoji", "●")
	btn.flat = false
	var earned: bool = SaveService.has_badge(gid_str(gym))
	if earned:
		btn.modulate = Color(1.0, 0.9, 0.5)
	else:
		btn.modulate = Color(0.85, 0.85, 0.85)
	btn.gui_input.connect(_on_orb_input.bind(gym.id, root))
	btn.pressed.connect(_on_gym_pressed.bind(gym.id))
	root.add_child(btn)
	root.set_meta("gym_id", gym.id)
	return root


func gid_str(gym: Dictionary) -> String:
	return str(gym.get("id", ""))


func _pct_to_pos(x: float, y: float) -> Vector2:
	var r := map_area.get_rect().size
	if r.x < 1:
		r = Vector2(400, 300)
	return Vector2(r.x * x / 100.0 - ORB_SIZE / 2, r.y * y / 100.0 - ORB_SIZE / 2)


func _pos_to_pct(pos: Vector2) -> Vector2:
	var r := map_area.get_rect().size
	if r.x < 1:
		return Vector2(50, 50)
	return Vector2(
		(pos.x + ORB_SIZE / 2) / r.x * 100.0,
		(pos.y + ORB_SIZE / 2) / r.y * 100.0
	)


func _on_orb_input(event: InputEvent, gym_id: String, node: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_gym_id = gym_id
				_drag_moved = false
				_drag_offset = node.position - map_area.get_local_mouse_position()
			else:
				if _drag_gym_id == gym_id and _drag_moved:
					var pct := _pos_to_pct(node.position)
					SaveService.save_orb_position(gym_id, pct.x, pct.y)
				_drag_gym_id = ""
				_drag_moved = false
	if event is InputEventMouseMotion and _drag_gym_id == gym_id:
		_drag_moved = true
		node.position = map_area.get_local_mouse_position() + _drag_offset


func _on_gym_pressed(gym_id: String) -> void:
	if _drag_moved:
		return
	GameState.selected_gym_id = gym_id
	GameState.reset_tournament()
	SceneNav.go_to_game()


func _refresh_badges() -> void:
	for c in badges_row.get_children():
		c.queue_free()
	for bid in SaveService.get_earned_badges():
		var gym: Dictionary = GameData.get_gym(bid)
		var l := Label.new()
		l.text = gym.get("badge_emoji", "")
		badges_row.add_child(l)


func _on_championship_pressed() -> void:
	GameState.reset_tournament()
	SceneNav.go_to_tournament_pick()


func _on_celebration_dismiss() -> void:
	GameState.show_champion_celebration = false
	celebration.visible = false


func _on_settings_pressed() -> void:
	SceneNav.go_to_settings()
