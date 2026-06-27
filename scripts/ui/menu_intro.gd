class_name MenuIntro
extends Control

signal intro_finished

const INTRO_CONFIG := preload("res://scripts/ui/intros/menu_intro_config.gd")
const IACTA_FADE_IN_SEC := 0.65
const IACTA_HOLD_SEC := 1.15
const IACTA_FADE_OUT_SEC := 0.85
const ALEA_SOLO_CENTER_SEC := 1.05
const TITLE_HOLD_SEC := 0.85
const TITLE_RISE_SEC := 1.5
const BACKDROP_FADE_SEC := 1.8

@onready var _backdrop: ColorRect = %IntroBackdrop
@onready var _text_viewport: SubViewportContainer = %IntroTextViewport
@onready var _quote_box: VBoxContainer = %IntroQuoteBox
@onready var _latin_row: HBoxContainer = %IntroLatinRow
@onready var _iacta_part: Label = %IntroIactaPart


func _get_backdrop() -> ColorRect:
	if _backdrop == null:
		_backdrop = %IntroBackdrop
	return _backdrop


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_viewport.visible = false
	_latin_row.visible = false


func show_backdrop() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_get_backdrop().modulate = Color.WHITE


func play(title_target: Label) -> void:
	if INTRO_CONFIG.USE_INTRO_1:
		await _play_intro_1(title_target)
	else:
		await _play_title_reveal(title_target)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_finished.emit()


func _play_title_reveal(title_target: Label) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_get_backdrop().modulate = Color.WHITE
	if title_target == null:
		await _fade_out_backdrop()
		return
	await _play_alea_iacta_phrase(title_target)
	var end_global: Vector2 = await _resolve_title_end_global(title_target)
	await get_tree().create_timer(TITLE_HOLD_SEC).timeout
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_target, "global_position", end_global, TITLE_RISE_SEC)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_get_backdrop(), "modulate:a", 0.0, BACKDROP_FADE_SEC)\
		.set_delay(0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_settle_title(title_target)
	_get_backdrop().modulate.a = 1.0


func _play_alea_iacta_phrase(title_target: Label) -> void:
	_text_viewport.visible = false
	_quote_box.visible = false
	_attach_title_to_latin_row(title_target)
	_iacta_part.text = " iacta est"
	_iacta_part.visible = true
	_iacta_part.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_latin_row.visible = true
	_latin_row.modulate = Color.WHITE
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_iacta_part, "modulate:a", 1.0, IACTA_FADE_IN_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	await get_tree().create_timer(IACTA_HOLD_SEC).timeout
	var fade_out := create_tween()
	fade_out.tween_property(_iacta_part, "modulate:a", 0.0, IACTA_FADE_OUT_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	_detach_title_for_rise(title_target)
	_iacta_part.visible = false
	_iacta_part.modulate.a = 1.0
	await _tween_title_to_solo_center(title_target)


func _screen_center_for(label: Control) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(
		viewport_size.x * 0.5 - label.size.x * 0.5,
		viewport_size.y * 0.5 - label.size.y * 0.5
	)


func _tween_title_to_solo_center(title_target: Label) -> void:
	var center_global: Vector2 = _screen_center_for(title_target)
	if title_target.global_position.distance_to(center_global) <= 1.0:
		return
	var recenter := create_tween()
	recenter.tween_property(title_target, "global_position", center_global, ALEA_SOLO_CENTER_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await recenter.finished


func _resolve_title_end_global(title_target: Label) -> Vector2:
	var title_row: Node = title_target.get_meta("intro_title_row") as Node
	if title_row == null:
		return title_target.get_meta(
			"intro_title_end_global",
			title_target.global_position
		) as Vector2
	var saved_index: int = int(title_target.get_meta("intro_title_index", 0))
	var end_font_size: int = int(title_target.get_meta("intro_title_font_size", 64))
	var fly_global: Vector2 = title_target.global_position
	title_target.reparent(title_row)
	if saved_index >= 0:
		title_row.move_child(title_target, saved_index)
	title_target.top_level = false
	title_target.z_index = 0
	title_target.add_theme_font_size_override("font_size", end_font_size)
	title_target.modulate = Color(1.0, 1.0, 1.0, 0.0)
	title_target.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var end_global: Vector2 = title_target.global_position
	title_target.reparent(self)
	title_target.top_level = true
	title_target.z_index = 91
	title_target.global_position = fly_global
	title_target.modulate = Color.WHITE
	title_target.visible = true
	return end_global


func _attach_title_to_latin_row(title_target: Label) -> void:
	var title_row: Node = title_target.get_parent()
	if title_row == null:
		return
	title_target.set_meta("intro_title_row", title_row)
	title_target.set_meta("intro_title_index", title_target.get_index())
	title_target.set_meta(
		"intro_title_font_size",
		int(title_target.get_theme_font_size("font_size"))
	)
	title_target.reparent(_latin_row)
	_latin_row.move_child(title_target, 0)
	title_target.visible = true
	title_target.modulate = Color.WHITE


func _detach_title_for_rise(title_target: Label) -> void:
	var hold_global: Vector2 = title_target.global_position
	title_target.reparent(self)
	title_target.top_level = true
	title_target.z_index = 91
	title_target.global_position = hold_global
	_latin_row.visible = false


func _settle_title(title_target: Label) -> void:
	var title_row: Node = title_target.get_meta("intro_title_row") as Node
	if title_row == null:
		title_target.top_level = false
		title_target.z_index = 0
		title_target.remove_meta("intro_title_end_global")
		return
	var saved_index: int = int(title_target.get_meta("intro_title_index", 0))
	var end_font_size: int = int(title_target.get_meta("intro_title_font_size", 64))
	title_target.top_level = false
	title_target.z_index = 0
	title_target.reparent(title_row, true)
	if saved_index >= 0:
		title_row.move_child(title_target, saved_index)
	title_target.visible = true
	title_target.modulate = Color.WHITE
	title_target.add_theme_font_size_override("font_size", end_font_size)
	title_target.remove_meta("intro_title_row")
	title_target.remove_meta("intro_title_index")
	title_target.remove_meta("intro_title_font_size")
	title_target.remove_meta("intro_title_end_global")


func _fade_out_backdrop() -> void:
	var tween := create_tween()
	tween.tween_property(_get_backdrop(), "modulate:a", 0.0, BACKDROP_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_get_backdrop().modulate.a = 1.0


func _play_intro_1(title_target: Label) -> void:
	push_warning(
		"MenuIntro: intro 1 is archived. Point IntroOverlay to scripts/ui/intros/menu_intro_1.gd to restore."
	)
	await _play_title_reveal(title_target)
