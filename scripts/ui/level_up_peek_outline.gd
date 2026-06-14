class_name LevelUpPeekOutline
extends Control

signal restore_requested


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _draw() -> void:
	var inset := 1.0
	var rect := Rect2(
		Vector2(inset, inset),
		size - Vector2(inset * 2.0, inset * 2.0)
	)
	_draw_dashed_rect(rect, Color(1.0, 1.0, 1.0, 0.92), 2.0, 10.0, 7.0)


func _draw_dashed_rect(
	rect: Rect2,
	color: Color,
	width: float,
	dash_len: float,
	gap_len: float
) -> void:
	_draw_dashed_segment(rect.position, rect.position + Vector2(rect.size.x, 0.0), color, width, dash_len, gap_len)
	_draw_dashed_segment(
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		color,
		width,
		dash_len,
		gap_len
	)
	_draw_dashed_segment(
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
		color,
		width,
		dash_len,
		gap_len
	)
	_draw_dashed_segment(rect.position + Vector2(0.0, rect.size.y), rect.position, color, width, dash_len, gap_len)


func _draw_dashed_segment(
	from: Vector2,
	to: Vector2,
	color: Color,
	width: float,
	dash_len: float,
	gap_len: float
) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		return
	var dir := delta / length
	var traveled := 0.0
	var drawing := true
	while traveled < length:
		var segment := dash_len if drawing else gap_len
		segment = minf(segment, length - traveled)
		if drawing:
			var start := from + dir * traveled
			var end := from + dir * (traveled + segment)
			draw_line(start, end, color, width, true)
		traveled += segment
		drawing = not drawing


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			restore_requested.emit()
			get_viewport().set_input_as_handled()
