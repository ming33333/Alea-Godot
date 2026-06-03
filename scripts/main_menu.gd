extends Control

const ORB_SIZE := 44.0
const TOOLTIP_GAP := 14.0

@onready var map_area: Control = %MapArea
@onready var badges_row: HBoxContainer = %BadgesRow
@onready var championship_btn: Button = %ChampionshipBtn
@onready var champion_badge: Label = %ChampionBadge
@onready var celebration: PanelContainer = %ChampionCelebration
@onready var gym_tooltip: PanelContainer = %GymTooltip
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_subtitle: Label = %TooltipSubtitle
@onready var tooltip_body: Label = %TooltipBody
@onready var tooltip_footer: Label = %TooltipFooter
@onready var river_video: VideoStreamPlayer = %River

var _layout: Dictionary = {}
var _drag_gym_id: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _hover_gym_id: String = ""


func _ready() -> void:
	_setup_river_background()
	_layout = SaveService.get_menu_layout()
	gym_tooltip.visible = false
	if not SaveService.badges_changed.is_connected(_on_badges_changed):
		SaveService.badges_changed.connect(_on_badges_changed)
	call_deferred("_build_orbs")
	_refresh_badges()
	champion_badge.visible = SaveService.is_dice_champion()
	celebration.visible = GameState.show_champion_celebration
	championship_btn.tooltip_text = (
		"Dice Master Championship\n"
		+ "Pick three powers and defeat three opponents in a row to become Dice Champion."
	)
	championship_btn.mouse_entered.connect(_on_championship_hover)
	championship_btn.mouse_exited.connect(_hide_gym_tooltip)


func _build_orbs() -> void:
	for c in map_area.get_children():
		c.queue_free()
	for gym in GameData.menu_gym_modes:
		var gid: String = str(gym.get("id", ""))
		var pos: Dictionary = _layout.get(gid, {"x": 50, "y": 50})
		var orb := _make_orb(gym, float(pos.x), float(pos.y))
		map_area.add_child(orb)


func _make_orb(gym: Dictionary, px: float, py: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = _pct_to_pos(px, py)
	root.custom_minimum_size = Vector2(ORB_SIZE, ORB_SIZE)
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.text = gym.get("badge_emoji", "●")
	btn.flat = false
	btn.tooltip_text = _gym_tooltip_plaintext(gym)
	var earned: bool = SaveService.has_badge(gid_str(gym))
	if earned:
		btn.modulate = Color(1.0, 0.9, 0.5)
	else:
		btn.modulate = Color(0.85, 0.85, 0.85)
	btn.mouse_entered.connect(_on_orb_hover.bind(gym, root))
	btn.mouse_exited.connect(_on_orb_unhover.bind(gym))
	var gid: String = gid_str(gym)
	btn.gui_input.connect(_on_orb_input.bind(gid, root))
	btn.pressed.connect(_on_gym_pressed.bind(gid))
	root.add_child(btn)
	root.set_meta("gym_id", gid)
	return root


func _gym_tooltip_plaintext(gym: Dictionary) -> String:
	return "%s — %s\n%s" % [
		gym.get("name", ""),
		gym.get("subtitle", ""),
		gym.get("description", ""),
	]


func _populate_tooltip(gym: Dictionary) -> void:
	tooltip_name.text = str(gym.get("name", "Gym"))
	tooltip_subtitle.text = str(gym.get("subtitle", ""))
	tooltip_body.text = str(gym.get("description", ""))
	var earned: bool = SaveService.has_badge(gid_str(gym))
	var badge_label: String = "Badge earned" if earned else "Badge locked"
	tooltip_footer.text = "%s %s · %s · drag to move · click to play" % [
		gym.get("badge_emoji", ""),
		gym.get("badge_name", ""),
		badge_label,
	]


func _on_orb_hover(gym: Dictionary, orb: Control) -> void:
	if _drag_gym_id != "":
		return
	_hover_gym_id = gid_str(gym)
	_populate_tooltip(gym)
	gym_tooltip.visible = true
	call_deferred("_position_tooltip_near_orb", orb)


func _on_orb_unhover(gym: Dictionary) -> void:
	if gid_str(gym) == _hover_gym_id:
		_hide_gym_tooltip()


func _on_championship_hover() -> void:
	_hover_gym_id = "championship"
	tooltip_name.text = "Dice Master Championship"
	tooltip_subtitle.text = "Tournament mode"
	tooltip_body.text = (
		"Choose three powers, then beat three special opponents in a row. "
		+ "Win the final match to earn the Dice Champion title on the map."
	)
	tooltip_footer.text = "Requires all gym badges · click to enter"
	gym_tooltip.visible = true
	call_deferred("_position_tooltip_near_control", championship_btn)


func _hide_gym_tooltip() -> void:
	_hover_gym_id = ""
	gym_tooltip.visible = false


func _position_tooltip_near_orb(orb: Control) -> void:
	_position_tooltip_near_control(orb)


func _position_tooltip_near_control(anchor: Control) -> void:
	if not gym_tooltip.visible:
		return
	gym_tooltip.reset_size()
	var center: Vector2 = anchor.get_global_rect().get_center()
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * center
	var tip_size: Vector2 = gym_tooltip.size
	var x: float = clampf(
		local.x - tip_size.x * 0.5,
		12.0,
		maxf(12.0, size.x - tip_size.x - 12.0)
	)
	var y: float = local.y - tip_size.y - TOOLTIP_GAP
	if y < 12.0:
		y = local.y + anchor.size.y + TOOLTIP_GAP
	gym_tooltip.position = Vector2(x, y)


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
				_hide_gym_tooltip()
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
	_hide_gym_tooltip()
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
	championship_btn.visible = SaveService.has_all_menu_badges()


func _on_badges_changed() -> void:
	_refresh_badges()
	call_deferred("_build_orbs")


func _on_championship_pressed() -> void:
	_hide_gym_tooltip()
	GameState.reset_tournament()
	SceneNav.go_to_tournament_pick()


func _on_celebration_dismiss() -> void:
	GameState.show_champion_celebration = false
	celebration.visible = false


func _on_settings_pressed() -> void:
	SceneNav.go_to_settings()


func _setup_river_background() -> void:
	if river_video == null:
		return
	if river_video.stream == null:
		push_warning("Main menu: assign res://assets/textures/river.ogv on the River node")
		return
	if not river_video.finished.is_connected(_on_river_video_finished):
		river_video.finished.connect(_on_river_video_finished)
	if not river_video.is_playing():
		river_video.play()


func _on_river_video_finished() -> void:
	if river_video:
		river_video.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if DevCheats.feed_typed_key(key.unicode):
			get_viewport().set_input_as_handled()
