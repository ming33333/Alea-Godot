extends Control

const DIE_CELL := preload("res://scenes/die_cell.tscn")
const POWER_DIE_BUTTON: PackedScene = preload("res://scenes/power_die_button.tscn")

@onready var grid_container: GridContainer = %Grid
@onready var level_label: Label = %LevelLabel
@onready var hearts_label: Label = %HeartsLabel
@onready var switches_label: Label = %SwitchesLabel
@onready var rerolls_label: Label = %RerollsLabel
@onready var gym_label: Label = %GymLabel
@onready var grid_board: Control = %GridBoard
@onready var power_dock: PanelContainer = %PowerDock
@onready var power_bar: HBoxContainer = %PowerBar
@onready var power_hint: VBoxContainer = %PowerHint
@onready var power_hint_label: Label = %PowerHintLabel
@onready var cancel_power_btn: Button = %CancelPowerBtn

const ACTIVATABLE_POWERS: Array[String] = [
	"chooseNumber", "switchAnywhere", "setAnyNumber", "switchRows"
]
@onready var safari_overlay: Label = %SafariOverlay
@onready var modal_round: Control = %ModalRound
@onready var modal_level_up: Control = %ModalLevelUp
@onready var modal_number: Control = %ModalNumber
@onready var modal_victory: Control = %ModalVictory
@onready var victory_badge: TextureRect = %VictoryBadge
@onready var modal_game_over: Control = %ModalGameOver
@onready var modal_stuck: Control = %ModalStuck
@onready var modal_tournament_win: Control = %ModalTournamentWin
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
var _die_cells: Dictionary = {}
const SINGLE_CLICK_DELAY_SEC := 0.12
const DOUBLE_CLICK_MS := 350


func _ready() -> void:
	DebugLog.alea_log("Game", "========== GAME _ready ==========")
	DebugLog.alea_log(
		"Game",
		"selected_gym=%s tournament_opponents=%d grid_node=%s"
		% [
			GameState.selected_gym_id,
			GameState.tournament_opponents.size(),
			"OK" if grid_container != null else "MISSING",
		]
	)
	_style_game_boards()
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
	if not DiceSprites.style_changed.is_connected(_on_dice_style_changed):
		DiceSprites.style_changed.connect(_on_dice_style_changed)
	_setup_dice_roll_sfx()
	_setup_dev_cheats()
	call_deferred("_begin_run")


func _begin_run() -> void:
	if grid_container == null:
		push_error("Game: %Grid node missing — cannot start run")
		return
	if GameState.tournament_opponents.size() > 0:
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


func _setup_dev_cheats() -> void:
	if not DevCheats.is_active():
		return
	_dev_panel = DevCheatsPanel.new()
	add_child(_dev_panel)
	_dev_panel.setup(session)
	_dev_panel.visible = not DevCheats.menu_minimized
	_dev_toggle_btn = Button.new()
	_dev_toggle_btn.text = "🔧"
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
	var stolen: String = ""
	if opp_id == "thief" and GameState.tournament_stolen_power.is_empty():
		GameState.tournament_stolen_power = TournamentRules.pick_stolen_power(
			GameState.tournament_loadout
		)
	stolen = GameState.tournament_stolen_power
	session.start_tournament_match(
		opp_id,
		GameState.tournament_loadout,
		stolen,
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
	GameState.tournament_stolen_power = ""
	_start_tournament_match()
	_refresh_ui()


func _refresh_ui() -> void:
	var gym: Dictionary = GameData.get_gym(session.gym_id)
	gym_label.text = gym.get("name", "Alea")
	level_label.text = "Level %d" % session.level
	hearts_label.text = "♥ %d" % session.hearts
	var lim: Dictionary = session.get_limits()
	switches_label.text = "Switch %d/%d" % [
		session.switches_left(), lim.max_switches
	]
	rerolls_label.text = "Reroll %d/%d" % [
		session.rerolls_left(), lim.max_rerolls
	]
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
				grid_container.add_child(btn)
				_die_cells[_die_key(r, c)] = btn
				btn.pressed.connect(_on_die_pressed.bind(r, c))
	for r in range(rows):
		for c in range(cols):
			var cell: DiceCellData = session.grid[r][c]
			var blur_key: String = "%d:%d" % [r, c]
			var blurred: bool = session.blurred_cell_key == blur_key
			var btn: DieCell = _die_cells[_die_key(r, c)] as DieCell
			btn.setup(r, c, cell, blurred)
			btn.set_highlight(_cell_highlight(r, c, cell, blurred))


func _style_game_boards() -> void:
	if power_dock:
		power_dock.add_theme_stylebox_override("panel", _make_board_style(
			Color(0.5, 0.38, 0.26),
			Color(0.32, 0.22, 0.14),
			12
		))


func _make_board_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 4)
	return box


func _power_short_label(power_type: String, def: Dictionary) -> String:
	match power_type:
		"chooseNumber":
			return "5 of\na Kind"
		"switchAnywhere":
			return "Switch"
		"setAnyNumber":
			return "Set\nDie"
		"switchRows":
			return "Switch\nRows"
		"rerollTrade":
			return "Reroll\nTrade"
		"switchHorizontal":
			return "Side\nSwitch"
		"verticalJump":
			return "V.\nJump"
		"secondChances":
			return "2nd\nChance"
		_:
			var raw: String = str(def.get("label", power_type))
			if raw.length() > 10:
				return raw.substr(0, 10)
			return raw


func _power_accent_color(power_type: String) -> Color:
	match power_type:
		"switchRows":
			return Color(0.35, 0.35, 0.82)
		"switchAnywhere":
			return Color(0.5, 0.35, 0.75)
		"chooseNumber":
			return Color(0.2, 0.6, 0.35)
		"setAnyNumber":
			return Color(0.9, 0.45, 0.1)
		"rerollTrade":
			return Color(0.45, 0.55, 0.75)
		_:
			return Color(0.45, 0.48, 0.55)


func _add_power_die_chip(
	title: String,
	charge_text: String,
	tooltip: String,
	is_active: bool,
	is_disabled: bool,
	accent: Color,
	on_pressed: Callable = Callable()
) -> void:
	var chip: PowerDieButton = POWER_DIE_BUTTON.instantiate() as PowerDieButton
	chip.setup_display(title, charge_text, is_active, is_disabled, accent)
	chip.tooltip_text = tooltip
	if on_pressed.is_valid():
		chip.pressed.connect(on_pressed)
	power_bar.add_child(chip)


func _build_power_bar() -> void:
	for c in power_bar.get_children():
		c.queue_free()
	for t in session.unlocked_powers:
		var def: Dictionary = GameData.get_power_def(t)
		var ch: int = session.power_charges.get(t, 0)
		var short: String = _power_short_label(t, def)
		var tip: String = str(def.get("description", ""))
		var charge_txt: String = ""
		if PowerLogic.is_pattern_power(t) or t == "switchRows":
			charge_txt = "×%d" % ch
		if t == "rerollTrade":
			var can_trade: bool = PowerLogic.can_trade_rerolls(
				session.level, session.switches_used, session.rerolls_used, session.unlocked_powers
			)
			_add_power_die_chip(
				short,
				"",
				tip,
				false,
				not can_trade,
				_power_accent_color(t),
				func(): session.reroll_trade()
			)
			continue
		if PowerLogic.is_permanent(t):
			_add_power_die_chip(short, "", tip, false, true, _power_accent_color(t))
			continue
		if t not in ACTIVATABLE_POWERS:
			continue
		var active: bool = session.active_power_type == t
		var usable: bool = _power_can_use(t) or active
		_add_power_die_chip(
			short,
			charge_txt,
			tip,
			active,
			not usable,
			_power_accent_color(t),
			_on_power_pressed.bind(t)
		)


func _on_power_pressed(power_type: String) -> void:
	if power_type not in ACTIVATABLE_POWERS:
		return
	if session.active_power_type == power_type:
		_clear_active_power()
	else:
		if not _power_can_use(power_type):
			return
		session.activate_power(power_type)
	_refresh_ui()


func _on_cancel_power_pressed() -> void:
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
	row: int, col: int, _cell: DiceCellData, blurred: bool
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
		return DieCell.Highlight.POWER_SWITCH_ANY
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


func _on_dice_rerolled(_row: int, _col: int, _new_value: int) -> void:
	if _dice_roll_player and _dice_roll_player.stream:
		_dice_roll_player.play()


func _on_dice_style_changed() -> void:
	_sync_grid()


func _on_die_pressed(row: int, col: int) -> void:
	if session.safari_countdown > 0:
		return
	var now := Time.get_ticks_msec()
	if (
		_last_click_cell == Vector2i(row, col)
		and now - _last_click_time < DOUBLE_CLICK_MS
	):
		_click_timer.stop()
		_last_click_cell = Vector2i(-1, -1)
		var cell: DiceCellData = session.grid[row][col]
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
	session.select_die(p.x, p.y)


func _on_safari_tick() -> void:
	session.tick_safari_countdown()


func _on_number_picked(n: int) -> void:
	session.apply_number_pick(n)


func _update_modals() -> void:
	modal_round.visible = session.current_modal == RunSession.Modal.ROUND_COMPLETE
	modal_level_up.visible = session.current_modal == RunSession.Modal.LEVEL_UP
	modal_number.visible = session.current_modal == RunSession.Modal.NUMBER_PICKER
	var show_victory: bool = session.current_modal == RunSession.Modal.GAME_VICTORY
	modal_victory.visible = show_victory
	if show_victory and victory_badge:
		victory_badge.texture = GameData.get_badge_texture(session.gym_id)
		victory_badge.visible = victory_badge.texture != null
	modal_game_over.visible = session.current_modal == RunSession.Modal.GAME_OVER
	modal_stuck.visible = session.current_modal == RunSession.Modal.STUCK
	modal_tournament_win.visible = session.current_modal == RunSession.Modal.TOURNAMENT_WIN
	modal_swap.visible = session.current_modal == RunSession.Modal.SWAP_POWER
	modal_restart_confirm.visible = (
		session.current_modal == RunSession.Modal.RESTART_CONFIRM
	)
	_update_restart_modal()
	_update_fail_modals()
	restart_btn.disabled = not session.can_offer_restart()
	if session.current_modal == RunSession.Modal.LEVEL_UP:
		_build_level_up()
	if session.current_modal == RunSession.Modal.SWAP_POWER:
		_build_swap()


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
		restart_hearts.text = "♥ 1 → gym failed"
	else:
		restart_body.text = (
			"Restart deals a fresh grid on this level.\n"
			+"Pattern power charges reset to how they were at the start of this level."
		)
		var after: int = h - 1
		var word: String = "heart" if after == 1 else "hearts"
		restart_hearts.text = "♥ %d → ♥ %d (%d %s left)" % [h, after, after, word]


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
			"♥ %d %s remaining — tap Restart level to try again (you already lost 1 heart)"
			% [h, heart_word]
		)
	elif session.current_modal == RunSession.Modal.GAME_OVER:
		if session.is_tournament:
			game_over_title.text = "Championship over"
			var opp: Dictionary = GameData.get_tournament_opponent(
				session.tournament_opponent_id
			)
			game_over_body.text = (
				"You lost to %s. Return to the menu to try again."
				% opp.get("name", "your opponent")
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
	SceneNav.go_to_main_menu()


func _on_continue_round_pressed() -> void:
	session.continue_after_round()


func _on_level_up_keep_powers_pressed() -> void:
	session.keep_current_powers_at_level_up()


func _on_retry_pressed() -> void:
	session.retry_level()


func _on_menu_from_over_pressed() -> void:
	SceneNav.go_to_main_menu()


func _on_endless_pressed() -> void:
	session.start_endless()


func _on_tournament_continue_pressed() -> void:
	session.tournament_match_won()
