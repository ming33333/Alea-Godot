class_name PowerDiceArt
extends RefCounted

const TEXTURE_PATHS: Dictionary = {
	"chooseNumber": "res://assets/powerup_dice/choose_number.png",
	"switchAnywhere": "res://assets/powerup_dice/switch_anywhere.png",
	"setAnyNumber": "res://assets/powerup_dice/set_any_die.png",
	"switchRows": "res://assets/powerup_dice/switch_rows.png",
	"switchHorizontal": "res://assets/powerup_dice/side_switch.png",
	"verticalJump": "res://assets/powerup_dice/vertical_jump.png",
	"secondChances": "res://assets/powerup_dice/second_chances.png",
	"rerollTrade": "res://assets/powerup_dice/reroll_trade.png",
}

static var _cache: Dictionary = {}


static func get_texture(power_type: String) -> Texture2D:
	if _cache.has(power_type):
		return _cache[power_type] as Texture2D
	var path: String = str(TEXTURE_PATHS.get(power_type, TEXTURE_PATHS["chooseNumber"]))
	var tex: Resource = load(path)
	if tex is Texture2D:
		_cache[power_type] = tex as Texture2D
		return _cache[power_type] as Texture2D
	push_warning("PowerDiceArt: missing texture for %s at %s" % [power_type, path])
	return null
