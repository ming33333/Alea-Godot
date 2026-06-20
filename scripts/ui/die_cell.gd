class_name DieCell
extends Button

const FACE_NORMAL := "normal"
const FACE_LOCKED := "locked"
const FACE_SELECTED := "selected"
const FACE_BLURRED := "blurred"
const FACE_SWITCH_VALID := "switch_valid"
const FACE_SWITCH_ROWS_PRIMARY := "switch_rows_primary"
const FACE_SWITCH_ROWS_PICKABLE := "switch_rows_pickable"
const FACE_POWER_CHOOSE := "power_choose"
const FACE_POWER_SET_ANY := "power_set_any"
const FACE_POWER_SWITCH_ANY := "power_switch_any"
const PIXEL_FACE_NORMAL := "pixel_normal"
const PIXEL_FACE_LOCKED := "pixel_locked"
const PIXEL_FACE_BLURRED := "pixel_blurred"

const DICE_BOARD_ATLAS: Texture2D = preload("res://assets/textures/dice_board.png")
const DICE_BOARD_TILE_REGION := Rect2(124, 130, 264, 258)
const DIE_BLUR_SHADER: Shader = preload("res://assets/shaders/die_blur.gdshader")

enum Highlight {
	NONE,
	SELECTED,
	SWITCH_VALID,
	SWITCH_ROWS_PRIMARY,
	SWITCH_ROWS_PICKABLE,
	POWER_CHOOSE,
	POWER_SET_ANY,
	POWER_SWITCH_ANY,
}

var value_label: Label
var die_face: TextureRect
var _face: PanelContainer
var _pixel_border: PixelDieFrame
var _shine: ColorRect
var _swap_overlay: Control
var _overlay_backdrop: ColorRect
var _overlay_face: TextureRect
var _overlay_label: Label
var _styles: Dictionary = {}
var _base_face_key: String = FACE_NORMAL
var _highlight: Highlight = Highlight.NONE
var _show_sprite: bool = true
var _blurred: bool = false
var _swap_overlay_active: bool = false
var _blur_material: ShaderMaterial
var grid_row: int = -1
var grid_col: int = -1

const SWAP_SLIDE_DURATION := 0.2
const FLOAT_PERIOD_SEC := 2.9
const FLOAT_BOB_RATIO := 0.024
const FLOAT_TILT_DEG := 1.1
const LOCK_POP_RISE_SEC := 0.1
const LOCK_POP_SETTLE_SEC := 0.12
const LOCK_POP_TOTAL_SEC := LOCK_POP_RISE_SEC + LOCK_POP_SETTLE_SEC
const LOCK_POP_LIFT_PX := 10.0
const LOCK_POP_SCALE := 1.16
const REROLL_SCRAMBLE_DURATION := 0.5
const REROLL_SCRAMBLE_STEPS := 21
const REROLL_SCRAMBLE_INTERVAL := REROLL_SCRAMBLE_DURATION / float(REROLL_SCRAMBLE_STEPS - 1)

var _wrap: Control
var _float_root: Control
var _swap_tween: Tween
var _lock_pop_tween: Tween
var _reroll_scramble_tween: Tween
var _float_phase: float = 0.0
var _float_paused: bool = false
var _float_disabled: bool = false
var _lock_pop_active: bool = false
var _reroll_scramble_active: bool = false


func _ready() -> void:
	_cache_styles()
	_wrap = get_node_or_null("Wrap") as Control
	_float_root = get_node_or_null("Wrap/FloatRoot") as Control
	_face = get_node_or_null("Wrap/FloatRoot/Face") as PanelContainer
	_pixel_border = get_node_or_null("Wrap/FloatRoot/PixelBorder") as PixelDieFrame
	_shine = get_node_or_null("Wrap/FloatRoot/Shine") as ColorRect
	die_face = get_node_or_null("Wrap/FloatRoot/Face/Margin/DieFace") as TextureRect
	value_label = get_node_or_null("Wrap/FloatRoot/ValueLabel") as Label
	_swap_overlay = get_node_or_null("Wrap/FloatRoot/SwapOverlay") as Control
	_overlay_backdrop = get_node_or_null("Wrap/FloatRoot/SwapOverlay/OverlayBackdrop") as ColorRect
	_overlay_face = get_node_or_null("Wrap/FloatRoot/SwapOverlay/OverlayFace") as TextureRect
	_overlay_label = get_node_or_null("Wrap/FloatRoot/SwapOverlay/OverlayLabel") as Label
	if _face:
		_face.add_theme_stylebox_override("panel", _styles[FACE_NORMAL])
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	set_process(true)


func _process(_delta: float) -> void:
	_update_float_bob()


func _update_float_bob() -> void:
	if _float_root == null or _float_paused or _float_disabled:
		return
	var cell_px: float = maxf(custom_minimum_size.x, custom_minimum_size.y)
	var amplitude: float = maxf(1.4, cell_px * FLOAT_BOB_RATIO)
	var t: float = Time.get_ticks_msec() * 0.001
	var bob: float = sin((t + _float_phase) * TAU / FLOAT_PERIOD_SEC) * amplitude
	var tilt: float = (
		sin((t + _float_phase * 1.37) * TAU / (FLOAT_PERIOD_SEC * 1.35))
		* deg_to_rad(FLOAT_TILT_DEG)
	)
	_float_root.position = Vector2(0.0, bob)
	_float_root.rotation = tilt


func _sync_float_phase() -> void:
	if grid_row < 0 or grid_col < 0:
		_float_phase = randf() * FLOAT_PERIOD_SEC
	else:
		_float_phase = float(grid_row) * 1.73 + float(grid_col) * 2.17


func pause_float_bob() -> void:
	_float_paused = true
	if _float_root != null and not _lock_pop_active:
		_float_root.position = Vector2.ZERO
		_float_root.rotation = 0.0
		_float_root.scale = Vector2.ONE


func resume_float_bob() -> void:
	if _float_disabled:
		return
	_float_paused = false


func play_lock_pop() -> void:
	if _float_root == null:
		return
	_lock_pop_active = true
	_float_disabled = true
	_float_paused = true
	if _lock_pop_tween != null and _lock_pop_tween.is_valid():
		_lock_pop_tween.kill()
	_float_root.rotation = 0.0
	_float_root.position = Vector2.ZERO
	_float_root.scale = Vector2.ONE
	_lock_pop_tween = create_tween()
	_lock_pop_tween.tween_property(
		_float_root, "position:y", -LOCK_POP_LIFT_PX, LOCK_POP_RISE_SEC
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lock_pop_tween.parallel().tween_property(
		_float_root, "scale", Vector2(LOCK_POP_SCALE, LOCK_POP_SCALE), LOCK_POP_RISE_SEC
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lock_pop_tween.tween_property(
		_float_root, "position:y", 0.0, LOCK_POP_SETTLE_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lock_pop_tween.parallel().tween_property(
		_float_root, "scale", Vector2.ONE, LOCK_POP_SETTLE_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lock_pop_tween.finished.connect(_on_lock_pop_finished, CONNECT_ONE_SHOT)


func _on_lock_pop_finished() -> void:
	_lock_pop_active = false
	if _float_root != null:
		_float_root.position = Vector2.ZERO
		_float_root.rotation = 0.0
		_float_root.scale = Vector2.ONE


func is_lock_pop_active() -> bool:
	return _lock_pop_active


func _cache_styles() -> void:
	_styles[FACE_NORMAL] = _make_board_face_style()
	_styles[FACE_LOCKED] = _make_face_style(
		Color(0.82, 0.84, 0.88),
		Color(0.45, 0.48, 0.52),
		3,
		12
	)
	_styles[FACE_SELECTED] = _make_face_style(
		Color(0.88, 0.94, 1.0),
		Color(0.15, 0.4, 0.92),
		6,
		12
	)
	_styles[FACE_BLURRED] = _make_board_face_style()
	_styles[FACE_SWITCH_VALID] = _make_face_style(
		Color(0.9, 0.98, 0.92),
		Color(0.2, 0.65, 0.35),
		6,
		12
	)
	_styles[FACE_SWITCH_ROWS_PRIMARY] = _make_face_style(
		Color(0.9, 0.91, 0.98),
		Color(0.35, 0.35, 0.85),
		6,
		12
	)
	_styles[FACE_SWITCH_ROWS_PICKABLE] = _make_face_style(
		Color(0.94, 0.94, 0.99),
		Color(0.55, 0.58, 0.82),
		5,
		12
	)
	_styles[FACE_POWER_CHOOSE] = _make_face_style(
		Color(0.9, 0.98, 0.93),
		Color(0.15, 0.6, 0.35),
		6,
		12
	)
	_styles[FACE_POWER_SET_ANY] = _make_face_style(
		Color(1.0, 0.96, 0.9),
		Color(0.9, 0.45, 0.1),
		6,
		12
	)
	_styles[FACE_POWER_SWITCH_ANY] = _make_face_style(
		Color(0.95, 0.93, 1.0),
		Color(0.45, 0.3, 0.75),
		5,
		12
	)
	_styles[PIXEL_FACE_NORMAL] = _make_pixel_face_style(
		Color(1, 1, 1),
		Color(0.28, 0.3, 0.34)
	)
	_styles[PIXEL_FACE_LOCKED] = _make_pixel_face_style(
		Color(0.96, 0.97, 0.99),
		Color(0.55, 0.58, 0.64)
	)
	_styles[PIXEL_FACE_BLURRED] = _make_pixel_face_style(
		Color(1, 1, 1),
		Color(0.28, 0.3, 0.34)
	)


func _make_board_face_style() -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = DICE_BOARD_ATLAS
	atlas.region = DICE_BOARD_TILE_REGION
	var box := StyleBoxTexture.new()
	box.texture = atlas
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.set_content_margin_all(5)
	return box


func _make_face_style(
	bg: Color, border: Color, border_w: int, radius: int
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.22)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 3)
	return box


func _make_pixel_face_style(bg: Color, _border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(0)
	box.set_corner_radius_all(0)
	box.shadow_size = 0
	box.shadow_offset = Vector2.ZERO
	box.anti_aliasing = false
	return box


func _panel_style_for_face(face_key: String) -> StyleBox:
	if not _styles.has(face_key):
		return null
	var style: StyleBox = _styles[face_key]
	if not _is_pixel_font_style() or not style is StyleBoxFlat:
		return style
	var flat_style := style.duplicate() as StyleBoxFlat
	flat_style.set_border_width_all(0)
	flat_style.set_corner_radius_all(0)
	flat_style.shadow_size = 0
	flat_style.shadow_offset = Vector2.ZERO
	flat_style.anti_aliasing = false
	return flat_style


func _pixel_border_color(face_key: String) -> Color:
	match face_key:
		PIXEL_FACE_NORMAL, FACE_NORMAL:
			return Color(0.28, 0.3, 0.34)
		PIXEL_FACE_LOCKED, FACE_LOCKED:
			return Color(0.55, 0.58, 0.64)
		PIXEL_FACE_BLURRED, FACE_BLURRED:
			return Color(0.28, 0.3, 0.34)
		FACE_SELECTED:
			return Color(0.15, 0.4, 0.92)
		FACE_SWITCH_VALID:
			return Color(0.2, 0.65, 0.35)
		FACE_SWITCH_ROWS_PRIMARY:
			return Color(0.35, 0.35, 0.85)
		FACE_SWITCH_ROWS_PICKABLE:
			return Color(0.55, 0.58, 0.82)
		FACE_POWER_CHOOSE:
			return Color(0.15, 0.6, 0.35)
		FACE_POWER_SET_ANY:
			return Color(0.9, 0.45, 0.1)
		FACE_POWER_SWITCH_ANY:
			return Color(0.45, 0.3, 0.75)
		_:
			return Color(0.28, 0.3, 0.34)


func _update_pixel_border(face_key: String) -> void:
	if _pixel_border == null:
		_pixel_border = get_node_or_null("Wrap/FloatRoot/PixelBorder") as PixelDieFrame
	if _pixel_border == null:
		return
	var show_frame: bool = _is_pixel_font_style() and not _show_sprite
	_pixel_border.visible = show_frame
	if not show_frame:
		return
	var cell_px: float = maxf(custom_minimum_size.x, custom_minimum_size.y)
	_pixel_border.line_thickness = maxi(3, int(round(cell_px * 0.034)))
	_pixel_border.corner_radius = maxi(2, int(round(cell_px * 0.028)))
	_pixel_border.frame_color = _pixel_border_color(face_key)
	_pixel_border.queue_redraw()


func _face_texture_for(value: int) -> Texture2D:
	var sprites := _dice_sprite_settings()
	if sprites == null:
		return null
	return sprites.get_face(value)


func _dice_sprite_settings() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("DiceSprites")


func _is_pixel_font_style() -> bool:
	var sprites := _dice_sprite_settings()
	return sprites != null and sprites.is_pixel_font_style()


func _resolve_face_key(face_key: String) -> String:
	if not _is_pixel_font_style():
		return face_key
	match face_key:
		FACE_NORMAL:
			return PIXEL_FACE_NORMAL
		FACE_LOCKED:
			return PIXEL_FACE_LOCKED
		FACE_BLURRED:
			return PIXEL_FACE_BLURRED
	return face_key


func _configure_value_label_font(blurred: bool) -> void:
	var label: Label = _ensure_value_label()
	if label == null:
		return
	var sprites := _dice_sprite_settings()
	if sprites != null and sprites.is_pixel_font_style():
		var font: Font = sprites.get_pixel_font()
		if font != null:
			label.add_theme_font_override("font", font)
		var cell_px: float = maxf(custom_minimum_size.x, custom_minimum_size.y)
		var font_px: int = maxi(16, int(round(cell_px * (0.5 if blurred else 0.58))))
		label.add_theme_font_size_override("font_size", font_px)
	else:
		label.remove_theme_font_override("font")
		label.add_theme_font_size_override("font_size", maxi(16, int(round(maxf(
			custom_minimum_size.x,
			custom_minimum_size.y
		) * 0.45))))


func setup(row: int, col: int, cell: DiceCellData, blurred: bool) -> void:
	if _reroll_scramble_active:
		cancel_reroll_scramble()
	grid_row = row
	grid_col = col
	_highlight = Highlight.NONE
	_sync_float_phase()
	_float_disabled = cell.locked
	if cell.locked and not _lock_pop_active:
		pause_float_bob()
	elif not _lock_pop_active and not _float_disabled and not _float_paused:
		resume_float_bob()
	_apply_cell_face(cell, blurred)
	if blurred:
		tooltip_text = ""
	elif cell.no_reroll:
		tooltip_text = "Cannot reroll"
	elif cell.locked:
		tooltip_text = ""
	else:
		tooltip_text = "Click to select · double-click to reroll"


func _apply_cell_face(cell: DiceCellData, blurred: bool) -> void:
	var label: Label = _ensure_value_label()
	var face_tex: TextureRect = _ensure_die_face()
	if label == null or face_tex == null:
		push_error("DieCell: DieFace or ValueLabel missing")
		return
	_blurred = blurred
	if cell.value >= 1 and cell.value <= 7:
		var tex: Texture2D = _face_texture_for(cell.value)
		if tex != null:
			_show_sprite = true
			face_tex.texture = tex
			_base_face_key = FACE_BLURRED if blurred else (
				FACE_LOCKED if cell.locked else FACE_NORMAL
			)
		else:
			_show_sprite = false
			label.text = str(cell.value)
			_configure_value_label_font(blurred)
			_base_face_key = FACE_BLURRED if blurred else (
				FACE_LOCKED if cell.locked else FACE_NORMAL
			)
			_set_fallback_label_colors(cell)
	else:
		_show_sprite = false
		label.text = str(cell.value)
		_configure_value_label_font(blurred)
		_base_face_key = FACE_BLURRED if blurred else (
			FACE_LOCKED if cell.locked else FACE_NORMAL
		)
		_set_fallback_label_colors(cell)
	if _shine:
		_shine.visible = false
	_apply_display()


func play_reroll_scramble(
	row: int,
	col: int,
	final_cell: DiceCellData,
	blurred: bool,
	on_complete: Callable = Callable()
) -> void:
	cancel_reroll_scramble()
	if _lock_pop_active or _swap_overlay_active:
		setup(row, col, final_cell, blurred)
		if on_complete.is_valid():
			on_complete.call()
		return
	pause_float_bob()
	_reroll_scramble_active = true
	_apply_cell_face(DiceCellData.new(randi_range(1, 6), final_cell.locked), blurred)
	_reroll_scramble_tween = create_tween()
	for step in range(REROLL_SCRAMBLE_STEPS):
		_reroll_scramble_tween.tween_callback(
			_reroll_scramble_step.bind(step, row, col, final_cell, blurred, on_complete)
		)
		if step < REROLL_SCRAMBLE_STEPS - 1:
			_reroll_scramble_tween.tween_interval(REROLL_SCRAMBLE_INTERVAL)


func _reroll_scramble_step(
	step: int,
	row: int,
	col: int,
	final_cell: DiceCellData,
	blurred: bool,
	on_complete: Callable
) -> void:
	if not _reroll_scramble_active:
		return
	if step == REROLL_SCRAMBLE_STEPS - 1:
		_reroll_scramble_active = false
		_reroll_scramble_tween = null
		setup(row, col, final_cell, blurred)
		if on_complete.is_valid():
			on_complete.call()
	else:
		var flash_cell := DiceCellData.new(randi_range(1, 6), final_cell.locked)
		_apply_cell_face(flash_cell, blurred)


func cancel_reroll_scramble() -> void:
	_reroll_scramble_active = false
	if _reroll_scramble_tween != null and _reroll_scramble_tween.is_valid():
		_reroll_scramble_tween.kill()
	_reroll_scramble_tween = null


func is_reroll_scramble_active() -> bool:
	return _reroll_scramble_active


func _set_fallback_label_colors(cell: DiceCellData) -> void:
	var label: Label = _ensure_value_label()
	if label == null:
		return
	if cell.value == 7:
		label.add_theme_color_override("font_color", Color(0.55, 0.12, 0.15))
	elif _is_pixel_font_style():
		if cell.locked:
			label.add_theme_color_override("font_color", Color(0.5, 0.53, 0.58))
		else:
			label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
	elif cell.locked:
		label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
	else:
		label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.18))


func set_highlight(h: Highlight) -> void:
	_highlight = h
	_apply_display()


func set_selected(selected: bool) -> void:
	set_highlight(Highlight.SELECTED if selected else Highlight.NONE)


func set_swap_overlay(cell: DiceCellData) -> void:
	_swap_overlay_active = true
	_configure_swap_overlay(cell)
	if _swap_overlay != null:
		_swap_overlay.visible = true
	_apply_display()


func commit_swap_result(cell: DiceCellData, blurred: bool) -> void:
	pause_float_bob()
	set_swap_overlay(cell)
	setup(grid_row, grid_col, cell, blurred)
	var wrap := _ensure_wrap()
	if wrap != null:
		wrap.position = Vector2.ZERO
	call_deferred("_deferred_commit_uncover")


func _deferred_commit_uncover() -> void:
	clear_swap_overlay()
	resume_float_bob()


func clear_swap_overlay() -> void:
	_swap_overlay_active = false
	if _swap_overlay != null:
		_swap_overlay.visible = false
	_apply_display()


func _configure_swap_overlay(cell: DiceCellData) -> void:
	if _overlay_face == null or _overlay_label == null:
		return
	if _overlay_backdrop != null:
		_overlay_backdrop.color = (
			Color(0.82, 0.84, 0.88) if cell.locked else Color(0.96, 0.97, 0.99)
		)
	var tex: Texture2D = _face_texture_for(cell.value)
	if tex != null:
		_overlay_face.texture = tex
		_overlay_face.visible = true
		_overlay_face.modulate = (
			Color(0.78, 0.8, 0.86) if cell.locked else Color.WHITE
		)
		_overlay_label.visible = false
	else:
		_overlay_face.visible = false
		_overlay_label.visible = true
		_overlay_label.text = str(cell.value)
		_configure_overlay_label_font(cell)


func _configure_overlay_label_font(cell: DiceCellData) -> void:
	if _overlay_label == null:
		return
	var sprites := _dice_sprite_settings()
	if sprites != null and sprites.is_pixel_font_style():
		var font: Font = sprites.get_pixel_font()
		if font != null:
			_overlay_label.add_theme_font_override("font", font)
		var cell_px: float = maxf(custom_minimum_size.x, custom_minimum_size.y)
		_overlay_label.add_theme_font_size_override(
			"font_size", maxi(16, int(round(cell_px * 0.58)))
		)
	else:
		_overlay_label.remove_theme_font_override("font")
		_overlay_label.add_theme_font_size_override(
			"font_size",
			maxi(16, int(round(maxf(custom_minimum_size.x, custom_minimum_size.y) * 0.45)))
		)
	if cell.value == 7:
		_overlay_label.add_theme_color_override("font_color", Color(0.55, 0.12, 0.15))
	elif _is_pixel_font_style():
		if cell.locked:
			_overlay_label.add_theme_color_override("font_color", Color(0.5, 0.53, 0.58))
		else:
			_overlay_label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
	elif cell.locked:
		_overlay_label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
	else:
		_overlay_label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.18))


func play_swap_to(
	target_offset: Vector2,
	duration: float = SWAP_SLIDE_DURATION,
	on_complete: Callable = Callable()
) -> Tween:
	var wrap := _ensure_wrap()
	if wrap == null:
		if on_complete.is_valid():
			on_complete.call()
		return null
	if _swap_tween != null and _swap_tween.is_valid():
		_swap_tween.kill()
	pause_float_bob()
	wrap.position = Vector2.ZERO
	_swap_tween = create_tween()
	_swap_tween.tween_property(
		wrap, "position", target_offset, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_swap_tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)
	return _swap_tween


func _ensure_wrap() -> Control:
	if _wrap == null:
		_wrap = get_node_or_null("Wrap") as Control
	return _wrap


func _apply_display() -> void:
	if _face == null:
		_face = get_node_or_null("Wrap/FloatRoot/Face") as PanelContainer
	var face_key: String = _base_face_key
	match _highlight:
		Highlight.SELECTED:
			face_key = FACE_SELECTED
		Highlight.SWITCH_VALID:
			face_key = FACE_SWITCH_VALID
		Highlight.SWITCH_ROWS_PRIMARY:
			face_key = FACE_SWITCH_ROWS_PRIMARY
		Highlight.SWITCH_ROWS_PICKABLE:
			face_key = FACE_SWITCH_ROWS_PICKABLE
		Highlight.POWER_CHOOSE:
			face_key = FACE_POWER_CHOOSE
		Highlight.POWER_SET_ANY:
			face_key = FACE_POWER_SET_ANY
		Highlight.POWER_SWITCH_ANY:
			face_key = FACE_POWER_SWITCH_ANY
	face_key = _resolve_face_key(face_key)
	var panel_style: StyleBox = _panel_style_for_face(face_key)
	if _face and panel_style != null:
		_face.add_theme_stylebox_override("panel", panel_style)
	_face.visible = not _swap_overlay_active
	_update_pixel_border(face_key)
	var face_tex: TextureRect = _ensure_die_face()
	var label: Label = _ensure_value_label()
	var blur_mat: ShaderMaterial = _blur_material_for_display() if _blurred else null
	var hide_base: bool = _swap_overlay_active
	if hide_base:
		if face_tex:
			face_tex.visible = false
		if label:
			label.visible = false
	elif face_tex:
		face_tex.visible = _show_sprite
		face_tex.modulate = _sprite_modulate(face_key)
		face_tex.material = blur_mat
		if label:
			label.visible = not _show_sprite
			label.material = blur_mat if _blurred and not _show_sprite else null
	elif label:
		label.visible = not _show_sprite
		label.material = blur_mat if _blurred and not _show_sprite else null
	var big: bool = (
		_highlight == Highlight.SELECTED
		or _highlight == Highlight.SWITCH_VALID
		or _highlight == Highlight.SWITCH_ROWS_PRIMARY
	)
	scale = Vector2(1.08, 1.08) if big else Vector2.ONE


func _sprite_modulate(face_key: String) -> Color:
	if face_key == FACE_LOCKED or face_key == PIXEL_FACE_LOCKED:
		return Color(0.78, 0.8, 0.86)
	return Color.WHITE


func _blur_material_for_display() -> ShaderMaterial:
	if _blur_material == null:
		_blur_material = ShaderMaterial.new()
		_blur_material.shader = DIE_BLUR_SHADER
		_blur_material.set_shader_parameter("blur_amount", 4.5)
	return _blur_material


func _ensure_die_face() -> TextureRect:
	if die_face != null:
		return die_face
	die_face = get_node_or_null("Wrap/FloatRoot/Face/Margin/DieFace") as TextureRect
	return die_face


func _ensure_value_label() -> Label:
	if value_label != null:
		return value_label
	value_label = get_node_or_null("Wrap/FloatRoot/ValueLabel") as Label
	return value_label
