extends Control

const ORB_SIZE := 48.0
const ORB_RADIUS := int(ORB_SIZE * 0.5)
const TOOLTIP_GAP := 14.0
const DRAG_THRESHOLD_PX := 8.0
const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")

const GYM_ORB_COLORS: Dictionary = {
	"vanilla": Color(0.25, 0.82, 0.48, 0.88),
	"orderedReroll": Color(0.35, 0.52, 0.95, 0.88),
	"countdownOne": Color(0.95, 0.72, 0.12, 0.88),
	"countdownAll": Color(0.12, 0.72, 0.88, 0.88),
	"twoSlots": Color(0.62, 0.38, 0.88, 0.88),
	"middleStraight": Color(0.92, 0.32, 0.28, 0.88),
}
const GYM_ORB_FALLBACK_COLOR := Color(0.55, 0.55, 0.62, 0.88)
const BADGE_ICON_SIZE := 40.0

@onready var map_area: Control = %MapArea
@onready var badges_row: VBoxContainer = %BadgesRow
@onready var championship_btn: Button = %ChampionshipBtn
@onready var champion_badge: Label = %ChampionBadge
@onready var celebration: PanelContainer = %ChampionCelebration
@onready var gym_tooltip: PanelContainer = %GymTooltip
@onready var tooltip_badge: TextureRect = %TooltipBadge
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_subtitle: Label = %TooltipSubtitle
@onready var tooltip_body: Label = %TooltipBody
@onready var tooltip_footer: Label = %TooltipFooter
@onready var river_video: VideoStreamPlayer = %River

var _layout: Dictionary = {}
var _drag_gym_id: String = ""
var _drag_orb: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _hover_gym_id: String = ""
var _launching: bool = false
var _click_seq: int = 0
var _orb_build_attempts: int = 0
var _last_orb_map_size: Vector2 = Vector2.ZERO
const MAX_ORB_BUILD_ATTEMPTS := 60


func _ready() -> void:
	DebugLog.alea_log("MainMenu", "========== MENU _ready ==========")
	_setup_river_background()
	_layout = SaveService.get_menu_layout()
	gym_tooltip.visible = false
	if map_area == null:
		DebugLog.log_error("MainMenu", "@onready MapArea is null")
	else:
		map_area.mouse_filter = Control.MOUSE_FILTER_STOP
		map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not map_area.resized.is_connected(_on_map_area_resized):
			map_area.resized.connect(_on_map_area_resized)
		if not map_area.gui_input.is_connected(_on_map_area_gui_input):
			map_area.gui_input.connect(_on_map_area_gui_input)
		DebugLog.alea_log(
			"MainMenu",
			"MapArea size=%s global_rect=%s filter=%s"
			% [map_area.size, map_area.get_global_rect(), DebugLog.mouse_filter_name(map_area.mouse_filter)]
		)
	if not SceneNav.change_succeeded.is_connected(_on_scene_nav_succeeded):
		SceneNav.change_succeeded.connect(_on_scene_nav_succeeded)
	if not SceneNav.change_failed.is_connected(_on_scene_nav_failed):
		SceneNav.change_failed.connect(_on_scene_nav_failed)
	if not SaveService.badges_changed.is_connected(_on_badges_changed):
		SaveService.badges_changed.connect(_on_badges_changed)
	call_deferred("_build_orbs")
	_refresh_badges()
	champion_badge.visible = SaveService.is_dice_champion()
	celebration.visible = GameState.show_champion_celebration
	DebugLog.alea_log(
		"MainMenu",
		"celebration_visible=%s menu_gym_count=%d game_scene=%s"
		% [
			celebration.visible,
			GameData.menu_gym_modes.size(),
			"OK" if GAME_SCENE != null else "MISSING",
		]
	)
	if celebration.visible:
		celebration.mouse_filter = Control.MOUSE_FILTER_STOP
		DebugLog.alea_log("MainMenu", "WARN: champion popup is open — dismiss it to click gyms")
	else:
		celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	championship_btn.tooltip_text = (
		"Dice Master Championship\n"
		+"Pick three powers and defeat three opponents in a row to become Dice Champion."
	)
	championship_btn.mouse_entered.connect(_on_championship_hover)
	championship_btn.mouse_exited.connect(_hide_gym_tooltip)


func _map_area_ready() -> bool:
	return map_area != null and map_area.size.x >= 32.0 and map_area.size.y >= 32.0


func _on_map_area_resized() -> void:
	if not _map_area_ready():
		return
	if map_area.size == _last_orb_map_size:
		return
	DebugLog.alea_log("MainMenu", "MapArea resized -> %s, rebuilding orbs" % map_area.size)
	_build_orbs()


func _build_orbs() -> void:
	if map_area == null:
		push_error("MainMenu: MapArea missing")
		return
	if not _map_area_ready():
		_orb_build_attempts += 1
		DebugLog.alea_log(
			"MainMenu",
			"MapArea not ready size=%s attempt=%d/%d"
			% [map_area.size, _orb_build_attempts, MAX_ORB_BUILD_ATTEMPTS]
		)
		if _orb_build_attempts < MAX_ORB_BUILD_ATTEMPTS:
			call_deferred("_build_orbs")
		else:
			DebugLog.log_error("MainMenu", "MapArea never laid out; orbs may not be clickable")
		return
	_orb_build_attempts = 0
	for c in map_area.get_children():
		c.queue_free()
	DebugLog.alea_log(
		"MainMenu",
		"building orbs in MapArea size=%s global_rect=%s"
		% [map_area.size, map_area.get_global_rect()]
	)
	for gym in GameData.menu_gym_modes:
		var gid: String = str(gym.get("id", ""))
		if gid.is_empty():
			continue
		var pos: Dictionary = _layout.get(gid, {"x": 50, "y": 50})
		var orb := _make_orb(gym, float(pos.x), float(pos.y))
		map_area.add_child(orb)
		DebugLog.alea_log(
			"MainMenu",
			"orb %s pos=%s size=%s global_rect=%s"
			% [gid, orb.position, orb.size, orb.get_global_rect()]
		)
	_last_orb_map_size = map_area.size
	DebugLog.alea_log(
		"MainMenu",
		"built %d orbs (map_area children=%d)"
		% [GameData.menu_gym_modes.size(), map_area.get_child_count()]
	)


func _orb_color_for_gym(gym_id: String) -> Color:
	if GYM_ORB_COLORS.has(gym_id):
		return GYM_ORB_COLORS[gym_id] as Color
	return GYM_ORB_FALLBACK_COLOR


func _make_orb_style(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(ORB_RADIUS)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	return box


func _apply_orb_styles(btn: Button, gym_id: String, _earned: bool) -> void:
	var base: Color = _orb_color_for_gym(gym_id)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("normal", _make_orb_style(base))
	btn.add_theme_stylebox_override("hover", _make_orb_style(base.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", _make_orb_style(base.darkened(0.08)))


func _make_orb(gym: Dictionary, px: float, py: float) -> Button:
	var gid: String = gid_str(gym)
	var btn := Button.new()
	btn.name = "Orb_%s" % gid
	btn.position = _pct_to_pos(px, py)
	btn.custom_minimum_size = Vector2(ORB_SIZE, ORB_SIZE)
	btn.size = Vector2(ORB_SIZE, ORB_SIZE)
	btn.text = ""
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = _gym_tooltip_plaintext(gym)
	var earned: bool = SaveService.has_badge(gid)
	_apply_orb_styles(btn, gid, earned)
	btn.mouse_entered.connect(_on_orb_hover.bind(gym, btn))
	btn.mouse_exited.connect(_on_orb_unhover.bind(gym))
	btn.button_down.connect(_on_orb_button_down.bind(gid, btn))
	btn.pressed.connect(_on_orb_pressed.bind(gid))
	btn.set_meta("gym_id", gid)
	return btn


func _gym_tooltip_plaintext(gym: Dictionary) -> String:
	return "%s — %s\n%s" % [
		gym.get("name", ""),
		gym.get("subtitle", ""),
		gym.get("description", ""),
	]


func _make_badge_icon(gym_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(BADGE_ICON_SIZE, BADGE_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = GameData.get_badge_texture(gym_id)
	return icon


func _populate_tooltip(gym: Dictionary) -> void:
	var gid: String = gid_str(gym)
	if tooltip_badge:
		tooltip_badge.texture = GameData.get_badge_texture(gid)
		tooltip_badge.visible = tooltip_badge.texture != null
	tooltip_name.text = str(gym.get("name", "Gym"))
	tooltip_subtitle.text = str(gym.get("subtitle", ""))
	tooltip_body.text = str(gym.get("description", ""))
	var earned: bool = SaveService.has_badge(gid)
	var badge_label: String = "Badge earned" if earned else "Badge locked"
	tooltip_footer.text = "%s · %s · drag to move · click to play" % [
		gym.get("badge_name", ""),
		badge_label,
	]


func _on_orb_hover(gym: Dictionary, orb: Control) -> void:
	if _drag_gym_id != "":
		return
	DebugLog.alea_log("MainMenu", "hover gym=%s orb_rect=%s" % [gid_str(gym), orb.get_global_rect()])
	_hover_gym_id = gid_str(gym)
	_populate_tooltip(gym)
	gym_tooltip.visible = true
	call_deferred("_position_tooltip_near_orb", orb)


func _on_orb_unhover(gym: Dictionary) -> void:
	if gid_str(gym) == _hover_gym_id:
		_hide_gym_tooltip()


func _on_championship_hover() -> void:
	_hover_gym_id = "championship"
	if tooltip_badge:
		tooltip_badge.visible = false
	tooltip_name.text = "Dice Master Championship"
	tooltip_subtitle.text = "Tournament mode"
	tooltip_body.text = (
		"Choose three powers, then beat three special opponents in a row. "
		+"Win the final match to earn the Dice Champion title on the map."
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


func _mark_input_handled() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp:
		vp.set_input_as_handled()


func _log_gym_click(phase: String, gym_id: String, detail: String = "") -> void:
	var label: String = gym_id if not gym_id.is_empty() else "(none)"
	if not gym_id.is_empty():
		var gym: Dictionary = GameData.get_gym(gym_id)
		var display_name: String = str(gym.get("name", ""))
		if not display_name.is_empty():
			label = "%s / %s" % [gym_id, display_name]
	var line := "*** GYM CLICK [%s] seq=%d gym=%s" % [phase, _click_seq, label]
	if not detail.is_empty():
		line += " | " + detail
	DebugLog.alea_log("MainMenu", line)


func _pct_to_pos(x: float, y: float) -> Vector2:
	var r := map_area.size
	return Vector2(r.x * x / 100.0 - ORB_SIZE / 2, r.y * y / 100.0 - ORB_SIZE / 2)


func _pos_to_pct(pos: Vector2) -> Vector2:
	var r := map_area.size
	if r.x < 1.0 or r.y < 1.0:
		return Vector2(50, 50)
	return Vector2(
		(pos.x + ORB_SIZE / 2) / r.x * 100.0,
		(pos.y + ORB_SIZE / 2) / r.y * 100.0
	)


func _find_orb(gym_id: String) -> Control:
	var node_name := "Orb_%s" % gym_id
	return map_area.get_node_or_null(node_name) as Control


func _gym_id_at_global(global_pos: Vector2) -> String:
	for child in map_area.get_children():
		if child is Control and child.get_global_rect().has_point(global_pos):
			return str(child.get_meta("gym_id", ""))
	return ""


func _on_map_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit_id := _gym_id_at_global(mb.global_position)
		if mb.pressed:
			if hit_id.is_empty():
				DebugLog.alea_log(
					"MainMenu",
					"[%d] map_area press MISS global=%s"
					% [_click_seq + 1, mb.global_position]
				)
				return
			_log_gym_click("PRESS", hit_id, "global=%s" % mb.global_position)
			var orb := _find_orb(hit_id)
			if orb != null:
				_on_orb_button_down(hit_id, orb)
			else:
				DebugLog.log_error("MainMenu", "hit gym %s but orb node missing" % hit_id)
		elif _drag_gym_id != "":
			_log_gym_click("RELEASE", _drag_gym_id, "via map_area")
			_mark_input_handled()
			_finish_orb_pointer()


func _on_orb_button_down(gym_id: String, orb: Control) -> void:
	_click_seq += 1
	_log_gym_click(
		"DOWN",
		gym_id,
		"orb=%s map_mouse=%s" % [orb.name, map_area.get_local_mouse_position()]
	)
	_hide_gym_tooltip()
	_drag_gym_id = gym_id
	_drag_orb = orb
	_drag_moved = false
	_drag_start = map_area.get_local_mouse_position()
	_drag_offset = orb.position - _drag_start


func _on_orb_pressed(gym_id: String) -> void:
	_log_gym_click(
		"PRESSED",
		gym_id,
		"drag_moved=%s active_drag=%s" % [_drag_moved, _drag_gym_id]
	)
	if _drag_moved:
		return
	_launch_gym(gym_id)


func _input(event: InputEvent) -> void:
	if _drag_gym_id == "":
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_orb_drag()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_log_gym_click("RELEASE", _drag_gym_id, "via _input global=%s" % mb.global_position)
			_mark_input_handled()
			_finish_orb_pointer()


func _update_orb_drag() -> void:
	if _drag_orb == null:
		return
	var local_mouse := map_area.get_local_mouse_position()
	if not _drag_moved and local_mouse.distance_to(_drag_start) > DRAG_THRESHOLD_PX:
		_drag_moved = true
		DebugLog.alea_log("MainMenu", "[%d] drag started gym=%s" % [_click_seq, _drag_gym_id])
	if _drag_moved:
		_drag_orb.position = local_mouse + _drag_offset


func _finish_orb_pointer() -> void:
	if _drag_gym_id == "":
		DebugLog.alea_log("MainMenu", "[%d] _finish_orb_pointer called but no active drag" % _click_seq)
		return
	var gym_id := _drag_gym_id
	var orb: Control = _drag_orb
	var was_drag := _drag_moved
	_drag_gym_id = ""
	_drag_orb = null
	_drag_moved = false
	if was_drag and orb != null:
		var pct := _pos_to_pct(orb.position)
		SaveService.save_orb_position(gym_id, pct.x, pct.y)
		DebugLog.alea_log("MainMenu", "[%d] saved orb position gym=%s pct=(%.1f,%.1f)" % [
			_click_seq, gym_id, pct.x, pct.y
		])
	else:
		_log_gym_click("CONFIRMED", gym_id, "short click (not drag) -> launching")
		_launch_gym(gym_id)


func _launch_gym(gym_id: String) -> void:
	if gym_id.is_empty():
		DebugLog.log_error("MainMenu", "_launch_gym called with empty gym_id")
		return
	if _launching:
		_log_gym_click("SKIPPED", gym_id, "launch already in progress")
		return
	_launching = true
	_log_gym_click("LAUNCH", gym_id, "starting scene change")
	_hide_gym_tooltip()
	GameState.selected_gym_id = gym_id
	GameState.reset_tournament()
	var tree := get_tree()
	if tree == null:
		DebugLog.log_error("MainMenu", "get_tree() returned null")
		_launching = false
		return
	var before: String = "null"
	if tree.current_scene != null:
		before = str(tree.current_scene.name)
	DebugLog.alea_log("MainMenu", "scene before change: %s" % before)
	var err: Error = tree.change_scene_to_packed(GAME_SCENE)
	DebugLog.alea_log("MainMenu", "change_scene_to_packed err=%s (%s)" % [err, error_string(err)])
	if err != OK:
		DebugLog.alea_log("MainMenu", "retrying via SceneNav.go_to_game()")
		SceneNav.go_to_game()
		return
	var after: String = "null"
	if tree.current_scene != null:
		after = str(tree.current_scene.name)
	_log_gym_click("LOADED", gym_id, "scene=%s err=%s" % [after, err])


func _on_scene_nav_succeeded(scene_path: String) -> void:
	DebugLog.alea_log("MainMenu", "SceneNav OK -> %s" % scene_path)


func _on_scene_nav_failed(message: String) -> void:
	DebugLog.log_error("MainMenu", "SceneNav FAILED: %s" % message)


func _refresh_badges() -> void:
	for c in badges_row.get_children():
		c.queue_free()
	for bid in SaveService.get_earned_badges():
		badges_row.add_child(_make_badge_icon(bid))
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
	celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	if DebugLog.log_menu_clicks and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var action: String = "DOWN" if mb.pressed else "UP"
			DebugLog.log_hovered(
				"MainMenu",
				"[%d] unhandled mouse_%s drag_id=%s" % [_click_seq, action, _drag_gym_id]
			)
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if DevCheats.feed_typed_key(key.unicode):
			_mark_input_handled()
