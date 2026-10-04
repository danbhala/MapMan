class_name Wardrobe
extends RefCounted
## The looks MapMan can collect (docs/wardrobe). The first clear of every 5th
## level in the main game releases one, the rarer ones come later, and
## finishing the game releases MapWoman. He wears one at a time, like a skin;
## Outfits draws them, Save keeps which are released and which is worn. Names
## are English msgids (i18n/catalog.json).

## The release level of a look that comes with finishing the game.
const THE_END := 101

## In release order. level 0: in the wardrobe from the start.
const LOOKS := [
	{"id": "classic", "name": "CLASSIC", "level": 0, "tier": "start"},
	{"id": "party_hat", "name": "PARTY HAT", "level": 5, "tier": "common"},
	{"id": "signal_red", "name": "SIGNAL RED", "level": 10, "tier": "common"},
	{"id": "bobble_hat", "name": "BOBBLE HAT", "level": 15, "tier": "common"},
	{"id": "racing_green", "name": "RACING GREEN", "level": 20, "tier": "common"},
	{"id": "shades", "name": "SHADES", "level": 25, "tier": "common"},
	{"id": "blueprint", "name": "BLUEPRINT", "level": 30, "tier": "uncommon"},
	{"id": "cowboy", "name": "COWBOY", "level": 35, "tier": "uncommon"},
	{"id": "hard_hat", "name": "HARD HAT", "level": 40, "tier": "uncommon"},
	{"id": "top_hat", "name": "TOP HAT", "level": 45, "tier": "uncommon"},
	{"id": "neon", "name": "NEON", "level": 50, "tier": "uncommon"},
	{"id": "doctor", "name": "DOCTOR", "level": 55, "tier": "rare"},
	{"id": "pirate", "name": "PIRATE", "level": 60, "tier": "rare"},
	{"id": "pumpkin", "name": "PUMPKIN HEAD", "level": 65, "tier": "rare"},
	{"id": "skeleton", "name": "SKELETON", "level": 70, "tier": "rare"},
	{"id": "explorer", "name": "EXPLORER", "level": 75, "tier": "rare"},
	{"id": "astronaut", "name": "ASTRONAUT", "level": 80, "tier": "epic"},
	{"id": "robot", "name": "ROBOT", "level": 85, "tier": "epic"},
	{"id": "superhero", "name": "SUPERHERO", "level": 90, "tier": "epic"},
	{"id": "wizard", "name": "WIZARD", "level": 95, "tier": "epic"},
	{"id": "gold", "name": "SOLID GOLD", "level": 100, "tier": "legendary"},
	{"id": "mapwoman", "name": "MAPWOMAN", "level": THE_END, "tier": "special"},
]
## Tier -> its name on the sheets (msgid); Classic has none.
const TIERS := {
	"start": "",
	"common": "COMMON",
	"uncommon": "UNCOMMON",
	"rare": "RARE",
	"epic": "EPIC",
	"legendary": "LEGENDARY",
	"special": "SPECIAL",
}


## The look with this id, or {} if there is none.
static func look(id: String) -> Dictionary:
	for entry: Dictionary in LOOKS:
		if entry.id == id:
			return entry
	return {}


static func is_look(id: String) -> bool:
	return not look(id).is_empty()


static func ids() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in LOOKS:
		out.append(entry.id)
	return out


## The look the first clear of `level` releases, or "".
static func released_at(level: int) -> String:
	for entry: Dictionary in LOOKS:
		if entry.level == level and level > 0:
			return entry.id
	return ""


## Every look the progress in a save has earned: a level's once he has been
## past it in the main game, and all of them once the game is finished (the
## last level leads to the ending, not to a level 101).
static func earned(furthest_level: int, has_completed: bool) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in LOOKS:
		var level: int = entry.level
		if level == 0 or level < furthest_level or has_completed:
			out.append(entry.id)
	return out
