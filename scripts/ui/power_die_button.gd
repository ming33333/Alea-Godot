class_name PowerDieButton
extends Button

const FACE_IDLE := "idle"
const FACE_ACTIVE := "active"
const FACE_DISABLED := "disabled"

var _face: PanelContainer
var _title_label: Label
var _charge_label: Label
var _styles: Dictionary = {}


func _ready() -> void:
	_cache_styles()
	_face = get_node_or_null("Wrap/Face") as PanelContainer
	_title_label = get_node_or_null("Wrap/Face/Margin/VBox/TitleLabel") as Label
	_charge_label = get_node_or_null("Wrap/Face/Margin/VBox/ChargeLabel") as Label
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	flat = true
	focus_mode = Control.FOCUS_NONE


func _cache_styles() -> void:
	_styles[FACE_IDLE] = _make_die_style(Color(1, 1, 1, 0), Color(0.52, 0.55, 0.6), 2, 3)
	_styles[FACE_DISABLED] = _make_die_style(Color(1, 1, 1, 0), Color(0.65, 0.68, 0.72), 2, 2)
	_styles[FACE_ACTIVE] = _make_die_style(Color(1, 1, 1, 0), Color(0.15, 0.4, 0.92), 4, 8)


func _make_die_style(
	bg: Color, border: Color, border_w: int, shadow_size: int
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.22)
	box.shadow_size = shadow_size
	box.shadow_offset = Vector2(0, 2)
	return box


func setup_display(
	title: String,
	charge_text: String,
	is_active: bool,
	is_disabled: bool,
	accent: Color
) -> void:
	if _title_label == null:
		_title_label = get_node_or_null("Wrap/Face/Margin/VBox/TitleLabel") as Label
	if _charge_label == null:
		_charge_label = get_node_or_null("Wrap/Face/Margin/VBox/ChargeLabel") as Label
	if _face == null:
		_face = get_node_or_null("Wrap/Face") as PanelContainer
	if _title_label:
		_title_label.text = title
	if _charge_label:
		_charge_label.text = charge_text
		_charge_label.visible = not charge_text.is_empty()
	disabled = is_disabled
	var face_key: String = FACE_DISABLED if is_disabled else (FACE_ACTIVE if is_active else FACE_IDLE)
	if _face and _styles.has(face_key):
		var style: StyleBoxFlat = _styles[face_key].duplicate() as StyleBoxFlat
		if is_active and style:
			style.border_color = accent
			style.shadow_color = accent.darkened(0.35)
		_face.add_theme_stylebox_override("panel", style)
	scale = Vector2(1.06, 1.06) if is_active else Vector2.ONE


func set_chip_size(pixel_size: int) -> void:
	custom_minimum_size = Vector2(pixel_size, pixel_size)
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
