class_name PixelChallengeOrb
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
const COMPLETED_GLOW_PAD := 30.0
const COMPLETED_GLOW_PERIOD := 2.4
const COMPLETED_GLOW_MIN := 0.78
const COMPLETED_GLOW_MAX := 1.0
const BLOOM_INNER_SCALE := 0.82
const BLOOM_OUTER_SCALE := 2.35
const SHADE_INNER_CELLS := 14.8
const SHADE_OUTER_CELLS := 22.5
const SHADE_OUTER_SOFT_CELLS := 26.0

var orb_color: Color = Color.WHITE
var _hovering: bool = false
var _pressing: bool = false
var _completed: bool = false
var _glow_ramp: float = 1.0
var _glow_time: float = 0.0
var _float_base: Vector2 = Vector2.ZERO
var _float_time: float = 0.0
var _float_phase_offset: float = 0.0
var _floating_enabled: bool = true
var _bloom_layer: OrbBloomLayer
var _demo_locked: bool = false
var _demo_lock_tint := Color(0.62, 0.65, 0.70, 0.82)
var _shine_tween: Tween
var _shine_boost: float = 0.0


class OrbBloomLayer extends Control:
	var orb: PixelChallengeOrb

	func _draw() -> void:
		if orb == null or not orb._completed:
			return
		var w: int = int(size.x)
		var h: int = int(size.y)
		if w <= 0 or h <= 0:
			return

		var cols: int = w / PixelChallengeOrb.CELL_SIZE
		var rows: int = h / PixelChallengeOrb.CELL_SIZE
		var center_px: Vector2 = orb._center_px(cols, rows)
		var center := Vector2((cols - 1) * 0.5, (rows - 1) * 0.5)
		var strength: float = orb._completed_glow_strength()
		var shine: float = orb._shine_boost
		var inner_px: float = (
			PixelChallengeOrb.ORB_RADIUS_CELLS
			* PixelChallengeOrb.CELL_SIZE
			* PixelChallengeOrb.BLOOM_INNER_SCALE
		)
		var outer_px: float = (
			PixelChallengeOrb.ORB_RADIUS_CELLS
			* PixelChallengeOrb.CELL_SIZE
			* PixelChallengeOrb.BLOOM_OUTER_SCALE
		)
		var bloom_white := Color(1.0, 1.0, 1.0, 1.0)
		var cell_size: int = PixelChallengeOrb.CELL_SIZE

		for pass_idx in range(3):
			var pass_scale: float = [1.0, 1.14, 1.28][pass_idx]
			var pass_strength: float = strength * [1.0, 0.55, 0.28][pass_idx]
			if shine > 0.0:
				pass_scale *= lerpf(1.0, 1.38, shine)
				pass_strength *= lerpf(1.0, 2.05, shine)
			for row in range(rows):
				for col in range(cols):
					var cell_center := Vector2(
						col * cell_size + cell_size * 0.5,
						row * cell_size + cell_size * 0.5
					)
					var alpha: float = orb._bloom_alpha(
						cell_center.distance_to(center_px),
						inner_px,
						outer_px * pass_scale,
						pass_strength
					)
					if alpha <= 0.008:
						continue
					bloom_white.a = alpha
					draw_rect(
						Rect2(col * cell_size, row * cell_size, cell_size, cell_size),
						bloom_white
					)

		var core_white := Color(1.0, 1.0, 1.0, 1.0)
		var core_radius: float = PixelChallengeOrb.ORB_RADIUS_CELLS * 0.72
		for row in range(rows):
			for col in range(cols):
				var cell := Vector2(col, row)
				var dist: float = cell.distance_to(center)
				if dist > core_radius:
					continue
				core_white.a = 0.22 * strength * (1.0 - dist / core_radius) * lerpf(1.0, 3.6, shine)
				if core_white.a <= 0.008:
					continue
				draw_rect(
					Rect2(col * cell_size, row * cell_size, cell_size, cell_size),
					core_white
				)


static func display_size(completed: bool, base_size: float = 72.0) -> float:
	if completed:
		return base_size + COMPLETED_GLOW_PAD * 2.0
	return base_size


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
	_setup_bloom_layer()


func _setup_bloom_layer() -> void:
	_bloom_layer = OrbBloomLayer.new()
	_bloom_layer.name = "BloomLayer"
	_bloom_layer.orb = self
	_bloom_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bloom_layer.anchor_right = 1.0
	_bloom_layer.anchor_bottom = 1.0
	_bloom_layer.visible = false
	var bloom_material := CanvasItemMaterial.new()
	bloom_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bloom_layer.material = bloom_material
	add_child(_bloom_layer)
	move_child(_bloom_layer, 0)


func configure_float(phase_offset: float) -> void:
	_float_phase_offset = phase_offset
	_set_floating(_floating_enabled)


func set_floating_enabled(enabled: bool) -> void:
	_floating_enabled = enabled
	_update_process_state()


func set_float_base(pos: Vector2) -> void:
	_float_base = pos
	position = pos


func _update_process_state() -> void:
	set_process(_floating_enabled or _completed)
	if not _floating_enabled:
		position = _float_base


func _set_floating(enabled: bool) -> void:
	_floating_enabled = enabled
	_update_process_state()


func set_orb_color(color: Color) -> void:
	orb_color = color
	queue_redraw()
	if _bloom_layer != null:
		_bloom_layer.queue_redraw()


func set_demo_locked(locked: bool) -> void:
	_demo_locked = locked
	modulate = _demo_lock_tint if locked else Color.WHITE
	queue_redraw()


func is_demo_locked() -> bool:
	return _demo_locked


func is_bob_near_rest(threshold: float = 0.45) -> bool:
	if not _floating_enabled:
		return true
	var bob: float = sin(
		(_float_time + _float_phase_offset) * TAU / FLOAT_PERIOD
	) * FLOAT_AMPLITUDE
	return absf(bob) <= threshold


func snap_to_float_rest() -> void:
	position = _float_base


func set_display_diameter(diameter: float) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	queue_redraw()
	if _bloom_layer != null:
		_bloom_layer.queue_redraw()


func set_glow_ramp(value: float) -> void:
	_glow_ramp = clampf(value, 0.0, 1.0)
	queue_redraw()
	if _bloom_layer != null:
		_bloom_layer.queue_redraw()


func set_completed(completed: bool) -> void:
	_completed = completed
	if not completed:
		_glow_ramp = 1.0
	if _bloom_layer != null:
		_bloom_layer.visible = completed
	_update_process_state()
	queue_redraw()
	if _bloom_layer != null:
		_bloom_layer.queue_redraw()


func is_menu_completed() -> bool:
	return _completed


func play_idle_shine(shine_sec: float = 1.0) -> void:
	if not _completed:
		return
	if _shine_tween != null and _shine_tween.is_valid():
		_shine_tween.kill()
	var rise_sec: float = shine_sec * 0.42
	var fall_sec: float = shine_sec - rise_sec
	_shine_tween = create_tween()
	_shine_tween.tween_method(_set_shine_boost, 0.0, 1.0, rise_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shine_tween.tween_method(_set_shine_boost, 1.0, 0.0, fall_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _set_shine_boost(value: float) -> void:
	_shine_boost = clampf(value, 0.0, 1.0)
	queue_redraw()
	if _bloom_layer != null:
		_bloom_layer.queue_redraw()


func _set_hover(value: bool) -> void:
	_hovering = value
	queue_redraw()


func _set_pressing(value: bool) -> void:
	_pressing = value
	queue_redraw()


func _process(delta: float) -> void:
	if _completed:
		_glow_time += delta
		queue_redraw()
		if _bloom_layer != null:
			_bloom_layer.queue_redraw()
	if _floating_enabled:
		_float_time += delta
		var bob: float = sin((_float_time + _float_phase_offset) * TAU / FLOAT_PERIOD) * FLOAT_AMPLITUDE
		position = Vector2(_float_base.x, _float_base.y + bob)
	elif not _completed:
		position = _float_base


func _ambient_color(base: Color) -> Color:
	return base.lerp(AMBIENT_TINT, AMBIENT_BLEND)


func _completed_glow_strength() -> float:
	var pulse: float = 0.5 + 0.5 * sin(
		(_glow_time + _float_phase_offset) * TAU / COMPLETED_GLOW_PERIOD
	)
	var strength: float = lerpf(COMPLETED_GLOW_MIN, COMPLETED_GLOW_MAX, pulse) * _glow_ramp
	if _shine_boost > 0.0:
		strength = lerpf(strength, 1.85, _shine_boost)
	return strength


func _center_px(cols: int, rows: int) -> Vector2:
	return Vector2(
		(cols * CELL_SIZE) * 0.5,
		(rows * CELL_SIZE) * 0.5
	)


func _bloom_alpha(dist_px: float, inner_px: float, outer_px: float, strength: float) -> float:
	if dist_px > outer_px:
		return 0.0
	if dist_px <= inner_px:
		var core_t: float = dist_px / maxf(inner_px, 1.0)
		return strength * lerpf(0.55, 0.24, core_t)
	var t: float = (dist_px - inner_px) / maxf(outer_px - inner_px, 1.0)
	return strength * 0.48 * pow(1.0 - clampf(t, 0.0, 1.0), 2.0)


func _shade_alpha(dist_cells: float, inner: float, outer: float, strength: float, peak: float) -> float:
	if dist_cells < inner or dist_cells > outer:
		return 0.0
	var t: float = (dist_cells - inner) / maxf(outer - inner, 0.001)
	return strength * peak * pow(1.0 - clampf(t, 0.0, 1.0), 1.65)


func _draw_completed_soft_shade(center: Vector2, cols: int, rows: int) -> void:
	var strength: float = _completed_glow_strength()
	var shade := Color(1.0, 1.0, 1.0, 1.0)
	for row in range(rows):
		for col in range(cols):
			var cell := Vector2(col, row)
			var dist: float = cell.distance_to(center)
			var alpha: float = _shade_alpha(
				dist, SHADE_INNER_CELLS, SHADE_OUTER_CELLS, strength, 0.52
			)
			alpha = maxf(
				alpha,
				_shade_alpha(
					dist,
					ORB_RADIUS_CELLS - 1.1,
					ORB_RADIUS_CELLS + 1.4,
					strength,
					0.38
				)
			)
			alpha = maxf(
				alpha,
				_shade_alpha(dist, SHADE_OUTER_CELLS - 2.0, SHADE_OUTER_SOFT_CELLS, strength, 0.28)
			)
			if alpha <= 0.01:
				continue
			shade.a = alpha
			draw_rect(
				Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE),
				shade
			)


func _base_color() -> Color:
	var base := _ambient_color(orb_color)
	if _completed and _glow_ramp > 0.0:
		var pulse: float = _completed_glow_strength()
		var luminous := Color(1.0, 1.0, 1.0, 1.0)
		var glow_mix: float = (0.72 + pulse * 0.12) * _glow_ramp
		if _shine_boost > 0.0:
			glow_mix = lerpf(glow_mix, 1.0, _shine_boost)
		base = base.lerp(luminous, glow_mix)
	if _pressing:
		return base.darkened(0.06)
	if _hovering:
		return base.lightened(0.08)
	return base


func _smooth_gradient_t(raw_t: float) -> float:
	var t: float = clampf(raw_t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _cell_tone_incomplete(base: Color, cell: Vector2i, center: Vector2, dist: float) -> Color:
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


func _cell_tone_completed(base: Color, cell: Vector2i, center: Vector2, dist: float) -> Color:
	var white := Color(1.0, 1.0, 1.0, 1.0)
	if dist <= ORB_RADIUS_CELLS * 0.55:
		return white.lerp(base, 0.08)
	if dist >= ORB_RADIUS_CELLS - 0.85:
		return base.lerp(white, 0.82)
	var top_y: float = center.y - ORB_RADIUS_CELLS
	var raw_t: float = (float(cell.y) - top_y) / (ORB_RADIUS_CELLS * 2.0)
	var t: float = _smooth_gradient_t(raw_t)
	var top_color: Color = white.lerp(base, 0.12)
	var bottom_color: Color = base.lerp(white, 0.55)
	return top_color.lerp(bottom_color, t)


func _cell_tone(base: Color, cell: Vector2i, center: Vector2, dist: float) -> Color:
	var incomplete := _cell_tone_incomplete(base, cell, center, dist)
	if not _completed or _glow_ramp <= 0.0:
		return incomplete
	if _glow_ramp >= 1.0:
		return _cell_tone_completed(base, cell, center, dist)
	var complete := _cell_tone_completed(base, cell, center, dist)
	return incomplete.lerp(complete, _glow_ramp)


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

	if _completed:
		_draw_completed_soft_shade(center, cols, rows)

	if not _completed:
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
		draw_rect(
			Rect2(
				cell.x * CELL_SIZE,
				cell.y * CELL_SIZE,
				CELL_SIZE,
				CELL_SIZE
			),
			_cell_tone(base, cell, center, dist)
		)
