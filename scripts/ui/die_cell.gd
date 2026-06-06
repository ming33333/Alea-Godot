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

const DICE_BOARD_ATLAS: Texture2D = preload("res://assets/textures/dice_board.png")
const DICE_BOARD_TILE_REGION := Rect2(124, 130, 264, 258)

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
var _shine: ColorRect
var _styles: Dictionary = {}
var _base_face_key: String = FACE_NORMAL
var _highlight: Highlight = Highlight.NONE
var _show_sprite: bool = true
var grid_row: int = -1
var grid_col: int = -1


func _ready() -> void:
	_cache_styles()
	_face = get_node_or_null("Wrap/Face") as PanelContainer
	_shine = get_node_or_null("Wrap/Shine") as ColorRect
	die_face = get_node_or_null("Wrap/Face/Margin/DieFace") as TextureRect
	value_label = get_node_or_null("Wrap/ValueLabel") as Label
	if _face:
		_face.add_theme_stylebox_override("panel", _styles[FACE_NORMAL])
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)


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
	_styles[FACE_BLURRED] = _make_face_style(
		Color(0.94, 0.94, 0.96),
		Color(0.6, 0.62, 0.68),
		3,
		12
	)
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


func _face_texture_for(value: int) -> Texture2D:
	var sprites := _dice_sprite_settings()
	if sprites == null:
		return null
	return sprites.get_face(value)


func _dice_sprite_settings() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("DiceSprites")


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
	grid_row = row
	grid_col = col
	_highlight = Highlight.NONE
	var label: Label = _ensure_value_label()
	var face_tex: TextureRect = _ensure_die_face()
	if label == null or face_tex == null:
		push_error("DieCell: DieFace or ValueLabel missing")
		return
	if blurred:
		_show_sprite = false
		_base_face_key = FACE_BLURRED
		label.text = "?"
		_configure_value_label_font(blurred)
		label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.45))
	elif cell.value >= 1 and cell.value <= 7:
		var tex: Texture2D = _face_texture_for(cell.value)
		if tex != null:
			_show_sprite = true
			face_tex.texture = tex
			_base_face_key = FACE_LOCKED if cell.locked else FACE_NORMAL
		else:
			_show_sprite = false
			label.text = str(cell.value)
			_configure_value_label_font(blurred)
			_base_face_key = FACE_LOCKED if cell.locked else FACE_NORMAL
			_set_fallback_label_colors(cell)
	else:
		_show_sprite = false
		label.text = str(cell.value)
		_configure_value_label_font(blurred)
		_base_face_key = FACE_LOCKED if cell.locked else FACE_NORMAL
		_set_fallback_label_colors(cell)
	if _shine:
		_shine.visible = false
	if blurred:
		tooltip_text = ""
	elif cell.no_reroll:
		tooltip_text = "Cannot reroll"
	elif cell.locked:
		tooltip_text = ""
	else:
		tooltip_text = "Click to select · double-click to reroll"
	_apply_display()


func _set_fallback_label_colors(cell: DiceCellData) -> void:
	var label: Label = _ensure_value_label()
	if label == null:
		return
	if cell.value == 7:
		label.add_theme_color_override("font_color", Color(0.55, 0.12, 0.15))
	elif cell.locked:
		label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
	else:
		label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.18))


func set_highlight(h: Highlight) -> void:
	_highlight = h
	_apply_display()


func set_selected(selected: bool) -> void:
	set_highlight(Highlight.SELECTED if selected else Highlight.NONE)


func _apply_display() -> void:
	if _face == null:
		_face = get_node_or_null("Wrap/Face") as PanelContainer
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
	if _face and _styles.has(face_key):
		_face.add_theme_stylebox_override("panel", _styles[face_key])
	var face_tex: TextureRect = _ensure_die_face()
	var label: Label = _ensure_value_label()
	if face_tex:
		face_tex.visible = _show_sprite
		face_tex.modulate = _sprite_modulate(face_key)
	if label:
		label.visible = not _show_sprite
	var big: bool = (
		_highlight == Highlight.SELECTED
		or _highlight == Highlight.SWITCH_VALID
		or _highlight == Highlight.SWITCH_ROWS_PRIMARY
	)
	scale = Vector2(1.08, 1.08) if big else Vector2.ONE


func _sprite_modulate(face_key: String) -> Color:
	if face_key == FACE_LOCKED:
		return Color(0.78, 0.8, 0.86)
	if face_key == FACE_BLURRED:
		return Color(0.55, 0.58, 0.65)
	return Color.WHITE


func _ensure_die_face() -> TextureRect:
	if die_face != null:
		return die_face
	die_face = get_node_or_null("Wrap/Face/Margin/DieFace") as TextureRect
	return die_face


func _ensure_value_label() -> Label:
	if value_label != null:
		return value_label
	value_label = get_node_or_null("Wrap/ValueLabel") as Label
	return value_label
