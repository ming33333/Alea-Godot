class_name IconTextRow
extends HBoxContainer

const DEFAULT_ICON_PX := 20

@onready var _icon: TextureRect = %Icon
@onready var _label: Label = %Label


func set_content(icon_id: String, text: String, icon_px: int = DEFAULT_ICON_PX) -> void:
	var icon := _icon if _icon else get_node_or_null("Icon") as TextureRect
	var label := _label if _label else get_node_or_null("Label") as Label
	if icon:
		PixelIconArt.apply_texture_rect(icon, icon_id, icon_px)
	if label:
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func make(icon_id: String, text: String, icon_px: int = DEFAULT_ICON_PX) -> IconTextRow:
	var row := preload("res://scenes/icon_text_row.tscn").instantiate() as IconTextRow
	row.set_content(icon_id, text, icon_px)
	return row
