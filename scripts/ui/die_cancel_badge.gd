class_name DieCancelBadge
extends Button

signal badge_pressed

const BADGE_PX := 20

var _hovering: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(BADGE_PX, BADGE_PX)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon = PixelIconArt.get_icon("close")
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", BADGE_PX - 4)
	pressed.connect(func() -> void: badge_pressed.emit())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visible = false
	z_index = 24
	tooltip_text = "Cancel power-up"
	_apply_modulate()


func layout_above(parent_size: Vector2, badge_px: float = BADGE_PX, gap_px: float = 3.0) -> void:
	_apply_badge_px(badge_px)
	position = Vector2(
		(parent_size.x - badge_px) * 0.5,
		-badge_px - gap_px
	)


func layout_on_die_top(
	parent_size: Vector2,
	badge_px: float,
	overlap_into_die: float = 10.0
) -> void:
	_apply_badge_px(badge_px)
	position = Vector2(
		(parent_size.x - badge_px) * 0.5,
		-badge_px + overlap_into_die
	)


func layout_snug_on_die_top(parent_size: Vector2, badge_px: float) -> void:
	# Bottom edge of the badge sits on the die top (1px into the cell for a flush fit).
	layout_on_die_top(parent_size, badge_px, badge_px - 1.0)


func _apply_badge_px(badge_px: float) -> void:
	custom_minimum_size = Vector2(badge_px, badge_px)
	size = Vector2(badge_px, badge_px)
	add_theme_constant_override("icon_max_width", maxi(10, int(badge_px) - 2))


func _on_mouse_entered() -> void:
	_hovering = true
	_apply_modulate()


func _on_mouse_exited() -> void:
	_hovering = false
	_apply_modulate()


func _apply_modulate() -> void:
	modulate = Color(1.12, 1.08, 1.05) if _hovering else Color.WHITE
