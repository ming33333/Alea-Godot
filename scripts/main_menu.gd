extends Control

const ORB_SIZE := 72.0
const ORB_ABOVE_PILLAR_GAP := 2.0
const ORB_SEATED_OVERLAP := 15.0
const PILLAR_TEXTURE_SRC_HEIGHT := 222.0
const PILLAR_TEXTURE_VISIBLE_TOP := 75.0
const TOOLTIP_GAP := 14.0
const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")

const BADGE_ICON_SIZE := 40.0
const BADGE_BOX_SIZE := 56.0
const BADGE_SLIDE_DURATION := 0.55
const CLOSED_BOX_TEX: Texture2D = preload("res://assets/textures/closed_box.png")
const OPENED_BOX_TEX: Texture2D = preload("res://assets/textures/opened_box.png")
const DECK_PILLAR_HEIGHT := 360.0
const DECK_PILLAR_WIDTH := 112.0
const DECK_BOTTOM_SCREEN_FRACTION := 0.15
const DECK_PILLAR_SIDE_MARGIN := 24.0
const PORTAL_HEIGHT_SCALE := 1.2
const PORTAL_CENTER_Y_FRACTION := 0.36

@onready var map_area: Control = %MapArea
@onready var champion_portal: TextureButton = %ChampionPortal
@onready var deck_pillars: HBoxContainer = %DeckPillars
@onready var badge_box_wrap: HBoxContainer = %BadgeBoxWrap
@onready var badge_box_btn: TextureButton = %BadgeBoxBtn
@onready var badge_slide_clip: Control = %BadgeSlideClip
@onready var badges_row: HBoxContainer = %BadgesRow
@onready var champion_badge: HBoxContainer = %ChampionBadge
@onready var champion_crown_icon: TextureRect = %CrownIcon
@onready var celebration_icon: TextureRect = %CelebrationIcon
@onready var celebration: PanelContainer = %ChampionCelebration
@onready var celebration_label: Label = %ChampionCelebrationLabel
@onready var how_to_play_overlay: Control = %HowToPlayOverlay
@onready var how_to_play_sections: VBoxContainer = %HowToPlaySections
@onready var gym_tooltip: PanelContainer = %GymTooltip
@onready var tooltip_badge: TextureRect = %TooltipBadge
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_subtitle: Label = %TooltipSubtitle
@onready var tooltip_body: Label = %TooltipBody
@onready var tooltip_footer: Label = %TooltipFooter
var _hover_gym_id: String = ""
var _launching: bool = false
var _click_seq: int = 0
var _orb_build_attempts: int = 0
var _portal_layout_attempts: int = 0
var _badge_box_open: bool = false
var _badge_box_animating: bool = false
var _badge_slide_tween: Tween
var _celebration_backdrop: ColorRect
const MAX_ORB_BUILD_ATTEMPTS := 60
const MAX_PORTAL_LAYOUT_ATTEMPTS := 40


func _ready() -> void:
	DebugLog.alea_log("MainMenu", "========== MENU _ready ==========")
	if not resized.is_connected(_layout_deck_pillars):
		resized.connect(_layout_deck_pillars)
	gym_tooltip.visible = false
	if map_area == null:
		DebugLog.log_error("MainMenu", "@onready MapArea is null")
	else:
		map_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not map_area.resized.is_connected(_on_map_area_resized):
			map_area.resized.connect(_on_map_area_resized)
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
	_layout_deck_pillars()
	_badge_box_open = SaveService.is_badge_box_open()
	_refresh_badges()
	_populate_how_to_play()
	if how_to_play_overlay:
		how_to_play_overlay.visible = false
	call_deferred("_refresh_champion_portal")
	PixelIconArt.apply_texture_rect(champion_crown_icon, "crown", 18)
	PixelIconArt.apply_texture_rect(celebration_icon, "crown", 32)
	champion_badge.visible = SaveService.is_dice_champion()
	_present_champion_celebration_if_needed()
	if champion_portal:
		champion_portal.tooltip_text = ""


func _map_area_ready() -> bool:
	return map_area != null and map_area.size.x >= 32.0 and map_area.size.y >= 32.0


func _on_map_area_resized() -> void:
	if not _map_area_ready():
		return
	DebugLog.alea_log("MainMenu", "MapArea resized -> %s, rebuilding orbs" % map_area.size)
	call_deferred("_build_orbs")


func _layout_deck_pillars() -> void:
	if deck_pillars == null:
		return
	var screen_h: float = get_viewport_rect().size.y
	var bottom_gap: float = screen_h * DECK_BOTTOM_SCREEN_FRACTION
	deck_pillars.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	deck_pillars.offset_left = DECK_PILLAR_SIDE_MARGIN
	deck_pillars.offset_right = -DECK_PILLAR_SIDE_MARGIN
	deck_pillars.offset_bottom = -bottom_gap
	deck_pillars.offset_top = -(bottom_gap + DECK_PILLAR_HEIGHT)
	for child in deck_pillars.get_children():
		if child is TextureRect:
			var pillar := child as TextureRect
			pillar.custom_minimum_size = Vector2(DECK_PILLAR_WIDTH, DECK_PILLAR_HEIGHT)
	if _map_area_ready():
		call_deferred("_build_orbs")
	if champion_portal != null and champion_portal.visible:
		call_deferred("_layout_champion_portal")


func _should_show_champion_portal() -> bool:
	var menu_count: int = GameData.menu_gym_modes.size()
	if menu_count <= 0:
		return false
	return SaveService.get_earned_badges().size() >= menu_count and SaveService.has_all_menu_badges()


func _portal_texture_size() -> Vector2:
	if champion_portal != null and champion_portal.texture_normal != null:
		return champion_portal.texture_normal.get_size()
	return Vector2(128.0, 256.0)


func _refresh_champion_portal() -> void:
	if champion_portal == null:
		return
	var show: bool = _should_show_champion_portal()
	champion_portal.visible = show
	if show:
		call_deferred("_layout_champion_portal")


func _layout_champion_portal() -> void:
	if champion_portal == null or not champion_portal.visible or deck_pillars == null:
		return
	var pillar_rect := deck_pillars.get_global_rect()
	if pillar_rect.size.x < 32.0 or pillar_rect.size.y < 32.0:
		_portal_layout_attempts += 1
		if _portal_layout_attempts < MAX_PORTAL_LAYOUT_ATTEMPTS:
			call_deferred("_layout_champion_portal")
		return
	_portal_layout_attempts = 0
	var tex_size: Vector2 = _portal_texture_size()
	var portal_h: float = DECK_PILLAR_HEIGHT * PORTAL_HEIGHT_SCALE
	var portal_w: float = portal_h * (tex_size.x / tex_size.y)
	var center_global := Vector2(
		pillar_rect.get_center().x,
		pillar_rect.position.y + pillar_rect.size.y * PORTAL_CENTER_Y_FRACTION
	)
	var top_left_global := center_global - Vector2(portal_w * 0.5, portal_h * 0.5)
	var local_top_left: Vector2 = get_global_transform_with_canvas().affine_inverse() * top_left_global
	champion_portal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	champion_portal.position = local_top_left
	champion_portal.size = Vector2(portal_w, portal_h)


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
		if c.name.begins_with("Orb_"):
			c.queue_free()
	DebugLog.alea_log(
		"MainMenu",
		"building orbs in MapArea size=%s global_rect=%s"
		% [map_area.size, map_area.get_global_rect()]
	)
	var pillar_idx := 0
	for gym in GameData.menu_gym_modes:
		var gid: String = str(gym.get("id", ""))
		if gid.is_empty():
			continue
		var defeated: bool = SaveService.has_badge(gid)
		var orb := _make_orb(gym, pillar_idx)
		var base_pos := _orb_position_above_pillar(pillar_idx, defeated)
		orb.set_float_base(base_pos)
		if defeated:
			orb.set_floating_enabled(false)
		else:
			orb.configure_float(float(pillar_idx) * 0.85)
		map_area.add_child(orb)
		DebugLog.alea_log(
			"MainMenu",
			"orb %s pillar=%d pos=%s size=%s global_rect=%s"
			% [gid, pillar_idx, orb.position, orb.size, orb.get_global_rect()]
		)
		pillar_idx += 1
	DebugLog.alea_log(
		"MainMenu",
		"built %d orbs (map_area children=%d)"
		% [GameData.menu_gym_modes.size(), map_area.get_child_count()]
	)


func _orb_color_for_gym(gym_id: String) -> Color:
	return GameData.get_gym_orb_color(gym_id)


func _orb_position_above_pillar(pillar_index: int, seated: bool = false) -> Vector2:
	if deck_pillars == null or map_area == null:
		return Vector2.ZERO
	var pillars := deck_pillars.get_children()
	if pillar_index < 0 or pillar_index >= pillars.size():
		return Vector2.ZERO
	var pillar := pillars[pillar_index] as Control
	if pillar == null:
		return Vector2.ZERO
	var pillar_rect := pillar.get_global_rect()
	var visible_top_y := pillar_rect.position.y + pillar_rect.size.y * (
		PILLAR_TEXTURE_VISIBLE_TOP / PILLAR_TEXTURE_SRC_HEIGHT
	)
	var top_center_global := Vector2(pillar_rect.get_center().x, visible_top_y)
	var local := map_area.get_global_transform_with_canvas().affine_inverse() * top_center_global
	var gap: float = -ORB_SEATED_OVERLAP if seated else ORB_ABOVE_PILLAR_GAP
	return Vector2(
		local.x - ORB_SIZE * 0.5,
		local.y - ORB_SIZE - gap
	)


func _make_orb(gym: Dictionary, pillar_index: int) -> PixelGymOrb:
	var gid: String = gid_str(gym)
	var btn := PixelGymOrb.new()
	btn.name = "Orb_%s" % gid
	btn.z_index = 2
	btn.custom_minimum_size = Vector2(ORB_SIZE, ORB_SIZE)
	btn.size = Vector2(ORB_SIZE, ORB_SIZE)
	btn.set_orb_color(_orb_color_for_gym(gid))
	btn.mouse_entered.connect(_on_orb_hover.bind(gym, btn))
	btn.mouse_exited.connect(_on_orb_unhover.bind(gym))
	btn.pressed.connect(_on_orb_pressed.bind(gid))
	btn.set_meta("gym_id", gid)
	btn.set_meta("pillar_index", pillar_index)
	return btn


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
	tooltip_footer.text = "%s · %s · click to play" % [
		gym.get("badge_name", ""),
		badge_label,
	]


func _on_orb_hover(gym: Dictionary, orb: Control) -> void:
	var gid: String = gid_str(gym)
	if _hover_gym_id == gid:
		if gym_tooltip.visible:
			call_deferred("_position_tooltip_near_orb", orb)
			return
	else:
		_hover_gym_id = gid
		_populate_tooltip(gym)
	gym_tooltip.visible = true
	call_deferred("_position_tooltip_near_orb", orb)


func _on_orb_unhover(gym: Dictionary) -> void:
	if gid_str(gym) == _hover_gym_id:
		_hide_gym_tooltip()


func _on_championship_hover() -> void:
	if champion_portal == null or not champion_portal.visible:
		return
	if _hover_gym_id == "championship" and gym_tooltip.visible:
		call_deferred("_position_tooltip_near_control", champion_portal)
		return
	_hover_gym_id = "championship"
	if tooltip_badge:
		tooltip_badge.visible = false
	tooltip_name.text = "Dice Master Test"
	tooltip_subtitle.text = "Portal to the ultimate challenge"
	tooltip_body.text = (
		"Enter the portal to face three random games. "
		+ "Win all three to become a Dice Master."
	)
	tooltip_footer.text = "All gym badges earned · click to enter"
	gym_tooltip.visible = true
	call_deferred("_position_tooltip_near_control", champion_portal)


func _on_championship_unhover() -> void:
	if _hover_gym_id == "championship":
		_hide_gym_tooltip()


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


func _on_orb_pressed(gym_id: String) -> void:
	_click_seq += 1
	_log_gym_click("PRESSED", gym_id, "launching gym")
	_hide_gym_tooltip()
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
	_size_badges_row()
	_update_badge_box()
	_refresh_champion_portal()


func _size_badges_row() -> void:
	if badges_row == null:
		return
	var row_w: float = _badges_row_width()
	var row_h: float = BADGE_ICON_SIZE
	badges_row.custom_minimum_size = Vector2(row_w, row_h)
	badges_row.size = Vector2(row_w, row_h)


func _reset_badge_icon_alpha() -> void:
	for child in badges_row.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 1.0


func _has_badges_to_show() -> bool:
	return not SaveService.get_earned_badges().is_empty()


func _badges_row_width() -> float:
	if badges_row == null:
		return 0.0
	var count: int = badges_row.get_child_count()
	if count <= 0:
		return 0.0
	var sep: float = float(badges_row.get_theme_constant("separation"))
	return float(count) * BADGE_ICON_SIZE + maxf(0.0, float(count - 1)) * sep


func _update_badge_box() -> void:
	if badge_box_wrap == null or badge_box_btn == null or badge_slide_clip == null:
		return
	var has_badges: bool = _has_badges_to_show()
	badge_box_wrap.visible = has_badges
	if not has_badges:
		return
	badge_box_btn.custom_minimum_size = Vector2(BADGE_BOX_SIZE, BADGE_BOX_SIZE)
	badge_slide_clip.custom_minimum_size.y = BADGE_BOX_SIZE
	if _badge_box_open:
		badge_box_btn.texture_normal = OPENED_BOX_TEX
		badge_box_btn.tooltip_text = "Click to close your badge box"
		badge_box_btn.disabled = _badge_box_animating
		badge_box_btn.focus_mode = Control.FOCUS_ALL
		_reset_badge_icon_alpha()
		_set_badge_slide_width(_badges_row_width(), false)
	else:
		badge_box_btn.texture_normal = CLOSED_BOX_TEX
		badge_box_btn.tooltip_text = "Click to open your badge box"
		badge_box_btn.disabled = _badge_box_animating
		badge_box_btn.focus_mode = Control.FOCUS_ALL
		_set_badge_slide_width(0.0, false)


func _set_badge_slide_width(target_w: float, animate: bool, closing: bool = false) -> void:
	if badge_slide_clip == null:
		return
	if _badge_slide_tween != null and _badge_slide_tween.is_valid():
		_badge_slide_tween.kill()
	var clamped: float = maxf(0.0, target_w)
	if not animate:
		badge_slide_clip.custom_minimum_size.x = clamped
		return
	_badge_box_animating = true
	badge_box_btn.disabled = true
	var icons: Array[Node] = []
	for child in badges_row.get_children():
		icons.append(child)
	_badge_slide_tween = create_tween()
	_badge_slide_tween.set_parallel(true)
	var width_tween := _badge_slide_tween.tween_property(
		badge_slide_clip,
		"custom_minimum_size:x",
		clamped,
		BADGE_SLIDE_DURATION
	)
	if closing:
		width_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	else:
		width_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in icons.size():
		var icon: CanvasItem = icons[i] as CanvasItem
		if icon == null:
			continue
		var stagger_idx: int = (icons.size() - 1 - i) if closing else i
		var delay: float = float(stagger_idx) * 0.07
		if closing:
			icon.modulate.a = 1.0
			_badge_slide_tween.tween_property(
				icon,
				"modulate:a",
				0.0,
				BADGE_SLIDE_DURATION * 0.5
			).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			icon.modulate.a = 0.0
			_badge_slide_tween.tween_property(
				icon,
				"modulate:a",
				1.0,
				BADGE_SLIDE_DURATION * 0.55
			).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_badge_slide_tween.finished.connect(_on_badge_slide_finished.bind(closing), CONNECT_ONE_SHOT)


func _on_badge_slide_finished(closing: bool) -> void:
	_badge_box_animating = false
	if closing:
		_badge_box_open = false
		SaveService.set_badge_box_open(false)
		if badge_box_btn != null:
			badge_box_btn.texture_normal = CLOSED_BOX_TEX
	if badge_box_btn != null:
		badge_box_btn.disabled = false
		if _badge_box_open:
			badge_box_btn.tooltip_text = "Click to close your badge box"
		else:
			badge_box_btn.tooltip_text = "Click to open your badge box"


func _on_badge_box_pressed() -> void:
	if _badge_box_animating or not _has_badges_to_show():
		return
	if _badge_box_open:
		_set_badge_slide_width(0.0, true, true)
		return
	_badge_box_open = true
	SaveService.set_badge_box_open(true)
	badge_box_btn.texture_normal = OPENED_BOX_TEX
	badge_box_btn.tooltip_text = "Click to close your badge box"
	_size_badges_row()
	_set_badge_slide_width(_badges_row_width(), true, false)


func _on_badges_changed() -> void:
	_refresh_badges()
	call_deferred("_build_orbs")


func _on_championship_pressed() -> void:
	_hide_gym_tooltip()
	GameState.start_championship_prep()
	SceneNav.go_to_tournament_pick()


func _present_champion_celebration_if_needed() -> void:
	if celebration == null:
		return
	if not GameState.show_champion_celebration:
		_hide_champion_celebration()
		return
	_ensure_celebration_backdrop()
	_celebration_backdrop.visible = true
	celebration.visible = true
	celebration.z_index = 50
	celebration.mouse_filter = Control.MOUSE_FILTER_STOP
	if celebration_label != null:
		celebration_label.text = "You are a Dice Master!"
	champion_badge.visible = SaveService.is_dice_champion()
	move_child(_celebration_backdrop, get_child_count() - 1)
	move_child(celebration, get_child_count() - 1)
	DebugLog.alea_log("MainMenu", "champion celebration shown")


func _ensure_celebration_backdrop() -> void:
	if _celebration_backdrop != null:
		return
	_celebration_backdrop = ColorRect.new()
	_celebration_backdrop.name = "ChampionCelebrationBackdrop"
	_celebration_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration_backdrop.anchor_right = 1.0
	_celebration_backdrop.anchor_bottom = 1.0
	_celebration_backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_celebration_backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	_celebration_backdrop.color = Color(0.0, 0.0, 0.0, 0.62)
	_celebration_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_celebration_backdrop.z_index = 49
	add_child(_celebration_backdrop)


func _hide_champion_celebration() -> void:
	if _celebration_backdrop != null:
		_celebration_backdrop.visible = false
	if celebration != null:
		celebration.visible = false
		celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_celebration_dismiss() -> void:
	GameState.show_champion_celebration = false
	_hide_champion_celebration()


func _on_settings_pressed() -> void:
	_hide_gym_tooltip()
	_close_how_to_play()
	SceneNav.go_to_settings()


func _populate_how_to_play() -> void:
	HowToPlayContent.populate(how_to_play_sections)


func _on_how_to_play_pressed() -> void:
	_hide_gym_tooltip()
	if how_to_play_overlay == null:
		return
	how_to_play_overlay.visible = true
	how_to_play_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_how_to_play_close_pressed() -> void:
	_close_how_to_play()


func _on_how_to_play_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_close_how_to_play()


func _close_how_to_play() -> void:
	if how_to_play_overlay == null:
		return
	how_to_play_overlay.visible = false
	how_to_play_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if DevCheats.feed_typed_key(key.unicode):
			_mark_input_handled()
