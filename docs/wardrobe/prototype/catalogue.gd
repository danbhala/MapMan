extends RefCounted
## WARDROBE DESIGN PROTOTYPE - the proposed collection, for the contact sheets.
## [id, name, level it unlocks at (0 = from the start, 101 = finishing the
## game, -1 = a feat on the bench), tier, kind]

const ITEMS := [
	["classic", "CLASSIC", 0, "START", "AS HE IS"],
	["party_hat", "PARTY HAT", 5, "COMMON", "HAT"],
	["signal_red", "SIGNAL RED", 10, "COMMON", "COLOUR"],
	["bobble_hat", "BOBBLE HAT", 15, "COMMON", "HAT"],
	["racing_green", "RACING GREEN", 20, "COMMON", "COLOUR"],
	["shades", "SHADES", 25, "COMMON", "FACE"],
	["blueprint", "BLUEPRINT", 30, "UNCOMMON", "COLOUR"],
	["cowboy", "COWBOY", 35, "UNCOMMON", "HAT"],
	["hard_hat", "HARD HAT", 40, "UNCOMMON", "OUTFIT"],
	["top_hat", "TOP HAT", 45, "UNCOMMON", "HAT"],
	["neon", "NEON", 50, "UNCOMMON", "COLOUR"],
	["doctor", "DOCTOR", 55, "RARE", "OUTFIT"],
	["pirate", "PIRATE", 60, "RARE", "OUTFIT"],
	["pumpkin", "PUMPKIN HEAD", 65, "RARE", "OUTFIT"],
	["skeleton", "SKELETON", 70, "RARE", "OUTFIT"],
	["explorer", "EXPLORER", 75, "RARE", "OUTFIT"],
	["astronaut", "ASTRONAUT", 80, "EPIC", "OUTFIT"],
	["robot", "ROBOT", 85, "EPIC", "OUTFIT"],
	["superhero", "SUPERHERO", 90, "EPIC", "OUTFIT"],
	["wizard", "WIZARD", 95, "EPIC", "OUTFIT"],
	["gold", "SOLID GOLD", 100, "LEGENDARY", "COLOUR"],
	["mapwoman", "MAPWOMAN", 101, "SPECIAL", "CHARACTER"],
]

## Alternates: swap into the main list, or later rewards for feats.
const BENCH := [
	["chef", "CHEF", -1, "BENCH", "OUTFIT"],
	["viking", "VIKING", -1, "BENCH", "OUTFIT"],
	["ninja", "NINJA", -1, "BENCH", "OUTFIT"],
	["vampire", "VAMPIRE", -1, "BENCH", "OUTFIT"],
	["king", "KING", -1, "BENCH", "OUTFIT"],
	["propeller", "PROPELLER CAP", -1, "BENCH", "HAT"],
	["bee", "BUMBLEBEE", -1, "BENCH", "OUTFIT"],
	["graduate", "GRADUATE", -1, "BENCH", "HAT"],
]

const TIER_COLOURS := {
	"START": Color(1, 1, 1, 0.66),
	"COMMON": Color.WHITE,
	"UNCOMMON": Color("#8be0c8"),
	"RARE": Color("#c9a6ff"),
	"EPIC": Color("#ff9fb5"),
	"LEGENDARY": Color("#ffd166"),
	"SPECIAL": Color("#ffd166"),
	"BENCH": Color(1, 1, 1, 0.66),
}

const POSES := [
	"front", "walk_r", "walk_l", "away", "land", "cheer", "blink", "spin", "stuck", "dying", "dead"
]
const POSE_NAMES := {
	"front": "FRONT",
	"walk_r": "WALK →",
	"walk_l": "WALK ←",
	"away": "AWAY",
	"land": "LAND",
	"cheer": "CHEER",
	"blink": "BLINK",
	"spin": "SPIN",
	"stuck": "COBWEB",
	"dying": "DYING",
	"dead": "DEAD",
}


static func when(level: int) -> String:
	if level == 0:
		return "FROM THE START"
	if level == 101:
		return "FINISH THE GAME"
	if level < 0:
		return "BENCH"
	return "LEVEL %d" % level


static func short_when(level: int) -> String:
	if level == 0:
		return "START"
	if level == 101:
		return "THE END"
	if level < 0:
		return "FEAT"
	return "LV %d" % level


static func find(id: String) -> Array:
	for item in ITEMS + BENCH:
		if item[0] == id:
			return item
	return []


## Set a figure's dials to one of POSES, the way the game would leave them.
static func pose(f, name: String) -> void:
	f.auto_look = false
	f.look = Vector2(0.15, 0.1)
	match name:
		"walk_r", "walk_l":
			f.flip = 1.0 if name == "walk_r" else -1.0
			f.look = Vector2(0.9, 0.0)
			f.walking = 1.0
			f._phase = 1.25
		"away":
			f.look = Vector2(0.0, -1.0)
			f.walking = 1.0
			f._phase = 0.5
		"land":
			f.squash = 0.4
			f.look = Vector2(0.3, 0.2)
		"cheer":
			f.happy = 1.0
			f._hop = 0.5
			f.look = Vector2(0.0, 0.1)
		"blink":
			f._blink = 1.0
		"spin":
			f.spin = 0.2
		"stuck":
			f.web = 1.0
		"dying":
			f.dead = 0.45
			f.squash = 0.45
			f.look = Vector2.ZERO
		"dead":
			f.dead = 1.0
			f.look = Vector2.ZERO
	f._idle_clock = 0.55
	f.queue_redraw()
