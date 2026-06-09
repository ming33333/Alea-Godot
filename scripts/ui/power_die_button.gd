class_name PowerDieButton
extends Button

const DICE_BOARD_ATLAS: Texture2D = preload("res://assets/textures/dice_board.png")
const DICE_BOARD_TILE_REGION := Rect2(124, 130, 264, 258)

var _face: PanelContainer
var _pixel_border: PixelDieFrame
var _title_label: Label
var _charge_label: Label
var _board_face_style: StyleBoxTexture
var _accent: Color = Color(0.45, 0.48, 0.55)
var _is_active: bool = false
var _is_disabled_state: bool = false


func _ready() -> void:
	_face = get_node_or_null("Wrap/Face") as PanelContainer
	_pixel_border = get_node_or_null("Wrap/PixelBorder") as PixelDieFrame
	_title_label = get_node_or_null("Wrap/Face/Margin/VBox/TitleLabel") as Label
	_charge_label = get_node_or_null("Wrap/Face/Margin/VBox/ChargeLabel") as Label
	_board_face_style = _make_board_face_style()
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	flat = true
	focus_mode = Control.FOCUS_NONE
	if not DiceSprites.style_changed.is_connected(_on_dice_style_changed):
		DiceSprites.style_changed.connect(_on_dice_style_changed)


func _on_dice_style_changed() -> void:
	_apply_face_style()


func setup_display(
	title: String,
	charge_text: String,
	is_active: bool,
	chip_disabled: bool,
	accent: Color
) -> void:
	if _title_label == null:
		_title_label = get_node_or_null("Wrap/Face/Margin/VBox/TitleLabel") as Label
	if _charge_label == null:
		_charge_label = get_node_or_null("Wrap/Face/Margin/VBox/ChargeLabel") as Label
	if _title_label:
		_title_label.text = title
	if _charge_label:
		_charge_label.text = charge_text
		_charge_label.visible = not charge_text.is_empty()
	disabled = chip_disabled
	_accent = accent
	_is_active = is_active
	_is_disabled_state = chip_disabled
	_apply_face_style()
	scale = Vector2(1.06, 1.06) if is_active else Vector2.ONE


func set_chip_size(pixel_size: int) -> void:
	var square := Vector2(pixel_size, pixel_size)
	custom_minimum_size = square
	size = square
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _title_label == null:
		_title_label = get_node_or_null("Wrap/Face/Margin/VBox/TitleLabel") as Label
	if _charge_label == null:
		_charge_label = get_node_or_null("Wrap/Face/Margin/VBox/ChargeLabel") as Label
	var title_font: int = maxi(7, int(round(float(pixel_size) * 0.14)))
	var charge_font: int = maxi(8, int(round(float(pixel_size) * 0.16)))
	if _title_label:
		_title_label.add_theme_font_size_override("font_size", title_font)
	if _charge_label:
		_charge_label.add_theme_font_size_override("font_size", charge_font)
	_update_pixel_border_metrics(pixel_size)
	_configure_fonts()


func _apply_face_style() -> void:
	if _face == null:
		_face = get_node_or_null("Wrap/Face") as PanelContainer
	if _face == null:
		return
	if _is_pixel_font_style():
		_apply_pixel_face()
	else:
		_apply_board_face()
	_configure_fonts()


func _apply_pixel_face() -> void:
	if _pixel_border:
		_pixel_border.visible = true
	var tint: float = 0.42 if _is_active else 0.32
	var face_bg: Color = Color.WHITE.lerp(_accent, tint)
	if _is_disabled_state:
		face_bg = face_bg.lerp(Color(0.9, 0.91, 0.93), 0.45)
	var style := StyleBoxFlat.new()
	style.bg_color = face_bg
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.anti_aliasing = false
	_face.add_theme_stylebox_override("panel", style)
	if _pixel_border:
		var border_color: Color = _accent if _is_active else _accent.darkened(0.08)
		if _is_disabled_state:
			border_color = Color(0.62, 0.65, 0.7)
		_pixel_border.frame_color = border_color
		_pixel_border.queue_redraw()
	if _title_label:
		_title_label.add_theme_color_override("font_color", _title_font_color())
	if _charge_label:
		_charge_label.add_theme_color_override("font_color", _charge_font_color())


func _apply_board_face() -> void:
	if _pixel_border:
		_pixel_border.visible = false
	var tint: float = 0.38 if _is_active else 0.28
	var face_bg: Color = Color.WHITE.lerp(_accent, tint)
	if _is_disabled_state:
		face_bg = face_bg.lerp(Color(0.9, 0.91, 0.93), 0.45)
	var style := StyleBoxFlat.new()
	style.bg_color = face_bg
	style.set_border_width_all(2)
	style.border_color = _accent.darkened(0.1) if not _is_disabled_state else Color(0.62, 0.65, 0.7)
	style.set_corner_radius_all(maxi(4, int(round(custom_minimum_size.x * 0.08))))
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	_face.add_theme_stylebox_override("panel", style)
	if _title_label:
		_title_label.add_theme_color_override("font_color", _title_font_color())
	if _charge_label:
		_charge_label.add_theme_color_override("font_color", _charge_font_color())


func _title_font_color() -> Color:
	if _is_disabled_state:
		return Color(0.4, 0.42, 0.46)
	return Color(0.04, 0.06, 0.1)


func _charge_font_color() -> Color:
	if _is_disabled_state:
		return Color(0.46, 0.48, 0.52)
	return Color(0.08, 0.1, 0.14)


func _configure_fonts() -> void:
	if _title_label == null and _charge_label == null:
		return
	if _is_pixel_font_style():
		var font: Font = DiceSprites.get_pixel_font()
		if font != null:
			if _title_label:
				_title_label.add_theme_font_override("font", font)
			if _charge_label:
				_charge_label.add_theme_font_override("font", font)
	else:
		if _title_label:
			_title_label.remove_theme_font_override("font")
		if _charge_label:
			_charge_label.remove_theme_font_override("font")


func _update_pixel_border_metrics(chip_px: int) -> void:
	if _pixel_border == null:
		return
	_pixel_border.line_thickness = maxi(2, int(round(float(chip_px) * 0.034)))
	_pixel_border.corner_radius = maxi(1, int(round(float(chip_px) * 0.028)))


func _is_pixel_font_style() -> bool:
	return DiceSprites.is_pixel_font_style()


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
