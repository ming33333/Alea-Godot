class_name HowToPlayContent
extends RefCounted

const PATH := "res://data/how_to_play.json"


static func populate(container: VBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_warning("HowToPlayContent: missing %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("HowToPlayContent: invalid JSON in %s" % PATH)
		return
	for item in parsed.get("sections", []):
		if not item is Dictionary:
			continue
		var section: Dictionary = item
		var heading: String = str(section.get("heading", "")).strip_edges()
		var body: String = str(section.get("text", "")).strip_edges()
		if heading.is_empty() and body.is_empty():
			continue
		if not heading.is_empty():
			var title := Label.new()
			title.text = heading
			title.add_theme_font_size_override("font_size", 15)
			title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
			container.add_child(title)
		if not body.is_empty():
			var text := Label.new()
			text.text = body
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.add_theme_font_size_override("font_size", 13)
			text.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
			container.add_child(text)
