extends Node
## Persistent player data: options, best score, completed checkpoints.
## Replaces the dot-files the Pythonista version wrote next to the script.

const PATH := "user://mapman.cfg"

var music_on := true
var fx_on := true
var vibration_on := true
## Skip the decorative animation (stamps, sheets drawing on, tiles folding).
var reduce_motion := false
## Locale code of the chosen language, or "" to follow the phone's.
var locale := ""
## "sitting" or "standing": how far the phone is tilted back when neutral.
var playing_position := "sitting"
var highscore := 0
var first_play := true
var has_completed := false
## level number -> best score when that checkpoint was reached
var checkpoints := {}
## The furthest level reached in the main game; practice unlocks up to it.
var furthest_level := 1
## level number -> {"time": best seconds left, "stars": most stars}
var bests := {}
## Tests turn this off so they never overwrite the player's real progress.
var persist := true

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_all()
	apply_locale()


## Use the chosen language, or the phone's when none is chosen.
func apply_locale() -> void:
	if locale != "":
		TranslationServer.set_locale(locale)
	else:
		TranslationServer.set_locale(OS.get_locale())


## Switch language for good: "" follows the phone again.
func set_locale(code: String) -> void:
	locale = code
	apply_locale()
	save_all()


## path: tests load an old save from elsewhere; the game uses PATH.
func load_all(path := PATH) -> void:
	if _cfg.load(path) != OK:
		return
	music_on = _cfg.get_value("options", "music", true)
	fx_on = _cfg.get_value("options", "fx", true)
	vibration_on = _cfg.get_value("options", "vibration", true)
	reduce_motion = _cfg.get_value("options", "reduce_motion", false)
	locale = _cfg.get_value("options", "locale", "")
	playing_position = _cfg.get_value("options", "playing_position", "sitting")
	if playing_position not in ["sitting", "standing"]:
		playing_position = "sitting"
	highscore = _cfg.get_value("progress", "highscore", 0)
	first_play = _cfg.get_value("progress", "first_play", true)
	has_completed = _cfg.get_value("progress", "has_completed", false)
	var cps: Dictionary = _cfg.get_value("progress", "checkpoints", {})
	checkpoints.clear()
	for key in cps:
		checkpoints[int(key)] = int(cps[key])
	# Saves from before practice mode have no furthest level: count what they
	# had reached (a checkpoint restarts on the level after it).
	var seeded := 1
	for level in checkpoints:
		seeded = maxi(seeded, level + 1)
	if has_completed:
		seeded = 100
	furthest_level = _cfg.get_value("progress", "furthest_level", seeded)
	var saved_bests: Dictionary = _cfg.get_value("progress", "bests", {})
	bests.clear()
	for key in saved_bests:
		var b: Dictionary = saved_bests[key]
		bests[int(key)] = {"time": int(b.get("time", 0)), "stars": int(b.get("stars", 0))}


func save_all() -> void:
	if not persist:
		return
	_cfg.set_value("options", "music", music_on)
	_cfg.set_value("options", "fx", fx_on)
	_cfg.set_value("options", "vibration", vibration_on)
	_cfg.set_value("options", "reduce_motion", reduce_motion)
	_cfg.set_value("options", "locale", locale)
	_cfg.set_value("options", "playing_position", playing_position)
	_cfg.set_value("progress", "highscore", highscore)
	_cfg.set_value("progress", "first_play", first_play)
	_cfg.set_value("progress", "has_completed", has_completed)
	_cfg.set_value("progress", "checkpoints", checkpoints)
	_cfg.set_value("progress", "furthest_level", furthest_level)
	_cfg.set_value("progress", "bests", bests)
	_cfg.save(PATH)


func checkpoint_reached(level: int, score: int) -> void:
	if not checkpoints.has(level) or score > checkpoints[level]:
		checkpoints[level] = score
	save_all()


func level_reached(level: int) -> void:
	if level > furthest_level:
		furthest_level = level
		save_all()


## Keeps the best time left and the most stars separately; true if either improved.
func record_best(level: int, time_left: int, stars: int) -> bool:
	var old: Dictionary = bests.get(level, {"time": -1, "stars": -1})
	if time_left <= old.time and stars <= old.stars:
		return false
	bests[level] = {"time": maxi(time_left, old.time), "stars": maxi(stars, old.stars)}
	save_all()
	return true


func has_any_checkpoint() -> bool:
	return not checkpoints.is_empty()


## Returns true when this is a new personal best.
func submit_score(score: int) -> bool:
	if score > highscore:
		highscore = score
		save_all()
		return true
	return false
