class_name PixelGymOrb
extends Button

const CELL_SIZE := 2
const ORB_RADIUS_CELLS := 15.3
const FLOAT_AMPLITUDE := 4.5
const FLOAT_PERIOD := 2.4
const AMBIENT_TINT := Color(0.90, 0.72, 0.56, 1.0)
const AMBIENT_BLEND := 0.2
const GRADIENT_TOP_WARM := Color(0.98, 0.84, 0.62, 1.0)
const GRADIENT_BOTTOM_COOL := Color(0.54, 0.42, 0.50, 1.0)
const GLOW_WARM := Color(1.0, 0.82, 0.55, 1.0)

var orb_color: Color = Color.WHITE
var _hovering: bool = false
var _pressing: bool = false
var _float_base: Vector2 = Vector2.ZERO
var _float_time: float = 0.0
var _float_phase_offset: float = 0.0
var _floating_enabled: bool = true


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = ""
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	button_down.connect(_set_pressing.bind(true))
	button_up.connect(_set_pressing.bind(false))


func configure_float(phase_offset: float) -> void:
	_float_phase_offset = phase_offset
	_set_floating(_floating_enabled)


func set_floating_enabled(enabled: bool) -> void:
	_floating_enabled = enabled
	_set_floating(enabled)


func set_float_base(pos: Vector2) -> void:
	_float_base = pos
	position = pos


func _set_floating(enabled: bool) -> void:
	set_process(enabled)
	if not enabled:
		position = _float_base


func set_orb_color(color: Color) -> void:
	orb_color = color
	queue_redraw()


func _set_hover(value: bool) -> void:
	_hovering = value
	queue_redraw()


func _set_pressing(value: bool) -> void:
	_pressing = value
	queue_redraw()


func _process(delta: float) -> void:
	if not _floating_enabled:
		position = _float_base
		return
	_float_time += delta
	var bob: float = sin((_float_time + _float_phase_offset) * TAU / FLOAT_PERIOD) * FLOAT_AMPLITUDE
	position = Vector2(_float_base.x, _float_base.y + bob)


func _ambient_color(base: Color) -> Color:
	return base.lerp(AMBIENT_TINT, AMBIENT_BLEND)


func _base_color() -> Color:
	var base := _ambient_color(orb_color)
	if _pressing:
		return base.darkened(0.06)
	if _hovering:
		return base.lightened(0.08)
	return base


func _smooth_gradient_t(raw_t: float) -> float:
	var t: float = clampf(raw_t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _cell_tone(base: Color, cell: Vector2i, center: Vector2, dist: float) -> Color:
	if dist >= ORB_RADIUS_CELLS - 1.05:
		var rim := base.darkened(0.10).lerp(GRADIENT_BOTTOM_COOL, 0.28)
		return rim.lerp(Color(0.94, 0.76, 0.50), 0.42)

	var top_y: float = center.y - ORB_RADIUS_CELLS
	var raw_t: float = (float(cell.y) - top_y) / (ORB_RADIUS_CELLS * 2.0)
	var t: float = _smooth_gradient_t(raw_t)
	var top_color: Color = base.lightened(0.16).lerp(GRADIENT_TOP_WARM, 0.42)
	var bottom_color: Color = base.darkened(0.20).lerp(GRADIENT_BOTTOM_COOL, 0.36)
	var tone: Color = top_color.lerp(bottom_color, t)

	var x_off: float = abs(float(cell.x) - center.x) / ORB_RADIUS_CELLS
	tone = tone.darkened(x_off * 0.05)
	return tone


func _draw() -> void:
	var base: Color = _base_color()
	var w: int = int(size.x)
	var h: int = int(size.y)
	if w <= 0 or h <= 0:
		return

	var cols: int = w / CELL_SIZE
	var rows: int = h / CELL_SIZE
	var center := Vector2((cols - 1) * 0.5, (rows - 1) * 0.5)
	var filled: Array[Vector2i] = []

	for row in range(rows):
		for col in range(cols):
			var cell := Vector2(col, row)
			var dist_to_center: float = cell.distance_to(center)
			if dist_to_center <= ORB_RADIUS_CELLS + 0.85:
				filled.append(Vector2i(col, row))

	for cell in filled:
		var dist: float = Vector2(cell).distance_to(center)
		if dist > ORB_RADIUS_CELLS - 0.2 and dist <= ORB_RADIUS_CELLS + 0.85:
			var glow_strength: float = 1.0 - ((dist - (ORB_RADIUS_CELLS - 0.2)) / 1.05)
			var glow := GLOW_WARM
			glow.a = 0.16 * glow_strength
			draw_rect(
				Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE),
				glow
			)

	for cell in filled:
		var dist: float = Vector2(cell).distance_to(center)
		if dist > ORB_RADIUS_CELLS:
			continue
		var rect := Rect2(
			cell.x * CELL_SIZE,
			cell.y * CELL_SIZE,
			CELL_SIZE,
			CELL_SIZE
		)
		draw_rect(rect, _cell_tone(base, cell, center, dist))
