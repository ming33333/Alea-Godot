class_name PowerSpeechBubble
extends Control

const TAIL_H := 9.0
const TAIL_W := 16.0
const BUBBLE_MIN_W := 152.0
const BUBBLE_MAX_W := 220.0
const SHOW_TWEEN_SEC := 0.2

var _panel: PanelContainer
var _label: Label
var _accent: Color = Color(0.2, 0.35, 0.55)
var _die_px: int = 116
var _shown: bool = false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 8
	_panel = get_node_or_null("Panel") as PanelContainer
	_label = get_node_or_null("Panel/Margin/Label") as Label
	visible = false
	modulate.a = 0.0


func configure(die_px: int) -> void:
	_die_px = die_px
	if _label:
		var font_size: int = maxi(9, int(round(float(die_px) * 0.11)))
		_label.add_theme_font_size_override("font_size", font_size)
	_relayout()


func show_message(text: String, accent: Color, animate: bool = true) -> void:
	if text.is_empty():
		hide_message()
		return
	_accent = accent
	if _label:
		_label.text = text
	_apply_panel_style()
	_relayout()
	var was_shown: bool = _shown
	_shown = true
	visible = true
	if was_shown:
		return
	if animate:
		_animate_in()
	else:
		if _tween and _tween.is_valid():
			_tween.kill()
		scale = Vector2.ONE
		modulate.a = 1.0


func hide_message(instant: bool = false) -> void:
	if not _shown and not visible:
		return
	_shown = false
	if instant:
		if _tween and _tween.is_valid():
			_tween.kill()
		visible = false
		modulate.a = 0.0
		scale = Vector2.ONE
		return
	_animate_out()


func _apply_panel_style() -> void:
	if _panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.92, 0.98)
	style.border_color = _accent.lerp(Color(0.92, 0.88, 0.82), 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 6
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)
	if _label:
		var text_color: Color = _accent.darkened(0.15)
		_label.add_theme_color_override("font_color", text_color)


func _relayout() -> void:
	if _panel == null or _label == null:
		return
	var max_text_w: float = BUBBLE_MAX_W - 20.0
	_label.custom_minimum_size = Vector2(max_text_w, 0.0)
	_panel.reset_size()
	var panel_size: Vector2 = _panel.get_minimum_size()
	var bubble_w: float = clampf(maxf(panel_size.x, BUBBLE_MIN_W), BUBBLE_MIN_W, BUBBLE_MAX_W)
	_panel.custom_minimum_size = Vector2(bubble_w, panel_size.y)
	_panel.size = _panel.custom_minimum_size
	custom_minimum_size = Vector2(bubble_w, panel_size.y + TAIL_H)
	size = custom_minimum_size
	position = Vector2((float(_die_px) - bubble_w) * 0.5, -custom_minimum_size.y - 4.0)
	pivot_offset = Vector2(bubble_w * 0.5, custom_minimum_size.y)
	queue_redraw()


func _draw() -> void:
	var panel_h: float = _panel.size.y if _panel else size.y - TAIL_H
	var center_x: float = size.x * 0.5
	var top_y: float = panel_h - 1.0
	var fill: Color = Color(0.98, 0.96, 0.92, 0.98)
	var points := PackedVector2Array([
		Vector2(center_x - TAIL_W * 0.5, top_y),
		Vector2(center_x + TAIL_W * 0.5, top_y),
		Vector2(center_x, size.y),
	])
	draw_colored_polygon(points, fill)
	var border: Color = _accent.lerp(Color(0.92, 0.88, 0.82), 0.25)
	draw_line(points[0], points[2], border, 2.0, true)
	draw_line(points[2], points[1], border, 2.0, true)


func _animate_in() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = Vector2(0.82, 0.82)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, SHOW_TWEEN_SEC)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, SHOW_TWEEN_SEC * 0.85)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_out() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		scale = Vector2.ONE
	)
