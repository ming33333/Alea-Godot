class_name DiceCrownArt
extends RefCounted

## Maps the three opponents faced in a Dice Master Test to crown sprites.
## With 4 opponents in the pool and 3 picked per run, there are exactly C(4,3)=4 combos.

const CROWN_PATHS: Dictionary = {
	1: "res://assets/crowns/sprite_1.png",
	2: "res://assets/crowns/sprite_2.png",
	3: "res://assets/crowns/sprite_3.png",
	4: "res://assets/crowns/sprite_4.png",
}

# Sorted opponent-id triplets (current 4-opponent pool).
const COMBO_TO_CROWN: Dictionary = {
	"fiveOfAKindRequired,luckySeven,noThreeRepeats": 1,
	"fiveOfAKindRequired,luckySeven,rerollChaos": 2,
	"fiveOfAKindRequired,noThreeRepeats,rerollChaos": 3,
	"luckySeven,noThreeRepeats,rerollChaos": 4,
}

static var _cache: Dictionary = {}


static func crown_count() -> int:
	return CROWN_PATHS.size()


static func combo_key(opponent_ids: Array) -> String:
	var ids: Array[String] = []
	for id in opponent_ids:
		var oid: String = str(id)
		if not oid.is_empty():
			ids.append(oid)
	ids.sort()
	return ",".join(ids)


static func crown_index_for_opponents(opponent_ids: Array) -> int:
	var key: String = combo_key(opponent_ids)
	if COMBO_TO_CROWN.has(key):
		return int(COMBO_TO_CROWN[key])
	push_warning("DiceCrownArt: unknown opponent combo '%s' — using crown 1" % key)
	return 1


static func get_texture(crown_index: int) -> Texture2D:
	var idx: int = clampi(crown_index, 1, CROWN_PATHS.size())
	if _cache.has(idx):
		return _cache[idx] as Texture2D
	var path: String = str(CROWN_PATHS.get(idx, CROWN_PATHS[1]))
	var tex: Resource = load(path)
	if tex is Texture2D:
		_cache[idx] = tex as Texture2D
		return _cache[idx] as Texture2D
	push_warning("DiceCrownArt: missing texture at %s" % path)
	return null


static func apply_texture_rect(rect: TextureRect, crown_index: int, display_px: int = 0) -> void:
	if rect == null:
		return
	var tex: Texture2D = get_texture(crown_index)
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if display_px > 0:
		rect.custom_minimum_size = Vector2(display_px, display_px)


static func opponents_for_crown(crown_index: int) -> Array[String]:
	for key in COMBO_TO_CROWN:
		if int(COMBO_TO_CROWN[key]) == crown_index:
			var out: Array[String] = []
			for part in str(key).split(","):
				var oid: String = str(part).strip_edges()
				if not oid.is_empty():
					out.append(oid)
			return out
	return []


static func opponent_display_names(opponent_ids: Array) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for id in opponent_ids:
		var opp: Dictionary = GameData.get_tournament_opponent(str(id))
		names.append(str(opp.get("name", id)))
	return names


static func format_combo_names(opponent_ids: Array) -> String:
	var names: PackedStringArray = opponent_display_names(opponent_ids)
	match names.size():
		0:
			return "three random opponents"
		1:
			return names[0]
		2:
			return "%s and %s" % [names[0], names[1]]
		_:
			return "%s, %s, and %s" % [names[0], names[1], names[2]]


static func format_opponents_line(opponent_ids: Array) -> String:
	var names: PackedStringArray = opponent_display_names(opponent_ids)
	match names.size():
		0:
			return "You conquered all three games in the Dice Master Test."
		1:
			return "You beat %s." % names[0]
		2:
			return "You beat %s and %s." % [names[0], names[1]]
		_:
			return "You beat %s, %s, and %s." % [names[0], names[1], names[2]]
