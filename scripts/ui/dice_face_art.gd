class_name DiceFaceArt
extends RefCounted

const SIZE := 64

static var _cache: Dictionary = {}

# 3x3 grid positions for a standard seven-pip die face (2-3-2 layout).
const PIP_LAYOUT_7: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(2, 2),
]


static func get_pip_face(value: int) -> Texture2D:
	if value != 7:
		return null
	var key := "pip_%d" % value
	if _cache.has(key):
		return _cache[key] as Texture2D
	var tex: ImageTexture = _build_pip_face(value)
	_cache[key] = tex
	return tex


static func _build_pip_face(value: int) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var face := Color(0.98, 0.98, 0.98, 1)
	var border := Color(0.08, 0.08, 0.1, 1)
	var pip := Color(0.08, 0.08, 0.1, 1)
	_fill_rect(img, 4, 4, SIZE - 5, SIZE - 5, border)
	_fill_rect(img, 6, 6, SIZE - 7, SIZE - 7, face)
	var layout: Array[Vector2i] = PIP_LAYOUT_7 if value == 7 else []
	var margin := 14
	var span := SIZE - margin * 2
	var cell := span / 2
	var pip_r := 4
	for pos in layout:
		var cx := margin + pos.x * cell
		var cy := margin + pos.y * cell
		_draw_pip(img, cx, cy, pip_r, pip)
	return ImageTexture.create_from_image(img)


static func _draw_pip(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if Vector2(x - cx, y - cy).length() <= float(radius) + 0.35:
				_px(img, x, y, color)


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	img.set_pixel(x, y, color)


static func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(img, x, y, color)
