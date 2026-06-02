extends Control

const DIE_CELL := preload("res://scenes/die_cell.tscn")

@onready var grid_container: GridContainer = %Grid
@onready var level_label: Label = %LevelLabel
@onready var hearts_label: Label = %HeartsLabel
@onready var switches_label: Label = %SwitchesLabel
@onready var rerolls_label: Label = %RerollsLabel
@onready var gym_label: Label = %GymLabel
@onready var power_bar: HBoxContainer = %PowerBar
@onready var safari_overlay: Label = %SafariOverlay
@onready var modal_round: PanelContainer = %ModalRound
@onready var modal_level_up: PanelContainer = %ModalLevelUp
@onready var modal_number: PanelContainer = %ModalNumber
@onready var modal_victory: PanelContainer = %ModalVictory
@onready var modal_game_over: PanelContainer = %ModalGameOver
@onready var modal_stuck: PanelContainer = %ModalStuck
@onready var modal_tournament_win: PanelContainer = %ModalTournamentWin
@onready var modal_swap: PanelContainer = %ModalSwap
@onready var level_up_options: VBoxContainer = %LevelUpOptions
@onready var number_buttons: HBoxContainer = %NumberButtons
@onready var swap_options: VBoxContainer = %SwapOptions

var session: RunSession
var _last_click_time: int = 0
var _last_click_cell: Vector2i = Vector2i(-1, -1)
var _click_timer: Timer
var _safari_timer: Timer
var _pending_click: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	_click_timer = Timer.new()
	_click_timer.one_shot = true
	_click_timer.wait_time = 0.28
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
	if GameState.tournament_opponents.size() > 0:
		_start_tournament_match()
	else:
		session.start_gym_run(GameState.selected_gym_id)
	_refresh_ui()


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
	_build_grid()
	_build_power_bar()
	_update_modals()


func _build_grid() -> void:
	for c in grid_container.get_children():
		c.queue_free()
	for r in range(session.grid.size()):
		for c in range(session.grid[r].size()):
			var cell: DiceCellData = session.grid[r][c]
			var btn: DieCell = DIE_CELL.instantiate() as DieCell
			var key: String = "%d:%d" % [r, c]
			var blurred: bool = session.blurred_cell_key == key
			grid_container.add_child(btn)
			btn.setup(r, c, cell, blurred)
			if r == session.selected_row and c == session.selected_col:
				btn.modulate = Color(1.0, 0.95, 0.6)
			btn.pressed.connect(_on_die_pressed.bind(r, c))


func _build_power_bar() -> void:
	for c in power_bar.get_children():
		c.queue_free()
	for t in session.unlocked_powers:
		var def: Dictionary = GameData.get_power_def(t)
		var b := Button.new()
		var ch: int = session.power_charges.get(t, 0)
		var label: String = def.get("label", t)
		if PowerLogic.is_pattern_power(t) or t == "switchRows":
			label += " (%d)" % ch
		b.text = label
		b.toggle_mode = true
		b.button_pressed = session.active_power_type == t
		b.pressed.connect(_on_power_pressed.bind(t))
		power_bar.add_child(b)
	if session.unlocked_powers.has("rerollTrade"):
		var trade := Button.new()
		trade.text = "Reroll Trade"
		trade.disabled = not PowerLogic.can_trade_rerolls(
			session.level, session.switches_used, session.rerolls_used, session.unlocked_powers
		)
		trade.pressed.connect(func(): session.reroll_trade())
		power_bar.add_child(trade)


func _on_power_pressed(power_type: String) -> void:
	if session.active_power_type == power_type:
		session.active_power_type = ""
	else:
		session.activate_power(power_type)
	_refresh_ui()


func _on_die_pressed(row: int, col: int) -> void:
	if session.safari_countdown > 0:
		return
	var now := Time.get_ticks_msec()
	if (
		_last_click_cell == Vector2i(row, col)
		and now - _last_click_time < 350
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
	modal_victory.visible = session.current_modal == RunSession.Modal.GAME_VICTORY
	modal_game_over.visible = session.current_modal == RunSession.Modal.GAME_OVER
	modal_stuck.visible = session.current_modal == RunSession.Modal.STUCK
	modal_tournament_win.visible = session.current_modal == RunSession.Modal.TOURNAMENT_WIN
	modal_swap.visible = session.current_modal == RunSession.Modal.SWAP_POWER
	if session.current_modal == RunSession.Modal.LEVEL_UP:
		_build_level_up()
	if session.current_modal == RunSession.Modal.SWAP_POWER:
		_build_swap()


func _build_level_up() -> void:
	for c in level_up_options.get_children():
		c.queue_free()
	for t in session.level_up_pool:
		var def: Dictionary = GameData.get_power_def(t)
		var b := Button.new()
		b.text = "%s\n%s" % [def.get("label", t), def.get("description", "")]
		b.pressed.connect(func(): session.choose_level_up_power(t))
		level_up_options.add_child(b)


func _build_swap() -> void:
	for c in swap_options.get_children():
		c.queue_free()
	for t in session.unlocked_powers:
		var def: Dictionary = GameData.get_power_def(t)
		var b := Button.new()
		b.text = "Drop: %s" % def.get("label", t)
		b.pressed.connect(func(): session.swap_out_power(t))
		swap_options.add_child(b)


func _on_back_pressed() -> void:
	SceneNav.go_to_main_menu()


func _on_continue_round_pressed() -> void:
	session.continue_after_round()


func _on_retry_pressed() -> void:
	session.retry_level()


func _on_menu_from_over_pressed() -> void:
	SceneNav.go_to_main_menu()


func _on_endless_pressed() -> void:
	session.start_endless()


func _on_tournament_continue_pressed() -> void:
	session.tournament_match_won()
