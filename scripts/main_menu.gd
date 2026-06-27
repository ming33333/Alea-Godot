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
const BADGE_SILHOUETTE_COLOR := Color(0.12, 0.14, 0.18, 0.72)
const CROWN_BADGE_BORDER_COLOR := Color(0.85, 0.72, 0.35, 0.82)
const BADGE_SLIDE_DURATION := 0.55
const BADGE_FLY_APPEAR_SEC := 0.22
const BADGE_FLY_HOLD_SEC := 0.12
const BADGE_FLY_TRAVEL_SEC := 0.48
const BADGE_FLY_SIZE := 56.0
const BADGE_FLY_PAUSE_BEFORE_SEC := 0.18
const BADGE_ARRIVAL_POP_SEC := 0.22
const BADGE_AWARD_SFX: AudioStream = preload("res://assets/sfx/badge_award.mp3")
const ORB_COMPLETION_SFX: AudioStream = preload("res://assets/sfx/orb_completion.mp3")
const CLOSED_BOX_TEX: Texture2D = preload("res://assets/textures/closed_box.png")
const OPENED_BOX_TEX: Texture2D = preload("res://assets/textures/opened_box.png")
const RIVER_DAY_TEX: Texture2D = preload("res://assets/textures/river_upscale.jpg")
const RIVER_NIGHT_TEX: Texture2D = preload("res://assets/textures/river_night.jpg")
const RIVER_BG_FADE_OUT_SEC := 5.0
const RIVER_BG_FADE_IN_SEC := 5.0
const CHAMPION_DIALOGUE_FIRST_TEXT := "Good work... the stars have come out for you."
const CHAMPION_DIALOGUE_REPEAT_TEXT := (
	"Nice work. When you are ready, pick your next crown challenge from the portal."
)
const TITLE_BLOCK_INTRO_Z := 90
const TITLE_BLOCK_DEFAULT_Z := 3
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
const ORB_IDLE_SHINE_MIN_SEC := 2.0
const ORB_IDLE_SHINE_MAX_SEC := 4.0
const ORB_IDLE_SHINE_DURATION_SEC := 1.0
const PORTAL_REVEAL_SEC := 1.15
const PORTAL_REVEAL_PAUSE_SEC := 0.35
const PORTAL_REVEAL_SHADER: Shader = preload("res://assets/shaders/portal_reveal.gdshader")
const DEMO_TITLE_BOB_SEC := 0.42
const DEMO_TITLE_SCALE_UP := 1.14

@onready var map_area: Control = %MapArea
@onready var champion_portal: TextureButton = %ChampionPortal
@onready var deck_pillars: HBoxContainer = %DeckPillars
@onready var badge_box_wrap: HBoxContainer = %BadgeBoxWrap
@onready var badge_box_btn: TextureButton = %BadgeBoxBtn
@onready var badge_slide_clip: Control = %BadgeSlideClip
@onready var badges_row: HBoxContainer = %BadgesRow
@onready var celebration_icon: TextureRect = %CelebrationIcon
@onready var celebration: PanelContainer = %ChampionCelebration
@onready var celebration_label: Label = %ChampionCelebrationLabel
@onready var celebration_detail: Label = %CelebrationDetail
@onready var champion_dialogue: PanelContainer = %ChampionDialogue
@onready var champion_dialogue_body: Label = %ChampionDialogueBody
@onready var how_to_play_overlay: Control = %HowToPlayOverlay
@onready var how_to_play_sections: VBoxContainer = %HowToPlaySections
@onready var challenge_orb_tooltip: PanelContainer = %ChallengeOrbTooltip
@onready var tooltip_badge: TextureRect = %TooltipBadge
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_subtitle: Label = %TooltipSubtitle
@onready var tooltip_body: Label = %TooltipBody
@onready var tooltip_footer: Label = %TooltipFooter
@onready var title_demo: Label = %TitleDemo
@onready var title_block: CenterContainer = %TitleBlock
@onready var title_alea: Label = %TitleAlea
@onready var menu_intro: MenuIntro = %IntroOverlay
@onready var badge_block: VBoxContainer = $BadgeBlock
@onready var menu_actions: VBoxContainer = $MenuActions
@onready var margin_block: MarginContainer = $Margin
@onready var river: TextureRect = %River
var _hover_challenge_orb_id: String = ""
var _hover_badge_box_icon: Control = null
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
var _badge_fly_layer: Control
var _badge_fly_reveal_orb_id: String = ""
var _crown_fly_reveal_index: int = 0
var _title_demo_tween: Tween
var _orb_idle_shine_timer: Timer
var _orb_idle_shine_active: bool = false
var _river_fade_tween: Tween
var _river_fade_overlay: ColorRect
var _champion_intro_active: bool = false
var _menu_intro_active: bool = false
var _orb_build_pending: bool = false
const MAX_ORB_BUILD_ATTEMPTS := 60
const MAX_PORTAL_LAYOUT_ATTEMPTS := 40
const MAX_CELEBRATION_PLAY_ATTEMPTS := 120


func _enter_tree() -> void:
	if not _should_play_menu_intro():
		return
	var intro := get_node_or_null("IntroOverlay")
	if intro != null and intro.has_method("show_backdrop"):
		intro.call("show_backdrop")


func _ready() -> void:
	if _should_play_menu_intro():
		_prepare_menu_intro_hidden()
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
	if _should_play_menu_intro():
		call_deferred("_run_menu_boot_sequence")
	elif not _menu_intro_active:
		_finish_menu_ready()


func _should_play_menu_intro() -> bool:
	if (
		GameState.skip_menu_intro
		or AudioSettings.is_menu_intro_skipped()
		or GameState.show_champion_celebration
	):
		return false
	return menu_intro != null or has_node("IntroOverlay")


func _prepare_menu_intro_hidden() -> void:
	_menu_intro_active = true
	if title_block != null:
		title_block.visible = true
		title_block.modulate = Color.WHITE
		title_block.z_index = TITLE_BLOCK_INTRO_Z
	if title_alea != null:
		title_alea.visible = false
	if title_demo != null and not GameState.demo_mode:
		title_demo.visible = false
	if menu_intro != null:
		menu_intro.show_backdrop()


func _run_menu_boot_sequence() -> void:
	if menu_intro == null or title_alea == null:
		_menu_intro_active = false
		GameState.skip_menu_intro = false
		_finish_menu_ready()
		return
	_menu_intro_active = false
	_finish_menu_ready()
	await _cache_title_slot_for_intro()
	await get_tree().process_frame
	_menu_intro_active = true
	await menu_intro.play(title_alea)
	_menu_intro_active = false
	GameState.skip_menu_intro = false
	if title_block != null:
		title_block.z_index = TITLE_BLOCK_DEFAULT_Z
	if title_alea != null:
		if title_alea.top_level:
			title_alea.top_level = false
		title_alea.visible = true
		title_alea.modulate = Color.WHITE


func _cache_title_slot_for_intro() -> void:
	if title_alea == null:
		return
	title_alea.visible = true
	title_alea.modulate = Color(1.0, 1.0, 1.0, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	title_alea.set_meta("intro_title_end_global", title_alea.global_position)
	title_alea.visible = false
	title_alea.modulate = Color.WHITE


func _finish_menu_ready() -> void:
	_layout_deck_pillars()
	_setup_demo_title()
	if (
		not GameState.pending_orb_completion_celebration.is_empty()
		and GameState.pending_badge_award_fly
	):
		_badge_fly_reveal_orb_id = GameState.pending_orb_completion_celebration
	_badge_box_open = SaveService.is_badge_box_open()
	_setup_badge_fly_layer()
	_setup_orb_idle_shine()
	if GameState.show_champion_celebration:
		call_deferred("_begin_champion_return_sequence")
	else:
		_refresh_river_background(false)
	_refresh_badges()
	_populate_how_to_play()
	if how_to_play_overlay:
		how_to_play_overlay.visible = false
	call_deferred("_refresh_champion_portal")
	_refresh_champion_crown_art()
	if not GameState.show_champion_celebration:
		_present_champion_celebration_if_needed()
	if champion_portal:
		champion_portal.tooltip_text = ""


func _champion_crown_index() -> int:
	if GameState.show_champion_celebration and GameState.pending_champion_crown_index > 0:
		return GameState.pending_champion_crown_index
	return SaveService.get_dice_champion_crown_index()


func _refresh_champion_crown_art() -> void:
	var crown_idx: int = _champion_crown_index()
	DiceCrownArt.apply_texture_rect(celebration_icon, crown_idx, 48)


func _make_crown_icon(crown_index: int, earned: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(BADGE_ICON_SIZE, BADGE_ICON_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.28)
	style.border_color = CROWN_BADGE_BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 3)
	pad.add_theme_constant_override("margin_top", 3)
	pad.add_theme_constant_override("margin_right", 3)
	pad.add_theme_constant_override("margin_bottom", 3)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(pad)
	var icon := TextureRect.new()
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = DiceCrownArt.get_texture(crown_index)
	icon.modulate = Color.WHITE if earned else BADGE_SILHOUETTE_COLOR
	icon.pivot_offset = Vector2(BADGE_ICON_SIZE * 0.5, BADGE_ICON_SIZE * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(icon)
	slot.set_meta("crown_index", crown_index)
	slot.set_meta("crown_earned", earned)
	slot.mouse_entered.connect(_on_badge_box_icon_hover.bind(slot))
	slot.mouse_exited.connect(_on_badge_box_icon_unhover.bind(slot))
	return slot


func _crown_slot_icon(slot: Control) -> TextureRect:
	if slot == null or slot.get_child_count() == 0:
		return null
	var pad := slot.get_child(0) as MarginContainer
	if pad == null or pad.get_child_count() == 0:
		return null
	return pad.get_child(0) as TextureRect


func _map_area_ready() -> bool:
	return map_area != null and map_area.size.x >= 32.0 and map_area.size.y >= 32.0


func _setup_demo_title() -> void:
	if title_demo == null:
		return
	if not GameState.demo_mode:
		title_demo.visible = false
		return
	title_demo.visible = true
	title_demo.pivot_offset = title_demo.size * 0.5
	title_demo.resized.connect(_layout_demo_title_pivot)
	call_deferred("_layout_demo_title_pivot")
	_start_demo_title_bob()


func _layout_demo_title_pivot() -> void:
	if title_demo != null:
		title_demo.pivot_offset = title_demo.size * 0.5


func _start_demo_title_bob() -> void:
	if title_demo == null:
		return
	if _title_demo_tween != null and _title_demo_tween.is_valid():
		_title_demo_tween.kill()
	title_demo.scale = Vector2.ONE
	_title_demo_tween = create_tween().set_loops()
	_title_demo_tween.tween_property(
		title_demo,
		"scale",
		Vector2(DEMO_TITLE_SCALE_UP, DEMO_TITLE_SCALE_UP),
		DEMO_TITLE_BOB_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_demo_tween.tween_property(
		title_demo,
		"scale",
		Vector2.ONE,
		DEMO_TITLE_BOB_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_map_area_resized() -> void:
	if _orb_completion_active or _menu_intro_active:
		return
	if not _map_area_ready():
		return
	DebugLog.alea_log("MainMenu", "MapArea resized -> %s, rebuilding orbs" % map_area.size)
	_schedule_build_orbs()


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
	if _map_area_ready() and not _menu_intro_active:
		_schedule_build_orbs()
	if champion_portal != null and champion_portal.visible:
		call_deferred("_layout_champion_portal")


func _should_show_champion_portal() -> bool:
	if GameState.demo_mode:
		return false
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


func _schedule_build_orbs() -> void:
	if _menu_intro_active or _orb_completion_active:
		return
	if _orb_build_pending:
		return
	_orb_build_pending = true
	call_deferred("_run_scheduled_build_orbs")


func _run_scheduled_build_orbs() -> void:
	_orb_build_pending = false
	_build_orbs()


func _build_orbs() -> void:
	if map_area == null:
		push_error("MainMenu: MapArea missing")
		return
	if _menu_intro_active:
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
			_schedule_build_orbs()
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
	else:
		_refresh_orb_idle_shine_schedule()


func _setup_orb_idle_shine() -> void:
	_orb_idle_shine_timer = Timer.new()
	_orb_idle_shine_timer.name = "OrbIdleShineTimer"
	_orb_idle_shine_timer.one_shot = true
	_orb_idle_shine_timer.timeout.connect(_on_orb_idle_shine_timer)
	add_child(_orb_idle_shine_timer)


func _can_orb_idle_shine() -> bool:
	return (
		SaveService.has_all_menu_badges()
		and not _orb_completion_active
		and not _orb_idle_shine_active
		and not _portal_reveal_active
		and not _menu_intro_active
		and not _champion_intro_active
		and not GameState.show_champion_celebration
		and GameState.pending_orb_completion_celebration.is_empty()
		and _badge_fly_reveal_orb_id.is_empty()
	)


func _refresh_orb_idle_shine_schedule() -> void:
	if _orb_idle_shine_timer == null:
		return
	if not _can_orb_idle_shine():
		_orb_idle_shine_timer.stop()
		return
	if _orb_idle_shine_timer.is_stopped():
		_orb_idle_shine_timer.start(randf_range(ORB_IDLE_SHINE_MIN_SEC, ORB_IDLE_SHINE_MAX_SEC))


func _on_orb_idle_shine_timer() -> void:
	if not _can_orb_idle_shine():
		_refresh_orb_idle_shine_schedule()
		return
	_play_orb_idle_shine()


func _play_orb_idle_shine() -> void:
	_orb_idle_shine_active = true
	var orbs := _completed_menu_orbs()
	if orbs.is_empty():
		_orb_idle_shine_active = false
		_refresh_orb_idle_shine_schedule()
		return
	var orb: PixelChallengeOrb = orbs[randi() % orbs.size()]
	orb.play_idle_shine(ORB_IDLE_SHINE_DURATION_SEC)
	var wait := get_tree().create_timer(ORB_IDLE_SHINE_DURATION_SEC)
	await wait.timeout
	_orb_idle_shine_active = false
	if is_inside_tree():
		_refresh_orb_idle_shine_schedule()


func _completed_menu_orbs() -> Array[PixelChallengeOrb]:
	var out: Array[PixelChallengeOrb] = []
	if map_area == null:
		return out
	for child in map_area.get_children():
		if child is PixelChallengeOrb and (child as PixelChallengeOrb).is_menu_completed():
			out.append(child as PixelChallengeOrb)
	return out


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
	var demo_locked: bool = GameState.demo_mode and not GameState.is_orb_playable(gid)
	btn.set_demo_locked(demo_locked)
	return btn


func _make_badge_icon(challenge_orb_id: String, earned: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(BADGE_ICON_SIZE, BADGE_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = GameData.get_badge_texture(challenge_orb_id)
	icon.modulate = Color.WHITE if earned else BADGE_SILHOUETTE_COLOR
	icon.pivot_offset = Vector2(BADGE_ICON_SIZE * 0.5, BADGE_ICON_SIZE * 0.5)
	icon.set_meta("challenge_orb_id", challenge_orb_id)
	icon.set_meta("badge_earned", earned)
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.mouse_entered.connect(_on_badge_box_icon_hover.bind(icon))
	icon.mouse_exited.connect(_on_badge_box_icon_unhover.bind(icon))
	return icon


func _populate_badge_box_orb_tooltip(challenge_orb_id: String, earned: bool) -> void:
	var challenge_orb: Dictionary = GameData.get_challenge_orb(challenge_orb_id)
	var orb_name: String = str(challenge_orb.get("name", "Challenge Orb"))
	var badge_name: String = str(challenge_orb.get("badge_name", "Badge"))
	if tooltip_badge:
		tooltip_badge.texture = GameData.get_badge_texture(challenge_orb_id)
		tooltip_badge.visible = tooltip_badge.texture != null
		tooltip_badge.modulate = Color.WHITE if earned else BADGE_SILHOUETTE_COLOR
	tooltip_name.text = badge_name
	tooltip_subtitle.text = orb_name
	if earned:
		tooltip_body.text = "Earned by reaching level 8 in %s." % orb_name
	else:
		tooltip_body.text = "Reach level 8 in %s to earn this badge." % orb_name
	tooltip_footer.text = str(challenge_orb.get("subtitle", ""))


func _populate_badge_box_crown_tooltip(crown_index: int, earned: bool) -> void:
	var opponents: Array[String] = DiceCrownArt.opponents_for_crown(crown_index)
	var combo_names: String = DiceCrownArt.format_combo_names(opponents)
	if tooltip_badge:
		tooltip_badge.texture = DiceCrownArt.get_texture(crown_index)
		tooltip_badge.visible = tooltip_badge.texture != null
		tooltip_badge.modulate = Color.WHITE if earned else BADGE_SILHOUETTE_COLOR
	tooltip_name.text = "Dice Master Crown"
	tooltip_subtitle.text = combo_names
	if earned:
		tooltip_body.text = (
			"Earned by winning the Dice Master Test against %s." % combo_names
		)
		tooltip_footer.text = "Win all three games in one run"
	else:
		tooltip_body.text = "Win the Dice Master Test against %s." % combo_names
		tooltip_footer.text = "Crown locked"


func _on_badge_box_icon_hover(icon: Control) -> void:
	_hover_badge_box_icon = icon
	_hover_challenge_orb_id = ""
	if icon.has_meta("crown_index"):
		_populate_badge_box_crown_tooltip(
			int(icon.get_meta("crown_index")),
			bool(icon.get_meta("crown_earned"))
		)
	elif icon.has_meta("challenge_orb_id"):
		_populate_badge_box_orb_tooltip(
			str(icon.get_meta("challenge_orb_id")),
			bool(icon.get_meta("badge_earned"))
		)
	else:
		return
	challenge_orb_tooltip.visible = true
	call_deferred("_position_tooltip_near_control", icon)


func _on_badge_box_icon_unhover(icon: Control) -> void:
	if _hover_badge_box_icon == icon:
		_hide_challenge_orb_tooltip()


func _populate_tooltip(challenge_orb: Dictionary) -> void:
	var gid: String = orb_id_str(challenge_orb)
	var earned: bool = SaveService.has_badge(gid)
	if tooltip_badge:
		tooltip_badge.texture = GameData.get_badge_texture(gid)
		tooltip_badge.visible = tooltip_badge.texture != null
		tooltip_badge.modulate = Color.WHITE if earned else BADGE_SILHOUETTE_COLOR
	tooltip_name.text = str(challenge_orb.get("name", "Challenge Orb"))
	tooltip_subtitle.text = str(challenge_orb.get("subtitle", ""))
	tooltip_body.text = str(challenge_orb.get("description", ""))
	var badge_label: String = "Badge earned" if earned else "Badge locked"
	if GameState.demo_mode and not GameState.is_orb_playable(gid):
		tooltip_footer.text = "Not in demo | full game unlocks all challenge orbs"
	else:
		tooltip_footer.text = "%s | %s | click to play" % [
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
	if SaveService.has_any_crown() and SaveService.has_unearned_crown():
		tooltip_body.text = (
			"Pick your powers, then choose which crown challenge to face. "
			+ "Win all three games in that run to earn the crown."
		)
	elif SaveService.has_all_crowns():
		tooltip_body.text = (
			"You collected every crown. Enter to replay any challenge."
		)
	else:
		tooltip_body.text = (
			"Enter the portal to face three random games. "
			+ "Win all three to earn your first crown."
		)
	tooltip_footer.text = "All challenge orb badges earned | click to enter"
	challenge_orb_tooltip.visible = true
	call_deferred("_position_tooltip_near_control", champion_portal)


func _on_championship_unhover() -> void:
	if _hover_challenge_orb_id == "championship":
		_hide_challenge_orb_tooltip()


func _hide_challenge_orb_tooltip() -> void:
	_hover_challenge_orb_id = ""
	_hover_badge_box_icon = null
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
	_play_orb_completion_sfx()
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
	if GameState.pending_badge_award_fly and SaveService.has_badge(orb_id):
		_badge_fly_reveal_orb_id = orb_id
		_refresh_badges()
		await _play_badge_award_fly(orb, orb_id)
	if (
		not GameState.demo_mode
		and SaveService.has_all_menu_badges()
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
	_badge_fly_reveal_orb_id = ""
	GameState.pending_badge_award_fly = false
	if GameState.pending_portal_reveal and SaveService.has_all_menu_badges():
		call_deferred("_play_champion_portal_reveal")
		return
	_launching = false
	_refresh_champion_portal()
	_refresh_orb_idle_shine_schedule()


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
	_refresh_orb_idle_shine_schedule()


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
	if not GameState.is_orb_playable(challenge_orb_id):
		_log_challenge_orb_click("SKIPPED", challenge_orb_id, "demo locked")
		return
	_click_seq += 1
	_log_challenge_orb_click("PRESSED", challenge_orb_id, "launching challenge orb")
	_hide_challenge_orb_tooltip()
	_launch_challenge_orb(challenge_orb_id)


func _launch_challenge_orb(challenge_orb_id: String) -> void:
	if challenge_orb_id.is_empty():
		DebugLog.log_error("MainMenu", "_launch_challenge_orb called with empty challenge_orb_id")
		return
	if not GameState.is_orb_playable(challenge_orb_id):
		_log_challenge_orb_click("SKIPPED", challenge_orb_id, "demo locked")
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
	for challenge_orb in GameData.menu_challenge_orbs:
		var gid: String = orb_id_str(challenge_orb)
		var earned: bool = SaveService.has_badge(gid)
		if earned and gid == _badge_fly_reveal_orb_id:
			earned = false
		badges_row.add_child(_make_badge_icon(gid, earned))
	if SaveService.has_any_crown():
		for crown_idx in range(1, DiceCrownArt.crown_count() + 1):
			var crown_earned: bool = SaveService.has_crown(crown_idx)
			if crown_earned and crown_idx == _crown_fly_reveal_index:
				crown_earned = false
			badges_row.add_child(_make_crown_icon(crown_idx, crown_earned))
	_size_badges_row()
	_update_badge_box()
	_refresh_champion_portal()


func _size_badges_row() -> void:
	if badges_row == null:
		return
	badges_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var row_w: float = _badges_row_width()
	var row_h: float = BADGE_ICON_SIZE
	badges_row.custom_minimum_size = Vector2(row_w, row_h)
	badges_row.size = Vector2(row_w, row_h)
	if badge_slide_clip != null:
		badges_row.position = Vector2.ZERO


func _reset_badge_icon_alpha() -> void:
	for child in badges_row.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 1.0


func _has_badge_collection() -> bool:
	return not GameData.menu_challenge_orbs.is_empty()


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
	var has_badges: bool = _has_badge_collection()
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


func _set_badge_slide_width(
	target_w: float,
	animate: bool,
	closing: bool = false,
	fade_icons: bool = true
) -> void:
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
	if fade_icons:
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
	else:
		_reset_badge_icon_alpha()
	_badge_slide_tween.finished.connect(_on_badge_slide_finished.bind(closing), CONNECT_ONE_SHOT)


func _on_badge_slide_finished(closing: bool) -> void:
	_badge_box_animating = false
	if closing:
		_badge_box_open = false
		SaveService.set_badge_box_open(false)
		_hide_challenge_orb_tooltip()
		if badge_box_btn != null:
			badge_box_btn.texture_normal = CLOSED_BOX_TEX
	if badge_box_btn != null:
		badge_box_btn.disabled = false
		if _badge_box_open:
			badge_box_btn.tooltip_text = "Click to close your badge box"
		else:
			badge_box_btn.tooltip_text = "Click to open your badge box"


func _on_badge_box_pressed() -> void:
	if _badge_box_animating or not _has_badge_collection():
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


func _target_river_texture() -> Texture2D:
	return RIVER_NIGHT_TEX if SaveService.has_any_crown() else RIVER_DAY_TEX


func _river_textures_match(a: Texture2D, b: Texture2D) -> bool:
	if a == b:
		return true
	if a == null or b == null:
		return false
	var path_a: String = a.resource_path
	var path_b: String = b.resource_path
	return not path_a.is_empty() and path_a == path_b


func _refresh_river_background(animated: bool = false) -> void:
	if river == null:
		return
	var target_tex: Texture2D = _target_river_texture()
	if _river_textures_match(river.texture, target_tex):
		river.modulate = Color.WHITE
		return
	if not animated:
		_stop_river_fade_overlay()
		river.texture = target_tex
		river.modulate = Color.WHITE
		return
	_animate_river_background_switch(target_tex)


func _ensure_river_fade_overlay() -> void:
	if _river_fade_overlay != null or river == null:
		return
	_river_fade_overlay = ColorRect.new()
	_river_fade_overlay.name = "RiverFadeOverlay"
	_river_fade_overlay.color = Color.BLACK
	_river_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_river_fade_overlay.anchor_right = 1.0
	_river_fade_overlay.anchor_bottom = 1.0
	_river_fade_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_river_fade_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_river_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_river_fade_overlay.z_index = 5
	_river_fade_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_river_fade_overlay.visible = false
	add_child(_river_fade_overlay)


func _stop_river_fade_overlay() -> void:
	if _river_fade_tween != null and _river_fade_tween.is_valid():
		_river_fade_tween.kill()
	if _river_fade_overlay == null:
		return
	_river_fade_overlay.visible = false
	_river_fade_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _animate_river_background_switch_async(target_tex: Texture2D) -> void:
	_animate_river_background_switch(target_tex)
	if _river_fade_tween != null and _river_fade_tween.is_valid():
		await _river_fade_tween.finished


func _begin_champion_return_sequence() -> void:
	if not GameState.show_champion_celebration:
		return
	_champion_intro_active = true
	_hide_champion_celebration()
	_hide_champion_dialogue()
	if GameState.pending_champion_first_crown:
		var target_tex: Texture2D = _target_river_texture()
		if river != null and not _river_textures_match(river.texture, target_tex):
			await _animate_river_background_switch_async(target_tex)
		else:
			_refresh_river_background(false)
	else:
		_refresh_river_background(false)
	if not is_inside_tree() or not GameState.show_champion_celebration:
		_champion_intro_active = false
		return
	_show_champion_dialogue(GameState.pending_champion_first_crown)


func _show_champion_dialogue(first_crown: bool) -> void:
	_ensure_celebration_backdrop()
	_celebration_backdrop.visible = true
	if champion_dialogue_body != null:
		champion_dialogue_body.text = (
			CHAMPION_DIALOGUE_FIRST_TEXT if first_crown else CHAMPION_DIALOGUE_REPEAT_TEXT
		)
	if champion_dialogue != null:
		champion_dialogue.visible = true
		champion_dialogue.z_index = 50
		champion_dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	if celebration != null:
		celebration.visible = false
	move_child(_celebration_backdrop, get_child_count() - 1)
	if champion_dialogue != null:
		move_child(champion_dialogue, get_child_count() - 1)


func _hide_champion_dialogue() -> void:
	if champion_dialogue != null:
		champion_dialogue.visible = false
		champion_dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_champion_dialogue_dismiss() -> void:
	_hide_champion_dialogue()
	_champion_intro_active = false
	GameState.pending_champion_first_crown = false
	_present_champion_celebration_if_needed()


func _animate_river_background_switch(target_tex: Texture2D) -> void:
	if river == null:
		return
	_ensure_river_fade_overlay()
	if _river_fade_overlay == null:
		river.texture = target_tex
		river.modulate = Color.WHITE
		return
	if _river_fade_tween != null and _river_fade_tween.is_valid():
		_river_fade_tween.kill()
	_river_fade_overlay.visible = true
	_river_fade_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_river_fade_tween = create_tween()
	_river_fade_tween.tween_property(
		_river_fade_overlay, "modulate:a", 1.0, RIVER_BG_FADE_OUT_SEC
	).set_trans(Tween.TRANS_LINEAR)
	_river_fade_tween.tween_callback(func() -> void:
		if is_instance_valid(river):
			river.texture = target_tex
			river.modulate = Color.WHITE
	)
	_river_fade_tween.tween_property(
		_river_fade_overlay, "modulate:a", 0.0, RIVER_BG_FADE_IN_SEC
	).set_trans(Tween.TRANS_LINEAR)
	_river_fade_tween.tween_callback(func() -> void:
		if is_instance_valid(_river_fade_overlay):
			_river_fade_overlay.visible = false
			_river_fade_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	)


func _on_badges_changed() -> void:
	if not _champion_intro_active and not GameState.show_champion_celebration:
		_refresh_river_background(false)
	_refresh_badges()
	if _orb_completion_active or not _badge_fly_reveal_orb_id.is_empty() or _crown_fly_reveal_index > 0:
		return
	_schedule_build_orbs()


func _setup_badge_fly_layer() -> void:
	if _badge_fly_layer != null:
		return
	_badge_fly_layer = Control.new()
	_badge_fly_layer.name = "BadgeFlyLayer"
	_badge_fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge_fly_layer.anchor_right = 1.0
	_badge_fly_layer.anchor_bottom = 1.0
	_badge_fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_fly_layer.z_index = 60
	add_child(_badge_fly_layer)


func _get_crown_icon(crown_index: int) -> Control:
	if badges_row == null:
		return null
	for child in badges_row.get_children():
		if int(child.get_meta("crown_index", 0)) == crown_index:
			return child as Control
	return null


func _get_badge_icon(challenge_orb_id: String) -> TextureRect:
	if badges_row == null:
		return null
	for child in badges_row.get_children():
		if child is TextureRect and str(child.get_meta("challenge_orb_id", "")) == challenge_orb_id:
			return child as TextureRect
	return null


func _ensure_badge_box_open_for_award() -> void:
	if badge_box_btn == null or badge_slide_clip == null:
		return
	var target_w: float = _badges_row_width()
	_size_badges_row()
	_reset_badge_icon_alpha()
	if _badge_box_open and is_equal_approx(badge_slide_clip.custom_minimum_size.x, target_w):
		return
	_badge_box_open = true
	SaveService.set_badge_box_open(true)
	badge_box_btn.texture_normal = OPENED_BOX_TEX
	badge_box_btn.tooltip_text = "Click to close your badge box"
	badge_box_btn.disabled = true
	if is_equal_approx(badge_slide_clip.custom_minimum_size.x, target_w):
		return
	await _await_badge_slide_width(target_w, false, false)
	if badge_box_btn != null:
		badge_box_btn.disabled = _badge_box_animating


func _await_badge_slide_width(
	target_w: float,
	closing: bool,
	fade_icons: bool = true
) -> void:
	if badge_slide_clip == null:
		return
	var clamped: float = maxf(0.0, target_w)
	if is_equal_approx(badge_slide_clip.custom_minimum_size.x, clamped) and not _badge_box_animating:
		return
	_set_badge_slide_width(clamped, true, closing, fade_icons)
	if _badge_slide_tween != null and _badge_slide_tween.is_valid():
		await _badge_slide_tween.finished


func _play_badge_award_fly(orb: Control, orb_id: String) -> void:
	if _badge_fly_layer == null or orb_id.is_empty():
		return
	var tex: Texture2D = GameData.get_badge_texture(orb_id)
	if tex == null:
		_reveal_earned_badge_icon(orb_id)
		return
	await get_tree().create_timer(BADGE_FLY_PAUSE_BEFORE_SEC).timeout
	if not is_instance_valid(orb):
		_reveal_earned_badge_icon(orb_id)
		return
	await _ensure_badge_box_open_for_award()
	await get_tree().process_frame
	await get_tree().process_frame
	var target_icon: TextureRect = _get_badge_icon(orb_id)
	var target: Vector2 = (
		target_icon.get_global_rect().get_center()
		if target_icon != null
		else badge_box_btn.get_global_rect().get_center()
	)
	var start: Vector2 = orb.get_global_rect().get_center()
	var size: float = BADGE_FLY_SIZE
	var fly := TextureRect.new()
	fly.texture = tex
	fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.custom_minimum_size = Vector2(size, size)
	fly.size = Vector2(size, size)
	fly.pivot_offset = Vector2(size * 0.5, size * 0.5)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_fly_layer.add_child(fly)
	fly.global_position = start - fly.pivot_offset
	fly.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(
		fly, "scale", Vector2(1.12, 1.12), BADGE_FLY_APPEAR_SEC
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		fly, "scale", Vector2.ONE, BADGE_FLY_APPEAR_SEC * 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(BADGE_FLY_HOLD_SEC)
	tween.tween_property(
		fly, "global_position", target - fly.pivot_offset, BADGE_FLY_TRAVEL_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		fly, "scale", Vector2(0.72, 0.72), BADGE_FLY_TRAVEL_SEC
	)
	await tween.finished
	if is_instance_valid(fly):
		fly.queue_free()
	_reveal_earned_badge_icon(orb_id)


func _play_crown_award_fly(source_center: Vector2, crown_index: int) -> void:
	if _badge_fly_layer == null or crown_index <= 0:
		_reveal_earned_crown_icon(crown_index)
		return
	var tex: Texture2D = DiceCrownArt.get_texture(crown_index)
	if tex == null:
		_reveal_earned_crown_icon(crown_index)
		return
	await get_tree().create_timer(BADGE_FLY_PAUSE_BEFORE_SEC).timeout
	await _ensure_badge_box_open_for_award()
	await get_tree().process_frame
	await get_tree().process_frame
	var target_slot: Control = _get_crown_icon(crown_index)
	var target: Vector2 = (
		target_slot.get_global_rect().get_center()
		if target_slot != null
		else badge_box_btn.get_global_rect().get_center()
	)
	var size: float = BADGE_FLY_SIZE
	var fly := TextureRect.new()
	fly.texture = tex
	fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.custom_minimum_size = Vector2(size, size)
	fly.size = Vector2(size, size)
	fly.pivot_offset = Vector2(size * 0.5, size * 0.5)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_fly_layer.add_child(fly)
	fly.global_position = source_center - fly.pivot_offset
	fly.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(
		fly, "scale", Vector2(1.12, 1.12), BADGE_FLY_APPEAR_SEC
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		fly, "scale", Vector2.ONE, BADGE_FLY_APPEAR_SEC * 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(BADGE_FLY_HOLD_SEC)
	tween.tween_property(
		fly, "global_position", target - fly.pivot_offset, BADGE_FLY_TRAVEL_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		fly, "scale", Vector2(0.72, 0.72), BADGE_FLY_TRAVEL_SEC
	)
	await tween.finished
	if is_instance_valid(fly):
		fly.queue_free()
	_reveal_earned_crown_icon(crown_index)


func _reveal_earned_crown_icon(crown_index: int) -> void:
	_crown_fly_reveal_index = 0
	var slot: Control = _get_crown_icon(crown_index)
	var icon: TextureRect = _crown_slot_icon(slot)
	if slot == null or icon == null:
		_refresh_badges()
		return
	slot.set_meta("crown_earned", true)
	icon.modulate = Color.WHITE
	_play_badge_arrival_pop(icon)
	_play_badge_award_ding()


func _reveal_earned_badge_icon(orb_id: String) -> void:
	_badge_fly_reveal_orb_id = ""
	GameState.pending_badge_award_fly = false
	var icon: TextureRect = _get_badge_icon(orb_id)
	if icon == null:
		_refresh_badges()
		return
	icon.set_meta("badge_earned", true)
	icon.modulate = Color.WHITE
	_play_badge_arrival_pop(icon)
	_play_badge_award_ding()


func _play_badge_arrival_pop(icon: TextureRect) -> void:
	if icon == null:
		return
	icon.modulate = Color.WHITE
	icon.scale = Vector2(0.55, 0.55)
	var tween: Tween = create_tween()
	tween.tween_property(
		icon,
		"scale",
		Vector2.ONE,
		BADGE_ARRIVAL_POP_SEC
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_menu_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(AudioSettings.get_master_volume_linear())
	player.bus = "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_badge_award_ding() -> void:
	_play_menu_sfx(BADGE_AWARD_SFX)


func _play_orb_completion_sfx() -> void:
	_play_menu_sfx(ORB_COMPLETION_SFX)


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
	_hide_champion_dialogue()
	_ensure_celebration_backdrop()
	_celebration_backdrop.visible = true
	celebration.visible = true
	celebration.z_index = 50
	celebration.mouse_filter = Control.MOUSE_FILTER_STOP
	if celebration_label != null:
		celebration_label.text = "You are a Dice Master!"
	if celebration_detail != null:
		var opponents: Array = GameState.pending_champion_opponents
		celebration_detail.text = DiceCrownArt.format_opponents_line(opponents)
	_crown_fly_reveal_index = GameState.pending_champion_crown_index
	_refresh_champion_crown_art()
	_refresh_badges()
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
	var crown_idx: int = GameState.pending_champion_crown_index
	var fly_center: Vector2 = Vector2.ZERO
	var should_fly: bool = (
		crown_idx > 0
		and celebration_icon != null
		and is_instance_valid(celebration_icon)
	)
	if should_fly:
		fly_center = celebration_icon.get_global_rect().get_center()
	GameState.show_champion_celebration = false
	GameState.pending_champion_first_crown = false
	GameState.pending_champion_opponents = []
	GameState.pending_champion_crown_index = 1
	_hide_champion_dialogue()
	_hide_champion_celebration()
	if should_fly:
		if _crown_fly_reveal_index <= 0:
			_crown_fly_reveal_index = crown_idx
			_refresh_badges()
		await _play_crown_award_fly(fly_center, crown_idx)
	_refresh_champion_crown_art()
	_refresh_badges()


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
