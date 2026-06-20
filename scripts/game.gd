extends Control

const DIE_CELL := preload("res://scenes/die_cell.tscn")
const POWER_DIE_BUTTON: PackedScene = preload("res://scenes/power_die_button.tscn")
const GYM_BACKGROUND_SHADER: Shader = preload("res://assets/shaders/gym_background.gdshader")

@onready var grid_container: GridContainer = %Grid
@onready var level_label: Label = %LevelLabel
@onready var hearts_icon: TextureRect = %HeartIcon
@onready var hearts_count: Label = %HeartsCount
@onready var switches_label: Label = %SwitchesLabel
@onready var rerolls_label: Label = %RerollsLabel
@onready var gym_label: Label = %GymLabel
@onready var gym_title_wrap: VBoxContainer = %GymTitleWrap
@onready var gym_title_underline: ColorRect = %GymTitleUnderline
@onready var board_column: VBoxContainer = %BoardColumn
@onready var stats_bar: PanelContainer = %StatsBar
@onready var grid_board: Control = %GridBoard
@onready var board_backdrop: NinePatchRect = %BoardBackdrop
@onready var board_margin: MarginContainer = %BoardMargin
@onready var power_dock: Control = %PowerDock
@onready var power_bar: HBoxContainer = %PowerBar
@onready var power_hint: VBoxContainer = %PowerHint
@onready var power_hint_label: Label = %PowerHintLabel
@onready var cancel_power_btn: Button = %CancelPowerBtn
@onready var background: ColorRect = $Background

const ACTIVATABLE_POWERS: Array[String] = [
	"chooseNumber", "switchAnywhere", "setAnyNumber", "switchRows"
]
@onready var safari_overlay: Label = %SafariOverlay
@onready var modal_round: Control = %ModalRound
@onready var modal_level_up: Control = %ModalLevelUp
@onready var level_up_backdrop: ColorRect = %LevelUpBackdrop
@onready var level_up_card: DraggablePanel = %LevelUpCard
@onready var level_up_peek_outline: LevelUpPeekOutline = %LevelUpPeekOutline
@onready var modal_number: Control = %ModalNumber
@onready var modal_victory: Control = %ModalVictory
@onready var victory_badge: TextureRect = %VictoryBadge
@onready var modal_game_over: Control = %ModalGameOver
@onready var modal_stuck: Control = %ModalStuck
@onready var modal_round_icon: TextureRect = %RoundIcon
@onready var round_label: Label = %RoundLabel
@onready var round_detail: Label = %RoundDetail
@onready var round_continue: Button = %RoundContinue
@onready var modal_game_over_icon: TextureRect = %GameOverIcon
@onready var modal_stuck_icon: TextureRect = %StuckIcon
@onready var modal_tournament_win: Control = %ModalTournamentWin
@onready var modal_tournament_win_icon: TextureRect = %TournamentWinIcon
@onready var tournament_win_label: Label = %TournamentWinLabel
@onready var tournament_win_detail: Label = %TournamentWinDetail
@onready var tournament_win_continue: Button = %TournamentWinContinue
@onready var modal_swap: Control = %ModalSwap
@onready var level_up_options: VBoxContainer = %LevelUpOptions
@onready var level_up_detail: Label = %LevelUpDetail
@onready var level_up_keep_powers: Button = %LevelUpKeepPowers

const LEVEL_UP_DETAIL_HINT := "Hover a power to see what it does"
@onready var number_buttons: HBoxContainer = %NumberButtons
@onready var swap_options: VBoxContainer = %SwapOptions
@onready var swap_in_label: Label = %SwapInLabel
@onready var swap_in_detail: Label = %SwapInDetail
@onready var stuck_title: Label = %StuckTitle
@onready var stuck_body: Label = %StuckBody
@onready var stuck_hearts: Label = %StuckHearts
@onready var game_over_title: Label = %GameOverTitle
@onready var game_over_body: Label = %GameOverBody
@onready var restart_btn: Button = %RestartBtn
@onready var modal_restart_confirm: Control = %ModalRestartConfirm
@onready var restart_title: Label = %RestartTitle
@onready var restart_body: Label = %RestartBody
@onready var restart_hearts: Label = %RestartHearts

var session: RunSession
var _last_click_time: int = 0
var _last_click_cell: Vector2i = Vector2i(-1, -1)
var _click_timer: Timer
var _safari_timer: Timer
var _pending_click: Vector2i = Vector2i(-1, -1)
var _dev_panel: DevCheatsPanel
var _dev_toggle_btn: Button
var _dice_roll_player: AudioStreamPlayer
var _dice_swish_player: AudioStreamPlayer
var _die_cells: Dictionary = {}
var _swap_animating: Dictionary = {}
var _row_lock_animating: Dictionary = {}
var _reroll_animating: Dictionary = {}
const SINGLE_CLICK_DELAY_SEC := 0.12
const DOUBLE_CLICK_MS := 350

const REF_BOARD_SIZE := 501.0
const REF_POWERUP_DIE := 58.0
const REF_POWER_NAME_H := 22.0
const POWER_CHIP_SCALE := 1.4
const REF_DIE_CELL := 87.0
const ROW_LOCK_DIE_STAGGER_SEC := 0.075
const POWER_FLY_APPEAR_SEC := 0.22
const POWER_FLY_HOLD_SEC := 0.12
const POWER_FLY_TRAVEL_SEC := 0.48
const POWER_FLY_STAGGER_SEC := 0.14

const DICE_SHUTTER_SFX: AudioStream = preload("res://assets/sfx/dice_shutter.mp3")
const DICE_COMPLETE_DING_SFX: AudioStream = preload("res://assets/sfx/dice_complete_ding.mp3")
const REF_GRID_SEP := 6.0
const REF_BOARD_INSET := 21.0
const REF_POWER_BAR_SEP := 10.0
const REF_POWER_DOCK_PAD := 6.0

var _board_size: float = REF_BOARD_SIZE
var _power_chip_size: int = int(REF_POWERUP_DIE * POWER_CHIP_SCALE)
var _power_bubble_track: String = ""
var _background_material: ShaderMaterial
var _gym_title_hovered: bool = false
var _level_up_modal_was_open: bool = false
var _level_up_eye_cursor_active: bool = false
var _eye_cursor: ImageTexture

enum LevelUpView { FULL, PEEK }
var _level_up_view: LevelUpView = LevelUpView.FULL

const GYM_TITLE_COLOR := Color(0.12, 0.16, 0.24, 1)
const GYM_TITLE_UNDERLINE_H := 2.0
const GYM_TITLE_UNDERLINE_HOVER_H := 3.0

const STATS_BAR_WHITE_BG := Color(0.96, 0.97, 0.99, 1)
const STATS_BAR_WHITE_BORDER := Color(0.84, 0.87, 0.92, 1)
const STATS_BAR_GOLD_BG := Color(0.99, 0.91, 0.55, 1)
const STATS_BAR_GOLD_BORDER := Color(0.85, 0.72, 0.28, 1)
const STATS_BAR_GOLD_SHINE := Color(1.12, 1.05, 0.82, 1)
const STAT_BLINK_CYCLES := 3
const STAT_BLINK_ON_SEC := 0.07
const STAT_BLINK_OFF_SEC := 0.07
const STAT_REVEAL_GAP_SEC := 0.12

var _stats_bar_style: StyleBoxFlat
var _stats_bar_tween: Tween
var _stats_bar_is_golden: bool = false
var _last_stats_level: int = 0
var _stats_reveal_tween: Tween
var _stats_reveal_active: bool = false
var _power_fly_layer: Control
var _power_fly_queue: Array = []
var _power_fly_display: Dictionary = {}


func _ready() -> void:
	DebugLog.alea_log("Game", "========== GAME _ready ==========")
	DebugLog.alea_log(
		"Game",
		"selected_gym=%s championship=%s opponents=%d grid_node=%s"
		% [
			GameState.selected_gym_id,
			GameState.championship_active,
			GameState.tournament_opponents.size(),
			"OK" if grid_container != null else "MISSING",
		]
	)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_layout_boards")
	if cancel_power_btn:
		cancel_power_btn.pressed.connect(_on_cancel_power_pressed)
	else:
		push_error("Game: %CancelPowerBtn missing — fix PowerHint children in game.tscn")
	_click_timer = Timer.new()
	_click_timer.one_shot = true
	_click_timer.wait_time = SINGLE_CLICK_DELAY_SEC
	_click_timer.timeout.connect(_on_single_click_timeout)
	add_child(_click_timer)
	_safari_timer = Timer.new()
	_safari_timer.one_shot = false
	_safari_timer.wait_time = 1.0
	_safari_timer.timeout.connect(_on_safari_tick)
	add_child(_safari_timer)
	for n in range(1, 7):
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(48, 48)
		var num := n
		b.pressed.connect(func(): _on_number_picked(num))
		number_buttons.add_child(b)
	session = RunSession.new()
	session.state_changed.connect(_refresh_ui)
	session.dice_rerolled.connect(_on_dice_rerolled)
	session.dice_swished.connect(_on_dice_swished)
	session.rows_locked.connect(_on_rows_locked)
	session.power_rewarded.connect(_on_power_rewarded)
	if not DiceSprites.style_changed.is_connected(_on_dice_style_changed):
		DiceSprites.style_changed.connect(_on_dice_style_changed)
	_setup_dice_roll_sfx()
	_setup_dice_swish_sfx()
	_setup_power_fly_layer()
	_setup_gym_background()
	_setup_gym_title_hover()
	_setup_level_up_peek()
	_setup_pixel_icons()
	_setup_stats_bar_style()
	if not DevCheats.unlock_state_changed.is_connected(_on_dev_cheats_unlock_changed):
		DevCheats.unlock_state_changed.connect(_on_dev_cheats_unlock_changed)
	_setup_dev_cheats()
	set_process(false)
	call_deferred("_begin_run")


func _begin_run() -> void:
	_row_lock_animating.clear()
	_reroll_animating.clear()
	_cancel_stats_reveal()
	_last_stats_level = 0
	_clear_power_fly_state()
	if grid_container == null:
		push_error("Game: %Grid node missing — cannot start run")
		return
	if GameState.is_championship_run():
		_start_tournament_match()
	else:
		var gym_id := GameState.selected_gym_id
		if gym_id.is_empty():
			gym_id = "vanilla"
		session.start_gym_run(gym_id)
	_refresh_ui()
	if session.grid.is_empty():
		push_error("Game: run started with an empty grid (check GameData / level_limits.json)")
	elif grid_container.get_child_count() == 0:
		_sync_grid()
	DebugLog.alea_log(
		"Game",
		"run started gym=%s level=%d grid=%dx%d ui_cells=%d"
		% [
			session.gym_id,
			session.level,
			session.grid.size(),
			session.grid[0].size() if session.grid.size() > 0 else 0,
			grid_container.get_child_count(),
		]
	)


func _setup_pixel_icons() -> void:
	PixelIconArt.apply_texture_rect(hearts_icon, "heart", 18)
	PixelIconArt.apply_texture_rect(modal_round_icon, "celebrate", 40)
	PixelIconArt.apply_texture_rect(modal_game_over_icon, "broken_heart", 40)
	PixelIconArt.apply_texture_rect(modal_stuck_icon, "dizzy", 40)
	PixelIconArt.apply_texture_rect(modal_tournament_win_icon, "swords", 40)


func _setup_dev_cheats() -> void:
	if not DevCheats.is_active():
		_teardown_dev_cheats()
		return
	if _dev_panel != null:
		return
	_dev_panel = DevCheatsPanel.new()
	add_child(_dev_panel)
	_dev_panel.setup(session)
	_dev_panel.visible = not DevCheats.menu_minimized
	_dev_toggle_btn = Button.new()
	_dev_toggle_btn.icon = PixelIconArt.get_icon("wrench")
	_dev_toggle_btn.text = ""
	_dev_toggle_btn.expand_icon = true
	_dev_toggle_btn.custom_minimum_size = Vector2(36, 36)
	_dev_toggle_btn.tooltip_text = "Dev cheats"
	_dev_toggle_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_dev_toggle_btn.offset_left = -44.0
	_dev_toggle_btn.offset_right = -8.0
	_dev_toggle_btn.offset_top = -28.0
	_dev_toggle_btn.offset_bottom = 4.0
	_dev_toggle_btn.pressed.connect(_on_dev_toggle_pressed)
	add_child(_dev_toggle_btn)
	if _dev_panel.visible:
		_dev_toggle_btn.visible = false


func _on_dev_cheats_unlock_changed(is_unlocked: bool) -> void:
	if is_unlocked:
		_setup_dev_cheats()
	else:
		_teardown_dev_cheats()


func _teardown_dev_cheats() -> void:
	if _dev_panel != null:
		_dev_panel.queue_free()
		_dev_panel = null
	if _dev_toggle_btn != null:
		_dev_toggle_btn.queue_free()
		_dev_toggle_btn = null


func _on_dev_toggle_pressed() -> void:
	if _dev_panel == null:
		return
	_dev_panel.visible = true
	_dev_toggle_btn.visible = false
	DevCheats.menu_minimized = false


func _on_dev_panel_minimized() -> void:
	if _dev_toggle_btn:
		_dev_toggle_btn.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not DevCheats.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if DevCheats.feed_typed_key(key.unicode):
			get_viewport().set_input_as_handled()


func _start_tournament_match() -> void:
	var opp_id: String = GameState.tournament_opponents[GameState.tournament_opponent_index]
	session.start_tournament_match(
		opp_id,
		GameState.tournament_loadout,
		"",
		_on_tournament_match_won
	)


func _on_tournament_match_won() -> void:
	var idx: int = GameState.tournament_opponent_index + 1
	if idx >= GameState.tournament_opponents.size():
		SaveService.award_dice_champion()
		GameState.show_champion_celebration = true
		GameState.reset_tournament()
		SceneNav.go_to_main_menu()
		return
	GameState.tournament_opponent_index = idx
	_start_tournament_match()
	_refresh_ui()


func _refresh_ui() -> void:
	if session.is_tournament:
		var opp: Dictionary = GameData.get_tournament_opponent(session.tournament_opponent_id)
		var match_no: int = GameState.tournament_opponent_index + 1
		gym_label.text = "Dice Master Test · Game %d/3 · %s" % [
			match_no,
			opp.get("name", "Opponent"),
		]
		gym_title_wrap.tooltip_text = str(opp.get("description", ""))
	else:
		var gym: Dictionary = GameData.get_gym(session.gym_id)
		gym_label.text = str(gym.get("name", "Alea"))
		var subtitle: String = str(gym.get("subtitle", ""))
		var description: String = str(gym.get("description", ""))
		if subtitle.is_empty():
			gym_title_wrap.tooltip_text = description
		else:
			gym_title_wrap.tooltip_text = "%s\n\n%s" % [subtitle, description]
	call_deferred("_layout_gym_title_underline")
	if background:
		_update_gym_background_color()
	_refresh_stats_labels()
	_update_stats_bar_theme()
	hearts_count.text = str(session.hearts)
	safari_overlay.visible = session.safari_countdown > 0
	if session.safari_countdown > 0:
		safari_overlay.text = str(session.safari_countdown)
		if not _safari_timer.is_stopped():
			pass
		elif session.safari_countdown > 0:
			_safari_timer.start()
	else:
		_safari_timer.stop()
	_sync_grid()
	_build_power_bar()
	_update_power_hint()
	_update_modals()
	if _dev_panel != null:
		_dev_panel.refresh_for_session()


func _die_key(row: int, col: int) -> String:
	return "%d,%d" % [row, col]


func _clear_die_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	_die_cells.clear()


func _sync_grid() -> void:
	if session.grid.is_empty():
		return
	var rows: int = session.grid.size()
	var cols: int = session.grid[0].size()
	if _die_cells.is_empty():
		for r in range(rows):
			for c in range(cols):
				var btn: DieCell = DIE_CELL.instantiate() as DieCell
				var die_px: int = int(round(REF_DIE_CELL * (_board_size / REF_BOARD_SIZE)))
				btn.custom_minimum_size = Vector2(die_px, die_px)
				grid_container.add_child(btn)
				_die_cells[_die_key(r, c)] = btn
				btn.pressed.connect(_on_die_pressed.bind(r, c))
	for r in range(rows):
		for c in range(cols):
			var key: String = _die_key(r, c)
			var cell: DiceCellData = session.grid[r][c]
			var blur_key: String = "%d:%d" % [r, c]
			var blurred: bool = session.blurred_cell_key == blur_key
			var btn: DieCell = _die_cells[key] as DieCell
			var highlight: DieCell.Highlight = _cell_highlight(r, c, cell, blurred)
			if _swap_animating.has(key) or _row_lock_animating.has(key) or _reroll_animating.has(key):
				if btn.grid_row < 0:
					btn.setup(r, c, cell, blurred)
				btn.set_highlight(highlight)
				continue
			btn.setup(r, c, cell, blurred)
			btn.set_highlight(highlight)


func _on_viewport_size_changed() -> void:
	_sync_gym_background_aspect()
	call_deferred("_layout_boards")
	call_deferred("_layout_gym_title_underline")


func _layout_gym_title_underline() -> void:
	if gym_label == null or gym_title_underline == null:
		return
	var text_w: float = gym_label.get_minimum_size().x
	if text_w < 8.0:
		text_w = gym_label.size.x
	gym_title_underline.custom_minimum_size = Vector2(
		maxf(text_w, 8.0),
		GYM_TITLE_UNDERLINE_HOVER_H if _gym_title_hovered else GYM_TITLE_UNDERLINE_H
	)


func _setup_gym_title_hover() -> void:
	if gym_title_wrap == null:
		return
	if not gym_title_wrap.mouse_entered.is_connected(_on_gym_title_mouse_entered):
		gym_title_wrap.mouse_entered.connect(_on_gym_title_mouse_entered)
	if not gym_title_wrap.mouse_exited.is_connected(_on_gym_title_mouse_exited):
		gym_title_wrap.mouse_exited.connect(_on_gym_title_mouse_exited)


func _on_gym_title_mouse_entered() -> void:
	_set_gym_title_highlight(true)


func _on_gym_title_mouse_exited() -> void:
	_set_gym_title_highlight(false)


func _set_gym_title_highlight(hovering: bool) -> void:
	_gym_title_hovered = hovering
	if gym_label == null:
		return
	if hovering:
		var accent: Color = GameData.get_gym_orb_color(
			session.gym_id if session != null else GameState.selected_gym_id
		)
		gym_label.add_theme_color_override("font_color", accent.darkened(0.12))
		if gym_title_underline != null:
			gym_title_underline.color = accent.darkened(0.08)
	else:
		gym_label.add_theme_color_override("font_color", GYM_TITLE_COLOR)
		if gym_title_underline != null:
			gym_title_underline.color = GYM_TITLE_COLOR
	call_deferred("_layout_gym_title_underline")


func _process(_delta: float) -> void:
	if (
		session == null
		or session.current_modal != RunSession.Modal.LEVEL_UP
		or _level_up_view != LevelUpView.FULL
		or level_up_card == null
	):
		_clear_level_up_eye_cursor()
		return
	var mouse: Vector2 = get_global_mouse_position()
	if level_up_card.get_global_rect().has_point(mouse):
		_clear_level_up_eye_cursor()
	elif _eye_cursor != null:
		Input.set_custom_mouse_cursor(_eye_cursor, Input.CURSOR_ARROW, Vector2(12, 12))
		_level_up_eye_cursor_active = true


func _setup_level_up_peek() -> void:
	_eye_cursor = _create_eye_cursor_texture()
	if level_up_backdrop != null:
		if not level_up_backdrop.gui_input.is_connected(_on_level_up_backdrop_gui_input):
			level_up_backdrop.gui_input.connect(_on_level_up_backdrop_gui_input)
	if level_up_peek_outline != null:
		if not level_up_peek_outline.restore_requested.is_connected(_on_level_up_peek_restore):
			level_up_peek_outline.restore_requested.connect(_on_level_up_peek_restore)


func _on_level_up_backdrop_gui_input(event: InputEvent) -> void:
	if _level_up_view != LevelUpView.FULL:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_level_up_minimize_to_peek()


func _on_level_up_peek_restore() -> void:
	_level_up_restore_full()
	set_process(true)


func _level_up_minimize_to_peek() -> void:
	if level_up_card == null or level_up_peek_outline == null:
		return
	var card_rect: Rect2 = level_up_card.get_rect()
	level_up_peek_outline.position = card_rect.position
	level_up_peek_outline.size = card_rect.size
	level_up_peek_outline.visible = true
	level_up_peek_outline.queue_redraw()
	level_up_card.visible = false
	if level_up_backdrop != null:
		level_up_backdrop.visible = false
	modal_level_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_up_view = LevelUpView.PEEK
	_clear_level_up_eye_cursor()
	set_process(false)


func _level_up_restore_full() -> void:
	_level_up_view = LevelUpView.FULL
	if level_up_card != null:
		level_up_card.visible = true
	if level_up_backdrop != null:
		level_up_backdrop.visible = true
	if level_up_peek_outline != null:
		level_up_peek_outline.visible = false
	if modal_level_up != null:
		modal_level_up.mouse_filter = Control.MOUSE_FILTER_STOP


func _clear_level_up_eye_cursor() -> void:
	if not _level_up_eye_cursor_active:
		return
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_level_up_eye_cursor_active = false


func _create_eye_cursor_texture() -> ImageTexture:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if dist >= 7.0 and dist <= 9.0:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.95))
			elif dist <= 3.2:
				img.set_pixel(x, y, Color(0.12, 0.16, 0.24, 1.0))
	return ImageTexture.create_from_image(img)


func _layout_boards() -> void:
	_board_size = _compute_board_size()
	var layout_scale: float = _board_size / REF_BOARD_SIZE
	var board_px: int = int(round(_board_size))
	var die_cell: int = int(round(REF_DIE_CELL * layout_scale))
	var grid_sep: int = maxi(2, int(round(REF_GRID_SEP * layout_scale)))
	var board_inset: int = maxi(8, int(round(REF_BOARD_INSET * layout_scale)))
	var power_bar_sep: int = maxi(4, int(round(REF_POWER_BAR_SEP * layout_scale)))
	var dock_pad: int = maxi(4, int(round(REF_POWER_DOCK_PAD * layout_scale)))
	_power_chip_size = maxi(32, int(round(REF_POWERUP_DIE * POWER_CHIP_SCALE * layout_scale)))
	var name_h: int = maxi(18, int(round(_power_chip_size * 0.28)))
	var power_h: int = _power_chip_size + 2 + name_h + dock_pad * 2

	if board_column:
		board_column.custom_minimum_size = Vector2(board_px, 0)
	if stats_bar:
		stats_bar.custom_minimum_size = Vector2(board_px, 0)
	if grid_board:
		grid_board.custom_minimum_size = Vector2(board_px, board_px)
	if board_margin:
		board_margin.add_theme_constant_override("margin_left", board_inset)
		board_margin.add_theme_constant_override("margin_top", board_inset)
		board_margin.add_theme_constant_override("margin_right", board_inset)
		board_margin.add_theme_constant_override("margin_bottom", board_inset)
	if board_backdrop:
		board_backdrop.patch_margin_left = int(round(78.0 * layout_scale))
		board_backdrop.patch_margin_top = int(round(78.0 * layout_scale))
		board_backdrop.patch_margin_right = int(round(78.0 * layout_scale))
		board_backdrop.patch_margin_bottom = int(round(96.0 * layout_scale))
	if grid_container:
		grid_container.add_theme_constant_override("h_separation", grid_sep)
		grid_container.add_theme_constant_override("v_separation", grid_sep)
	if power_dock:
		power_dock.custom_minimum_size = Vector2(board_px, power_h)
	if power_bar:
		power_bar.add_theme_constant_override("separation", power_bar_sep)

	_apply_die_cell_sizes(die_cell)
	_apply_power_chip_sizes()


func _compute_board_size() -> float:
	var vp_h: float = get_viewport_rect().size.y
	var chrome_h: float = 24.0 + 44.0 + 8.0 + 40.0 + 6.0 + 6.0
	var power_chrome: float = (
		REF_POWERUP_DIE * POWER_CHIP_SCALE
		+ REF_POWER_NAME_H
		+ REF_POWER_DOCK_PAD * 2.0
		+ 14.0
	)
	var available: float = vp_h - chrome_h - power_chrome
	if available <= 0.0:
		return REF_BOARD_SIZE
	return floor(min(REF_BOARD_SIZE, max(280.0, available)))


func _apply_die_cell_sizes(die_cell: int = -1) -> void:
	var size_px: int = die_cell if die_cell > 0 else int(round(REF_DIE_CELL * (_board_size / REF_BOARD_SIZE)))
	for btn in _die_cells.values():
		if btn is Control:
			(btn as Control).custom_minimum_size = Vector2(size_px, size_px)


func _apply_power_chip_sizes() -> void:
	if power_bar == null:
		return
	for child in power_bar.get_children():
		if child is PowerDieButton:
			(child as PowerDieButton).set_chip_size(_power_chip_size)


func _add_power_die_chip(
	power_type: String,
	power_name: String,
	charge_text: String,
	tooltip: String,
	description_text: String,
	is_active: bool,
	is_unusable: bool,
	on_pressed: Callable = Callable(),
	active_hint: String = "",
	bubble_accent: Color = Color(0.2, 0.35, 0.55),
	bubble_animate: bool = true
) -> void:
	var chip: PowerDieButton = POWER_DIE_BUTTON.instantiate() as PowerDieButton
	chip.set_chip_size(_power_chip_size)
	chip.setup_display(power_type, power_name, charge_text, is_active, is_unusable)
	chip.configure_messages(description_text, active_hint, bubble_accent)
	chip.set_active_state(is_active, bubble_animate)
	chip.tooltip_text = tooltip
	if on_pressed.is_valid():
		chip.pressed.connect(on_pressed)
	power_bar.add_child(chip)
	_apply_power_fly_display_state(chip, power_type)


func _apply_power_fly_display_state(chip: PowerDieButton, power_type: String) -> void:
	if not _power_fly_display.has(power_type):
		return
	var state: Dictionary = _power_fly_display[power_type]
	if state.get("is_new", false):
		chip.set_fly_reveal_pending(true)


func _get_power_chip(power_type: String) -> PowerDieButton:
	if power_bar == null:
		return null
	for child in power_bar.get_children():
		if child is PowerDieButton and (child as PowerDieButton).power_type == power_type:
			return child as PowerDieButton
	return null


func _pulse_power_info(power_type: String) -> void:
	var chip: PowerDieButton = _get_power_chip(power_type)
	if chip:
		chip.pulse_info_bubble()


func _setup_power_fly_layer() -> void:
	_power_fly_layer = Control.new()
	_power_fly_layer.name = "PowerFlyLayer"
	_power_fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_power_fly_layer.anchor_right = 1.0
	_power_fly_layer.anchor_bottom = 1.0
	_power_fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_fly_layer.z_index = 50
	add_child(_power_fly_layer)


func _clear_power_fly_state() -> void:
	_power_fly_queue.clear()
	_power_fly_display.clear()
	if _power_fly_layer != null:
		for child in _power_fly_layer.get_children():
			child.queue_free()


func _on_power_rewarded(
	power_type: String,
	source_row: int,
	previous_charge: int,
	is_new_unlock: bool
) -> void:
	_power_fly_queue.append({
		"power_type": power_type,
		"source_row": source_row,
		"previous_charge": previous_charge,
		"is_new_unlock": is_new_unlock,
	})
	var display_state: Dictionary = {}
	if is_new_unlock:
		display_state["is_new"] = true
	elif PowerLogic.is_pattern_power(power_type) or power_type == "switchRows":
		display_state["charge_override"] = previous_charge
	_power_fly_display[power_type] = display_state


func _start_power_fly_animations() -> void:
	if _power_fly_queue.is_empty():
		return
	var batch: Array = _power_fly_queue.duplicate()
	_power_fly_queue.clear()
	for i in range(batch.size()):
		var item: Dictionary = batch[i]
		var delay: float = float(i) * POWER_FLY_STAGGER_SEC
		var tree: SceneTree = get_tree()
		if tree == null:
			_play_one_power_fly(item)
			continue
		tree.create_timer(delay).timeout.connect(_play_one_power_fly.bind(item))


func _play_one_power_fly(item: Dictionary) -> void:
	var power_type: String = str(item.get("power_type", ""))
	if power_type.is_empty() or _power_fly_layer == null:
		_finish_power_fly(power_type)
		return
	var tex: Texture2D = PowerDiceArt.get_texture(power_type)
	if tex == null:
		_finish_power_fly(power_type)
		return
	var size: float = float(_power_chip_size)
	var start: Vector2 = (
		_row_global_center(int(item.get("source_row", -1)))
		if int(item.get("source_row", -1)) >= 0
		else _grid_board_center()
	)
	var chip: PowerDieButton = _get_power_chip(power_type)
	var target: Vector2 = chip.get_die_global_center() if chip != null else _power_dock_center()
	var fly := TextureRect.new()
	fly.texture = tex
	fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.custom_minimum_size = Vector2(size, size)
	fly.size = Vector2(size, size)
	fly.pivot_offset = Vector2(size * 0.5, size * 0.5)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_fly_layer.add_child(fly)
	fly.global_position = start - fly.pivot_offset
	fly.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(
		fly, "scale", Vector2(1.12, 1.12), POWER_FLY_APPEAR_SEC
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		fly, "scale", Vector2.ONE, POWER_FLY_APPEAR_SEC * 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(POWER_FLY_HOLD_SEC)
	tween.tween_property(
		fly, "global_position", target - fly.pivot_offset, POWER_FLY_TRAVEL_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		fly, "scale", Vector2(0.72, 0.72), POWER_FLY_TRAVEL_SEC
	)
	tween.tween_callback(func() -> void:
		fly.queue_free()
		_finish_power_fly(power_type)
	)


func _finish_power_fly(power_type: String) -> void:
	_power_fly_display.erase(power_type)
	var chip: PowerDieButton = _get_power_chip(power_type)
	if chip == null or session == null:
		return
	var def: Dictionary = GameData.get_power_def(power_type)
	var ch: int = session.power_charges.get(power_type, 0)
	var power_name: String = str(def.get("label", power_type))
	var charge_txt: String = ""
	if PowerLogic.is_pattern_power(power_type) or power_type == "switchRows":
		charge_txt = "×%d" % ch
	var active: bool = session.active_power_type == power_type
	var usable: bool = _power_can_use(power_type) or active
	chip.set_fly_reveal_pending(false)
	chip.setup_display(
		power_type,
		power_name,
		charge_txt,
		active,
		not usable
	)
	chip.play_reward_arrival_pop()


func _row_global_center(row: int) -> Vector2:
	if session == null or session.grid.is_empty() or row < 0:
		return _grid_board_center()
	var cols: int = session.grid[0].size()
	var sum := Vector2.ZERO
	var count: int = 0
	for c in range(cols):
		var btn: DieCell = _die_cells.get(_die_key(row, c)) as DieCell
		if btn == null:
			continue
		var rect: Rect2 = btn.get_global_rect()
		sum += rect.position + rect.size * 0.5
		count += 1
	if count == 0:
		return _grid_board_center()
	return sum / float(count)


func _grid_board_center() -> Vector2:
	if grid_board == null:
		return get_viewport_rect().get_center()
	var rect: Rect2 = grid_board.get_global_rect()
	return rect.position + rect.size * 0.5


func _power_dock_center() -> Vector2:
	if power_bar == null:
		return _grid_board_center()
	var rect: Rect2 = power_bar.get_global_rect()
	return rect.position + rect.size * 0.5


func _build_power_bar() -> void:
	var previous_active: String = _power_bubble_track
	for key in _power_fly_display.keys():
		if not session.unlocked_powers.has(key):
			_power_fly_display.erase(key)
	for c in power_bar.get_children():
		c.queue_free()
	for t in session.unlocked_powers:
		var def: Dictionary = GameData.get_power_def(t)
		var ch: int = session.power_charges.get(t, 0)
		if _power_fly_display.has(t) and _power_fly_display[t].has("charge_override"):
			ch = int(_power_fly_display[t].charge_override)
		var power_name: String = str(def.get("label", t))
		var description_text: String = str(def.get("description", ""))
		var tip: String = "%s\n\n%s" % [power_name, description_text]
		var charge_txt: String = ""
		if PowerLogic.is_pattern_power(t) or t == "switchRows":
			charge_txt = "×%d" % ch
		if t == "rerollTrade":
			var can_trade: bool = PowerLogic.can_trade_rerolls(
				session.level, session.switches_used, session.rerolls_used, session.unlocked_powers
			)
			_add_power_die_chip(
				t,
				power_name,
				"",
				tip,
				description_text,
				false,
				not can_trade,
				func() -> void:
					if can_trade:
						session.reroll_trade()
					else:
						_pulse_power_info(t),
				"",
				_power_hint_color(t)
			)
			continue
		if PowerLogic.is_permanent(t):
			_add_power_die_chip(
				t,
				power_name,
				"",
				tip,
				description_text,
				false,
				false,
				Callable(),
				"",
				_power_hint_color(t)
			)
			continue
		if t not in ACTIVATABLE_POWERS:
			continue
		var active: bool = session.active_power_type == t
		var usable: bool = _power_can_use(t) or active
		var hint_text: String = _power_hint_text(t)
		_add_power_die_chip(
			t,
			power_name,
			charge_txt,
			tip,
			description_text,
			active,
			not usable,
			_on_power_pressed.bind(t),
			hint_text,
			_power_hint_color(t),
			active and previous_active != t
		)
	_power_bubble_track = session.active_power_type
	if not _power_fly_queue.is_empty():
		call_deferred("_start_power_fly_animations")


func _on_power_pressed(power_type: String) -> void:
	if power_type not in ACTIVATABLE_POWERS:
		DebugLog.alea_log("Power", "chip ignored (not activatable): %s" % power_type)
		return
	if session.active_power_type == power_type:
		DebugLog.alea_log("Power", "chip toggle off: %s" % power_type)
		_clear_active_power()
	else:
		var can_use: bool = _power_can_use(power_type)
		DebugLog.alea_log(
			"Power",
			"chip pressed type=%s can_use=%s active=%s charges=%s rerolls=%d"
			% [
				power_type,
				can_use,
				session.active_power_type,
				session.power_charges.get(power_type, 0),
				session.rerolls_left(),
			]
		)
		if not can_use:
			_pulse_power_info(power_type)
			return
		session.activate_power(power_type)
	_refresh_ui()


func _on_cancel_power_pressed() -> void:
	DebugLog.alea_log("Power", "cancel pressed active=%s" % session.active_power_type)
	_clear_active_power()
	_refresh_ui()


func _clear_active_power() -> void:
	session.clear_active_power()


func _power_can_use(power_type: String) -> bool:
	if PowerLogic.is_permanent(power_type):
		return false
	if power_type == "setAnyNumber":
		return session.rerolls_left() > 0 and session.power_charges.get(power_type, 0) > 0
	if PowerLogic.is_pattern_power(power_type) or power_type == "switchRows":
		return session.power_charges.get(power_type, 0) > 0
	return true


func _update_power_hint() -> void:
	if power_hint == null or power_hint_label == null:
		return
	var active: String = session.active_power_type
	if active.is_empty() or active not in ACTIVATABLE_POWERS:
		power_hint.visible = false
		return
	power_hint.visible = true
	power_hint_label.text = _power_hint_text(active)
	var hint_color: Color = _power_hint_color(active).lerp(Color(0.95, 0.93, 0.88), 0.35)
	power_hint_label.add_theme_color_override("font_color", hint_color)


func _power_hint_color(power_type: String) -> Color:
	match power_type:
		"switchRows":
			return Color(0.28, 0.28, 0.62)
		"switchAnywhere":
			return Color(0.4, 0.28, 0.58)
		"chooseNumber":
			return Color(0.15, 0.45, 0.28)
		"setAnyNumber":
			return Color(0.75, 0.38, 0.1)
		_:
			return Color(0.2, 0.35, 0.55)


func _power_hint_text(power_type: String) -> String:
	match power_type:
		"switchRows":
			return (
				"Switch Rows — tap a die in the first row, "
				+"then tap a die in another row (completed rows are OK)"
			)
		"switchAnywhere":
			return (
				"Switch — tap one die, then another unlocked die to swap (uses 1 charge)"
			)
		"chooseNumber":
			return (
				"5 of a Kind — tap a die on an incomplete row, then pick 1–6 for the row"
			)
		"setAnyNumber":
			return "Set Any Die — tap any die, then pick 1–6 (uses 1 reroll)"
		_:
			return ""


func _cell_highlight(
	row: int, col: int, cell: DiceCellData, blurred: bool
) -> DieCell.Highlight:
	if blurred:
		return DieCell.Highlight.NONE
	var active: String = session.active_power_type
	if active == "switchRows":
		if session.active_target_row >= 0:
			if row == session.active_target_row:
				return DieCell.Highlight.SWITCH_ROWS_PRIMARY
			return DieCell.Highlight.SWITCH_ROWS_PICKABLE
		return DieCell.Highlight.SWITCH_ROWS_PICKABLE
	if active == "chooseNumber":
		if _row_valid_for_choose_number(row):
			return DieCell.Highlight.POWER_CHOOSE
		return DieCell.Highlight.NONE
	if active == "setAnyNumber":
		return DieCell.Highlight.POWER_SET_ANY
	if active == "switchAnywhere":
		if session.selected_row >= 0:
			if _can_switch_target(row, col):
				return DieCell.Highlight.SWITCH_VALID
			if row == session.selected_row and col == session.selected_col:
				return DieCell.Highlight.SELECTED
			return DieCell.Highlight.NONE
		if not cell.locked:
			return DieCell.Highlight.POWER_SWITCH_ANY
		return DieCell.Highlight.NONE
	if row == session.selected_row and col == session.selected_col:
		return DieCell.Highlight.SELECTED
	if session.selected_row >= 0 and _can_switch_target(row, col):
		return DieCell.Highlight.SWITCH_VALID
	return DieCell.Highlight.NONE


func _row_valid_for_choose_number(row: int) -> bool:
	if session.awarded_rows.has(row):
		return false
	var vals: Array = []
	for c in session.grid[row]:
		vals.append(c.value)
	return PatternCheck.check_pattern(vals) == PatternCheck.INCOMPLETE


func _can_switch_target(row: int, col: int) -> bool:
	if session.selected_row < 0:
		return false
	if session.active_power_type != "switchAnywhere" and session.switches_left() <= 0:
		return false
	if row == session.selected_row and col == session.selected_col:
		return false
	var cell: DiceCellData = session.grid[row][col]
	var sel: DiceCellData = session.grid[session.selected_row][session.selected_col]
	if session.active_power_type == "switchAnywhere":
		if cell.locked or sel.locked:
			return false
		return true
	if cell.locked or sel.locked:
		return false
	var sw_any: bool = false
	var side: bool = session.unlocked_powers.has("switchHorizontal")
	var vjump: bool = session.unlocked_powers.has("verticalJump")
	var adj_v: bool = (
		session.selected_col == col
		and abs(session.selected_row - row) == 1
	)
	var adj_h: bool = (
		session.selected_row == row
		and abs(session.selected_col - col) == 1
	)
	var v_jump: bool = (
		vjump
		and session.selected_col == col
		and PowerLogic.can_vertical_jump(
			session.grid, session.selected_row, row, col
		)
	)
	return adj_v or sw_any or (side and adj_h) or v_jump


func _setup_dice_roll_sfx() -> void:
	_dice_roll_player = AudioStreamPlayer.new()
	_dice_roll_player.stream = AudioSettings.get_dice_roll_stream()
	_dice_roll_player.bus = &"Master"
	add_child(_dice_roll_player)


func _on_dice_rerolled(row: int, col: int, _new_value: int) -> void:
	if _dice_roll_player and _dice_roll_player.stream:
		_dice_roll_player.play()
	_start_reroll_scramble(row, col)


func _start_reroll_scramble(row: int, col: int) -> void:
	var key: String = _die_key(row, col)
	if _swap_animating.has(key) or _row_lock_animating.has(key):
		return
	var btn: DieCell = _die_cells.get(key) as DieCell
	if btn == null:
		return
	var cell: DiceCellData = session.grid[row][col]
	var blur_key: String = "%d:%d" % [row, col]
	var blurred: bool = session.blurred_cell_key == blur_key
	_reroll_animating[key] = true
	btn.play_reroll_scramble(row, col, cell, blurred, func() -> void:
		_reroll_animating.erase(key)
		if btn == null or not is_instance_valid(btn):
			return
		var final_cell: DiceCellData = session.grid[row][col]
		var final_blurred: bool = session.blurred_cell_key == blur_key
		btn.set_highlight(_cell_highlight(row, col, final_cell, final_blurred))
	)


func _setup_dice_swish_sfx() -> void:
	_dice_swish_player = AudioStreamPlayer.new()
	_dice_swish_player.stream = AudioSettings.get_dice_swish_stream()
	_dice_swish_player.bus = &"Master"
	add_child(_dice_swish_player)


func _setup_gym_background() -> void:
	if background == null or GYM_BACKGROUND_SHADER == null:
		return
	_background_material = ShaderMaterial.new()
	_background_material.shader = GYM_BACKGROUND_SHADER
	_background_material.set_shader_parameter("light_strength", 0.82)
	background.material = _background_material
	background.color = Color.WHITE
	_sync_gym_background_aspect()
	if session != null:
		_update_gym_background_color()


func _update_gym_background_color() -> void:
	if session == null:
		return
	var base: Color = GameData.get_gym_background_color(session.gym_id)
	if _background_material != null:
		_background_material.set_shader_parameter("base_color", base)
		_sync_gym_background_aspect()
	else:
		background.color = base


func _sync_gym_background_aspect() -> void:
	if _background_material == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	_background_material.set_shader_parameter(
		"aspect_ratio",
		vp.x / maxf(vp.y, 1.0)
	)


func _on_dice_swished(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	if _dice_swish_player and _dice_swish_player.stream:
		_dice_swish_player.play()
	if from_col < 0:
		_play_row_swap_animation(from_row, to_row)
	else:
		_play_die_swap_animation(
			from_row,
			from_col,
			to_row,
			to_col,
			session.pending_swap_before_from,
			session.pending_swap_before_to
		)
		session.pending_swap_before_from = null
		session.pending_swap_before_to = null


func _on_rows_locked(row_indices: Array) -> void:
	if row_indices.is_empty() or session.grid.is_empty():
		return
	for row in row_indices:
		var row_index: int = int(row)
		for c in range(session.grid[0].size()):
			_row_lock_animating[_die_key(row_index, c)] = true
	call_deferred("_play_row_lock_batch", row_indices, 0)


func _play_row_lock_batch(row_indices: Array, batch_index: int) -> void:
	if batch_index >= row_indices.size():
		return
	var row: int = int(row_indices[batch_index])
	_play_row_lock_sequence(row, func() -> void:
		_play_row_lock_batch(row_indices, batch_index + 1)
	)


func _play_row_lock_sequence(row: int, on_complete: Callable = Callable()) -> void:
	if session.grid.is_empty():
		if on_complete.is_valid():
			on_complete.call()
		return
	var cols: int = session.grid[0].size()
	for c in range(cols):
		var key: String = _die_key(row, c)
		if _reroll_animating.has(key):
			var scramble_btn: DieCell = _die_cells.get(key) as DieCell
			if scramble_btn != null:
				scramble_btn.cancel_reroll_scramble()
			_reroll_animating.erase(key)
		var btn: DieCell = _die_cells.get(key) as DieCell
		if btn == null:
			continue
		var cell: DiceCellData = session.grid[row][c]
		var blur_key: String = "%d:%d" % [row, c]
		var blurred: bool = session.blurred_cell_key == blur_key
		btn.setup(row, c, cell, blurred)
	var tree := get_tree()
	if tree == null:
		if on_complete.is_valid():
			on_complete.call()
		return
	for c in range(cols):
		var col: int = c
		tree.create_timer(col * ROW_LOCK_DIE_STAGGER_SEC).timeout.connect(
			func() -> void:
				var btn: DieCell = _die_cells.get(_die_key(row, col)) as DieCell
				if btn == null:
					return
				_play_one_shot_sfx(DICE_SHUTTER_SFX)
				btn.play_lock_pop(),
			CONNECT_ONE_SHOT
		)
	var ding_delay: float = (
		float(cols - 1) * ROW_LOCK_DIE_STAGGER_SEC + DieCell.LOCK_POP_TOTAL_SEC
	)
	tree.create_timer(ding_delay).timeout.connect(
		func() -> void:
			_play_one_shot_sfx(DICE_COMPLETE_DING_SFX)
			_finish_row_lock_sequence(row)
			if on_complete.is_valid():
				on_complete.call(),
		CONNECT_ONE_SHOT
	)


func _finish_row_lock_sequence(row: int) -> void:
	if session.grid.is_empty():
		return
	for c in range(session.grid[0].size()):
		var key: String = _die_key(row, c)
		_row_lock_animating.erase(key)
		var btn: DieCell = _die_cells.get(key) as DieCell
		if btn == null:
			continue
		var cell: DiceCellData = session.grid[row][c]
		var blur_key: String = "%d:%d" % [row, c]
		var blurred: bool = session.blurred_cell_key == blur_key
		btn.setup(row, c, cell, blurred)
		btn.set_highlight(_cell_highlight(row, c, cell, blurred))


func _play_one_shot_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_die_swap_animation(
	r1: int,
	c1: int,
	r2: int,
	c2: int,
	before_a: DiceCellData = null,
	before_b: DiceCellData = null
) -> void:
	var key_a: String = _die_key(r1, c1)
	var key_b: String = _die_key(r2, c2)
	var btn_a: DieCell = _die_cells.get(key_a) as DieCell
	var btn_b: DieCell = _die_cells.get(key_b) as DieCell
	if btn_a == null or btn_b == null:
		return
	_swap_animating[key_a] = true
	_swap_animating[key_b] = true
	call_deferred(
		"_begin_swap_animation",
		r1,
		c1,
		r2,
		c2,
		before_a,
		before_b
	)


func _begin_swap_animation(
	r1: int,
	c1: int,
	r2: int,
	c2: int,
	before_a: DiceCellData = null,
	before_b: DiceCellData = null
) -> void:
	var key_a: String = _die_key(r1, c1)
	var key_b: String = _die_key(r2, c2)
	var btn_a: DieCell = _die_cells.get(key_a) as DieCell
	var btn_b: DieCell = _die_cells.get(key_b) as DieCell
	if btn_a == null or btn_b == null:
		_swap_animating.erase(key_a)
		_swap_animating.erase(key_b)
		return
	_apply_swap_slide_visuals(r1, c1, r2, c2, before_a, before_b)
	var offset: Vector2 = btn_b.position - btn_a.position
	var duration: float = DieCell.SWAP_SLIDE_DURATION
	var remaining: int = 2
	var on_complete := func() -> void:
		remaining -= 1
		if remaining != 0:
			return
		_finish_swap_animation(r1, c1, r2, c2)
	btn_a.play_swap_to(offset, duration, on_complete)
	btn_b.play_swap_to(-offset, duration, on_complete)
	var tree := get_tree()
	if tree != null:
		tree.create_timer(duration + 0.08).timeout.connect(
			func() -> void:
				_finish_swap_animation(r1, c1, r2, c2),
			CONNECT_ONE_SHOT
		)


func _apply_swap_slide_visuals(
	r1: int,
	c1: int,
	r2: int,
	c2: int,
	before_a: DiceCellData,
	before_b: DiceCellData
) -> void:
	if before_a == null or before_b == null:
		return
	var pairs: Array = [
		[r1, c1, before_a],
		[r2, c2, before_b],
	]
	for entry in pairs:
		var r: int = entry[0]
		var c: int = entry[1]
		var slide_cell: DiceCellData = entry[2]
		var key: String = _die_key(r, c)
		var btn: DieCell = _die_cells.get(key) as DieCell
		if btn == null:
			continue
		var blur_key: String = "%d:%d" % [r, c]
		var blurred: bool = session.blurred_cell_key == blur_key
		btn.clear_swap_overlay()
		btn.setup(r, c, slide_cell, blurred)
		btn.set_highlight(_cell_highlight(r, c, session.grid[r][c], blurred))


func _play_row_swap_animation(row_a: int, row_b: int) -> void:
	if session.grid.is_empty():
		return
	for c in range(session.grid[0].size()):
		var snap: Dictionary = (
			session.pending_row_swap_before[c]
			if c < session.pending_row_swap_before.size()
			else {}
		)
		var before_a: DiceCellData = snap.get("from") as DiceCellData
		var before_b: DiceCellData = snap.get("to") as DiceCellData
		_play_die_swap_animation(row_a, c, row_b, c, before_a, before_b)
	session.pending_row_swap_before.clear()


func _finish_swap_animation(r1: int, c1: int, r2: int, c2: int) -> void:
	var key_a: String = _die_key(r1, c1)
	var key_b: String = _die_key(r2, c2)
	if not _swap_animating.has(key_a) and not _swap_animating.has(key_b):
		return
	_swap_animating.erase(key_a)
	_swap_animating.erase(key_b)
	for coords in [Vector2i(r1, c1), Vector2i(r2, c2)]:
		var r: int = coords.x
		var c: int = coords.y
		var btn: DieCell = _die_cells.get(_die_key(r, c)) as DieCell
		if btn == null:
			continue
		var cell: DiceCellData = session.grid[r][c]
		var blur_key: String = "%d:%d" % [r, c]
		var blurred: bool = session.blurred_cell_key == blur_key
		btn.commit_swap_result(cell, blurred)
		btn.set_highlight(_cell_highlight(r, c, cell, blurred))


func _on_dice_style_changed() -> void:
	_sync_grid()
	_build_power_bar()


func _on_die_pressed(row: int, col: int) -> void:
	if session.safari_countdown > 0:
		DebugLog.alea_log("Power", "die click ignored safari countdown=%d" % session.safari_countdown)
		return
	var now := Time.get_ticks_msec()
	if (
		_last_click_cell == Vector2i(row, col)
		and now - _last_click_time < DOUBLE_CLICK_MS
	):
		_click_timer.stop()
		_last_click_cell = Vector2i(-1, -1)
		var cell: DiceCellData = session.grid[row][col]
		DebugLog.alea_log(
			"Power",
			"die double-click reroll (%d,%d) locked=%s active=%s"
			% [row, col, cell.locked, session.active_power_type]
		)
		if not cell.locked and not cell.no_reroll:
			session.selected_row = -1
			session.selected_col = -1
			session.reroll_die(row, col)
		return
	_last_click_time = now
	_last_click_cell = Vector2i(row, col)
	_pending_click = Vector2i(row, col)
	_click_timer.start()


func _on_single_click_timeout() -> void:
	var p := _pending_click
	_pending_click = Vector2i(-1, -1)
	DebugLog.alea_log(
		"Power",
		"die single-click (%d,%d) active=%s modal=%d"
		% [p.x, p.y, session.active_power_type, session.current_modal]
	)
	session.select_die(p.x, p.y)


func _on_safari_tick() -> void:
	session.tick_safari_countdown()


func _on_number_picked(n: int) -> void:
	DebugLog.alea_log(
		"Power",
		"number picked %d active=%s target=(%d,%d)"
		% [
			n,
			session.active_power_type,
			session.active_target_row,
			session.active_target_col,
		]
	)
	session.apply_number_pick(n)


func _refresh_stats_labels() -> void:
	if session == null or level_label == null or switches_label == null or rerolls_label == null:
		return
	var lim: Dictionary = session.get_limits()
	if (
		not _stats_reveal_active
		and _last_stats_level > 0
		and session.level > _last_stats_level
	):
		_play_level_up_stats_reveal(
			level_label.text,
			switches_label.text,
			rerolls_label.text,
			session.level,
			lim
		)
	elif not _stats_reveal_active:
		_apply_stats_labels(session.level, lim)
		_last_stats_level = session.level


func _apply_stats_labels(lvl: int, lim: Dictionary) -> void:
	level_label.text = "Level %d" % lvl
	switches_label.text = "Switch %d/%d" % [
		session.switches_left(), lim.max_switches
	]
	rerolls_label.text = "Reroll %d/%d" % [
		session.rerolls_left(), lim.max_rerolls
	]


func _play_level_up_stats_reveal(
	old_level_text: String,
	old_switch_text: String,
	old_reroll_text: String,
	new_level: int,
	new_lim: Dictionary
) -> void:
	_cancel_stats_reveal()
	var old_lim: Dictionary = LevelLimits.get_level_limits(_last_stats_level)
	var new_level_text: String = "Level %d" % new_level
	var new_switch_text: String = "Switch %d/%d" % [
		session.switches_left(), new_lim.max_switches
	]
	var new_reroll_text: String = "Reroll %d/%d" % [
		session.rerolls_left(), new_lim.max_rerolls
	]
	level_label.text = old_level_text
	switches_label.text = old_switch_text
	rerolls_label.text = old_reroll_text
	_stats_reveal_active = true
	_stats_reveal_tween = create_tween()
	_tween_stat_blink_and_set(_stats_reveal_tween, level_label, new_level_text)
	_stats_reveal_tween.tween_interval(STAT_REVEAL_GAP_SEC)
	if old_lim.max_switches != new_lim.max_switches:
		_tween_stat_blink_and_set(_stats_reveal_tween, switches_label, new_switch_text)
		_stats_reveal_tween.tween_interval(STAT_REVEAL_GAP_SEC)
	else:
		_stats_reveal_tween.tween_callback(func() -> void:
			switches_label.text = new_switch_text
		)
	if old_lim.max_rerolls != new_lim.max_rerolls:
		_tween_stat_blink_and_set(_stats_reveal_tween, rerolls_label, new_reroll_text)
	else:
		_stats_reveal_tween.tween_callback(func() -> void:
			rerolls_label.text = new_reroll_text
		)
	_stats_reveal_tween.tween_callback(func() -> void:
		_stats_reveal_active = false
		_stats_reveal_tween = null
		_last_stats_level = new_level
	)


func _tween_stat_blink_and_set(tween: Tween, label: Label, new_text: String) -> void:
	label.modulate = Color.WHITE
	for _i in range(STAT_BLINK_CYCLES):
		tween.tween_property(label, "modulate:a", 0.2, STAT_BLINK_ON_SEC)
		tween.tween_property(label, "modulate:a", 1.0, STAT_BLINK_OFF_SEC)
	tween.tween_callback(func() -> void:
		label.text = new_text
		label.modulate = Color.WHITE
	)


func _cancel_stats_reveal() -> void:
	_stats_reveal_active = false
	if _stats_reveal_tween != null and _stats_reveal_tween.is_valid():
		_stats_reveal_tween.kill()
	_stats_reveal_tween = null
	if level_label != null:
		level_label.modulate = Color.WHITE
	if switches_label != null:
		switches_label.modulate = Color.WHITE
	if rerolls_label != null:
		rerolls_label.modulate = Color.WHITE


func _setup_stats_bar_style() -> void:
	if stats_bar == null:
		return
	var base := stats_bar.get_theme_stylebox("panel") as StyleBoxFlat
	if base == null:
		return
	_stats_bar_style = base.duplicate() as StyleBoxFlat
	stats_bar.add_theme_stylebox_override("panel", _stats_bar_style)


func _update_stats_bar_theme() -> void:
	if stats_bar == null or _stats_bar_style == null or session == null:
		return
	if session.is_tournament:
		_reset_stats_bar_white(false)
		return
	var max_lvl: int = int(GameData.level_limits.get("max_level", 8))
	if session.level >= max_lvl:
		_animate_stats_bar_golden()
	elif _stats_bar_is_golden:
		_reset_stats_bar_white(false)


func _reset_stats_bar_white(animate: bool) -> void:
	_stats_bar_is_golden = false
	if _stats_bar_tween != null and _stats_bar_tween.is_valid():
		_stats_bar_tween.kill()
	if animate:
		_stats_bar_tween = create_tween().set_parallel(true)
		_stats_bar_tween.tween_property(
			_stats_bar_style, "bg_color", STATS_BAR_WHITE_BG, 0.4
		)
		_stats_bar_tween.tween_property(
			_stats_bar_style, "border_color", STATS_BAR_WHITE_BORDER, 0.4
		)
	else:
		_stats_bar_style.bg_color = STATS_BAR_WHITE_BG
		_stats_bar_style.border_color = STATS_BAR_WHITE_BORDER
	stats_bar.modulate = Color.WHITE


func _animate_stats_bar_golden() -> void:
	if _stats_bar_is_golden:
		return
	_stats_bar_is_golden = true
	if _stats_bar_tween != null and _stats_bar_tween.is_valid():
		_stats_bar_tween.kill()
	_stats_bar_tween = create_tween().set_parallel(true)
	_stats_bar_tween.tween_property(
		_stats_bar_style, "bg_color", STATS_BAR_GOLD_BG, 0.9
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_stats_bar_tween.tween_property(
		_stats_bar_style, "border_color", STATS_BAR_GOLD_BORDER, 0.9
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	stats_bar.modulate = STATS_BAR_GOLD_SHINE
	var shine := create_tween()
	shine.tween_property(stats_bar, "modulate", Color.WHITE, 0.55).set_delay(0.25)


func _is_final_level_announcement() -> bool:
	if session.is_tournament:
		return false
	var max_lvl: int = int(GameData.level_limits.get("max_level", 8))
	return session.level == max_lvl - 1


func _update_round_modal() -> void:
	if not _is_final_level_announcement():
		round_label.text = "Level complete!"
		round_detail.visible = false
		PixelIconArt.apply_texture_rect(modal_round_icon, "celebrate", 40)
		round_continue.text = "Choose power"
		return
	round_label.text = "Level %d complete!" % session.level
	round_detail.text = (
		"Next is Level %d — the final level. Beat it to earn this gym's badge!"
		% (session.level + 1)
	)
	round_detail.visible = true
	PixelIconArt.apply_texture_rect(modal_round_icon, "crown", 40)
	round_continue.text = "Continue to final level"


func _update_modals() -> void:
	var round_open: bool = session.current_modal == RunSession.Modal.ROUND_COMPLETE
	modal_round.visible = round_open
	if round_open:
		_update_round_modal()
	var level_up_open: bool = session.current_modal == RunSession.Modal.LEVEL_UP
	modal_level_up.visible = level_up_open
	if level_up_open:
		if not _level_up_modal_was_open:
			_level_up_restore_full()
			if level_up_card != null:
				level_up_card.reset_drag_state()
		_build_level_up()
		if not _level_up_modal_was_open and level_up_card != null:
			level_up_card.call_deferred("ensure_centered")
		set_process(_level_up_view == LevelUpView.FULL)
	else:
		_level_up_restore_full()
		_clear_level_up_eye_cursor()
		set_process(false)
	_level_up_modal_was_open = level_up_open
	modal_number.visible = session.current_modal == RunSession.Modal.NUMBER_PICKER
	var show_victory: bool = session.current_modal == RunSession.Modal.GAME_VICTORY
	modal_victory.visible = show_victory
	if show_victory and victory_badge:
		victory_badge.texture = GameData.get_badge_texture(session.gym_id)
		victory_badge.visible = victory_badge.texture != null
	modal_game_over.visible = session.current_modal == RunSession.Modal.GAME_OVER
	modal_stuck.visible = session.current_modal == RunSession.Modal.STUCK
	modal_tournament_win.visible = session.current_modal == RunSession.Modal.TOURNAMENT_WIN
	if session.current_modal == RunSession.Modal.TOURNAMENT_WIN:
		_update_tournament_win_modal()
	modal_swap.visible = session.current_modal == RunSession.Modal.SWAP_POWER
	modal_restart_confirm.visible = (
		session.current_modal == RunSession.Modal.RESTART_CONFIRM
	)
	_update_restart_modal()
	_update_fail_modals()
	restart_btn.disabled = not session.can_offer_restart()
	if session.current_modal == RunSession.Modal.SWAP_POWER:
		_build_swap()


func _update_tournament_win_modal() -> void:
	if tournament_win_label == null or tournament_win_continue == null:
		return
	var is_final_match: bool = (
		session.is_tournament
		and not GameState.tournament_opponents.is_empty()
		and GameState.tournament_opponent_index >= GameState.tournament_opponents.size() - 1
	)
	if is_final_match:
		PixelIconArt.apply_texture_rect(modal_tournament_win_icon, "crown", 40)
		tournament_win_label.text = "You are a Dice Master!"
		if tournament_win_detail != null:
			tournament_win_detail.text = (
				"You won all three games in the Dice Master Test."
			)
		tournament_win_continue.text = "Return to map"
	else:
		PixelIconArt.apply_texture_rect(modal_tournament_win_icon, "swords", 40)
		tournament_win_label.text = "Game won!"
		if tournament_win_detail != null:
			var remaining: int = (
				GameState.tournament_opponents.size()
				- GameState.tournament_opponent_index
				- 1
			)
			tournament_win_detail.text = (
				"%d more game%s to go." % [remaining, "s" if remaining != 1 else ""]
			)
		tournament_win_continue.text = "Continue"


func _build_level_up() -> void:
	for c in level_up_options.get_children():
		c.queue_free()
	level_up_detail.text = LEVEL_UP_DETAIL_HINT
	level_up_keep_powers.visible = true
	level_up_keep_powers.text = "Keep current powers → Level %d" % (session.level + 1)
	for t in session.level_up_pool:
		var def: Dictionary = GameData.get_power_def(t)
		var power_label: String = str(def.get("label", t))
		var power_desc: String = str(def.get("description", ""))
		var earn_label: String = str(def.get("earn_label", ""))
		var b := Button.new()
		b.text = power_label
		if not earn_label.is_empty() and earn_label != "Always on":
			b.tooltip_text = "%s\nEarn: %s\n\n%s" % [power_label, earn_label, power_desc]
		else:
			b.tooltip_text = "%s\n\n%s" % [power_label, power_desc]
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): session.choose_level_up_power(t))
		level_up_options.add_child(b)


func _update_restart_modal() -> void:
	if session.current_modal != RunSession.Modal.RESTART_CONFIRM:
		return
	restart_title.text = "Restart level?"
	var h: int = session.hearts
	if h <= 1:
		restart_body.text = (
			"Restarting this level costs your last heart.\n"
			+"You will fail the gym immediately after."
		)
		restart_hearts.text = "Hearts 1 -> gym failed"
	else:
		restart_body.text = (
			"Restart deals a fresh grid on this level.\n"
			+"Pattern power charges reset to how they were at the start of this level."
		)
		var after: int = h - 1
		var word: String = "heart" if after == 1 else "hearts"
		restart_hearts.text = "Hearts %d -> %d (%d %s left)" % [h, after, after, word]


func _on_restart_pressed() -> void:
	session.request_restart_confirm()


func _on_cancel_restart_pressed() -> void:
	session.cancel_restart_confirm()


func _on_confirm_restart_pressed() -> void:
	session.confirm_restart_level()


func _update_fail_modals() -> void:
	var lim: Dictionary = session.get_limits()
	if session.current_modal == RunSession.Modal.STUCK:
		stuck_title.text = "No moves left"
		stuck_body.text = (
			"You have no valid switches or rerolls left (%d/%d switches, %d/%d rerolls).\n"
			+"Pattern power charges reset when you restart this level."
		) % [
			session.switches_left(),
			int(lim.get("max_switches", 0)),
			session.rerolls_left(),
			int(lim.get("max_rerolls", 0)),
		]
		var h: int = session.hearts
		var heart_word: String = "heart" if h == 1 else "hearts"
		stuck_hearts.text = (
			"Hearts %d %s remaining — tap Restart level to try again (you already lost 1 heart)"
			% [h, heart_word]
		)
	elif session.current_modal == RunSession.Modal.GAME_OVER:
		if session.is_tournament:
			game_over_title.text = "Dice Master Test failed"
			var opp: Dictionary = GameData.get_tournament_opponent(
				session.tournament_opponent_id
			)
			game_over_body.text = (
				"You lost game %d against %s. Return to the menu to try again."
				% [GameState.tournament_opponent_index + 1, opp.get("name", "your opponent")]
			)
		else:
			var gym: Dictionary = GameData.get_gym(session.gym_id)
			var max_hearts: int = int(GameData.level_limits.get("max_hearts", 3))
			game_over_title.text = "Gym failed"
			game_over_body.text = (
				"You ran out of hearts in %s.\n"
				+"You used all %d lives — this gym run is over."
			) % [gym.get("name", "this gym"), max_hearts]


func _build_swap() -> void:
	for c in swap_options.get_children():
		c.queue_free()
	var incoming_id: String = session.pending_swap_in
	var incoming_def: Dictionary = GameData.get_power_def(incoming_id)
	var incoming_label: String = str(incoming_def.get("label", incoming_id))
	swap_in_label.text = "Adding: %s" % incoming_label
	swap_in_detail.text = str(incoming_def.get("description", ""))
	for t in session.unlocked_powers:
		var def: Dictionary = GameData.get_power_def(t)
		var outgoing_label: String = str(def.get("label", t))
		var b := Button.new()
		b.text = "Drop %s → add %s" % [outgoing_label, incoming_label]
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var outgoing_desc: String = str(def.get("description", ""))
		b.tooltip_text = "Remove %s\n\n%s" % [outgoing_label, outgoing_desc]
		b.pressed.connect(func(): session.swap_out_power(t))
		swap_options.add_child(b)


func _on_cancel_swap_pressed() -> void:
	session.cancel_swap_power()


func _on_back_pressed() -> void:
	if GameState.championship_active:
		GameState.reset_tournament()
	SceneNav.go_to_main_menu()


func _on_continue_round_pressed() -> void:
	session.continue_after_round()


func _on_level_up_keep_powers_pressed() -> void:
	session.keep_current_powers_at_level_up()


func _on_retry_pressed() -> void:
	session.retry_level()


func _on_menu_from_over_pressed() -> void:
	if GameState.championship_active:
		GameState.reset_tournament()
	SceneNav.go_to_main_menu()


func _on_endless_pressed() -> void:
	session.start_endless()


func _on_tournament_continue_pressed() -> void:
	session.tournament_match_won()
