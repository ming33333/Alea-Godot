class_name PixelDieFrame
extends Control

var frame_color: Color = Color(0.28, 0.3, 0.34)
var line_thickness: int = 3
var corner_radius: int = 2


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var w: int = int(size.x)
	var h: int = int(size.y)
	var thick: int = maxi(1, line_thickness)
	var radius: int = maxi(1, mini(corner_radius, thick))
	if w < thick * 2 or h < thick * 2:
		return

	for row in range(thick):
		var inset: int = maxi(0, radius - row)
		var width: int = w - inset * 2
		if width > 0:
			draw_rect(Rect2(inset, row, width, 1), frame_color)
			draw_rect(Rect2(inset, h - 1 - row, width, 1), frame_color)

	for col in range(thick):
		var inset: int = maxi(0, radius - col)
		var height: int = h - inset * 2
		if height > 0:
			draw_rect(Rect2(col, inset, 1, height), frame_color)
			draw_rect(Rect2(w - 1 - col, inset, 1, height), frame_color)
