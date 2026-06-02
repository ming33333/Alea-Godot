class_name DieCell
extends Button

var value_label: Label
var grid_row: int = -1
var grid_col: int = -1


func _ready() -> void:
	value_label = get_node_or_null("ValueLabel") as Label


func setup(row: int, col: int, cell: DiceCellData, blurred: bool) -> void:
	grid_row = row
	grid_col = col
	var label: Label = _ensure_value_label()
	if label == null:
		push_error("DieCell: ValueLabel node missing in die_cell.tscn")
		return
	if blurred:
		label.text = "?"
	else:
		label.text = str(cell.value)
	if cell.locked:
		modulate = Color(0.85, 0.9, 1.0)
		add_theme_color_override("font_color", Color(0.2, 0.25, 0.4))
	else:
		modulate = Color.WHITE
		remove_theme_color_override("font_color")
	if cell.no_reroll:
		tooltip_text = "Cannot reroll"
	else:
		tooltip_text = ""


func _ensure_value_label() -> Label:
	if value_label != null:
		return value_label
	value_label = get_node_or_null("ValueLabel") as Label
	return value_label
