class_name MenuIntro
extends Control

signal intro_finished

const INTRO_CONFIG := preload("res://scripts/ui/intros/menu_intro_config.gd")
const QUOTE_FADE_IN_SEC := 0.85
const QUOTE_HOLD_SEC := 1.85
const CURTAIN_REVEAL_SEC := 1.15
const REVEAL_CLIP_PADDING := Vector2(48.0, 28.0)
const IACTA_HOLD_SEC := 1.15
const IACTA_FADE_OUT_SEC := 0.85
const ALEA_SOLO_CENTER_SEC := 1.05
const TITLE_HOLD_SEC := 0.85
const TITLE_RISE_SEC := 1.5
const BACKDROP_FADE_SEC := 1.8

@onready var _backdrop: ColorRect = %IntroBackdrop
@onready var _text_viewport: SubViewportContainer = %IntroTextViewport
@onready var _quote_box: VBoxContainer = %IntroQuoteBox
@onready var _quote: Label = %IntroQuote
@onready var _attribution: Label = %IntroAttribution
@onready var _reveal_clip: Control = %IntroRevealClip
@onready var _latin_row: HBoxContainer = %IntroLatinRow
@onready var _iacta_part: Label = %IntroIactaPart
@onready var _reveal_curtain: ColorRect = %IntroRevealCurtain


func _get_backdrop() -> ColorRect:
	if _backdrop == null:
		_backdrop = %IntroBackdrop
	return _backdrop


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_viewport.visible = false
	_quote_box.visible = false
	_reveal_clip.visible = false


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
	await _play_caesar_quote()
	await _curtain_reveal_alea_phrase(title_target)
	await _play_alea_after_slide(title_target)
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


func _play_caesar_quote() -> void:
	_reveal_clip.visible = false
	_text_viewport.visible = false
	_quote.text = "The die is cast"
	_attribution.text = "— Julius Caesar"
	_quote_box.visible = true
	_quote_box.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_quote.modulate = Color.WHITE
	_attribution.modulate = Color.WHITE
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_quote_box, "modulate:a", 1.0, QUOTE_FADE_IN_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	await get_tree().create_timer(QUOTE_HOLD_SEC).timeout


func _curtain_reveal_alea_phrase(title_target: Label) -> void:
	_attach_title_to_latin_row(title_target)
	_iacta_part.text = " iacta est"
	_iacta_part.visible = true
	_iacta_part.modulate = Color.WHITE
	_latin_row.visible = true
	_latin_row.modulate = Color.WHITE
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_reveal_clip_size()
	_mount_quote_on_curtain()
	_reveal_clip.visible = true
	_reset_reveal_curtain()
	var curtain := create_tween()
	curtain.tween_property(_reveal_curtain, "position:x", _reveal_clip.size.x, CURTAIN_REVEAL_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await curtain.finished
	_restore_quote_box()
	_reveal_curtain.visible = false


func _mount_quote_on_curtain() -> void:
	var quote_size: Vector2 = _quote_box.get_combined_minimum_size()
	var clip_size: Vector2 = _reveal_clip.size
	_quote_box.set_meta("intro_quote_parent", _quote_box.get_parent())
	_quote_box.set_meta("intro_quote_index", _quote_box.get_index())
	_quote_box.reparent(_reveal_curtain)
	_quote_box.position = Vector2(
		(clip_size.x - quote_size.x) * 0.5,
		(clip_size.y - quote_size.y) * 0.5
	)
	_quote_box.size = quote_size
	_quote_box.modulate = Color.WHITE
	_quote_box.visible = true


func _restore_quote_box() -> void:
	var quote_parent: Node = _quote_box.get_meta("intro_quote_parent") as Node
	if quote_parent != null:
		var saved_index: int = int(_quote_box.get_meta("intro_quote_index", 0))
		_quote_box.reparent(quote_parent, true)
		if saved_index >= 0:
			quote_parent.move_child(_quote_box, saved_index)
		_quote_box.remove_meta("intro_quote_parent")
		_quote_box.remove_meta("intro_quote_index")
	_reset_quote_box()


func _sync_reveal_clip_size() -> void:
	var latin_size: Vector2 = _latin_row.get_combined_minimum_size()
	var quote_size: Vector2 = _quote_box.get_combined_minimum_size()
	var inner_size: Vector2 = Vector2(
		maxf(latin_size.x, quote_size.x),
		maxf(latin_size.y, quote_size.y)
	)
	var content_size: Vector2 = inner_size + REVEAL_CLIP_PADDING
	_reveal_clip.custom_minimum_size = content_size
	_reveal_clip.size = content_size
	_latin_row.position = Vector2(
		(content_size.x - latin_size.x) * 0.5,
		(content_size.y - latin_size.y) * 0.5
	)
	_latin_row.size = latin_size
	_reveal_curtain.size = content_size
	_reveal_curtain.position = Vector2.ZERO
	_reveal_curtain.visible = true


func _reset_reveal_curtain() -> void:
	_reveal_curtain.visible = true
	_reveal_curtain.position = Vector2.ZERO
	_reveal_curtain.size = _reveal_clip.size


func _reset_quote_box() -> void:
	_quote_box.modulate = Color.WHITE
	_quote_box.visible = false


func _play_alea_after_slide(title_target: Label) -> void:
	await get_tree().create_timer(IACTA_HOLD_SEC).timeout
	var fade_out := create_tween()
	fade_out.tween_property(_iacta_part, "modulate:a", 0.0, IACTA_FADE_OUT_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	_detach_title_for_rise(title_target)
	_iacta_part.visible = false
	_iacta_part.modulate.a = 1.0
	_reveal_clip.visible = false
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
