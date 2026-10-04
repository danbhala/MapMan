extends Node
## Persistent player data: options, best score, completed checkpoints, the
## wardrobe. Replaces the dot-files the Pythonista version wrote next to the
## script.

## The language on screen changed (use_locale).
signal locale_changed

const PATH := "user://mapman.cfg"

var music_on := true
var fx_on := true
var vibration_on := true
## Skip the decorative animation (stamps, sheets drawing on, tiles folding).
var reduce_motion := false
## The tilt gauge in the corner of the field (TiltDial).
var tilt_gauge := true
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
## The look MapMan wears (a Wardrobe id), and the looks released so far, in
## the order they came. Classic is always there and never listed.
var worn := "classic"
var released: Array[String] = []
## Released looks the wardrobe has shown: the main menu says NEW until then.
var seen: Array[String] = []
## Tests turn this off so they never overwrite the player's real progress.
var persist := true

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_all()
	apply_locale()


## Use the chosen language, or the phone's when none is chosen.
func apply_locale() -> void:
	use_locale(locale if locale != "" else OS.get_locale())


## Show the game in `code` without changing the choice: apply_locale() picks
## the code, tests pass one to stand in for the phone's.
func use_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	Blueprint.prefer_script(shown_locale())
	locale_changed.emit()


## The language on screen: that of the translation closest to the locale in
## force, or English when there is none for it.
func shown_locale() -> String:
	var t := TranslationServer.get_translation_object(TranslationServer.get_locale())
	return t.locale if t != null else "en"


## Whether the language on screen reads right to left: Arabic does, English
## shown on a Hebrew phone does not.
func reads_rtl() -> bool:
	var ts := TextServerManager.get_primary_interface()
	return ts.is_locale_right_to_left(shown_locale())


## Switch language for good: "" follows the phone again.
func set_locale(code: String) -> void:
	locale = code
	apply_locale()
	save_all()


## path: tests load an old save from elsewhere; the game uses PATH.
func load_all(path := PATH) -> void:
	# A fresh file each time: ConfigFile.load() keeps keys from a file loaded
	# before, which a second load (tests load old saves) would inherit.
	_cfg = ConfigFile.new()
	if _cfg.load(path) != OK:
		return
	music_on = _cfg.get_value("options", "music", true)
	fx_on = _cfg.get_value("options", "fx", true)
	vibration_on = _cfg.get_value("options", "vibration", true)
	reduce_motion = _cfg.get_value("options", "reduce_motion", false)
	tilt_gauge = _cfg.get_value("options", "tilt_gauge", true)
	locale = _cfg.get_value("options", "locale", "")
	# A language this build no longer ships falls back to the phone's.
	if locale != "" and locale != "en" and locale not in TranslationServer.get_loaded_locales():
		locale = ""
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
	released = _looks(_cfg.get_value("wardrobe", "released", []))
	seen = _looks(_cfg.get_value("wardrobe", "seen", []))
	# Saves from before the wardrobe have the progress but not the looks.
	sync_wardrobe()
	var saved_worn: Variant = _cfg.get_value("wardrobe", "worn", "classic")
	worn = saved_worn if saved_worn is String and is_released(saved_worn) else "classic"


## path: tests write to a file of their own; the game uses PATH.
func save_all(path := PATH) -> void:
	if not persist:
		return
	_cfg.set_value("options", "music", music_on)
	_cfg.set_value("options", "fx", fx_on)
	_cfg.set_value("options", "vibration", vibration_on)
	_cfg.set_value("options", "reduce_motion", reduce_motion)
	_cfg.set_value("options", "tilt_gauge", tilt_gauge)
	_cfg.set_value("options", "locale", locale)
	_cfg.set_value("options", "playing_position", playing_position)
	_cfg.set_value("progress", "highscore", highscore)
	_cfg.set_value("progress", "first_play", first_play)
	_cfg.set_value("progress", "has_completed", has_completed)
	_cfg.set_value("progress", "checkpoints", checkpoints)
	_cfg.set_value("progress", "furthest_level", furthest_level)
	_cfg.set_value("progress", "bests", bests)
	_cfg.set_value("wardrobe", "worn", worn)
	_cfg.set_value("wardrobe", "released", released)
	_cfg.set_value("wardrobe", "seen", seen)
	_cfg.save(path)


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


# --- the wardrobe (docs/wardrobe) -------------------------------------------------


func is_released(id: String) -> bool:
	return id == "classic" or id in released


## Puts a look in the wardrobe; true if it wasn't there before.
func release(id: String) -> bool:
	if not Wardrobe.is_look(id) or is_released(id):
		return false
	released.append(id)
	save_all()
	return true


## Wears a released look; false (and no change) for any other id.
func wear(id: String) -> bool:
	if not is_released(id):
		return false
	worn = id
	save_all()
	return true


## The wardrobe has been looked at: nothing in it is new any more.
func mark_seen() -> void:
	if seen == released:
		return
	seen = released.duplicate()
	save_all()


## Released looks the wardrobe hasn't shown yet.
func unseen() -> int:
	var n := 0
	for id in released:
		if id not in seen:
			n += 1
	return n


## Releases every look the progress has earned: a save from before the
## wardrobe, or a level skipped in a dev build.
func sync_wardrobe() -> void:
	for id in Wardrobe.earned(furthest_level, has_completed):
		if not is_released(id):
			released.append(id)


## The known looks in a list read from the save, each once.
func _looks(saved: Variant) -> Array[String]:
	var out: Array[String] = []
	if saved is Array:
		for id in saved:
			if id is String and id != "classic" and Wardrobe.is_look(id) and id not in out:
				out.append(id)
	return out
