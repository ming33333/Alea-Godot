class_name RunSession
extends RefCounted

signal state_changed
signal dice_rerolled(row: int, col: int, new_value: int)
signal show_modal(modal: String)
signal hide_modal(modal: String)

enum Modal {
	NONE, ROUND_COMPLETE, LEVEL_UP, NUMBER_PICKER, GAME_VICTORY,
	GAME_OVER, TOURNAMENT_WIN, SWAP_POWER, STUCK, RESTART_CONFIRM
}

var gym_id: String = "vanilla"
var is_tournament: bool = false
var tournament_opponent_id: String = ""
var tournament_loadout: Array = []
var tournament_stolen: String = ""
var tournament_on_match_win: Callable = Callable()

var level: int = 1
var hearts: int = 3
var switches_used: int = 0
var rerolls_used: int = 0
var grid: Array = []
var awarded_rows: Dictionary = {}
var power_earned_rows: Dictionary = {}
var unlocked_powers: Dictionary = {}
var power_charges: Dictionary = {}
var charges_at_level_start: Dictionary = {}
var active_power_type: String = ""
var active_target_row: int = -1
var active_target_col: int = -1
var selected_row: int = -1
var selected_col: int = -1
var level_power_goal: String = ""
var level_up_pool: Array = []
var pending_swap_in: String = ""
var skip_choose_earn_rows: Dictionary = {}
var endless_mode: bool = false
var safari_countdown: int = 0
var blurred_cell_key: String = ""
var game_over: bool = false
var current_modal: int = Modal.NONE
var victory_badge_is_new: bool = false
var max_owned_powers: int = 3
var fail_heart_processed: bool = false

var _safari_timer: SceneTreeTimer = null


func start_gym_run(gym: String) -> void:
	gym_id = gym
	is_tournament = false
	tournament_opponent_id = ""
	max_owned_powers = GameData.max_owned_powers_for_gym(gym_id)
	_reset_meta()
	_start_level(1, true)


func start_tournament_match(
	opponent_id: String,
	loadout: Array,
	stolen: String,
	on_win: Callable
) -> void:
	gym_id = "vanilla"
	is_tournament = true
	tournament_opponent_id = opponent_id
	tournament_loadout = loadout.duplicate()
	tournament_stolen = stolen
	tournament_on_match_win = on_win
	max_owned_powers = 3
	_reset_meta()
	unlocked_powers = TournamentRules.build_unlocked(loadout, stolen)
	level = int(GameData.level_limits.get("championship_level", 8))
	_init_tournament_charges()
	_start_level(level, false)


func _reset_meta() -> void:
	hearts = int(GameData.level_limits.get("max_hearts", 3))
	game_over = false
	endless_mode = false
	unlocked_powers = {}
	power_charges = _empty_charges()
	level_power_goal = ""
	fail_heart_processed = false
	victory_badge_is_new = false


func _empty_charges() -> Dictionary:
	var d: Dictionary = {}
	for p in GameData.powers:
		d[str(p.get("type", ""))] = 0
	return d


func _start_level(lvl: int, new_run: bool) -> void:
	level = lvl
	switches_used = 0
	rerolls_used = 0
	selected_row = -1
	selected_col = -1
	active_power_type = ""
	active_target_row = -1
	active_target_col = -1
	skip_choose_earn_rows = {}
	safari_countdown = 0
	blurred_cell_key = ""
	current_modal = Modal.NONE
	awarded_rows = {}
	for r in GymRules.initial_awarded_rows(gym_id):
		awarded_rows[r] = true
	var has_sc: bool = unlocked_powers.has("secondChances")
	var lucky: bool = is_tournament and tournament_opponent_id == "luckySeven"
	grid = GymRules.build_grid(gym_id, has_sc, lucky)
	if new_run:
		charges_at_level_start = _snapshot_charges()
	elif not is_tournament:
		_apply_charges_for_new_level()
		charges_at_level_start = _snapshot_charges()
	process_row_completions()
	_emit()


func _init_tournament_charges() -> void:
	power_charges = _empty_charges()
	for t in unlocked_powers:
		if PowerLogic.is_pattern_power(t) or t == "switchRows":
			power_charges[t] = maxi(power_charges.get(t, 0), 1)
	_apply_charges_for_new_level()
	charges_at_level_start = _snapshot_charges()


func _apply_charges_for_new_level() -> void:
	for p in GameData.powers:
		var t: String = str(p.get("type", ""))
		if PowerLogic.is_permanent(t):
			continue
		if PowerLogic.is_per_level(t) and unlocked_powers.has(t):
			power_charges[t] = 1
		elif PowerLogic.is_pattern_power(t):
			power_charges[t] = 0


func _snapshot_charges() -> Dictionary:
	return power_charges.duplicate()


func get_limits() -> Dictionary:
	return LevelLimits.get_level_limits(level)


func switches_left() -> int:
	return LevelLimits.switches_remaining(level, switches_used)


func rerolls_left() -> int:
	return LevelLimits.rerolls_remaining(level, rerolls_used)


func check_win() -> bool:
	var patterns: Array = []
	for row in grid:
		var vals: Array = []
		for c in row:
			vals.append(c.value)
		patterns.append(PatternCheck.check_pattern(vals))
	var opp: String = tournament_opponent_id if is_tournament else ""
	return TournamentRules.check_win_patterns(patterns, opp)


func blocks_play() -> bool:
	if game_over or safari_countdown > 0:
		return true
	return (
		current_modal != Modal.NONE
		and current_modal != Modal.NUMBER_PICKER
	)


func can_offer_restart() -> bool:
	if game_over or is_tournament or check_win() or safari_countdown > 0:
		return false
	if (
		current_modal != Modal.NONE
		and current_modal != Modal.RESTART_CONFIRM
	):
		return false
	return hearts > 0


func request_restart_confirm() -> void:
	if not can_offer_restart():
		return
	current_modal = Modal.RESTART_CONFIRM
	_emit()


func cancel_restart_confirm() -> void:
	if current_modal == Modal.RESTART_CONFIRM:
		current_modal = Modal.NONE
		_emit()


func confirm_restart_level() -> void:
	if current_modal != Modal.RESTART_CONFIRM:
		return
	current_modal = Modal.NONE
	restart_level_voluntary()


func is_level_failed() -> bool:
	if check_win() or game_over or blocks_play():
		return false
	return PowerLogic.is_level_stuck(
		grid, level, switches_used, rerolls_used,
		unlocked_powers, active_power_type, power_charges, awarded_rows
	)


func process_row_completions() -> void:
	var skip_rows: Dictionary = skip_choose_earn_rows.duplicate()
	skip_choose_earn_rows = {}
	var rows_done: Array = []
	var patterns: Array = []
	for row in grid:
		var vals: Array = []
		for c in row:
			vals.append(c.value)
		patterns.append(PatternCheck.check_pattern(vals))
	var pattern_counts: Dictionary = {}
	if is_tournament and tournament_opponent_id == "noThreeRepeats":
		for p in patterns:
			if p != PatternCheck.INCOMPLETE:
				pattern_counts[p] = pattern_counts.get(p, 0) + 1
	for row_index in range(patterns.size()):
		var pattern: String = str(patterns[row_index])
		var complete: bool = false
		if is_tournament:
			complete = TournamentRules.row_complete_for_opponent(
				pattern, tournament_opponent_id
			)
			if tournament_opponent_id == "noThreeRepeats" and pattern != PatternCheck.INCOMPLETE:
				complete = complete and pattern_counts.get(pattern, 0) <= 2
		else:
			complete = pattern != PatternCheck.INCOMPLETE
		if complete and not awarded_rows.has(row_index):
			rows_done.append({"index": row_index, "pattern": pattern})
	if rows_done.is_empty():
		_maybe_fail_level()
		return
	var charges_add: Dictionary = {}
	for item in rows_done:
		var row_item: Dictionary = item
		var idx: int = int(row_item["index"])
		var pat: String = str(row_item["pattern"])
		awarded_rows[idx] = true
		for t in unlocked_powers:
			if not PowerLogic.is_pattern_power(t):
				continue
			var key: String = PowerLogic.power_earn_key(idx, t)
			if power_earned_rows.has(key):
				continue
			if not PowerLogic.row_earns_goal(t, pat):
				continue
			if t == "chooseNumber" and pat == PatternCheck.FIVE_KIND and skip_rows.has(idx):
				power_earned_rows[key] = true
				continue
			power_earned_rows[key] = true
			charges_add[t] = charges_add.get(t, 0) + 1
		grid[idx] = _lock_row(grid[idx])
	for t in charges_add:
		power_charges[t] = power_charges.get(t, 0) + charges_add[t]
	_check_win_flow()


func _lock_row(row: Array) -> Array:
	var out: Array = []
	for cell in row:
		var c: DiceCellData = cell.duplicate_cell()
		c.locked = true
		out.append(c)
	return out


func _check_win_flow() -> void:
	if not check_win():
		if is_level_failed():
			_handle_fail()
		_emit()
		return
	if is_tournament:
		current_modal = Modal.TOURNAMENT_WIN
		_emit()
		return
	var max_lvl: int = int(GameData.level_limits.get("max_level", 8))
	if level >= max_lvl and not endless_mode:
		if not is_tournament:
			victory_badge_is_new = SaveService.award_gym_badge(gym_id)
		current_modal = Modal.GAME_VICTORY
		_emit()
		return
	level_up_pool = _pick_level_up_pool()
	current_modal = Modal.ROUND_COMPLETE
	_emit()


func _pick_level_up_pool() -> Array:
	var available: Array = []
	for p in GameData.powers:
		var t: String = str(p.get("type", ""))
		if not unlocked_powers.has(t):
			available.append(t)
	available.shuffle()
	var n: int = int(GameData.level_limits.get("level_up_offer_count", 2))
	return available.slice(0, mini(n, available.size()))


func _handle_fail() -> void:
	if fail_heart_processed:
		return
	fail_heart_processed = true
	selected_row = -1
	selected_col = -1
	active_power_type = ""
	active_target_row = -1
	active_target_col = -1
	if is_tournament:
		game_over = true
		current_modal = Modal.GAME_OVER
		return
	hearts -= 1
	if hearts <= 0:
		game_over = true
		current_modal = Modal.GAME_OVER
	else:
		current_modal = Modal.STUCK


func retry_level() -> void:
	fail_heart_processed = false
	current_modal = Modal.NONE
	_restore_charges_snapshot()
	_start_level(level, false)


func restart_level_voluntary() -> void:
	if game_over or check_win() or is_tournament:
		return
	if hearts <= 1:
		hearts = 0
		game_over = true
		current_modal = Modal.GAME_OVER
		_emit()
		return
	hearts -= 1
	retry_level()


func select_die(row: int, col: int) -> void:
	if blocks_play() or current_modal == Modal.GAME_VICTORY:
		return
	if active_power_type in ["switchRows", "chooseNumber", "setAnyNumber"]:
		_handle_power_click(row, col)
		return
	if is_level_failed() and not check_win():
		return
	var cell: DiceCellData = grid[row][col]
	if cell.locked:
		return
	if selected_row < 0:
		selected_row = row
		selected_col = col
	elif selected_row == row and selected_col == col:
		selected_row = -1
		selected_col = -1
	elif _try_switch(row, col):
		pass
	else:
		selected_row = row
		selected_col = col
	_emit()


func reroll_die(row: int, col: int) -> void:
	if blocks_play():
		return
	if is_level_failed() and not check_win():
		return
	var cell: DiceCellData = grid[row][col]
	if cell.locked or cell.no_reroll:
		return
	if rerolls_left() <= 0:
		return
	var new_val: int = GymRules.reroll_value(cell.value, gym_id)
	cell.push_history(new_val)
	rerolls_used += 1
	dice_rerolled.emit(row, col, new_val)
	var pending: Dictionary = {"row": row, "col": col, "value": new_val}
	if GameData.is_countdown_gym(gym_id) and rerolls_used % int(
		GameData.level_limits.get("safari_reroll_interval", 3)
	) == 0:
		_trigger_safari(pending)
	else:
		_after_reroll_side_effects(pending)
	process_row_completions()


func _after_reroll_side_effects(pending: Dictionary) -> void:
	if is_tournament and tournament_opponent_id == "rerollChaos":
		_apply_random_die_change()
	if is_tournament and tournament_opponent_id == "blurPerReroll":
		blurred_cell_key = _pick_random_unlocked_key()
	_emit()


func _trigger_safari(pending: Dictionary) -> void:
	safari_countdown = 3
	# UI will tick countdown; on complete call finish_safari_wave
	_pending_safari = pending


var _pending_safari: Dictionary = {}


func tick_safari_countdown() -> void:
	if safari_countdown <= 0:
		return
	safari_countdown -= 1
	if safari_countdown <= 0:
		grid = SafariRules.apply_wave(grid, gym_id, _pending_safari)
		_after_reroll_side_effects(_pending_safari)
		process_row_completions()
	_emit()


func _apply_random_die_change() -> void:
	var pick: Dictionary = _pick_random_unlocked_pos()
	if pick.is_empty():
		return
	var v: int = GymRules.roll_die()
	grid[int(pick["row"])][int(pick["col"])].push_history(v)


func _pick_random_unlocked_key() -> String:
	var p: Dictionary = _pick_random_unlocked_pos()
	if p.is_empty():
		return ""
	return "%d:%d" % [int(p["row"]), int(p["col"])]


func _pick_random_unlocked_pos() -> Dictionary:
	var cands: Array = []
	for r in range(grid.size()):
		for c in range(grid[r].size()):
			var cell: DiceCellData = grid[r][c]
			if not cell.locked and not cell.no_reroll:
				cands.append({"row": r, "col": c})
	if cands.is_empty():
		return {}
	return cands[randi() % cands.size()] as Dictionary


func _try_switch(row: int, col: int) -> bool:
	if switches_left() <= 0:
		return false
	if grid[row][col].locked or grid[selected_row][selected_col].locked:
		return false
	var sw_any: bool = active_power_type == "switchAnywhere"
	var side: bool = unlocked_powers.has("switchHorizontal")
	var vjump: bool = unlocked_powers.has("verticalJump")
	var sc: bool = unlocked_powers.has("secondChances")
	var adj_v: bool = selected_col == col and abs(selected_row - row) == 1
	var adj_h: bool = selected_row == row and abs(selected_col - col) == 1
	var v_jump: bool = vjump and selected_col == col and PowerLogic.can_vertical_jump(
		grid, selected_row, row, col
	)
	var valid: bool = adj_v or sw_any or (side and adj_h) or v_jump
	if not valid:
		return false
	var free_side: bool = side and adj_h
	var normal_v: bool = adj_v and not sw_any and not free_side
	_swap_values(selected_row, selected_col, row, col)
	if normal_v and sc:
		_apply_second_chances(selected_row, row, col)
	elif not free_side:
		grid[selected_row][selected_col].locked = true
		grid[row][col].locked = true
	switches_used += 1
	if free_side:
		selected_row = row
		selected_col = col
	else:
		selected_row = -1
		selected_col = -1
	if sw_any:
		power_charges["switchAnywhere"] = power_charges.get("switchAnywhere", 0) - 1
		active_power_type = ""
	process_row_completions()
	return true


func _swap_values(r1: int, c1: int, r2: int, c2: int) -> void:
	var t: int = grid[r1][c1].value
	grid[r1][c1].value = grid[r2][c2].value
	grid[r2][c2].value = t


func _apply_second_chances(r1: int, r2: int, col: int) -> void:
	for r in [r1, r2]:
		var cell: DiceCellData = grid[r][col]
		var rem: int = cell.vertical_swaps_remaining
		if rem < 0:
			rem = int(GameData.level_limits.get("second_chances_vertical_swaps", 2))
		rem -= 1
		cell.vertical_swaps_remaining = rem
		if rem <= 0:
			cell.locked = true


func activate_power(power_type: String) -> void:
	if not unlocked_powers.has(power_type):
		return
	active_power_type = power_type
	active_target_row = -1
	active_target_col = -1
	selected_row = -1
	selected_col = -1
	_emit()


func clear_active_power() -> void:
	if (
		active_power_type == ""
		and active_target_row < 0
		and selected_row < 0
	):
		return
	active_power_type = ""
	active_target_row = -1
	active_target_col = -1
	selected_row = -1
	selected_col = -1
	_emit()


func _handle_power_click(row: int, col: int) -> void:
	match active_power_type:
		"switchRows":
			_handle_switch_rows(row)
		"setAnyNumber", "chooseNumber":
			_handle_pattern_pick(row, col)
		_:
			pass


func _handle_switch_rows(row: int) -> void:
	if active_target_row < 0:
		active_target_row = row
		_emit()
		return
	if active_target_row == row:
		active_power_type = ""
		active_target_row = -1
		_emit()
		return
	_swap_rows(active_target_row, row)
	power_charges["switchRows"] = power_charges.get("switchRows", 0) - 1
	active_power_type = ""
	active_target_row = -1
	process_row_completions()


func _swap_rows(first: int, second: int) -> void:
	var has_sc: bool = unlocked_powers.has("secondChances")
	for c in range(grid[0].size()):
		var a: DiceCellData = grid[first][c]
		var b: DiceCellData = grid[second][c]
		var tv: int = a.value
		a.value = b.value
		b.value = tv
		var th: Array = a.history.duplicate()
		a.history = b.history.duplicate()
		b.history = th
	for ri in [first, second]:
		var vals: Array = []
		for cell in grid[ri]:
			vals.append(cell.value)
		if PatternCheck.check_pattern(vals) == PatternCheck.INCOMPLETE:
			awarded_rows.erase(ri)
			for pt in PowerLogic.PATTERN_POWERS:
				power_earned_rows.erase(PowerLogic.power_earn_key(ri, pt))
			var new_row: Array = []
			for cell in grid[ri]:
				var nc: DiceCellData = cell.duplicate_cell()
				nc.locked = false
				if has_sc:
					nc.vertical_swaps_remaining = int(
						GameData.level_limits.get("second_chances_vertical_swaps", 2)
					)
				new_row.append(nc)
			grid[ri] = new_row


func _handle_pattern_pick(row: int, col: int) -> void:
	if active_power_type == "chooseNumber":
		if awarded_rows.has(row):
			return
		var vals: Array = []
		for c in grid[row]:
			vals.append(c.value)
		if PatternCheck.check_pattern(vals) != PatternCheck.INCOMPLETE:
			return
	active_target_row = row
	active_target_col = col
	current_modal = Modal.NUMBER_PICKER
	_emit()


func apply_number_pick(number: int) -> void:
	if active_power_type not in ["chooseNumber", "setAnyNumber"]:
		return
	var tr: int = active_target_row
	var tc: int = active_target_col
	var ptype: String = active_power_type
	if ptype == "chooseNumber":
		skip_choose_earn_rows[tr] = true
		for c in range(grid[tr].size()):
			grid[tr][c].push_history(number)
	else:
		grid[tr][tc].push_history(number)
		rerolls_used += 1
	power_charges[ptype] = power_charges.get(ptype, 0) - 1
	active_power_type = ""
	active_target_row = -1
	active_target_col = -1
	current_modal = Modal.NONE
	process_row_completions()


func reroll_trade() -> void:
	if not PowerLogic.can_trade_rerolls(
		level, switches_used, rerolls_used, unlocked_powers
	):
		return
	rerolls_used += 2
	switches_used -= 1
	_emit()


func choose_level_up_power(power_type: String) -> void:
	if unlocked_powers.has(power_type):
		return
	if unlocked_powers.size() < max_owned_powers:
		_apply_level_up(power_type)
		return
	pending_swap_in = power_type
	current_modal = Modal.SWAP_POWER
	_emit()


func swap_out_power(replaced: String) -> void:
	if pending_swap_in == "":
		return
	unlocked_powers.erase(replaced)
	unlocked_powers[pending_swap_in] = true
	if active_power_type == replaced:
		active_power_type = ""
	if PowerLogic.is_pattern_power(pending_swap_in):
		level_power_goal = pending_swap_in
	pending_swap_in = ""
	current_modal = Modal.NONE
	level += 1
	_start_level(level, false)


func _apply_level_up(power_type: String) -> void:
	unlocked_powers[power_type] = true
	if PowerLogic.is_pattern_power(power_type):
		level_power_goal = power_type
	level += 1
	_start_level(level, false)


func keep_current_powers_at_level_up() -> void:
	if current_modal != Modal.LEVEL_UP:
		return
	pending_swap_in = ""
	level += 1
	_start_level(level, false)


func continue_after_round() -> void:
	if level_up_pool.is_empty():
		level += 1
		_start_level(level, false)
		return
	current_modal = Modal.LEVEL_UP
	_emit()


func start_endless() -> void:
	endless_mode = true
	current_modal = Modal.NONE
	level = int(GameData.level_limits.get("max_level", 8)) + 1
	_start_level(level, false)


func _restore_charges_snapshot() -> void:
	for t in power_charges:
		if PowerLogic.is_permanent(t):
			continue
		power_charges[t] = charges_at_level_start.get(t, 0)


func tournament_match_won() -> void:
	current_modal = Modal.NONE
	if tournament_on_match_win.is_valid():
		tournament_on_match_win.call()


func dev_complete_level() -> void:
	if game_over or check_win():
		return
	if current_modal == Modal.ROUND_COMPLETE:
		return
	var patterns: Array = [
		[1, 1, 1, 1, 1],
		[1, 1, 1, 2, 2],
		[1, 2, 3, 4, 5],
		[6, 6, 6, 6, 6],
		[2, 3, 4, 5, 6],
	]
	grid = []
	awarded_rows = {}
	for row_vals in patterns:
		var row: Array = []
		for v in row_vals:
			var cell := DiceCellData.new(v, true)
			row.append(cell)
		grid.append(row)
		awarded_rows[grid.size() - 1] = true
	selected_row = -1
	selected_col = -1
	active_power_type = ""
	level_up_pool = _pick_level_up_pool()
	current_modal = Modal.ROUND_COMPLETE
	_emit()


func dev_add_heart() -> void:
	if game_over:
		return
	var max_h: int = int(GameData.level_limits.get("max_hearts", 3))
	hearts = mini(hearts + 1, max_h)
	_emit()


func dev_refill_resources() -> void:
	switches_used = 0
	rerolls_used = 0
	_emit()


func dev_grant_power(power_type: String) -> String:
	if game_over:
		return "Game over — start a new run"
	if power_type.is_empty():
		return "Pick a power"
	if unlocked_powers.has(power_type):
		var owned: Dictionary = GameData.get_power_def(power_type)
		return "Already owned: %s" % str(owned.get("label", power_type))
	if unlocked_powers.size() >= max_owned_powers:
		return "Loadout full (%d/%d) — drop one first" % [
			unlocked_powers.size(), max_owned_powers
		]
	unlocked_powers[power_type] = true
	if PowerLogic.is_per_level(power_type):
		power_charges[power_type] = maxi(power_charges.get(power_type, 0), 1)
	elif PowerLogic.is_pattern_power(power_type):
		power_charges[power_type] = 0
		if level_power_goal.is_empty():
			level_power_goal = power_type
	if pending_swap_in == power_type:
		pending_swap_in = ""
		if current_modal == Modal.SWAP_POWER:
			current_modal = Modal.NONE
	_emit()
	var def: Dictionary = GameData.get_power_def(power_type)
	return "Added %s (%d/%d)" % [
		str(def.get("label", power_type)),
		unlocked_powers.size(),
		max_owned_powers,
	]


func _maybe_fail_level() -> void:
	if game_over or current_modal != Modal.NONE:
		return
	if is_level_failed():
		_handle_fail()


func _emit() -> void:
	_maybe_fail_level()
	state_changed.emit()
