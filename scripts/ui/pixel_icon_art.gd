class_name PixelIconArt
extends RefCounted

const SIZE := 24

static var _cache: Dictionary = {}


static func get_icon(icon_id: String) -> Texture2D:
	if icon_id.is_empty():
		return null
	if _cache.has(icon_id):
		return _cache[icon_id] as Texture2D
	var tex: ImageTexture = _build(icon_id)
	_cache[icon_id] = tex
	return tex


static func get_opponent_icon(opponent_id: String) -> Texture2D:
	return get_icon(opponent_id)


static func apply_texture_rect(rect: TextureRect, icon_id: String, px: int = SIZE) -> void:
	if rect == null:
		return
	rect.texture = get_icon(icon_id)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


static func _build(icon_id: String) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match icon_id:
		"heart":
			_draw_heart(img)
		"wrench":
			_draw_wrench(img)
		"crown":
			_draw_crown(img)
		"celebrate":
			_draw_celebrate(img)
		"broken_heart":
			_draw_broken_heart(img)
		"dizzy":
			_draw_dizzy(img)
		"swords":
			_draw_swords(img)
		"luckySeven":
			_draw_lucky_seven(img)
		"straightSpecialist":
			_draw_straight_specialist(img)
		"fullHouseSpecialist":
			_draw_full_house(img)
		"fiveOfAKindRequired":
			_draw_five_kind(img)
		"noThreeRepeats":
			_draw_puzzle(img)
		"rerollChaos":
			_draw_spiral(img)
		"blurPerReroll":
			_draw_fog(img)
		"close":
			_draw_close(img)
		"arrow_right":
			_draw_arrow_right(img)
		_:
			_draw_fallback(img)
	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	img.set_pixel(x, y, color)


static func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(img, x, y, color)


static func _draw_heart(img: Image) -> void:
	var red := Color(0.86, 0.18, 0.24)
	var dark := Color(0.55, 0.08, 0.14)
	_fill_rect(img, 7, 6, 10, 9, red)
	_fill_rect(img, 13, 6, 16, 9, red)
	_fill_rect(img, 6, 8, 17, 12, red)
	_fill_rect(img, 7, 13, 16, 15, red)
	_fill_rect(img, 9, 16, 14, 17, red)
	_fill_rect(img, 11, 18, 12, 19, red)
	_px(img, 6, 10, dark)
	_px(img, 17, 10, dark)


static func _draw_broken_heart(img: Image) -> void:
	_draw_heart(img)
	var crack := Color(0.16, 0.12, 0.14)
	for i in 6:
		_px(img, 11 + i, 8 + i, crack)
		_px(img, 10 + i, 8 + i, crack)


static func _draw_wrench(img: Image) -> void:
	var metal := Color(0.72, 0.76, 0.82)
	var dark := Color(0.42, 0.46, 0.54)
	_fill_rect(img, 4, 4, 8, 8, metal)
	_fill_rect(img, 5, 9, 7, 11, metal)
	for i in 8:
		_px(img, 8 + i, 11 + i, metal)
		_px(img, 9 + i, 11 + i, dark)
	_fill_rect(img, 15, 17, 18, 19, metal)


static func _draw_crown(img: Image) -> void:
	var gold := Color(0.95, 0.82, 0.34)
	var dark := Color(0.62, 0.46, 0.12)
	_fill_rect(img, 5, 14, 18, 17, gold)
	_px(img, 6, 10, gold)
	_px(img, 11, 7, gold)
	_px(img, 17, 10, gold)
	_fill_rect(img, 7, 11, 8, 13, gold)
	_fill_rect(img, 11, 8, 12, 13, gold)
	_fill_rect(img, 15, 11, 16, 13, gold)
	_px(img, 5, 14, dark)
	_px(img, 18, 14, dark)


static func _draw_celebrate(img: Image) -> void:
	var gold := Color(0.95, 0.82, 0.34)
	var blue := Color(0.42, 0.62, 0.92)
	_fill_rect(img, 10, 5, 13, 8, gold)
	_fill_rect(img, 5, 9, 8, 12, blue)
	_fill_rect(img, 16, 9, 19, 12, blue)
	_fill_rect(img, 8, 14, 11, 17, gold)
	_fill_rect(img, 13, 14, 16, 17, gold)
	_px(img, 11, 10, gold)
	_px(img, 12, 10, gold)


static func _draw_dizzy(img: Image) -> void:
	var face := Color(0.92, 0.78, 0.34)
	var dark := Color(0.28, 0.2, 0.12)
	_fill_rect(img, 6, 7, 17, 16, face)
	_px(img, 8, 10, dark)
	_px(img, 15, 10, dark)
	_px(img, 9, 14, dark)
	_px(img, 13, 14, dark)
	_px(img, 11, 15, dark)
	_px(img, 16, 5, Color(0.55, 0.72, 0.92))
	_px(img, 18, 7, Color(0.55, 0.72, 0.92))


static func _draw_swords(img: Image) -> void:
	var blade := Color(0.78, 0.82, 0.9)
	var hilt := Color(0.62, 0.42, 0.2)
	for i in 9:
		_px(img, 5 + i, 15 - i, blade)
		_px(img, 18 - i, 15 - i, blade)
	_fill_rect(img, 10, 14, 13, 16, hilt)
	_fill_rect(img, 11, 16, 12, 19, hilt)


static func _draw_lucky_seven(img: Image) -> void:
	var frame := Color(0.72, 0.18, 0.28)
	var face := Color(0.98, 0.94, 0.82)
	_fill_rect(img, 5, 5, 18, 18, frame)
	_fill_rect(img, 7, 7, 16, 16, face)
	_fill_rect(img, 9, 10, 14, 14, Color(0.2, 0.24, 0.34))
	_fill_rect(img, 10, 11, 11, 13, face)
	_fill_rect(img, 12, 11, 13, 13, face)


static func _draw_straight_specialist(img: Image) -> void:
	var line := Color(0.42, 0.58, 0.88)
	_fill_rect(img, 5, 11, 18, 12, line)
	_fill_rect(img, 5, 8, 6, 15, line)
	_fill_rect(img, 17, 8, 18, 15, line)
	for x in range(7, 17):
		_px(img, x, 10, Color(0.95, 0.82, 0.34))


static func _draw_full_house(img: Image) -> void:
	var wall := Color(0.82, 0.58, 0.36)
	var roof := Color(0.72, 0.22, 0.2)
	_fill_rect(img, 8, 12, 15, 18, wall)
	_px(img, 7, 13, roof)
	_px(img, 16, 13, roof)
	_fill_rect(img, 9, 14, 10, 16, Color(0.55, 0.72, 0.92))
	_fill_rect(img, 13, 14, 14, 16, Color(0.55, 0.72, 0.92))
	for x in range(8, 16):
		_px(img, x, 9 - absi(x - 11), roof)


static func _draw_five_kind(img: Image) -> void:
	var gold := Color(0.95, 0.82, 0.34)
	_px(img, 12, 5, gold)
	_px(img, 10, 8, gold)
	_px(img, 14, 8, gold)
	_px(img, 8, 11, gold)
	_px(img, 16, 11, gold)
	_px(img, 10, 14, gold)
	_px(img, 14, 14, gold)
	_px(img, 12, 17, gold)


static func _draw_puzzle(img: Image) -> void:
	var a := Color(0.42, 0.72, 0.48)
	var b := Color(0.35, 0.58, 0.4)
	_fill_rect(img, 6, 6, 11, 11, a)
	_fill_rect(img, 12, 6, 17, 11, b)
	_fill_rect(img, 6, 12, 11, 17, b)
	_fill_rect(img, 12, 12, 17, 17, a)
	_px(img, 11, 9, Color(0.16, 0.18, 0.22))
	_px(img, 12, 9, Color(0.16, 0.18, 0.22))


static func _draw_spiral(img: Image) -> void:
	var c := Color(0.55, 0.42, 0.82)
	for i in 8:
		_px(img, 8 + i, 7, c)
		_px(img, 15, 7 + i, c)
		_px(img, 15 - i, 15, c)
		_px(img, 8, 15 - i, c)
	_px(img, 10, 10, c)
	_px(img, 13, 10, c)
	_px(img, 13, 13, c)


static func _draw_fog(img: Image) -> void:
	var fog := Color(0.72, 0.78, 0.86, 0.9)
	for x in range(4, 20, 3):
		_fill_rect(img, x, 10, x + 4, 12, fog)
	for x in range(6, 18, 4):
		_fill_rect(img, x, 14, x + 5, 16, fog)


static func _draw_arrow_right(img: Image) -> void:
	var ink := Color(0.35, 0.4, 0.5, 1)
	_fill_rect(img, 6, 11, 13, 12, ink)
	for row in range(24):
		var y: int = row
		if y < 8 or y > 15:
			continue
		var half: int = mini(y - 8, 15 - y)
		for dx in range(half + 1):
			_px(img, 14 + dx, y, ink)


static func _draw_close(img: Image) -> void:
	var rim := Color(0.72, 0.14, 0.2, 1)
	var fill := Color(0.98, 0.95, 0.93, 1)
	var cx := 12
	var cy := 12
	for y in SIZE:
		for x in SIZE:
			var dist: float = Vector2(x - cx, y - cy).length()
			if dist <= 9.5 and dist >= 7.5:
				_px(img, x, y, rim)
			elif dist < 7.5:
				_px(img, x, y, fill)
	for i in range(-4, 5):
		_px(img, cx + i, cy + i, rim)
		_px(img, cx + i, cy - i, rim)
		if i > -4 and i < 4:
			_px(img, cx + i + 1, cy + i, rim)
			_px(img, cx + i - 1, cy - i, rim)


static func _draw_fallback(img: Image) -> void:
	_fill_rect(img, 8, 8, 15, 15, Color(0.55, 0.58, 0.64))
	_fill_rect(img, 10, 10, 13, 13, Color(0.82, 0.84, 0.88))
