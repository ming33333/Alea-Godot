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
const ORB_COMPLETION_SETTLE_MAX_SEC := 2.8
const ORB_COMPLETION_START_DELAY_SEC := 0.45
const ORB_COMPLETION_PAUSE_SEC := 0.28
const ORB_COMPLETION_DROP_SEC := 0.88
const ORB_COMPLETION_GLOW_RAMP_SEC := 1.15
const PORTAL_REVEAL_SEC := 1.15
const PORTAL_REVEAL_PAUSE_SEC := 0.35
const PORTAL_REVEAL_SHADER: Shader = preload("res://assets/shaders/portal_reveal.gdshader")

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
@onready var challenge_orb_tooltip: PanelContainer = %ChallengeOrbTooltip
@onready var tooltip_badge: TextureRect = %TooltipBadge
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_subtitle: Label = %TooltipSubtitle
@onready var tooltip_body: Label = %TooltipBody
@onready var tooltip_footer: Label = %TooltipFooter
var _hover_challenge_orb_id: String = ""
var _launching: bool = false
var _click_seq: int = 0
var _orb_build_attempts: int = 0
var _portal_layout_attempts: int = 0
var _badge_box_open: bool = false
var _badge_box_animating: bool = false
var _badge_slide_tween: Tween
var _celebration_backdrop: ColorRect
var _orb_completion_active: bool = false
var _orb_completion_tween: Tween
var _celebration_orb_id: String = ""
var _celebration_play_attempts: int = 0
var _portal_reveal_active: bool = false
var _portal_reveal_tween: Tween
var _portal_was_visible_before_orb_celebration: bool = false
const MAX_ORB_BUILD_ATTEMPTS := 60
const MAX_PORTAL_LAYOUT_ATTEMPTS := 40
const MAX_CELEBRATION_PLAY_ATTEMPTS := 120


func _ready() -> void:
	DebugLog.alea_log("MainMenu", "========== MENU _ready ==========")
	if not resized.is_connected(_layout_deck_pillars):
		resized.connect(_layout_deck_pillars)
	challenge_orb_tooltip.visible = false
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
	if _orb_completion_active:
		return
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
	var menu_count: int = GameData.menu_challenge_orbs.size()
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
	if _portal_reveal_active:
		return
	if _should_hide_portal_for_celebration():
		champion_portal.visible = false
		return
	var show: bool = _should_show_champion_portal()
	champion_portal.visible = show
	if show:
		champion_portal.material = null
		champion_portal.mouse_filter = Control.MOUSE_FILTER_STOP
		call_deferred("_layout_champion_portal")
	else:
		champion_portal.material = null


func _should_hide_portal_for_celebration() -> bool:
	if GameState.pending_portal_reveal:
		return true
	if (
		not GameState.pending_orb_completion_celebration.is_empty()
		and SaveService.has_all_menu_badges()
	):
		return true
	return false


func _layout_champion_portal() -> void:
	if champion_portal == null or deck_pillars == null:
		return
	if not champion_portal.visible and not _portal_reveal_active:
		return
	if not _apply_champion_portal_layout():
		_portal_layout_attempts += 1
		if _portal_layout_attempts < MAX_PORTAL_LAYOUT_ATTEMPTS:
			call_deferred("_layout_champion_portal")
		return
	_portal_layout_attempts = 0


func _apply_champion_portal_layout() -> bool:
	if champion_portal == null or deck_pillars == null:
		return false
	var pillar_rect := deck_pillars.get_global_rect()
	if pillar_rect.size.x < 32.0 or pillar_rect.size.y < 32.0:
		return false
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
	return true


func _wait_for_champion_portal_layout() -> bool:
	if champion_portal == null:
		return false
	champion_portal.visible = true
	for _attempt in range(MAX_PORTAL_LAYOUT_ATTEMPTS):
		if _apply_champion_portal_layout():
			return true
		await get_tree().process_frame
	return false


func _build_orbs() -> void:
	if map_area == null:
		push_error("MainMenu: MapArea missing")
		return
	if _orb_completion_active:
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
	var pending_id: String = GameState.pending_orb_completion_celebration
	for challenge_orb in GameData.menu_challenge_orbs:
		var gid: String = str(challenge_orb.get("id", ""))
		if gid.is_empty():
			continue
		var defeated: bool = SaveService.has_badge(gid)
		var celebrate_now: bool = defeated and gid == pending_id
		var show_completed: bool = defeated and not celebrate_now
		var orb := _make_orb(challenge_orb, pillar_idx, show_completed)
		var base_pos := _orb_position_above_pillar(pillar_idx, show_completed)
		orb.set_float_base(base_pos)
		orb.configure_float(float(pillar_idx) * 0.85)
		orb.set_completed(show_completed)
		if show_completed:
			orb.set_floating_enabled(false)
		else:
			orb.set_floating_enabled(true)
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
		% [GameData.menu_challenge_orbs.size(), map_area.get_child_count()]
	)
	if not GameState.pending_orb_completion_celebration.is_empty():
		_orb_completion_active = true
		_launching = true
		_celebration_play_attempts = 0
		call_deferred("_play_orb_completion_celebration_if_needed")


func _orb_color_for_challenge_orb(challenge_orb_id: String) -> Color:
	return GameData.get_challenge_orb_color(challenge_orb_id)


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
	var orb_size: float = PixelChallengeOrb.display_size(seated, ORB_SIZE)
	var pad_offset: float = (orb_size - ORB_SIZE) * 0.5
	return Vector2(
		local.x - orb_size * 0.5,
		local.y - ORB_SIZE - gap - pad_offset
	)


func _make_orb(
	challenge_orb: Dictionary, pillar_index: int, seated: bool = false
) -> PixelChallengeOrb:
	var gid: String = orb_id_str(challenge_orb)
	var orb_size: float = PixelChallengeOrb.display_size(seated, ORB_SIZE)
	var btn := PixelChallengeOrb.new()
	btn.name = "Orb_%s" % gid
	btn.z_index = 3 if seated else 2
	btn.custom_minimum_size = Vector2(orb_size, orb_size)
	btn.size = Vector2(orb_size, orb_size)
	btn.set_orb_color(_orb_color_for_challenge_orb(gid))
	btn.mouse_entered.connect(_on_orb_hover.bind(challenge_orb, btn))
	btn.mouse_exited.connect(_on_orb_unhover.bind(challenge_orb))
	btn.pressed.connect(_on_orb_pressed.bind(gid))
	btn.set_meta("challenge_orb_id", gid)
	btn.set_meta("pillar_index", pillar_index)
	return btn


func _make_badge_icon(challenge_orb_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(BADGE_ICON_SIZE, BADGE_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = GameData.get_badge_texture(challenge_orb_id)
	return icon


func _populate_tooltip(challenge_orb: Dictionary) -> void:
	var gid: String = orb_id_str(challenge_orb)
	if tooltip_badge:
		tooltip_badge.texture = GameData.get_badge_texture(gid)
		tooltip_badge.visible = tooltip_badge.texture != null
	tooltip_name.text = str(challenge_orb.get("name", "Challenge Orb"))
	tooltip_subtitle.text = str(challenge_orb.get("subtitle", ""))
	tooltip_body.text = str(challenge_orb.get("description", ""))
	var earned: bool = SaveService.has_badge(gid)
	var badge_label: String = "Badge earned" if earned else "Badge locked"
	tooltip_footer.text = "%s · %s · click to play" % [
		challenge_orb.get("badge_name", ""),
		badge_label,
	]


func _on_orb_hover(challenge_orb: Dictionary, orb: Control) -> void:
	var gid: String = orb_id_str(challenge_orb)
	if _hover_challenge_orb_id == gid:
		if challenge_orb_tooltip.visible:
			call_deferred("_position_tooltip_near_orb", orb)
			return
	else:
		_hover_challenge_orb_id = gid
		_populate_tooltip(challenge_orb)
	challenge_orb_tooltip.visible = true
	call_deferred("_position_tooltip_near_orb", orb)


func _on_orb_unhover(challenge_orb: Dictionary) -> void:
	if orb_id_str(challenge_orb) == _hover_challenge_orb_id:
		_hide_challenge_orb_tooltip()


func _on_championship_hover() -> void:
	if champion_portal == null or not champion_portal.visible:
		return
	if _hover_challenge_orb_id == "championship" and challenge_orb_tooltip.visible:
		call_deferred("_position_tooltip_near_control", champion_portal)
		return
	_hover_challenge_orb_id = "championship"
	if tooltip_badge:
		tooltip_badge.visible = false
	tooltip_name.text = "Dice Master Test"
	tooltip_subtitle.text = "Portal to the ultimate challenge"
	tooltip_body.text = (
		"Enter the portal to face three random games. "
		+ "Win all three to become a Dice Master."
	)
	tooltip_footer.text = "All challenge orb badges earned · click to enter"
	challenge_orb_tooltip.visible = true
	call_deferred("_position_tooltip_near_control", champion_portal)


func _on_championship_unhover() -> void:
	if _hover_challenge_orb_id == "championship":
		_hide_challenge_orb_tooltip()


func _hide_challenge_orb_tooltip() -> void:
	_hover_challenge_orb_id = ""
	challenge_orb_tooltip.visible = false


func _position_tooltip_near_orb(orb: Control) -> void:
	_position_tooltip_near_control(orb)


func _position_tooltip_near_control(anchor: Control) -> void:
	if not challenge_orb_tooltip.visible:
		return
	challenge_orb_tooltip.reset_size()
	var center: Vector2 = anchor.get_global_rect().get_center()
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * center
	var tip_size: Vector2 = challenge_orb_tooltip.size
	var x: float = clampf(
		local.x - tip_size.x * 0.5,
		12.0,
		maxf(12.0, size.x - tip_size.x - 12.0)
	)
	var y: float = local.y - tip_size.y - TOOLTIP_GAP
	if y < 12.0:
		y = local.y + anchor.size.y + TOOLTIP_GAP
	challenge_orb_tooltip.position = Vector2(x, y)


func _find_orb(challenge_orb_id: String) -> PixelChallengeOrb:
	if map_area == null or challenge_orb_id.is_empty():
		return null
	var node := map_area.get_node_or_null("Orb_%s" % challenge_orb_id)
	return node as PixelChallengeOrb


func _play_orb_completion_celebration_if_needed() -> void:
	var orb_id: String = GameState.pending_orb_completion_celebration
	if orb_id.is_empty():
		_finish_orb_completion_celebration()
		return
	if not _map_area_ready():
		_celebration_play_attempts += 1
		if _celebration_play_attempts >= MAX_CELEBRATION_PLAY_ATTEMPTS:
			GameState.pending_orb_completion_celebration = ""
			_finish_orb_completion_celebration()
			return
		call_deferred("_play_orb_completion_celebration_if_needed")
		return
	var orb: PixelChallengeOrb = _find_orb(orb_id)
	if orb == null:
		_celebration_play_attempts += 1
		if _celebration_play_attempts >= MAX_CELEBRATION_PLAY_ATTEMPTS:
			GameState.pending_orb_completion_celebration = ""
			_finish_orb_completion_celebration()
			return
		call_deferred("_play_orb_completion_celebration_if_needed")
		return
	_celebration_play_attempts = 0
	_celebration_orb_id = orb_id
	_portal_was_visible_before_orb_celebration = (
		champion_portal != null
		and champion_portal.visible
		and champion_portal.material == null
	)
	_orb_completion_active = true
	_launching = true
	_run_orb_completion_celebration(orb, orb_id)


func _run_orb_completion_celebration(orb: PixelChallengeOrb, orb_id: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(orb):
		_finish_orb_completion_celebration()
		return
	if _celebration_orb_id != orb_id:
		_finish_orb_completion_celebration()
		return
	await get_tree().create_timer(ORB_COMPLETION_START_DELAY_SEC).timeout
	if not is_instance_valid(orb):
		_finish_orb_completion_celebration()
		return
	GameState.pending_orb_completion_celebration = ""
	var pillar_idx: int = int(orb.get_meta("pillar_index", 0))
	var hover_base: Vector2 = _orb_position_above_pillar(pillar_idx, false)
	var seated_base: Vector2 = _orb_position_above_pillar(pillar_idx, true)
	var completed_size: float = PixelChallengeOrb.display_size(true, ORB_SIZE)
	orb.set_display_diameter(ORB_SIZE)
	orb.set_completed(false)
	orb.set_float_base(hover_base)
	orb.set_floating_enabled(true)
	orb.z_index = 4
	await _wait_for_orb_bob_rest(orb)
	if not is_instance_valid(orb):
		_finish_orb_completion_celebration()
		return
	await get_tree().create_timer(ORB_COMPLETION_PAUSE_SEC).timeout
	if not is_instance_valid(orb):
		_finish_orb_completion_celebration()
		return
	orb.set_floating_enabled(false)
	orb.snap_to_float_rest()
	if _orb_completion_tween != null and _orb_completion_tween.is_valid():
		_orb_completion_tween.kill()
	_orb_completion_tween = create_tween()
	_orb_completion_tween.tween_property(orb, "position", seated_base, ORB_COMPLETION_DROP_SEC)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _orb_completion_tween.finished
	if not is_instance_valid(orb):
		_finish_orb_completion_celebration()
		return
	orb.position = seated_base
	orb.set_float_base(seated_base)
	orb.set_display_diameter(ORB_SIZE)
	orb.set_glow_ramp(0.0)
	orb.set_completed(true)
	orb.z_index = 3
	var glow := create_tween()
	glow.set_parallel(true)
	glow.tween_method(
		func(ramp: float) -> void:
			if is_instance_valid(orb):
				orb.set_glow_ramp(ramp),
		0.0,
		1.0,
		ORB_COMPLETION_GLOW_RAMP_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow.tween_method(
		func(diameter: float) -> void:
			if is_instance_valid(orb):
				orb.set_display_diameter(diameter),
		ORB_SIZE,
		completed_size,
		ORB_COMPLETION_GLOW_RAMP_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await glow.finished
	if is_instance_valid(orb):
		orb.set_glow_ramp(1.0)
		orb.set_display_diameter(completed_size)
	DebugLog.alea_log("MainMenu", "orb completion celebration finished for %s" % orb_id)
	if (
		SaveService.has_all_menu_badges()
		and not _portal_was_visible_before_orb_celebration
	):
		GameState.request_portal_reveal()
	_finish_orb_completion_celebration()


func _wait_for_orb_bob_rest(orb: PixelChallengeOrb) -> void:
	var frames: int = 0
	var max_frames: int = int(ceil(ORB_COMPLETION_SETTLE_MAX_SEC * 60.0))
	while is_instance_valid(orb) and frames < max_frames:
		if orb.is_bob_near_rest():
			return
		frames += 1
		await get_tree().process_frame


func _finish_orb_completion_celebration() -> void:
	_orb_completion_active = false
	_celebration_orb_id = ""
	_celebration_play_attempts = 0
	if GameState.pending_portal_reveal and SaveService.has_all_menu_badges():
		call_deferred("_play_champion_portal_reveal")
		return
	_launching = false
	_refresh_champion_portal()


func _play_champion_portal_reveal() -> void:
	if champion_portal == null or not _should_show_champion_portal():
		GameState.pending_portal_reveal = false
		_launching = false
		_refresh_champion_portal()
		return
	if _portal_reveal_active:
		return
	_portal_reveal_active = true
	_launching = true
	_run_champion_portal_reveal()


func _run_champion_portal_reveal() -> void:
	if champion_portal == null:
		_finish_champion_portal_reveal()
		return
	GameState.pending_portal_reveal = false
	champion_portal.visible = true
	if not await _wait_for_champion_portal_layout():
		_finish_champion_portal_reveal()
		return
	champion_portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PORTAL_REVEAL_SHADER
	mat.set_shader_parameter("reveal_y", 0.0)
	champion_portal.material = mat
	await get_tree().process_frame
	await get_tree().create_timer(PORTAL_REVEAL_PAUSE_SEC).timeout
	if not is_instance_valid(champion_portal):
		_finish_champion_portal_reveal()
		return
	if _portal_reveal_tween != null and _portal_reveal_tween.is_valid():
		_portal_reveal_tween.kill()
	_portal_reveal_tween = create_tween()
	_portal_reveal_tween.tween_method(
		func(reveal: float) -> void:
			if is_instance_valid(champion_portal) and champion_portal.material is ShaderMaterial:
				(champion_portal.material as ShaderMaterial).set_shader_parameter("reveal_y", reveal),
		0.0,
		1.0,
		PORTAL_REVEAL_SEC
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _portal_reveal_tween.finished
	_finish_champion_portal_reveal()


func _finish_champion_portal_reveal() -> void:
	_portal_reveal_active = false
	_launching = false
	GameState.pending_portal_reveal = false
	if champion_portal != null:
		champion_portal.material = null
	_refresh_champion_portal()


func orb_id_str(challenge_orb: Dictionary) -> String:
	return str(challenge_orb.get("id", ""))


func _mark_input_handled() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp:
		vp.set_input_as_handled()


func _log_challenge_orb_click(phase: String, challenge_orb_id: String, detail: String = "") -> void:
	var label: String = challenge_orb_id if not challenge_orb_id.is_empty() else "(none)"
	if not challenge_orb_id.is_empty():
		var challenge_orb: Dictionary = GameData.get_challenge_orb(challenge_orb_id)
		var display_name: String = str(challenge_orb.get("name", ""))
		if not display_name.is_empty():
			label = "%s / %s" % [challenge_orb_id, display_name]
	var line := "*** CHALLENGE ORB CLICK [%s] seq=%d challenge_orb=%s" % [phase, _click_seq, label]
	if not detail.is_empty():
		line += " | " + detail
	DebugLog.alea_log("MainMenu", line)


func _on_orb_pressed(challenge_orb_id: String) -> void:
	_click_seq += 1
	_log_challenge_orb_click("PRESSED", challenge_orb_id, "launching challenge orb")
	_hide_challenge_orb_tooltip()
	_launch_challenge_orb(challenge_orb_id)


func _launch_challenge_orb(challenge_orb_id: String) -> void:
	if challenge_orb_id.is_empty():
		DebugLog.log_error("MainMenu", "_launch_challenge_orb called with empty challenge_orb_id")
		return
	if _launching:
		_log_challenge_orb_click("SKIPPED", challenge_orb_id, "launch already in progress")
		return
	_launching = true
	_log_challenge_orb_click("LAUNCH", challenge_orb_id, "starting scene change")
	_hide_challenge_orb_tooltip()
	GameState.selected_challenge_orb_id = challenge_orb_id
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
	_log_challenge_orb_click("LOADED", challenge_orb_id, "scene=%s err=%s" % [after, err])


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
	if _orb_completion_active:
		return
	call_deferred("_build_orbs")


func _on_championship_pressed() -> void:
	_hide_challenge_orb_tooltip()
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
	_hide_challenge_orb_tooltip()
	_close_how_to_play()
	SceneNav.go_to_settings()


func _populate_how_to_play() -> void:
	HowToPlayContent.populate(how_to_play_sections)


func _on_how_to_play_pressed() -> void:
	_hide_challenge_orb_tooltip()
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
