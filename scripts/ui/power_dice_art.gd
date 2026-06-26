class_name PowerDiceArt
extends RefCounted

const _NEW_ART := "res://assets/powerup_dice/new_art/"

const TEXTURE_PATHS: Dictionary = {
	"chooseNumber": _NEW_ART + "dream_team.png",
	"switchAnywhere": _NEW_ART + "fair_exchange.png",
	"setAnyNumber": _NEW_ART + "be_who_you_are.png",
	"switchRows": _NEW_ART + "trade_me_seats.png",
	"switchHorizontal": _NEW_ART + "cha_cha.png",
	"verticalJump": _NEW_ART + "leap_faith.png",
	"secondChances": _NEW_ART + "encore.png",
	"rerollTrade": _NEW_ART + "pawn_shop.png",
	"extraSwitches": _NEW_ART + "bulk_up.png",
	"straightSwitch": _NEW_ART + "main_char.png",
	"comboReroll": _NEW_ART + "house_party.png",
	"extraLoadout": _NEW_ART + "baggage_claim.png",
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
