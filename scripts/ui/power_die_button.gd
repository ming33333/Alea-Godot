class_name PowerDieButton
extends Button

const HOVER_GLOW_COLOR := Color(1.0, 0.92, 0.55, 0.42)
const HOVER_TWEEN_SEC := 0.12

var power_type: String = ""

var _die_wrap: Control
var _die_sprite: TextureRect
var _charge_label: Label
var _name_label: Label
var _hover_glow: ColorRect
var _speech_bubble: PowerSpeechBubble
var _hovering: bool = false
var _is_active: bool = false
var _chip_unusable: bool = false
var _description_text: String = ""
var _active_hint_text: String = ""
var _bubble_accent: Color = Color(0.2, 0.35, 0.55)
var _hover_tween: Tween


func _ready() -> void:
	_die_wrap = get_node_or_null("VBox/DieWrap") as Control
	_die_sprite = get_node_or_null("VBox/DieWrap/DieSprite") as TextureRect
	_charge_label = get_node_or_null("VBox/DieWrap/ChargeLabel") as Label
	_name_label = get_node_or_null("VBox/NameLabel") as Label
	_hover_glow = get_node_or_null("VBox/DieWrap/HoverGlow") as ColorRect
	_speech_bubble = get_node_or_null("SpeechBubble") as PowerSpeechBubble
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func setup_display(
	power_type_val: String,
	power_name: String,
	charge_text: String,
	is_active: bool,
	chip_unusable: bool
) -> void:
	power_type = power_type_val
	if _die_sprite == null:
		_die_sprite = get_node_or_null("VBox/DieWrap/DieSprite") as TextureRect
	if _charge_label == null:
		_charge_label = get_node_or_null("VBox/DieWrap/ChargeLabel") as Label
	if _name_label == null:
		_name_label = get_node_or_null("VBox/NameLabel") as Label
	var tex: Texture2D = PowerDiceArt.get_texture(power_type)
	if _die_sprite:
		_die_sprite.texture = tex
		_die_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _name_label:
		_name_label.text = power_name
	if _charge_label:
		_charge_label.text = charge_text
		_charge_label.visible = not charge_text.is_empty()
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_chip_unusable = chip_unusable
	_is_active = is_active
	_hovering = false
	z_index = 2 if is_active else 0
	_apply_visual_state(is_active, chip_unusable)
	_refresh_hover_visual(true)


func configure_messages(description: String, active_hint: String, accent: Color) -> void:
	_description_text = description
	_active_hint_text = active_hint
	_bubble_accent = accent


func set_active_state(is_active: bool, animate_bubble: bool = true) -> void:
	_is_active = is_active
	z_index = 2 if is_active else 0
	_apply_visual_state(is_active, _chip_unusable)
	_refresh_hover_visual(true)
	_update_bubble_for_state(animate_bubble)


func pulse_info_bubble() -> void:
	if _description_text.is_empty() or _speech_bubble == null:
		return
	_speech_bubble.show_message(_description_text, _bubble_accent, true)


func get_die_global_center() -> Vector2:
	if _die_wrap != null:
		var rect: Rect2 = _die_wrap.get_global_rect()
		return rect.position + rect.size * 0.5
	return get_global_rect().get_center()


func set_fly_reveal_pending(pending: bool) -> void:
	var alpha: float = 0.0 if pending else 1.0
	if _die_wrap != null:
		_die_wrap.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _charge_label != null:
		_charge_label.modulate = Color(1.0, 1.0, 1.0, alpha)


func play_reward_arrival_pop() -> void:
	if _die_wrap == null:
		return
	if _reward_pop_tween != null and _reward_pop_tween.is_valid():
		_reward_pop_tween.kill()
	_die_wrap.modulate = Color.WHITE
	if _charge_label != null:
		_charge_label.modulate = Color.WHITE
	_die_wrap.scale = Vector2(0.55, 0.55)
	_reward_pop_tween = create_tween()
	_reward_pop_tween.tween_property(
		_die_wrap,
		"scale",
		Vector2.ONE,
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var _reward_pop_tween: Tween


func set_chip_size(die_px: int) -> void:
	var name_h: int = maxi(18, int(round(float(die_px) * 0.28)))
	var total_h: int = die_px + 2 + name_h
	custom_minimum_size = Vector2(die_px, total_h)
	size = Vector2(die_px, total_h)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _die_wrap:
		_die_wrap.custom_minimum_size = Vector2(die_px, die_px)
		_die_wrap.pivot_offset = Vector2(die_px * 0.5, die_px * 0.5)
	if _hover_glow:
		var glow_pad: float = float(die_px) * 0.06
		var glow_size: float = float(die_px) + glow_pad * 2.0
		_hover_glow.custom_minimum_size = Vector2(glow_size, glow_size)
		_hover_glow.size = Vector2(glow_size, glow_size)
		_hover_glow.position = Vector2(
			(float(die_px) - glow_size) * 0.5,
			(float(die_px) - glow_size) * 0.5
		)
		_hover_glow.color = HOVER_GLOW_COLOR
	if _charge_label:
		var charge_font: int = maxi(9, int(round(float(die_px) * 0.2)))
		_charge_label.add_theme_font_size_override("font_size", charge_font)
	if _name_label:
		var name_font: int = maxi(11, int(round(float(die_px) * 0.18)))
		_name_label.add_theme_font_size_override("font_size", name_font)
		_name_label.custom_minimum_size = Vector2(die_px, name_h)
	if _speech_bubble:
		_speech_bubble.configure(die_px)


func _apply_visual_state(is_active: bool, chip_unusable: bool) -> void:
	if _die_sprite:
		_die_sprite.modulate = Color.WHITE
	if _name_label == null:
		return
	if chip_unusable:
		_name_label.add_theme_color_override("font_color", Color(0.38, 0.4, 0.44))
	elif is_active:
		_name_label.add_theme_color_override("font_color", Color(0.82, 0.1, 0.12))
	else:
		_name_label.add_theme_color_override("font_color", Color.BLACK)


func _on_mouse_entered() -> void:
	_hovering = true
	_refresh_hover_visual()


func _on_mouse_exited() -> void:
	_hovering = false
	_refresh_hover_visual()


func _bubble_text() -> String:
	return _active_hint_text if _is_active else ""


func _should_show_bubble() -> bool:
	return _is_active and not _active_hint_text.is_empty()


func _update_bubble_for_state(animate: bool) -> void:
	if _speech_bubble == null:
		return
	if _should_show_bubble():
		_speech_bubble.show_message(_bubble_text(), _bubble_accent, animate)
	else:
		_speech_bubble.hide_message(true)


func _die_hover_scale() -> float:
	var scale_val: float = 1.06 if _is_active else 1.0
	if _hovering:
		scale_val += 0.04
	return scale_val


func _refresh_hover_visual(instant: bool = false) -> void:
	if _die_wrap == null:
		return
	var target_scale: float = _die_hover_scale()
	var show_glow: bool = _hovering
	if _hover_glow:
		if instant:
			_hover_glow.visible = show_glow
			_hover_glow.modulate.a = HOVER_GLOW_COLOR.a if show_glow else 0.0
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	if instant:
		_die_wrap.scale = Vector2.ONE * target_scale
		if _die_sprite:
			_die_sprite.modulate = Color.WHITE
		return
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(
		_die_wrap,
		"scale",
		Vector2.ONE * target_scale,
		HOVER_TWEEN_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _hover_glow:
		_hover_glow.visible = true
		_hover_tween.tween_property(
			_hover_glow,
			"modulate:a",
			HOVER_GLOW_COLOR.a if show_glow else 0.0,
			HOVER_TWEEN_SEC
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _die_sprite:
		var sprite_modulate: Color = Color(1.06, 1.06, 1.02) if show_glow else Color.WHITE
		_hover_tween.tween_property(
			_die_sprite,
			"modulate",
			sprite_modulate,
			HOVER_TWEEN_SEC
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
