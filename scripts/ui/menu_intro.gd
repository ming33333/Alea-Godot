class_name MenuIntro
extends Control

signal intro_finished
signal menu_reveal_started

const TEXT_BLUR_SHADER: Shader = preload("res://assets/shaders/text_blur.gdshader")
const BLUR_START := 28.0
const QUOTE_BLUR_IN_SEC := 2.8
const QUOTE_HOLD_SEC := 1.8
const QUOTE_OUT_SEC := 0.9
const LATIN_BLUR_IN_SEC := 2.6
const LATIN_HOLD_SEC := 2.0
const IACTA_FADE_SEC := 0.85
const INTRO_ALEA_FONT_SIZE := 72
const INTRO_ALEA_COLOR := Color(0.96, 0.92, 0.84, 1)
const ALEA_ISOLATED_HOLD_SEC := 0.55
const VIEWPORT_OUT_SEC := 0.2
const ALEA_FLY_SEC := 1.35
const BACKDROP_FADE_SEC := 1.8

@onready var _backdrop: ColorRect = %IntroBackdrop
@onready var _text_viewport_container: SubViewportContainer = %IntroTextViewport
@onready var _text_subviewport: SubViewport = %IntroTextSubViewport
@onready var _quote_box: VBoxContainer = %IntroQuoteBox
@onready var _quote: Label = %IntroQuote
@onready var _attribution: Label = %IntroAttribution
@onready var _latin_row: HBoxContainer = %IntroLatinRow
@onready var _iacta_part: Label = %IntroIactaPart

var _text_blur: ShaderMaterial
var _title_target: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_blur = _make_blur_material()
	_text_viewport_container.material = _text_blur
	_text_viewport_container.stretch = true


func play(title_target: Label) -> void:
	_title_target = title_target
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_visual_state()
	await _sync_text_viewport_size()
	await _reveal_quote()
	await _transition_to_latin()
	await _hold_latin()
	await _strip_iacta_est()
	await _fly_alea_to_title(title_target)
	menu_reveal_started.emit()
	await _fade_out_backdrop()
	_finish_title_handoff(title_target)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_finished.emit()


func _make_blur_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TEXT_BLUR_SHADER
	mat.set_shader_parameter("blur_amount", BLUR_START)
	return mat


func _sync_text_viewport_size() -> void:
	await get_tree().process_frame
	var quote_size := _quote_box.get_combined_minimum_size()
	var latin_size := _latin_row.get_combined_minimum_size()
	var width := int(maxf(quote_size.x, latin_size.x)) + 48
	var height := int(maxf(quote_size.y, latin_size.y)) + 40
	_text_subviewport.size = Vector2i(width, height)
	_text_viewport_container.custom_minimum_size = Vector2(width, height)
	await get_tree().process_frame


func _reset_visual_state() -> void:
	_backdrop.modulate = Color.WHITE
	_text_viewport_container.visible = true
	_text_viewport_container.modulate = Color.WHITE
	_quote_box.visible = true
	_quote_box.modulate = Color.WHITE
	_latin_row.visible = false
	_latin_row.modulate = Color.WHITE
	_quote.modulate = Color.WHITE
	_attribution.modulate = Color.WHITE
	_iacta_part.modulate = Color.WHITE
	_iacta_part.visible = true
	_text_blur.set_shader_parameter("blur_amount", BLUR_START)


func _reveal_quote() -> void:
	var tween := create_tween()
	tween.tween_method(
		func(amount: float) -> void:
			_text_blur.set_shader_parameter("blur_amount", amount),
		BLUR_START,
		0.0,
		QUOTE_BLUR_IN_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(QUOTE_HOLD_SEC).timeout


func _transition_to_latin() -> void:
	var tween := create_tween()
	tween.tween_property(_quote_box, "modulate:a", 0.0, QUOTE_OUT_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_quote_box.visible = false
	_latin_row.visible = true
	_latin_row.modulate = Color.WHITE
	_attach_title_to_latin_row()
	_text_blur.set_shader_parameter("blur_amount", BLUR_START)
	var latin := create_tween()
	latin.tween_method(
		func(amount: float) -> void:
			_text_blur.set_shader_parameter("blur_amount", amount),
		BLUR_START,
		0.0,
		LATIN_BLUR_IN_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await latin.finished


func _hold_latin() -> void:
	await get_tree().create_timer(LATIN_HOLD_SEC).timeout


func _strip_iacta_est() -> void:
	var tween := create_tween()
	tween.tween_property(_iacta_part, "modulate:a", 0.0, IACTA_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_iacta_part.visible = false
	await _sync_text_viewport_size()


func _attach_title_to_latin_row() -> void:
	if _title_target == null:
		return
	var title_row: Node = _title_target.get_parent()
	if title_row == null:
		return
	_title_target.set_meta("intro_title_row", title_row)
	_title_target.set_meta("intro_title_index", _title_target.get_index())
	_title_target.set_meta(
		"intro_title_font_size",
		int(_title_target.get_theme_font_size("font_size"))
	)
	_title_target.reparent(_latin_row)
	_latin_row.move_child(_title_target, 0)
	_title_target.visible = true
	_title_target.modulate = Color.WHITE
	_title_target.add_theme_font_size_override("font_size", INTRO_ALEA_FONT_SIZE)
	_title_target.add_theme_color_override("font_color", INTRO_ALEA_COLOR)


func _fly_alea_to_title(title_target: Label) -> void:
	if title_target == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(ALEA_ISOLATED_HOLD_SEC).timeout
	var title_row: Node = title_target.get_meta("intro_title_row") as Node
	if title_row == null:
		return
	var saved_index: int = int(title_target.get_meta("intro_title_index", 0))
	var end_font_size: int = int(title_target.get_meta("intro_title_font_size", 64))
	var start_rect: Rect2 = title_target.get_global_rect()
	var start_font_size: int = int(title_target.get_theme_font_size("font_size"))
	title_target.reparent(title_row)
	if saved_index >= 0:
		title_row.move_child(title_target, saved_index)
	title_target.add_theme_font_size_override("font_size", end_font_size)
	title_target.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var end_global: Vector2 = title_target.global_position
	title_target.reparent(self)
	title_target.z_index = 2
	title_target.global_position = start_rect.position
	title_target.modulate = Color.WHITE
	title_target.add_theme_font_size_override("font_size", start_font_size)
	var viewport_out := create_tween()
	viewport_out.tween_property(_text_viewport_container, "modulate:a", 0.0, VIEWPORT_OUT_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await viewport_out.finished
	_text_viewport_container.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_target, "global_position", end_global, ALEA_FLY_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(font_size: float) -> void:
			title_target.add_theme_font_size_override("font_size", int(font_size)),
		float(start_font_size),
		float(end_font_size),
		ALEA_FLY_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	title_target.set_meta("intro_title_row", title_row)
	title_target.set_meta("intro_title_index", saved_index)
	title_target.set_meta("intro_title_font_size", end_font_size)


func _finish_title_handoff(title_target: Label) -> void:
	if title_target == null:
		return
	var title_row: Node = title_target.get_meta("intro_title_row") as Node
	if title_row == null:
		title_target.visible = true
		title_target.modulate = Color.WHITE
		return
	var saved_index: int = int(title_target.get_meta("intro_title_index", 0))
	var end_font_size: int = int(title_target.get_meta("intro_title_font_size", 64))
	title_target.reparent(title_row)
	if saved_index >= 0:
		title_row.move_child(title_target, saved_index)
	title_target.position = Vector2.ZERO
	title_target.z_index = 0
	title_target.visible = true
	title_target.modulate = Color.WHITE
	title_target.add_theme_font_size_override("font_size", end_font_size)
	title_target.remove_theme_color_override("font_color")
	title_target.remove_meta("intro_title_row")
	title_target.remove_meta("intro_title_index")
	title_target.remove_meta("intro_title_font_size")


func _fade_out_backdrop() -> void:
	var tween := create_tween()
	tween.tween_property(_backdrop, "modulate:a", 0.0, BACKDROP_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_backdrop.modulate.a = 1.0
