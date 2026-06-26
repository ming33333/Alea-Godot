class_name CrownPickTile
extends Button

signal hovered(crown_index: int)
signal unhovered(crown_index: int)

const BRACKET_COLOR := Color(0.98, 0.86, 0.12, 1.0)
const BRACKET_LEN := 14.0
const BRACKET_THICK := 3.0
const TILE_W := 108
const TILE_H := 132

var crown_index: int = 0

var _selected: bool = false
var _locked_out: bool = false
var _earned: bool = false

@onready var _crown_sprite: TextureRect = %CrownSprite
@onready var _name_label: Label = %NameLabel


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = false
	toggle_mode = false
	custom_minimum_size = Vector2(TILE_W, TILE_H)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_panel_styles()


func setup(crown_index_val: int, label: String) -> void:
	crown_index = crown_index_val
	if _crown_sprite == null:
		_crown_sprite = get_node_or_null("%CrownSprite") as TextureRect
	if _name_label == null:
		_name_label = get_node_or_null("%NameLabel") as Label
	var tex: Texture2D = DiceCrownArt.get_texture(crown_index)
	if _crown_sprite:
		_crown_sprite.texture = tex
		_crown_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _name_label:
		_name_label.text = label


func set_tile_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()
	_refresh_modulate()


func set_locked_out(locked: bool) -> void:
	if _earned:
		return
	_locked_out = locked
	disabled = locked
	_refresh_modulate()


func set_tile_earned(earned: bool) -> void:
	_earned = earned
	if earned:
		disabled = true
		_locked_out = false
		_selected = false
		queue_redraw()
	_refresh_modulate()


func _refresh_modulate() -> void:
	if _earned:
		modulate = Color(1.0, 0.98, 0.82, 1.0)
	elif _locked_out:
		modulate = Color(0.48, 0.5, 0.54, 0.72)
	elif _selected:
		modulate = Color(1.04, 1.02, 0.96, 1.0)
	else:
		modulate = Color.WHITE


func _on_mouse_entered() -> void:
	if not _locked_out and not _earned:
		hovered.emit(crown_index)


func _on_mouse_exited() -> void:
	unhovered.emit(crown_index)


func _draw() -> void:
	if not _selected or _earned:
		return
	var r := Rect2(Vector2.ZERO, size)
	var pad := 3.0
	var x0 := pad
	var y0 := pad
	var x1: float = r.size.x - pad
	var y1: float = r.size.y - pad
	var c := BRACKET_COLOR
	var L := BRACKET_LEN
	var t := BRACKET_THICK
	draw_line(Vector2(x0, y0 + t * 0.5), Vector2(x0 + L, y0 + t * 0.5), c, t)
	draw_line(Vector2(x0 + t * 0.5, y0), Vector2(x0 + t * 0.5, y0 + L), c, t)
	draw_line(Vector2(x1 - L, y0 + t * 0.5), Vector2(x1, y0 + t * 0.5), c, t)
	draw_line(Vector2(x1 - t * 0.5, y0), Vector2(x1 - t * 0.5, y0 + L), c, t)
	draw_line(Vector2(x0, y1 - t * 0.5), Vector2(x0 + L, y1 - t * 0.5), c, t)
	draw_line(Vector2(x0 + t * 0.5, y1 - L), Vector2(x0 + t * 0.5, y1), c, t)
	draw_line(Vector2(x1 - L, y1 - t * 0.5), Vector2(x1, y1 - t * 0.5), c, t)
	draw_line(Vector2(x1 - t * 0.5, y1 - L), Vector2(x1 - t * 0.5, y1), c, t)


func _apply_panel_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.15, 0.18, 0.96)
	normal.border_color = Color(0.42, 0.46, 0.52, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 6.0
	normal.content_margin_top = 8.0
	normal.content_margin_right = 6.0
	normal.content_margin_bottom = 6.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.22, 0.28, 0.98)
	hover.border_color = Color(0.72, 0.76, 0.84, 1.0)
	var pressed_style := hover.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.26, 0.24, 0.18, 1.0)
	pressed_style.border_color = Color(0.95, 0.82, 0.38, 1.0)
	var disabled_box := normal.duplicate() as StyleBoxFlat
	disabled_box.bg_color = Color(0.12, 0.13, 0.16, 0.55)
	disabled_box.border_color = Color(0.32, 0.34, 0.38, 0.45)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_box)
