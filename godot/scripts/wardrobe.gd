class_name Wardrobe
extends RefCounted
## The looks MapMan can collect (docs/wardrobe). The first clear of every 5th
## level in the main game releases one, the rarer ones come later, and
## finishing the game releases MapWoman. He wears one at a time, like a skin;
## Outfits draws them, Save keeps which are released and which is worn. Names
## are English msgids (i18n/catalog.json).
##
## MapWoman has a wardrobe of her own (HERS): looks that are hers, not his
## with a bow on, released by the first clear of every 5th sheet of Revision
## B. Wearing one is playing as her, in it.

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
## MapWoman's wardrobe, in release order: `level` is the Revision B sheet
## whose first clear releases the look. MapWoman herself (LOOKS' last entry)
## opens it, and is its Classic.
const HERS := [
	{"id": "sky_blue", "name": "SKY BLUE", "level": 5, "tier": "common"},
	{"id": "beret", "name": "BERET", "level": 10, "tier": "common"},
	{"id": "headband", "name": "HEADBAND", "level": 15, "tier": "common"},
	{"id": "sunflower", "name": "SUNFLOWER", "level": 20, "tier": "common"},
	{"id": "goggles", "name": "GOGGLES", "level": 25, "tier": "common"},
	{"id": "footballer", "name": "FOOTBALLER", "level": 30, "tier": "uncommon"},
	{"id": "chef", "name": "CHEF", "level": 35, "tier": "uncommon"},
	{"id": "firefighter", "name": "FIREFIGHTER", "level": 40, "tier": "uncommon"},
	{"id": "detective", "name": "DETECTIVE", "level": 45, "tier": "uncommon"},
	{"id": "storm", "name": "STORM", "level": 50, "tier": "uncommon"},
	{"id": "surgeon", "name": "SURGEON", "level": 55, "tier": "rare"},
	{"id": "mechanic", "name": "MECHANIC", "level": 60, "tier": "rare"},
	{"id": "beekeeper", "name": "BEEKEEPER", "level": 65, "tier": "rare"},
	{"id": "rock_star", "name": "ROCK STAR", "level": 70, "tier": "rare"},
	{"id": "sea_captain", "name": "SEA CAPTAIN", "level": 75, "tier": "rare"},
	{"id": "knight", "name": "KNIGHT", "level": 80, "tier": "epic"},
	{"id": "aviator", "name": "AVIATOR", "level": 85, "tier": "epic"},
	{"id": "disco", "name": "DISCO", "level": 90, "tier": "epic"},
	{"id": "dragon", "name": "DRAGON", "level": 95, "tier": "epic"},
	{"id": "platinum", "name": "PLATINUM", "level": 100, "tier": "legendary"},
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
## The colour each tier frames its looks in, on the sheets and in the tools;
## Classic's is faint.
const TIER_COLOURS := {
	"start": Blueprint.FAINT,
	"common": Blueprint.INK,
	"uncommon": Blueprint.MINT,
	"rare": Blueprint.LILAC,
	"epic": Blueprint.PINK,
	"legendary": Blueprint.GOLD,
	"special": Blueprint.GOLD,
}


## The look with this id, his or hers, or {} if there is none.
static func look(id: String) -> Dictionary:
	for entry: Dictionary in LOOKS:
		if entry.id == id:
			return entry
	for entry: Dictionary in HERS:
		if entry.id == id:
			return entry
	return {}


static func is_look(id: String) -> bool:
	return not look(id).is_empty()


## MapWoman's looks, and MapWoman herself: worn, the player is her.
static func is_hers(id: String) -> bool:
	if id == "mapwoman":
		return true
	for entry: Dictionary in HERS:
		if entry.id == id:
			return true
	return false


## Every id: his looks, then hers.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in LOOKS:
		out.append(entry.id)
	for entry: Dictionary in HERS:
		out.append(entry.id)
	return out


## Her wardrobe as the sheet lists it: MapWoman first, then her looks.
static func her_list() -> Array:
	return [LOOKS[-1]] + HERS


## The look the first clear of `level` releases, or "": one of his in the
## main game, one of hers in Revision B. MapWoman isn't a level's: she comes
## with finishing the game.
static func released_at(level: int, rev_b := false) -> String:
	if level <= 0 or level >= THE_END:
		return ""
	for entry: Dictionary in HERS if rev_b else LOOKS:
		if entry.level == level:
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


## Every look of hers that Revision B's progress has earned: a sheet's once
## she has been past it (the last sheet's only by clearing it, which
## releases it at the time).
static func earned_hers(furthest_sheet: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in HERS:
		if entry.level < furthest_sheet:
			out.append(entry.id)
	return out
